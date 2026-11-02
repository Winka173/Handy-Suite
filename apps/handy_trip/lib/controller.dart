import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'data/store.dart';

class TripController extends ChangeNotifier {
  final Future<TripStore> Function() open;
  TripStore? store;
  TripState? state;
  Object? error;
  bool disposed = false;
  int _pending = 0;
  bool get busy => _pending > 0;
  final adsVisible = ValueNotifier(false);
  Future<void> _queue = Future.value();
  TripState? _undo;
  int? _undoAt;
  bool get canUndo => _undo != null && state?.revision == _undoAt;
  TripController({Future<TripStore> Function()? open})
    : open = open ?? openTripStore;
  Future<void> load() async {
    try {
      store ??= await open();
      state = await store!.read();
      error = null;
    } catch (e) {
      error = e;
    }
    if (!disposed) notifyListeners();
  }

  Future<void> change(
    TripState Function(TripState) action, {
    bool undoable = true,
  }) {
    final done = Completer<void>();
    _pending++;
    if (!disposed) notifyListeners();
    _queue = _queue.then((_) async {
      try {
        final before = state ?? (throw StateError('Trip data unavailable')),
            proposed = action(before),
            next = proposed.copy({'revision': before.revision + 1});
        next.validate();
        await store!.commit(next, expectedRevision: before.revision);
        _undo = undoable ? before : null;
        _undoAt = undoable ? next.revision : null;
        state = next;
        error = null;
        done.complete();
      } catch (e, st) {
        done.completeError(e, st);
      } finally {
        _pending--;
        if (!disposed) notifyListeners();
      }
    });
    return done.future;
  }

  Future<void> undo() async {
    final old = _undo, at = _undoAt;
    if (old == null) throw StateError('No Undo after restart');
    await change((s) {
      if (s.revision != at) throw StateError('Newer changes prevent Undo');
      return old;
    }, undoable: false);
  }

  @override
  void dispose() {
    disposed = true;
    adsVisible.dispose();
    super.dispose();
  }
}
