import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/services/media_import.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import 'controller_test.dart' show TestStore, TestInbox;
import 'new_flows_test.dart' show OneFile, boot, settle;
import 'widget_test.dart' show tapKey;

Uint8List png(int w, int h, {bool alpha = false}) {
  final image = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  img.fill(
    image,
    color: alpha
        ? img.ColorRgba8(20, 120, 200, 90)
        : img.ColorRgb8(20, 120, 200),
  );
  return img.encodePng(image);
}

/// A landscape JPEG whose EXIF says "rotate 90°": a phone photo held upright.
Uint8List rotatedJpeg() {
  final image = img.Image(width: 400, height: 300);
  img.fill(image, color: img.ColorRgb8(200, 80, 40));
  image.exif.imageIfd.orientation = 6;
  return img.encodeJpg(image);
}

void main() {
  group('preparing a picture', () {
    test(
      'a see-through PNG gets a white JPEG preview; the original is kept as is',
      () {
        final bytes = png(1600, 900, alpha: true);
        final p = preparePicture(bytes, name: 'Bảng giá.png');
        expect(p.ref.mime, 'image/png');
        expect((p.ref.width, p.ref.height), (1600, 900));
        expect(p.original, same(bytes));
        expect(pictureMime(p.preview), 'image/jpeg');
        final small = img.decodeJpg(p.preview)!;
        expect(small.width, previewEdge);
        expect(p.ref.name, 'Bảng giá.png');
      },
    );

    test('a phone photo is reported upright; its bytes are not rewritten', () {
      final bytes = rotatedJpeg();
      final p = preparePicture(bytes, name: 'IMG_2041.jpg');
      expect((p.ref.width, p.ref.height), (300, 400));
      expect(p.original, same(bytes));
      expect(pictureTitle('IMG_2041.jpg'), '');
      expect(pictureTitle('Screenshot_20261106-091200.png'), '');
      expect(pictureTitle('Thực đơn quán phở.webp'), 'Thực đơn quán phở');
    });

    test('unusable files are refused before anything is stored', () {
      expect(() => preparePicture(Uint8List(0)), throwsFormatException);
      expect(
        () => preparePicture(Uint8List.fromList('GIF89a....'.codeUnits)),
        throwsFormatException,
      );
      // A small file that claims 30000 × 30000 pixels (a decompression bomb).
      final bomb = Uint8List.fromList(png(8, 8));
      final view = ByteData.sublistView(bomb);
      view.setUint32(16, 30000);
      view.setUint32(20, 30000);
      expect(() => preparePicture(bomb), throwsFormatException);
    });
  });

  group('picture items', () {
    test('saved once by content, found as images, reclaimed only after delete '
        'for good and the grace period', () async {
      final store = TestStore();
      var clock = DateTime.utc(2026, 11, 6, 9);
      store.now = () => clock;
      final c = SaveController(open: () async => store, shares: TestInbox());
      await c.initialize();
      final bytes = png(800, 600);
      final first = await c.addPictures([(bytes: bytes, name: 'Thực đơn.png')]);
      expect(first.added.single.isImage, isTrue);
      expect(first.added.single.title, 'Thực đơn');
      expect(store.ownedMedia.length, 1);
      final again = await c.addPictures([(bytes: bytes, name: 'copy.png')]);
      expect(again.added, isEmpty);
      expect(again.existing.single.id, first.added.single.id);
      final found = await store.search({'kind': 'image', 'text': 'thuc don'});
      expect(found['total'], 1);

      final id = first.added.single.id;
      await c.update((l) => moveToTrash(l, [id], saveTime()));
      clock = clock.add(const Duration(hours: 1));
      expect(
        await store.collectMedia(mediaInUse(c.library!)),
        0,
        reason: 'in Trash',
      );
      await c.update((l) => purgeTrash(l, [id], saveTime()));
      expect(await store.collectMedia(mediaInUse(c.library!)), 1);
      expect(store.ownedMedia, isEmpty);
      c.dispose();
    });

    testWidgets('Add a picture saves an image item; its page shows the picture '
        'and none of the link-only tools', (t) async {
      final files = OneFile()
        ..next = ImportedBytes('Bản đồ quán.png', png(1200, 800));
      final (c, _) = await boot(t, files: files);
      await tapKey(t, 'save-new');
      await tapKey(t, 'save-photo');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(t);
      final item = c.library!.bookmarks.firstWhere((b) => b.isImage);
      expect(item.title, 'Bản đồ quán');
      expect(find.text('Picture saved.'), findsOneWidget);
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).pushNamed('/bookmark/${item.id}');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(t);
      expect(find.byKey(const Key('detail-picture')), findsOneWidget);
      expect(find.byKey(const Key('detail-view-picture')), findsOneWidget);
      expect(find.byKey(const Key('save-open-original')), findsNothing);
      expect(find.byKey(const Key('detail-copy')), findsNothing);
      expect(find.byKey(const Key('detail-check')), findsNothing);
      expect(find.byKey(const Key('detail-copy-save')), findsNothing);
      await tapKey(t, 'detail-view-picture');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(t);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });

  testWidgets("a chosen link picture is the person's own; reset brings the "
      "page's picture back", (t) async {
    final files = OneFile()..next = ImportedBytes('cover.png', png(600, 400));
    final (c, _) = await boot(t, files: files);
    final link = c.library!.bookmarks.first;
    Navigator.of(
      t.element(find.byType(Scaffold).first),
    ).pushNamed('/bookmark/${link.id}');
    await settle(t);
    await tapKey(t, 'detail-tools');
    await tapKey(t, 'detail-thumbnail');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(t);
    final chosen = c.library!.bookmarks.firstWhere((b) => b.id == link.id);
    expect(chosen.media, isNotNull);
    expect(chosen.isImage, isFalse, reason: 'still a link');
    expect((c.store as TestStore).ownedMedia.keys, [chosen.media!.id]);
    expect(mediaInUse(c.library!), {chosen.media!.id});
    await tapKey(t, 'detail-thumbnail-reset');
    await settle(t);
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == link.id).media,
      isNull,
    );
    expect(mediaInUse(c.library!), isEmpty);
  });
}
