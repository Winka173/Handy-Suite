import 'dart:convert';
import 'dart:io';
import 'package:handy_habit_engine/handy_habit_engine.dart';

HabitState scaleFixture(int count) {
  const from = '2021-01-01';
  final routines = [
    for (var i = 0; i < 200; i++)
      Routine(
        id: 'r$i',
        title: 'Routine $i',
        steps: [RoutineStep(id: 's$i', title: 'Breathe')],
      ),
  ];
  return HabitState(
    habits: [
      for (var i = 0; i < count; i++)
        Habit(
          id: 'h$i',
          title: 'Habit $i',
          created: from,
          schedules: [Schedule(id: 'g$i', from: from)],
        ),
    ],
    events: [
      for (var i = 0; i < count; i++)
        for (var d = 0; d < 1095; d++)
          HabitEvent(
            id: 'e$i-$d',
            habit: 'h$i',
            day: addDays(from, d),
            value: 1000,
          ),
    ],
    routines: routines,
    sessions: [
      for (final r in routines)
        startSession(
          r,
          from,
          DateTime.utc(2021),
        ).copy({'status': 'finished', 'anchor': null}),
    ],
    moods: [
      for (var d = 0; d < 2000; d++)
        MoodEntry(
          day: addDays('2018-01-01', d),
          mood: 1 + d % 5,
          recordedAt: '${addDays('2018-01-01', d)}T12:00:00Z',
        ),
    ],
    settings: {'onboarded': true},
  );
}

void main(List<String> args) {
  final count = int.parse(args.first), s = scaleFixture(int.parse(args.first));
  const today = '2024-01-01';
  void measure(String name, Object? Function() action) {
    final watch = Stopwatch()..start();
    try {
      final value = action();
      stdout.writeln(
        jsonEncode({
          'habits': count,
          'metric': name,
          'ms': watch.elapsedMicroseconds / 1000,
          if (value is int) 'value': value,
        }),
      );
    } catch (e) {
      stdout.writeln(
        jsonEncode({
          'habits': count,
          'metric': name,
          'ms': watch.elapsedMicroseconds / 1000,
          'error': e.toString(),
        }),
      );
    }
  }

  late HabitIndex index;
  measure('index', () {
    index = HabitIndex.of(s);
    return index.totals.length;
  });
  measure(
    'today_projection',
    () => s.habits
        .where((h) => habitStatus(h, today, today, index) == 'due')
        .length,
  );
  measure(
    'progress_year',
    () =>
        progressDays(s.habits, '2023-01-01', '2023-12-31', today, index).length,
  );
  measure(
    'insights',
    () => insightCount(s.habits, '2023-10-01', '2023-12-31', today, index).kept,
  );
  measure('backup_restore', () {
    final b = backup(s);
    restore(b);
    return b.length;
  });
  measure('sync_merge', () => mergeHabitStates(s, HabitState()).events.length);
  measure(
    'check_in',
    () => record(
      s,
      HabitEvent(id: 'new', habit: 'h0', day: today, value: 1000),
      today: today,
    ).events.length,
  );
  measure(
    'raw_snapshot_bytes',
    () => utf8.encode(jsonEncode(s.toJson())).length,
  );
  measure('process_rss_bytes', () => ProcessInfo.currentRss);
  measure('sync_generation_bytes', () => encodeHabitSync(s).length);
}
