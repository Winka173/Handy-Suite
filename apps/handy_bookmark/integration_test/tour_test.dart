// A guided walk through the app for a screen recording on a device:
// python tooling/device-tour.py --device <serial> save
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:integration_test/integration_test.dart';
import '../test/widget_test.dart' show OpeningController, Preferences;
import '../tool/screens_test.dart' show PictureStore, picture;

/// Lets the viewer see the screen before the next step.
Future<void> pause(WidgetTester t, [int ms = 1200]) async {
  await t.pumpAndSettle();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

/// Scrolls every list on screen back to its top, the way a thumb would.
Future<void> toTop(WidgetTester t) async {
  final lists = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .hitTestable();
  for (final list in t.stateList<ScrollableState>(lists)) {
    unawaited(
      list.position.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      ),
    );
  }
  await pause(t, 700);
}

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  // Scrolled out of a lazy list, such as a collection's header after
  // coming back from a link.
  if (f.evaluate().isEmpty) await toTop(t);
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await pause(t, 700);
}

/// A long press, which starts selecting links.
Future<void> hold(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.longPress(f.first);
  await pause(t, 700);
}

Future<void> type(WidgetTester t, String key, String text) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  // A new text-input client after the last one closed on the device.
  await t.tap(f);
  await t.pumpAndSettle();
  await t.enterText(f, text);
  await pause(t, 700);
}

/// Scrolls smoothly until [key] is in view, so the film shows the way.
Future<void> show(WidgetTester t, String key, [int ms = 1500]) async {
  // A long settings list builds only what is near the screen.
  if (find.byKey(Key(key)).evaluate().isEmpty) {
    await t.scrollUntilVisible(
      find.byKey(Key(key)),
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .hitTestable()
          .first,
    );
  }
  unawaited(
    Scrollable.ensureVisible(
      t.element(find.byKey(Key(key)).first),
      alignment: .3,
      duration: const Duration(milliseconds: 600),
    ),
  );
  await pause(t, ms);
}

/// Files a link from Home's Recently saved rows: its chip when the
/// collection is one of the usual ones, otherwise through "Khác…".
Future<void> fileInto(WidgetTester t, String id, String collection) async {
  final button = find.byKey(Key('file-$id'));
  await t.scrollUntilVisible(
    button,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('save-home')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await pause(t, 600);
  await tap(t, 'file-$id');
  final chip = 'file-$id-$collection';
  if (find.byKey(Key(chip)).evaluate().isEmpty) {
    await tap(t, 'file-$id-other');
    await tap(t, 'pick-$collection');
  } else {
    await tap(t, chip);
  }
  await pause(t, 1500);
}

/// Goes back the way a person does: the top bar's back arrow, or the
/// system back when the screen has none.
Future<void> back(WidgetTester t) async {
  await t.pumpAndSettle();
  final arrow = find.byType(BackButton).hitTestable();
  if (arrow.evaluate().isNotEmpty) {
    await t.tap(arrow.last);
  } else {
    await t.binding.handlePopRoute();
  }
  await pause(t, 700);
}

/// The seeded library: (address, title, collection, picture colours).
const _links = [
  (
    'https://www.youtube.com/watch?v=bunbo1',
    'Cách nấu bún bò Huế chuẩn vị',
    'food',
    0xFFE9D8B4,
    0xFFB5472B,
  ),
  (
    'https://www.tiktok.com/@chef/video/7301',
    'Mẹo nướng bánh mì giòn bằng nồi chiên',
    'food',
    0xFFF1E3C8,
    0xFF8C5A2B,
  ),
  (
    'https://shopee.vn/product/1201/5531',
    'Nồi chiên không dầu 6L',
    'buy',
    0xFFDDE7EE,
    0xFF34617A,
  ),
  (
    'https://www.facebook.com/groups/dulich/posts/88',
    'Lịch trình 3 ngày Đà Nẵng – Hội An',
    'trip',
    0xFFCFE6E3,
    0xFF2F7F86,
  ),
  (
    'https://maps.google.com/?cid=1234',
    'Bánh xèo Bà Dưỡng',
    'trip',
    0xFFE7E1D3,
    0xFF6E6A3B,
  ),
  (
    'https://vnexpress.net/du-lich/mua-dep-nhat-ha-giang',
    'Mùa đẹp nhất để đi Hà Giang',
    'read',
    0xFFE3E6D8,
    0xFF5D7A3A,
  ),
  ('https://github.com/flutter/flutter', 'flutter/flutter', 'read', 0, 0),
  (
    'https://www.youtube.com/watch?v=yoga20',
    'Yoga 20 phút buổi sáng',
    null,
    0xFFE6DDEB,
    0xFF6B5A7A,
  ),
  (
    'https://www.tiktok.com/@decor/video/9921',
    'Trang trí ban công nhỏ',
    null,
    0xFFDDEBD9,
    0xFF3F7A4A,
  ),
  ('https://shopee.vn/product/88/17', 'Kệ sách gỗ 5 tầng', null, 0, 0),
  (
    'https://www.instagram.com/p/Cx1',
    'Quán cà phê view hồ Tây',
    null,
    0xFFE9E2D2,
    0xFF7A6447,
  ),
];

/// Fills the library before the app is pumped. Nothing touches the network:
/// titles are given, pictures are drawn, and page details stay off.
Future<OpeningController> seed() async {
  final store = PictureStore();
  final c = OpeningController(store);
  await c.initialize();
  for (final l in _links) {
    await c.quickSave(l.$1, title: l.$2);
  }
  await c.update(
    (l) => l.copyWith(
      collections: [
        SaveCollection(id: 'food', name: 'Công thức nấu ăn', position: 0),
        SaveCollection(id: 'trip', name: 'Du lịch', position: 1),
        SaveCollection(
          id: 'dn',
          name: 'Đà Nẵng',
          parentId: 'trip',
          position: 0,
        ),
        SaveCollection(id: 'buy', name: 'Cần mua', position: 2),
        SaveCollection(id: 'read', name: 'Đọc sau', position: 3),
      ],
      tags: ['món-huế', 'cuối-tuần'],
      bookmarks: [
        for (final (i, b) in l.bookmarks.indexed)
          b.copyWith(
            collectionId: _links[i].$3,
            tags: i == 0 ? ['món-huế'] : (i == 3 ? ['cuối-tuần'] : null),
            isFavorite: i == 0 || i == 4,
            isRead: i == 2 || i == 6,
            savedAt: DateTime.now()
                .subtract(Duration(hours: i * 7 + 1))
                .toUtc()
                .toIso8601String(),
          ),
      ],
    ),
  );
  final ids = c.library!.bookmarks.map((b) => b.id).toList();
  for (final (i, l) in _links.indexed) {
    if (l.$4 != 0) store.pictures[ids[i]] = await picture(l.$4, l.$5);
  }
  return c;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Handy Bookmark tour', (t) async {
    // Seed first: the library is ready before the first frame.
    final c = await seed();
    addTearDown(c.dispose);
    final ids = c.library!.bookmarks.map((b) => b.id).toList();
    final width = t.view.physicalSize.width / t.view.devicePixelRatio;
    expect(
      width,
      greaterThanOrEqualTo(700),
      reason: 'The tour films the wide layout (a landscape tablet).',
    );
    // From 1100 the chosen link opens beside the list; below, as a page.
    final side = width >= 1100;

    await t.pumpWidget(
      SaveApp(
        controller: c,
        preferences: Preferences()..value = HandyPreferences(locale: 'vi'),
      ),
    );
    await pause(t, 2000);

    // Not sorted: links shared from other apps wait in the strip. One tap
    // on a collection chip files each one.
    await fileInto(t, ids[10], 'trip');
    await fileInto(t, ids[9], 'buy');
    await pause(t, 1000);

    // A collection, as rows and then as cards.
    await tap(t, 'collection-trip');
    await pause(t, 1800);
    await tap(t, 'list-more');
    await tap(t, 'save-view');
    await pause(t, 3000);

    // One link's details; make it a favourite.
    await tap(t, 'details-${ids[3]}');
    await pause(t, 800);
    await tap(t, 'item-details');
    await pause(t, 2500);
    await tap(t, 'detail-favorite');
    await pause(t, 1500);
    if (!side) await back(t);
    await tap(t, 'list-more');
    await tap(t, 'save-view');
    await pause(t, 1200);

    // Select two links and move them into Đà Nẵng together.
    await hold(t, 'bookmark-${ids[3]}');
    await tap(t, 'bookmark-${ids[4]}');
    await pause(t, 1000);
    await tap(t, 'batch-move');
    await pause(t, 1000);
    await tap(t, 'pick-dn');
    await pause(t, 2000);
    await tap(t, 'collection-dn');
    await pause(t, 2500);

    // Paste a link: saved offline, no page is fetched; it lands in the strip.
    const url = 'https://www.youtube.com/watch?v=banhcuon-thanh-tri';
    await tap(t, 'place-all');
    await pause(t, 1000);
    await tap(t, 'save-new');
    await tap(t, 'save-add');
    await type(t, 'save-text-input', url);
    await pause(t, 1000);
    await tap(t, 'save-text-confirm');
    await pause(t, 2500);
    final added = c.library!.bookmarks.firstWhere((b) => b.originalUrl == url);
    await fileInto(t, added.id, 'food');

    // Search (one tap from Home) narrows the list as you type.
    await tap(t, 'open-search');
    await type(t, 'save-search', 'bánh');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await pause(t, 3000);
    await back(t);
    await pause(t, 1200);

    // Focus: one unread link at a time.
    await tap(t, 'place-focus');
    await pause(t, 2500);
    await tap(t, 'focus-read');
    await pause(t, 1500);
    await tap(t, 'focus-later');
    await pause(t, 1500);
    await back(t);
    await pause(t, 1000);

    // Settings: how links open, what is fetched (nothing, by default), data.
    await tap(t, 'open-settings');
    await pause(t, 1500);
    // Page details and the library check live in Advanced library tools.
    await tap(t, 'set-library-tools');
    await pause(t, 1000);
    await show(t, 'set-metadata', 2500);
    await show(t, 'save-integrity', 2000);
    await back(t);
    await pause(t, 800);
    await back(t);
    await pause(t, 1500);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
