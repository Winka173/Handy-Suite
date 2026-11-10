import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'screens_test.dart' as shots;
import 'run10_screens_test.dart' show fonts;
import '../test/run3_ui_test.dart' show go, nav;

void main() {
  setUpAll(fonts);
  for (final locale in ['en', 'vi']) {
    for (final theme in ['light', 'dark']) {
      testWidgets('320 enlarged type $locale $theme', (t) async {
        await shots.boot(
          t,
          const Size(320, 900),
          locale: locale,
          theme: theme,
          scale: 2,
        );
        for (final path in [
          '/today',
          '/routines',
          '/progress',
          '/routine/morning',
          '/help',
          '/help/mood',
          '/mood/2026-11-02',
          '/settings/trash',
        ]) {
          await go(t, path);
          await shots.shot(
            t,
            'r11-320-$locale-$theme-x2-${path.substring(1).replaceAll('/', '-')}',
          );
          expect(t.takeException(), isNull, reason: path);
          nav(t).pop();
          await t.pumpAndSettle();
        }
      });
    }
  }
}
