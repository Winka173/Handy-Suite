import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/run14_test.dart' as host14;
import '../test/run15_fixtures.dart';
import '../test/run3_ui_test.dart' as host;
import '../test/run4_routines_test.dart' show tap;
import 'run10_screens_test.dart' show fonts;
import 'run14_screens_test.dart' show shot, root, focus;

void main() {
  setUpAll(fonts);
  for (final width in [320.0, 390.0, 1440.0])
    for (final locale in ['en', 'vi'])
      for (final theme in ['light', 'dark'])
        for (final scale in [1.0, 1.5]) {
          testWidgets('run15 $width $locale $theme $scale', (t) async {
            debugDefaultTargetPlatformOverride = TargetPlatform.android;
            try {
              final (c, _, _) = await host14.bootRun14(
                t,
                state: convenienceSeed(locale: locale),
                width: width,
                locale: locale,
                theme: theme,
                scale: scale,
                boundary: root,
              );
              final stem =
                  '${width.toInt()}-$locale-$theme-${scale == 1 ? 100 : 150}';
              await host.go(t, '/habits');
              await shot(t, '$stem-saved-habits');
              await tap(t, 'save-filter-habits');
              await shot(t, '$stem-save-filter');
              host.nav(t).pop();
              await t.pumpAndSettle();
              await host.go(t, '/progress');
              await shot(t, '$stem-saved-progress');
              await host.go(t, '/habits/batch');
              await tap(t, 'batch-water');
              await tap(t, 'batch-walk');
              await shot(t, '$stem-batch-select');
              await tap(t, 'batch-preview');
              await shot(t, '$stem-batch-options');
              await tap(t, 'editor-save');
              await shot(t, '$stem-batch-preview');
              host.nav(t).pop();
              await t.pumpAndSettle();
              host.nav(t).pop();
              await t.pumpAndSettle();
              await host.go(t, '/settings/rules');
              await shot(t, '$stem-rules');
              await focus(
                t,
                find.byKey(
                  Key('rule-undo-${convenienceHistory(c.state!).last.$1.id}'),
                ),
              );
              await shot(t, '$stem-rules-history');
              await focus(t, find.byKey(const Key('rule-add')));
              await tap(t, 'rule-add');
              await shot(t, '$stem-rule-form');
              // Host renders are explicit fixtures, never a device/store result.
              expect(t.takeException(), isNull);
            } finally {
              debugDefaultTargetPlatformOverride = null;
            }
          });
        }
}
