import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'data/store.dart';

class BoardsController extends ChangeNotifier {
  final Future<BoardsStore> Function() open;
  BoardsStore? store;
  BoardsState? state;
  Object? error;
  bool _disposed = false;
  int _pending = 0;
  bool get busy => _pending > 0;
  final adsVisible = ValueNotifier(false);
  bool advancedEnabled = false;
  Future<void> Function(BoardsState)? afterCommit;
  String? adapterWarning;
  Future<void> _queue = Future.value();
  final _undo = <BoardsState>[], _redo = <BoardsState>[];
  bool get canUndo => _undo.isNotEmpty && !busy;
  bool get canRedo => _redo.isNotEmpty && !busy;
  BoardsController({Future<BoardsStore> Function()? open})
    : open = open ?? openBoardsStore;
  Future<void> load() async {
    try {
      store ??= await open();
      final loaded = await store!.read();
      state = loaded;
      error = null;
      _undo.clear();
      _redo.clear();
      try {
        await afterCommit?.call(loaded);
        adapterWarning = null;
      } catch (e) {
        adapterWarning = e.toString();
      }
    } catch (e) {
      error = e;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> change(
    BoardsState Function(BoardsState) action, {
    bool history = true,
  }) {
    final done = Completer<void>();
    _pending++;
    if (!_disposed) notifyListeners();
    _queue = _queue.then((_) async {
      try {
        final before = state ?? (throw StateError('Boards data unavailable'));
        final proposed = action(before);
        if (identical(proposed, before)) {
          done.complete();
          return;
        }
        var next = proposed.copy(revision: before.revision + 1);
        final retention = next.preferences['historyDays'] as int? ?? 0;
        if (retention > 0)
          next = retainActivity(next, retention, DateTime.now());
        if (history &&
            advancedEnabled &&
            next.rows('rules').any((r) => r.flag('enabled'))) {
          final eventId = newId();
          for (final task in next.rows('tasks').toList()) {
            final old = before.maybe('tasks', task.id);
            final trigger = old == null
                ? 'created'
                : old.data['category'] != task.data['category']
                ? 'moved'
                : !completed(before, old) && completed(next, task)
                ? 'completed'
                : old.data['due'].toString() != task.data['due'].toString()
                ? 'due changed'
                : null;
            if (trigger != null)
              next = runAutomations(
                next,
                task.id,
                trigger,
                '$eventId/${task.id}',
                now: DateTime.now(),
              );
          }
        }
        next.validate();
        await store!.commit(next, expectedRevision: before.revision);
        if (history) {
          _undo.add(before);
          if (_undo.length > 10) _undo.removeAt(0);
          _redo.clear();
        }
        state = store is BoardsSnapshotStore
            ? (store as BoardsSnapshotStore).currentSnapshot ?? next
            : next;
        error = null;
        try {
          await afterCommit?.call(state!);
          adapterWarning = null;
        } catch (e) {
          adapterWarning = e.toString();
        }
        done.complete();
      } catch (e, st) {
        done.completeError(e, st);
      } finally {
        _pending--;
        if (!_disposed) notifyListeners();
      }
    });
    return done.future;
  }

  Future<void> undo() async {
    if (!canUndo) throw StateError('No Undo');
    final old = _undo.last, before = state!;
    await change((s) => old, history: false);
    _undo.removeLast();
    _redo.add(before);
    if (!_disposed) notifyListeners();
  }

  Future<void> redo() async {
    if (!canRedo) throw StateError('No Redo');
    final next = _redo.last, before = state!;
    await change((s) => next, history: false);
    _redo.removeLast();
    _undo.add(before);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    adsVisible.dispose();
    if (store is BoardsSnapshotStore) (store as BoardsSnapshotStore).close();
    super.dispose();
  }
}
