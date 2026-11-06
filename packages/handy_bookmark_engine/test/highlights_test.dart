import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Bookmark _b(String id, String url) {
  final u = UrlTools.normalize(url);
  return Bookmark(
    id: id,
    originalUrl: u.originalUrl,
    normalizedUrl: u.normalizedUrl,
    platform: u.platform,
    contentType: u.contentType,
    sourceDomain: u.sourceDomain,
    title: 'Phở',
    savedAt: '2026-11-06T10:00:00Z',
    updatedAt: '2026-11-06T10:00:00Z',
  );
}

const _h = Highlight(
  id: 'h1',
  block: 1,
  start: 4,
  end: 12,
  quote: 'nước dùng',
  color: 'green',
  note: 'Hầm 8 tiếng',
  createdAt: '2026-11-06T10:00:00Z',
);

void main() {
  test('a highlight finds its place: unchanged, moved in its block, moved '
      'to another block, or gone', () {
    final blocks = ['Mở đầu', 'Nồi nước dùng ngon', 'Cuối'];
    expect(anchorHighlight(_h, blocks), (1, 4, 13));
    final exact = Highlight.tryJson({..._h.toJson(), 'start': 4, 'end': 13})!;
    expect(anchorHighlight(exact, blocks), (1, 4, 13));
    expect(anchorHighlight(_h, ['nước dùng ở đây']), (0, 0, 9));
    expect(anchorHighlight(_h, ['khác hẳn']), isNull);
  });

  test('a selection is found nearest the block on screen, first line only', () {
    final blocks = ['bún chả', 'x', 'bún chả ngon'];
    expect(locateQuote('bún chả', blocks, 2), (2, 0, 7));
    expect(locateQuote('bún chả', blocks, 0), (0, 0, 7));
    expect(locateQuote('\n ngon\nCuối', blocks, 0), (2, 8, 12));
    expect(locateQuote('   ', blocks, 0), isNull);
  });

  test(
    'stored highlights are validated: bad entries and unknown items drop',
    () {
      final read = readHighlights(
        {
          'a': [
            _h.toJson(),
            {'id': 'x'},
            {..._h.toJson(), 'id': 'h2', 'color': 'violet'},
          ],
          'gone': [_h.toJson()],
          'b': 'nope',
        },
        ['a', 'b'],
      );
      expect(read.keys, ['a']);
      expect(read['a']!.map((h) => h.id), ['h1', 'h2']);
      expect(
        read['a']![1].color,
        'yellow',
        reason: 'unknown colour falls back',
      );
      expect(readHighlights(null, ['a']), isEmpty);
    },
  );

  for (final format in [SaveFormat.json, SaveFormat.zip]) {
    test('highlights round-trip through ${format.name}; a merge carries them '
        'only for items it adds, under their new ids', () {
      final lib = SaveLibrary(bookmarks: [_b('a', 'https://a.com/x')]);
      final out = SavePortable.export(
        lib,
        format,
        highlights: {
          'a': [_h.toJson()],
          'other': [_h.toJson()],
        },
      );
      final p = SavePortable.preview(out, format);
      expect(p.highlights.keys, ['a']);
      final r = p.apply(SaveLibrary(), strategy: ImportStrategy.replace);
      expect(r.highlights['a']!.single.note, 'Hầm 8 tiếng');
      // Merging into a library that already uses id 'a' for another link.
      final mine = SaveLibrary(bookmarks: [_b('a', 'https://b.com/y')]);
      final m = p.apply(mine);
      final added = m.library.bookmarks.firstWhere(
        (b) => b.originalUrl == 'https://a.com/x',
      );
      expect(added.id, isNot('a'));
      expect(m.highlights.keys, [added.id]);
    });
  }

  test('an older backup without highlights restores with none', () {
    final out = SavePortable.export(
      SaveLibrary(bookmarks: [_b('a', 'https://a.com/x')]),
      SaveFormat.json,
    );
    expect(SavePortable.preview(out, SaveFormat.json).highlights, isEmpty);
  });

  test('highlights read as Markdown quotes with notes', () {
    expect(
      highlightsAsText('Phở', 'https://a.com/x', [_h]),
      '# Phở\nhttps://a.com/x\n\n> nước dùng\n\nHầm 8 tiếng\n',
    );
  });
}
