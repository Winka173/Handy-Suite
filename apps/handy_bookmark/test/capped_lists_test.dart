import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/share_sheet/share_sheet.dart';
import 'package:handy_bookmark/share_sheet/sheet_controller.dart';
import 'package:handy_bookmark/share_sheet/snapshot.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'new_flows_test.dart' show NetController, boot, settle;
import 'share_sheet_test.dart' show FakeBridge, PictureNet, jpeg, read, video;
import 'widget_test.dart' show tapKey;

List<SaveCollection> many(int n) => [
  for (var i = 0; i < n; i++)
    SaveCollection(id: 'c$i'.padRight(32, 'x'), name: 'Topic $i', position: i),
];

Future<void> twelve(NetController c) =>
    c.update((l) => l.copyWith(collections: many(12)));

Finder col(int i) => find.byKey(Key('collection-${'c$i'.padRight(32, 'x')}'));

void main() {
  testWidgets('a long sidebar shows eight collections and opens the rest '
      'in place', (t) async {
    await boot(t, size: const Size(1280, 800), seed: twelve);
    expect(col(7), findsOneWidget);
    expect(col(8), findsNothing);
    await t.scrollUntilVisible(
      find.byKey(const Key('collections-more')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('bookmark-sidebar')),
        matching: find.byType(Scrollable),
      ),
    );
    await tapKey(t, 'collections-more');
    await settle(t);
    expect(col(11), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);
  });

  testWidgets('the phone Library shows six tiles, then Show all', (t) async {
    await boot(t, seed: twelve);
    await tapKey(t, 'home-library');
    await settle(t);
    final tile = find.byKey(Key('in-${'c5'.padRight(32, 'x')}'));
    expect(tile, findsOneWidget);
    expect(find.byKey(Key('in-${'c6'.padRight(32, 'x')}')), findsNothing);
    expect(find.text('Show all 12'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('covers-more')));
    await tapKey(t, 'covers-more');
    await settle(t);
    expect(find.byKey(Key('in-${'c11'.padRight(32, 'x')}')), findsOneWidget);
  });

  testWidgets('the share sheet lists six collections, the rest one tap '
      'away', (t) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final bridge = FakeBridge(
      SheetShare(
        id: 'q',
        text: video,
        snapshot: SheetSnapshot.parse(
          sheetSnapshot(SaveLibrary(collections: many(10)), const {}),
        ),
      ),
    );
    final c = SheetController(
      bridge: bridge,
      metadata: PictureNet([read], jpeg),
      retryDelay: Duration.zero,
      confirm: const Duration(milliseconds: 300),
      pictureWait: const Duration(milliseconds: 100),
    );
    addTearDown(c.dispose);
    await t.pumpWidget(ShareSheetApp(controller: c));
    await t.pumpAndSettle();
    final places = find.descendant(
      of: find.byKey(const Key('share-sheet-places')),
      matching: find.byType(ListTile),
    );
    expect(places, findsNWidgets(6));
    await t.ensureVisible(find.byKey(const Key('share-sheet-more')));
    await t.tap(find.byKey(const Key('share-sheet-more')));
    await t.pumpAndSettle();
    expect(places, findsNWidgets(10));
  });
}
