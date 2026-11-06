import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/platform/store_native.dart';
import 'package:sqlite3/sqlite3.dart';

Map<String, dynamic> fixture(int index, {List<String> tags = const []}) => {
  'id': 'bookmark-$index',
  'originalUrl': 'https://public.org/article/$index',
  'normalizedUrl': 'https://public.org/article/$index',
  'canonicalUrl': null,
  'sourceDomain': 'public.org',
  'platform': 'website',
  'contentType': 'article',
  'collectionId': index.isEven ? 'reading' : null,
  'title': 'Article $index alpha',
  'description': 'Vietnamese Việt Nam reference',
  'note': 'Private note $index',
  'tags': tags,
  'isFavorite': false,
  'isArchived': false,
  'isRead': false,
  'isPinned': false,
  'savedAt': '2026-11-01T00:00:00.000Z',
  'updatedAt': '2026-11-01T00:00:00.000Z',
  'lastOpenedAt': null,
  'openedCount': 0,
};

void main() {
  test(
    'recovery preserves main database bytes before a new empty database is opened',
    () async {
      final dir = await Directory.systemTemp.createTemp('save-recovery-');
      final file = File('${dir.path}/broken.sqlite');
      final bytes = Uint8List.fromList(List.generate(128, (i) => i));
      await file.writeAsBytes(bytes, flush: true);
      final recovery = await preserveDatabaseFiles(file.path);
      expect(await file.exists(), false);
      expect(
        await File('${recovery.path}/snapshot.sqlite').readAsBytes(),
        bytes,
      );
      expect(
        await File('${recovery.path}/snapshot.sqlite.original').readAsBytes(),
        bytes,
      );
      final fresh = await NativeBookmarkStore.open(file.path);
      try {
        expect((await fresh.read())['bookmarks'], isEmpty);
        expect(await fresh.integrity(), 'ok');
      } finally {
        await fresh.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'manual order, collection-name search and last-opened range persist without changing content',
    () async {
      final dir = await Directory.systemTemp.createTemp('save-order-');
      final path = '${dir.path}/ordered.sqlite';
      final a = {
            ...fixture(1),
            'collectionId': 'learning',
            'lastOpenedAt': '2026-11-01T08:00:00.000Z',
          },
          b = {...fixture(2), 'collectionId': 'learning'};
      final store = await NativeBookmarkStore.open(path);
      final state = {
        'collections': [
          {
            'id': 'learning',
            'name': 'CollectionOnly',
            'parentId': null,
            'position': 0,
          },
        ],
        'preferences': {
          'bookmarkOrder': [b['id'], a['id']],
        },
      };
      try {
        await store.write(upserts: [a, b], settings: state);
        expect(
          (await store.search({
            'sort': 'manual',
          }))['bookmarks'].map((v) => v['id']).toList(),
          [b['id'], a['id']],
        );
        expect((await store.search({'text': 'CollectionOnly'}))['total'], 2);
        expect(
          (await store.search({
            'openedAfter': '2026-11-01T00:00:00.000Z',
            'openedBefore': '2026-11-02T00:00:00.000Z',
          }))['total'],
          1,
        );
      } finally {
        await store.close();
      }
      final reopened = await NativeBookmarkStore.open(path);
      try {
        expect(
          (await reopened.search({
            'sort': 'manual',
          }))['bookmarks'].map((v) => v['id']).toList(),
          [b['id'], a['id']],
        );
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );
  late Directory temporary;
  late String path;
  NativeBookmarkStore? store;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('handy-save-store-test-');
    path = '${temporary.path}${Platform.pathSeparator}bookmarks.sqlite';
  });
  tearDown(() async {
    await store?.close();
    store = null;
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test('native SQLite schema, indexes, FTS and integrity are real', () async {
    store = await NativeBookmarkStore.open(path);
    expect(await store!.integrity(), 'ok');
    final db = sqlite3.open(path);
    try {
      expect(db.userVersion, 4);
      final names = db
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => r['name'])
          .toSet();
      expect(
        names,
        containsAll([
          'bookmarks',
          'collections',
          'tags',
          'bookmark_tags',
          'settings',
          'thumbnails',
          'bookmark_search',
          'reading_copies',
          'reading_trash',
          'trash',
          'media',
        ]),
      );
      final indexes = db
          .select("PRAGMA index_list('bookmarks')")
          .map((r) => r['name'])
          .toSet();
      expect(
        indexes,
        containsAll([
          'idx_normalized_url',
          'idx_domain',
          'idx_saved_at',
          'idx_collection_id',
          'idx_favorite',
          'idx_read_state',
        ]),
      );
      expect(db.select('PRAGMA journal_mode').first.values.first, 'wal');
      expect(
        db.select('SELECT sqlite_version() AS version').first['version'],
        isA<String>(),
      );
    } finally {
      db.close();
    }
  });

  test(
    'CRUD tags and collection snapshot survive close and reopen exactly',
    () async {
      store = await NativeBookmarkStore.open(path);
      final first = fixture(0, tags: ['reading', 'Việt Nam']);
      final second = fixture(1, tags: ['reading']);
      final settings = {
        'locale': 'vi',
        'collections': [
          {'id': 'reading', 'parentId': null, 'position': 0, 'name': 'Đọc sau'},
        ],
        'smartCollections': [],
        'searchHistory': ['private search'],
      };
      await store!.write(upserts: [first, second], settings: settings);
      expect(
        (await store!.search({
          'tags': ['Việt Nam'],
        }))['total'],
        1,
      );
      final changed = {
        ...first,
        'title': 'Edited title',
        'tags': ['new tag'],
        'isFavorite': true,
        'isRead': true,
      };
      await store!.write(upserts: [changed], deletes: ['bookmark-1']);
      final expected = {
        'bookmarks': [changed],
        'state': settings,
      };
      expect(await store!.read(), expected);
      await store!.close();
      store = await NativeBookmarkStore.open(path);
      expect(await store!.read(), expected);
      expect(
        (await store!.search({'text': 'Edited', 'isFavorite': true}))['total'],
        1,
      );
      final db = sqlite3.open(path);
      try {
        expect(
          db.select('SELECT name FROM tags').map((r) => r['name']).toList(),
          ['new tag'],
        );
        expect(db.select('SELECT payload FROM collections').length, 1);
        expect(db.select('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        db.close();
      }
    },
  );

  test(
    'failed multi-row replace rolls back original payload and thumbnail bytes',
    () async {
      store = await NativeBookmarkStore.open(path);
      final original = fixture(0, tags: ['original']);
      final state = {'collections': [], 'theme': 'dark'};
      final pixels = Uint8List.fromList([1, 2, 3, 4]);
      await store!.write(upserts: [original], settings: state);
      await store!.putThumbnail('bookmark-0', pixels);
      await expectLater(
        store!.write(
          replace: true,
          upserts: [
            fixture(1),
            {...fixture(2), 'normalizedUrl': null},
          ],
          settings: {'theme': 'light'},
        ),
        throwsStateError,
      );
      expect(await store!.read(), {
        'bookmarks': [original],
        'state': state,
      });
      expect(await store!.thumbnail('bookmark-0'), pixels);
      final db = sqlite3.open(path);
      try {
        expect(
          db.select('SELECT payload FROM bookmarks').single['payload'],
          jsonEncode(original),
        );
        expect(
          db.select('SELECT tag FROM bookmark_tags').single['tag'],
          'original',
        );
      } finally {
        db.close();
      }
      expect(await store!.integrity(), 'ok');
    },
  );

  test(
    'malicious search and filters remain parameterized and cannot modify schema',
    () async {
      store = await NativeBookmarkStore.open(path);
      await store!.write(upserts: [fixture(0), fixture(1)]);
      for (final input in [
        "'; DROP TABLE bookmarks; --",
        '" OR 1=1 --',
        '* NEAR(a b)',
        '%_\\',
        'title:alpha',
        '"',
      ]) {
        await store!.search({
          'text': input,
          'sort': 'title; DROP TABLE tags',
          'platform': "x' OR 1=1 --",
        });
      }
      expect((await store!.search({}))['total'], 2);
      expect(await store!.integrity(), 'ok');
      await expectLater(store!.search({}, offset: -1), throwsStateError);
      await expectLater(store!.search({}, limit: 501), throwsStateError);
    },
  );

  test(
    'future schema version is refused without modifying original file bytes',
    () async {
      final db = sqlite3.open(path);
      db.userVersion = 99;
      db.execute('CREATE TABLE sentinel(payload TEXT)');
      db.execute('INSERT INTO sentinel VALUES(?)', ['Do not modify']);
      db.close();
      final original = await File(path).readAsBytes();
      await expectLater(NativeBookmarkStore.open(path), throwsStateError);
      expect(await File(path).readAsBytes(), original);
      final preserved = sqlite3.open(path);
      try {
        expect(preserved.userVersion, 99);
        expect(
          preserved.select('SELECT payload FROM sentinel').single['payload'],
          'Do not modify',
        );
      } finally {
        preserved.close();
      }
    },
  );

  test(
    'cache is bounded, reads refresh LRU, and deleting bookmark cascades',
    () async {
      store = await NativeBookmarkStore.open(path);
      await store!.write(upserts: List.generate(23, fixture));
      final bytes = Uint8List(1000000)..[0] = 7;
      for (var i = 0; i < 20; i++) {
        await store!.putThumbnail('bookmark-$i', bytes);
      }
      expect(
        await store!.thumbnail('bookmark-0'),
        bytes,
      ); // Refresh the oldest.
      await store!.putThumbnail('bookmark-20', bytes);
      expect(await store!.thumbnail('bookmark-1'), isNull);
      expect(await store!.thumbnail('bookmark-0'), bytes);
      await store!.write(
        upserts: [
          {...fixture(0), 'title': 'Still cached'},
        ],
      );
      expect(await store!.thumbnail('bookmark-0'), bytes);
      await store!.write(deletes: ['bookmark-0']);
      expect(await store!.thumbnail('bookmark-0'), isNull);
      final db = sqlite3.open(path);
      try {
        expect(
          db
              .select('SELECT sum(length(data)) AS n FROM thumbnails')
              .single['n'],
          lessThanOrEqualTo(20000000),
        );
        expect(db.select('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        db.close();
      }
      await expectLater(
        store!.putThumbnail('bookmark-22', Uint8List(1000001)),
        throwsFormatException,
      );
      await store!.clearThumbnails();
      expect(await store!.thumbnail('bookmark-2'), isNull);
    },
  );

  test(
    'worker exit fails pending request promptly with uncertain commit warning',
    () async {
      store = await NativeBookmarkStore.open(path);
      store!.worker.pause();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final pending = store!.read();
      final checked = expectLater(
        pending,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('may have committed'),
          ),
        ),
      );
      store!.worker.kill(priority: Isolate.immediate);
      await checked.timeout(const Duration(seconds: 2));
      expect(store!.closed, isTrue);
    },
  );

  test(
    'operation deadline invalidates connection and reopening reloads committed data',
    () async {
      store = await NativeBookmarkStore.open(
        path,
        operationTimeout: const Duration(milliseconds: 100),
      );
      await store!.write(upserts: [fixture(0)]);
      store!.worker.pause();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await expectLater(
        store!.write(upserts: [fixture(1)]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('reopen the database'),
          ),
        ),
      );
      expect(store!.closed, isTrue);
      await expectLater(store!.read(), throwsStateError);
      store = await NativeBookmarkStore.open(path);
      expect((await store!.read())['bookmarks'], [fixture(0)]);
      expect(await store!.integrity(), 'ok');
    },
  );

  test(
    'FTS mapping from older writes is rebuilt without losing bookmarks',
    () async {
      store = await NativeBookmarkStore.open(path);
      await store!.write(upserts: [fixture(0), fixture(1)]);
      await store!.close();
      final db = sqlite3.open(path);
      db.execute('DELETE FROM bookmark_search');
      db.execute(
        'INSERT INTO bookmark_search(rowid,id,content) VALUES(100,?,?)',
        ['bookmark-0', 'stale content'],
      );
      db.execute(
        'INSERT INTO bookmark_search(rowid,id,content) VALUES(101,?,?)',
        ['bookmark-1', 'stale content'],
      );
      db.close();
      store = await NativeBookmarkStore.open(path);
      expect((await store!.search({'text': 'alpha'}))['total'], 2);
      await store!.write(
        upserts: [
          {...fixture(0), 'title': 'Replacement unique'},
        ],
        deletes: ['bookmark-1'],
      );
      expect((await store!.search({'text': 'alpha'}))['total'], 0);
      expect((await store!.search({'text': 'Replacement'}))['total'], 1);
    },
  );

  test(
    'worker protocol failure completes pending request instead of hanging',
    () async {
      store = await NativeBookmarkStore.open(path);
      store!.port.send([]);
      await expectLater(
        store!.read().timeout(const Duration(seconds: 2)),
        throwsStateError,
      );
      expect(store!.closed, isTrue);
    },
  );

  test('recentlyOpened sort uses open history with stable page ties', () async {
    store = await NativeBookmarkStore.open(path);
    await store!.write(
      upserts: [
        {...fixture(0), 'lastOpenedAt': '2026-10-01T00:00:00.000Z'},
        {...fixture(1), 'lastOpenedAt': '2026-11-01T00:00:00.000Z'},
      ],
    );
    final result = await store!.search({'sort': 'recentlyOpened'});
    expect((result['bookmarks'] as List).first['id'], 'bookmark-1');
  });

  test(
    '50,000 native rows support indexed text search and bounded pagination',
    () async {
      store = await NativeBookmarkStore.open(
        path,
        operationTimeout: const Duration(minutes: 2),
      );
      await store!.write(
        upserts: List.generate(
          50000,
          (i) => fixture(i, tags: [i % 10 == 0 ? 'special' : 'ordinary']),
        ),
      );
      final page = await store!.search(
        {
          'text': 'alpha',
          'tags': ['special'],
        },
        offset: 100,
        limit: 37,
      );
      expect(page['total'], 5000);
      expect(page['bookmarks'], hasLength(37));
      final next = await store!.search(
        {
          'text': 'alpha',
          'tags': ['special'],
        },
        offset: 137,
        limit: 37,
      );
      expect(
        (page['bookmarks'] as List)
            .map((b) => b['id'])
            .toSet()
            .intersection(
              (next['bookmarks'] as List).map((b) => b['id']).toSet(),
            ),
        isEmpty,
      );
      expect(await store!.integrity(), 'ok');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
