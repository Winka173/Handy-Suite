import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:web/web.dart' as web;

import 'store.dart';

Future<BookmarkStore> openStore() => BrowserBookmarkStore.open();
Future<void> preserveAndResetStore() async {
  final store = await BrowserBookmarkStore.open();
  try {
    final snapshot = await store.read();
    // Store a recovery snapshot before touching active records. Quota failures
    // refuse reset. The separate DB remains until an explicit browser data clear.
    final ready = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open('handy-save-recovery', 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore('snapshots');
    }).toJS;
    request.onsuccess = ((web.Event _) => ready.complete(
      request.result as web.IDBDatabase,
    )).toJS;
    request.onerror = ((web.Event _) => ready.completeError(
      StateError('Recovery storage unavailable; reset refused'),
    )).toJS;
    request.onblocked = ((web.Event _) => ready.completeError(
      StateError('Recovery storage blocked; reset refused'),
    )).toJS;
    final recovery = await ready.future;
    try {
      final done = Completer<void>(),
          tx = recovery.transaction('snapshots'.toJS, 'readwrite');
      tx.oncomplete = ((web.Event _) => done.complete()).toJS;
      tx.onabort = ((web.Event _) => done.completeError(
        StateError('Recovery write aborted; reset refused'),
      )).toJS;
      tx
          .objectStore('snapshots')
          .put(
            jsonEncode(snapshot).toJS,
            DateTime.now().toUtc().toIso8601String().toJS,
          );
      await done.future;
    } finally {
      recovery.close();
    }
    await store.write(
      replace: true,
      settings: SaveLibrary().toJson()..remove('bookmarks'),
    );
  } finally {
    await store.close();
  }
}

typedef _Guard = void Function(void Function());

/// IndexedDB records are independent; a library is never serialized into one
/// localStorage value. Browser quota/eviction still requires portable backups.
class BrowserBookmarkStore implements BookmarkStore {
  static const _names = ['bookmarks', 'state', 'thumbnails'];
  static const _cacheBudget = 20000000;
  final web.IDBDatabase _database;
  bool _closed = false;

  BrowserBookmarkStore._(this._database) {
    _database.onversionchange = ((web.Event _) {
      _closed = true;
      _database.close();
    }).toJS;
    _database.onclose = ((web.Event _) {
      _closed = true;
    }).toJS;
  }

  static Future<BrowserBookmarkStore> open() async {
    final done = Completer<BrowserBookmarkStore>();
    final request = web.window.indexedDB.open('handy-save-bookmarks', 1);
    request.onupgradeneeded = ((web.Event _) {
      if (done.isCompleted) {
        request.transaction?.abort();
        return;
      }
      final db = request.result as web.IDBDatabase;
      for (final name in _names) {
        if (!db.objectStoreNames.contains(name)) {
          if (name == 'state') {
            db.createObjectStore(name);
          } else {
            db.createObjectStore(
              name,
              web.IDBObjectStoreParameters(keyPath: 'id'.toJS),
            );
          }
        }
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (done.isCompleted) {
        db.close();
        return;
      }
      if (_names.any((name) => !db.objectStoreNames.contains(name))) {
        db.close();
        done.completeError(
          StateError(
            'Browser database schema is damaged; existing data was preserved',
          ),
        );
        return;
      }
      done.complete(BrowserBookmarkStore._(db));
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!done.isCompleted) {
        done.completeError(
          StateError(
            'Browser database could not open; existing data was preserved (${request.error?.name ?? 'unavailable'})',
          ),
        );
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!done.isCompleted) {
        done.completeError(
          StateError(
            'Browser database upgrade blocked. Close other Handy Save tabs and try again.',
          ),
        );
      }
    }).toJS;
    return done.future;
  }

  Future<T> _run<T>(
    List<String> stores,
    String mode,
    void Function(web.IDBTransaction, void Function(T), _Guard) action,
  ) async {
    if (_closed)
      throw StateError('Browser database is closed; reopen Handy Save');
    final done = Completer<T>();
    final tx = _database.transaction(
      stores.map((s) => s.toJS).toList().toJS,
      mode,
    );
    late T value;
    var assigned = false;
    Object? failure;
    void guard(void Function() callback) {
      try {
        callback();
      } catch (_) {
        // Do not expose malformed record contents or bookmark URLs in errors.
        failure = StateError(
          'Browser database contains invalid data or the operation failed; existing data was preserved',
        );
        try {
          tx.abort();
        } catch (_) {
          if (!done.isCompleted) done.completeError(failure!);
        }
      }
    }

    tx.oncomplete = ((web.Event _) {
      if (!done.isCompleted) {
        if (assigned && failure == null) {
          done.complete(value);
        } else {
          done.completeError(
            failure ?? StateError('Incomplete browser database operation'),
          );
        }
      }
    }).toJS;
    tx.onerror = ((web.Event _) {
      failure ??= StateError(
        'Browser storage failed or quota was exceeded; transaction changes were not saved',
      );
      // The default IndexedDB error action aborts the entire transaction.
    }).toJS;
    tx.onabort = ((web.Event _) {
      if (!done.isCompleted) {
        done.completeError(
          failure ??
              StateError(
                'Browser storage transaction aborted; existing data was preserved',
              ),
        );
      }
    }).toJS;
    guard(
      () => action(tx, (next) {
        value = next;
        assigned = true;
      }, guard),
    );
    return done.future;
  }

  static Map<String, dynamic> _object(dynamic value) {
    if (value is! Map) throw const FormatException('Expected stored object');
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> _records(web.IDBRequest request) {
    final raw = request.result.dartify();
    if (raw is! List) throw const FormatException('Expected stored records');
    return raw.map(_object).toList();
  }

  static Map<String, dynamic> _bookmark(Map<String, dynamic> record) {
    final result = _object(jsonDecode(record['payload'] as String));
    if (record['id'] != result['id'])
      throw const FormatException('Stored identifier mismatch');
    Bookmark.fromJson(result);
    return result;
  }

  @override
  Future<Map<String, dynamic>> read() =>
      _run(['bookmarks', 'state'], 'readonly', (tx, result, guard) {
        var bookmarks = <Map<String, dynamic>>[];
        var state = <String, dynamic>{};
        final all = tx.objectStore('bookmarks').getAll();
        all.onsuccess = ((web.Event _) {
          guard(() {
            bookmarks = _records(all).map(_bookmark).toList();
            result({'bookmarks': bookmarks, 'state': state});
          });
        }).toJS;
        final current = tx.objectStore('state').get('current'.toJS);
        current.onsuccess = ((web.Event _) {
          guard(() {
            final raw = current.result;
            if (raw != null)
              state = _object(jsonDecode((raw as JSString).toDart));
            result({'bookmarks': bookmarks, 'state': state});
          });
        }).toJS;
      });

  @override
  Future<void> write({
    List<Map<String, dynamic>> upserts = const [],
    List<String> deletes = const [],
    Map<String, dynamic>? settings,
    bool replace = false,
  }) async {
    // Validate/encode before opening a transaction; no async gap may make an
    // IndexedDB transaction inactive between its clear and subsequent puts.
    final rows = <JSAny>[];
    for (final record in upserts) {
      final bookmark = Bookmark.fromJson(record);
      rows.add({'id': bookmark.id, 'payload': jsonEncode(record)}.jsify()!);
    }
    final state = settings == null ? null : jsonEncode(settings);
    await _run<bool>(_names, 'readwrite', (tx, result, guard) {
      final bookmarks = tx.objectStore('bookmarks');
      final thumbnails = tx.objectStore('thumbnails');
      if (replace) {
        bookmarks.clear();
        thumbnails.clear();
      }
      for (final id in deletes) {
        bookmarks.delete(id.toJS);
        thumbnails.delete(id.toJS);
      }
      for (final row in rows) {
        bookmarks.put(row);
      }
      if (state != null)
        tx.objectStore('state').put(state.toJS, 'current'.toJS);
      result(true);
    });
  }

  @override
  Future<Map<String, dynamic>> search(
    Map<String, dynamic> query, {
    int offset = 0,
    int limit = 100,
  }) async {
    if (offset < 0 || limit < 1 || limit > 500)
      throw const FormatException('Invalid page');
    final snapshot = await read();
    final state = snapshot['state'] as Map<String, dynamic>;
    final library = SaveLibrary.fromJson({
      ...state,
      'bookmarks': snapshot['bookmarks'],
    });
    SmartCollection? smart;
    if (query['smartCollectionId'] != null) {
      for (final collection in library.smartCollections) {
        if (collection.id == query['smartCollectionId']) smart = collection;
      }
      if (smart == null)
        throw const FormatException('Smart collection not found');
    }
    var matches = searchBookmarks(
      library,
      SearchQuery.fromJson(query),
      smartCollection: smart,
    );
    if (query['inbox'] == true)
      matches = matches.where((b) => b.collectionId == null).toList();
    if (query['sort'] == 'opened') {
      matches.sort((a, b) {
        final order = (b.lastOpenedAt ?? '').compareTo(a.lastOpenedAt ?? '');
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    }
    if (query['sort'] == 'manual') {
      final manualIds =
          (state['preferences'] as Map?)?['bookmarkOrder'] as List? ??
          library.bookmarks.map((b) => b.id).toList();
      final order = {
        for (var i = 0; i < manualIds.length; i++) manualIds[i]: i,
      };
      matches.sort(
        (a, b) =>
            (order[a.id] ?? 2147483647).compareTo(order[b.id] ?? 2147483647),
      );
    }
    // Keep pinned records first without disturbing the selected secondary order.
    matches = [
      ...matches.where((b) => b.isPinned),
      ...matches.where((b) => !b.isPinned),
    ];
    return {
      'bookmarks': matches
          .skip(offset)
          .take(limit)
          .map((b) => b.toJson())
          .toList(),
      'total': matches.length,
    };
  }

  static Uint8List _thumbnailData(Map<String, dynamic> record) {
    final data = base64Decode(record['data'] as String);
    if (data.length > 1000000 ||
        data.length != record['bytes'] ||
        record['accessed'] is! int ||
        record['id'] is! String) {
      throw const FormatException('Invalid thumbnail record');
    }
    return data;
  }

  @override
  Future<Uint8List?> thumbnail(String id) =>
      _run(['thumbnails'], 'readwrite', (tx, result, guard) {
        final store = tx.objectStore('thumbnails');
        final request = store.get(id.toJS);
        request.onsuccess = ((web.Event _) {
          guard(() {
            final raw = request.result;
            if (raw == null) {
              result(null);
              return;
            }
            final record = _object(raw.dartify());
            if (record['id'] != id)
              throw const FormatException('Invalid thumbnail key');
            final bytes = _thumbnailData(record);
            record['accessed'] = DateTime.now().microsecondsSinceEpoch;
            store.put(record.jsify()!);
            result(bytes);
          });
        }).toJS;
      });

  @override
  Future<void> putThumbnail(String id, Uint8List bytes) async {
    if (bytes.length > 1000000)
      throw const FormatException('Thumbnail exceeds 1 MB');
    final encoded = base64Encode(bytes);
    await _run<bool>(['bookmarks', 'thumbnails'], 'readwrite', (
      tx,
      result,
      guard,
    ) {
      final existing = tx.objectStore('bookmarks').get(id.toJS);
      existing.onsuccess = ((web.Event _) {
        guard(() {
          if (existing.result == null)
            throw const FormatException('Bookmark not found');
          final store = tx.objectStore('thumbnails');
          final request = store.getAll();
          request.onsuccess = ((web.Event _) {
            guard(() {
              final records = _records(
                request,
              ).where((record) => record['id'] != id).toList();
              var total = encoded.length;
              for (final record in records) {
                _thumbnailData(record);
                total += (record['data'] as String).length;
              }
              records.sort(
                (a, b) =>
                    (a['accessed'] as int).compareTo(b['accessed'] as int),
              );
              for (final record in records) {
                if (total <= _cacheBudget) break;
                store.delete((record['id'] as String).toJS);
                total -= (record['data'] as String).length;
              }
              store.put(
                {
                  'id': id,
                  'data': encoded,
                  'bytes': bytes.length,
                  'accessed': DateTime.now().microsecondsSinceEpoch,
                }.jsify()!,
              );
              result(true);
            });
          }).toJS;
        });
      }).toJS;
    });
  }

  @override
  Future<void> clearThumbnails() async {
    await _run<bool>(['thumbnails'], 'readwrite', (tx, result, guard) {
      tx.objectStore('thumbnails').clear();
      result(true);
    });
  }

  @override
  Future<String> integrity() async {
    final snapshot = await read();
    SaveLibrary.fromJson({
      ...snapshot['state'] as Map<String, dynamic>,
      'bookmarks': snapshot['bookmarks'],
    });
    await _run<bool>(['thumbnails'], 'readonly', (tx, result, guard) {
      final request = tx.objectStore('thumbnails').getAll();
      request.onsuccess = ((web.Event _) {
        guard(() {
          var total = 0;
          for (final record in _records(request)) {
            _thumbnailData(record);
            total += (record['data'] as String).length;
          }
          if (total > _cacheBudget)
            throw const FormatException('Thumbnail budget exceeded');
          result(true);
        });
      }).toJS;
    });
    return 'ok';
  }

  @override
  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      _database.close();
    }
  }
}
