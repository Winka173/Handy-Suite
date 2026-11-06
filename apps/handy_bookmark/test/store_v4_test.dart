import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/platform/store.dart';
import 'package:handy_bookmark/platform/store_native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'store_test.dart' show fixture;
import 'store_v2_test.dart' show copy;

/// A picture record and its bytes (content-addressed by SHA-256).
(Map<String, dynamic>, Uint8List, Uint8List) picture(
  int seed, {
  int size = 4000,
}) {
  final bytes = Uint8List.fromList(
    List.generate(size, (i) => (i * seed) % 251),
  );
  final id = sha256.convert(bytes).toString();
  return (
    {
      'id': id,
      'mime': 'image/png',
      'width': 1080,
      'height': 2400,
      'bytes': bytes.length,
    },
    bytes,
    Uint8List.fromList(List.generate(300, (i) => (i + seed) % 251)),
  );
}

Map<String, dynamic> imageItem(
  String id,
  Map<String, dynamic> ref, {
  String title = '',
}) => {
  'id': id,
  'kind': 'image',
  'originalUrl': '',
  'normalizedUrl': '',
  'canonicalUrl': null,
  'sourceDomain': '',
  'platform': 'image',
  'contentType': 'image',
  'collectionId': null,
  'title': title,
  'note': '',
  'tags': <String>[],
  'isFavorite': false,
  'isArchived': false,
  'isRead': false,
  'isPinned': false,
  'savedAt': '2026-11-01T00:00:00.000Z',
  'updatedAt': '2026-11-01T00:00:00.000Z',
  'lastOpenedAt': null,
  'openedCount': 0,
  'media': ref,
};

void main() {
  late Directory dir;
  late String path;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('save-v4-');
    path = '${dir.path}${Platform.pathSeparator}v4.sqlite';
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('a schema 3 database with copies and retained deleted copies becomes 4 '
      'and keeps every row', () async {
    var store = await NativeBookmarkStore.open(path);
    await store.write(upserts: [fixture(1), fixture(2), fixture(3)]);
    await store.putReadingCopies({
      'bookmark-1': copy('Active article'),
      'bookmark-3': copy('About to be deleted'),
    });
    await store.write(deletes: ['bookmark-3']);
    await store.close();
    final db = sqlite3.open(path);
    db.execute('DROP TABLE trash');
    db.execute('DROP TABLE media');
    db.execute('DROP INDEX idx_kind');
    db.execute('DROP INDEX idx_media');
    db.execute('ALTER TABLE bookmarks DROP COLUMN kind');
    db.execute('ALTER TABLE bookmarks DROP COLUMN media_id');
    db.userVersion = 3;
    db.close();

    store = await NativeBookmarkStore.open(path);
    try {
      final raw = await store.read();
      expect((raw['bookmarks'] as List).map((b) => b['id']).toSet(), {
        'bookmark-1',
        'bookmark-2',
      });
      expect(raw.containsKey('trash'), isFalse);
      expect((await store.readingCopy('bookmark-1'))!['blocks'], isNotEmpty);
      // The retained copy of the deleted link still comes back with it.
      await store.write(upserts: [fixture(3)]);
      expect(
        (await store.readingCopy('bookmark-3'))!['blocks'][0]['t'],
        'About to be deleted',
      );
      expect(((await store.search({'kind': 'link'}))['total']), 3);
    } finally {
      await store.close();
    }
    final check = sqlite3.open(path);
    try {
      expect(check.userVersion, 4);
      expect(
        check
            .select("SELECT count(*) AS n FROM bookmarks WHERE kind='link'")
            .first['n'],
        3,
      );
    } finally {
      check.close();
    }
  });

  test('Trash keeps the offline copy for 30 days; restore brings it back, '
      'deleting for good drops it; all of it survives a restart', () async {
    var store = await NativeBookmarkStore.open(path);
    await store.write(upserts: [fixture(1), fixture(2)]);
    await store.putReadingCopies({'bookmark-1': copy('Kept while in Trash')});
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> trashed(int i) => {
      ...fixture(i),
      'deletedAt': deletedAt,
      'rev': 1,
    };
    await store.write(
      deletes: ['bookmark-1', 'bookmark-2'],
      trashUpserts: [trashed(1), trashed(2)],
    );
    expect(await store.readingCopy('bookmark-1'), isNull, reason: 'not active');
    await store.close();
    final db = sqlite3.open(path);
    try {
      final expires =
          db
                  .select(
                    "SELECT expires_at FROM reading_trash WHERE bookmark_id='bookmark-1'",
                  )
                  .first['expires_at']
              as int;
      final days = Duration(
        milliseconds:
            expires - DateTime.parse(deletedAt).millisecondsSinceEpoch,
      ).inDays;
      expect(days, 30);
    } finally {
      db.close();
    }

    store = await NativeBookmarkStore.open(path);
    try {
      final raw = await store.read();
      expect((raw['trash'] as List).map((b) => b['id']).toSet(), {
        'bookmark-1',
        'bookmark-2',
      });
      expect((raw['bookmarks'] as List), isEmpty);
      expect(
        (await store.search({}))['total'],
        0,
        reason: 'Trash is not searched',
      );
      // Restore 1, delete 2 for good.
      await store.write(
        upserts: [fixture(1)],
        trashDeletes: ['bookmark-1', 'bookmark-2'],
      );
      expect(
        (await store.readingCopy('bookmark-1'))!['blocks'][0]['t'],
        'Kept while in Trash',
      );
      final after = await store.read();
      expect(after.containsKey('trash'), isFalse);
      expect((after['bookmarks'] as List).single['id'], 'bookmark-1');
    } finally {
      await store.close();
    }
  });

  test('pictures are stored once, read back exactly, and reclaimed only when '
      'nothing uses them and the grace period has passed', () async {
    final store = await NativeBookmarkStore.open(path);
    try {
      final (refA, bytesA, previewA) = picture(3);
      final (refB, bytesB, previewB) = picture(7);
      await store.putMedia(refA, bytesA, previewA);
      await store.putMedia(refA, bytesA, previewA);
      await store.putMedia(refB, bytesB, previewB);
      expect((await store.mediaIndex()).length, 2);
      expect(await store.media(refA['id'] as String), bytesA);
      expect(await store.media(refA['id'] as String, preview: true), previewA);
      await store.write(
        upserts: [imageItem('img-1', refA, title: 'Thực đơn Đà Nẵng')],
      );
      // Nothing is old enough yet.
      expect(await store.collectMedia({}), 0);
      // With no grace: B is unused and goes; A is used by an item and stays.
      expect(await store.collectMedia({}, grace: Duration.zero), 1);
      expect((await store.mediaIndex()).keys, [refA['id']]);
      // Moved to Trash it still counts as used.
      await store.write(
        deletes: ['img-1'],
        trashUpserts: [
          {
            ...imageItem('img-1', refA),
            'deletedAt': '2026-11-02T00:00:00.000Z',
          },
        ],
      );
      expect(await store.collectMedia({}, grace: Duration.zero), 0);
      await store.write(trashDeletes: ['img-1']);
      expect(await store.collectMedia({}, grace: Duration.zero), 1);
      expect(await store.mediaIndex(), isEmpty);
      // A record that does not match its bytes is refused before writing.
      expect(
        () => store.putMedia({...refB, 'bytes': 1}, bytesB, previewB),
        throwsFormatException,
      );
    } finally {
      await store.close();
    }
  });

  test(
    'search finds pictures, filters by kind and ignores Vietnamese marks',
    () async {
      final store = await NativeBookmarkStore.open(path);
      try {
        final (ref, bytes, preview) = picture(5);
        await store.putMedia(ref, bytes, preview);
        await store.write(
          upserts: [
            fixture(1),
            imageItem('img-1', ref, title: 'Thực đơn quán Đà Nẵng'),
          ],
        );
        Future<List> ids(Map<String, dynamic> q) async =>
            ((await store.search(q))['bookmarks'] as List)
                .map((b) => b['id'])
                .toList();
        expect(await ids({'text': 'da nang'}), ['img-1']);
        expect(await ids({'text': 'Đà Nẵng'}), ['img-1']);
        expect(await ids({'text': 'viet nam'}), ['bookmark-1']);
        expect(await ids({'kind': 'image'}), ['img-1']);
        expect(await ids({'kind': 'link'}), ['bookmark-1']);
        expect(
          jsonEncode((await store.read())['bookmarks']),
          contains('"kind":"image"'),
        );
      } finally {
        await store.close();
      }
    },
  );

  test('constants match the engine rules', () {
    expect(trashRetention, const Duration(days: 30));
    expect(mediaGrace, const Duration(minutes: 10));
  });
}
