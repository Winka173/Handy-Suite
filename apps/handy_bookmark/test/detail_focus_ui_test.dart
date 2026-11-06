import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestStore;
import 'link_tasks_test.dart' show FakeNet;
import 'new_flows_test.dart' show NetController, OneFile, settle;
import 'pictures_test.dart' show png;
import 'widget_test.dart' show Preferences, tapKey;

/// A store that can lose a picture's original but keep its preview, as
/// after a restore from a light backup.
class PreviewOnlyStore extends TestStore {
  bool originals = true;
  @override
  Future<Uint8List?> media(String id, {bool preview = false}) =>
      !preview && !originals
      ? Future.value(null)
      : super.media(id, preview: preview);
}

Future<(NetController, PreviewOnlyStore)> start(
  WidgetTester t, {
  String theme = 'light',
  Size size = const Size(400, 900),
  double textScale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final store = PreviewOnlyStore();
  final c = NetController(store, FakeNet());
  await t.runAsync(c.initialize);
  for (final u in ['https://a.com/one', 'https://b.org/two']) {
    await c.quickSave(u, title: 'Page ${u.split('/').last}');
  }
  await t.pumpWidget(
    SaveApp(
      controller: c,
      files: OneFile(),
      preferences: Preferences()
        ..value = HandyPreferences(locale: 'en', theme: theme),
      guide: false,
    ),
  );
  await settle(t);
  addTearDown(c.dispose);
  return (c, store);
}

Future<String> addPicture(WidgetTester t, NetController c) async {
  unawaited(c.addPictures([(bytes: png(900, 600), name: 'Menu board.png')]));
  for (var i = 0; i < 50 && !c.library!.bookmarks.any((b) => b.isImage); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump();
  }
  return c.library!.bookmarks.firstWhere((b) => b.isImage).id;
}

Future<void> openItem(WidgetTester t, String id) async {
  Navigator.of(
    t.element(find.byType(Scaffold).first),
  ).pushNamed('/bookmark/$id');
  await settle(t, 100);
}

Color? textColor(WidgetTester t, Finder f) => t
    .widget<RichText>(find.descendant(of: f, matching: find.byType(RichText)))
    .text
    .style
    ?.color;

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets('the picture viewer is light on black in the $theme theme', (
      t,
    ) async {
      final (c, _) = await start(t, theme: theme);
      await openItem(t, await addPicture(t, c));
      await tapKey(t, 'detail-view-picture');
      await settle(t, 100);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final title = textColor(t, find.byKey(const Key('picture-title')))!;
      final file = textColor(t, find.byKey(const Key('picture-file')))!;
      final close = textColor(t, find.byKey(const Key('picture-close')))!;
      for (final (name, color) in [
        ('title', title),
        ('file line', file),
        ('close', close),
      ]) {
        expect(
          color.computeLuminance(),
          greaterThan(.55),
          reason: '$name must be light on black',
        );
      }
      final bar = t.widget<AppBar>(find.byType(AppBar).last);
      expect(bar.systemOverlayStyle?.statusBarIconBrightness, Brightness.light);
      expect(bar.backgroundColor, Colors.black);
      // Escape closes it on desktop and the web.
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(t);
      expect(find.byKey(const Key('picture-view')), findsNothing);
      expect(find.byKey(const Key('detail')), findsOneWidget);
    });
  }

  testWidgets('with only the preview left, the viewer shows it and says so', (
    t,
  ) async {
    final (c, store) = await start(t);
    final id = await addPicture(t, c);
    store.originals = false;
    await openItem(t, id);
    await tapKey(t, 'detail-view-picture');
    await settle(t, 100);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byKey(const Key('picture-preview-only')), findsOneWidget);
    expect(find.textContaining('Only a small preview'), findsOneWidget);
  });

  testWidgets('a link opens with one main action; the tools are folded and '
      'nothing is lost behind the fold', (t) async {
    final (c, _) = await start(t);
    final id = c.library!.bookmarks.first.id;
    await openItem(t, id);
    expect(find.byKey(const Key('save-open-original')), findsOneWidget);
    expect(find.byType(FilledButton).evaluate().length, greaterThan(0));
    for (final key in [
      'detail-favorite',
      'detail-move',
      'detail-rename',
      'detail-share',
      'detail-reader',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    // Copy link waits in the "…"; reminders and pins are no longer made here.
    for (final key in ['detail-copy', 'detail-remind', 'detail-pin']) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
    expect(find.byKey(const Key('detail-check')), findsNothing);
    await tapKey(t, 'detail-tools');
    for (final key in [
      'detail-read',
      'detail-archive',
      'detail-metadata',
      'detail-copy-save',
      'detail-check',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.byKey(const Key('detail-pin')), findsNothing);
    expect(find.byKey(const Key('detail-unpin')), findsNothing);
  });

  testWidgets('an item pinned before pins were retired shows its state and '
      'one Unpin; nothing else changes', (t) async {
    final (c, _) = await start(t);
    final id = c.library!.bookmarks.first.id;
    await t.runAsync(
      () => c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              b.id == id ? b.copyWith(isPinned: true) : b,
          ],
        ),
      ),
    );
    await openItem(t, id);
    // The folded header carries the state, so it shows without opening.
    expect(find.text('Pinned'), findsOneWidget);
    await tapKey(t, 'detail-tools');
    await tapKey(t, 'detail-unpin');
    final after = c.library!.bookmarks.firstWhere((b) => b.id == id);
    expect(after.isPinned, isFalse);
    expect(after.title, 'Page one');
    expect(find.byKey(const Key('detail-unpin')), findsNothing);
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('detail and Focus fit 320px at 200% text ($theme)', (t) async {
      final (c, _) = await start(
        t,
        theme: theme,
        size: const Size(320, 640),
        textScale: 2,
      );
      await addPicture(t, c);
      for (final b in c.library!.bookmarks) {
        await openItem(t, b.id);
        expect(t.takeException(), isNull, reason: 'detail ${b.title}');
        await tapKey(t, 'detail-tools');
        expect(t.takeException(), isNull, reason: 'tools ${b.title}');
        Navigator.of(t.element(find.byKey(const Key('detail')))).pop();
        await settle(t);
      }
      Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/focus');
      await settle(t, 100);
      expect(t.takeException(), isNull, reason: 'focus');
      await t.drag(find.byKey(const Key('focus-card')), const Offset(60, 0));
      await t.pump(const Duration(milliseconds: 50));
      expect(t.takeException(), isNull, reason: 'focus mid-drag');
      await settle(t);
    });
  }

  testWidgets('with reduced motion a swipe still counts, and the card does '
      'not turn', (t) async {
    final (c, _) = await start(t);
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/focus');
    await settle(t, 100);
    final gesture = await t.startGesture(
      t.getCenter(find.byKey(const Key('focus-card'))),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(40, 0));
    await t.pump();
    final turns = find.descendant(
      of: find.byKey(const Key('focus-card')),
      matching: find.byType(Transform),
    );
    for (final e in turns.evaluate()) {
      final m = (e.widget as Transform).transform;
      // No rotation: the upper-left 2×2 stays a pure scale.
      expect(m.entry(0, 1).abs(), lessThan(1e-9));
    }
    expect(c.library!.bookmarks.every((b) => !b.isRead), isTrue);
    await gesture.moveBy(const Offset(220, 0));
    await gesture.up();
    await settle(t);
    expect(c.library!.bookmarks.where((b) => b.isRead), hasLength(1));
  });
}
