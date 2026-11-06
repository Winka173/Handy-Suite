@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;
import 'package:handy_bookmark/platform/store_web.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

void main() {
  test(
    'IndexedDB v2 upgrades without changing links, state or article text',
    () async {
      final removed = Completer<void>();
      final remove = web.window.indexedDB.deleteDatabase(
        'handy-save-bookmarks',
      );
      remove.onsuccess = ((web.Event _) => removed.complete()).toJS;
      remove.onerror = ((web.Event _) => removed.completeError(
        StateError('Test database reset failed'),
      )).toJS;
      remove.onblocked = ((web.Event _) => removed.completeError(
        StateError('Test database still open'),
      )).toJS;
      await removed.future;
      final opened = Completer<web.IDBDatabase>();
      final request = web.window.indexedDB.open('handy-save-bookmarks', 2);
      request.onupgradeneeded = ((web.Event _) {
        final db = request.result as web.IDBDatabase;
        for (final name in ['bookmarks', 'thumbnails', 'reading']) {
          db.createObjectStore(
            name,
            web.IDBObjectStoreParameters(keyPath: 'id'.toJS),
          );
        }
        db.createObjectStore('state');
      }).toJS;
      request.onsuccess = ((web.Event _) => opened.complete(
        request.result as web.IDBDatabase,
      )).toJS;
      request.onerror = ((web.Event _) => opened.completeError(
        StateError('Legacy open failed'),
      )).toJS;
      final db = await opened.future;
      final row = Bookmark(
        id: 'legacy-v2',
        originalUrl: 'https://example.org/legacy',
        normalizedUrl: 'https://example.org/legacy',
        savedAt: '2026-11-05T00:00:00Z',
        updatedAt: '2026-11-05T00:00:00Z',
      ).toJson();
      final article = {
        'savedAt': '2026-11-05T00:00:00Z',
        'title': 'Dữ liệu cũ',
        'blocks': [
          {'k': 'p', 't': 'Không thay đổi qua nâng cấp.'},
        ],
      };
      final committed = Completer<void>();
      final tx = db.transaction(
        ['bookmarks'.toJS, 'state'.toJS, 'reading'.toJS].toJS,
        'readwrite',
      );
      tx.oncomplete = ((web.Event _) => committed.complete()).toJS;
      tx.onabort = ((web.Event _) => committed.completeError(
        StateError('Legacy write failed'),
      )).toJS;
      tx
          .objectStore('bookmarks')
          .put({'id': row['id'], 'payload': jsonEncode(row)}.jsify()!);
      tx
          .objectStore('state')
          .put(
            jsonEncode({
              'preferences': {'locale': 'vi'},
            }).toJS,
            'current'.toJS,
          );
      tx
          .objectStore('reading')
          .put(
            {
              'id': row['id'],
              'savedAt': article['savedAt'],
              'payload': jsonEncode(article),
            }.jsify()!,
          );
      await committed.future;
      db.close();
      final store = await BrowserBookmarkStore.open();
      try {
        expect((await store.read())['bookmarks'], [row]);
        expect(((await store.read())['state'] as Map)['preferences'], {
          'locale': 'vi',
        });
        expect(await store.readingCopy('legacy-v2'), article);
        await store.write(deletes: ['legacy-v2']);
        await store.write(upserts: [row]);
        expect(await store.readingCopy('legacy-v2'), article);
      } finally {
        await store.close();
      }
    },
  );

  test(
    'IndexedDB retains hidden copies across reopen and restores only matching URLs',
    () async {
      var store = await BrowserBookmarkStore.open();
      final row = Bookmark(
        id: 'reading-undo-browser',
        originalUrl: 'https://example.org/article',
        normalizedUrl: 'https://example.org/article',
        savedAt: '2026-11-05T00:00:00Z',
        updatedAt: '2026-11-05T00:00:00Z',
      ).toJson();
      final article = {
        'url': row['originalUrl'],
        'title': 'Bản đọc tiếng Việt',
        'savedAt': '2026-11-05T00:00:00Z',
        'blocks': [
          {'k': 'p', 't': 'Nội dung được giữ nguyên khi hoàn tác.'},
        ],
      };
      var stage = 'replace';
      try {
        await store.write(replace: true, upserts: [row], settings: {});
        stage = 'copy';
        await store.putReadingCopies({'reading-undo-browser': article});
        stage = 'delete';
        await store.write(deletes: ['reading-undo-browser']);
        stage = 'hidden reads';
        expect(await store.readingCopy('reading-undo-browser'), isNull);
        expect(await store.readingCopies(), isEmpty);
        await store.close();
        store = await BrowserBookmarkStore.open();
        stage = 'restore';
        await store.write(upserts: [row]);
        stage = 'restored reads';
        expect(await store.readingCopy('reading-undo-browser'), article);
        expect(await store.readingIndex(), contains('reading-undo-browser'));
        await store.write(deletes: ['reading-undo-browser']);
        await store.write(
          upserts: [
            {
              ...row,
              'originalUrl': 'https://example.org/another',
              'normalizedUrl': 'https://example.org/another',
            },
          ],
        );
        expect(await store.readingCopy('reading-undo-browser'), isNull);
      } catch (e) {
        fail('IndexedDB $stage: $e');
      } finally {
        await store.write(replace: true, settings: {});
        await store.close();
      }
    },
  );
}
