import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/bookmark/rename.dart';
import 'package:handy_bookmark/bookmark/share_item.dart';
import 'package:handy_bookmark/services/metadata_types.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/share.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import 'detail_focus_ui_test.dart' show start, openItem;
import 'link_tasks_test.dart' show FakeNet;
import 'controller_test.dart' show TestStore;
import 'new_flows_test.dart' show NetController, settle;
import 'pictures_test.dart' show png;
import 'widget_test.dart' show tapKey;

/// Records what would reach the OS share sheet.
class FakeSharer implements ItemSharer {
  @override
  bool supported = true;
  final texts = <({String text, String? subject})>[];
  final files = <({String name, Uint8List bytes, String mime})>[];
  LocalShareResult result = LocalShareResult.selected;
  @override
  Future<LocalShareResult> text(
    String text, {
    String? subject,
    required Rect origin,
  }) async {
    texts.add((text: text, subject: subject));
    return result;
  }

  @override
  Future<LocalShareResult> bytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    required Rect origin,
  }) async {
    files.add((name: name, bytes: bytes, mime: mimeType));
    return result;
  }
}

/// A page whose details always come back with the site's own title.
class TitledNet extends FakeNet {
  @override
  Future<MetadataResult> fetch(
    String url, {
    CancellationToken? cancellation,
  }) async => const MetadataResult(
    status: 'complete',
    title: 'The site title',
    description: 'From the page',
  );
}

/// A camera photo: a JPEG whose EXIF names a camera and a place.
Uint8List cameraJpeg() {
  final image = img.Image(width: 64, height: 48);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  image.exif.imageIfd['Make'] = 'TestCam';
  image.exif.imageIfd['ImageDescription'] = 'Hồ Gươm, Hà Nội';
  return img.encodeJpg(image);
}

Future<void> waitFor(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
  }
  await t.pumpAndSettle();
}

Future<String> addPictureBytes(
  WidgetTester t,
  dynamic c,
  Uint8List bytes,
  String name,
) async {
  unawaited(c.addPictures([(bytes: bytes, name: name)]));
  await waitFor(
    t,
    () => (c.library!.bookmarks as List<Bookmark>).any((b) => b.isImage),
  );
  return (c.library!.bookmarks as List<Bookmark>)
      .firstWhere((b) => b.isImage)
      .id;
}

Future<void> typeName(WidgetTester t, String name) async {
  await t.enterText(find.byKey(const Key('rename-field')), name);
  await t.pump();
  await tapKey(t, 'rename-save');
  await settle(t);
}

Future<(NetController, TestStore)> startController(FakeNet net) async {
  final store = TestStore();
  final c = NetController(store, net);
  await c.initialize();
  await c.quickSave('https://a.com/one');
  return (c, store);
}

void main() {
  late FakeSharer sharer;
  setUp(() => itemSharer = sharer = FakeSharer());

  group('rename', () {
    testWidgets('from the detail: autofocused, saved as the person\'s name, '
        'the address and id kept, and every list shows it', (t) async {
      final (c, _) = await start(t);
      final before = c.library!.bookmarks.first;
      await openItem(t, before.id);
      await tapKey(t, 'detail-rename');
      expect(find.byKey(const Key('rename-sheet')), findsOneWidget);
      final field = t.widget<TextField>(find.byKey(const Key('rename-field')));
      expect(field.autofocus, isTrue);
      expect(field.controller!.text, 'Page one');
      // Unchanged or blank names cannot be saved.
      expect(
        t.widget<FilledButton>(find.byKey(const Key('rename-save'))).onPressed,
        isNull,
      );
      await typeName(t, '  Phở ngon nhất phố  ');
      final after = c.library!.bookmarks.firstWhere((b) => b.id == before.id);
      expect(after.title, 'Phở ngon nhất phố');
      expect(after.metadataSource, 'user');
      expect(after.originalUrl, before.originalUrl);
      expect(after.normalizedUrl, before.normalizedUrl);
      expect(find.byKey(const Key('rename-sheet')), findsNothing);
      expect(find.text('Renamed.'), findsOneWidget);
      expect(find.text('Phở ngon nhất phố'), findsWidgets);
      // Back in the library the row has the new name too.
      Navigator.of(t.element(find.byKey(const Key('detail')))).pop();
      await settle(t, 200);
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).pushNamed('/place/all');
      await settle(t, 200);
      expect(find.text('Phở ngon nhất phố'), findsWidgets);
    });

    testWidgets('Cancel changes nothing; a failed write keeps the sheet open '
        'with the reason and the old name', (t) async {
      final (c, store) = await start(t);
      final id = c.library!.bookmarks.first.id;
      await openItem(t, id);
      await tapKey(t, 'detail-rename');
      await t.enterText(find.byKey(const Key('rename-field')), 'Other');
      await tapKey(t, 'rename-cancel');
      expect(c.library!.bookmarks.first.title, 'Page one');
      await tapKey(t, 'detail-rename');
      store.fail = true;
      await typeName(t, 'Will not stick');
      store.fail = false;
      expect(find.byKey(const Key('rename-sheet')), findsOneWidget);
      expect(find.textContaining('Not saved'), findsOneWidget);
      expect(c.library!.bookmarks.first.title, 'Page one');
      // Typing again clears the error; the name typed is still there.
      expect(
        t
            .widget<TextField>(find.byKey(const Key('rename-field')))
            .controller!
            .text,
        'Will not stick',
      );
    });

    testWidgets('from a row\'s "…": Open details comes first, then Rename', (
      t,
    ) async {
      final (c, _) = await start(t);
      final id = c.library!.bookmarks.first.id;
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).pushNamed('/place/all');
      await settle(t, 200);
      await tapKey(t, 'details-$id');
      final order = [
        'item-details',
        'item-rename',
        'item-share',
        'item-move',
        'item-delete',
      ].map((k) => t.getTopLeft(find.byKey(Key(k))).dy).toList();
      expect(order, [...order]..sort());
      await tapKey(t, 'item-rename');
      await typeName(t, 'Bún chả Hàng Mành');
      expect(
        c.library!.bookmarks.firstWhere((b) => b.id == id).title,
        'Bún chả Hàng Mành',
      );
      await settle(t, 200);
      expect(find.text('Bún chả Hàng Mành'), findsOneWidget);
      // Open details still opens the item.
      await tapKey(t, 'details-$id');
      await tapKey(t, 'item-details');
      expect(find.byKey(const Key('detail')), findsOneWidget);
    });

    testWidgets('a picture keeps its file when renamed', (t) async {
      final (c, _) = await start(t);
      final id = await addPictureBytes(t, c, png(300, 200), 'IMG_2041.png');
      final media = c.library!.bookmarks.firstWhere((b) => b.id == id).media!;
      await openItem(t, id);
      await tapKey(t, 'detail-rename');
      await typeName(t, 'Thực đơn quán');
      final after = c.library!.bookmarks.firstWhere((b) => b.id == id);
      expect(after.title, 'Thực đơn quán');
      expect(after.media!.id, media.id);
      expect(after.media!.bytes, media.bytes);
      expect(after.isImage, isTrue);
    });

    test('a renamed title survives reading the page again', () async {
      final (c, store) = await startController(TitledNet());
      final id = c.library!.bookmarks.first.id;
      await c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              b.id == id ? renamedItem(b, 'Mine') : b,
          ],
        ),
      );
      await c.refreshMetadata(id);
      final b = c.library!.bookmarks.firstWhere((b) => b.id == id);
      expect(b.title, 'Mine');
      expect(b.metadataSource, 'user');
      expect(b.metadataStatus, 'complete');
      expect(store, isNotNull);
      c.dispose();
    });

    test('a renamed item keeps its name through a ZIP backup and back out '
        'of Recently Deleted', () {
      final now = DateTime.utc(2026, 11, 6).toIso8601String();
      final item = Bookmark(
        id: 'b1',
        originalUrl: 'https://a.com/pho?utm_source=x',
        normalizedUrl: 'https://a.com/pho',
        title: 'Phở',
        savedAt: now,
        updatedAt: now,
        metadataSource: 'html',
      );
      final renamed = renamedItem(item, 'Phở của mẹ');
      final library = SaveLibrary(bookmarks: [renamed]);
      final zip = SavePortable.export(library, SaveFormat.zip);
      final back = SavePortable.preview(
        zip,
        SaveFormat.zip,
      ).library.bookmarks.single;
      expect(back.id, 'b1');
      expect(back.title, 'Phở của mẹ');
      expect(back.metadataSource, 'user');
      expect(back.originalUrl, item.originalUrl);

      final trashed = moveToTrash(library, ['b1'], now);
      expect(trashed.bookmarks, isEmpty);
      final restored = restoreFromTrash(trashed, ['b1'], now);
      expect(restored.bookmarks.single.title, 'Phở của mẹ');
      expect(restored.bookmarks.single.metadataSource, 'user');
    });
  });

  group('share', () {
    testWidgets('a link shares its title and clean address, never the note', (
      t,
    ) async {
      final (c, _) = await start(t);
      await t.runAsync(
        () => c.quickSave(
          'https://c.vn/an?id=3&utm_source=zalo&fbclid=x',
          title: 'Quán ăn',
        ),
      );
      final b = c.library!.bookmarks.firstWhere(
        (b) => b.originalUrl.contains('c.vn'),
      );
      await t.runAsync(
        () => c.update(
          (l) => l.copyWith(
            bookmarks: [
              for (final x in l.bookmarks)
                x.id == b.id ? x.copyWith(note: 'private note') : x,
            ],
          ),
        ),
      );
      await openItem(t, b.id);
      await tapKey(t, 'detail-share');
      expect(sharer.texts.single.text, 'Quán ăn\nhttps://c.vn/an?id=3');
      expect(sharer.texts.single.subject, 'Quán ăn');
      expect(sharer.texts.single.text, isNot(contains('private')));
      // The same from the "…" menu.
      await tapKey(t, 'detail-more');
      await tapKey(t, 'detail-share-menu');
      expect(sharer.texts, hasLength(2));
      // A sheet that cannot confirm says so, and never claims it was sent.
      sharer.result = LocalShareResult.unknown;
      await tapKey(t, 'detail-share');
      expect(
        find.text('Could not confirm that it was shared.'),
        findsOneWidget,
      );
    });

    testWidgets('Copy link sits in the "…" and says Copied, not Shared', (
      t,
    ) async {
      final (c, _) = await start(t);
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String?;
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openItem(t, c.library!.bookmarks.first.id);
      expect(find.byKey(const Key('detail-copy')), findsNothing);
      await tapKey(t, 'detail-more');
      await tapKey(t, 'detail-copy');
      expect(copied, 'https://a.com/one');
      expect(find.text('Copied'), findsOneWidget);
      expect(find.textContaining('hared'), findsNothing);
      expect(sharer.texts, isEmpty);
    });

    testWidgets('where there is no share sheet it says so and sends nothing', (
      t,
    ) async {
      final (c, _) = await start(t);
      sharer.supported = false;
      await openItem(t, c.library!.bookmarks.first.id);
      await tapKey(t, 'detail-share');
      expect(
        find.text('Sharing is not available on this device. Nothing was sent.'),
        findsOneWidget,
      );
      expect(sharer.texts, isEmpty);
    });

    testWidgets('a camera photo asks first; without location is the default '
        'and leaves the camera data behind; the original is exact', (t) async {
      final (c, _) = await start(t);
      final original = cameraJpeg();
      expect(pictureCarriesMetadata(original), isTrue);
      final id = await addPictureBytes(t, c, original, 'Hồ Gươm.jpg');
      await openItem(t, id);
      await tapKey(t, 'detail-share');
      expect(find.byKey(const Key('share-picture-sheet')), findsOneWidget);
      expect(find.byKey(const Key('share-has-exif')), findsOneWidget);
      await tapKey(t, 'share-picture-go');
      await waitFor(t, () => sharer.files.isNotEmpty);
      final clean = sharer.files.single;
      expect(clean.name, 'Hồ Gươm.jpg');
      expect(clean.mime, 'image/jpeg');
      expect(pictureCarriesMetadata(clean.bytes), isFalse);
      final decoded = img.decodeJpg(clean.bytes)!;
      expect((decoded.width, decoded.height), (64, 48));

      await tapKey(t, 'detail-share');
      await tapKey(t, 'share-picture-original');
      await tapKey(t, 'share-picture-go');
      await waitFor(t, () => sharer.files.length == 2);
      expect(sharer.files.last.bytes, original);
    });

    testWidgets('a picture with nothing but pixels goes as it is', (t) async {
      final (c, _) = await start(t);
      final bytes = png(120, 80);
      final id = await addPictureBytes(t, c, bytes, 'plan.png');
      await openItem(t, id);
      await tapKey(t, 'detail-share');
      expect(find.byKey(const Key('share-picture-sheet')), findsNothing);
      expect(sharer.files.single.bytes, bytes);
      expect(sharer.files.single.mime, 'image/png');
    });

    testWidgets('with only the preview left it says so and shares that', (
      t,
    ) async {
      final (c, store) = await start(t);
      final id = await addPictureBytes(t, c, cameraJpeg(), 'Hồ Gươm.jpg');
      store.originals = false;
      await openItem(t, id);
      await tapKey(t, 'detail-share');
      expect(find.byKey(const Key('share-preview-only')), findsOneWidget);
      expect(find.byKey(const Key('share-picture-original')), findsNothing);
      await tapKey(t, 'share-picture-go');
      await waitFor(t, () => sharer.files.isNotEmpty);
      final preview = await t.runAsync(
        () => c.mediaPreview(
          c.library!.bookmarks.firstWhere((b) => b.id == id).media!.id,
        ),
      );
      expect(sharer.files.single.bytes, preview);
      expect(pictureCarriesMetadata(sharer.files.single.bytes), isFalse);
    });
  });

  test('metadata check reads only headers and knows each format', () {
    expect(pictureCarriesMetadata(png(4, 4)), isFalse);
    expect(pictureCarriesMetadata(cameraJpeg()), isTrue);
    final plain = img.encodeJpg(img.Image(width: 4, height: 4));
    expect(pictureCarriesMetadata(plain), isFalse);
    final texted = img.Image(width: 4, height: 4)
      ..addTextData({'Comment': 'Hanoi'});
    expect(pictureCarriesMetadata(img.encodePng(texted)), isTrue);
    final clean = cleanPictureForShare(cameraJpeg())!;
    expect(pictureCarriesMetadata(clean.bytes), isFalse);
    expect(clean.extension, 'jpg');
    final alpha = cleanPictureForShare(png(4, 4, alpha: true))!;
    expect(alpha.mime, 'image/png');
    expect(cleanPictureForShare(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('a shared address drops trackers only', () {
    Bookmark link(String url) => Bookmark(
      id: 'x',
      originalUrl: url,
      normalizedUrl: UrlTools.normalize(url).normalizedUrl,
      savedAt: '2026-11-06T00:00:00Z',
      updatedAt: '2026-11-06T00:00:00Z',
    );
    expect(
      shareableUrl(link('https://a.com/p?b=2&utm_medium=x&a=1#top')),
      'https://a.com/p?b=2&a=1#top',
    );
    expect(shareText(link('https://a.com/x')), 'https://a.com/x');
    expect(
      shareText(link('https://a.com/x').copyWith(title: 'Phở')),
      'Phở\nhttps://a.com/x',
    );
  });
}
