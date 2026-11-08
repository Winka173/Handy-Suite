import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:test/test.dart';

SaveCollection _c(String id, [String? parent]) =>
    SaveCollection(id: id, name: id, parentId: parent);

Bookmark _b(String id, String collection) => Bookmark(
  id: id,
  originalUrl: 'https://example.com/$id',
  normalizedUrl: 'https://example.com/$id',
  title: id,
  collectionId: collection,
  savedAt: '2026-11-09T00:00:00.000Z',
  updatedAt: '2026-11-09T00:00:00.000Z',
);

void main() {
  test('folders are one level: deeper ones become folders of the top '
      'collection, and every item stays where it was', () {
    final library = SaveLibrary(
      collections: [
        _c('trips'),
        _c('vietnam', 'trips'),
        _c('danang', 'vietnam'),
        _c('hoian', 'danang'),
        _c('recipes'),
      ],
      bookmarks: [_b('beach', 'danang'), _b('lanterns', 'hoian')],
    );
    final parent = {for (final c in library.collections) c.id: c.parentId};
    expect(parent, {
      'trips': null,
      'vietnam': 'trips',
      'danang': 'trips',
      'hoian': 'trips',
      'recipes': null,
    });
    expect(
      {for (final b in library.bookmarks) b.id: b.collectionId},
      {'beach': 'danang', 'lanterns': 'hoian'},
    );
  });

  test('a stored library with deep nesting reads back one level deep, and '
      'round-trips unchanged after that', () {
    final json = SaveLibrary(collections: [_c('a'), _c('b', 'a')]).toJson();
    (json['collections'] as List).add(_c('c', 'b').toJson());
    final read = SaveLibrary.fromJson(json);
    expect(read.collections.singleWhere((c) => c.id == 'c').parentId, 'a');
    final again = SaveLibrary.fromJson(read.toJson());
    expect(
      [for (final c in again.collections) (c.id, c.parentId)],
      [for (final c in read.collections) (c.id, c.parentId)],
    );
  });

  test('a broken tree is still refused, not hidden by the flattening', () {
    expect(
      () =>
          SaveLibrary(collections: [_c('x', 'y'), _c('y', 'x'), _c('z', 'x')]),
      throwsFormatException,
    );
  });
}
