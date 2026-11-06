import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/platform/store_native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'store_test.dart' show fixture;

Map<String, dynamic> copy(String text) => {
  'url': 'https://public.org/article',
  'title': 'Article',
  'savedAt': '2026-11-02T08:00:00.000Z',
  'blocks': [
    {'k': 'p', 't': text},
  ],
};

void main() {
  late Directory dir;
  late String path;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('save-v2-');
    path = '${dir.path}${Platform.pathSeparator}v2.sqlite';
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('a schema 1 database migrates to current and keeps every row', () async {
    var store = await NativeBookmarkStore.open(path);
    await store.write(
      upserts: [
        fixture(1),
        fixture(2, tags: ['kept']),
      ],
      settings: {
        'collections': [
          {'id': 'reading', 'name': 'Reading', 'parentId': null, 'position': 0},
        ],
        'preferences': {
          'bookmarkOrder': ['bookmark-2', 'bookmark-1'],
        },
      },
    );
    await store.close();
    // Turn it back into what version 1 wrote.
    final db = sqlite3.open(path);
    db.execute('DROP TABLE reading_copies');
    db.execute('DROP TABLE reading_trash');
    db.userVersion = 1;
    db.close();

    store = await NativeBookmarkStore.open(path);
    try {
      final raw = await store.read();
      expect((raw['bookmarks'] as List).map((b) => b['id']).toSet(), {
        'bookmark-1',
        'bookmark-2',
      });
      // The schema 1 order (in preferences) still sorts.
      expect(
        (await store.search({
          'sort': 'manual',
        }))['bookmarks'].map((b) => b['id']).toList(),
        ['bookmark-2', 'bookmark-1'],
      );
      await store.putReadingCopies({'bookmark-1': copy('Kept offline')});
      expect(await store.integrity(), 'ok');
    } finally {
      await store.close();
    }
    final check = sqlite3.open(path);
    try {
      expect(check.userVersion, schemaVersion);
      expect(
        check.select('SELECT count(*) AS n FROM reading_copies').first['n'],
        1,
      );
    } finally {
      check.close();
    }
  });

  test(
    'reading copies: stored apart, all-or-nothing, deleted with the link',
    () async {
      final store = await NativeBookmarkStore.open(path);
      try {
        await store.write(upserts: [fixture(1), fixture(2)], settings: {});
        await store.putReadingCopies({
          'bookmark-1': copy('One'),
          'bookmark-2': copy('Two'),
        });
        expect((await store.readingCopy('bookmark-1'))!['blocks'], [
          {'k': 'p', 't': 'One'},
        ]);
        expect(await store.readingIndex(), {
          'bookmark-1': '2026-11-02T08:00:00.000Z',
          'bookmark-2': '2026-11-02T08:00:00.000Z',
        });
        // Bookmark rows never carry the copy.
        final rows = (await store.read())['bookmarks'] as List;
        expect(rows.every((b) => !(b as Map).containsKey('blocks')), isTrue);
        // A copy for a missing link fails the whole write.
        await expectLater(
          store.putReadingCopies({
            'bookmark-1': copy('Changed'),
            'missing': copy('Orphan'),
          }),
          throwsStateError,
        );
        expect(
          ((await store.readingCopy('bookmark-1'))!['blocks'] as List)
              .single['t'],
          'One',
        );
        await expectLater(
          store.putReadingCopies({'bookmark-1': copy('x' * 2000001)}),
          throwsFormatException,
        );
        // Deleting the link deletes its copy.
        await store.write(deletes: ['bookmark-2']);
        expect((await store.readingIndex()).keys, ['bookmark-1']);
        expect((await store.readingCopies()).keys, ['bookmark-1']);
        await store.deleteReadingCopy('bookmark-1');
        expect(await store.readingCopy('bookmark-1'), isNull);
        await store.putReadingCopies({'bookmark-1': copy('Again')});
        await store.clearReadingCopies();
        expect(await store.readingIndex(), isEmpty);
        // Replace clears copies with their links.
        await store.putReadingCopies({'bookmark-1': copy('Again')});
        await store.write(replace: true, upserts: [fixture(3)], settings: {});
        expect(await store.readingIndex(), isEmpty);
      } finally {
        await store.close();
      }
    },
  );

  test('schema 2 order and the broken-link filter run in SQL', () async {
    final store = await NativeBookmarkStore.open(path);
    try {
      final gone = {
        ...fixture(1),
        'linkCheck': {
          'status': 'gone',
          'checkedAt': '2026-11-02T08:00:00.000Z',
          'httpStatus': 404,
        },
      };
      final ok = {
        ...fixture(2),
        'linkCheck': {'status': 'ok', 'checkedAt': '2026-11-02T08:00:00.000Z'},
      };
      await store.write(
        upserts: [gone, ok, fixture(3)],
        settings: {
          'manualOrder': ['bookmark-3', 'bookmark-1', 'bookmark-2'],
          'preferences': {
            'bookmarkOrder': ['bookmark-2'],
          },
        },
      );
      expect(
        (await store.search({
          'sort': 'manual',
        }))['bookmarks'].map((b) => b['id']).toList(),
        ['bookmark-3', 'bookmark-1', 'bookmark-2'],
      );
      final broken = await store.search({'linkIssue': true});
      expect(broken['total'], 1);
      expect((broken['bookmarks'] as List).single['id'], 'bookmark-1');
    } finally {
      await store.close();
    }
  });
}
