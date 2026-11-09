import 'dart:ui' show AccessibilityFeatures;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/welcome/rehearsal.dart' show SwipeHint;
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/welcome/welcome_page.dart';
import 'package:handy_storage/handy_storage.dart';
import 'controller_test.dart' show TestStore, TestInbox;
import 'new_flows_test.dart' show OneFile, settle;
import 'widget_test.dart' show Preferences, tapKey;

/// The guide's glow rings breathe for ever; with motion reduced (as a
/// person can ask for) they hold still, so frames settle.
class StillMotion implements AccessibilityFeatures {
  @override
  bool get disableAnimations => true;
  @override
  dynamic noSuchMethod(Invocation i) => false;
}

Future<SaveController> open(
  WidgetTester t, {
  TestStore? store,
  Size size = const Size(400, 900),
  double textScale = 1,
  List<String> urls = const [],
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  t.platformDispatcher.accessibilityFeaturesTestValue = StillMotion();
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final c = SaveController(
    open: () async => store ?? TestStore(),
    shares: TestInbox(),
  );
  await t.runAsync(c.initialize);
  for (final u in urls) {
    await c.quickSave(u, title: 'Page ${u.split('/').last}');
  }
  await t.pumpWidget(
    SaveApp(
      controller: c,
      files: OneFile(),
      preferences: Preferences()..value = HandyPreferences(locale: 'en'),
      device: false,
    ),
  );
  await settle(t);
  addTearDown(c.dispose);
  return c;
}

/// Swipes the phone's app row from its visible start (its centre is past
/// the edge).
Future<void> swipeApps(WidgetTester t) async {
  final start = t.getTopLeft(find.byKey(const Key('practice-apps')));
  await t.dragFrom(start + const Offset(60, 30), const Offset(-400, 0));
  await t.pumpAndSettle();
}

/// Plays the practice save on the pretend phone.
Future<void> practise(WidgetTester t) async {
  await tapKey(t, 'practice-share');
  await tapKey(t, 'practice-more');
  await tapKey(t, 'practice-direct');
  await tapKey(t, 'practice-close');
  await settle(t);
}

void main() {
  testWidgets('an empty library opens the guide; Skip remembers it', (t) async {
    final store = TestStore();
    final c = await open(t, store: store);
    expect(find.textContaining('Then forgot it'), findsOneWidget);
    await tapKey(t, 'welcome-skip');
    await settle(t);
    expect(find.byType(WelcomePage), findsNothing);
    expect(c.preferences[guideDoneKey], isTrue);

    await t.pumpWidget(const SizedBox());
    final again = await open(t, store: store);
    expect(again.preferences[guideDoneKey], isTrue);
    expect(find.byType(WelcomePage), findsNothing);
  });

  testWidgets('the app row shows a finger sweeping and an arrow; the arrow '
      'moves the row too (a mouse cannot swipe)', (t) async {
    await open(t);
    await tapKey(t, 'welcome-next-0');
    await tapKey(t, 'welcome-next-1');
    await tapKey(t, 'practice-share');
    await tapKey(t, 'practice-more');
    expect(find.byType(SwipeHint), findsOneWidget);
    for (
      var i = 0;
      i < 4 && find.text('Tap Handy Bookmark').evaluate().isEmpty;
      i++
    ) {
      await tapKey(t, 'practice-apps-more');
      await t.pumpAndSettle();
    }
    expect(find.text('Tap Handy Bookmark'), findsOneWidget);
    expect(find.byType(SwipeHint), findsNothing);
  });

  testWidgets('someone who already has links never sees it unasked', (t) async {
    await open(t, urls: ['https://a.com/one']);
    expect(find.byType(WelcomePage), findsNothing);
  });

  testWidgets('the practice save goes step by step and saves nothing', (
    t,
  ) async {
    final c = await open(t);
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
    // The first button brings the cards together on the same stage.
    await tapKey(t, 'welcome-next-0');
    expect(find.textContaining('all of it'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
    await tapKey(t, 'welcome-next-1');
    expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
    // On a phone the practice is the whole screen: the task, no button.
    expect(find.textContaining('save this video'), findsOneWidget);
    expect(find.text('Tap Share'), findsOneWidget, reason: 'the lit word');
    expect(find.byKey(const Key('welcome-next-2')), findsNothing);

    // As in real apps: their own list first (no Handy Bookmark), More,
    // then the phone's list with the collections in the top row.
    await tapKey(t, 'practice-share');
    expect(find.textContaining('own list first'), findsOneWidget);
    expect(find.text('Not here? Tap More'), findsOneWidget);
    await tapKey(t, 'practice-more');
    // As on a real phone, Handy Bookmark is past the edge: swipe to it.
    expect(find.text('Swipe to find Handy Bookmark'), findsOneWidget);
    expect(find.text('Tap Handy Bookmark'), findsNothing);
    await swipeApps(t);
    await t.pumpAndSettle();
    expect(find.text('Tap Handy Bookmark'), findsOneWidget);
    await tapKey(t, 'practice-direct');
    // Its sheet opens with the collection it came through already chosen.
    expect(find.byKey(const Key('practice-our-sheet')), findsOneWidget);
    expect(find.text('Saved in Good food'), findsOneWidget);
    expect(find.text('Already in Good food. Tap ✕'), findsOneWidget);
    await tapKey(t, 'practice-close');
    await settle(t);
    expect(find.text('Saved to Good food'), findsOneWidget);
    expect(find.textContaining('all it takes'), findsOneWidget);
    expect(find.textContaining('pin it'), findsOneWidget);

    await tapKey(t, 'welcome-next-2');
    expect(find.textContaining('in a moment'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 3 of 3'), findsOneWidget);
    // The find stage's button finishes: no notification step, no
    // permission asked during the first run.
    expect(find.text('Start saving'), findsOneWidget);
    await tapKey(t, 'welcome-next-3');
    await settle(t);
    expect(find.byKey(const Key('welcome-later')), findsNothing);
    expect(find.byType(WelcomePage), findsNothing);
    expect(c.preferences[guideDoneKey], isTrue);
    expect(c.library!.bookmarks, isEmpty, reason: 'practice saves nothing');
    expect(
      c.preferences['notifications'],
      isNot(true),
      reason: 'no notification is turned on for the person',
    );
  });

  testWidgets('Handy Bookmark itself, in the practice, opens its sheet; one '
      'tap on a collection files it', (t) async {
    await open(t);
    await tapKey(t, 'welcome-next-0');
    await tapKey(t, 'welcome-next-1');
    await tapKey(t, 'practice-share');
    await tapKey(t, 'practice-more');
    await swipeApps(t);
    await t.pumpAndSettle();
    await tapKey(t, 'practice-target');
    expect(find.text('Saved in Not sorted'), findsOneWidget);
    expect(find.text('Tap a collection'), findsOneWidget);
    // The place it is in is not a row; only places it can go.
    expect(find.byKey(const Key('practice-pick-inbox')), findsNothing);
    await tapKey(t, 'practice-pick-trips');
    await settle(t);
    expect(find.text('Saved to Trips'), findsOneWidget);
  });

  testWidgets('back steps back; on the first step it leaves', (t) async {
    final c = await open(t);
    expect(find.byKey(const Key('welcome-back')), findsNothing);
    await tapKey(t, 'welcome-next-0');
    await tapKey(t, 'welcome-next-1');
    // From the practice, back returns to the gathered library.
    await tapKey(t, 'welcome-back');
    expect(find.textContaining('all of it'), findsOneWidget);
    // Then to the scattered cards, the same stage.
    await tapKey(t, 'welcome-back');
    expect(find.textContaining('Then forgot it'), findsOneWidget);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byType(WelcomePage), findsNothing);
    expect(c.preferences[guideDoneKey], isTrue);
  });

  testWidgets('Settings replays it for someone with links', (t) async {
    final c = await open(t, urls: ['https://a.com/one']);
    Navigator.of(
      t.element(find.byType(Navigator).first),
    ).pushNamed('/settings');
    await settle(t);
    // Help › How to use › the welcome again.
    await t.scrollUntilVisible(
      find.byKey(const Key('set-howto')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapKey(t, 'set-howto');
    await tapKey(t, 'howto-replay');
    await settle(t);
    expect(find.textContaining('Then forgot it'), findsOneWidget);
    await tapKey(t, 'welcome-skip');
    await settle(t);
    expect(c.library!.bookmarks, hasLength(1), reason: 'nothing changed');
  });

  for (final (size, scale) in [
    (const Size(320, 640), 2.0),
    (const Size(390, 844), 1.0),
    (const Size(1280, 800), 1.0),
  ]) {
    testWidgets('every step fits at ${size.width.toInt()} px, text ×$scale', (
      t,
    ) async {
      await open(t, size: size, textScale: scale);
      for (var i = 0; i < 2; i++) {
        expect(t.takeException(), isNull);
        await tapKey(t, 'welcome-next-$i');
      }
      await practise(t);
      expect(t.takeException(), isNull);
      await tapKey(t, 'welcome-next-2');
      expect(t.takeException(), isNull);
      await tapKey(t, 'welcome-next-3');
      expect(t.takeException(), isNull);
    });
  }
}
