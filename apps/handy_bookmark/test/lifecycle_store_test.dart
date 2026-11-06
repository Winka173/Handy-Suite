import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/platform/store_native.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'controller_test.dart' show TestInbox, TestStore;
import 'pictures_test.dart' show png;

ReadingCopy copy(String url, String text) => ReadingCopy(
  url: url,
  title: 'Bài đọc',
  blocks: [ReadingBlock('p', text)],
  savedAt: '2026-11-02T08:00:00.000Z',
);

String ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  final stores = <NativeBookmarkStore>[];
  final controllers = <SaveController>[];

  Future<(SaveController, NativeBookmarkStore)> device(String name) async {
    final store = await NativeBookmarkStore.open(
      '${dir.path}${Platform.pathSeparator}$name.sqlite',
    );
    stores.add(store);
    final c = SaveController(open: () async => store, shares: TestInbox());
    controllers.add(c);
    await c.initialize();
    expect(c.error, isNull);
    return (c, store);
  }

  setUp(() async => dir = await Directory.systemTemp.createTemp('hb-life-'));
  tearDown(() async {
    for (final c in controllers) {
      c.store = null; // The test owns and awaits each worker's close.
      c.dispose();
    }
    controllers.clear();
    for (final s in stores) {
      await s.close();
    }
    stores.clear();
    await dir.delete(recursive: true);
  });

  test('a Trash item\'s offline copy goes into a ZIP backup and comes back '
      'with the item on a fresh device', () async {
    final (a, storeA) = await device('a');
    final saved = await a.quickSave(
      'https://vnexpress.net/pho-ha-noi https://b.org/bun-cha',
    );
    final kept = saved.first, gone = saved.last;
    await a.putReadingCopies({
      kept.id: copy(kept.originalUrl, 'Phở bò tái'),
      gone.id: copy(gone.originalUrl, 'Bún chả Hàng Mành'),
    });
    await a.update((l) => moveToTrash(l, [gone.id], saveTime()));
    expect(a.readingIds.keys, [kept.id], reason: 'only live copies show');

    final read = await a.readingCopiesForBackup();
    expect(read.copies.keys.toSet(), {kept.id, gone.id});
    expect(read.unreadable, 0);
    final out = SavePortable.exportWithReport(
      a.library!,
      SaveFormat.zip,
      readingCopies: read.copies,
      unreadableReadingCopies: read.unreadable,
    );
    expect(out.readingIncluded, 2);
    expect(out.complete, isTrue);

    // A new device restores the file (replace, as the import does).
    final (b, storeB) = await device('b');
    final preview = SavePortable.preview(
      out.bytes,
      SaveFormat.zip,
      current: b.library,
    );
    expect(preview.readingCopies.length, 2);
    final applied = preview.apply(b.library!, strategy: ImportStrategy.replace);
    await b.update((_) => applied.library);
    await b.putReadingCopies(applied.readingCopies);
    expect(b.library!.trash.single.id, gone.id);
    expect(b.readingIds.keys, [kept.id]);
    expect(await storeB.readingCopy(gone.id), isNull, reason: 'in Trash');
    expect(
      (await storeB.readingCopies()).keys.toSet(),
      {kept.id, gone.id},
      reason: 'the next backup carries it again',
    );

    await b.update((l) => restoreFromTrash(l, [gone.id], saveTime()));
    final back = await b.readingCopy(gone.id);
    expect(back!.blocks.single.text, 'Bún chả Hàng Mành');
    expect(b.readingIds, contains(gone.id));
    expect(await storeB.integrity(), 'ok');
    expect(await storeA.integrity(), 'ok');
  });

  test('backups leave out Undo-only copies and expired Trash copies; a copy '
      'for an unknown item is refused whole', () async {
    final (c, store) = await device('c');
    final saved = await c.quickSave(
      'https://a.com/1 https://a.com/2 https://a.com/3',
    );
    await c.putReadingCopies({
      for (final b in saved) b.id: copy(b.originalUrl, 'Văn bản ${b.id}'),
    });
    // 1: deleted outright (kept only for Undo); 2: in Trash for 40 days
    // (expired, not yet tidied); 3: in Trash today.
    await c.update(
      (l) => l.copyWith(
        bookmarks: [
          for (final b in l.bookmarks)
            if (b.id != saved[0].id) b,
        ],
      ),
    );
    await c.update(
      (l) => moveToTrash(l, [saved[1].id], ago(const Duration(days: 40))),
    );
    await c.update((l) => moveToTrash(l, [saved[2].id], saveTime()));
    expect((await store.readingCopies()).keys, [saved[2].id]);

    await expectLater(
      store.putReadingCopies({
        saved[2].id: copy(saved[2].originalUrl, 'mới').toJson(),
        'nobody': copy('https://x.com', 'x').toJson(),
      }),
      throwsStateError,
    );
    final kept = await c.readingCopiesForBackup();
    expect(
      kept.copies[saved[2].id]!.blocks.single.text,
      'Văn bản ${saved[2].id}',
    );
  });

  group('housekeeping when the library opens', () {
    test('expires Trash after 30 days, forgets deletions older than the '
        'sync horizon, and reclaims only pictures nothing uses', () async {
      final store = TestStore()
        ..now = () => DateTime.now().subtract(const Duration(hours: 2));
      final c = SaveController(open: () async => store, shares: TestInbox());
      await c.initialize();
      final added = (await c.addPictures([
        (bytes: png(40, 30), name: 'live.png'),
        (bytes: png(41, 30), name: 'trash.png'),
        (bytes: png(42, 30), name: 'expired.png'),
      ])).added;
      expect(added, hasLength(3));
      final [live, recent, old] = added;
      await c.update((l) => moveToTrash(l, [recent.id], saveTime()));
      await c.update(
        (l) => moveToTrash(l, [old.id], ago(const Duration(days: 31))),
      );
      await c.update(
        (l) => l.copyWith(
          tombstones: [
            Tombstone(
              entity: 'bookmark',
              id: 'ancient',
              deletedAt: ago(const Duration(days: 400)),
            ),
            Tombstone(
              entity: 'collection',
              id: 'recent',
              deletedAt: ago(const Duration(days: 300)),
            ),
          ],
        ),
      );
      c.dispose();
      store.now = DateTime.now; // Pictures were stored two hours ago.

      // The next opening tidies.
      final again = SaveController(
        open: () async => store,
        shares: TestInbox(),
      );
      await again.initialize();
      final l = again.library!;
      expect(l.bookmarks.single.id, live.id);
      expect(l.trash.single.id, recent.id);
      expect(l.tombstones.map((t) => t.id).toSet(), {'recent', old.id});
      expect(store.ownedMedia.keys.toSet(), {live.media!.id, recent.media!.id});
      again.dispose();
    });

    test('a failing write leaves everything as it was, and pictures in use '
        'are still kept', () async {
      final store = TestStore()
        ..now = () => DateTime.now().subtract(const Duration(hours: 2));
      final c = SaveController(open: () async => store, shares: TestInbox());
      await c.initialize();
      final [pic] = (await c.addPictures([
        (bytes: png(43, 30), name: 'old.png'),
      ])).added;
      await c.update(
        (l) => moveToTrash(l, [pic.id], ago(const Duration(days: 31))),
      );
      store.now = DateTime.now; // Stored two hours ago.
      store.fail = true;
      await c.tidy();
      expect(c.library!.trash.single.id, pic.id);
      expect(store.ownedMedia.keys, [pic.media!.id]);
      store.fail = false;
      await c.tidy();
      expect(c.library!.trash, isEmpty);
      expect(store.ownedMedia, isEmpty);
      c.dispose();
    });
  });
}
