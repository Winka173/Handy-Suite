import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/collections/share_collection.dart';
import 'package:handy_bookmark/pro/entitlements.dart';
import 'package:handy_bookmark/services/media_import.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:image/image.dart' as img;
import 'new_flows_test.dart' show OneFile, boot, settle;
import 'widget_test.dart' show tapKey;
import 'package:handy_files/handy_files.dart';
import 'package:handy_bookmark/links/link_tasks.dart';
import 'package:handy_bookmark/scope.dart';
import 'package:handy_bookmark/services/reminders.dart';
import 'package:handy_bookmark/view/library_view.dart';

/// A phone photo that says where and with what it was taken.
Uint8List placedPhoto() {
  final image = img.Image(width: 1200, height: 900);
  img.fill(image, color: img.ColorRgb8(30, 90, 140));
  image.exif.imageIfd['Make'] = img.IfdValueAscii('PhoneMaker');
  image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
  image.exif.imageIfd.orientation = 6;
  return img.encodeJpg(image);
}

bool carriesMetadata(Uint8List jpeg) {
  final e = img.decodeJpg(jpeg)!.exif;
  return e.imageIfd.containsKey(0x010F) || e.gpsIfd.values.isNotEmpty;
}

void main() {
  test('the source photo really carries camera and place data', () {
    expect(carriesMetadata(placedPhoto()), isTrue);
  });

  test('a picture leaving in a page is upright, small and has no metadata', () {
    final out = sharablePicture(placedPhoto())!;
    expect(carriesMetadata(out), isFalse);
    final d = img.decodeJpg(out)!;
    expect((d.width, d.height), (360, 480), reason: 'turned upright, 480 max');
    expect(sharablePicture(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('stored previews carry no metadata either', () {
    final p = preparePicture(placedPhoto(), name: 'IMG_1.jpg');
    expect(carriesMetadata(p.preview), isFalse);
    expect(p.original, isNotEmpty, reason: 'the original stays as it was');
  });

  testWidgets('Share as a page builds one file from the collection only', (
    t,
  ) async {
    final files = OneFile()
      ..next = ImportedBytes('Quán phở.jpg', placedPhoto());
    final (c, _) = await boot(t, files: files);
    await tapKey(t, 'save-new');
    await tapKey(t, 'save-photo');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(t);
    await c.update(
      (l) => l.copyWith(
        collections: [SaveCollection(id: 'food', name: 'Món ngon')],
        bookmarks: [
          for (final b in l.bookmarks)
            b.isImage || b.originalUrl == 'https://a.com/one'
                ? b.copyWith(collectionId: 'food')
                : b,
        ],
      ),
    );
    final view = LibraryView(c);
    addTearDown(view.dispose);
    final scope = SaveScope(
      c: c,
      view: view,
      files: OneFile(),
      reminders: SaveReminders(),
      tasks: LinkTasks(c),
    );
    final page = (await t.runAsync(() => scope.sharedPage(['food'])))!;
    expect(page, contains('<title>Món ngon</title>'));
    expect(page, contains('a.com/one'));
    expect(page, isNot(contains('b.org/two')));
    expect(page, contains('data:image/jpeg;base64,'));
    expect(page, isNot(contains('PhoneMaker')));
  });
  receiveTests();
}

/// A file a friend with Pro sent: "Trips" with a folder "Đà Nẵng".
Uint8List friendsFile() {
  Bookmark link(String id, String url, String collection) {
    final u = UrlTools.normalize(url);
    return Bookmark(
      id: id,
      originalUrl: u.originalUrl,
      normalizedUrl: u.normalizedUrl,
      sourceDomain: u.sourceDomain,
      title: 'Friend $id',
      collectionId: collection,
      savedAt: '2026-11-01T00:00:00Z',
      updatedAt: '2026-11-01T00:00:00Z',
    );
  }

  final theirs = SaveLibrary(
    collections: [
      SaveCollection(id: 'trips', name: 'Trips'),
      SaveCollection(id: 'dn', name: 'Đà Nẵng', parentId: 'trips'),
    ],
    bookmarks: [
      link('t1', 'https://trip.example/hue', 'trips'),
      link('t2', 'https://trip.example/my-khe', 'dn'),
      link('t3', 'https://a.com/one', 'dn'),
    ],
  );
  return Uint8List.fromList(
    utf8.encode(
      sharedCollectionsPage(theirs, ['trips'], now: DateTime(2026, 11, 9)),
    ),
  );
}

void receiveTests() {
  testWidgets('an item on a wide page shows what else is in its collection', (
    t,
  ) async {
    final (c, _) = await boot(t, size: const Size(1280, 800));
    await c.update(
      (l) => l.copyWith(
        collections: [SaveCollection(id: 'food', name: 'Food')],
        bookmarks: [
          for (final b in l.bookmarks) b.copyWith(collectionId: 'food'),
        ],
      ),
    );
    final first = c.library!.bookmarks.first;
    Navigator.of(
      t.element(find.byType(Scaffold).first),
    ).pushNamed('/bookmark/${first.id}');
    await settle(t);
    expect(find.byKey(const Key('detail-nearby')), findsOneWidget);
    expect(find.text('Also in Food'), findsOneWidget);
    expect(find.byKey(Key('nearby-${first.id}')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith('nearby-'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('holding a collection offers Send, already picked', (t) async {
    final (c, _) = await boot(t);
    await c.update(
      (l) => l.copyWith(
        collections: [SaveCollection(id: 'food', name: 'Food')],
        bookmarks: [
          for (final b in l.bookmarks) b.copyWith(collectionId: 'food'),
        ],
      ),
    );
    await settle(t);
    final tile = find.byKey(const Key('collection-food'));
    await t.ensureVisible(tile);
    await settle(t);
    await t.longPress(tile);
    await settle(t);
    expect(find.byKey(const Key('collection-quick')), findsOneWidget);
    await tapKey(t, 'collection-quick-send');
    expect(find.byKey(const Key('send-sheet')), findsOneWidget);
    expect(find.text('Send 1 collection · 3 items'), findsOneWidget);
  });

  testWidgets('Send collections: pick several, the button says how much', (
    t,
  ) async {
    final (c, _) = await boot(t);
    await c.update(
      (l) => l.copyWith(
        collections: [
          SaveCollection(id: 'food', name: 'Food'),
          SaveCollection(id: 'trips', name: 'Trips', position: 1),
        ],
        bookmarks: [
          for (final (i, b) in l.bookmarks.indexed)
            b.copyWith(collectionId: i == 0 ? 'food' : 'trips'),
        ],
      ),
    );
    Navigator.of(
      t.element(find.byKey(const Key('save-home'))),
    ).pushNamed('/library');
    await settle(t);
    await tapKey(t, 'collections-send');
    expect(find.byKey(const Key('send-sheet')), findsOneWidget);
    expect(find.text('Pick a collection'), findsOneWidget);
    await tapKey(t, 'send-pick-food');
    expect(find.text('Send 1 collection · 1 item'), findsOneWidget);
    await tapKey(t, 'send-all');
    expect(find.text('Send 2 collections · 3 items'), findsOneWidget);
  });

  for (final pro in [false, true]) {
    testWidgets(
      'collections a friend sent arrive from Library (${pro ? 'Pro keeps folders' : 'free spreads folders'})',
      (t) async {
        debugProOverride = pro;
        addTearDown(() => debugProOverride = null);
        final files = OneFile()
          ..next = ImportedBytes('Trips.html', friendsFile());
        final (c, _) = await boot(t, files: files);
        Navigator.of(
          t.element(find.byKey(const Key('save-home'))),
        ).pushNamed('/library');
        await settle(t);
        await tapKey(t, 'collections-receive');
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await settle(t);
        expect(find.byKey(const Key('receive-sheet')), findsOneWidget);
        expect(find.text('Trips'), findsWidgets);
        // a.com/one is already saved here: two are new.
        expect(find.text('Add 2 items'), findsOneWidget);
        expect(
          find.byKey(const Key('receive-flattened')),
          pro ? findsNothing : findsOneWidget,
        );
        await tapKey(t, 'receive-add');
        await settle(t);
        final l = c.library!;
        final trips = l.collections.singleWhere((x) => x.name == 'Trips');
        final folder = l.collections.where((x) => x.name == 'Đà Nẵng');
        final myKhe = l.bookmarks.singleWhere((b) => b.title == 'Friend t2');
        if (pro) {
          expect(folder.single.parentId, trips.id);
          expect(myKhe.collectionId, folder.single.id);
        } else {
          expect(folder, isEmpty);
          expect(myKhe.collectionId, trips.id);
          expect(myKhe.tags, ['Đà Nẵng']);
        }
        expect(
          l.bookmarks.where((b) => b.originalUrl == 'https://a.com/one'),
          hasLength(1),
        );
      },
    );
  }
}
