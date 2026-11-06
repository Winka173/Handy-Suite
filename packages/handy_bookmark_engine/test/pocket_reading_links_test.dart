import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Bookmark mark(String id, String url, {String title = ''}) {
  final u = UrlTools.normalize(url);
  return Bookmark(
    id: id,
    originalUrl: u.originalUrl,
    normalizedUrl: u.normalizedUrl,
    canonicalUrl: u.canonicalUrl,
    platform: u.platform,
    contentType: u.contentType,
    sourceDomain: u.sourceDomain,
    title: title,
    savedAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
  );
}

Uint8List fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

ReadingCopy copy(String text, {String at = '2026-03-01T00:00:00Z'}) =>
    ReadingCopy(
      url: 'https://a.com/x',
      title: 'Title',
      savedAt: at,
      blocks: [ReadingBlock('p', text)],
    );

void main() {
  group('Pocket import', () {
    test('CSV maps status, tags, time_added and files into Pocket', () {
      final p = SavePortable.previewPocket(fixture('part_000000.csv'));
      final l = p.library;
      // Broken URL and the short row are counted, not imported.
      expect(p.invalidCount, 2);
      expect(p.validCount, 4);
      // The second coffee link is the same page without tracking.
      expect(p.duplicateCount, 1);
      expect(l.collections.single.name, 'Pocket');
      expect(l.bookmarks.every((b) => b.collectionId == 'pocket'), isTrue);
      final coffee = l.bookmarks.first;
      expect(coffee.title, 'How to brew coffee, properly');
      expect(coffee.tags, ['coffee', 'kitchen']);
      expect(coffee.savedAt, '2023-11-14T22:13:20.000Z');
      expect(coffee.isArchived || coffee.isRead, isFalse);
      final read = l.bookmarks[1];
      expect(read.title, 'Đọc sách mỗi ngày');
      expect(read.isArchived && read.isRead, isTrue);
      // A title that only repeats the address is dropped.
      expect(l.bookmarks[2].title, '');
      expect(l.bookmarks[2].tags, ['dev', 'flutter']);
    });

    test('ril_export.html maps the Unread and Read Archive lists', () {
      final p = SavePortable.previewPocket(fixture('ril_export.html'));
      final l = p.library;
      expect(p.invalidCount, 1); // javascript: link
      expect(l.bookmarks.map((b) => b.title), [
        'A song worth keeping',
        'Slow mornings',
        'Hacker News 1',
      ]);
      expect(l.bookmarks.map((b) => b.isArchived), [false, false, true]);
      expect(l.bookmarks.first.tags, ['music', 'video']);
      expect(l.bookmarks.first.savedAt, '2020-09-13T12:26:40.000Z');
      expect(l.bookmarks.last.savedAt, '2017-07-14T02:40:00.000Z');
    });

    test('merges through the usual duplicate and id remapping', () {
      final current = SaveLibrary(
        collections: [SaveCollection(id: 'pocket', name: 'Mine')],
        bookmarks: [
          mark('import_0', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        ],
      );
      final p = SavePortable.previewPocket(
        fixture('ril_export.html'),
        current: current,
      );
      expect(p.duplicateCount, 1);
      final merged = p.commit(current);
      expect(merged.bookmarks, hasLength(3));
      expect(merged.collections.map((c) => c.name), ['Mine', 'Pocket']);
      final pocket = merged.collections.last.id;
      expect(pocket, isNot('pocket'));
      expect(
        merged.bookmarks.skip(1).every((b) => b.collectionId == pocket),
        isTrue,
      );
      expect(merged.bookmarks.map((b) => b.id).toSet(), hasLength(3));
      // Cancel changes nothing.
      expect(identical(p.commit(current, cancelled: true), current), isTrue);
    });

    test('refuses files that are not Pocket exports', () {
      Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));
      expect(
        () => SavePortable.previewPocket(bytes('url,title\nhttps://a.com,A')),
        throwsFormatException,
      );
      expect(
        () => SavePortable.previewPocket(bytes('<html><body></body></html>')),
        throwsFormatException,
      );
      expect(
        () => SavePortable.previewPocket(Uint8List(0)),
        throwsFormatException,
      );
    });

    test('the generic CSV importer loses what Pocket meant', () {
      // Why an explicit path exists: generic CSV keeps the links but not the
      // read state, the saved date or the `|` tags.
      final p = SavePortable.preview(
        fixture('part_000000.csv'),
        SaveFormat.csv,
      );
      final read = p.library.bookmarks[1];
      expect(read.isArchived, isFalse);
      expect(p.library.bookmarks.first.tags, ['coffee|kitchen']);
    });
  });

  group('link checks', () {
    const at = '2026-11-02T08:00:00Z';
    test('classifies conservatively', () {
      LinkCheck judge(LinkProbe p, [String url = 'https://a.com/post/1']) =>
          classifyLinkProbe(url, p, at);
      expect(judge(const LinkProbe(status: 200)).status, 'ok');
      expect(judge(const LinkProbe(status: 404)).status, 'gone');
      expect(judge(const LinkProbe(status: 410)).status, 'gone');
      for (final s in [401, 403, 429, 500, 503]) {
        final c = judge(LinkProbe(status: s));
        expect(c.status, 'unreachable', reason: '$s');
        expect(c.httpStatus, s);
      }
      final down = judge(const LinkProbe(error: 'timeout'));
      expect((down.status, down.reason), ('unreachable', 'timeout'));
      final moved = judge(
        const LinkProbe(status: 200, permanentUrl: 'https://b.org/new'),
      );
      expect((moved.status, moved.movedTo), ('moved', 'https://b.org/new'));
      expect(moved.reason, isNull);
      // Scheme, www and a trailing slash alone are not a move.
      expect(
        judge(
          const LinkProbe(
            status: 200,
            permanentUrl: 'https://www.a.com/post/1/',
          ),
          'http://a.com/post/1',
        ).status,
        'ok',
      );
      expect(
        judge(
          const LinkProbe(status: 200, permanentUrl: 'https://a.com/'),
        ).reason,
        'home',
      );
      // Moved then gone is gone.
      expect(
        judge(
          const LinkProbe(status: 404, permanentUrl: 'https://b.org/x'),
        ).status,
        'gone',
      );
    });

    test('survives JSON, stays out of unchecked payloads, validates', () {
      final b = mark('a', 'https://a.com/post/1');
      expect(b.toJson().containsKey('linkCheck'), isFalse);
      final checked = b.copyWith(
        linkCheck: classifyLinkProbe(
          b.originalUrl,
          const LinkProbe(status: 200, permanentUrl: 'https://b.org/x'),
          at,
        ),
      );
      final again = Bookmark.fromJson(
        jsonDecode(jsonEncode(checked.toJson())) as Map<String, dynamic>,
      );
      expect(again.linkCheck!.toJson(), checked.linkCheck!.toJson());
      expect(again.copyWith(linkCheck: null).linkCheck, isNull);
      expect(
        () => LinkCheck(status: 'moved', checkedAt: at),
        throwsFormatException,
      );
      expect(
        () => LinkCheck(status: 'lost', checkedAt: at),
        throwsFormatException,
      );
      expect(
        () => LinkCheck(
          status: 'moved',
          checkedAt: at,
          movedTo: 'https://user:pw@b.org/',
        ),
        throwsFormatException,
      );
    });

    test('adopting the moved address keeps the person\'s words', () {
      final b = mark('a', 'https://a.com/post/1', title: 'Mine').copyWith(
        note: 'keep',
        tags: ['t'],
        linkCheck: LinkCheck(
          status: 'moved',
          checkedAt: at,
          movedTo: 'https://www.youtube.com/watch?v=abc',
        ),
      );
      final next = adoptMovedUrl(b, at);
      expect(next.originalUrl, 'https://www.youtube.com/watch?v=abc');
      expect(next.platform, 'youtube');
      expect((next.title, next.note), ('Mine', 'keep'));
      expect(next.tags, ['t']);
      expect(next.linkCheck!.status, 'ok');
      expect(() => adoptMovedUrl(next, at), throwsStateError);
    });

    test('the broken filter finds links whose check found a problem', () {
      final ok = mark('ok', 'https://a.com/1').copyWith(
        linkCheck: LinkCheck(status: 'ok', checkedAt: at),
      );
      final gone = mark('gone', 'https://a.com/2').copyWith(
        linkCheck: LinkCheck(status: 'gone', checkedAt: at, httpStatus: 404),
      );
      final never = mark('never', 'https://a.com/3');
      final l = SaveLibrary(bookmarks: [ok, gone, never]);
      expect(
        searchBookmarks(l, SearchQuery(linkIssue: true)).map((b) => b.id),
        ['gone'],
      );
      expect(
        SearchQuery.fromJson(SearchQuery(linkIssue: true).toJson()).linkIssue,
        isTrue,
      );
    });
  });

  group('manual order', () {
    final l = SaveLibrary(
      bookmarks: [
        for (final id in ['a', 'b', 'c', 'd']) mark(id, 'https://$id.com'),
      ],
      manualOrder: ['c', 'gone', 'a', 'c'],
    );
    test('drops unknown ids and repeats; the rest follow', () {
      expect(l.manualOrder, ['c', 'a']);
      expect(l.fullManualOrder(), ['c', 'a', 'b', 'd']);
      expect(
        searchBookmarks(l, SearchQuery(sort: SaveSort.manual)).map((b) => b.id),
        ['c', 'a', 'b', 'd'],
      );
      // Deleting a link removes it from the order.
      expect(l.copyWith(bookmarks: l.bookmarks.skip(1).toList()).manualOrder, [
        'c',
      ]);
    });

    test('moves within a filtered list keep the others in place', () {
      // The list shows c, b, d (a is filtered out). Move d to the top.
      expect(moveInManualOrder(l, ['c', 'b', 'd'], 2, 0), ['d', 'c', 'a', 'b']);
      // Step c down one.
      expect(moveInManualOrder(l, ['c', 'b', 'd'], 0, 1), ['a', 'b', 'c', 'd']);
      // To the end.
      expect(moveInManualOrder(l, ['c', 'a', 'b', 'd'], 0, 3), [
        'a',
        'b',
        'd',
        'c',
      ]);
      expect(() => moveInManualOrder(l, ['c', 'zz'], 0, 1), throwsStateError);
      expect(() => moveInManualOrder(l, ['c'], 0, 1), throwsRangeError);
    });

    test('merge appends an imported order after the current one', () {
      final incoming = SaveLibrary(
        bookmarks: [mark('x', 'https://x.com'), mark('a', 'https://a.com')],
        manualOrder: ['x', 'a'],
      );
      final preview = SavePortable.preview(
        SavePortable.export(incoming, SaveFormat.json),
        SaveFormat.json,
        current: l,
      );
      final merged = preview.commit(l);
      // a is a duplicate and stays where it was; x comes after the rest.
      expect(merged.fullManualOrder(), ['c', 'a', 'b', 'd', 'x']);
    });

    test('version 1 libraries still read; newer ones are refused', () {
      final v1 = {
        'format': 'handy-save',
        'version': 1,
        'bookmarks': [mark('a', 'https://a.com').toJson()],
        'preferences': {
          'bookmarkOrder': ['a'],
        },
      };
      final p = SavePortable.preview(
        Uint8List.fromList(utf8.encode(jsonEncode(v1))),
        SaveFormat.json,
      );
      expect(p.library.manualOrder, isEmpty);
      expect(p.library.toJson()['version'], 2);
      expect(
        () => SaveLibrary.fromJson({...v1, 'version': 4}),
        throwsFormatException,
      );
    });
  });

  group('reading copies', () {
    const article = '''
<!doctype html><html><head>
<title>Slow mornings | Example Blog</title>
<meta property="og:title" content="Slow mornings">
<meta property="og:site_name" content="Example Blog">
<meta name="author" content="By Lan Nguyễn">
<script>var tracking = "SECRET_SCRIPT";</script>
<style>.x{color:red}</style>
</head><body>
<header><nav><a href="/">Home</a> <a href="/about">About</a></nav></header>
<div class="share-buttons"><a href="#">Share on X</a></div>
<main><article class="post-content">
<h1>Slow mornings</h1>
<p>Waking before the city does, I make coffee slowly, grinding the beans by hand, and watch the street turn from blue to gold.</p>
<img src="https://tracker.example.com/pixel.gif" alt="pixel">
<figure><img src="/a.jpg"><figcaption>A photo caption</figcaption></figure>
<h2>Why it matters</h2>
<p>A quiet hour, kept on purpose, changes the rest of the day: fewer decisions, more attention, and a little room to think before the messages arrive.</p>
<ul><li>Coffee, by hand</li><li>No phone until eight</li></ul>
<blockquote>Slow is smooth, and smooth is fast.</blockquote>
<pre>  brew --slow
  sip</pre>
<p style="display:none">HIDDEN_TEXT</p>
</article></main>
<aside class="related">Related: ten more posts</aside>
<footer>© Example</footer>
<script>document.write("SECRET_SCRIPT_2")</script>
</body></html>''';
    test('keeps the article text and leaves out the rest', () {
      final c = extractReadingCopy(
        article,
        url: 'https://blog.example.net/posts/slow-mornings',
        savedAt: '2026-11-02T08:00:00Z',
      )!;
      expect(c.title, 'Slow mornings');
      expect(c.byline, 'Lan Nguyễn');
      expect(c.siteName, 'Example Blog');
      final kinds = c.blocks.map((b) => b.kind).toList();
      expect(kinds, ['p', 'h', 'p', 'li', 'li', 'quote', 'pre']);
      final all = c.blocks.map((b) => b.text).join('\n');
      for (final gone in [
        'SECRET_SCRIPT',
        'color:red',
        'Home',
        'Share on X',
        'Related',
        '©',
        'HIDDEN_TEXT',
        'pixel',
        'A photo caption',
      ]) {
        expect(all.contains(gone), isFalse, reason: gone);
      }
      expect(c.blocks.last.text, '  brew --slow\n  sip');
      expect(
        ReadingCopy.fromJson(
          jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>,
        ).toJson(),
        c.toJson(),
      );
    });

    test('a page without prose gives no copy; a long one is cut', () {
      expect(
        extractReadingCopy(
          '<html><body><nav>Menu</nav><p>Hi</p></body></html>',
          url: 'https://a.com',
          savedAt: '2026-11-02T08:00:00Z',
        ),
        isNull,
      );
      final para = 'Sentence, with a comma and enough words to count. ' * 20;
      final long = extractReadingCopy(
        '<html><body><article>${'<p>$para</p>' * 400}</article></body></html>',
        url: 'https://a.com',
        savedAt: '2026-11-02T08:00:00Z',
      )!;
      expect(long.truncated, isTrue);
      expect(long.chars, lessThanOrEqualTo(ReadingCopy.maxChars));
      expect(
        () => ReadingCopy(
          url: 'https://a.com',
          title: '',
          savedAt: '2026-11-02T08:00:00Z',
          blocks: const [],
        ),
        throwsFormatException,
      );
    });

    final library = SaveLibrary(
      bookmarks: [mark('a', 'https://a.com/1'), mark('b', 'https://b.com/2')],
    );
    final copies = {'a': copy('First copy'), 'gone': copy('orphan')};
    for (final format in [SaveFormat.json, SaveFormat.zip]) {
      test('$format backup carries reading copies and re-keys on merge', () {
        final out = SavePortable.exportWithReport(
          library,
          format,
          readingCopies: copies,
        );
        expect((out.readingIncluded, out.readingOmitted), (1, 0));
        final p = SavePortable.preview(out.bytes, format);
        expect(p.readingCopies.keys, ['a']);
        expect(p.readingCopies['a']!.toJson(), copies['a']!.toJson());
        final replaced = p.apply(
          SaveLibrary(),
          strategy: ImportStrategy.replace,
        );
        expect(replaced.readingCopies.keys, ['a']);
        // Merging into a library that already has id "a" for another link.
        final current = SaveLibrary(bookmarks: [mark('a', 'https://z.com')]);
        final merged = SavePortable.preview(
          out.bytes,
          format,
          current: current,
        ).apply(current);
        final newId = merged.library.bookmarks
            .firstWhere((b) => b.originalUrl == 'https://a.com/1')
            .id;
        expect(newId, isNot('a'));
        expect(merged.readingCopies.keys, [newId]);
      });
    }

    test('text formats carry no copies; a bad copy is counted, not fatal', () {
      final csv = SavePortable.exportWithReport(
        library,
        SaveFormat.csv,
        readingCopies: copies,
      );
      expect((csv.readingIncluded, csv.readingOmitted), (0, 1));
      expect(
        SavePortable.preview(csv.bytes, SaveFormat.csv).readingCopies,
        isEmpty,
      );
      final json =
          jsonDecode(
                utf8.decode(
                  SavePortable.export(
                    library,
                    SaveFormat.json,
                    readingCopies: copies,
                  ),
                ),
              )
              as Map<String, dynamic>;
      (json['readingCopies'] as Map)['b'] = {'url': 'x', 'blocks': 'nope'};
      final p = SavePortable.preview(
        Uint8List.fromList(utf8.encode(jsonEncode(json))),
        SaveFormat.json,
      );
      expect((p.readingCopies.length, p.invalidCopies), (1, 1));
    });

    test('copies beyond the 30 MB budget are left out, newest kept', () {
      final big = 'x' * (ReadingCopy.maxChars - 10);
      final many = SaveLibrary(
        bookmarks: [
          for (var i = 0; i < 160; i++) mark('b$i', 'https://a.com/$i'),
        ],
      );
      final out = SavePortable.exportWithReport(
        many,
        SaveFormat.zip,
        readingCopies: {
          for (var i = 0; i < 160; i++)
            'b$i': copy(
              big,
              at: DateTime.utc(
                2026,
                1,
                1,
              ).add(Duration(hours: i)).toIso8601String(),
            ),
        },
      );
      expect(out.readingOmitted, greaterThan(0));
      expect(out.readingIncluded + out.readingOmitted, 160);
      expect(out.bytes.length, lessThanOrEqualTo(SavePortable.maxImportBytes));
      final p = SavePortable.preview(out.bytes, SaveFormat.zip);
      expect(p.readingCopies.length, out.readingIncluded);
      expect(p.readingCopies.containsKey('b159'), isTrue);
      expect(p.readingCopies.containsKey('b0'), isFalse);
    });

    test('version 1 ZIPs still restore; a changed reading.json is refused', () {
      final data = utf8.encode(jsonEncode({...library.toJson(), 'version': 1}));
      final manifest = utf8.encode(
        jsonEncode({
          'format': 'handy-save-zip',
          'version': 1,
          'files': {
            'library.json': {
              'sha256': sha256.convert(data).toString(),
              'bytes': data.length,
            },
          },
        }),
      );
      final old = ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
          ..addFile(ArchiveFile('library.json', data.length, data)),
      );
      expect(
        SavePortable.preview(
          Uint8List.fromList(old),
          SaveFormat.zip,
        ).validCount,
        2,
      );
      final good = ZipDecoder().decodeBytes(
        SavePortable.export(library, SaveFormat.zip, readingCopies: copies),
      );
      final tampered = Archive();
      for (final f in good.files) {
        final bytes = f.name == 'reading.json'
            ? utf8.encode(utf8.decode(f.content).replaceAll('First', 'Fakes'))
            : f.content;
        tampered.addFile(ArchiveFile(f.name, bytes.length, bytes));
      }
      expect(
        () => SavePortable.preview(
          Uint8List.fromList(ZipEncoder().encode(tampered)),
          SaveFormat.zip,
        ),
        throwsFormatException,
      );
    });
  });
}
