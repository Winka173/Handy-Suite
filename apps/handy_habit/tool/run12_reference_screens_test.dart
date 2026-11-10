// Run from the chosen sibling's own directory so its asset bundle stays correct.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import '../../handy_bookmark/tool/screens_test.dart' as bookmark;
import '../../handy_boards/tool/screens_test.dart' as boards;

void main() {
  final app = Platform.environment['REFERENCE_APP'] ?? 'boards';
  setUpAll(() async {
    final dirs = [
      ('PlusJakartaSans', '../handy_boards/fonts', 'PlusJakartaSans'),
      ('Newsreader', '../handy_bookmark/fonts', 'Newsreader'),
      ('Manrope', '../handy_bookmark/fonts', 'Manrope'),
      ('Geist', '../../packages/handy_ui/fonts', 'Geist-'),
      ('packages/handy_ui/Geist', '../../packages/handy_ui/fonts', 'Geist-'),
    ];
    for (final (family, dir, match) in dirs) {
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
  final locale = Platform.environment['STORE_LOCALE'] ?? 'en';
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final theme in ['light', 'dark']) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('$app $width $locale $theme $scale', (t) async {
          t.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          if (app == 'boards') {
            final c = await boards.boot(
              t,
              boards.sample(locale: locale, theme: theme),
              size: Size(width, 1000),
            );
            addTearDown(c.dispose);
          } else {
            await bookmark.boot(t, Size(width, 1000), theme: theme);
          }
          final shoot = app == 'boards' ? boards.shot : bookmark.shot;
          final stem =
              '$app-${width.toInt()}-$locale-$theme-${scale == 1 ? 100 : 150}';
          await t.runAsync(
            () => precacheImage(
              const AssetImage('assets/icon.png'),
              t.element(find.byType(Scaffold).first),
            ),
          );
          await shoot(t, '$stem-shell');
          for (final path in ['/how-to', '/pro']) {
            t
                .state<NavigatorState>(find.byType(Navigator).first)
                .pushNamed(path);
            await t.pumpAndSettle();
            await shoot(t, '$stem-${path == '/pro' ? 'pro' : 'help'}');
            t.state<NavigatorState>(find.byType(Navigator).first).pop();
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
