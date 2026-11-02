import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

void main() {
  test('50,000 bookmarks remain searchable with portable export bounds', () {
    final watch = Stopwatch()..start();
    final library = SaveLibrary(
      bookmarks: List.generate(
        50000,
        (i) => Bookmark(
          id: 'b$i',
          originalUrl: 'https://example.com/$i',
          normalizedUrl: 'https://example.com/$i',
          title: 'Reference $i',
          sourceDomain: 'example.com',
          tags: i % 2 == 0 ? ['research'] : [],
          savedAt: '2026-01-01T00:00:00Z',
          updatedAt: '2026-01-01T00:00:00Z',
        ),
      ),
    );
    final buildMs = watch.elapsedMilliseconds;
    watch.reset();
    final result = searchBookmarks(
      library,
      SearchQuery(text: 'reference', tags: ['research']),
    );
    expect(result.length, 25000);
    final searchMs = watch.elapsedMilliseconds;
    watch.reset();
    final size = utf8.encode(jsonEncode(library.toJson())).length;
    if (size <= SavePortable.maxImportBytes) {
      final bytes = SavePortable.export(library, SaveFormat.json);
      expect(SavePortable.preview(bytes, SaveFormat.json).validCount, 50000);
    } else {
      expect(
        () => SavePortable.export(library, SaveFormat.json),
        throwsFormatException,
      );
    }
    // Measurements are informational; avoid flaky machine-specific time limits.
    // ignore: avoid_print
    print(
      '50k build=${buildMs}ms search=${searchMs}ms JSON=$size bytes portable=${watch.elapsedMilliseconds}ms',
    );
  });
}
