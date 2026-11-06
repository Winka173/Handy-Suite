import 'dart:typed_data';
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
    title: id == 'x' ? '<script>alert(1)</script>' : 'Title $id',
    note: note,
    tags: const ['private-tag'],
    collectionId: collection,
    savedAt: '2026-11-0${id.length}T00:00:00Z',
    updatedAt: '2026-11-01T00:00:00Z',
  );
}

void main() {
  final library = SaveLibrary(
    collections: [
      SaveCollection(id: 'food', name: 'Món ngon'),
      SaveCollection(id: 'hn', name: 'Hà Nội', parentId: 'food'),
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
      link('x', 'https://evil.example/?q="><b>', collection: 'food'),
      link('w', 'https://work.example/secret', collection: 'work'),
    ],
  );
  final now = DateTime(2026, 11, 6);

  test(
    'only this collection and its sub-collections leave; text is escaped',
    () {
      final page = collectionPage(library, 'food', now: now, vietnamese: true);
      expect(page, contains('<title>Món ngon</title>'));
      expect(page, contains('<h2>Hà Nội</h2>'));
      expect(page, contains('3 mục'));
      expect(page, isNot(contains('work.example')));
      expect(page, isNot(contains('private-tag')));
      expect(page, isNot(contains('<script>alert')));
      expect(page, contains('&lt;script&gt;'));
      expect(page, isNot(contains('"><b>')));
      expect(page, contains('rel="noopener noreferrer"'));
      expect(page, isNot(contains('http://')), reason: 'no external resources');
    },
  );

  test('notes stay out unless asked for', () {
    expect(
      collectionPage(library, 'food', now: now),
      isNot(contains('call mum')),
    );
    expect(
      collectionPage(library, 'food', now: now, notes: true),
      contains('call mum first'),
    );
  });

  test('pictures are embedded as data, never linked', () {
    final page = collectionPage(
      library,
      'food',
      now: now,
      pictures: {
        'a': Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
      },
    );
    expect(page, contains('src="data:image/jpeg;base64,/9j/2Q=="'));
  });

  test('an unknown collection is refused', () {
    expect(
      () => collectionPage(library, 'nope', now: now),
      throwsFormatException,
    );
  });
}
