import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

const t0 = '2026-01-01T00:00:00.000Z';
const t1 = '2026-02-01T00:00:00.000Z';

Bookmark link(String id, String url, {String? collection}) {
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
    savedAt: t0,
    updatedAt: t0,
  );
}

ReadingCopy copy(String url, String text) => ReadingCopy(
  url: url,
  title: 'Bài đọc',
  blocks: [ReadingBlock('p', text)],
  savedAt: t0,
);

/// A live item and one in Recently Deleted, each with an offline copy.
SaveLibrary withTrash() => moveToTrash(
  SaveLibrary(
    collections: [SaveCollection(id: 'food', name: 'Ẩm thực')],
    bookmarks: [
      link('live', 'https://a.com/pho', collection: 'food'),
      link('gone', 'https://b.com/bun-cha', collection: 'food'),
    ],
  ),
  ['gone'],
  t1,
);

final copies = {
  'live': copy('https://a.com/pho', 'Phở bò'),
  'gone': copy('https://b.com/bun-cha', 'Bún chả Hà Nội'),
};

void main() {
  group('offline copies of items in Recently Deleted', () {
    for (final format in [SaveFormat.zip, SaveFormat.json]) {
      test('${format.name} carries them and a replace restores them', () {
        final out = SavePortable.exportWithReport(
          withTrash(),
          format,
          readingCopies: copies,
        );
        expect(out.readingIncluded, 2);
        expect(out.complete, isTrue);
        final p = SavePortable.preview(out.bytes, format);
        expect(p.readingCopies.keys.toSet(), {'live', 'gone'});
        expect(p.invalidCopies, 0);
        final r = p.apply(SaveLibrary(), strategy: ImportStrategy.replace);
        expect(r.library.trash.single.id, 'gone');
        expect(r.readingCopies['gone']!.blocks.single.text, 'Bún chả Hà Nội');
      });
    }

    test('a merge brings no Trash, so not its copies either', () {
      final out = SavePortable.exportWithReport(
        withTrash(),
        SaveFormat.zip,
        readingCopies: copies,
      );
      final r = SavePortable.preview(
        out.bytes,
        SaveFormat.zip,
      ).apply(SaveLibrary());
      expect(r.library.trash, isEmpty);
      expect(r.readingCopies.keys, ['live']);
    });

    test('formats without copies count them, Trash ones included', () {
      final out = SavePortable.exportWithReport(
        withTrash(),
        SaveFormat.csv,
        readingCopies: copies,
      );
      expect(out.omissions, [
        const BackupOmission('readingCopies', OmissionReason.format, 2),
      ]);
    });

    test('an export of picked items leaves Trash copies out silently', () {
      final picked = withTrash().copyWith(trash: const []);
      final out = SavePortable.exportWithReport(
        picked,
        SaveFormat.zip,
        readingCopies: copies,
      );
      expect(out.readingIncluded, 1);
      expect(out.complete, isTrue);
    });
  });

  group('a collection\'s chosen cover', () {
    SaveLibrary lib() => SaveLibrary(
      collections: [SaveCollection(id: 'food', name: 'Food')],
      bookmarks: [
        link('a', 'https://a.com/1', collection: 'food'),
        link('b', 'https://b.com/2', collection: 'food'),
      ],
    );

    test('is kept when it names an item in the file, else dropped', () {
      expect(
        SavePortable.readCollectionViews(
          {
            'food': {'cards': true, 'cover': 'b'},
            'other': {'cover': 'a'},
          },
          ['food'],
          ['a', 'b'],
        ),
        {
          'food': {'cards': true, 'cover': 'b'},
        },
      );
      expect(
        SavePortable.readCollectionViews(
          {
            'food': {'cover': 'zzz'},
          },
          ['food'],
          ['a'],
        ),
        isEmpty,
      );
      expect(
        SavePortable.readCollectionViews(
          {
            'food': {'cover': 7, 'sort': 'oldest'},
          },
          ['food'],
          ['a'],
        ),
        {
          'food': {'sort': 'oldest'},
        },
      );
    });

    for (final format in [SaveFormat.zip, SaveFormat.json, SaveFormat.csv]) {
      test('travels in ${format.name} and survives a replace', () {
        final bytes = SavePortable.export(
          lib(),
          format,
          collectionViews: {
            'food': {'cover': 'b', 'cards': true},
          },
        );
        final p = SavePortable.preview(bytes, format);
        expect(p.collectionViews['food'], {'cards': true, 'cover': 'b'});
        expect(
          p
              .apply(SaveLibrary(), strategy: ImportStrategy.replace)
              .collectionViews['food']!['cover'],
          'b',
        );
      });
    }

    test('an item in Recently Deleted may be the cover', () {
      final l = moveToTrash(lib(), ['b'], t1);
      final out = SavePortable.export(
        l,
        SaveFormat.json,
        collectionViews: {
          'food': {'cover': 'b'},
        },
      );
      final json = jsonDecode(utf8.decode(out)) as Map;
      expect(json['collectionViews'], {
        'food': {'cover': 'b'},
      });
    });

    test('a merge remaps it to the id the item ends up with', () {
      final bytes = SavePortable.export(
        lib(),
        SaveFormat.json,
        collectionViews: {
          'food': {'cover': 'b', 'sort': 'oldest'},
        },
      );
      // Here: other things under the file's ids already.
      final here = SaveLibrary(
        collections: [SaveCollection(id: 'food', name: 'Mine')],
        bookmarks: [
          link('a', 'https://x.com/1', collection: 'food'),
          link('b', 'https://x.com/2'),
        ],
      );
      final r = SavePortable.preview(bytes, SaveFormat.json).apply(here);
      final food = r.library.collections.firstWhere((c) => c.name == 'Food');
      final cover = r.collectionViews[food.id]!['cover'] as String;
      expect(cover, isNot('b'));
      final item = r.library.bookmarks.firstWhere((x) => x.id == cover);
      expect(item.originalUrl, 'https://b.com/2');
      expect(item.collectionId, food.id);
      expect(r.collectionViews[food.id]!['sort'], 'oldest');
    });

    test('a merge points a duplicate cover at the link already here, and '
        'drops one that names a Trash item', () {
      final file = moveToTrash(
        SaveLibrary(
          collections: [
            SaveCollection(id: 'food', name: 'Food'),
            SaveCollection(id: 'tea', name: 'Tea'),
          ],
          bookmarks: [
            link('a', 'https://a.com/1', collection: 'food'),
            link('c', 'https://c.com/3', collection: 'tea'),
            link('d', 'https://d.com/4', collection: 'tea'),
          ],
        ),
        ['d'],
        t1,
      );
      final bytes = SavePortable.export(
        file,
        SaveFormat.json,
        collectionViews: {
          'food': {'cover': 'a'},
          'tea': {'cover': 'd', 'cards': true},
        },
      );
      final here = SaveLibrary(bookmarks: [link('mine', 'https://a.com/1')]);
      final r = SavePortable.preview(bytes, SaveFormat.json).apply(here);
      expect(r.collectionViews['food'], {'cover': 'mine'});
      expect(r.collectionViews['tea'], {'cards': true});
    });
  });

  group('tombstones', () {
    final now = DateTime.utc(2027, 6, 1);
    SaveLibrary graves(List<String> dates) => SaveLibrary(
      bookmarks: [link('x', 'https://x.com')],
      tombstones: [
        for (final (i, d) in dates.indexed)
          Tombstone(entity: 'bookmark', id: 't$i', deletedAt: d),
      ],
    );

    test('are kept for at least a year, whatever age is asked', () {
      final l = graves([
        '2026-07-01T00:00:00.000Z',
        '2026-05-01T00:00:00.000Z',
      ]);
      // x was saved in 2026-01, so the library's newest record is the
      // July tombstone; nothing within a year of it goes.
      expect(identical(pruneTombstones(l, now), l), isTrue);
      expect(
        identical(pruneTombstones(l, now, age: const Duration(days: 1)), l),
        isTrue,
      );
      final later = l.copyWith(
        bookmarks: [
          link(
            'x',
            'https://x.com',
          ).copyWith(updatedAt: '2027-05-30T00:00:00Z'),
        ],
      );
      expect(pruneTombstones(later, now).tombstones.map((t) => t.id), ['t0']);
      expect(tombstoneRetention.inDays, greaterThanOrEqualTo(365));
    });

    test('a clock set far ahead does not drop recent ones', () {
      final l = graves(['2026-07-01T00:00:00.000Z']);
      expect(identical(pruneTombstones(l, DateTime.utc(2040)), l), isTrue);
    });

    test('an old offline device cannot bring back a deletion within the '
        'horizon', () {
      final old = SaveLibrary(bookmarks: [link('x', 'https://x.com')]);
      // Deleted for good elsewhere 300 days after the old device last saw
      // it, then kept through a prune 11 months on.
      final purged = purgeTrash(
        moveToTrash(old, ['x'], '2026-10-28T00:00:00.000Z'),
        ['x'],
        '2026-10-28T00:00:00.000Z',
      );
      // This device stayed in use: its newest change is the day before.
      final here = pruneTombstones(
        purged.copyWith(
          bookmarks: [
            link(
              'new',
              'https://new.com',
            ).copyWith(updatedAt: '2027-09-27T00:00:00.000Z'),
          ],
        ),
        DateTime.utc(2027, 9, 28),
      );
      expect(here.tombstones.single.id, 'x');
      final merged = mergeLibraries(old, here);
      expect(merged.bookmarks.map((b) => b.id), ['new']);
      expect(merged.trash, isEmpty);
      expect(mergeLibraries(here, old).bookmarks.map((b) => b.id), ['new']);
      // Past the horizon it is forgotten, and only then could it return.
      final later = pruneTombstones(
        here.copyWith(
          bookmarks: [
            link(
              'new',
              'https://new.com',
            ).copyWith(updatedAt: '2027-11-01T00:00:00.000Z'),
          ],
        ),
        DateTime.utc(2027, 11, 1),
      );
      expect(later.tombstones, isEmpty);
    });
  });

  group('deleting a collection', () {
    SaveLibrary lib() => moveToTrash(
      SaveLibrary(
        collections: [
          SaveCollection(id: 'trip', name: 'Trips'),
          SaveCollection(id: 'hn', name: 'Hà Nội', parentId: 'trip'),
          SaveCollection(id: 'old', name: 'Old', parentId: 'hn'),
          SaveCollection(id: 'tea', name: 'Tea'),
        ],
        bookmarks: [
          link('a', 'https://a.com', collection: 'hn'),
          link('b', 'https://b.com', collection: 'hn'),
          link('c', 'https://c.com', collection: 'old'),
          link('d', 'https://d.com', collection: 'tea'),
        ],
        smartCollections: [
          SmartCollection(
            id: 's',
            name: 'Hanoi links',
            rules: [
              SmartRule(field: 'collectionId', operator: 'equals', value: 'hn'),
            ],
          ),
        ],
        savedSearches: [
          SavedSearch(id: 'q', name: 'HN', query: {'collectionId': 'hn'}),
        ],
      ),
      ['b'],
      t1,
    );

    test('unfiles its items; subcollections move up a level', () {
      final l = removeCollection(lib(), 'hn', now: t1);
      expect(l.collections.map((c) => c.id), ['trip', 'old', 'tea']);
      expect(l.collections.firstWhere((c) => c.id == 'old').parentId, 'trip');
      expect(l.bookmarks.firstWhere((b) => b.id == 'a').collectionId, isNull);
      expect(l.bookmarks.firstWhere((b) => b.id == 'c').collectionId, 'old');
      expect(l.tombstones.single.id, 'hn');
      expect(l.tombstones.single.entity, 'collection');
      // Its Trash item comes back to Not sorted.
      expect(l.trash.single.collectionId, isNull);
      final back = restoreFromTrash(l, ['b'], t1);
      expect(back.bookmarks.firstWhere((b) => b.id == 'b').collectionId, null);
      // Filters naming it are left alone.
      expect(l.smartCollections.single.rules.single.value, 'hn');
      expect(l.savedSearches.single.query['collectionId'], 'hn');
    });

    test('a top collection\'s children become top-level', () {
      final l = removeCollection(lib(), 'trip', now: t1);
      expect(l.collections.firstWhere((c) => c.id == 'hn').parentId, isNull);
      expect(l.bookmarks.where((b) => b.collectionId == 'hn'), hasLength(1));
    });

    test('moves its items, Trash ones and filters to another collection', () {
      final l = removeCollection(
        lib(),
        'hn',
        now: t1,
        contents: CollectionContents.move,
        moveTo: 'tea',
      );
      final a = l.bookmarks.firstWhere((b) => b.id == 'a');
      expect(a.collectionId, 'tea');
      expect(a.updatedAt, t1);
      expect(a.rev, 1);
      expect(l.trash.single.collectionId, 'tea');
      expect(l.trash.single.deletedAt, t1);
      expect(
        restoreFromTrash(l, [
          'b',
        ], t1).bookmarks.firstWhere((b) => b.id == 'b').collectionId,
        'tea',
      );
      expect(l.smartCollections.single.rules.single.value, 'tea');
      expect(l.savedSearches.single.query['collectionId'], 'tea');
    });

    test('may move its items into its own subcollection', () {
      final l = removeCollection(
        lib(),
        'hn',
        now: t1,
        contents: CollectionContents.move,
        moveTo: 'old',
      );
      expect(l.bookmarks.firstWhere((b) => b.id == 'a').collectionId, 'old');
      expect(l.collections.firstWhere((c) => c.id == 'old').parentId, 'trip');
    });

    test('sends its items to Recently Deleted, restorable to Not sorted', () {
      final l = removeCollection(
        lib(),
        'hn',
        now: t1,
        contents: CollectionContents.trash,
      );
      expect(l.bookmarks.map((b) => b.id), ['c', 'd']);
      expect(l.trash.map((b) => b.id).toSet(), {'a', 'b'});
      final back = restoreFromTrash(l, ['a'], t1);
      expect(back.bookmarks.firstWhere((b) => b.id == 'a').collectionId, null);
    });

    test('refuses a missing target; an unknown collection changes nothing', () {
      for (final to in [null, 'hn', 'nope']) {
        expect(
          () => removeCollection(
            lib(),
            'hn',
            now: t1,
            contents: CollectionContents.move,
            moveTo: to,
          ),
          throwsFormatException,
        );
      }
      final l = lib();
      expect(identical(removeCollection(l, 'nope', now: t1), l), isTrue);
    });

    test('another device learns it by sync, items to Not sorted', () {
      final other = lib();
      final here = removeCollection(lib(), 'hn', now: t1);
      final merged = mergeLibraries(other, here);
      expect(merged.collections.any((c) => c.id == 'hn'), isFalse);
      expect(
        merged.collections.firstWhere((c) => c.id == 'old').parentId,
        'trip',
      );
      expect(
        merged.bookmarks.firstWhere((b) => b.id == 'a').collectionId,
        isNull,
      );
    });
  });

  group('a damaged collection tree', () {
    Map<String, dynamic> raw() => {
      'format': 'handy-save',
      'version': 2,
      'collections': [
        {'id': 'kid', 'name': 'Kid', 'parentId': 'lost'},
        {'id': 'a', 'name': 'A', 'parentId': 'b'},
        {'id': 'b', 'name': 'B', 'parentId': 'a'},
      ],
      'bookmarks': [
        link('x', 'https://x.com', collection: 'kid').toJson(),
        link('y', 'https://y.com', collection: 'gone').toJson(),
      ],
    };

    test('reads with orphans at the top and cycles cut', () {
      final l = SaveLibrary.fromJson(raw());
      expect(l.collections.firstWhere((c) => c.id == 'kid').parentId, isNull);
      final a = l.collections.firstWhere((c) => c.id == 'a');
      final b = l.collections.firstWhere((c) => c.id == 'b');
      expect([a.parentId, b.parentId].where((p) => p == null), hasLength(1));
      expect(l.bookmarks.firstWhere((x) => x.id == 'x').collectionId, 'kid');
      expect(l.bookmarks.firstWhere((x) => x.id == 'y').collectionId, isNull);
    });

    test('a backup with one still restores', () {
      final p = SavePortable.preview(
        utf8.encode(jsonEncode(raw())),
        SaveFormat.json,
      );
      expect(p.validCount, 2);
    });

    test('building one in code is still refused', () {
      expect(
        () => SaveLibrary(
          collections: [SaveCollection(id: 'k', name: 'K', parentId: 'lost')],
        ),
        throwsFormatException,
      );
    });

    test('sync lifts an orphan to the top with its look intact', () {
      final parent = SaveCollection(id: 'p', name: 'P');
      final kid = SaveCollection(
        id: 'k',
        name: 'K',
        parentId: 'p',
        color: '#2E7D32',
        icon: 'tea',
        description: 'Trà',
        position: 4,
      );
      final mine = SaveLibrary(collections: [parent, kid]);
      final theirs = withCollectionTombstones(
        SaveLibrary(collections: [parent]),
        ['p'],
        t1,
      );
      final k = mergeLibraries(mine, theirs).collections.single;
      expect(k.parentId, isNull);
      expect(
        (k.color, k.icon, k.description, k.position),
        ('#2E7D32', 'tea', 'Trà', 4),
      );
    });
  });
}
