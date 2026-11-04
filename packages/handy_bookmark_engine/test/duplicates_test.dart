import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Bookmark link(
  String id,
  String url, {
  String saved = '2026-01-01T12:00:00Z',
  String? collectionId,
  List<String> tags = const [],
  String title = '',
  String note = '',
  bool favorite = false,
  bool archived = false,
  int opened = 0,
}) {
  final u = UrlTools.normalize(url);
  return Bookmark(
    id: id,
    originalUrl: url,
    normalizedUrl: u.normalizedUrl,
    canonicalUrl: u.canonicalUrl,
    platform: u.platform,
    contentType: u.contentType,
    title: title,
    sourceDomain: u.sourceDomain,
    collectionId: collectionId,
    tags: tags,
    note: note,
    isFavorite: favorite,
    isArchived: archived,
    openedCount: opened,
    savedAt: saved,
    updatedAt: saved,
  );
}

void main() {
  final library = SaveLibrary(
    collections: [SaveCollection(id: 'read', name: 'Read later')],
    bookmarks: [
      link(
        'a',
        'https://example.com/post?utm_source=x',
        saved: '2026-02-01T00:00:00Z',
        tags: ['go'],
        note: 'from Lan',
        opened: 2,
      ),
      link('other', 'https://example.org/'),
      link(
        'b',
        'https://example.com/post',
        saved: '2026-01-10T00:00:00Z',
        collectionId: 'read',
        title: 'The post',
        tags: ['go', 'later'],
        note: 'check prices',
        favorite: true,
        archived: true,
        opened: 1,
      ),
    ],
    manualOrder: ['other', 'b', 'a'],
  );

  test('the same page saved twice is one group, oldest first', () {
    final groups = duplicateGroups(library);
    expect(groups.map((g) => g.map((b) => b.id).toList()), [
      ['b', 'a'],
    ]);
  });

  test('merging keeps the chosen link and everything the others carry', () {
    final next = mergeBookmarks(library, 'a', [
      'b',
    ], now: '2026-11-04T00:00:00Z');
    expect(next.bookmarks.map((b) => b.id), ['a', 'other']);
    final a = next.bookmarks.first;
    expect(a.title, 'The post');
    expect(a.collectionId, 'read');
    expect(a.tags, ['go', 'later']);
    expect(a.note, 'from Lan\n\ncheck prices');
    expect(a.isFavorite, isTrue);
    expect(a.isArchived, isFalse);
    expect(a.openedCount, 3);
    expect(a.savedAt, startsWith('2026-01-10'));
    // The kept link takes the first copy's place in the person's order.
    expect(next.manualOrder, ['other', 'a']);
    expect(duplicateGroups(next), isEmpty);
    // It survives the library's own round trip.
    expect(SaveLibrary.fromJson(next.toJson()).bookmarks.first.note, a.note);
  });

  test('different pages never merge', () {
    expect(
      () =>
          mergeBookmarks(library, 'a', ['other'], now: '2026-11-04T00:00:00Z'),
      throwsFormatException,
    );
  });
}
