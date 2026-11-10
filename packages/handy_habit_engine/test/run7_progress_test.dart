import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'negative_test.dart' show seed, total;

void main() {
  test('closed weekly ceilings infer blanks, current week stays open', () {
    var s = total(seed(window: 'week'), '2024-01-02', 2000);
    final h = s.habits.single, index = HabitIndex.of(s);
    expect(
      negativePeriod(h, '2024-01-01', '2024-01-08', index).status,
      'withinLimit',
    );
    expect(negativePeriod(h, '2024-01-01', '2024-01-07', index).status, 'open');
    expect(metrics(h, '2024-01-15', 1, index).completed, 2);
    expect(habitStatus(h, '2024-01-03', '2024-01-08', index), 'withinLimit');
    s = total(s, '2024-01-05', 2000);
    expect(
      negativePeriod(h, '2024-01-01', '2024-01-08', HabitIndex.of(s)).status,
      'overLimit',
    );
  });
  test('daily blanks are hollow but excluded from metrics and review', () {
    final s = total(seed(), '2024-01-02', 0),
        h = s.habits.single,
        index = HabitIndex.of(s);
    expect(habitStatus(h, '2024-01-01', '2024-01-08', index), 'unknown');
    expect(habitStatus(h, '2024-01-08', '2024-01-08', index), 'unknown');
    final m = metrics(h, '2024-01-08', 1, index);
    expect([m.completed, m.eligible, m.current], [1, 1, 1]);
    final review = weekReview(s, index, '2024-01-01', '2024-01-08');
    expect([review.kept, review.due], [1, 1]);
  });

  test('leap year has 366 civil dates and future never earns heat', () {
    final s = seed(window: 'week'), h = s.habits.single;
    final days = yearHeatmap([h], 2024, '2024-03-11', HabitIndex.of(s));
    expect(days, hasLength(366));
    expect(days.map((d) => d.day).toSet(), hasLength(366));
    expect(days.where((d) => d.day == '2024-02-29'), hasLength(1));
    expect(days.last.kept, 0);
    expect(days.last.eligible, 0);
    expect(yearHeatmap([], 2025, '2025-12-31', HabitIndex([])), hasLength(365));
  });
  test('range end uses actual today for closed Sunday and daily limits', () {
    final s = total(seed(window: 'week'), '2024-01-02', 2000),
        h = s.habits.single,
        index = HabitIndex.of(s);
    final a = progressCount(h, '2024-01-01', '2024-01-07', '2024-01-08', index);
    expect([a.kept, a.eligible, a.unit], [1, 1, 'weeks']);
    expect(
      progressCount(
        h,
        '2024-01-02',
        '2024-01-07',
        '2024-01-08',
        index,
      ).eligible,
      0,
    );
    expect(
      progressCount(
        h,
        '2024-01-01',
        '2024-01-07',
        '2024-01-07',
        index,
      ).eligible,
      0,
    );
    final d = total(seed(), '2024-01-07', 0);
    expect(
      progressCount(
        d.habits.single,
        '2024-01-01',
        '2024-01-07',
        '2024-01-08',
        HabitIndex.of(d),
      ).eligible,
      1,
    );
  });
  test('pauses exclude whole negative weeks, never infer through them', () {
    final s = seed(window: 'week').copy({
          'pauses': [
            Pause(id: 'p', from: '2024-01-03', until: '2024-01-03').toJson(),
          ],
        }),
        index = HabitIndex.of(s),
        h = s.habits.single;
    expect(
      progressCount(
        h,
        '2024-01-01',
        '2024-01-07',
        '2024-01-08',
        index,
      ).eligible,
      0,
    );
    final days = progressDays(
      [h],
      '2024-01-01',
      '2024-01-07',
      '2024-01-08',
      index,
    );
    expect(days.every((d) => d.kept == 0 && d.eligible == 0), isTrue);
  });
  test('daily unknown heat remains hollow; aggregate totals reconcile', () {
    final s = total(seed(), '2024-01-02', 0),
        h = s.habits.single,
        index = HabitIndex.of(s);
    final d = progressDays(
      [h],
      '2024-01-01',
      '2024-01-03',
      '2024-01-08',
      index,
    );
    expect([d[0].unknown, d[0].eligible], [1, 0]);
    expect([d[1].kept, d[1].eligible], [1, 1]);
    final open = progressDays(
      [h],
      '2024-01-01',
      '2024-01-02',
      '2024-01-02',
      index,
    );
    expect([open[0].unknown, open[0].eligible], [1, 0]);
    expect([open[1].unknown, open[1].eligible, open[1].kept], [0, 0, 0]);
    expect(
      progressDays(
        [h],
        '2024-01-03',
        '2024-01-03',
        '2024-01-03',
        index,
      ).single.unknown,
      1,
    );
    final doubled = progressDays(
      [
        h,
        h.copy({'id': 'second'}),
      ],
      '2024-01-01',
      '2024-01-03',
      '2024-01-08',
      index,
    );
    expect(doubled[1].kept, 1);
    expect(doubled[1].unknown, 1);
  });
  test('DST dates and custom week boundaries are calendar stable', () {
    final s = HabitState(settings: {'zone': 'America/New_York'});
    expect(habitDayAt(s, DateTime.parse('2024-03-10T07:30:00Z')), '2024-03-10');
    final days = progressDays(
      [],
      '2024-03-09',
      '2024-03-12',
      '2024-03-12',
      HabitIndex([]),
    );
    expect(days.map((d) => d.day), [
      '2024-03-09',
      '2024-03-10',
      '2024-03-11',
      '2024-03-12',
    ]);
    expect(progressRange('week', '2024-03-10', 7), (
      '2024-03-10',
      '2024-03-16',
    ));
    expect(progressRange('month', '2024-02-10', 1), (
      '2024-02-01',
      '2024-02-29',
    ));
    expect(
      () => yearHeatmap([], 2201, '2024-01-01', HabitIndex([])),
      throwsFormatException,
    );
    expect(
      () => progressDays(
        [],
        '2024-01-02',
        '2024-01-01',
        '2024-01-08',
        HabitIndex([]),
      ),
      throwsFormatException,
    );
  });

  test('positive weekly quota counts once and excludes partial first week', () {
    final h = Habit(
      id: 'read',
      title: 'Read',
      created: '2024-01-01',
      schedules: [
        Schedule(id: 's', from: '2024-01-01', kind: 'weekly', weeklyTarget: 3),
      ],
    );
    final index = HabitIndex([
      for (var i = 0; i < 3; i++)
        HabitEvent(
          id: 'e$i',
          habit: 'read',
          day: addDays('2024-01-01', i),
          value: 1000,
        ),
    ]);
    final count = progressCount(
      h,
      '2024-01-01',
      '2024-01-07',
      '2024-01-08',
      index,
    );
    expect([count.kept, count.eligible], [1, 1]);
    expect(
      progressCount(
        h,
        '2024-01-02',
        '2024-01-07',
        '2024-01-08',
        index,
      ).eligible,
      0,
    );
    final pause = HabitIndex([], [
      Pause(id: 'p', from: '2024-01-01', until: '2024-01-07'),
    ]);
    expect(
      progressCount(
        h,
        '2024-01-01',
        '2024-01-07',
        '2024-01-08',
        pause,
      ).eligible,
      0,
    );
  });
  test('partial creation week and conflicts are excluded, not inferred', () {
    final h = Habit(
      id: 'n',
      title: 'Less',
      type: 'count',
      direction: 'reduce',
      created: '2024-01-03',
      schedules: [Schedule(id: 's', from: '2024-01-03')],
      negativeGoals: [
        NegativeGoal(id: 'g', from: '2024-01-03', window: 'week'),
      ],
    );
    final index = HabitIndex([]);
    expect(
      progressCount(
        h,
        '2024-01-01',
        '2024-01-07',
        '2024-01-08',
        index,
      ).eligible,
      0,
    );
    final whole = seed(window: 'week'),
        conflicted = HabitIndex.of(whole)..conflicts = {'reduce:2024-01-03'};
    expect(
      progressCount(
        whole.habits.single,
        '2024-01-01',
        '2024-01-07',
        '2024-01-08',
        conflicted,
      ).eligible,
      0,
    );
    expect(
      yearHeatmap(whole.habits, 2024, '2024-01-08', conflicted)[2].unknown,
      1,
    );
  });
  test('export counts a closed past Sunday like the Progress range', () {
    final s = total(seed(window: 'week'), '2024-01-02', 2000);
    final report = markdownReport(
      s,
      '2024-01-01',
      '2024-01-07',
      today: '2024-01-08',
    );
    expect(report, contains('| Sugary drinks | 1 | 1 |'));
    expect(report, contains('Weekly limits count recorded incidents'));
  });

  test('positive quota already met counts in the open week once', () {
    final h = Habit(
      id: 'h',
      title: 'Read',
      created: '2024-01-01',
      schedules: [
        Schedule(id: 's', from: '2024-01-01', kind: 'weekly', weeklyTarget: 3),
      ],
    );
    final index = HabitIndex([
      for (var i = 0; i < 3; i++)
        HabitEvent(
          id: 'e$i',
          habit: 'h',
          day: addDays('2024-01-01', i),
          value: 1000,
        ),
    ]);
    final c = progressCount(h, '2024-01-01', '2024-01-07', '2024-01-03', index);
    expect([c.kept, c.eligible], [1, 1]);
  });
  test('range with changed day/week goals labels mixed units honestly', () {
    final h = seed(window: 'week').habits.single.copy({
      'negativeGoals': [
        NegativeGoal(id: 'one', from: '2024-01-01', window: 'week').toJson(),
        NegativeGoal(id: 'two', from: '2024-01-08', window: 'day').toJson(),
      ],
    });
    final index = HabitIndex([
      HabitEvent(id: 'none', habit: h.id, day: '2024-01-08', value: 0),
    ]);
    final c = progressCount(h, '2024-01-01', '2024-01-08', '2024-01-09', index);
    expect([c.kept, c.eligible, c.unit], [2, 2, 'goals']);
  });
}
