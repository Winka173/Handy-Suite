import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/services/share_inbox.dart';
import 'package:handy_bookmark/welcome/welcome_page.dart';
import 'package:handy_storage/handy_storage.dart';
import 'controller_test.dart' show TestStore, TestInbox;
import 'new_flows_test.dart' show OneFile, settle;
import 'widget_test.dart' show Preferences, tapKey;

Future<SaveController> open(
  WidgetTester t, {
  TestStore? store,
  TestInbox? inbox,
  Size size = const Size(400, 900),
  double textScale = 1,
  List<String> urls = const [],
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final c = SaveController(
    open: () async => store ?? TestStore(),
    shares: inbox ?? TestInbox(),
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

void main() {
  testWidgets('an empty library opens the guide; Skip remembers it', (t) async {
    final store = TestStore();
    final c = await open(t, store: store);
    expect(find.text('Keep it once. Find it again.'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 4'), findsOneWidget);
    await tapKey(t, 'welcome-skip');
    await settle(t);
    expect(find.byType(WelcomePage), findsNothing);
    expect(c.preferences[guideDoneKey], isTrue);

    // Started again on the same data: the guide stays closed.
    await t.pumpWidget(const SizedBox());
    final again = await open(t, store: store);
    expect(again.preferences[guideDoneKey], isTrue);
    expect(find.byType(WelcomePage), findsNothing);
  });

  testWidgets('someone who already has links never sees it unasked', (t) async {
    await open(t, urls: ['https://a.com/one']);
    expect(find.byType(WelcomePage), findsNothing);
  });

  testWidgets('a real first save stays, and filing it creates the collection', (
    t,
  ) async {
    final c = await open(t);
    await tapKey(t, 'welcome-next-0');
    expect(find.text('Save from any app.'), findsOneWidget);
    await tapKey(t, 'welcome-next-1');
    expect(find.text('Save your first one.'), findsOneWidget);
    expect(find.text('Your first save goes here.'), findsOneWidget);

    await t.enterText(
      find.byKey(const Key('welcome-url')),
      'https://example.com/bun-cha',
    );
    await t.pump();
    await tapKey(t, 'welcome-url-save');
    await settle(t);
    expect(find.text("Saved. It's in Not sorted."), findsOneWidget);
    final saved = c.library!.bookmarks.single;
    expect(saved.collectionId, isNull);
    expect(find.byKey(ValueKey('welcome-saved-${saved.id}')), findsOneWidget);

    await tapKey(t, 'welcome-start-0');
    await settle(t);
    final recipes = c.library!.collections.single;
    expect(recipes.name, 'Recipes');
    expect(c.library!.bookmarks.single.collectionId, recipes.id);
    expect(find.text('Saved and filed.'), findsOneWidget);

    await tapKey(t, 'welcome-next-3');
    await settle(t);
    expect(find.byType(WelcomePage), findsNothing);
    expect(c.preferences[guideDoneKey], isTrue);
    expect(c.library!.bookmarks, hasLength(1), reason: 'the save is kept');
  });

  testWidgets(
    'a link shared from another app while waiting moves the guide on',
    (t) async {
      final inbox = TestInbox();
      final c = await open(t, inbox: inbox);
      await tapKey(t, 'welcome-next-0');
      await tapKey(t, 'welcome-next-1');
      inbox.pending = [
        const SharedLink(
          's1',
          'https://shopee.vn/giay-chay-bo',
          'Giày chạy bộ',
        ),
      ];
      unawaited(c.drain());
      await settle(t);
      expect(find.text("Saved. It's in Not sorted."), findsOneWidget);
      expect(find.text('Giày chạy bộ'), findsWidgets);
      expect(inbox.acknowledgments, ['s1']);
    },
  );

  testWidgets('back steps back; on the first step it leaves', (t) async {
    final c = await open(t);
    await tapKey(t, 'welcome-next-0');
    await tapKey(t, 'welcome-back');
    expect(find.text('Keep it once. Find it again.'), findsOneWidget);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byType(WelcomePage), findsNothing);
    expect(c.preferences[guideDoneKey], isTrue);
  });

  testWidgets('Settings replays it for someone with links', (t) async {
    final c = await open(t, urls: ['https://a.com/one']);
    final nav = Navigator.of(t.element(find.byType(Navigator).first));
    nav.pushNamed('/settings');
    await settle(t);
    await tapKey(t, 'set-guide');
    await settle(t);
    expect(find.text('Keep it once. Find it again.'), findsOneWidget);
    await tapKey(t, 'welcome-next-0');
    await tapKey(t, 'welcome-next-1');
    await t.enterText(
      find.byKey(const Key('welcome-url')),
      'https://b.org/two',
    );
    await t.pump();
    await tapKey(t, 'welcome-url-save');
    await settle(t);
    // Only the new save counts, not the links already there.
    expect(find.text('Page two'), findsNothing);
    expect(find.text("Saved. It's in Not sorted."), findsOneWidget);
    expect(c.library!.bookmarks, hasLength(2));
  });

  for (final (size, scale) in [
    (const Size(320, 640), 2.0),
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
      expect(t.takeException(), isNull);
      await t.enterText(
        find.byKey(const Key('welcome-url')),
        'https://example.com/a-rather-long-address/for-a-small-screen',
      );
      await t.pump();
      await tapKey(t, 'welcome-url-save');
      await settle(t);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('welcome-next-3')), findsOneWidget);
    });
  }
}
