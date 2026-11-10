import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'negative_test.dart' as n;

Habit reading({String from = '2024-01-01'}) => Habit(
  id: 'read',
  title: 'Read',
  created: from,
  type: 'count',
  unit: 'pages',
  schedules: [Schedule(id: 's', from: from, target: 6000)],
  category: 'Learning',
);
HabitState history({int kept = 9, int days = 10, String from = '2024-01-01'}) {
  final h = reading(from: from);
  return HabitState(
    habits: [h],
    events: [
      for (var i = 0; i < kept; i++)
        HabitEvent(
          id: 'e$i',
          habit: h.id,
          day: addDays(from, i),
          value: 6000,
          source: 'manual',
        ),
    ],
  );
}

void main() {
  test('insights exclude completed today and an unfinished weekly quota', () {
    final h = reading();
    final s = HabitState(
      habits: [h],
      events: [
        HabitEvent(id: 'now', habit: h.id, day: '2024-01-01', value: 6000),
      ],
    );
    expect(
      insightCount(
        s.habits,
        '2024-01-01',
        '2024-01-01',
        '2024-01-01',
        HabitIndex.of(s),
      ).eligible,
      0,
    );
    final w = h.copy({
      'schedules': [
        Schedule(
          id: 'w',
          from: h.created,
          kind: 'weekly',
          weeklyTarget: 1,
          target: 6000,
        ).toJson(),
      ],
    });
    expect(
      insightCount(
        [w],
        '2024-01-01',
        '2024-01-02',
        '2024-01-02',
        HabitIndex.of(s),
      ).eligible,
      0,
    );
  });
  test('advanced filters compose without changing history or counts', () {
    final s = history().copy({
      'settings': {
        'habitDayParts': {'read': 'morning'},
      },
    });
    const f = InsightFilter(
      collection: 'Learning',
      dayPart: 'morning',
      direction: 'build',
      weekday: 1,
      outcome: 'kept',
    );
    final days = f.days(s, '2024-01-01', '2024-01-10', '2024-01-11');
    expect(days.map((d) => d.day).toList(), ['2024-01-01', '2024-01-08']);
    expect(days.fold(0, (int n, d) => n + d.kept), 2);
    expect(const InsightFilter(direction: 'reduce').habits(s), isEmpty);
    expect(
      const InsightFilter(
        outcome: 'missed',
      ).days(s, '2024-01-01', '2024-01-10', '2024-01-11').single.day,
      '2024-01-10',
    );
    final neg = n.total(n.seed(), '2024-01-02', 0);
    final unknown = const InsightFilter(
      outcome: 'unknown',
    ).days(neg, '2024-01-01', '2024-01-03', '2024-01-04');
    expect(unknown.map((d) => d.day).toList(), ['2024-01-01', '2024-01-03']);
  });
  test('group rates weight goals, rather than averaging habit percentages', () {
    final a = reading(), b = reading(from: '2024-01-10').copy({'id': 'b'});
    final s = HabitState(habits: [a, b], events: history(kept: 5).events);
    final c = insightGroups(
      s,
      '2024-01-01',
      '2024-01-10',
      '2024-01-11',
      byCollection: true,
    )['Learning']!;
    expect([c.kept, c.eligible, c.percent], [5, 11, 45]);
  });
  test(
    'missed weekdays omit skips, pauses, unknown daily negatives and weekly goals',
    () {
      final s = history(kept: 0).copy({
        'events': [
          HabitEvent(
            id: 'skip',
            habit: 'read',
            day: '2024-01-01',
            value: 0,
            skipped: true,
          ).toJson(),
        ],
        'pauses': [
          Pause(id: 'pause', from: '2024-01-02', until: '2024-01-02').toJson(),
        ],
      });
      expect(
        weekdaySlips(
          s.habits.single,
          '2024-01-01',
          '2024-01-07',
          '2024-01-08',
          HabitIndex.of(s),
        ).map((d) => d.eligible).toList(),
        [0, 0, 1, 1, 1, 1, 1],
      );
      final neg = n.seed();
      expect(
        weekdaySlips(
          neg.habits.single,
          '2024-01-01',
          '2024-01-07',
          '2024-01-08',
          HabitIndex.of(neg),
        ).every((d) => d.eligible == 0),
        true,
      );
    },
  );
  test('goal reductions and duration targets round whole stored minutes', () {
    final base = history(kept: 5);
    final lower = goalSuggestion(base, base.habits.single, '2024-01-11')!;
    expect(lower.proposed, 4000);
    final h = reading().copy({'type': 'duration'}),
        s = history().copy({
          'habits': [
            reading().copy({'type': 'duration'}).toJson(),
          ],
        });
    expect(goalSuggestion(s, h, '2024-01-11')!.proposed, 8000);
  });
  test(
    'studio and goal decisions round-trip with existing schema and backups',
    () {
      final s =
          decideGoal(
            history(),
            goalSuggestion(history(), reading(), '2024-01-11')!,
            '2024-01-11',
            accept: false,
          ).copy({
            'settings': {
              'studio': {
                'palette': 'grove',
                'icons': {'read': 'leaf'},
              },
              'goalDecisions': {'key': 'dismissed'},
            },
          });
      final restored = restore(backup(s));
      expect(restored.settings, s.settings);
    },
  );
  test(
    'month and quarter compare equal elapsed civil windows, clamp short month',
    () {
      final m = insightWindows('month', '2024-03-31');
      expect(
        [m.from, m.until, m.previousFrom, m.previousUntil],
        ['2024-03-01', '2024-03-30', '2024-02-01', '2024-02-29'],
      );
      final q = insightWindows('quarter', '2024-05-11');
      expect(
        [q.from, q.until, q.previousFrom, q.previousUntil],
        ['2024-04-01', '2024-05-10', '2024-01-01', '2024-02-09'],
      );
      expect(insightWindows('month', '2024-03-01').until, isNull);
    },
  );
  test('difficulty reconciles counts and does not divide by zero', () {
    final s = history();
    final c = insightCount(
      s.liveHabits,
      '2024-01-01',
      '2024-01-10',
      '2024-01-11',
      HabitIndex.of(s),
    );
    expect(
      [c.kept, c.eligible, c.missed, c.percent, c.difficulty],
      [9, 10, 1, 90, 'steady'],
    );
    expect(const InsightCount(0, 0).percent, isNull);
    expect(const InsightCount(1, 2).difficulty, 'learning');
    expect(const InsightCount(3, 10).difficulty, 'stretch');
  });
  test('pauses and unknown negative days excluded; zero is known success', () {
    final s = n.total(n.seed(), '2024-01-02', 0);
    final c = insightCount(
      s.liveHabits,
      '2024-01-01',
      '2024-01-03',
      '2024-01-04',
      HabitIndex.of(s),
    );
    expect([c.kept, c.eligible], [1, 1]);
    final p = history().copy({
      'pauses': [
        Pause(id: 'p', from: '2024-01-10', until: '2024-01-10').toJson(),
      ],
    });
    expect(
      insightCount(
        p.liveHabits,
        '2024-01-01',
        '2024-01-10',
        '2024-01-11',
        HabitIndex.of(p),
      ).eligible,
      9,
    );
  });
  test(
    'weekly negative counts once and never attributes a week to weekdays',
    () {
      final s = n.seed(window: 'week');
      final c = insightCount(
        s.liveHabits,
        '2024-01-01',
        '2024-01-14',
        '2024-01-15',
        HabitIndex.of(s),
      );
      expect([c.kept, c.eligible], [2, 2]);
      expect(
        weekdaySlips(
          s.habits.single,
          '2024-01-01',
          '2024-01-14',
          '2024-01-15',
          HabitIndex.of(s),
        ).every((c) => c.eligible == 0),
        isTrue,
      );
    },
  );
  test('weekday slips use opportunities not total calendar days', () {
    final s = history(kept: 0);
    final days = weekdaySlips(
      s.habits.single,
      '2024-01-01',
      '2024-01-10',
      '2024-01-11',
      HabitIndex.of(s),
    );
    expect(days.map((c) => c.eligible).toList(), [2, 2, 2, 1, 1, 1, 1]);
    expect(days.fold(0, (int v, c) => v + c.missed), 10);
  });
  test(
    'groups aggregate opportunity-weighted counts and explicit day parts',
    () {
      final s = history().copy({
        'settings': {
          'habitDayParts': {'read': 'morning'},
        },
      });
      expect(insightDayPart(s, s.habits.single), 'morning');
      final groups = insightGroups(
        s,
        '2024-01-01',
        '2024-01-10',
        '2024-01-11',
        byCollection: true,
      );
      expect([groups['Learning']!.kept, groups['Learning']!.eligible], [9, 10]);
    },
  );
  test(
    'goal rule requires ten comparable daily opportunities; accept changes tomorrow only',
    () {
      final s = history();
      final g = goalSuggestion(s, s.habits.single, '2024-01-11')!;
      expect([g.kept, g.eligible, g.target, g.proposed], [9, 10, 6000, 8000]);
      final accepted = decideGoal(s, g, '2024-01-11', accept: true);
      expect(scheduleOn(accepted.habits.single, '2024-01-10')!.target, 6000);
      expect(scheduleOn(accepted.habits.single, '2024-01-12')!.target, 8000);
      expect(
        goalSuggestion(accepted, accepted.habits.single, '2024-01-11'),
        isNull,
      );
      final dismissed = decideGoal(s, g, '2024-01-11', accept: false);
      expect(dismissed.habits.single.schedules.length, 1);
      expect(
        goalSuggestion(dismissed, dismissed.habits.single, '2024-01-11'),
        isNull,
      );
      expect(
        () => decideGoal(dismissed, g, '2024-01-11', accept: true),
        throwsStateError,
      );
      expect(
        goalSuggestion(history(kept: 5), s.habits.single, '2024-01-06'),
        isNull,
      );
    },
  );
  test('goal rule excludes negative/binary/weekly and refuses stale data', () {
    final s = history(),
        g = goalSuggestion(history(), reading(), '2024-01-11')!;
    expect(
      goalSuggestion(n.seed(), n.seed().habits.single, '2024-01-11'),
      isNull,
    );
    final stale = s.copy({
      'habits': [
        reading().copy({'title': 'Changed'}).toJson(),
      ],
    });
    expect(
      () => decideGoal(stale, g, '2024-01-11', accept: true),
      throwsStateError,
    );
    final weekly = reading().copy({
      'schedules': [
        Schedule(
          id: 'w',
          from: '2024-01-01',
          kind: 'weekly',
          target: 6000,
        ).toJson(),
      ],
    });
    expect(
      goalSuggestion(HabitState(habits: [weekly]), weekly, '2024-02-01'),
      isNull,
    );
  });
  test(
    'mood pairing uses only closed known daily opportunities and minimum fourteen',
    () {
      var s = history(kept: 10).copy({
        'moods': [
          for (var i = 0; i < 14; i++)
            MoodEntry(
              day: addDays('2024-01-01', i),
              mood: i < 10 ? 4 : 2,
              recordedAt: '2024-02-01T00:00:00Z',
            ).toJson(),
        ],
      });
      final m = moodCooccurrence(
        s,
        s.habits.single,
        '2024-01-01',
        '2024-01-14',
        '2024-01-15',
      );
      expect(
        [m.keptDays, m.otherDays, m.keptAverage, m.otherAverage, m.enough],
        [10, 4, 4.0, 2.0, true],
      );
      expect(
        moodCooccurrence(
          s,
          s.habits.single,
          '2024-01-01',
          '2024-01-13',
          '2024-01-15',
        ).enough,
        isFalse,
      );
      s = s.copy({
        'pauses': [
          Pause(id: 'p', from: '2024-01-14', until: '2024-01-14').toJson(),
        ],
      });
      expect(
        moodCooccurrence(
          s,
          s.habits.single,
          '2024-01-01',
          '2024-01-14',
          '2024-01-15',
        ).enough,
        isFalse,
      );
    },
  );
  test('DST gaps/folds and day boundary keep exact civil denominators', () {
    for (final (zone, from, until, today) in [
      ('America/New_York', '2024-03-08', '2024-03-12', '2024-03-13'),
      ('America/New_York', '2024-11-01', '2024-11-05', '2024-11-06'),
      ('Australia/Sydney', '2024-10-04', '2024-10-08', '2024-10-09'),
    ]) {
      final s = history(kept: 3, from: from).copy({
        'settings': {'zone': zone, 'dayBoundaryMinutes': 240},
      });
      expect(
        insightCount(
          s.liveHabits,
          from,
          until,
          today,
          HabitIndex.of(s),
        ).eligible,
        5,
      );
    }
  });
}
