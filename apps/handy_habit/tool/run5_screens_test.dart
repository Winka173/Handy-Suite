// Host rendering only. No device, permission prompt, or real data store.
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_habit/settings/help_topics.dart';
import 'package:handy_ui/kit.dart';
import '../test/run4_routines_test.dart' show route;
import '../test/run5_learning_test.dart' show tap;
import 'screens_test.dart' as shots;

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths)
    loader.addFont(
      Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
    );
  await loader.load();
}

Future<void> top(WidgetTester t) async {
  final scroll = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .last;
  t.state<ScrollableState>(scroll).position.jumpTo(0);
  await t.pumpAndSettle();
}

Future<void> reveal(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await top(t);
    await t.scrollUntilVisible(
      f,
      250,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
      maxScrolls: 80,
    );
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadFont('Nunito', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    final sdk =
        Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\Winka\flutter';
    await loadFont('MaterialIcons', [
      '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });
  for (final width in [320.0, 390.0, 1440.0])
    for (final locale in ['en', 'vi'])
      for (final theme in ['light', 'dark'])
        for (final scale in [1.0, 1.5]) {
          final name =
              '${width.toInt()}-$locale-$theme-${scale == 1 ? '100' : '150'}';
          testWidgets('R8 R9 render $name', (t) async {
            final c = await shots.boot(
              t,
              Size(width, width > 1000 ? 1000 : 900),
              locale: locale,
              theme: theme,
              scale: scale,
              state: HabitState(settings: {'reducedMotion': true}),
            );
            await shots.shot(t, '$name-stage1-scattered');
            await tap(t, 'welcome-next');
            await top(t);
            await shots.shot(t, '$name-stage1-gathered');
            await tap(t, 'welcome-next');
            for (var i = 0; i <= 6; i++) {
              await top(t);
              // Bring the instruction and target into view at enlarged text.
              await reveal(t, 'practice-instruction-$i');
              await shots.shot(t, '$name-practice-$i');
              if (i < 6) await tap(t, 'welcome-do-it');
            }
            await tap(t, 'welcome-next');
            await top(t);
            await shots.shot(t, '$name-stage3');
            await tap(t, 'welcome-next');
            await top(t);
            await shots.shot(t, '$name-empty-goals');
            await route(t, '/help');
            await shots.shot(t, '$name-help');
            await t.enterText(
              find.byKey(const Key('help-search')),
              'thoi quen',
            );
            await t.pumpAndSettle();
            await shots.shot(t, '$name-help-search');
            await t.enterText(find.byKey(const Key('help-search')), 'zzzz');
            await t.pumpAndSettle();
            await shots.shot(t, '$name-help-no-match');
            for (final topic in habitHelpTopics) {
              await route(t, '/help/${topic.id}');
              await shots.shot(t, '$name-help-${topic.id}');
              t.state<NavigatorState>(find.byType(Navigator).first).pop();
              await t.pumpAndSettle();
            }
            await route(t, '/settings');
            await shots.shot(t, '$name-settings');
            for (final (id, key) in [
              ('habits', 'settings-default-schedule'),
              ('routines', 'settings-routine-timer'),
              ('notifications', 'notification-status'),
              ('pauses', 'pause-add'),
              ('data', 'habit-backup'),
              ('learning', 'settings-help'),
              ('about', 'settings-whats-new'),
              ('reset', 'settings-reset'),
            ]) {
              await reveal(t, key);
              await shots.shot(t, '$name-settings-$id');
            }
            expect(t.takeException(), isNull, reason: name);
            expect(c.state!.habits, isEmpty);
            expect(c.state!.events, isEmpty);
          });
        }
}
