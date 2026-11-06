import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/platform/store_native.dart';
import 'package:handy_bookmark/view/library_view.dart';
import 'package:sqlite3/sqlite3.dart';
import 'controller_test.dart' show TestInbox;
import 'store_test.dart' show fixture;
import 'store_v2_test.dart' show copy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late NativeBookmarkStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bookmark-reading-undo-');
    store = await NativeBookmarkStore.open('${directory.path}/library.sqlite');
    await store.write(
      upserts: [
        fixture(1),
        {...fixture(2), 'collectionId': null},
      ],
      settings: {},
    );
    await store.putReadingCopies({
      'bookmark-1': copy('Bản đọc tiếng Việt — giữ nguyên.'),
      'bookmark-2': copy('Second article'),
    });
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'delete and Undo restore the exact offline copy and reading badge',
    () async {
      final c = SaveController(open: () async => store, shares: TestInbox());
      await c.initialize();
      expect(c.error, isNull);
      final view = LibraryView(c);
      try {
        await view.change((l) => l.copyWith(bookmarks: [l.bookmarks.last]));
        expect(await store.readingCopy('bookmark-1'), isNull);
        expect(c.readingIds, isNot(contains('bookmark-1')));
        expect(await view.undo(), isTrue);
        expect(
          await store.readingCopy('bookmark-1'),
          copy('Bản đọc tiếng Việt — giữ nguyên.'),
        );
        expect(c.readingIds, contains('bookmark-1'));
        expect(await store.integrity(), 'ok');
      } finally {
        view.dispose();
        c.store = null; // This fixture owns and awaits the worker's close.
        c.dispose();
      }
    },
  );

  test(
    'retained copy survives restart and is never exported while deleted',
    () async {
      await store.write(deletes: ['bookmark-1']);
      expect(await store.readingCopies(), isNot(contains('bookmark-1')));
      await store.close();
      store = await NativeBookmarkStore.open(
        '${directory.path}/library.sqlite',
      );
      await store.write(upserts: [fixture(1)]);
      expect(
        await store.readingCopy('bookmark-1'),
        copy('Bản đọc tiếng Việt — giữ nguyên.'),
      );
    },
  );

  test(
    'reusing a deleted ID for another URL does not restore the old article',
    () async {
      await store.write(deletes: ['bookmark-1']);
      await store.write(
        upserts: [
          {
            ...fixture(1),
            'originalUrl': 'https://different.example/new',
            'normalizedUrl': 'https://different.example/new',
          },
        ],
      );
      expect(await store.readingCopy('bookmark-1'), isNull);
    },
  );

  test(
    'v2 migration preserves active articles and adds retention without changing IDs',
    () async {
      await store.close();
      final db = sqlite3.open('${directory.path}/library.sqlite');
      db.execute('DROP TABLE reading_trash');
      db.userVersion = 2;
      db.close();
      store = await NativeBookmarkStore.open(
        '${directory.path}/library.sqlite',
      );
      expect(
        await store.readingCopy('bookmark-1'),
        copy('Bản đọc tiếng Việt — giữ nguyên.'),
      );
      expect((await store.read())['bookmarks'], hasLength(2));
      await store.write(deletes: ['bookmark-1']);
      await store.write(upserts: [fixture(1)]);
      expect(await store.readingCopy('bookmark-1'), isNotNull);
    },
  );

  test(
    'only expired deleted copies are pruned; active articles remain',
    () async {
      await store.write(deletes: ['bookmark-1']);
      await store.close();
      final db = sqlite3.open('${directory.path}/library.sqlite');
      db.execute('UPDATE reading_trash SET expires_at=0');
      db.close();
      store = await NativeBookmarkStore.open(
        '${directory.path}/library.sqlite',
      );
      await store.write(upserts: [fixture(1)]);
      expect(await store.readingCopy('bookmark-1'), isNull);
      expect(await store.readingCopy('bookmark-2'), copy('Second article'));
    },
  );

  test('a failed mutation cannot remove either link or article', () async {
    await expectLater(
      store.write(
        deletes: ['bookmark-1'],
        upserts: [
          {'id': 'invalid'},
        ],
      ),
      throwsA(isA<StateError>()),
    );
    expect((await store.read())['bookmarks'], hasLength(2));
    expect(
      await store.readingCopy('bookmark-1'),
      copy('Bản đọc tiếng Việt — giữ nguyên.'),
    );
  });

  test('explicit full replacement clears retained content', () async {
    await store.write(deletes: ['bookmark-1']);
    await store.write(replace: true, upserts: [fixture(1)], settings: {});
    expect(await store.readingCopy('bookmark-1'), isNull);
  });

  test(
    'clear copies rolls back both stores when retained-copy deletion fails',
    () async {
      await store.write(deletes: ['bookmark-1']);
      await store.close();
      final db = sqlite3.open('${directory.path}/library.sqlite');
      db.execute(
        "CREATE TRIGGER reject_clear BEFORE DELETE ON reading_trash BEGIN SELECT RAISE(ABORT,'QA storage refusal'); END",
      );
      db.close();
      store = await NativeBookmarkStore.open(
        '${directory.path}/library.sqlite',
      );
      await expectLater(store.clearReadingCopies(), throwsA(isA<StateError>()));
      expect(await store.readingCopy('bookmark-2'), copy('Second article'));
      await store.close();
      final resumed = sqlite3.open('${directory.path}/library.sqlite');
      resumed.execute('DROP TRIGGER reject_clear');
      resumed.close();
      store = await NativeBookmarkStore.open(
        '${directory.path}/library.sqlite',
      );
      await store.write(upserts: [fixture(1)]);
      expect(
        await store.readingCopy('bookmark-1'),
        copy('Bản đọc tiếng Việt — giữ nguyên.'),
      );
    },
  );
}
