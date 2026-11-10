// Host widget renders with real Nunito/icons; no device or browser claims.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/run4_routines_test.dart' show route, tap;
import 'run5_screens_test.dart' show loadFont, top, reveal;
import 'run6_screens_test.dart' show mixed;
import 'screens_test.dart' as shots;

HabitState fixture(bool vi) {
  final s = mixed(vi);
  final routine = routineTemplateCatalog.first.instantiate(vietnamese: vi);
  final sessions = [
    for (var i = 1; i <= 4; i++)
      RoutineSession(
        id: 'run$i',
        routine: routine.id,
        title: routine.title,
        started: '${addDays(shots.today, -i)}T07:00:00Z',
        day: addDays(shots.today, -i),
        steps: [
          for (final st in routine.steps)
            StepRun(plan: st, status: 'completed', elapsed: st.seconds),
        ],
        cursor: 2,
        status: 'finished',
        ended: '${addDays(shots.today, -i)}T07:08:00Z',
      ),
  ];
  final habits = [
    for (final h in s.habits)
      h.copy({
        'created': '2026-01-05',
        'schedules': [
          for (final p in h.schedules) {...p.toJson(), 'from': '2026-01-05'},
        ],
        'negativeGoals': [
          for (final g in h.negativeGoals)
            {...g.toJson(), 'from': '2026-01-05'},
        ],
      }),
  ];
  final events = <HabitEvent>[];
  for (var i = 0; i < 301; i++) {
    final d = addDays('2026-01-05', i);
    if (i % 4 != 0)
      events.add(HabitEvent(id: 'r$i', habit: 'read', day: d, value: 1000));
    if (i % 3 == 0)
      events.add(
        HabitEvent(
          id: 'd$i',
          habit: 'drinks',
          day: d,
          value: i % 9 == 0 ? 4000 : 1000,
        ),
      );
    if (i % 8 == 0)
      events.add(
        HabitEvent(
          id: 's$i',
          habit: 'snacks',
          day: d,
          value: i % 24 == 0 ? 4000 : 1000,
        ),
      );
    if (i % 5 == 0)
      events.add(HabitEvent(id: 'n$i', habit: 'social', day: d, value: 0));
  }
  return HabitState(
    habits: habits,
    events: events,
    routines: [routine],
    sessions: sessions,
    settings: {'onboarded': true, 'reducedMotion': true},
  );
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
          testWidgets('R12 R13 render $name', (t) async {
            await shots.boot(
              t,
              Size(width, width > 1000 ? 1000 : 900),
              locale: locale,
              theme: theme,
              scale: scale,
              state: fixture(locale == 'vi'),
            );
            await shots.shot(t, '$name-today-copy');
            await route(t, '/templates');
            await shots.shot(t, '$name-gallery');
            await t.enterText(
              find.byKey(const Key('template-search')),
              'nuoc ngot',
            );
            await t.pumpAndSettle();
            await shots.shot(t, '$name-search');
            await tap(t, 'preset-sugary-drinks');
            await shots.shot(t, '$name-preview');
            await tap(t, 'template-customise');
            await shots.shot(t, '$name-customise');
            await reveal(t, 'field-window-week');
            await shots.shot(t, '$name-customise-limit');
            await route(t, '/templates?kind=routine');
            await shots.shot(t, '$name-routine-gallery');
            await tap(t, 'featured-study');
            await shots.shot(t, '$name-routine-preview');
            await route(t, '/progress');
            await shots.shot(t, '$name-progress-month');
            await reveal(t, 'progress-calendar');
            await shots.shot(t, '$name-calendar');
            await tap(t, 'range-week');
            await top(t);
            await shots.shot(t, '$name-progress-week');
            await tap(t, 'range-year');
            await top(t);
            await shots.shot(t, '$name-progress-year');
            await reveal(t, 'year-heatmap');
            await shots.shot(t, '$name-heatmap');
            await tap(t, 'progress-habit-filter');
            await t.tap(
              find
                  .text(
                    locale == 'vi'
                        ? 'Bớt ăn khuya'
                        : 'Less late-night snacking',
                  )
                  .last,
            );
            await t.pumpAndSettle();
            await shots.shot(t, '$name-heatmap-habit');
            expect(t.takeException(), isNull);
          });
        }
}
