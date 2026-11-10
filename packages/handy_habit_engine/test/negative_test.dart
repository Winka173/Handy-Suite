import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

Habit negative({String window = 'day', int limit = 3000}) => Habit(
  id: 'reduce',
  title: 'Sugary drinks',
  created: '2024-01-01',
  type: 'count',
  direction: 'reduce',
  schedules: [Schedule(id: 'schedule', from: '2024-01-01')],
  negativeGoals: [
    NegativeGoal(id: 'goal', from: '2024-01-01', window: window, limit: limit),
  ],
);
HabitState seed({String window = 'day', int limit = 3000}) => HabitState(
  habits: [negative(window: window, limit: limit)],
  settings: {'zone': 'UTC'},
);
HabitState total(HabitState s, String d, int n) =>
    setManualTotal(s, 'reduce', d, n, today: '2024-01-15');

void main() {
  test('unknown differs from explicit none and over-limit recovers', () {
    var s = seed();
    final h = s.habits.single;
    expect(
      habitStatus(h, '2024-01-01', '2024-01-15', HabitIndex.of(s)),
      'unknown',
    );
    s = total(s, '2024-01-01', 0);
    expect(s.events.single.value, 0);
    expect(
      habitStatus(h, '2024-01-01', '2024-01-15', HabitIndex.of(s)),
      'withinLimit',
    );
    s = total(s, '2024-01-02', 4000);
    s = total(s, '2024-01-03', 1000);
    final m = metrics(h, '2024-01-04', 1, HabitIndex.of(s));
    expect([m.current, m.longest, m.completed, m.eligible], [1, 1, 2, 3]);
  });
  test('incident additions never cap at a ceiling, zero limit is valid', () {
    var s = seed(limit: 0);
    s = total(s, '2024-01-01', 0);
    for (var i = 0; i < 4; i++) {
      s = record(
        s,
        HabitEvent(
          id: 'incident$i',
          habit: 'reduce',
          day: '2024-01-01',
          value: 1000,
          note: 'tea',
        ),
        today: '2024-01-15',
      );
    }
    expect(HabitIndex.of(s).value('reduce', '2024-01-01'), 4000);
    expect(
      habitStatus(
        s.habits.single,
        '2024-01-01',
        '2024-01-15',
        HabitIndex.of(s),
      ),
      'overLimit',
    );
  });
  test('daily period stays open until next habit day', () {
    final s = total(seed(), '2024-01-01', 0), h = s.habits.single;
    expect(
      negativePeriod(h, '2024-01-01', '2024-01-01', HabitIndex.of(s)).status,
      'open',
    );
    expect(metrics(h, '2024-01-01', 1, HabitIndex.of(s)).completed, 0);
    expect(metrics(h, '2024-01-02', 1, HabitIndex.of(s)).completed, 1);
  });
  test('weekly ceilings sum incidents, infer blanks and close Monday', () {
    var s = seed(window: 'week');
    final h = s.habits.single;
    for (var i = 0; i < 6; i++)
      s = total(s, addDays('2024-01-01', i), i == 0 ? 3000 : 0);
    expect(
      negativePeriod(h, '2024-01-01', '2024-01-08', HabitIndex.of(s)).status,
      'withinLimit',
    );
    s = total(s, '2024-01-07', 0);
    expect(
      negativePeriod(h, '2024-01-01', '2024-01-07', HabitIndex.of(s)).status,
      'open',
    );
    expect(
      negativePeriod(h, '2024-01-01', '2024-01-08', HabitIndex.of(s)).status,
      'withinLimit',
    );
    expect(metrics(h, '2024-01-08', 1, HabitIndex.of(s)).completed, 1);
    s = total(s, '2024-01-07', 1000);
    expect(
      negativePeriod(h, '2024-01-01', '2024-01-08', HabitIndex.of(s)).status,
      'overLimit',
    );
  });

  test(
    'pause and skip are neutral, never zero observations or prorated ceilings',
    () {
      var s = seed(window: 'week');
      for (var i = 0; i < 7; i++) s = total(s, addDays('2024-01-01', i), 0);
      s = s.copy({
        'pauses': [
          Pause(id: 'pause', from: '2024-01-03', until: '2024-01-03').toJson(),
        ],
      });
      expect(
        negativePeriod(
          s.habits.single,
          '2024-01-01',
          '2024-01-08',
          HabitIndex.of(s),
        ).status,
        'paused',
      );
      expect(
        metrics(s.habits.single, '2024-01-08', 1, HabitIndex.of(s)).eligible,
        0,
      );
      final skipped = setManualTotal(
        seed(),
        'reduce',
        '2024-01-01',
        0,
        today: '2024-01-08',
        skipped: true,
      );
      expect(
        habitStatus(
          skipped.habits.single,
          '2024-01-01',
          '2024-01-08',
          HabitIndex.of(skipped),
        ),
        'skipped',
      );
      expect(HabitIndex.of(skipped).known('reduce', '2024-01-01'), isFalse);
    },
  );
  test(
    'Undo retracts incident/zero separately and preserves unrelated additions',
    () {
      final before = seed();
      final a = recordChange(
        before,
        record(
          before,
          HabitEvent(id: 'a', habit: 'reduce', day: '2024-01-01', value: 1000),
          today: '2024-01-08',
        ),
        actor: 'one',
      );
      final b = recordChange(
        a,
        record(
          a,
          HabitEvent(id: 'b', habit: 'reduce', day: '2024-01-01', value: 1000),
          today: '2024-01-08',
        ),
        actor: 'two',
      );
      final undone = undoChange(b, a.undoBatch!, actor: 'one');
      expect(undone.events.map((e) => e.id), ['b']);
      final zero = recordChange(
        before,
        total(before, '2024-01-01', 0),
        actor: 'one',
      );
      expect(HabitIndex.of(zero).known('reduce', '2024-01-01'), isTrue);
      expect(
        HabitIndex.of(
          undoChange(zero, zero.undoBatch!, actor: 'one'),
        ).known('reduce', '2024-01-01'),
        isFalse,
      );
    },
  );
  test('backfill removes observation and history retains old limits', () {
    var s = total(seed(), '2024-01-01', 2000);
    final h = s.habits.single.copy({
      'negativeGoals': [
        ...s.habits.single.negativeGoals.map((g) => g.toJson()),
        NegativeGoal(id: 'next', from: '2024-01-08', limit: 0).toJson(),
      ],
    });
    s = s.copy({
      'habits': [h.toJson()],
    });
    expect(
      habitStatus(h, '2024-01-01', '2024-01-15', HabitIndex.of(s)),
      'withinLimit',
    );
    s = total(s, '2024-01-08', 1000);
    expect(
      habitStatus(h, '2024-01-08', '2024-01-15', HabitIndex.of(s)),
      'overLimit',
    );
    s = setManualTotal(
      s,
      'reduce',
      '2024-01-01',
      0,
      today: '2024-01-15',
      observed: false,
    );
    expect(
      habitStatus(h, '2024-01-01', '2024-01-15', HabitIndex.of(s)),
      'unknown',
    );
    expect(
      () => setManualTotal(s, 'reduce', '2023-12-31', 0, today: '2024-01-15'),
      throwsFormatException,
    );
    expect(
      () => setManualTotal(s, 'reduce', '2024-01-16', 0, today: '2024-01-15'),
      throwsFormatException,
    );
    expect(
      () => setManualTotal(
        s.copy({
          'settings': {'backfill': 1},
        }),
        'reduce',
        '2024-01-01',
        0,
        today: '2024-01-15',
      ),
      throwsFormatException,
    );
  });
  test('weekly revisions require both old and new week boundary', () {
    final h = negative(window: 'week');
    expect(
      () => h.copy({
        'negativeGoals': [
          ...h.negativeGoals.map((g) => g.toJson()),
          NegativeGoal(id: 'bad', from: '2024-01-03', limit: 0).toJson(),
        ],
      }),
      throwsFormatException,
    );
    final next = h.copy({
      'negativeGoals': [
        ...h.negativeGoals.map((g) => g.toJson()),
        NegativeGoal(id: 'next', from: '2024-01-08', limit: 0).toJson(),
      ],
    });
    expect(negativeGoalOn(next, '2024-01-07')!.window, 'week');
    expect(negativeGoalOn(next, '2024-01-08')!.window, 'day');
  });
  test(
    'conflicting zero/total edits stay unscored until causal resolution',
    () {
      final before = seed(),
          a = total(seed(), '2024-01-01', 0),
          b = total(seed(), '2024-01-01', 2000);
      final ops = unionOperations(a.operations, b.operations);
      final conflicted = before.copy({
        'events': a.events.map((e) => e.toJson()).toList(),
        'operations': ops.map((o) => o.toJson()).toList(),
      });
      expect(
        habitStatus(
          before.habits.single,
          '2024-01-01',
          '2024-01-02',
          HabitIndex.of(conflicted),
        ),
        'conflict',
      );
      expect(
        metrics(
          before.habits.single,
          '2024-01-02',
          1,
          HabitIndex.of(conflicted),
        ).completed,
        0,
      );
      final resolved = total(conflicted, '2024-01-01', 1000);
      expect(dayOperationConflicts(resolved.operations), isEmpty);
      expect(
        habitStatus(
          before.habits.single,
          '2024-01-01',
          '2024-01-02',
          HabitIndex.of(resolved),
        ),
        'withinLimit',
      );
      expect(unionOperations(ops, ops).length, ops.length);
    },
  );
  test(
    'mixed roundtrip JSON ZIP CSV includes zero note and goal revisions',
    () {
      var s = total(seed(), '2024-01-01', 0);
      s = setManualTotal(
        s,
        'reduce',
        '2024-01-02',
        2000,
        today: '2024-01-15',
        note: 'After lunch',
      );
      final positive = Habit(
        id: 'build',
        title: 'Read',
        created: '2024-01-01',
        schedules: [Schedule(id: 'pos', from: '2024-01-01')],
      );
      s = s.copy({
        'habits': [...s.habits.map((h) => h.toJson()), positive.toJson()],
      });
      for (final zip in [true, false])
        expect(restore(backup(s, zip: zip), zip: zip).toJson(), s.toJson());
      final csv = Uint8List.fromList(
        utf8.encode(csvLogs(s, '2024-01-01', '2024-01-15')),
      );
      final imported = importCsvLogs(HabitState(), csv);
      expect(imported.habits.single.toJson(), s.habits.first.toJson());
      expect(
        imported.events.map((e) => e.toJson()),
        s.events.map((e) => e.toJson()),
      );
      expect(HabitIndex.of(imported).known('reduce', '2024-01-01'), isTrue);
      expect(HabitIndex.of(imported).known('reduce', '2024-01-03'), isFalse);
    },
  );
  test('trash/restore/copy-merge retain negative goals and observations', () {
    final s = total(seed(), '2024-01-01', 0),
        instant = DateTime.utc(2024, 1, 8);
    final trashed = trashEntity(s, 'habit', 'reduce', instant);
    expect(trashed.liveHabits, isEmpty);
    final back = restoreTrash(
      restore(backup(trashed)),
      trashed.trash.single.id,
      instant,
    );
    expect(back.habits.single.toJson(), s.habits.single.toJson());
    final copied = merge(HabitState(), back);
    expect(copied.habits.single.id, isNot('reduce'));
    expect(copied.habits.single.isNegative, isTrue);
    expect(
      HabitIndex.of(copied).known(copied.habits.single.id, '2024-01-01'),
      isTrue,
    );
  });
  test('routine links and routine-origin incidents rejected in engine', () {
    final s = seed();
    expect(
      () => s.copy({
        'routines': [
          Routine(
            id: 'r',
            title: 'Evening',
            steps: [RoutineStep(id: 'step', title: 'Drink', habit: 'reduce')],
          ).toJson(),
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => record(
        s,
        HabitEvent(
          id: 'r',
          habit: 'reduce',
          day: '2024-01-01',
          value: 1000,
          source: 'routine',
          session: 's',
          step: 'x',
        ),
        today: '2024-01-15',
      ),
      throwsFormatException,
    );
    expect(
      () => NegativeGoal(id: 'bad', from: '2024-01-01', limit: 500),
      throwsFormatException,
    );
  });
  test(
    'review excludes unknown daily days and counts weekly ceilings once',
    () {
      var s = seed();
      for (var i = 0; i < 6; i++)
        s = total(s, addDays('2024-01-01', i), i == 0 ? 4000 : 0);
      final daily = weekReview(s, HabitIndex.of(s), '2024-01-01', '2024-01-08');
      expect([daily.kept, daily.due, daily.habits.single.unknown], [5, 6, 1]);
      var w = seed(window: 'week');
      for (var i = 0; i < 7; i++) w = total(w, addDays('2024-01-01', i), 0);
      final weekly = weekReview(
        w,
        HabitIndex.of(w),
        '2024-01-01',
        '2024-01-08',
      );
      expect([weekly.kept, weekly.due], [1, 1]);
      final open = weekReview(w, HabitIndex.of(w), '2024-01-01', '2024-01-07');
      expect([open.kept, open.due], [0, 0]);
    },
  );
  for (final version in [1, 2, 3, 4]) {
    test(
      'old v$version positive backups preserve payload and roundtrip as v6',
      () {
        final h = Habit(
          id: 'p',
          title: 'Read',
          created: '2024-01-01',
          schedules: [Schedule(id: 's', from: '2024-01-01')],
        );
        final old = HabitState(habits: [h]).toJson()..['schema'] = version;
        if (version == 1) old.remove('pauses');
        if (version < 3) {
          old.remove('operations');
          old.remove('clockPolicies');
        }
        final data = utf8.encode(jsonEncode(old));
        final manifest = utf8.encode(
          jsonEncode({
            'app': 'handy-habit',
            'schema': version,
            'files': {'data.json': sha256.convert(data).toString()},
            'assets': [],
          }),
        );
        final zipped = Uint8List.fromList(
          ZipEncoder().encode(
            Archive()
              ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
              ..addFile(ArchiveFile('data.json', data.length, data)),
          ),
        );
        expect(restore(zipped).habits.single.toJson(), h.toJson());
        final read = restore(
          Uint8List.fromList(utf8.encode(jsonEncode(old))),
          zip: false,
        );
        expect(read.habits.single.direction, 'build');
        expect(read.habits.single.toJson(), h.toJson());
        expect(read.toJson()['schema'], 7);
        expect(restore(backup(read)).toJson(), read.toJson());
      },
    );
  }
  for (final c in [
    (
      'America/New_York',
      '2024-03-11T07:59:59Z',
      '2024-03-11T08:00:00Z',
      '2024-03-11',
    ),
    (
      'America/New_York',
      '2024-11-04T08:59:59Z',
      '2024-11-04T09:00:00Z',
      '2024-11-04',
    ),
    (
      'Australia/Sydney',
      '2024-04-07T17:59:59Z',
      '2024-04-07T18:00:00Z',
      '2024-04-08',
    ),
    (
      'Australia/Sydney',
      '2024-10-06T16:59:59Z',
      '2024-10-06T17:00:00Z',
      '2024-10-07',
    ),
  ]) {
    test('weekly close follows 04:00 policy across DST ${c.$1} ${c.$4}', () {
      final start = addDays(c.$4, -7);
      final h = Habit(
        id: 'reduce',
        title: 'Less',
        type: 'count',
        direction: 'reduce',
        created: start,
        schedules: [Schedule(id: 's', from: start)],
        negativeGoals: [
          NegativeGoal(id: 'g', from: start, window: 'week', limit: 3000),
        ],
      );
      var s = HabitState(
        habits: [h],
        settings: {'zone': c.$1, 'dayBoundaryMinutes': 240},
      );
      for (var i = 0; i < 7; i++)
        s = setManualTotal(s, h.id, addDays(start, i), 0, today: c.$4);
      final before = habitDayAt(s, DateTime.parse(c.$2)),
          after = habitDayAt(s, DateTime.parse(c.$3));
      expect(before, addDays(c.$4, -1));
      expect(after, c.$4);
      expect(negativePeriod(h, start, before, HabitIndex.of(s)).status, 'open');
      expect(
        negativePeriod(h, start, after, HabitIndex.of(s)).status,
        'withinLimit',
      );
    });
  }
}
