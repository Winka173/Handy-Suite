import 'package:handy_habit_engine/handy_habit_engine.dart';

const smartDemoToday = '2026-11-11';

/// All figures in free previews come from this disposable, labelled history.
HabitState smartDemoState() {
  final h = Habit(
    id: 'demo-read',
    title: 'Read',
    created: '2026-08-01',
    type: 'quantity',
    unit: 'pages',
    category: 'Learning',
    schedules: [Schedule(id: 'demo-s', from: '2026-08-01', target: 6000)],
  );
  return HabitState(
    habits: [h],
    settings: {
      'habitDayParts': {h.id: 'morning'},
    },
    events: [
      for (var i = 0; i < 102; i++)
        // October 1–10 has six kept goals; November 1–10 has nine.
        if (i % 10 != 1 && (i < 61 || i > 70 || i % 3 != 0))
          HabitEvent(
            id: 'demo-e$i',
            habit: h.id,
            day: addDays(h.created, i),
            value: 6000,
          ),
    ],
    moods: [
      for (var i = 0; i < 28; i++)
        MoodEntry(
          day: addDays('2026-10-14', i),
          mood: i % 10 == 1 ? 2 : 4,
          recordedAt: '2026-11-11T00:00:00Z',
        ),
    ],
  );
}
