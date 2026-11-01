import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'store.dart';

const names = ['habits', 'events', 'routines', 'sessions', 'state'];
Future<HabitStore> openStore() async {
  final done = Completer<HabitStore>(),
      request = web.window.indexedDB.open('handy-habit', 1);
  request.onupgradeneeded = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    for (final name in names) {
      db.createObjectStore(name);
    }
  }).toJS;
  request.onsuccess = ((web.Event _) => done.complete(
    BrowserHabitStore(request.result as web.IDBDatabase),
  )).toJS;
  request.onerror = ((web.Event _) => done.completeError(
    StateError('Browser storage unavailable; data preserved'),
  )).toJS;
  request.onblocked = ((web.Event _) => done.completeError(
    StateError('Close other Habit tabs and retry'),
  )).toJS;
  return done.future;
}

class BrowserHabitStore implements HabitStore {
  final web.IDBDatabase db;
  BrowserHabitStore(this.db);
  web.IDBTransaction transaction(String mode) =>
      db.transaction(names.map((s) => s.toJS).toList().toJS, mode);
  @override
  Future<HabitState> read() {
    final done = Completer<HabitState>(),
        tx = transaction('readonly'),
        result = <String, dynamic>{};
    for (final name in names) {
      final request = name == 'state'
          ? tx.objectStore(name).get('snapshot'.toJS)
          : tx.objectStore(name).getAll();
      request.onsuccess = ((web.Event _) {
        final value = request.result.dartify();
        result[name] = name == 'state'
            ? (value == null
                  ? HabitState().toJson()
                  : jsonDecode(value as String))
            : (value as List).map((s) => jsonDecode(s as String)).toList();
      }).toJS;
    }
    tx.oncomplete = ((web.Event _) {
      try {
        done.complete(
          HabitState.fromJson({
            ...Map<String, dynamic>.from(result['state'] as Map),
            for (final name in names.where((s) => s != 'state'))
              name: result[name],
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
  Future<void> commit(HabitState next, {required int expectedRevision}) async {
    next.validate();
    final done = Completer<void>(),
        tx = transaction('readwrite'),
        request = tx.objectStore('state').get('snapshot'.toJS);
    Object? failure;
    tx.oncomplete = ((web.Event _) => done.complete()).toJS;
    tx.onabort = ((web.Event _) => done.completeError(
      failure ?? StateError('Storage quota/transaction failure; preserved'),
    )).toJS;
    request.onsuccess = ((web.Event _) {
      try {
        final raw = request.result.dartify(),
            revision = raw == null
                ? 0
                : (jsonDecode(raw as String) as Map)['revision'];
        if (revision != expectedRevision ||
            next.revision != expectedRevision + 1)
          throw StateError('Another tab changed data; reload');
        final json = next.toJson();
        for (final name in names.where((s) => s != 'state')) {
          final store = tx.objectStore(name);
          store.clear();
          for (final value in json[name] as List) {
            store.put(jsonEncode(value).toJS, (value['id'] as String).toJS);
          }
          json.remove(name);
        }
        tx.objectStore('state').put(jsonEncode(json).toJS, 'snapshot'.toJS);
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
