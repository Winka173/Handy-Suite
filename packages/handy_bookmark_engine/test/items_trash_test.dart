import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

const t0 = '2026-11-01T00:00:00.000Z';
final hashA = 'a' * 64, hashB = 'b' * 64;

MediaRef pic(String id, {String mime = 'image/png'}) => MediaRef(
  id: id,
  mime: mime,
  width: 1080,
  height: 2400,
  bytes: 345678,
  name: 'Screenshot.png',
);

Bookmark link(String id, String url, {String? collectionId, MediaRef? media}) {
  final u = UrlTools.normalize(url);
  return Bookmark(
    id: id,
    originalUrl: url,
    normalizedUrl: u.normalizedUrl,
    canonicalUrl: u.canonicalUrl,
    platform: u.platform,
    contentType: u.contentType,
    sourceDomain: u.sourceDomain,
    title: 'Link $id',
    collectionId: collectionId,
    media: media,
    savedAt: t0,
    updatedAt: t0,
  );
}

Bookmark image(
  String id,
  MediaRef media, {
  String title = '',
  String? collectionId,
}) => Bookmark(
  id: id,
  kind: 'image',
  originalUrl: '',
  normalizedUrl: '',
  contentType: 'image',
  platform: 'image',
  media: media,
  title: title,
  collectionId: collectionId,
  savedAt: t0,
  updatedAt: t0,
);

void main() {
  group('items', () {
    test('an image item stands without an address; a link never does', () {
      final b = image('i1', pic(hashA), title: 'Bảng giá Phở Hà Nội');
      expect(b.isImage, isTrue);
      expect(b.hasUrl, isFalse);
      final back = Bookmark.fromJson(jsonDecode(jsonEncode(b.toJson())));
      expect(back.toJson(), b.toJson());
      expect(back.media, b.media);
      expect(
        () => Bookmark(
          id: 'x',
          originalUrl: '',
          normalizedUrl: '',
          savedAt: t0,
          updatedAt: t0,
        ),
        throwsFormatException,
      );
      expect(
        () => Bookmark(
          id: 'x',
          kind: 'image',
          originalUrl: '',
          normalizedUrl: '',
          savedAt: t0,
          updatedAt: t0,
        ),
        throwsFormatException,
        reason: 'an image item needs its picture',
      );
    });

    test('an image may keep the address it came from', () {
      final u = UrlTools.normalize(
        'https://shopee.vn/product/88/17?utm_source=x',
      );
      final b = Bookmark(
        id: 'i2',
        kind: 'image',
        media: pic(hashB, mime: 'image/jpeg'),
        originalUrl: u.originalUrl,
        normalizedUrl: u.normalizedUrl,
        canonicalUrl: u.canonicalUrl,
        savedAt: t0,
        updatedAt: t0,
      );
      expect(b.hasUrl, isTrue);
      expect(b.normalizedUrl, 'https://shopee.vn/product/88/17');
    });

    test('pictures are validated', () {
      expect(() => pic('not-a-hash'), throwsFormatException);
      expect(() => pic(hashA, mime: 'image/svg+xml'), throwsFormatException);
      expect(
        () => MediaRef(
          id: hashA,
          mime: 'image/png',
          width: 1,
          height: 1,
          bytes: MediaRef.maxBytes + 1,
        ),
        throwsFormatException,
      );
    });

    test('old items keep their exact JSON and libraries stay version 2', () {
      final old = link('a', 'https://example.com/a');
      expect(old.toJson().keys, isNot(contains('kind')));
      expect(old.toJson().keys, isNot(contains('rev')));
      final lib = SaveLibrary(bookmarks: [old]);
      expect(lib.toJson()['version'], 2);
      final withImage = SaveLibrary(bookmarks: [old, image('i', pic(hashA))]);
      expect(withImage.toJson()['version'], 3);
      expect(
        SaveLibrary.fromJson(withImage.toJson()).toJson(),
        withImage.toJson(),
      );
    });
  });

  group('Recently Deleted', () {
    final travel = SaveCollection(id: 'travel', name: 'Du lịch');
    SaveLibrary start() => SaveLibrary(
      collections: [travel],
      bookmarks: [
        link('a', 'https://a.example/', collectionId: 'travel'),
        link('b', 'https://b.example/'),
        image('i', pic(hashA), collectionId: 'travel'),
      ],
      manualOrder: ['b', 'a', 'i'],
    );

    test(
      'delete moves whole items to Trash; restore brings them back as they were',
      () {
        final lib = start();
        final deleted = moveToTrash(lib, [
          'a',
          'i',
        ], '2026-11-02T08:00:00.000Z');
        expect(deleted.bookmarks.map((b) => b.id), ['b']);
        expect(deleted.trash.map((b) => b.id), unorderedEquals(['a', 'i']));
        expect(deleted.manualOrder, ['b']);
        // Hidden from search, duplicates and portable lists.
        expect(searchBookmarks(deleted, SearchQuery()).map((b) => b.id), ['b']);
        final again = SaveLibrary.fromJson(
          jsonDecode(jsonEncode(deleted.toJson())),
        );
        expect(again.trash.length, 2);

        final restored = restoreFromTrash(deleted, [
          'a',
          'i',
        ], '2026-11-03T08:00:00.000Z');
        final a = restored.bookmarks.firstWhere((b) => b.id == 'a');
        expect(restored.trash, isEmpty);
        expect(a.deletedAt, isNull);
        expect(a.collectionId, 'travel');
        expect(a.title, 'Link a');
        expect(a.savedAt, t0);
        expect(a.rev, 2, reason: 'delete and restore are both changes');
        expect(
          restored.bookmarks.firstWhere((b) => b.id == 'i').media,
          pic(hashA),
        );
      },
    );

    test(
      'a deleted item whose collection is gone comes back to Not sorted',
      () {
        final deleted = moveToTrash(start(), ['a'], t0);
        final noTravel = deleted.copyWith(
          collections: [],
          bookmarks: [
            for (final b in deleted.bookmarks) b.copyWith(collectionId: null),
          ],
        );
        expect(noTravel.trash.single.collectionId, isNull);
        final back = restoreFromTrash(noTravel, ['a'], t0);
        expect(
          back.bookmarks.firstWhere((b) => b.id == 'a').collectionId,
          isNull,
        );
      },
    );

    test(
      'delete for good leaves a tombstone; the picture stays while another item uses it',
      () {
        var lib = start().copyWith(
          bookmarks: [
            ...start().bookmarks,
            link('c', 'https://c.example/', media: pic(hashA)),
          ],
        );
        lib = moveToTrash(lib, ['i'], t0);
        expect(mediaInUse(lib), {hashA}, reason: 'in Trash still counts');
        lib = purgeTrash(lib, ['i'], '2026-11-05T00:00:00.000Z');
        expect(lib.trash, isEmpty);
        expect(lib.tombstones.single.id, 'i');
        expect(mediaInUse(lib), {hashA}, reason: 'link c still uses it');
        lib = purgeTrash(moveToTrash(lib, ['c'], t0), ['c'], t0);
        expect(mediaInUse(lib), isEmpty);
        expect(lib.tombstones.map((t) => t.id), unorderedEquals(['i', 'c']));
      },
    );

    test('expiry is exact at 30 days, by UTC instant, and only at a check', () {
      final lib = moveToTrash(start(), ['a'], '2026-11-01T10:00:00.000Z');
      final item = lib.trash.single;
      expect(trashDaysLeft(item, DateTime.utc(2026, 11, 1, 10)), 30);
      expect(trashDaysLeft(item, DateTime.utc(2026, 11, 30, 10, 0, 1)), 1);
      expect(trashDaysLeft(item, DateTime.utc(2026, 12, 1, 10)), 0);
      // A clock moved back adds no days.
      expect(trashDaysLeft(item, DateTime.utc(2026, 10, 1)), 30);
      final justBefore = expireTrash(lib, DateTime.utc(2026, 12, 1, 9, 59, 59));
      expect(identical(justBefore, lib), isTrue);
      final at = expireTrash(lib, DateTime.utc(2026, 12, 1, 10));
      expect(at.trash, isEmpty);
      expect(at.tombstones.single.entity, 'bookmark');
      // A local time zone gives the same answer for the same instant.
      final local = DateTime.utc(2026, 12, 1, 10).toLocal();
      expect(expireTrash(lib, local).trash, isEmpty);
    });

    test(
      'a deleted item cannot sit in the live list, nor a live one in Trash',
      () {
        final a = link('a', 'https://a.example/');
        expect(
          () => SaveLibrary(bookmarks: [a.copyWith(deletedAt: t0)]),
          throwsFormatException,
        );
        expect(() => SaveLibrary(trash: [a]), throwsFormatException);
        expect(
          () => SaveLibrary(
            bookmarks: [a],
            trash: [a.copyWith(deletedAt: t0)],
          ),
          throwsFormatException,
        );
      },
    );
  });

  group('finding', () {
    final lib = SaveLibrary(
      bookmarks: [
        link(
          'a',
          'https://pho.example/ha-noi',
        ).copyWith(title: 'Phở Hà Nội ngon nhất'),
        image('i', pic(hashA), title: 'Thực đơn quán phở'),
      ],
    );

    test('All, Links or Images, and no accents needed', () {
      expect(searchBookmarks(lib, SearchQuery(text: 'pho')).length, 2);
      expect(
        searchBookmarks(lib, SearchQuery(text: 'pho ha noi')).single.id,
        'a',
      );
      expect(
        searchBookmarks(lib, SearchQuery(text: 'phở', kind: 'image')).single.id,
        'i',
      );
      expect(searchBookmarks(lib, SearchQuery(kind: 'link')).single.id, 'a');
      expect(foldSearch('Đà Nẵng'), 'da nang');
      expect(
        SearchQuery.fromJson(SearchQuery(kind: 'image').toJson()).kind,
        'image',
      );
    });

    test(
      'the same picture saved twice is a duplicate; different pictures are not',
      () {
        final twice = SaveLibrary(
          bookmarks: [
            image('i1', pic(hashA)),
            image('i2', pic(hashA)),
            image('i3', pic(hashB)),
          ],
        );
        expect(
          duplicateGroups(twice).single.map((b) => b.id),
          unorderedEquals(['i1', 'i2']),
        );
      },
    );

    test(
      'lists of addresses leave out pictures without one; the Handy payload keeps them',
      () {
        for (final format in [
          SaveFormat.txt,
          SaveFormat.markdown,
          SaveFormat.html,
        ]) {
          final bytes = SavePortable.export(lib, format);
          final text = utf8.decode(bytes);
          expect(text, contains('https://pho.example/ha-noi'));
          final back = SavePortable.preview(Uint8List.fromList(bytes), format);
          expect(
            back.library.bookmarks.map((b) => b.id),
            contains('i'),
            reason: '$format',
          );
        }
      },
    );
  });
}
