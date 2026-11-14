import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/handy_bookmark_engine.dart';

Bookmark bookmark(
  String id,
  String url, {
  String? collectionId,
  List<String> tags = const [],
  String title = '',
  String note = '',
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
    savedAt: '2026-01-01T12:00:00Z',
    updatedAt: '2026-01-01T12:00:00Z',
    reminderAt: '2026-12-02T01:00:00Z',
  );
}

void main() {
  test(
    'YouTube short share and tracking watch share are identical canonical URLs',
    () {
      final short = UrlTools.normalize('https://youtu.be/dQw4w9WgXcQ');
      final watch = UrlTools.normalize(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&utm_source=test',
      );
      expect(short.canonicalUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(watch.canonicalUrl, short.canonicalUrl);
      expect(
        UrlTools.extract(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&utm_source=test',
        ).single.canonicalUrl,
        short.canonicalUrl,
      );
      expect(
        UrlTools.normalize('https://youtu.be/dQw4w9WgXc').canonicalUrl,
        'https://youtu.be/dQw4w9WgXc',
      );
    },
  );
  test(
    'dynamic saved-within rules include boundary and reject future dates',
    () {
      final now = DateTime.utc(2026, 2, 1, 12);
      final b = bookmark('a', 'https://a.com').copyWith(
        savedAt: now.subtract(const Duration(days: 30)).toIso8601String(),
      );
      final recent = SmartRule(
        field: 'savedAt',
        operator: 'withinDays',
        value: 30,
      );
      expect(recent.matches(b, now: now), isTrue);
      expect(
        recent.matches(b, now: now.add(const Duration(microseconds: 1))),
        isFalse,
      );
      expect(
        recent.matches(
          b.copyWith(
            savedAt: now.add(const Duration(seconds: 1)).toIso8601String(),
          ),
          now: now,
        ),
        isFalse,
      );
      final smart = SmartCollection(
        id: 's',
        name: 'Recent favorites',
        rules: [
          recent,
          SmartRule(field: 'isFavorite', operator: 'equals', value: true),
        ],
      );
      expect(smart.matches(b, now: now), isFalse);
      expect(smart.copyWith(mode: 'any').matches(b, now: now), isTrue);
      expect(smart.matches(b.copyWith(isFavorite: true), now: now), isTrue);
      for (final value in [0, 36501, '30', double.infinity]) {
        expect(
          () =>
              SmartRule(field: 'savedAt', operator: 'withinDays', value: value),
          throwsFormatException,
        );
      }
    },
  );
  test('Facebook reels shared from the app are videos, posts stay posts', () {
    String type(String url) => UrlTools.normalize(url).contentType;
    expect(type('https://www.facebook.com/share/r/1GgvysCjAs/'), 'video');
    expect(type('https://www.facebook.com/share/v/1AbCdEf/'), 'video');
    expect(type('https://www.facebook.com/reel/2151614385753408'), 'video');
    expect(type('https://www.facebook.com/share/p/18RRxAWX57/'), 'post');
  });

  test('recently opened sorting puts never-opened bookmarks last', () {
    final b = bookmark('a', 'https://a.com');
    final library = SaveLibrary(
      bookmarks: [
        b,
        b.copyWith(id: 'b', lastOpenedAt: '2026-01-02T12:00:00Z'),
        b.copyWith(id: 'c', lastOpenedAt: '2026-01-03T12:00:00Z'),
      ],
    );
    expect(
      searchBookmarks(
        library,
        SearchQuery(sort: SaveSort.recentlyOpened),
      ).map((b) => b.id),
      ['c', 'b', 'a'],
    );
  });
  test(
    'extracts shared URLs, balances punctuation and rejects unsafe schemes',
    () {
      final result = UrlTools.extract(
        'Look (https://example.com/a(b)), https://例え.テスト/道?q=猫. ftp://bad.com javascript:alert(1)',
      );
      expect(result.length, 2);
      expect(result.first.originalUrl, 'https://example.com/a(b)');
      expect(
        UrlTools.extract("'https://example.com/a'").single.originalUrl,
        'https://example.com/a',
      );
      expect(() => UrlTools.normalize('file:///secret'), throwsFormatException);
      expect(
        () => UrlTools.normalize('https://a.com/${'x' * 8192}'),
        throwsFormatException,
      );
      expect(() => UrlTools.extract('x' * 262145), throwsFormatException);
    },
  );
  test(
    'conservative normalization preserves unknown query semantics and fragment',
    () {
      final u = UrlTools.normalize(
        'https://example.com/Path/?id=1&id=2&ref=abc&feature=x&si=y&utm_source=z#part',
      );
      expect(
        u.normalizedUrl,
        'https://example.com/Path/?id=1&id=2&ref=abc&feature=x&si=y#part',
      );
      expect(
        UrlTools.normalize('https://example.com/?utm_source=x').normalizedUrl,
        'https://example.com/',
      );
      expect(u.platform, 'web');
      expect(
        UrlTools.normalize(
          'https://youtube.com.evil.com/watch?v=abcdefghijk',
        ).platform,
        'web',
      );
    },
  );
  test(
    'known YouTube and social aliases retain time and semantic parameters; '
    'the ids a Share button adds (feature=share, s=20) are not part of the '
    'link (2026-11-14)',
    () {
      expect(
        UrlTools.normalize(
          'https://youtu.be/abcdefghijk?t=30&list=abc',
        ).canonicalUrl,
        'https://www.youtube.com/watch?v=abcdefghijk&t=30&list=abc',
      );
      expect(
        UrlTools.normalize(
          'https://youtube.com/shorts/abcdefghijk?feature=share',
        ).canonicalUrl,
        'https://www.youtube.com/watch?v=abcdefghijk',
      );
      expect(
        UrlTools.normalize(
          'https://twitter.com/a/status/123?s=20',
        ).canonicalUrl,
        'https://x.com/a/status/123',
      );
      expect(
        UrlTools.normalize(
          'http://user:pass@127.0.0.1:8080/a.exe',
        ).warnings.length,
        greaterThanOrEqualTo(4),
      );
    },
  );
  test(
    'immutable models clear nullable fields and reject collection cycles',
    () {
      final b = bookmark(
        '1',
        'https://example.com',
        collectionId: 'c',
        tags: ['a'],
      );
      expect(
        b.copyWith(collectionId: null, reminderAt: null).collectionId,
        isNull,
      );
      expect(() => b.tags.add('x'), throwsUnsupportedError);
      expect(
        () => SaveLibrary(
          collections: [
            SaveCollection(id: 'a', name: 'A', parentId: 'b'),
            SaveCollection(id: 'b', name: 'B', parentId: 'a'),
          ],
        ),
        throwsFormatException,
      );
      expect(() => SaveLibrary(bookmarks: [b]), throwsFormatException);
    },
  );
  test(
    'search and smart all/any rules use fields and deterministic sorting',
    () {
      final a = bookmark(
        'a',
        'https://a.com',
        tags: ['Dart'],
        title: 'Learning Dart',
        note: 'local first',
      );
      final b = bookmark(
        'b',
        'https://b.com',
        title: 'Other',
      ).copyWith(isFavorite: true);
      final library = SaveLibrary(bookmarks: [b, a]);
      expect(
        searchBookmarks(
          library,
          SearchQuery(text: 'dart local', tags: ['dart']),
        ).single.id,
        'a',
      );
      final smart = SmartCollection(
        id: 's',
        name: 's',
        mode: 'any',
        rules: [
          SmartRule(field: 'isFavorite', operator: 'equals', value: true),
          SmartRule(field: 'tags', operator: 'equals', value: 'dart'),
        ],
      );
      expect(
        searchBookmarks(
          library,
          SearchQuery(sort: SaveSort.title),
          smartCollection: smart,
        ).map((e) => e.id),
        ['a', 'b'],
      );
      expect(smart.copyWith(mode: 'all').matches(a), isFalse);
    },
  );
  final library = SaveLibrary(
    tags: ['Unassigned global tag', 'One'],
    collections: [
      SaveCollection(id: 'c', name: '研究, "Docs"'),
      SaveCollection(id: 'child', name: 'Child', parentId: 'c'),
    ],
    bookmarks: [
      bookmark(
        'a',
        'https://example.com/?x=1&x=2',
        collectionId: 'child',
        tags: ['One', '猫'],
        title: 'Title, "quoted"\nnext',
        note: 'notes\n<script>text</script>',
      ).copyWith(
        // Schema 2: link checks and the manual order roundtrip too.
        linkCheck: LinkCheck(
          status: 'moved',
          checkedAt: '2026-11-02T08:00:00Z',
          movedTo: 'https://example.org/new?x=1',
          httpStatus: 200,
        ),
      ),
      bookmark('b', 'https://example.net/second', title: 'Second'),
    ],
    manualOrder: ['b', 'a'],
    smartCollections: [
      SmartCollection(
        id: 's',
        name: 'Smart',
        rules: [
          SmartRule(field: 'collectionId', operator: 'equals', value: 'child'),
        ],
      ),
    ],
    savedSearches: [
      SavedSearch(
        id: 'q',
        name: 'Query',
        query: {'text': '猫', 'collectionId': 'child'},
      ),
    ],
  );
  for (final format in SaveFormat.values) {
    test('$format full roundtrip and cancellation', () {
      final bytes = SavePortable.export(library, format);
      final preview = SavePortable.preview(bytes, format, current: library);
      expect(preview.library.toJson(), library.toJson());
      expect(preview.duplicateCount, 2);
      expect(preview.invalidCount, 0);
      expect(
        identical(preview.commit(library, cancelled: true), library),
        true,
      );
      expect(
        preview
            .commit(SaveLibrary(), strategy: ImportStrategy.replace)
            .toJson(),
        library.toJson(),
      );
      final merged = preview.commit(library);
      expect(merged.bookmarks.length, 2);
      expect(merged.tags, containsAll(['Unassigned global tag', 'One']));
      merged.validate();
    });
  }
  test('plain interoperable CSV HTML TXT Markdown import', () {
    ImportPreview read(String s, SaveFormat f) =>
        SavePortable.preview(Uint8List.fromList(utf8.encode(s)), f);
    expect(
      read(
        'url,title,tags\r\nhttps://a.com,"A, B","one;two"',
        SaveFormat.csv,
      ).library.bookmarks.single.tags,
      ['one', 'two'],
    );
    final h = read(
      '<!DOCTYPE NETSCAPE-Bookmark-file-1><DL><DT><H3>Folder</H3><DL><DT><A HREF="https://a.com" TAGS="one,two">A</A></DL></DL>',
      SaveFormat.html,
    );
    expect(h.library.bookmarks.single.title, 'A');
    expect(h.library.collections.length, 1);
    expect(
      h.library.bookmarks.single.collectionId,
      h.library.collections.single.id,
    );
    expect(
      read(
        'https://a.com\ninvalid\nhttps://b.com',
        SaveFormat.txt,
      ).invalidCount,
      1,
    );
    expect(
      read(
        '- [A](https://a.com)',
        SaveFormat.markdown,
      ).library.bookmarks.single.title,
      'A',
    );
  });
  test('merge remaps collection and bookmark identifier collisions', () {
    final current = SaveLibrary(
      collections: [SaveCollection(id: 'c', name: 'Existing')],
      bookmarks: [bookmark('a', 'https://old.com', collectionId: 'c')],
    );
    final p = SavePortable.preview(
      SavePortable.export(library, SaveFormat.json),
      SaveFormat.json,
      current: current,
    );
    final result = p.commit(current);
    expect(result.bookmarks.length, 3);
    expect(result.collections.length, 3);
    final remapped = result.bookmarks[1].id;
    expect(remapped, isNot('a'));
    // The imported order follows the current one, with remapped ids.
    expect(result.fullManualOrder(), ['a', 'b', remapped]);
    expect(result.collections.last.parentId, 'c_import1');
    expect(result.smartCollections.last.rules.single.value, 'child');
    result.validate();
  });
  test(
    'malformed documents, unsafe ZIP paths and digest mismatch are refused',
    () {
      expect(
        () => SavePortable.preview(
          Uint8List.fromList(utf8.encode('{')),
          SaveFormat.json,
        ),
        throwsFormatException,
      );
      expect(
        () => SavePortable.preview(
          Uint8List.fromList(utf8.encode('url,title\n"unclosed')),
          SaveFormat.csv,
        ),
        throwsFormatException,
      );
      final archive = Archive()
        ..addFile(ArchiveFile('../library.json', 2, utf8.encode('{}')));
      expect(
        () => SavePortable.preview(
          Uint8List.fromList(ZipEncoder().encode(archive)),
          SaveFormat.zip,
        ),
        throwsFormatException,
      );
      final bad = Archive()
        ..addFile(ArchiveFile('library.json', 2, utf8.encode('{}')))
        ..addFile(
          ArchiveFile(
            'manifest.json',
            0,
            utf8.encode(
              jsonEncode({
                'format': 'handy-save-zip',
                'version': 1,
                'files': {
                  'library.json': {'bytes': 2, 'sha256': 'bad'},
                },
              }),
            ),
          ),
        );
      expect(
        () => SavePortable.preview(
          Uint8List.fromList(ZipEncoder().encode(bad)),
          SaveFormat.zip,
        ),
        throwsFormatException,
      );
      expect(
        () => SavePortable.preview(Uint8List(30000001), SaveFormat.txt),
        throwsFormatException,
      );
    },
  );
}
