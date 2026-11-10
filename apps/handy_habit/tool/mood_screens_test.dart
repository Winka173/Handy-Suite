// Host rendering only. SHOTS_DIR points outside docs/qa/evidence.
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/run3_ui_test.dart' as host;
import '../test/run4_routines_test.dart' show tap;
import 'screens_test.dart' as shots;

void main() {
  setUpAll(() async {
    final nunito = FontLoader('Nunito');
    for (final f in Directory(
      'fonts',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
      nunito.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
    await nunito.load();
    final sdk =
        Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\Winka\flutter';
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.view(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ).readAsBytesSync().buffer,
          ),
        ),
      );
    await icons.load();
  });
  testWidgets('month calendar draws unknown marks with bundled Nunito', (
    t,
  ) async {
    final state = HabitState(
      habits: [
        Habit(
          id: 'reduce',
          title: 'Fewer sugary drinks',
          created: '2026-10-01',
          direction: 'reduce',
          type: 'count',
          schedules: [Schedule(id: 's', from: '2026-10-01')],
          negativeGoals: [
            NegativeGoal(id: 'g', from: '2026-10-01', limit: 3000),
          ],
        ),
      ],
      settings: {'onboarded': true},
    );
    await shots.boot(t, const Size(1440, 1000), locale: 'en', state: state);
    await host.go(t, '/progress');
    expect(find.byKey(const Key('calendar-unknown-mark')), findsWidgets);
    await shots.shot(t, '1440-en-light-100-progress-month-glyph');
    expect(t.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final locale in ['en', 'vi']) {
      for (final theme in ['light', 'dark']) {
        for (final scale in [1.0, 1.5]) {
          testWidgets('mood $width $locale $theme $scale', (t) async {
            final name =
                '${width.toInt()}-$locale-$theme-${(scale * 100).toInt()}';
            final c = await shots.boot(
              t,
              Size(width, width >= 1000 ? 1000 : 844),
              theme: theme,
              locale: locale,
              scale: scale,
            );
            await Scrollable.ensureVisible(
              t.element(find.byKey(const Key('today-mood'))),
              alignment: 1,
            );
            await shots.shot(t, '$name-today-unlogged');
            await tap(t, 'today-mood');
            await shots.shot(t, '$name-log');
            await tap(t, 'mood-details');
            await shots.shot(t, '$name-details');
            host.nav(t).pop();
            await t.pumpAndSettle();
            await c.change((s) {
              var next = s;
              for (var i = 0; i < 7; i++) {
                next = saveMood(
                  next,
                  addDays(shots.today, -i),
                  1 + i % 5,
                  energy: i == 0 ? 3 : null,
                  note: i == 0
                      ? (locale == 'vi'
                            ? 'Đi bộ sau giờ làm.'
                            : 'A walk after work.')
                      : '',
                  tags: i == 0
                      ? [locale == 'vi' ? 'Ngoài trời' : 'Outdoors']
                      : [],
                  now: shots.now,
                  expectedRevision: 0,
                );
              }
              return deleteMood(
                next,
                addDays(shots.today, -3),
                now: shots.now,
                expectedRevision: 1,
              );
            });
            await t.pumpAndSettle();
            await Scrollable.ensureVisible(
              t.element(find.byKey(const Key('today-mood'))),
              alignment: 1,
            );
            await shots.shot(t, '$name-today-logged');
            await c.change(
              (s) => s.copy({
                'settings': {...s.settings, 'showMoodToday': false},
              }),
            );
            await t.pumpAndSettle();
            await shots.shot(t, '$name-today-hidden');
            await host.go(t, '/progress');
            await t.ensureVisible(find.byKey(const Key('mood-history')));
            await shots.shot(t, '$name-progress-mood');
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  }
}
