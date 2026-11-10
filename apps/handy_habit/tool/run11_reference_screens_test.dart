// Run from apps/handy_bookmark, with STORE_LOCALE=en or vi and SHOTS_DIR.
// Reuses each sibling's real renderer and fixtures without editing its source.
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import '../../handy_bookmark/tool/screens_test.dart' as bookmark;
import '../../handy_boards/tool/screens_test.dart' as boards;

Future<void> go(WidgetTester t, String path) async {
  t.state<NavigatorState>(find.byType(Navigator).first).pushNamed(path);
  await t.pumpAndSettle();
}

Future<void> reveal(WidgetTester t, String key) async {
  final item = find.byKey(Key(key));
  if (item.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      item,
      250,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .hitTestable()
          .last,
    );
  }
  await t.ensureVisible(item);
  await t.pumpAndSettle();
}

Future<void> firstTopic(WidgetTester t) async {
  await t.tap(
    find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('howto-topic-'),
        )
        .first,
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
    for (final (family, dir, match) in [
      ('packages/handy_ui/Geist', '../../packages/handy_ui/fonts', 'Geist-'),
      ('Geist', '../../packages/handy_ui/fonts', 'Geist-'),
      (
        'packages/handy_ui/GeistMono',
        '../../packages/handy_ui/fonts',
        'GeistMono-',
      ),
      ('Newsreader', 'fonts', 'Newsreader'),
      ('Manrope', 'fonts', 'Manrope'),
      ('PlusJakartaSans', '../handy_boards/fonts', 'PlusJakartaSans'),
    ]) {
      await boards.loadFont(family, [
        for (final file in Directory(dir).listSync())
          if (file.path.endsWith('.ttf') && file.path.contains(match))
            file.path,
      ]);
    }
    await boards.loadFont('MaterialIcons', [
      'C:/Users/Winka/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });
  final locale = Platform.environment['STORE_LOCALE'] ?? 'vi';
  for (final width in [390.0, 1440.0]) {
    for (final theme in ['light', 'dark']) {
      final stem = '${width.toInt()}-$locale-$theme';
      testWidgets('Bookmark matrix $stem', (t) async {
        await bookmark.boot(t, Size(width, 900), theme: theme);
        await bookmark.shot(t, 'bookmark-$stem-shell');
        for (final (name, route) in [
          ('settings', '/settings'),
          ('help', '/how-to'),
          ('trash', '/trash'),
        ]) {
          await go(t, route);
          await bookmark.shot(t, 'bookmark-$stem-$name');
          if (name == 'settings') {
            await reveal(t, 'save-backup');
            await bookmark.shot(t, 'bookmark-$stem-settings-data');
          }
          if (name == 'help') {
            await firstTopic(t);
            await bookmark.shot(t, 'bookmark-$stem-help-detail');
          }
          t.state<NavigatorState>(find.byType(Navigator).first).pop();
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
      testWidgets('Boards matrix $stem', (t) async {
        final c = await boards.boot(
          t,
          boards.sample(locale: locale, theme: theme),
          size: Size(width, 900),
        );
        await boards.shot(t, 'boards-$stem-shell');
        for (final (name, route) in [
          ('settings', '/settings'),
          ('help', '/how-to'),
          ('trash', '/trash'),
        ]) {
          await go(t, route);
          await boards.shot(t, 'boards-$stem-$name');
          if (name == 'settings') {
            await reveal(t, 'settings-backup');
            await boards.shot(t, 'boards-$stem-settings-data');
          }
          if (name == 'help') {
            await firstTopic(t);
            await boards.shot(t, 'boards-$stem-help-detail');
          }
          t.state<NavigatorState>(find.byType(Navigator).first).pop();
          await t.pumpAndSettle();
        }
        await t.pumpWidget(const SizedBox());
        c.dispose();
      });
    }
  }
}
