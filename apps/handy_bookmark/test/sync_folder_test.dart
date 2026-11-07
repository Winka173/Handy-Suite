import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/sync/folder_sync_io.dart';
import 'package:handy_bookmark/sync/sync_service.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'controller_test.dart' show TestStore, TestInbox;
import 'pictures_test.dart' show png;

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

Future<SaveController> device() async {
  final c = SaveController(open: () async => TestStore(), shares: TestInbox());
  await c.initialize();
  // A page read finishing mid-sync would change the library under it.
  c.preferences['automaticMetadata'] = false;
  return c;
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('hb-sync-'));
  tearDown(() async => dir.delete(recursive: true));

  test('a folder refuses writes meant for an older version', () async {
    final f = FolderSyncProvider(dir.path);
    final first = await f.write(
      'handy-bookmark/library.json',
      b('1'),
      ifAbsent: true,
    );
    await expectLater(
      f.write('handy-bookmark/library.json', b('2'), ifAbsent: true),
      throwsA(isA<SyncConflict>()),
    );
    await expectLater(
      f.write('handy-bookmark/library.json', b('2'), ifMatch: 'stale'),
      throwsA(isA<SyncConflict>()),
    );
    final second = await f.write(
      'handy-bookmark/library.json',
      b('2'),
      ifMatch: first,
    );
    expect((await f.read('handy-bookmark/library.json'))!.etag, second);
    expect(await f.list('handy-bookmark'), {'library.json'});
    await expectLater(f.read('../escape'), throwsFormatException);
  });

  test(
    'two devices meet through a folder: links, pictures and deletions',
    () async {
      final folder = FolderSyncProvider(dir.path);
      final a = await device(), b = await device();
      await a.quickSave('https://example.com/pho', title: 'Phở');
      final pic = png(320, 200);
      await a.addPictures([(bytes: pic, name: 'Thực đơn.png')]);
      await syncLibrary(a, folder);
      final r = await syncLibrary(b, folder);
      expect(r.picturesReceived, 1);
      expect(b.library!.bookmarks.map((x) => x.title).toSet(), {
        'Phở',
        'Thực đơn',
      });
      final picture = b.library!.bookmarks.firstWhere((x) => x.isImage);
      expect(await b.store!.media(picture.media!.id), pic);

      // B deletes the link; A learns it on its next sync.
      final link = b.library!.bookmarks.firstWhere((x) => x.hasUrl);
      await b.update((l) => moveToTrash(l, [link.id], saveTime()));
      await syncLibrary(b, folder);
      await syncLibrary(a, folder);
      expect(a.library!.bookmarks.where((x) => x.hasUrl), isEmpty);
      expect(a.library!.trash.single.id, link.id);
      a.dispose();
      b.dispose();
    },
  );
}
