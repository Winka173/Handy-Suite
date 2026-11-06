@TestOn('browser')
library;

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:handy_bookmark/platform/store.dart';
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

void main() {
  test('IndexedDB 4: Trash keeps the copy, restore brings it back, purge drops '
      'it, across reopen', () async {
    var store = await BrowserBookmarkStore.open();
    final article = {
      'url': 'https://example.org/a',
      'title': 'Giữ khi ở Thùng rác',
      'savedAt': '2026-11-05T00:00:00Z',
      'blocks': [
        {'k': 'p', 't': 'Bản đọc đi theo mục vào Thùng rác.'},
      ],
    };
    try {
      await store.write(
        replace: true,
        upserts: [link('a'), link('b')],
        settings: {},
      );
      await store.putReadingCopies({'a': article});
      final at = DateTime.now().toUtc().toIso8601String();
      await store.write(
        deletes: ['a', 'b'],
        trashUpserts: [
          {...link('a'), 'deletedAt': at, 'rev': 1},
          {...link('b'), 'deletedAt': at, 'rev': 1},
        ],
      );
      expect(await store.readingCopy('a'), isNull);
      await store.close();
      store = await BrowserBookmarkStore.open();
      final raw = await store.read();
      expect((raw['trash'] as List).map((b) => b['id']).toSet(), {'a', 'b'});
      expect(raw['bookmarks'], isEmpty);
      expect((await store.search({}))['total'], 0);
      await store.write(upserts: [link('a')], trashDeletes: ['a', 'b']);
      expect(await store.readingCopy('a'), article);
      final after = await store.read();
      expect(after.containsKey('trash'), isFalse);
      expect((after['bookmarks'] as List).single['id'], 'a');
    } finally {
      await store.close();
    }
  });

  test(
    'IndexedDB 4: pictures as raw bytes, stored once, reclaimed safely',
    () async {
      final store = await BrowserBookmarkStore.open();
      try {
        await store.write(replace: true, settings: {});
        final bytes = Uint8List.fromList(List.generate(5000, (i) => i % 251));
        final preview = Uint8List.fromList(List.generate(200, (i) => i % 7));
        final ref = {
          'id': sha256.convert(bytes).toString(),
          'mime': 'image/jpeg',
          'width': 800,
          'height': 600,
          'bytes': bytes.length,
        };
        await store.putMedia(ref, bytes, preview);
        await store.putMedia(ref, bytes, preview);
        expect(await store.mediaIndex(), {ref['id']: bytes.length});
        expect(await store.media(ref['id'] as String), bytes);
        expect(await store.media(ref['id'] as String, preview: true), preview);
        final item = Bookmark(
          id: 'img',
          kind: 'image',
          originalUrl: '',
          normalizedUrl: '',
          media: MediaRef.fromJson(ref),
          title: 'Ảnh chụp màn hình',
          savedAt: '2026-11-05T00:00:00Z',
          updatedAt: '2026-11-05T00:00:00Z',
        ).toJson();
        await store.write(upserts: [item]);
        expect(await store.collectMedia({}, grace: Duration.zero), 0);
        expect(
          ((await store.search({'kind': 'image'}))['bookmarks'] as List)
              .single['id'],
          'img',
        );
        expect(
          ((await store.search({'text': 'anh chup'}))['bookmarks'] as List)
              .single['id'],
          'img',
        );
        await store.write(deletes: ['img']);
        expect(await store.collectMedia({}), 0, reason: 'grace period');
        expect(await store.collectMedia({}, grace: Duration.zero), 1);
        expect(await store.mediaIndex(), isEmpty);
        expect(trashRetention.inDays, 30);
      } finally {
        await store.close();
      }
    },
  );
}
