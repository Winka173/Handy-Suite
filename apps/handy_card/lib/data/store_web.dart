import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'store.dart';

Future<CardStore> openStore() {
  final done = Completer<CardStore>(),
      request = web.window.indexedDB.open('handy-card', 1);
  request.onupgradeneeded = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    db.createObjectStore('records');
    db.createObjectStore('assets');
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    db.onversionchange = ((web.Event _) => db.close()).toJS;
    if (!done.isCompleted) done.complete(BrowserCardStore(db));
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!done.isCompleted) {
      done.completeError(StateError('Browser storage is unavailable'));
    }
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!done.isCompleted) {
      done.completeError(StateError('Close other Handy Card tabs and retry'));
    }
  }).toJS;
  return done.future;
}

/// IndexedDB: records keyed "kind/id", pictures as raw bytes by id. A full
/// quota aborts the transaction and the previous copy stays.
class BrowserCardStore implements CardStore {
  final web.IDBDatabase db;
  BrowserCardStore(this.db);

  Future<T> _tx<T>(
    String store,
    String mode,
    T Function() value,
    void Function(web.IDBObjectStore s) body,
  ) {
    final done = Completer<T>();
    final t = db.transaction(store.toJS, mode);
    body(t.objectStore(store));
    t.oncomplete = ((web.Event _) => done.complete(value())).toJS;
    t.onabort = ((web.Event _) => done.completeError(
      StateError('Browser storage refused the write (quota?); nothing changed'),
    )).toJS;
    return done.future;
  }

  @override
  Future<CardStoreData> read() async {
    final records = <String, Map<String, String>>{};
    await _tx<void>('records', 'readonly', () {}, (s) {
      final keys = s.getAllKeys(), values = s.getAll();
      values.onsuccess = ((web.Event _) {
        final ks = (keys.result.dartify() as List).cast<String>();
        final vs = (values.result.dartify() as List).cast<String>();
        for (var i = 0; i < ks.length; i++) {
          final slash = ks[i].indexOf('/');
          (records[ks[i].substring(0, slash)] ??= {})[ks[i].substring(
                slash + 1,
              )] =
              vs[i];
        }
      }).toJS;
    });
    final assets = <String>{};
    await _tx<void>('assets', 'readonly', () {}, (s) {
      final keys = s.getAllKeys();
      keys.onsuccess = ((web.Event _) => assets.addAll(
        (keys.result.dartify() as List).cast<String>(),
      )).toJS;
    });
    return CardStoreData(records, assets);
  }

  @override
  Future<void> put(String kind, String id, String json) => _tx<void>(
    'records',
    'readwrite',
    () {},
    (s) => s.put(json.toJS, '$kind/$id'.toJS),
  );

  @override
  Future<void> delete(String kind, String id) => _tx<void>(
    'records',
    'readwrite',
    () {},
    (s) => s.delete('$kind/$id'.toJS),
  );

  @override
  Future<void> putAsset(String id, Uint8List bytes) => _tx<void>(
    'assets',
    'readwrite',
    () {},
    (s) => s.put(bytes.toJS, id.toJS),
  );

  @override
  Future<Uint8List?> asset(String id) {
    Uint8List? out;
    return _tx<Uint8List?>('assets', 'readonly', () => out, (s) {
      final r = s.get(id.toJS);
      r.onsuccess = ((web.Event _) {
        final v = r.result;
        out = v == null ? null : (v as JSUint8Array).toDart;
      }).toJS;
    });
  }

  @override
  Future<void> deleteAssets(Set<String> ids) =>
      _tx<void>('assets', 'readwrite', () {}, (s) {
        for (final id in ids) {
          s.delete(id.toJS);
        }
      });
}
