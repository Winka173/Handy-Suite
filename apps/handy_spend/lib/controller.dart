import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'data/store.dart';

class SpendController extends ChangeNotifier {
  final Future<SpendStore> Function() open;
  SpendStore? store;
  SpendState? state;
  Object? error;
  final adsVisible = ValueNotifier(false);
  bool disposed = false;
  SpendState? _undo;
  int? _undoRevision;
  Future<void> _queue = Future.value();
  SpendController({Future<SpendStore> Function()? open})
    : open = open ?? openSpendStore;
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

  Future<void> change(SpendState Function(SpendState) transform, String label) {
    final result = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        final before = state ?? (throw StateError('Library unavailable')),
            proposed = transform(before);
        proposed.validate();
        final a = before.toJson(),
            b = proposed.toJson(),
            changes = <String, dynamic>{};
        for (final key in [
          'accounts',
          'entries',
          'categories',
          'budgets',
          'goals',
          'bills',
          'scenarios',
          'rules',
          'profiles',
          'imports',
        ]) {
          final old = {for (final e in a[key] as List) (e as Map)['id']: e},
              next = {for (final e in b[key] as List) (e as Map)['id']: e};
          final changed = {
            ...old.keys,
            ...next.keys,
          }.where((id) => jsonEncode(old[id]) != jsonEncode(next[id]));
          changes[key] = [
            for (final id in changed)
              {'id': id, 'before': old[id], 'after': next[id]},
          ];
        }
        if (jsonEncode(a['settings']) != jsonEncode(b['settings']))
          changes['settings'] = {
            'before': a['settings'],
            'after': b['settings'],
          };
        final event = {
          'id': newId(),
          'at': DateTime.now().toUtc().toIso8601String(),
          'action': label,
          'previousRevision': before.revision,
          'beforeHash': sha256.convert(utf8.encode(jsonEncode(a))).toString(),
          'changes': changes,
        };
        final auditIds = before.audit.map((record) => record['id']).toSet();
        final next = proposed.copy({
          'revision': before.revision + 1,
          'audit': [
            ...before.audit,
            ...proposed.audit.where(
              (record) => !auditIds.contains(record['id']),
            ),
            event,
          ],
        });
        await store!.commit(next, expectedRevision: before.revision);
        _undo = before;
        _undoRevision = next.revision;
        state = next;
        error = null;
        if (!disposed) notifyListeners();
        result.complete();
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  Future<void> undo() async {
    final old = _undo, expected = _undoRevision;
    if (old == null || state?.revision != expected)
      throw StateError('Undo unavailable after newer changes');
    await change((s) {
      if (s.revision != expected) throw StateError('Stale Undo');
      return old;
    }, 'undo');
    _undo = null;
    _undoRevision = null;
  }

  Future<void> putEntry(Entry e) => change(
    (s) => s.copy({
      'entries': [
        for (final x in s.entries)
          if (x.id != e.id) x.toJson(),
        e.toJson(),
      ],
    }),
    'save_transaction',
  );
  @override
  void dispose() {
    disposed = true;
    adsVisible.dispose();
    super.dispose();
  }
}
