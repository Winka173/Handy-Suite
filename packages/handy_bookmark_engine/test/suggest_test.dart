import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Bookmark _b(String id, String url, String title, {String? col}) {
  final u = UrlTools.normalize(url);
  return Bookmark(
    id: id,
    originalUrl: u.originalUrl,
    normalizedUrl: u.normalizedUrl,
    platform: u.platform,
    contentType: u.contentType,
    sourceDomain: u.sourceDomain,
    title: title,
    collectionId: col,
    savedAt: '2026-11-14T10:00:00Z',
    updatedAt: '2026-11-14T10:00:00Z',
  );
}

void main() {
  SaveLibrary lib(List<Bookmark> items) => SaveLibrary(
    collections: [
      SaveCollection(id: 'food', name: 'Ăn uống', position: 0),
      SaveCollection(id: 'trip', name: 'Du lịch', position: 1),
      SaveCollection(id: 'pho', name: 'Phở ngon', position: 2),
      SaveCollection(id: 'work', name: 'Công việc', position: 3),
    ],
    bookmarks: items,
  );

  test('a site already filed somewhere goes there first', () {
    final fresh = _b('n', 'https://www.foody.vn/ha-noi/x', 'Quán mới');
    final l = lib([
      _b('1', 'https://www.foody.vn/a', 'A', col: 'trip'),
      _b('2', 'https://vnexpress.net/b', 'B', col: 'work'),
      _b('3', 'https://vnexpress.net/c', 'C', col: 'work'),
      fresh,
    ]);
    expect(suggestCollections(l, fresh).first.id, 'trip');
  });

  test('a word of the name in the title, marks or not, comes next', () {
    final fresh = _b('n', 'https://example.com/x', 'Pho ga Ha Noi');
    final l = lib([
      _b('1', 'https://a.com/1', 'x', col: 'work'),
      _b('2', 'https://b.com/2', 'y', col: 'work'),
      fresh,
    ]);
    expect(suggestCollections(l, fresh).first.id, 'pho');
  });

  test('short words never match: "Hội An" is not "Ăn uống"', () {
    final fresh = _b('n', 'https://example.com/x', 'Hội An 3 ngày');
    final l = lib([_b('1', 'https://a.com/1', 'x', col: 'work'), fresh]);
    final ids = suggestCollections(l, fresh).map((c) => c.id).toList();
    expect(ids.first, 'work'); // the most used, nothing else matched
    expect(ids, hasLength(4));
  });

  test('without any hint: the most used, then the person\'s order', () {
    final fresh = _b('n', 'https://example.com/x', 'Nothing alike');
    final l = lib([_b('1', 'https://a.com/1', 'x', col: 'pho'), fresh]);
    expect(suggestCollections(l, fresh, take: 3).map((c) => c.id), [
      'pho',
      'food',
      'trip',
    ]);
  });

  test('the save itself is never counted as a hint', () {
    final self = _b('n', 'https://www.foody.vn/x', 'x', col: 'work');
    final l = lib([self]);
    expect(suggestCollections(l, self).first.id, 'food');
  });
}
