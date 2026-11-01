import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'data/store.dart';

class HabitController extends ChangeNotifier {
  final Future<HabitStore> Function() open;
  HabitStore? store;
  HabitState? state;
  Object? error;
  bool busy = false, disposed = false;
  final adsVisible = ValueNotifier(false);
  HabitState? _undo;
  int? _undoRevision;
  Future<void> _queue = Future.value();
  HabitController({Future<HabitStore> Function()? open})
    : open = open ?? openHabitStore;
  bool get canUndo => _undo != null && state?.revision == _undoRevision;
  Future<void> load() async {
    try {
      error = null;
      store ??= await open();
      state = await store!.read();
    } catch (e) {
      error = e;
    }
    if (!disposed) notifyListeners();
  }

  Future<void> change(
    HabitState Function(HabitState) action, {
    bool remember = true,
  }) {
    final result = Completer<void>();
    busy = true;
    if (!disposed) notifyListeners();
    _queue = _queue.then((_) async {
      try {
        final before = state ?? (throw StateError('Data unavailable')),
            proposed = action(before);
        proposed.validate();
        final next = proposed.copy({'revision': before.revision + 1});
        await store!.commit(next, expectedRevision: before.revision);
        if (remember) {
          _undo = before;
          _undoRevision = next.revision;
        } else {
          _undo = null;
          _undoRevision = null;
        }
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
    final old = _undo, revision = _undoRevision;
    if (old == null) throw StateError('No Undo after restart');
    await change((s) {
      if (s.revision != revision)
        throw StateError('Newer changes prevent Undo');
      return old;
    }, remember: false);
  }

  @override
  void dispose() {
    disposed = true;
    adsVisible.dispose();
    super.dispose();
  }
}
