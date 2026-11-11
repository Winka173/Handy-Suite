// Host renders only. EN/VI x light/dark x 390/1440 x 100/150% text.
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import '../test/pro_test.dart' as p;
import '../test/run17_device_fixes_test.dart' show oneGoal;
import '../test/run3_ui_test.dart' as host;
import '../test/run4_routines_test.dart' show tap;
import 'run10_screens_test.dart' show fonts, root, shot;

void main() {
  setUpAll(fonts);
  for (final width in [390.0, 1440.0]) {
    for (final locale in ['en', 'vi']) {
      for (final theme in ['light', 'dark']) {
        for (final scale in [1.0, 1.5]) {
          p.proTest('run17 $width $locale $theme $scale', (t) async {
            final fake = p.FakeHabitStore()
              ..value = p.FakeHabitStore.snapshot('unavailable');
            final (controller, _, _) = await p.bootPro(
              t,
              state: oneGoal(habits: 0),
              fake: fake,
              width: width,
              locale: locale,
              theme: theme,
              scale: scale,
              boundary: root,
              open: false,
            );
            t.view.physicalSize = Size(width, width > 1000 ? 900 : 844);
            await t.pumpAndSettle();
            final stem =
                '${width.toInt()}-$locale-$theme-${(scale * 100).toInt()}';
            await shot(t, '$stem-today-empty');
            await controller.change(
              (s) => s.copy({
                'habits': oneGoal().habits
                    .map(
                      (h) => h.copy({
                        'title': locale == 'vi'
                            ? 'Đọc vài trang sách'
                            : 'Read a few pages',
                      }).toJson(),
                    )
                    .toList(),
              }),
            );
            await t.pumpAndSettle();
            await tap(t, 'bead-h0');
            await shot(t, '$stem-today-undo');
            ScaffoldMessenger.of(
              t.element(find.byType(SnackBar)),
            ).clearSnackBars();
            await host.go(t, '/progress');
            await shot(t, '$stem-progress');
            await tap(t, 'progress-method');
            await shot(t, '$stem-counting-sheet');
            await tap(t, 'progress-method-done');
            host.nav(t).pop();
            await t.pumpAndSettle();
            await host.go(t, '/templates');
            await shot(t, '$stem-templates');
            await t.enterText(
              find.byKey(const Key('template-search')),
              'water',
            );
            await t.pumpAndSettle();
            await shot(t, '$stem-water-icons');
            await t.enterText(find.byKey(const Key('template-search')), '');
            await tap(t, 'templates-routines');
            await shot(t, '$stem-routine-icons');
            host.nav(t).pop();
            await t.pumpAndSettle();
            await host.go(t, '/settings');
            await shot(t, '$stem-settings');
            await tap(t, 'settings-rules');
            host.nav(t).pop();
            await t.pumpAndSettle();
            await shot(t, '$stem-settings-convenience');
            await tap(t, 'settings-pro');
            host.nav(t).pop();
            await t.pumpAndSettle();
            await shot(t, '$stem-settings-pro');
            host.nav(t).pop();
            await t.pumpAndSettle();
            await host.go(t, '/pro?feature=reports');
            await t.pump(const Duration(seconds: 1));
            await shot(t, '$stem-pro-report');
            host.nav(t).pop();
            await t.pumpAndSettle();
            await host.go(t, '/pro?feature=convenience');
            await t.pump(const Duration(seconds: 1));
            await shot(t, '$stem-pro-convenience');
            host.nav(t).pop();
            await t.pumpAndSettle();
            await host.go(t, '/welcome');
            await tap(t, 'welcome-next');
            await tap(t, 'welcome-next');
            await tap(t, 'welcome-do-it');
            await tap(t, 'welcome-do-it');
            await tap(t, 'practice-goal');
            await shot(t, '$stem-practice-goal');
          });
        }
      }
    }
  }
}
