import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'data/store.dart';

class HabitController extends ChangeNotifier {
  final Future<HabitStore> Function() open;
  final DateTime Function() clock;
  HabitStore? store;
  HabitState? state;
  Object? error;
  bool busy = false, disposed = false;
  final adsVisible = ValueNotifier(false);
  final String actor = uid();
  bool hasRecovery = false;
  Future<void> _queue = Future.value();
  HabitController({
    Future<HabitStore> Function()? open,
    DateTime Function()? clock,
  }) : open = open ?? openHabitStore,
       clock = clock ?? DateTime.now;
  bool get canUndo => state?.undoBatch != null;
  Future<void> load() async {
    try {
      error = null;
      store ??= await open();
      state = await store!.read();
      if (store case final RecoverableHabitStore recoverable) {
        hasRecovery = await recoverable.readRecovery() != null;
      }
      final purged = purgeTrash(state!, clock().toUtc());
      if (purged.trash.length != state!.trash.length) {
        final next = purged.copy({'revision': state!.revision + 1});
        await store!.commit(next, expectedRevision: state!.revision);
        state = next;
      }
    } catch (e) {
      error = e;
      store = null;
    }
    if (!disposed) notifyListeners();
  }

  Future<void> change(
    HabitState Function(HabitState) action, {
    bool remember = true,
    bool recorded = false,
    bool recovery = false,
  }) {
    final result = Completer<void>();
    busy = true;
    if (!disposed) notifyListeners();
    _queue = _queue.then((_) async {
      try {
        final before = state ?? (throw StateError('Data unavailable')),
            proposed = action(before);
        proposed.validate();
        final tracked = recorded
            ? proposed
            : recordChange(
                before,
                proposed,
                actor: actor,
                undoable: remember,
                now: clock(),
              );
        final next = tracked.copy({'revision': before.revision + 1});
        if (recovery) {
          final recoverable = store;
          if (recoverable is! RecoverableHabitStore)
            throw StateError(
              'Durable recovery unavailable; replacement stopped',
            );
          await recoverable.saveRecovery(expectedRevision: before.revision);
          hasRecovery = true;
        }
        await store!.commit(next, expectedRevision: before.revision);
        state = next;
        error = null;
        result.complete();
      } catch (e, st) {
        result.completeError(e, st);
      } finally {
        busy = false;
        if (!disposed) notifyListeners();
      }
    });
    return result.future;
  }

  Future<void> undo() async {
    final batch = state?.undoBatch;
    if (batch == null) throw StateError('Undo is no longer available');
    await change(
      (s) => undoChange(s, batch, actor: actor),
      remember: false,
      recorded: true,
    );
  }

  Future<void> replaceFromBackup(
    HabitState imported, {
    required int expectedRevision,
  }) => change(
    (s) {
      if (s.revision != expectedRevision)
        throw StateError('Data changed during preview');
      return imported.copy({'undoBatch': null});
    },
    remember: false,
    recorded: true,
    recovery: true,
  );

  Future<void> recoverBeforeReplace() async {
    final recoverable = store;
    if (recoverable is! RecoverableHabitStore)
      throw StateError('Recovery unavailable');
    final revision = state!.revision;
    final saved = await recoverable.readRecovery();
    if (saved == null) throw StateError('No recovery copy');
    // Preserve the existing recovery copy until the recovery commit succeeds.
    await change(
      (s) {
        if (s.revision != revision)
          throw StateError('Data changed during recovery');
        return saved.copy({'undoBatch': null});
      },
      remember: false,
      recorded: true,
    );
  }

  @override
  void dispose() {
    disposed = true;
    adsVisible.dispose();
    super.dispose();
  }
}
