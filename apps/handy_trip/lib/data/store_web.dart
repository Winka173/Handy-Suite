import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'store.dart';

final names = [...collections, 'files', 'state'];
Future<TripStore> openStore() async {
  final done = Completer<TripStore>(),
      request = web.window.indexedDB.open('handy-trip', 1);
  request.onupgradeneeded = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    for (final k in names) db.createObjectStore(k);
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    db.onversionchange = ((web.Event _) => db.close()).toJS;
    if (!done.isCompleted) done.complete(BrowserTripStore(db));
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!done.isCompleted)
      done.completeError(
        StateError('Browser storage unavailable; existing data preserved'),
      );
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!done.isCompleted)
      done.completeError(StateError('Close other Trip tabs and retry'));
  }).toJS;
  return done.future;
}

class BrowserTripStore implements TripStore {
  final web.IDBDatabase db;
  BrowserTripStore(this.db);
  web.IDBTransaction tx(String mode) =>
      db.transaction(names.map((s) => s.toJS).toList().toJS, mode);
  @override
  Future<TripState> read() {
    final done = Completer<TripState>(),
        transaction = tx('readonly'),
        values = <String, dynamic>{};
    for (final name in names) {
      final request = name == 'state'
          ? transaction.objectStore(name).get('snapshot'.toJS)
          : transaction.objectStore(name).getAll();
      request.onsuccess = ((web.Event _) {
        final v = request.result.dartify();
        values[name] = name == 'state'
            ? (v == null
                  ? TripState().toJson(includeData: false)
                  : jsonDecode(v as String))
            : (v as List).map((x) => jsonDecode(x as String)).toList();
      }).toJS;
    }
    transaction.oncomplete = ((web.Event _) {
      try {
        done.complete(
          TripState.fromJson(
            {
              ...object(values['state']),
              for (final kind in collections) kind: values[kind],
            },
            files: {
              for (final row in values['files'] as List)
                row['path'] as String: base64Decode(row['body'] as String),
            },
          ),
        );
      } catch (e) {
        done.completeError(e);
      }
    }).toJS;
    transaction.onabort = ((web.Event _) => done.completeError(
      StateError('Browser read aborted'),
    )).toJS;
    return done.future;
  }

  @override
  Future<void> commit(TripState next, {required int expectedRevision}) async {
    next.validate();
    final done = Completer<void>(),
        transaction = tx('readwrite'),
        request = transaction.objectStore('state').get('snapshot'.toJS);
    Object? failure;
    transaction.oncomplete = ((web.Event _) => done.complete()).toJS;
    transaction.onabort = ((web.Event _) => done.completeError(
      failure ??
          StateError(
            'Browser quota/transaction failure; previous data preserved',
          ),
    )).toJS;
    request.onsuccess = ((web.Event _) {
      try {
        final raw = request.result.dartify(),
            previous = raw == null
                ? 0
                : object(jsonDecode(raw as String))['revision'];
        if (previous != expectedRevision ||
            next.revision != expectedRevision + 1)
          throw StateError('Another tab changed Trip data; reload');
        final data = next.toJson(includeData: false);
        for (final kind in collections) {
          final store = transaction.objectStore(kind);
          store.clear();
          for (final e in next.entities(kind))
            store.put(jsonEncode(e.toJson()).toJS, e.key.toJS);
          data.remove(kind);
        }
        final fileStore = transaction.objectStore('files'),
            keys = fileStore.getAllKeys();
        keys.onsuccess = ((web.Event _) {
          for (final key in keys.result.dartify() as List)
            if (!next.files.containsKey(key))
              fileStore.delete((key as String).toJS);
        }).toJS;
        for (final entry in next.files.entries) {
          final previous = fileStore.get(entry.key.toJS);
          previous.onsuccess = ((web.Event _) {
            final expected = jsonEncode({
              'path': entry.key,
              'body': base64Encode(entry.value),
            });
            if (previous.result.dartify() != expected)
              fileStore.put(expected.toJS, entry.key.toJS);
          }).toJS;
        }
        transaction
            .objectStore('state')
            .put(jsonEncode(data).toJS, 'snapshot'.toJS);
      } catch (e) {
        failure = e;
        transaction.abort();
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
