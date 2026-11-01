import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;
import '../documents.dart';

DocumentRepository createDocuments(String namespace, int maxBytes) =>
    BrowserDocuments(namespace, maxBytes);

class BrowserDocuments implements RecoverableDocuments {
  final String namespace;
  final int maxBytes;
  BrowserDocuments(this.namespace, this.maxBytes);
  Future<web.IDBDatabase> _database() {
    final completed = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(namespace, 1);
    request.onupgradeneeded = ((web.Event e) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains('library'))
        db.createObjectStore('library');
    }).toJS;
    request.onsuccess = ((web.Event e) {
      if (!completed.isCompleted)
        completed.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event e) {
      if (!completed.isCompleted)
        completed.completeError(
          StateError('Browser database unavailable: ${request.error?.name}'),
        );
    }).toJS;
    request.onblocked = ((web.Event e) {
      if (!completed.isCompleted)
        completed.completeError(
          StateError('Close other tabs before upgrading local storage.'),
        );
    }).toJS;
    return completed.future;
  }

  Future<String?> _transaction(String? value) async {
    final db = await _database(), done = Completer<String?>();
    final tx = db.transaction(
      'library'.toJS,
      value == null ? 'readonly' : 'readwrite',
    );
    String? result;
    tx.oncomplete = ((web.Event e) {
      if (!done.isCompleted) done.complete(result);
    }).toJS;
    tx.onabort = ((web.Event e) {
      if (!done.isCompleted)
        done.completeError(
          StateError(
            'Browser storage transaction aborted; existing data was kept.',
          ),
        );
    }).toJS;
    tx.onerror = ((web.Event e) {
      if (!done.isCompleted)
        done.completeError(
          StateError(
            'Browser storage failed or quota exceeded. Export a backup.',
          ),
        );
    }).toJS;
    final store = tx.objectStore('library');
    if (value == null) {
      final request = store.get('current'.toJS);
      request.onsuccess = ((web.Event e) {
        final raw = request.result;
        result = raw == null ? null : (raw as JSString).toDart;
      }).toJS;
    } else {
      store.put(value.toJS, 'current'.toJS);
    }
    try {
      return await done.future;
    } finally {
      db.close();
    }
  }

  @override
  Future<String?> load() async {
    final text = await _transaction(null);
    if (text != null) {
      if (utf8.encode(text).length > maxBytes)
        throw const FormatException('Browser library exceeds limit');
      jsonDecode(text);
    }
    return text;
  }

  @override
  Future<void> save(String text) async {
    if (utf8.encode(text).length > maxBytes)
      throw const FormatException('Browser library exceeds limit');
    jsonDecode(text);
    await _transaction(text);
  }

  void _id(String id) {
    if (!RegExp(r'^[0-9]{12,20}-[a-f0-9]{16}$').hasMatch(id))
      throw const FormatException('Invalid preserved library ID');
  }

  Future<T> _recoveryTransaction<T>(
    bool write,
    void Function(web.IDBObjectStore store, void Function(T) result) action,
  ) async {
    final db = await _database(), done = Completer<T>();
    final tx = db.transaction('library'.toJS, write ? 'readwrite' : 'readonly');
    late T value;
    var hasValue = false;
    tx.oncomplete = ((web.Event _) {
      if (!done.isCompleted) {
        if (hasValue) {
          done.complete(value);
        } else {
          done.completeError(StateError('Incomplete recovery transaction'));
        }
      }
    }).toJS;
    tx.onabort = ((web.Event _) {
      if (!done.isCompleted)
        done.completeError(
          StateError('Recovery canceled; existing data was preserved'),
        );
    }).toJS;
    tx.onerror = ((web.Event _) {
      if (!done.isCompleted)
        done.completeError(
          StateError(
            'Recovery failed or browser quota exceeded; existing data was preserved',
          ),
        );
    }).toJS;
    try {
      action(tx.objectStore('library'), (next) {
        value = next;
        hasValue = true;
      });
      return await done.future;
    } finally {
      db.close();
    }
  }

  @override
  Future<List<PreservedDocuments>> preserved() =>
      _recoveryTransaction(false, (store, result) {
        final request = store.getAllKeys();
        request.onsuccess = ((web.Event _) {
          final keys = (request.result as JSArray).toDart;
          final copies = <PreservedDocuments>[];
          for (final key in keys) {
            final text = (key as JSString).toDart;
            if (!text.startsWith('recovery:')) continue;
            final id = text.substring(9);
            if (!RegExp(r'^[0-9]{12,20}-[a-f0-9]{16}$').hasMatch(id)) continue;
            copies.add(
              PreservedDocuments(
                id,
                DateTime.fromMicrosecondsSinceEpoch(
                  int.parse(id.split('-').first),
                  isUtc: true,
                ),
              ),
            );
          }
          copies.sort((a, b) => b.id.compareTo(a.id));
          result(copies);
        }).toJS;
      });

  @override
  Future<PreservedDocuments> preserveAndReset() {
    final now = DateTime.now().toUtc();
    final nonce = List.generate(
      8,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final id = '${now.microsecondsSinceEpoch}-$nonce';
    return _recoveryTransaction(true, (store, result) {
      final request = store.get('current'.toJS);
      request.onsuccess = ((web.Event _) {
        final raw = request.result;
        if (raw == null) {
          request.transaction?.abort();
          return;
        }
        store.put(raw, 'recovery:$id'.toJS);
        store.delete('current'.toJS);
        result(PreservedDocuments(id, now));
      }).toJS;
    });
  }

  @override
  Future<Uint8List> exportPreserved(String id) async {
    _id(id);
    final raw = await _recoveryTransaction<String?>(false, (store, result) {
      final request = store.get('recovery:$id'.toJS);
      request.onsuccess = ((web.Event _) {
        result(
          request.result == null ? null : (request.result as JSString).toDart,
        );
      }).toJS;
    });
    if (raw == null) throw const FormatException('Preserved library not found');
    final bytes = utf8.encode(raw);
    if (bytes.length > 29000000)
      throw const FormatException(
        'Diagnostic export exceeds 29 MB; preserved data remains stored locally',
      );
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'handy-preserved-documents',
        'version': 1,
        'namespace': namespace,
        'id': id,
        'checksums': {'current.json': sha256.convert(bytes).toString()},
      }),
    );
    return Uint8List.fromList(
      ZipEncoder().encodeBytes(
        Archive()
          ..addFile(ArchiveFile('current.json', bytes.length, bytes))
          ..addFile(ArchiveFile('manifest.json', manifest.length, manifest)),
        level: 0,
      ),
    );
  }

  @override
  Future<void> undoReset(String id) async {
    _id(id);
    await _recoveryTransaction<bool>(true, (store, result) {
      final current = store.get('current'.toJS);
      current.onsuccess = ((web.Event _) {
        if (current.result != null) {
          current.transaction?.abort();
          return;
        }
        final old = store.get('recovery:$id'.toJS);
        old.onsuccess = ((web.Event _) {
          if (old.result == null) {
            old.transaction?.abort();
            return;
          }
          store.put(old.result, 'current'.toJS);
          store.delete('recovery:$id'.toJS);
          result(true);
        }).toJS;
      }).toJS;
    });
  }
}
