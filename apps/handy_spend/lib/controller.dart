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
      if (!_swept) {
        _swept = true;
        // Files left by a change that never landed. Only here, before any
        // Undo in this session could need them.
        try {
          await store!.sweepReceipts({for (final r in state!.receipts) r.id});
        } catch (_) {}
      }
    } catch (e) {
      error = e;
    }
    if (!disposed) notifyListeners();
  }

  bool _swept = false;
  final _files = <String, Uint8List>{};

  /// A receipt's bytes, from a small memory cache or the store.
  Future<Uint8List?> receiptBytes(String id) async {
    final cached = _files.remove(id);
    if (cached != null) return _files[id] = cached;
    final bytes = await store!.readReceipt(id);
    if (bytes != null) _remember(id, bytes);
    return bytes;
  }

  void _remember(String id, Uint8List bytes) {
    _files[id] = bytes;
    var size = _files.values.fold(0, (int n, b) => n + b.length);
    while (_files.length > 1 && size > 24000000) {
      size -= _files.remove(_files.keys.first)!.length;
    }
  }

  /// Stores [files] (receipt ID to bytes) first, then makes the change
  /// that lists them. If the change fails, the files are unlisted and the
  /// next start removes them; the ledger is as it was.
  Future<void> changeWithFiles(
    SpendState Function(SpendState) transform,
    String label, {
    Map<String, Uint8List> files = const {},
  }) async {
    for (final f in files.entries) {
      await store!.putReceipt(f.key, f.value);
      _remember(f.key, f.value);
    }
    await change(transform, label);
  }

  /// Deletes entries with their receipts and splits, in one change.
  Future<void> deleteEntries(Set<String> ids, String label) =>
      change((s) => withoutEntries(s, ids), label);

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
          'receipts',
          'people',
          'splits',
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
