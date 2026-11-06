import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

String at(int minute) => DateTime.utc(2026, 11, 6, 9, minute).toIso8601String();

Bookmark link(String id, {int edited = 0, String title = '', String? col}) {
  final u = UrlTools.normalize('https://example.com/$id');
  return Bookmark(
    id: id,
    originalUrl: u.originalUrl,
    normalizedUrl: u.normalizedUrl,
    canonicalUrl: u.canonicalUrl,
    platform: u.platform,
    contentType: u.contentType,
    sourceDomain: u.sourceDomain,
    title: title.isEmpty ? id : title,
    collectionId: col,
    savedAt: at(0),
    updatedAt: at(edited),
  );
}

/// A device: its library and its pictures.
class Device implements SyncMedia {
  SaveLibrary library;
  final pictures = <String, Uint8List>{};
  Device([SaveLibrary? l]) : library = l ?? SaveLibrary();
  @override
  Future<Uint8List?> original(String id) async => pictures[id];
  @override
  Future<void> store(MediaRef ref, Uint8List original) async =>
      pictures[ref.id] = original;

  Future<SyncResult> sync(SyncProvider remote) async {
    final r = await syncOnce(local: library, remote: remote, media: this);
    library = mergeLibraries(library, r.library);
    return r;
  }
}

String snapshot(SaveLibrary l) => jsonEncode(l.toJson());

void main() {
  test('what one device saves reaches the other', () async {
    final cloud = MemorySyncProvider();
    final a = Device(SaveLibrary(bookmarks: [link('one')]));
    final b = Device();
    expect((await a.sync(cloud)).wrote, isTrue);
    await b.sync(cloud);
    expect(b.library.bookmarks.single.id, 'one');
  });

  test('the later edit wins on both devices, and they end identical', () async {
    final cloud = MemorySyncProvider();
    final a = Device(
      SaveLibrary(bookmarks: [link('x', edited: 5, title: 'A')]),
    );
    final b = Device(
      SaveLibrary(bookmarks: [link('x', edited: 9, title: 'B')]),
    );
    await a.sync(cloud);
    await b.sync(cloud);
    await a.sync(cloud);
    expect(a.library.bookmarks.single.title, 'B');
    expect(snapshot(a.library), snapshot(b.library));
  });

  test('a delete wins over an older edit; a newer edit brings it back', () {
    final edited = SaveLibrary(bookmarks: [link('x', edited: 3)]);
    final deleted = moveToTrash(SaveLibrary(bookmarks: [link('x')]), [
      'x',
    ], at(7));
    var m = mergeLibraries(edited, deleted);
    expect(m.bookmarks, isEmpty);
    expect(m.trash.single.id, 'x');
    final later = SaveLibrary(bookmarks: [link('x', edited: 12)]);
    m = mergeLibraries(later, deleted);
    expect(m.bookmarks.single.id, 'x');
    expect(m.trash, isEmpty);
  });

  test(
    'deleted for good stays gone on a device that never saw it deleted',
    () async {
      final cloud = MemorySyncProvider();
      final a = Device(SaveLibrary(bookmarks: [link('x'), link('y')]));
      final b = Device();
      await a.sync(cloud);
      await b.sync(cloud);
      a.library = purgeTrash(moveToTrash(a.library, ['x'], at(5)), [
        'x',
      ], at(6));
      await a.sync(cloud);
      await b.sync(cloud);
      expect(b.library.bookmarks.map((e) => e.id), ['y']);
      expect(b.library.trash, isEmpty);
      expect(b.library.tombstones.single.id, 'x');
    },
  );

  test(
    'a collection deleted on one device sends its items to Not sorted',
    () async {
      final cloud = MemorySyncProvider();
      final food = SaveCollection(id: 'food', name: 'Food');
      final a = Device(
        SaveLibrary(
          collections: [food],
          bookmarks: [link('x', col: 'food')],
        ),
      );
      final b = Device();
      await a.sync(cloud);
      await b.sync(cloud);
      b.library = withCollectionTombstones(
        b.library.copyWith(
          collections: [],
          bookmarks: [
            for (final x in b.library.bookmarks)
              x.copyWith(collectionId: null, updatedAt: at(4)),
          ],
        ),
        ['food'],
        at(4),
      );
      await b.sync(cloud);
      await a.sync(cloud);
      expect(a.library.collections, isEmpty);
      expect(a.library.bookmarks.single.collectionId, isNull);
    },
  );

  test('pictures travel by content and are checked on arrival', () async {
    final cloud = MemorySyncProvider();
    final bytes = Uint8List.fromList(List.generate(64, (i) => i));
    final id = sha256.convert(bytes).toString();
    final ref = MediaRef(
      id: id,
      mime: 'image/png',
      width: 8,
      height: 8,
      bytes: bytes.length,
      name: 'a.png',
    );
    final picture = Bookmark(
      id: 'p',
      kind: 'image',
      originalUrl: '',
      normalizedUrl: '',
      platform: 'image',
      contentType: 'image',
      media: ref,
      title: 'Bảng giá',
      savedAt: at(0),
      updatedAt: at(0),
    );
    final a = Device(SaveLibrary(bookmarks: [picture]))..pictures[id] = bytes;
    final b = Device();
    expect((await a.sync(cloud)).picturesSent, 1);
    expect((await b.sync(cloud)).picturesReceived, 1);
    expect(b.pictures[id], bytes);

    // A picture altered in the folder is refused.
    final c = Device();
    cloud.files['$syncRoot/media/$id'] = (Uint8List.fromList([1, 2, 3]), 'x');
    await expectLater(c.sync(cloud), throwsFormatException);
    expect(c.pictures, isEmpty);
  });

  test('a write from another device in between is merged, not lost', () async {
    final cloud = MemorySyncProvider();
    final a = Device(SaveLibrary(bookmarks: [link('a')]));
    final b = Device(SaveLibrary(bookmarks: [link('b')]));
    cloud.beforeWrite = () => b.sync(cloud);
    final r = await a.sync(cloud);
    expect(r.attempts, 2);
    final there = decodeSyncLibrary(
      (await cloud.read('$syncRoot/library.json'))!.bytes,
    );
    expect(there.bookmarks.map((e) => e.id).toSet(), {'a', 'b'});
  });

  test(
    'a dropped connection changes nothing; the next sync completes',
    () async {
      final cloud = MemorySyncProvider();
      final a = Device(SaveLibrary(bookmarks: [link('a')]));
      cloud.failWrites = 1;
      await expectLater(a.sync(cloud), throwsStateError);
      expect(cloud.files, isEmpty);
      expect(a.library.bookmarks.single.id, 'a');
      expect((await a.sync(cloud)).wrote, isTrue);
    },
  );

  test('syncing again with nothing new writes nothing', () async {
    final cloud = MemorySyncProvider();
    final a = Device(SaveLibrary(bookmarks: [link('a')]));
    await a.sync(cloud);
    final writes = cloud.writes;
    expect((await a.sync(cloud)).wrote, isFalse);
    expect(cloud.writes, writes);
  });

  test('items merge the same whichever side is local', () {
    final x = SaveLibrary(
      bookmarks: [
        link('1', edited: 2),
        link('2', edited: 9, title: 'x2'),
      ],
    );
    final y = SaveLibrary(
      bookmarks: [
        link('1', edited: 5, title: 'y1'),
        link('2', edited: 1),
        link('3'),
      ],
    );
    String items(SaveLibrary l) => jsonEncode([
      for (final b in [...l.bookmarks]..sort((a, b) => a.id.compareTo(b.id)))
        b.toJson(),
    ]);
    expect(items(mergeLibraries(x, y)), items(mergeLibraries(y, x)));
  });

  test('anything but a sync file is refused', () {
    expect(
      () =>
          decodeSyncLibrary(Uint8List.fromList(utf8.encode('{"format":"x"}'))),
      throwsFormatException,
    );
  });
}
