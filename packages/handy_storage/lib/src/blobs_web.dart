import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;
import '../blobs.dart';

BlobRepository createBlobs(String namespace) => BrowserBlobs(namespace);

/// IndexedDB database `<namespace>-blobs` (separate from the document's own
/// database, so that one is never upgraded): bytes in `blobs`, their
/// SHA-256 in `sums`, both written in one transaction.
class BrowserBlobs implements BlobRepository {
  final String namespace;
  BrowserBlobs(this.namespace);

  Future<web.IDBDatabase> _database() {
    final done = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open('$namespace-blobs', 1);
    request.onupgradeneeded = ((web.Event e) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains('blobs')) db.createObjectStore('blobs');
      if (!db.objectStoreNames.contains('sums')) db.createObjectStore('sums');
    }).toJS;
    request.onsuccess = ((web.Event e) {
      if (!done.isCompleted) done.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event e) {
      if (!done.isCompleted)
        done.completeError(StateError('Browser storage unavailable'));
    }).toJS;
    return done.future;
  }

  Future<T> _run<T>(
    String mode,
    T Function() result,
    void Function(web.IDBObjectStore blobs, web.IDBObjectStore sums) work,
  ) async {
    final db = await _database(), done = Completer<T>();
    final tx = db.transaction(['blobs'.toJS, 'sums'.toJS].toJS, mode);
    tx.oncomplete = ((web.Event e) {
      if (!done.isCompleted) done.complete(result());
    }).toJS;
    void fail(web.Event e) {
      if (!done.isCompleted)
        done.completeError(
          StateError('Browser storage failed or is full. Export a backup.'),
        );
    }

    tx.onabort = fail.toJS;
    tx.onerror = fail.toJS;
    work(tx.objectStore('blobs'), tx.objectStore('sums'));
    return done.future;
  }

  @override
  Future<Uint8List?> read(String id) async {
    checkBlobId(id);
    JSAny? bytes, sum;
    await _run<void>('readonly', () {}, (blobs, sums) {
      final a = blobs.get(id.toJS), b = sums.get(id.toJS);
      a.onsuccess = ((web.Event e) => bytes = a.result).toJS;
      b.onsuccess = ((web.Event e) => sum = b.result).toJS;
    });
    if (bytes == null) return null;
    final data = (bytes as JSUint8Array).toDart;
    if (sum == null ||
        (sum as JSString).toDart != sha256.convert(data).toString())
      throw const FormatException('Blob checksum mismatch');
    return data;
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    checkBlobId(id);
    if (bytes.length > blobMaxBytes)
      throw const FormatException('File too large to keep');
    await _run<void>('readwrite', () {}, (blobs, sums) {
      blobs.put(Uint8List.fromList(bytes).toJS, id.toJS);
      sums.put(sha256.convert(bytes).toString().toJS, id.toJS);
    });
    if ((await read(id))?.length != bytes.length)
      throw StateError('Browser storage write verification failed');
  }

  @override
  Future<void> delete(String id) async {
    checkBlobId(id);
    await _run<void>('readwrite', () {}, (blobs, sums) {
      blobs.delete(id.toJS);
      sums.delete(id.toJS);
    });
  }

  @override
  Future<Set<String>> ids() async {
    final result = <String>{};
    await _run<void>('readonly', () {}, (blobs, sums) {
      final r = blobs.getAllKeys();
      r.onsuccess = ((web.Event e) {
        for (final k in (r.result as JSArray<JSAny?>).toDart) {
          if (k.isA<JSString>()) result.add((k as JSString).toDart);
        }
      }).toJS;
    });
    return result;
  }
}
