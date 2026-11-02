import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'store.dart';

Future<SpendStore> openStore() => BrowserSpendStore.open();

class BrowserSpendStore implements SpendStore {
  final web.IDBDatabase db;
  BrowserSpendStore._(this.db);
  static Future<BrowserSpendStore> open() async {
    final ready = Completer<BrowserSpendStore>(),
        r = web.window.indexedDB.open('handy-spend', 2);
    // Version 2 adds the receipts store; existing stores are kept as they
    // are, whichever version the browser had.
    r.onupgradeneeded = ((web.Event _) {
      final db = r.result as web.IDBDatabase;
      for (final name in ['accounts', 'entries', 'state', 'receipts']) {
        if (!db.objectStoreNames.contains(name)) db.createObjectStore(name);
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

  Future<T> _receipts<T>(
    String mode,
    void Function(web.IDBObjectStore store, void Function(T) done) run,
  ) {
    final result = Completer<T>(), tx = db.transaction('receipts'.toJS, mode);
    T? value;
    tx.oncomplete = ((web.Event _) => result.complete(value as T)).toJS;
    tx.onabort = ((web.Event _) => result.completeError(
      StateError('Browser storage refused the receipt; nothing changed'),
    )).toJS;
    tx.onerror = tx.onabort;
    run(tx.objectStore('receipts'), (v) => value = v);
    return result.future;
  }

  @override
  Future<void> putReceipt(String id, Uint8List bytes) =>
      _receipts<void>('readwrite', (store, _) {
        store.put(bytes.toJS, id.toJS);
      });

  @override
  Future<Uint8List?> readReceipt(String id) => _receipts<Uint8List?>(
    'readonly',
    (store, done) {
      final r = store.get(id.toJS);
      r.onsuccess = ((web.Event _) {
        final v = r.result;
        done(
          v == null || v.isUndefinedOrNull ? null : (v as JSUint8Array).toDart,
        );
      }).toJS;
    },
  );

  @override
  Future<int> sweepReceipts(Set<String> keep) =>
      _receipts<int>('readwrite', (store, done) {
        final r = store.getAllKeys();
        done(0);
        r.onsuccess = ((web.Event _) {
          var n = 0;
          for (final k in (r.result as JSArray).toDart) {
            final id = (k as JSString).toDart;
            if (keep.contains(id)) continue;
            store.delete(k);
            n++;
          }
          done(n);
        }).toJS;
      });

  @override
  Future<String> integrity() async {
    (await read()).validate();
    return 'ok';
  }
}
