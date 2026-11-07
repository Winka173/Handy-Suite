import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/settings/help_links.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestStore;
import 'pictures_test.dart' show png;
import 'widget_test.dart' show start, tapKey;

Future<void> openSettings(WidgetTester t) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/settings');
  await t.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester t, String key) => t.scrollUntilVisible(
  find.byKey(Key(key)),
  300,
  scrollable: find.byType(Scrollable).first,
);

void main() {
  tearDown(() => openExternal = (_) async => false);

  testWidgets('How to use: the welcome again, then topics; a topic opens '
      'as steps with Previous, Next and Done', (t) async {
    await start(t, size: const Size(390, 844));
    await openSettings(t);
    await scrollTo(t, 'set-howto');
    await tapKey(t, 'set-howto');
    expect(find.byKey(const Key('howto-replay')), findsOneWidget);
    for (final id in ['faster', 'home', 'organize', 'find', 'read', 'safe']) {
      await scrollTo(t, 'howto-topic-$id');
      expect(find.byKey(Key('howto-topic-$id')), findsOneWidget);
    }
    await t.scrollUntilVisible(
      find.byKey(const Key('howto-topic-faster')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapKey(t, 'howto-topic-faster');
    expect(find.byKey(const Key('howto-sheet-faster')), findsOneWidget);
    expect(find.text('Open the share menu'), findsWidgets);
    expect(find.byKey(const Key('howto-action-0')), findsOneWidget);
    expect(find.byKey(const Key('howto-previous')), findsNothing);
    await tapKey(t, 'howto-next');
    expect(find.byKey(const Key('howto-sheet-home')), findsOneWidget);
    await tapKey(t, 'howto-previous');
    expect(find.byKey(const Key('howto-sheet-faster')), findsOneWidget);
    await tapKey(t, 'howto-done');
    expect(find.byKey(const Key('howto-sheet-faster')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('How to use fits 320 px at 200% text', (t) async {
    await start(t, size: const Size(320, 640), textScale: 2);
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/how-to');
    await t.pumpAndSettle();
    await t.drag(find.byType(Scrollable).first, const Offset(0, -6000));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Send feedback writes to the studio address; without a mail '
      'app it says the address and offers Copy', (t) async {
    await start(t);
    await openSettings(t);
    final opened = <Uri>[];
    openExternal = (uri) async {
      opened.add(uri);
      return true;
    };
    await scrollTo(t, 'set-feedback');
    expect(find.text('apps.winka.studio@gmail.com'), findsOneWidget);
    await tapKey(t, 'set-feedback');
    expect(opened.single.scheme, 'mailto');
    expect(opened.single.path, 'apps.winka.studio@gmail.com');
    expect(
      Uri.decodeComponent(opened.single.query),
      contains('Handy Bookmark feedback'),
    );

    openExternal = (_) async => false;
    await tapKey(t, 'set-feedback');
    expect(find.byKey(const Key('feedback-no-mail')), findsOneWidget);
    expect(find.textContaining('apps.winka.studio@gmail.com'), findsWidgets);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('privacy policy and terms say plainly they are not published '
      'yet; terms opens nothing', (t) async {
    await start(t);
    await openSettings(t);
    await scrollTo(t, 'set-terms');
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Terms of service'), findsOneWidget);
    expect(find.text('Not published yet'), findsOneWidget);
    await tapKey(t, 'set-terms');
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('Delete all data asks first, then removes items, pictures '
      'and the library settings', (t) async {
    final store = TestStore();
    store.now = () => DateTime.now().subtract(const Duration(days: 30));
    final c = await start(
      t,
      store: store,
      seed: (c) async {
        await c.quickSave('https://a.com/one');
        await c.update((l) => l, prefs: {...c.preferences, 'look': 'x'});
      },
    );
    // Pictures are prepared on another isolate: wait for it in real time.
    unawaited(c.addPictures([(bytes: png(32, 24), name: 'one.png')]));
    for (
      var i = 0;
      i < 50 && !c.library!.bookmarks.any((b) => b.isImage);
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
    }
    store.now = DateTime.now;
    expect(store.ownedMedia, isNotEmpty);
    await openSettings(t);
    await scrollTo(t, 'save-reset');
    await tapKey(t, 'save-reset');
    expect(find.text('Delete all data?'), findsOneWidget);
    await t.tap(find.text('Delete all data').last);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    expect(c.library!.bookmarks, isEmpty);
    expect(store.ownedMedia, isEmpty);
    expect(c.preferences['look'], isNull);
  });
}
