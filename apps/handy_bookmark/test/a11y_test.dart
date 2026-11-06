import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'widget_test.dart' show start, tapKey, OpeningController;

Future<void> meetsAll(WidgetTester tester, String state) async {
  for (final g in [
    textContrastGuideline,
    androidTapTargetGuideline,
    iOSTapTargetGuideline,
    labeledTapTargetGuideline,
  ]) {
    await expectLater(tester, meetsGuideline(g), reason: state);
  }
}

Future<void> library(OpeningController c) async {
  await c.quickSave('https://www.youtube.com/watch?v=pho123');
  await c.quickSave('https://shopee.vn/product/12/34');
  await c.quickSave(
    'https://example.com/a-very-long-article-title-that-goes-on-and-on-about-travel-in-vietnam',
  );
  await c.update(
    (l) => l.copyWith(
      collections: [
        SaveCollection(id: 'trips', name: 'Du lịch'),
        SaveCollection(
          id: 'food',
          name: 'Món ngon cần thử ở Đà Nẵng và Hội An',
          parentId: 'trips',
        ),
      ],
      tags: ['travel'],
      bookmarks: [
        for (final b in l.bookmarks)
          b.platform == 'youtube'
              ? b.copyWith(
                  collectionId: 'food',
                  tags: ['travel'],
                  isFavorite: true,
                )
              : b,
      ],
    ),
  );
}

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets(
      'home, results, detail, editor and settings meet guidelines ($theme)',
      (tester) async {
        final handle = tester.ensureSemantics();
        final c = await start(tester, seed: library, theme: theme);
        await meetsAll(tester, 'home');
        await tapKey(tester, 'collection-food');
        await meetsAll(tester, 'collection');
        final id = c.library!.bookmarks
            .firstWhere((b) => b.collectionId == 'food')
            .id;
        await tapKey(tester, 'details-$id');
        await tapKey(tester, 'item-details');
        await meetsAll(tester, 'detail');
        await tapKey(tester, 'detail-edit');
        await meetsAll(tester, 'editor');
        handle.dispose();
      },
    );
  }

  testWidgets('wide layout meets guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await start(tester, seed: library, size: const Size(1440, 900));
    await tapKey(tester, 'details-${c.library!.bookmarks.first.id}');
    await tapKey(tester, 'item-details');
    await meetsAll(tester, 'wide');
    await tapKey(tester, 'open-settings');
    await meetsAll(tester, 'settings');
    handle.dispose();
  });

  testWidgets('every Save screen lays out at 320px without overflow', (
    tester,
  ) async {
    final c = await start(tester, seed: library, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'collection-food');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'save-view');
    expect(tester.takeException(), isNull, reason: 'cards');
    final id = c.library!.bookmarks
        .firstWhere((b) => b.collectionId == 'food')
        .id;
    await tester.longPress(find.byKey(ValueKey('card-$id')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'batch bar');
    await tapKey(tester, 'batch-clear');
    await tapKey(tester, 'details-$id');
    await tapKey(tester, 'item-details');
    expect(tester.takeException(), isNull, reason: 'detail');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // Focus sits at the top of the home (since 2026-11-06), above the
    // covers this test scrolled down to.
    await tester.fling(
      find.byKey(const Key('save-home')),
      const Offset(0, 2000),
      3000,
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'place-focus');
    expect(tester.takeException(), isNull, reason: 'focus');
  });
}
