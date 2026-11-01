import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Durable inbox populated only by an installed PWA's Web Share Target worker.
/// Draining never deletes entries; acknowledgment follows bookmark persistence.
class BrowserShareInbox {
  JSFunction? _listener;

  Future<web.IDBDatabase> _open() {
    final done = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open('handy-save-incoming', 1);
    request.onupgradeneeded = ((web.Event event) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains('shares'))
        db.createObjectStore(
          'shares',
          web.IDBObjectStoreParameters(keyPath: 'id'.toJS),
        );
    }).toJS;
    request.onsuccess = ((web.Event event) {
      final db = request.result as web.IDBDatabase;
      if (done.isCompleted) {
        db.close();
      } else {
        done.complete(db);
      }
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!done.isCompleted)
        done.completeError(StateError('Browser share inbox is unavailable'));
    }).toJS;
    request.onblocked = ((web.Event event) {
      if (!done.isCompleted)
        done.completeError(
          StateError('Close other tabs to open the share inbox'),
        );
    }).toJS;
    return done.future;
  }

  Future<List<Map<String, dynamic>>> _transaction({String? acknowledge}) async {
    final db = await _open(), done = Completer<List<Map<String, dynamic>>>();
    final tx = db.transaction(
      'shares'.toJS,
      acknowledge == null ? 'readonly' : 'readwrite',
    );
    final rows = <Map<String, dynamic>>[];
    tx.oncomplete = ((web.Event event) {
      if (!done.isCompleted) done.complete(rows);
    }).toJS;
    void fail() {
      if (!done.isCompleted)
        done.completeError(
          StateError(
            'Share inbox transaction failed; incoming shares were retained',
          ),
        );
    }

    tx.onerror = ((web.Event event) => fail()).toJS;
    tx.onabort = ((web.Event event) => fail()).toJS;
    final store = tx.objectStore('shares');
    if (acknowledge != null) {
      store.delete(acknowledge.toJS);
    } else {
      final request = store.getAll();
      request.onsuccess = ((web.Event event) {
        try {
          final result = (request.result as JSArray<JSAny?>).toDart;
          if (result.length > 100)
            throw const FormatException('Share inbox exceeds queue limit');
          for (final item in result) {
            final value = item.dartify();
            if (value is! Map)
              throw const FormatException('Invalid incoming share');
            final row = Map<String, dynamic>.from(value);
            if (row['id'] is! String ||
                !_validId(row['id'] as String) ||
                row['text'] is! String ||
                utf8.encode(row['text'] as String).length > 262144 ||
                row['title'] != null &&
                    (row['title'] is! String ||
                        (row['title'] as String).length > 8192) ||
                row['receivedAt'] is! String)
              throw const FormatException('Invalid incoming share');
            rows.add(row);
          }
          rows.sort(
            (a, b) => (a['receivedAt'] as String).compareTo(
              b['receivedAt'] as String,
            ),
          );
        } catch (error) {
          if (!done.isCompleted) done.completeError(error);
        }
      }).toJS;
    }
    try {
      return await done.future;
    } finally {
      db.close();
    }
  }

  static bool _validId(String id) => RegExp(
    r'^(?:[a-f0-9]{32}|[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12})$',
  ).hasMatch(id);
  Future<List<Map<String, dynamic>>> drain() => _transaction();
  Future<void> ack(String id) async {
    if (!_validId(id))
      throw const FormatException('Invalid incoming share identifier');
    await _transaction(acknowledge: id);
  }

  void listen(VoidCallback callback) {
    dispose();
    if (!web.window.isSecureContext) return;
    _listener = ((web.MessageEvent event) {
      final value = event.data.dartify();
      if (value is Map && value['type'] == 'handy-save-share') callback();
    }).toJS;
    web.window.navigator.serviceWorker.addEventListener('message', _listener);
  }

  void dispose() {
    if (_listener != null) {
      web.window.navigator.serviceWorker.removeEventListener(
        'message',
        _listener,
      );
      _listener = null;
    }
  }
}
