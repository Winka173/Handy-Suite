import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/services/metadata_client.dart';
import 'package:handy_bookmark/services/share_inbox.dart';
import 'package:handy_bookmark/share_sheet/share_sheet.dart';
import 'package:handy_bookmark/share_sheet/sheet_controller.dart';
import 'package:handy_bookmark/share_sheet/snapshot.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:image/image.dart' as img;
import 'controller_test.dart' show TestStore, TestInbox;
import 'reel_metadata_test.dart' show ScriptedNet;

/// A page read that also brings its picture.
class PictureNet extends ScriptedNet {
  PictureNet(super.answers, this.picture);
  final Uint8List picture;
  @override
  Future<ThumbnailResult> fetchThumbnail(
    String url, {
    dynamic cancellation,
  }) async => ThumbnailResult(bytes: picture, contentType: 'image/jpeg');
}

/// A store that keeps pictures (the shared one discards them).
class PictureStore extends TestStore {
  final pictures = <String, Uint8List>{};
  @override
  Future<void> putThumbnail(String id, Uint8List bytes) async =>
      pictures[id] = bytes;
  @override
  Future<Uint8List?> thumbnail(String id) async => pictures[id];
}

/// The activity's side of the sheet, recorded.
class FakeBridge extends SheetBridge {
  FakeBridge(this.share);
  final SheetShare share;
  Map<String, Object?>? saved;
  bool discarded = false, closed = false;
  @override
  Future<SheetShare> start() async => share;
  @override
  Future<void> save({
    String? collection,
    String? newCollection,
    MetadataResult? metadata,
    Uint8List? thumbnail,
  }) async => saved = {
    'collection': collection,
    'newCollection': newCollection,
    'title': metadata?.title,
    'thumbnail': thumbnail,
  };
  @override
  Future<void> discard() async => discarded = true;
  @override
  Future<void> close() async => closed = true;
}

final jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
const video = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
const read = MetadataResult(
  status: 'complete',
  title: 'Me at the zoo',
  siteName: 'YouTube',
  thumbnailUrl: 'https://i.ytimg.com/vi/jNQXAC9IVRw/hqdefault.jpg',
);

SaveLibrary library() => SaveLibrary(
  collections: [
    SaveCollection(id: 'c' * 32, name: 'Food', icon: 'emoji:🍜'),
    SaveCollection(id: 'd' * 32, name: 'Trips', position: 1),
  ],
  bookmarks: [
    Bookmark(
      id: 'b' * 32,
      originalUrl: 'https://example.com/a',
      normalizedUrl: 'https://example.com/a',
      canonicalUrl: 'https://example.com/a',
      platform: 'web',
      contentType: 'article',
      sourceDomain: 'example.com',
      title: 'A',
      savedAt: '2026-11-07T00:00:00Z',
      updatedAt: '2026-11-07T00:00:00Z',
      collectionId: 'c' * 32,
    ),
  ],
);

Future<(SheetController, FakeBridge)> showSheet(
  WidgetTester t, {
  Map<String, dynamic> prefs = const {},
  String text = video,
  String? collection,
}) async {
  final bridge = FakeBridge(
    SheetShare(
      id: 'q',
      text: text,
      collection: collection,
      snapshot: SheetSnapshot.parse(sheetSnapshot(library(), prefs)),
    ),
  );
  final c = SheetController(
    bridge: bridge,
    metadata: PictureNet([read], jpeg),
    retryDelay: Duration.zero,
    settle: const Duration(milliseconds: 300),
  );
  addTearDown(c.dispose);
  await t.pumpWidget(ShareSheetApp(controller: c));
  await t.pumpAndSettle();
  return (c, bridge);
}

/// New collection sits on the right of the list's head.
void expectEdges(WidgetTester t) {
  final right = t.getTopRight(find.byKey(const Key('share-sheet'))).dx;
  expect(
    t.getTopRight(find.byKey(const Key('share-sheet-new'))).dx,
    closeTo(right - 8, 1),
  );
}

void main() {
  test('the snapshot lists collections with their counts, never links', () {
    final json = sheetSnapshot(library(), {}, theme: 'dark', locale: 'vi');
    expect(json, isNot(contains('example.com')));
    final s = SheetSnapshot.parse(json);
    expect(s.library.collections.map((c) => c.name), ['Food', 'Trips']);
    expect(s.counts['c' * 32], 1);
    expect(s.counts['d' * 32], 0);
    expect((s.theme, s.locale, s.locked, s.read), ('dark', 'vi', false, true));

    final locked = SheetSnapshot.parse(
      sheetSnapshot(library(), {'appLock': true, 'automaticMetadata': false}),
    );
    expect(locked.locked, isTrue);
    expect(locked.read, isFalse);
    expect(locked.library.collections, isEmpty);
    // Nothing written yet, or unreadable: an empty list, defaults.
    expect(SheetSnapshot.parse(null).library.collections, isEmpty);
    expect(SheetSnapshot.parse('{oops').locked, isFalse);
  });

  testWidgets('one tap on a collection puts it there and closes', (t) async {
    final (c, bridge) = await showSheet(t);
    expect(find.text('Me at the zoo'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(c.picture, isNotNull);
    expectEdges(t);
    expect(find.text('Saved in Not sorted'), findsOneWidget);
    expect(find.text('Here now'), findsOneWidget);
    expect(find.text('1 link'), findsOneWidget);
    // No separate Save step.
    expect(find.text('Save'), findsNothing);

    await t.tap(find.byKey(Key('share-place-${'c' * 32}')));
    await t.pump();
    // The place shows its tick while the sheet goes.
    expect(find.text('Saved in Food'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(bridge.saved, isNull);
    await t.pump(const Duration(milliseconds: 300));
    expect(bridge.saved!['collection'], 'c' * 32);
    expect(bridge.saved!['title'], 'Me at the zoo');
    expect(bridge.saved!['thumbnail'], jpeg);

    // A second tap while it closes does nothing more.
    await t.tap(find.byKey(const Key('share-place-inbox')));
    await t.pump(const Duration(milliseconds: 300));
    expect(bridge.saved!['collection'], 'c' * 32);
  });

  testWidgets('shared through a collection, it is there; another tap moves '
      'it', (t) async {
    final (c, bridge) = await showSheet(t, collection: 'd' * 32);
    expect((c.choice as InCollection).id, 'd' * 32);
    expect(find.text('Saved in Trips'), findsOneWidget);
    expect(find.byKey(const Key('share-sheet-new')), findsOneWidget);

    await t.tap(find.byKey(const Key('share-place-inbox')));
    await t.pump(const Duration(milliseconds: 300));
    expect(bridge.saved!['collection'], isNull);
    expect(bridge.saved!['newCollection'], isNull);
  });

  testWidgets('a new collection is named in place and the share goes in', (
    t,
  ) async {
    final (_, bridge) = await showSheet(t);
    await t.tap(find.byKey(const Key('share-sheet-new')));
    await t.pump();
    await t.enterText(find.byKey(const Key('share-sheet-name')), ' Xem sau ');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(find.byKey(const Key('share-sheet-name')), findsNothing);
    expect(find.text('Saved in Xem sau'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 300));
    expect(bridge.saved!['newCollection'], 'Xem sau');
    expect(bridge.saved!['collection'], isNull);
  });

  testWidgets('a name already used picks that collection', (t) async {
    final (c, _) = await showSheet(t);
    final where = c.name('food');
    expect(where, isA<InCollection>());
    expect((where as InCollection).id, 'c' * 32);
    expect(c.named, isEmpty);
  });

  testWidgets('closing keeps it where it is; Don’t save takes it back', (
    t,
  ) async {
    final (c, bridge) = await showSheet(t);
    expect(c.choice, isA<NotSorted>());
    await t.tap(find.byKey(const Key('share-sheet-close')));
    await t.pump();
    expect(bridge.closed, isTrue);
    expect(bridge.saved, isNull);

    await t.tap(find.byKey(const Key('share-sheet-discard')));
    await t.pump();
    expect(bridge.discarded, isTrue);
  });

  testWidgets('with the app lock on, no collection is listed', (t) async {
    await showSheet(t, prefs: {'appLock': true});
    expect(find.text('Food'), findsNothing);
    expect(find.byKey(const Key('share-sheet-places')), findsNothing);
    expect(find.textContaining('Unlock the app'), findsOneWidget);
  });

  testWidgets('the sheet fits a narrow phone with large text', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await showSheet(t);
    expect(t.takeException(), isNull);
    expectEdges(t);
  });

  test('a share from the sheet makes its collection and keeps the picture '
      'it read, without reading the page again', () async {
    final dir = await Directory.systemTemp.createTemp('sheet');
    addTearDown(() => dir.delete(recursive: true));
    final thumb = File('${dir.path}/thumb')..writeAsBytesSync(jpeg);
    final net = ScriptedNet([
      const MetadataResult(status: 'failed', errorCode: 'httpStatus'),
    ]);
    final inbox = TestInbox()
      ..pending = [
        SharedLink.full(
          'one',
          video,
          null,
          newCollection: 'Xem sau',
          metadata: read,
          thumbnail: thumb.path,
        ),
      ];
    final store = PictureStore();
    final c = SaveController(
      open: () async => store,
      shares: inbox,
      metadataClient: net,
    );
    await c.initialize();
    addTearDown(c.dispose);
    await c.drain();

    final l = c.library!;
    final made = l.collections.singleWhere((x) => x.name == 'Xem sau');
    final b = l.bookmarks.single;
    expect(b.collectionId, made.id);
    expect(b.title, 'Me at the zoo');
    expect(b.metadataStatus, 'complete');
    expect(await store.thumbnail(b.id), isNotNull);
    expect(net.reads, 0);
    expect(inbox.acknowledgments, ['one']);

    // The same name again (another share) goes into the same collection.
    inbox.pending = [
      SharedLink.full(
        'two',
        'https://example.com/b',
        null,
        newCollection: 'xem sau',
      ),
    ];
    c.preferences['automaticMetadata'] = false;
    await c.drain();
    expect(c.library!.collections.where((x) => x.name == 'Xem sau').length, 1);
    expect(
      c.library!.bookmarks
          .where((x) => x.collectionId == made.id)
          .map((x) => x.originalUrl),
      containsAll([video, 'https://example.com/b']),
    );
  });
}
