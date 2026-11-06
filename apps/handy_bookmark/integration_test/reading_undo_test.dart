import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_bookmark/platform/store_native.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native v2 upgrade and atomic reading Undo across process connections',
    (tester) async {
      await tester.runAsync(() async {
        // Dedicated disposable QA directory, never the production database.
        final directory = await Directory.systemTemp.createTemp(
          'bookmark-retention-qa-',
        );
        final path = '${directory.path}/reading-undo.sqlite';
        var store = await NativeBookmarkStore.open(path);
        try {
          final row = Bookmark(
            id: 'native-qa',
            originalUrl: 'https://example.org/native',
            normalizedUrl: 'https://example.org/native',
            savedAt: '2026-11-05T00:00:00Z',
            updatedAt: '2026-11-05T00:00:00Z',
          ).toJson();
          final article = {
            'title': 'Bản đọc cũ',
            'url': row['originalUrl'],
            'savedAt': '2026-11-05T00:00:00Z',
            'blocks': [
              {'k': 'p', 't': 'Giữ nội dung tiếng Việt sau khi hoàn tác.'},
            ],
          };
          await store.write(upserts: [row], settings: {});
          await store.putReadingCopies({'native-qa': article});
          await store.close();
          final legacy = sqlite3.open(path);
          legacy.execute('DROP TABLE reading_trash');
          legacy.userVersion = 2;
          legacy.close();
          store = await NativeBookmarkStore.open(path);
          expect(await store.readingCopy('native-qa'), article);
          await store.write(deletes: ['native-qa']);
          expect(await store.readingCopy('native-qa'), isNull);
          expect(await store.readingCopies(), isEmpty);
          await store.close();
          store = await NativeBookmarkStore.open(path);
          await store.write(upserts: [row]);
          expect(await store.readingCopy('native-qa'), article);
          expect(await store.integrity(), 'ok');
        } finally {
          await store.close();
          await directory.delete(recursive: true);
        }
      });
    },
  );
}
