import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Bookmark link(String id, String url, {String? collection, String note = ''}) {
  final u = UrlTools.normalize(url);
  return Bookmark(
    id: id,
    originalUrl: u.originalUrl,
    normalizedUrl: u.normalizedUrl,
    canonicalUrl: u.canonicalUrl,
    platform: u.platform,
    contentType: u.contentType,
    sourceDomain: u.sourceDomain,
    title: 'Title $id',
    note: note,
    tags: const ['private-tag'],
    isFavorite: true,
    isRead: true,
    reminderAt: '2026-11-20T09:00:00Z',
    collectionId: collection,
    savedAt: '2026-11-0${id.length}T00:00:00Z',
    updatedAt: '2026-11-01T00:00:00Z',
  );
}

Uint8List page(SaveLibrary library, List<String> ids, {bool notes = false}) =>
    Uint8List.fromList(
      utf8.encode(
        sharedCollectionsPage(
          library,
          ids,
          notes: notes,
          pictures: {
            'a': SharedPicture(Uint8List.fromList([1, 2, 3]), 4, 3),
            'pic': SharedPicture(Uint8List.fromList([9, 8, 7, 6]), 40, 30),
          },
          vietnamese: true,
          now: DateTime(2026, 11, 9),
        ),
      ),
    );

void main() {
  final picture = Uint8List.fromList([5, 5, 5]);
  final library = SaveLibrary(
    collections: [
      SaveCollection(id: 'food', name: 'Món ngon'),
      SaveCollection(id: 'hn', name: 'Hà Nội', parentId: 'food'),
      SaveCollection(id: 'trip', name: 'Du lịch'),
      SaveCollection(id: 'work', name: 'Work'),
    ],
    bookmarks: [
      link(
        'a',
        'https://www.youtube.com/watch?v=pho',
        collection: 'food',
        note: 'call mum first',
      ),
      link('bb', 'https://maps.example/pho-thin', collection: 'hn'),
      link('ccc', 'https://trip.example/da-nang', collection: 'trip'),
      link('w', 'https://work.example/secret', collection: 'work'),
      Bookmark(
        id: 'pic',
        originalUrl: '',
        normalizedUrl: '',
        kind: 'image',
        collectionId: 'trip',
        media: MediaRef(
          id: sha256.convert(picture).toString(),
          mime: 'image/jpeg',
          width: 400,
          height: 300,
          bytes: picture.length,
        ),
        savedAt: '2026-11-05T00:00:00Z',
        updatedAt: '2026-11-05T00:00:00Z',
      ),
    ],
  );
  final now = DateTime.utc(2026, 11, 10, 8);

  test('the page reads in a browser and names every collection sent', () {
    final bytes = page(library, ['food', 'trip']);
    final html = utf8.decode(bytes);
    expect(isSharedCollections(bytes), isTrue);
    expect(html, contains('<h1>2 bộ sưu tập</h1>'));
    expect(html, contains('<h2>Món ngon</h2>'));
    expect(html, contains('<h3>Hà Nội</h3>'));
    expect(html, contains('<h2>Du lịch</h2>'));
    expect(html, contains('Thêm bộ sưu tập được gửi cho bạn'));
    // Nothing from the collection that was not chosen, nothing private.
    expect(html, isNot(contains('work.example')));
    expect(html, isNot(contains('call mum first')));
    expect(html, isNot(contains('private-tag')));
    final data = utf8.decode(
      base64Url.decode(
        RegExp(
          '${sharedCollectionsMarker}([A-Za-z0-9_=-]+)',
        ).firstMatch(html)!.group(1)!,
      ),
    );
    expect(data, isNot(contains('private-tag')));
    expect(data, isNot(contains('call mum first')));
    expect(data, isNot(contains('2026-11-20')));
  });

  test('notes travel only when asked', () {
    final html = utf8.decode(page(library, ['food'], notes: true));
    expect(html, contains('call mum first'));
  });

  test('Pro to Pro: folders arrive as folders', () {
    final got = readSharedCollections(
      page(library, ['food', 'trip']),
      current: SaveLibrary(),
      keepFolders: true,
      suffix: '(từ bạn)',
      now: now,
    );
    final l = got.preview.library;
    expect(l.collections.map((c) => c.name), ['Món ngon', 'Du lịch', 'Hà Nội']);
    expect(
      l.collections.firstWhere((c) => c.name == 'Hà Nội').parentId,
      l.collections.firstWhere((c) => c.name == 'Món ngon').id,
    );
    expect(got.flattened, isFalse);
    expect(got.folders, 1);
    expect(l.bookmarks, hasLength(4));
    for (final b in l.bookmarks) {
      expect(b.isRead, isFalse);
      expect(b.isFavorite, isFalse);
      expect(b.reminderAt, isNull);
      expect(b.tags, isEmpty);
    }
    // The picture item arrives with its picture; a link's picture is its
    // preview.
    final pic = l.bookmarks.firstWhere((b) => b.isImage);
    expect(pic.media!.width, 40);
    expect(got.preview.pictures[pic.media!.id]!.original, [9, 8, 7, 6]);
    final pho = l.bookmarks.firstWhere((b) => b.title == 'Title a');
    expect(got.thumbnails[pho.id], [1, 2, 3]);
    final merged = got.preview.commit(SaveLibrary());
    expect(merged.bookmarks, hasLength(4));
    expect(merged.collections, hasLength(3));
  });

  test('Pro to free: folders spread into their collection as tags', () {
    final got = readSharedCollections(
      page(library, ['food']),
      current: SaveLibrary(),
      keepFolders: false,
      suffix: '(từ bạn)',
      now: now,
    );
    final l = got.preview.library;
    expect(got.flattened, isTrue);
    expect(l.collections.map((c) => c.name), ['Món ngon']);
    final thin = l.bookmarks.firstWhere((b) => b.title == 'Title bb');
    expect(thin.collectionId, l.collections.single.id);
    expect(thin.tags, ['Hà Nội']);
    expect(l.bookmarks.firstWhere((b) => b.title == 'Title a').tags, isEmpty);
  });

  test('a name already used here arrives renamed; duplicates are counted', () {
    final mine = SaveLibrary(
      collections: [SaveCollection(id: 'mine', name: 'du lịch')],
      bookmarks: [
        link('zz', 'https://trip.example/da-nang', collection: 'mine'),
      ],
    );
    final got = readSharedCollections(
      page(library, ['trip']),
      current: mine,
      keepFolders: true,
      suffix: '(từ bạn)',
      now: now,
    );
    expect(got.names, ['Du lịch (từ bạn)']);
    expect(got.renamed, 1);
    expect(got.preview.duplicateCount, 1);
    final merged = got.preview.commit(mine);
    expect(merged.collections.map((c) => c.name), [
      'du lịch',
      'Du lịch (từ bạn)',
    ]);
    // The link already saved is not added twice; the picture is.
    expect(merged.bookmarks, hasLength(2));
  });

  test('a damaged or foreign file is refused whole', () {
    final html = utf8.decode(page(library, ['food']));
    final broken = html.replaceFirst(
      sharedCollectionsMarker,
      '${sharedCollectionsMarker}AAAA',
    );
    expect(
      () => readSharedCollections(
        Uint8List.fromList(utf8.encode(broken)),
        current: SaveLibrary(),
        keepFolders: true,
        suffix: 'x',
        now: now,
      ),
      throwsFormatException,
    );
    final plain = Uint8List.fromList(utf8.encode('<html>hello</html>'));
    expect(isSharedCollections(plain), isFalse);
    expect(
      () => readSharedCollections(
        plain,
        current: SaveLibrary(),
        keepFolders: true,
        suffix: 'x',
        now: now,
      ),
      throwsFormatException,
    );
  });
}
