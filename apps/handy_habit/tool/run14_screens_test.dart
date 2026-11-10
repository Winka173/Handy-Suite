import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/insights/insight_filters.dart';
import 'package:handy_habit/insights/smart_report.dart';
import 'package:handy_habit/insights/smart_review.dart';
import 'package:handy_habit/reminders.dart';
import '../test/run14_test.dart' as f;
import '../test/run3_ui_test.dart' as host;
import '../test/run4_routines_test.dart' show tap;
import 'run10_screens_test.dart' show fonts;

final root = GlobalKey();
Future<void> shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await t.pump(const Duration(milliseconds: 300));
  await t.runAsync(() async {
    final boundary =
        root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final im = await boundary.toImage(pixelRatio: 1.25);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    final dir = Platform.environment['SHOTS_DIR'] ?? 'build/run14/round1';
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    im.dispose();
  });
  expect(t.takeException(), isNull, reason: name);
}

Future<void> focus(WidgetTester t, Finder finder) async {
  await Scrollable.ensureVisible(t.element(finder.first), alignment: 0);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(fonts);
  for (final width in [320.0, 390.0, 1440.0])
    for (final locale in ['en', 'vi'])
      for (final theme in ['light', 'dark'])
        for (final scale in [1.0, 1.5]) {
          testWidgets('run14 $width $locale $theme $scale', (t) async {
            debugDefaultTargetPlatformOverride = TargetPlatform.android;
            try {
              final reminder = f.Run14Reminders(
                value: ReminderDiagnostics(
                  permission: HabitPermission.allowed,
                  exactAllowed: false,
                  batteryExempt: false,
                  lastScheduled: DateTime.utc(2024, 1, 8, 1),
                  nextScheduled: DateTime.utc(2024, 1, 9, 1),
                  scheduled: 50,
                ),
              );
              final (c, _, _) = await f.bootRun14(
                t,
                width: width,
                locale: locale,
                theme: theme,
                scale: scale,
                reminders: reminder,
                boundary: root,
              );
              final stem =
                  '${width.toInt()}-$locale-$theme-${scale == 1 ? 100 : 150}';
              await host.go(t, '/progress/smart');
              await shot(t, '$stem-insights-top');
              for (final (i, name) in [
                (1, 'groups'),
                (2, 'collections'),
                (3, 'weekdays'),
                (4, 'mood'),
              ]) {
                await focus(t, find.byKey(Key('smart-section-$i')));
                await shot(t, '$stem-insights-$name');
              }
              await focus(t, find.byType(InsightFilters));
              await shot(t, '$stem-insights-heatmap');
              final chip = find.byKey(const Key('smart-filter-time'));
              await Scrollable.ensureVisible(t.element(chip), alignment: .5);
              await t.pumpAndSettle();
              await t.tap(chip);
              await t.pumpAndSettle();
              await shot(t, '$stem-filter-sheet');
              host.nav(t).pop();
              await t.pumpAndSettle();
              final weekday = find.byKey(const Key('smart-filter-weekday'));
              await Scrollable.ensureVisible(t.element(weekday), alignment: .5);
              await t.pumpAndSettle();
              await t.tap(weekday);
              await t.pumpAndSettle();
              await shot(t, '$stem-weekday-sheet');
              host.nav(t).pop();
              await t.pumpAndSettle();
              await tap(t, 'smart-report');
              await shot(t, '$stem-report-preview');
              final ctx = t.element(find.byKey(const Key('smart-report-save')));
              final sections = smartReview(
                ctx,
                c.state!,
                host.now.toIso8601String().substring(0, 10),
                'month',
              );
              await t.runAsync(() async {
                final bytes = await smartReportPdf(
                  sections,
                  today: '2024-01-08',
                  zone: c.state!.zone,
                  vi: locale == 'vi',
                );
                File('build/run14/report-$stem.pdf').writeAsBytesSync(bytes);
              });
              await host.go(t, '/settings/notifications');
              await shot(t, '$stem-notifications');
              await focus(t, find.byKey(const Key('set-notifications')));
              await shot(t, '$stem-notifications-rules');
              await host.go(t, '/settings/notifications/diagnostics');
              await shot(t, '$stem-diagnostics');
              await focus(t, find.byKey(const Key('diagnostics-last')));
              await shot(t, '$stem-diagnostics-test');
              await host.go(t, '/settings/widgets');
              await shot(t, '$stem-widgets-compact');
              await tap(t, 'widget-size-large');
              await shot(t, '$stem-widgets-large');
              await focus(t, find.byKey(const Key('widget-preview-habit')));
              await shot(t, '$stem-widgets-habit');
              await focus(t, find.byKey(const Key('widget-preview-routine')));
              await shot(t, '$stem-widgets-routine');
              expect(t.takeException(), isNull);
            } finally {
              debugDefaultTargetPlatformOverride = null;
            }
          });
        }
  testWidgets('run14 supplemental palette and permission states', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final r = f.Run14Reminders();
      final (c, _, _) = await f.bootRun14(t, reminders: r, boundary: root);
      for (final palette in ['vermilion', 'grove', 'ochre'])
        for (final theme in ['light', 'dark']) {
          await c.change(
            (s) => s.copy({
              'settings': {
                ...s.settings,
                'theme': theme,
                'studio': {'palette': palette},
              },
            }),
          );
          await host.go(t, '/settings/widgets');
          await tap(t, 'widget-size-large');
          await shot(t, 'extra-$palette-$theme-widgets');
        }
      for (final permission in [
        HabitPermission.denied,
        HabitPermission.error,
        HabitPermission.unsupported,
        HabitPermission.unreadable,
      ]) {
        r.value = ReminderDiagnostics(permission: permission);
        r.available = permission != HabitPermission.unsupported;
        await host.go(t, '/settings/notifications/diagnostics');
        await shot(t, 'extra-${permission.name}-diagnostics');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
