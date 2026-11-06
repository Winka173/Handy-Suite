import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
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
  /// 3 adds deleted-copy retention; 4 adds Recently Deleted and owned
  /// pictures. Upgrades add stores and never rewrite existing records.
  static const _version = 4;
  static const _names = [
    'bookmarks',
    'state',
    'thumbnails',
    'reading',
    'readingTrash',
    'trash',
    'media',
  ];
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
    final request = web.window.indexedDB.open('handy-save-bookmarks', _version);
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
            'Browser database upgrade blocked. Close other Handy Bookmark tabs and try again.',
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
      throw StateError('Browser database is closed; reopen Handy Bookmark');
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
      _run(['bookmarks', 'state', 'trash'], 'readonly', (tx, result, guard) {
        var bookmarks = <Map<String, dynamic>>[];
        var trash = <Map<String, dynamic>>[];
        var state = <String, dynamic>{};
        void done() => result({
          'bookmarks': bookmarks,
          if (trash.isNotEmpty) 'trash': trash,
          'state': state,
        });
        final all = tx.objectStore('bookmarks').getAll();
        all.onsuccess = ((web.Event _) {
          guard(() {
            bookmarks = _records(all).map(_bookmark).toList();
            done();
          });
        }).toJS;
        final deleted = tx.objectStore('trash').getAll();
        deleted.onsuccess = ((web.Event _) {
          guard(() {
            trash = _records(deleted).map(_bookmark).toList();
            done();
          });
        }).toJS;
        final current = tx.objectStore('state').get('current'.toJS);
        current.onsuccess = ((web.Event _) {
          guard(() {
            final raw = current.result;
            if (raw != null)
              state = _object(jsonDecode((raw as JSString).toDart));
            done();
          });
        }).toJS;
      });

  @override
  Future<void> write({
    List<Map<String, dynamic>> upserts = const [],
    List<String> deletes = const [],
    Map<String, dynamic>? settings,
    bool replace = false,
    List<Map<String, dynamic>> trashUpserts = const [],
    List<String> trashDeletes = const [],
  }) async {
    // Validate/encode before opening a transaction; no async gap may make an
    // IndexedDB transaction inactive between its clear and subsequent puts.
    final deletedRows = <String, JSAny>{};
    final intoTrash = <String, int>{};
    for (final record in trashUpserts) {
      final item = Bookmark.fromJson(record);
      if (item.deletedAt == null)
        throw const FormatException('A Trash row needs its deletion time');
      deletedRows[item.id] = {
        'id': item.id,
        'payload': jsonEncode(record),
      }.jsify()!;
      intoTrash[item.id] = DateTime.parse(
        item.deletedAt!,
      ).add(trashRetention).millisecondsSinceEpoch;
    }
    final rows = <String, JSAny>{};
    final urls = <String, String>{};
    for (final record in upserts) {
      final bookmark = Bookmark.fromJson(record);
      rows[bookmark.id] = {
        'id': bookmark.id,
        'payload': jsonEncode(record),
      }.jsify()!;
      urls[bookmark.id] = bookmark.normalizedUrl;
    }
    final state = settings == null ? null : jsonEncode(settings);
    await _run<bool>(_names, 'readwrite', (tx, result, guard) {
      final bookmarks = tx.objectStore('bookmarks');
      final thumbnails = tx.objectStore('thumbnails');
      final reading = tx.objectStore('reading');
      final trash = tx.objectStore('readingTrash');
      final deleted = tx.objectStore('trash');
      final now = DateTime.now().millisecondsSinceEpoch;
      void upsert(String id) {
        bookmarks.put(rows[id]!);
        final retained = trash.get(id.toJS);
        retained.onsuccess = ((web.Event _) {
          guard(() {
            final raw = retained.result.dartify();
            if (raw is Map &&
                raw['url'] == urls[id] &&
                (raw['expiresAt'] as num) > now) {
              final existing = reading.get(id.toJS);
              existing.onsuccess = ((web.Event _) {
                guard(() {
                  if (existing.result == null)
                    reading.put(_object(raw['copy']).jsify()!);
                });
              }).toJS;
            }
            trash.delete(id.toJS);
          });
        }).toJS;
      }

      if (replace) {
        bookmarks.clear();
        thumbnails.clear();
        reading.clear();
        trash.clear();
        deleted.clear();
      }
      for (final row in deletedRows.values) {
        deleted.put(row);
      }
      for (final id in deletes) {
        final link = bookmarks.get(id.toJS);
        link.onsuccess = ((web.Event _) {
          guard(() {
            final original = link.result.dartify();
            final article = reading.get(id.toJS);
            article.onsuccess = ((web.Event _) {
              guard(() {
                final value = article.result.dartify();
                if (original is Map && value != null) {
                  final payload = _object(
                    jsonDecode(original['payload'] as String),
                  );
                  trash.put(
                    {
                      'id': id,
                      'url': payload['normalizedUrl'],
                      // Into Recently Deleted: as long as it can be
                      // restored; any other delete: the Undo window.
                      'expiresAt':
                          intoTrash[id] ??
                          now + readingUndoRetention.inMilliseconds,
                      'copy': value,
                    }.jsify()!,
                  );
                }
                bookmarks.delete(id.toJS);
                thumbnails.delete(id.toJS);
                reading.delete(id.toJS);
                if (rows.containsKey(id)) upsert(id);
              });
            }).toJS;
          });
        }).toJS;
      }
      for (final id in rows.keys) {
        if (!deletes.contains(id)) upsert(id);
      }
      // Leaving Trash. A restored item (also in [rows]) took its copy back
      // in upsert; one deleted for good loses it.
      for (final id in trashDeletes) {
        deleted.delete(id.toJS);
        if (!rows.containsKey(id)) trash.delete(id.toJS);
      }
      final expired = trash.openCursor();
      expired.onsuccess = ((web.Event _) {
        guard(() {
          final cursor = expired.result as web.IDBCursorWithValue?;
          if (cursor == null) return;
          final value = _object(cursor.value.dartify());
          if ((value['expiresAt'] as num) <= now) cursor.delete();
          cursor.continue_();
        });
      }).toJS;
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
      // Schema 2 keeps the order in the library; older states in preferences.
      final manualIds = state['manualOrder'] != null
          ? library.fullManualOrder()
          : [
              ...((state['preferences'] as Map?)?['bookmarkOrder'] as List? ??
                  []),
              ...library.fullManualOrder(),
            ];
      final order = <Object?, int>{};
      for (final id in manualIds) {
        order.putIfAbsent(id, () => order.length);
      }
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
  Future<Map<String, dynamic>?> readingCopy(String id) =>
      _run(['reading'], 'readonly', (tx, result, guard) {
        final request = tx.objectStore('reading').get(id.toJS);
        request.onsuccess = ((web.Event _) {
          guard(() {
            final raw = request.result;
            if (raw == null) {
              result(null);
              return;
            }
            final record = _object(raw.dartify());
            if (record['id'] != id)
              throw const FormatException('Invalid reading key');
            result(_object(jsonDecode(record['payload'] as String)));
          });
        }).toJS;
      });

  @override
  Future<void> putReadingCopies(
    Map<String, Map<String, dynamic>> copies,
  ) async {
    final rows = <String, JSAny>{};
    for (final e in copies.entries) {
      final payload = jsonEncode(e.value);
      if (utf8.encode(payload).length > maxReadingCopyBytes)
        throw const FormatException('Reading copy exceeds 2 MB');
      rows[e.key] = {
        'id': e.key,
        'savedAt': e.value['savedAt'],
        'payload': payload,
      }.jsify()!;
    }
    if (rows.isEmpty) return;
    await _run<bool>(['bookmarks', 'reading'], 'readwrite', (
      tx,
      result,
      guard,
    ) {
      // Every copy needs its bookmark; one missing aborts the whole write.
      final keys = tx.objectStore('bookmarks').getAllKeys();
      keys.onsuccess = ((web.Event _) {
        guard(() {
          final known = (keys.result.dartify() as List).toSet();
          for (final e in rows.entries) {
            if (!known.contains(e.key))
              throw const FormatException('Bookmark not found');
            tx.objectStore('reading').put(e.value);
          }
          result(true);
        });
      }).toJS;
    });
  }

  @override
  Future<void> deleteReadingCopy(String id) async {
    await _run<bool>(['reading'], 'readwrite', (tx, result, guard) {
      tx.objectStore('reading').delete(id.toJS);
      result(true);
    });
  }

  Future<List<Map<String, dynamic>>> _readingRecords() =>
      _run(['reading'], 'readonly', (tx, result, guard) {
        final request = tx.objectStore('reading').getAll();
        request.onsuccess = ((web.Event _) {
          guard(() => result(_records(request)));
        }).toJS;
      });

  @override
  Future<Map<String, String>> readingIndex() async => {
    for (final r in await _readingRecords())
      r['id'] as String: r['savedAt'] as String,
  };

  @override
  Future<Map<String, Map<String, dynamic>>> readingCopies() async => {
    for (final r in await _readingRecords())
      r['id'] as String: _object(jsonDecode(r['payload'] as String)),
  };

  @override
  Future<void> clearReadingCopies() async {
    await _run<bool>(['reading', 'readingTrash'], 'readwrite', (
      tx,
      result,
      guard,
    ) {
      tx.objectStore('reading').clear();
      tx.objectStore('readingTrash').clear();
      result(true);
    });
  }

  @override
  Future<void> putMedia(
    Map<String, dynamic> ref,
    Uint8List original,
    Uint8List preview,
  ) async {
    checkMedia(ref, original, preview);
    final id = ref['id'] as String;
    // Raw bytes, not base64: a large picture costs its size in quota.
    final record =
        {
              'id': id,
              'mime': ref['mime'],
              'bytes': original.length,
              'width': ref['width'],
              'height': ref['height'],
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            }.jsify()!
            as JSObject;
    record.setProperty('original'.toJS, original.toJS);
    record.setProperty('preview'.toJS, preview.toJS);
    await _run<bool>(['media'], 'readwrite', (tx, result, guard) {
      final store = tx.objectStore('media');
      final existing = store.getKey(id.toJS);
      existing.onsuccess = ((web.Event _) {
        guard(() {
          if (existing.result == null) store.put(record);
          result(true);
        });
      }).toJS;
    });
  }

  @override
  Future<Uint8List?> media(String id, {bool preview = false}) =>
      _run(['media'], 'readonly', (tx, result, guard) {
        final request = tx.objectStore('media').get(id.toJS);
        request.onsuccess = ((web.Event _) {
          guard(() {
            final raw = request.result;
            if (raw == null) return result(null);
            final data = (raw as JSObject).getProperty(
              (preview ? 'preview' : 'original').toJS,
            );
            result((data as JSUint8Array).toDart);
          });
        }).toJS;
      });

  @override
  Future<Map<String, int>> mediaIndex() =>
      _run(['media'], 'readonly', (tx, result, guard) {
        final out = <String, int>{};
        final cursor = tx.objectStore('media').openCursor();
        cursor.onsuccess = ((web.Event _) {
          guard(() {
            final c = cursor.result as web.IDBCursorWithValue?;
            if (c == null) return result(out);
            final v = c.value as JSObject;
            out[(v.getProperty('id'.toJS) as JSString).toDart] =
                (v.getProperty('bytes'.toJS) as JSNumber).toDartInt;
            c.continue_();
          });
        }).toJS;
      });

  @override
  Future<int> collectMedia(
    Set<String> keep, {
    Duration grace = mediaGrace,
  }) async {
    final snapshot = await read();
    final used = {
      ...keep,
      for (final b in [
        ...snapshot['bookmarks'] as List,
        ...snapshot['trash'] as List? ?? const [],
      ])
        if ((b as Map)['media'] != null) (b['media'] as Map)['id'] as String,
    };
    final before = DateTime.now().subtract(grace).millisecondsSinceEpoch;
    return _run<int>(['media'], 'readwrite', (tx, result, guard) {
      var removed = 0;
      final cursor = tx.objectStore('media').openCursor();
      cursor.onsuccess = ((web.Event _) {
        guard(() {
          final c = cursor.result as web.IDBCursorWithValue?;
          if (c == null) return result(removed);
          final v = c.value as JSObject;
          final id = (v.getProperty('id'.toJS) as JSString).toDart;
          final created =
              (v.getProperty('createdAt'.toJS) as JSNumber).toDartInt;
          if (!used.contains(id) && created < before) {
            c.delete();
            removed++;
          }
          c.continue_();
        });
      }).toJS;
    });
  }

  @override
  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      _database.close();
    }
  }
}
