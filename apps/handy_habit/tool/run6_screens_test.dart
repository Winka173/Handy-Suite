// Host renders only, with real Nunito and icons. No devices or real store.
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/habits/month_grid.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/run4_routines_test.dart' show route, tap;
import 'run5_screens_test.dart' show loadFont, top, reveal;
import 'screens_test.dart' as shots;
import 'dart:io';

HabitState mixed(bool vi) {
  const start = '2026-10-05';
  final habits = [
    Habit(
      id: 'read',
      title: vi ? 'Đọc một chút' : 'Read a little',
      created: start,
      color: 0xffa16207,
      schedules: [Schedule(id: 'read-plan', from: start)],
    ),
    for (final row in [
      (
        'drinks',
        vi ? 'Bớt nước ngọt' : 'Fewer sugary drinks',
        'day',
        3000,
        0xff2563eb,
      ),
      (
        'snacks',
        vi ? 'Bớt ăn khuya' : 'Less late-night snacking',
        'week',
        3000,
        0xff4d7c0f,
      ),
      (
        'social',
        vi ? 'Bớt mạng xã hội' : 'Less social media',
        'day',
        0,
        0xffa16207,
      ),
    ])
      Habit(
        id: row.$1,
        title: row.$2,
        type: 'count',
        direction: 'reduce',
        created: start,
        color: row.$5,
        schedules: [Schedule(id: '${row.$1}-plan', from: start)],
        negativeGoals: [
          NegativeGoal(
            id: '${row.$1}-limit',
            from: start,
            window: row.$3,
            limit: row.$4,
          ),
        ],
      ),
  ];
  final events = <HabitEvent>[];
  for (var i = 0; i < 28; i++) {
    final d = addDays(start, i);
    if (i % 4 != 0)
      events.add(HabitEvent(id: 'read-$i', habit: 'read', day: d, value: 1000));
    if (i % 5 != 0)
      events.add(
        HabitEvent(
          id: 'drinks-$i',
          habit: 'drinks',
          day: d,
          value: i % 4 == 0 ? 4000 : i % 3 * 1000,
        ),
      );
    events.add(
      HabitEvent(
        id: 'snacks-$i',
        habit: 'snacks',
        day: d,
        value: i % 7 == 0 ? 2000 : 0,
      ),
    );
    if (i % 3 != 0)
      events.add(
        HabitEvent(id: 'social-$i', habit: 'social', day: d, value: 0),
      );
  }
  events.add(
    HabitEvent(
      id: 'drinks-today',
      habit: 'drinks',
      day: shots.today,
      value: 2000,
    ),
  );
  events.add(
    HabitEvent(
      id: 'snacks-today',
      habit: 'snacks',
      day: shots.today,
      value: 4000,
    ),
  );
  final s = HabitState(
    habits: habits,
    events: events,
    settings: {'onboarded': true, 'reducedMotion': true},
  );
  assert(HabitIndex.of(s).value('drinks', shots.today) == 2000);
  assert(!HabitIndex.of(s).known('social', shots.today));
  return s;
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
          testWidgets('R10 R11 render $name', (t) async {
            await shots.boot(
              t,
              Size(width, width > 1000 ? 1000 : 900),
              locale: locale,
              theme: theme,
              scale: scale,
              state: mixed(locale == 'vi'),
            );
            await shots.shot(t, '$name-today');
            await reveal(t, 'bead-social');
            await shots.shot(t, '$name-today-unknown');
            await route(t, '/habit/drinks');
            await shots.shot(t, '$name-history');
            await t.ensureVisible(find.byType(MonthGrid));
            await shots.shot(t, '$name-history-month');
            await route(t, '/progress/week?from=2026-10-26');
            await shots.shot(t, '$name-review');
            await reveal(t, 'week-review-snacks');
            await shots.shot(t, '$name-review-weekly');
            await route(t, '/progress');
            await shots.shot(t, '$name-progress');
            await route(t, '/habit/new');
            await shots.shot(t, '$name-create-choice');
            await tap(t, 'field-direction-reduce');
            await t.enterText(
              find.byKey(const Key('field-title')),
              locale == 'vi' ? 'Bớt nước ngọt' : 'Fewer sugary drinks',
            );
            await tap(t, 'field-ceilingMode-limit');
            await t.enterText(find.byKey(const Key('field-ceiling')), '3');
            await tap(t, 'field-window-week');
            await top(t);
            await shots.shot(t, '$name-create');
            await reveal(t, 'field-window-week');
            await shots.shot(t, '$name-create-limit');
            expect(t.takeException(), isNull);
          });
        }
  for (final scale in [1.0, 1.5]) {
    testWidgets('practice coach clears goal at 390 VI scale $scale', (t) async {
      await shots.boot(
        t,
        const Size(390, 900),
        locale: 'vi',
        scale: scale,
        state: HabitState(settings: {'reducedMotion': true}),
      );
      await tap(t, 'welcome-next');
      await tap(t, 'welcome-next');
      await reveal(t, 'practice-instruction-0');
      final word = t.getRect(find.byKey(const Key('practice-instruction-0')));
      final goal = t.getRect(find.byKey(const Key('practice-goal')));
      expect(word.overlaps(goal), isFalse);
      await shots.shot(
        t,
        '390-vi-light-${scale == 1 ? '100' : '150'}-practice-0',
      );
    });
  }
}
