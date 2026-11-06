@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:handy_bookmark/platform/store_web.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Map<String, dynamic> link(String id) => Bookmark(
  id: id,
  originalUrl: 'https://example.org/$id',
  normalizedUrl: 'https://example.org/$id',
  title: 'Bài $id',
  savedAt: '2026-11-05T00:00:00Z',
  updatedAt: '2026-11-05T00:00:00Z',
).toJson();

Map<String, dynamic> article(String id, String text) => {
  'url': 'https://example.org/$id',
  'title': 'Bài $id',
  'savedAt': '2026-11-05T00:00:00Z',
  'blocks': [
    {'k': 'p', 't': text},
  ],
};

void main() {
  test('IndexedDB: a Trash item\'s copy is in the backup set, can be stored '
      'by a restore, and comes back with the item', () async {
    var store = await BrowserBookmarkStore.open();
    try {
      await store.write(
        replace: true,
        upserts: [link('a'), link('b'), link('c')],
        settings: {},
      );
      await store.putReadingCopies({
        'a': article('a', 'Còn trong thư viện'),
        'b': article('b', 'Đang ở Thùng rác'),
        'c': article('c', 'Chỉ giữ để Hoàn tác'),
      });
      final at = DateTime.now().toUtc().toIso8601String();
      await store.write(
        deletes: ['b', 'c'],
        trashUpserts: [
          {...link('b'), 'deletedAt': at, 'rev': 1},
        ],
      );
      expect(
        (await store.readingCopies()).keys.toSet(),
        {'a', 'b'},
        reason: 'Trash copies go into backups; Undo-only ones do not',
      );

      // A fresh library restored from a backup: the item is in Trash and
      // its copy is stored beside it.
      await store.write(
        replace: true,
        settings: {},
        trashUpserts: [
          {...link('b'), 'deletedAt': at, 'rev': 1},
        ],
      );
      await store.putReadingCopies({'b': article('b', 'Từ bản sao lưu')});
      expect(await store.readingCopy('b'), isNull);
      expect(await store.readingIndex(), isEmpty);
      await expectLater(
        store.putReadingCopies({'nobody': article('x', 'x')}),
        throwsA(isA<StateError>()),
      );
      await store.close();
      store = await BrowserBookmarkStore.open();
      await store.write(upserts: [link('b')], trashDeletes: ['b']);
      expect(
        (await store.readingCopy('b'))!['blocks'][0]['t'],
        'Từ bản sao lưu',
      );
    } finally {
      await store.close();
    }
  });
}
