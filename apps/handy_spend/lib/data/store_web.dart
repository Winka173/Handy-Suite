import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'store.dart';

Future<SpendStore> openStore() => BrowserSpendStore.open();

class BrowserSpendStore implements SpendStore {
  final web.IDBDatabase db;
  BrowserSpendStore._(this.db);
  static Future<BrowserSpendStore> open() async {
    final ready = Completer<BrowserSpendStore>(),
        r = web.window.indexedDB.open('handy-spend', 1);
    r.onupgradeneeded = ((web.Event _) {
      final db = r.result as web.IDBDatabase;
      for (final name in ['accounts', 'entries', 'state']) {
        db.createObjectStore(name);
      }
    }).toJS;
    r.onsuccess = ((web.Event _) => ready.complete(
      BrowserSpendStore._(r.result as web.IDBDatabase),
    )).toJS;
    r.onerror = ((web.Event _) => ready.completeError(
      StateError('Browser storage unavailable; existing data preserved'),
    )).toJS;
    r.onblocked = ((web.Event _) => ready.completeError(
      StateError('Close other Spend tabs and retry'),
    )).toJS;
    return ready.future;
  }

  web.IDBTransaction _tx(String mode) => db.transaction(
    ['accounts', 'entries', 'state'].map((e) => e.toJS).toList().toJS,
    mode,
  );
  @override
  Future<SpendState> read() async {
    final done = Completer<SpendState>(),
        tx = _tx('readonly'),
        result = <String, dynamic>{};
    for (final name in ['accounts', 'entries', 'state']) {
      final r = name == 'state'
          ? tx.objectStore(name).get('snapshot'.toJS)
          : tx.objectStore(name).getAll();
      r.onsuccess = ((web.Event _) {
        final data = r.result.dartify();
        result[name] = name == 'state'
            ? (data == null
                  ? SpendState().toJson()
                  : jsonDecode(data as String))
            : (data as List).map((v) => jsonDecode(v as String)).toList();
      }).toJS;
    }
    tx.oncomplete = ((web.Event _) {
      try {
        done.complete(
          SpendState.fromJson({
            ...Map<String, dynamic>.from(result['state'] as Map),
            'accounts': result['accounts'],
            'entries': result['entries'],
          }),
        );
      } catch (e) {
        done.completeError(e);
      }
    }).toJS;
    tx.onabort = ((web.Event _) => done.completeError(
      StateError('Browser read aborted'),
    )).toJS;
    return done.future;
  }

  @override
  Future<void> commit(SpendState state, {required int expectedRevision}) async {
    state.validate();
    if (state.revision != expectedRevision + 1)
      throw StateError('Revision mismatch');
    final done = Completer<void>(),
        tx = _tx('readwrite'),
        r = tx.objectStore('state').get('snapshot'.toJS);
    Object? failure;
    tx.oncomplete = ((web.Event _) => done.complete()).toJS;
    tx.onabort = ((web.Event _) => done.completeError(
      failure ??
          StateError('Storage quota or transaction failure; data preserved'),
    )).toJS;
    r.onsuccess = ((web.Event _) {
      try {
        final raw = r.result.dartify(),
            revision = raw == null
                ? 0
                : (jsonDecode(raw as String) as Map)['revision'];
        if (revision != expectedRevision)
          throw StateError('Another tab changed data; reload');
        final accounts = tx.objectStore('accounts'),
            entries = tx.objectStore('entries');
        accounts.clear();
        entries.clear();
        for (final a in state.accounts) {
          accounts.put(jsonEncode(a.toJson()).toJS, a.id.toJS);
        }
        for (final e in state.entries) {
          entries.put(jsonEncode(e.toJson()).toJS, e.id.toJS);
        }
        final metadata = state.toJson()
          ..remove('accounts')
          ..remove('entries');
        tx.objectStore('state').put(jsonEncode(metadata).toJS, 'snapshot'.toJS);
      } catch (e) {
        failure = e;
        tx.abort();
      }
    }).toJS;
    await done.future;
  }

  @override
  Future<String> integrity() async {
    (await read()).validate();
    return 'ok';
  }
}
