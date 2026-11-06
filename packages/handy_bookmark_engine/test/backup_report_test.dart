import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

const t0 = '2026-01-01T00:00:00.000Z';

Bookmark link(String id, String url, {String? collection, MediaRef? media}) {
  final u = UrlTools.normalize(url);
  return Bookmark(
    id: id,
    originalUrl: u.originalUrl,
    normalizedUrl: u.normalizedUrl,
    canonicalUrl: u.canonicalUrl,
    platform: u.platform,
    contentType: u.contentType,
    sourceDomain: u.sourceDomain,
    title: id,
    collectionId: collection,
    media: media,
    savedAt: t0,
    updatedAt: t0,
  );
}

SaveLibrary withViews() => SaveLibrary(
  collections: [
    SaveCollection(id: 'food', name: 'Food'),
    SaveCollection(id: 'trip', name: 'Trips', position: 1),
  ],
  bookmarks: [
    link('a', 'https://a.com/1', collection: 'food'),
    link('b', 'https://b.com/2', collection: 'trip'),
  ],
);

const views = {
  'food': {'cards': true, 'sort': 'oldest'},
  'trip': {'cards': false},
};

/// Pocket CSV export with the given links.
String pocket(List<String> urls) => [
  'title,url,time_added,tags,status',
  for (final u in urls) 'T,$u,1700000000,,unread',
].join('\n');

void main() {
  group('collection views in backups', () {
    for (final format in [
      SaveFormat.zip,
      SaveFormat.json,
      SaveFormat.csv,
      SaveFormat.html,
      SaveFormat.txt,
      SaveFormat.markdown,
    ]) {
      test('round-trip through ${format.name}', () {
        final out = SavePortable.export(
          withViews(),
          format,
          collectionViews: views,
        );
        final p = SavePortable.preview(out, format);
        expect(p.collectionViews, views);
        final r = p.apply(SaveLibrary(), strategy: ImportStrategy.replace);
        expect(r.collectionViews, views);
      });
    }

    test('a backup without views (older app) still restores, and keeps the '
        "person's existing choices", () {
      final out = SavePortable.export(withViews(), SaveFormat.zip);
      final p = SavePortable.preview(out, SaveFormat.zip);
      expect(p.collectionViews, isEmpty);
      final r = p.apply(SaveLibrary(), strategy: ImportStrategy.replace);
      expect(r.library.collections, hasLength(2));
      final mine = {
        'food': {'cards': true},
      };
      expect(mergeCollectionViews(mine, r.collectionViews), isNull);
      expect(
        mergeCollectionViews(mine, {
          'trip': {'sort': 'title'},
        }),
        {
          'food': {'cards': true},
          'trip': {'sort': 'title'},
        },
      );
    });

    test('the ZIP format and library version are unchanged, and an older '
        'reader ignores the extra key', () {
      final out = SavePortable.export(
        withViews(),
        SaveFormat.zip,
        collectionViews: views,
      );
      final zip = ZipDecoder().decodeBytes(out);
      final manifest = jsonDecode(
        utf8.decode(zip.findFile('manifest.json')!.content as List<int>),
      );
      expect(manifest['version'], 2);
      final library = jsonDecode(
        utf8.decode(zip.findFile('library.json')!.content as List<int>),
      );
      expect(library['version'], 2);
      expect(library['collectionViews'], views);
      // What an older version does with it: SaveLibrary.fromJson.
      expect(
        SaveLibrary.fromJson(Map<String, dynamic>.from(library)).toJson(),
        withViews().toJson(),
      );
    });

    test('damaged or unknown views are dropped, never fatal', () {
      final out = SavePortable.export(
        withViews(),
        SaveFormat.json,
        collectionViews: {
          'food': {'cards': 'yes', 'sort': 'oldest', 'colour': 'red'},
          'trip': 'gallery',
          'gone': {'cards': true},
          'other': {'sort': 'sideways'},
        },
      );
      final p = SavePortable.preview(out, SaveFormat.json);
      expect(p.collectionViews, {
        'food': {'sort': 'oldest'},
      });
    });

    test('a merge carries views only for collections it creates, under '
        'their new ids', () {
      final current = SaveLibrary(
        collections: [SaveCollection(id: 'food', name: 'Mine')],
        bookmarks: [link('x', 'https://x.com/1', collection: 'food')],
      );
      final out = SavePortable.export(
        withViews(),
        SaveFormat.zip,
        collectionViews: views,
      );
      final r = SavePortable.preview(
        out,
        SaveFormat.zip,
        current: current,
      ).apply(current);
      // The file's "food" became food_import1; the person's "food" keeps
      // whatever view they chose.
      expect(r.collectionViews, {
        'food_import1': {'cards': true, 'sort': 'oldest'},
        'trip': {'cards': false},
      });
    });
  });

  group('what a backup left out', () {
    final png = MediaRef(
      id: 'a' * 64,
      mime: 'image/png',
      bytes: 4,
      width: 1,
      height: 1,
      name: 'p',
    );
    SaveLibrary withPicture() => SaveLibrary(
      bookmarks: [
        link('a', 'https://a.com/1', media: png),
        link('b', 'https://b.com/2'),
      ],
    );
    final copy = ReadingCopy(
      url: 'https://b.com/2',
      title: 'B',
      blocks: [ReadingBlock('p', 'hello')],
      savedAt: t0,
    );

    test('a ZIP with a picture missing on the device is not complete', () {
      final out = SavePortable.exportWithReport(withPicture(), SaveFormat.zip);
      expect(out.complete, isFalse);
      expect(out.omissions, [
        const BackupOmission('pictures', OmissionReason.missing, 1),
      ]);
    });

    test('unreadable offline copies are reported', () {
      final out = SavePortable.exportWithReport(
        withPicture(),
        SaveFormat.zip,
        pictures: {
          png.id: PortablePicture(
            Uint8List.fromList([1, 2, 3, 4]),
            Uint8List.fromList([5]),
          ),
        },
        readingCopies: {'b': copy},
        unreadableReadingCopies: 2,
      );
      expect(out.picturesIncluded, 1);
      expect(out.readingIncluded, 1);
      expect(out.omissions, [
        const BackupOmission('readingCopies', OmissionReason.unreadable, 2),
      ]);
      expect(out.complete, isFalse);
    });

    test('formats that cannot carry pictures or copies say so', () {
      final json = SavePortable.exportWithReport(
        withPicture(),
        SaveFormat.json,
        readingCopies: {'b': copy},
      );
      expect(json.omissions, [
        const BackupOmission('pictures', OmissionReason.format, 1),
      ]);
      final csv = SavePortable.exportWithReport(
        withPicture(),
        SaveFormat.csv,
        readingCopies: {'b': copy},
      );
      expect(csv.omissions, [
        const BackupOmission('readingCopies', OmissionReason.format, 1),
        const BackupOmission('pictures', OmissionReason.format, 1),
      ]);
    });

    test('offline copies over the size budget are counted as too large', () {
      final big = ReadingCopy(
        url: 'https://b.com/2',
        title: 'B',
        blocks: [ReadingBlock('p', 'x' * ReadingCopy.maxChars)],
        savedAt: t0,
      );
      final library = SaveLibrary(
        bookmarks: [
          for (var i = 0; i < 200; i++) link('l$i', 'https://b.com/$i'),
        ],
      );
      final out = SavePortable.exportWithReport(
        library,
        SaveFormat.zip,
        readingCopies: {for (var i = 0; i < 200; i++) 'l$i': big},
      );
      expect(out.readingOmitted, greaterThan(0));
      expect(
        out.omissions.single,
        BackupOmission(
          'readingCopies',
          OmissionReason.tooLarge,
          out.readingOmitted,
        ),
      );
    });

    test('a library with everything present is complete', () {
      final out = SavePortable.exportWithReport(withViews(), SaveFormat.zip);
      expect(out.complete, isTrue);
      expect(out.omissions, isEmpty);
    });

    test('an omission survives its JSON form', () {
      const o = BackupOmission('pictures', OmissionReason.tooLarge, 3, 900);
      expect(BackupOmission.fromJson(o.toJson()), o);
      expect(BackupOmission.fromJson({'what': 1}), isNull);
    });

    test('a report keeps what was left out, and is never complete then', () {
      final out = SavePortable.exportWithReport(withPicture(), SaveFormat.zip);
      final r = BackupReport.of(out, at: t0, automatic: true, links: 2);
      expect(r.complete, isFalse);
      expect(r.left('pictures'), 1);
      expect(r.left('readingCopies'), 0);
      final back = BackupReport.fromJson(jsonDecode(jsonEncode(r.toJson())))!;
      expect(back.toJson(), r.toJson());
      expect(back.omissions, out.omissions);
      expect(BackupReport.fromJson({'at': t0}), isNull);
      expect(BackupReport.fromJson('x'), isNull);
    });
  });

  group('importing Pocket or Raindrop again', () {
    test('a second Pocket import finds the existing Pocket collection', () {
      final first = SavePortable.previewPocket(
        bytes(pocket(['https://a.com/1'])),
      ).commit(SaveLibrary());
      final second = SavePortable.previewPocket(
        bytes(pocket(['https://a.com/1', 'https://a.com/2'])),
        current: first,
      );
      expect(second.sameNamedCollections(first), {'pocket': 'pocket'});
    });

    test('by default new links go to a separate collection and the '
        "person's collection is untouched", () {
      final first = SavePortable.previewPocket(
        bytes(pocket(['https://a.com/1'])),
      ).commit(SaveLibrary());
      final next = SavePortable.previewPocket(
        bytes(pocket(['https://a.com/1', 'https://a.com/2'])),
        current: first,
      ).commit(first);
      expect(next.collections.map((c) => c.name), ['Pocket', 'Pocket']);
      expect(next.collections.first, first.collections.single);
    });

    test('reusing puts new links into the existing collection', () {
      final first = SavePortable.previewPocket(
        bytes(pocket(['https://a.com/1'])),
      ).commit(SaveLibrary());
      final next = SavePortable.previewPocket(
        bytes(pocket(['https://a.com/1', 'https://a.com/2'])),
        current: first,
      ).commit(first, reuseCollections: true);
      expect(next.collections, first.collections);
      expect(next.bookmarks.map((b) => b.collectionId), ['pocket', 'pocket']);
    });

    test('a Raindrop tree is not copied again for folders that get no new '
        'link', () {
      String raindrop(List<(String, String)> rows) => [
        'id,title,note,excerpt,url,folder,tags,created,cover,highlights,favorite',
        for (final (url, folder) in rows)
          '1,T,,,$url,$folder,,2025-03-01T08:30:00.000Z,,,false',
      ].join('\n');
      final first = SavePortable.previewRaindrop(
        bytes(
          raindrop([
            ('https://a.com/1', 'Food'),
            ('https://a.com/2', 'Trips/Hội An'),
          ]),
        ),
      ).commit(SaveLibrary());
      expect(first.collections, hasLength(3));
      final again = SavePortable.previewRaindrop(
        bytes(
          raindrop([
            ('https://a.com/1', 'Food'),
            ('https://a.com/2', 'Trips/Hội An'),
            ('https://a.com/3', 'Trips/Hội An'),
          ]),
        ),
        current: first,
      );
      expect(again.sameNamedCollections(first), hasLength(3));
      // Default: Food gets nothing new, so no second Food; the Trips/Hội An
      // branch gets a link, so it is added beside the person's.
      final separate = again.commit(first);
      expect(separate.collections.where((c) => c.name == 'Food'), hasLength(1));
      expect(separate.collections, hasLength(5));
      // Reusing: nothing new is created; the link joins the existing branch.
      final reused = again.commit(first, reuseCollections: true);
      expect(reused.collections, first.collections);
      final hoiAn = first.collections.firstWhere((c) => c.name == 'Hội An');
      expect(
        reused.bookmarks
            .firstWhere((b) => b.originalUrl == 'https://a.com/3')
            .collectionId,
        hoiAn.id,
      );
    });

    test('a different name or place is not the same collection', () {
      final current = SaveLibrary(
        collections: [
          SaveCollection(id: 'p', name: 'Parent'),
          SaveCollection(id: 'k', name: 'Kids', parentId: 'p'),
        ],
      );
      final file = ImportPreview(
        library: SaveLibrary(
          collections: [
            SaveCollection(id: 'k2', name: 'Kids'),
            SaveCollection(id: 'p2', name: 'parent'),
          ],
        ),
        duplicateCount: 0,
        invalidCount: 0,
      );
      expect(file.sameNamedCollections(current), {'p2': 'p'});
    });
  });
}
