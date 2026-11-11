// Host visual QA for the release-polish contract; not device evidence.
import 'package:flutter_test/flutter_test.dart';
import '../test/run14_test.dart' as host14;
import '../test/run15_fixtures.dart';
import '../test/run3_ui_test.dart' as host;
import '../test/run4_routines_test.dart' show tap;
import 'run10_screens_test.dart' show fonts, root, shot;

void main() {
  setUpAll(fonts);
  for (final width in [320.0, 415.0, 1440.0]) {
    for (final locale in ['en', 'vi']) {
      for (final theme in ['light', 'dark']) {
        for (final scale in [1.0, 1.5]) {
          testWidgets('release polish $width $locale $theme $scale', (t) async {
            await host14.bootRun14(
              t,
              state: convenienceSeed(locale: locale),
              width: width,
              locale: locale,
              theme: theme,
              scale: scale,
              boundary: root,
            );
            final stem =
                '${width.toInt()}-$locale-$theme-${(scale * 100).toInt()}';
            await host.go(t, '/welcome');
            await shot(t, '$stem-story');
            await tap(t, 'welcome-next');
            await tap(t, 'welcome-next');
            await shot(t, '$stem-practice');
            for (var i = 0; i < 6; i++) {
              await tap(t, 'welcome-do-it');
            }
            await tap(t, 'welcome-next');
            await shot(t, '$stem-final');
            host.nav(t).pop();
            await t.pumpAndSettle();
            await host.go(t, '/habits/batch');
            await tap(t, 'batch-water');
            await tap(t, 'batch-preview');
            await tap(t, 'editor-save');
            await shot(t, '$stem-archive');
          });
        }
      }
    }
  }
}
