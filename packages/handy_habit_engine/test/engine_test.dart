import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

Habit habit({
  String kind = 'daily',
  String type = 'binary',
  String start = '2024-01-01',
  int target = 1000,
  List<int> weekdays = const [1, 3, 5],
  int weekStart = 1,
}) => Habit(
  id: 'h',
  title: 'Read',
  created: start,
  type: type,
  unit: type == 'quantity' ? 'pages' : '',
  schedules: [
    Schedule(
      id: 'v1',
      from: start,
      kind: kind,
      target: target,
      weekdays: weekdays,
      weekStart: weekStart,
    ),
  ],
);
HabitEvent event(
  String d, {
  String id = '',
  int value = 1000,
  bool skipped = false,
}) => HabitEvent(
  id: id.isEmpty ? d : id,
  habit: 'h',
  day: d,
  value: value,
  skipped: skipped,
  updated: '2024-01-01T00:00:00Z',
);
HabitState state(Habit h, [List<HabitEvent> events = const []]) =>
    HabitState(habits: [h], events: events);
Routine routine() => Routine(
  id: 'r',
  title: 'Read and note',
  steps: [
    RoutineStep(id: 'a', title: 'Read', habit: 'h'),
    RoutineStep(id: 'b', title: 'Note', habit: 'h'),
  ],
);
void main() {
  test(
    'CSV log roundtrip preserves multiline notes, IDs and linked provenance',
    () {
      final h = habit(type: 'count'),
          s = state(h, [
            HabitEvent(
              id: 'e',
              habit: 'h',
              day: '2024-01-01',
              value: 1000,
              note: '=1+1\nĐọc, "sách"',
              updated: '2024-01-01T00:00:00Z',
            ),
          ]),
          bytes = Uint8List.fromList(
            utf8.encode(csvLogs(s, '2024-01-01', '2024-01-31')),
          ),
          imported = importCsvLogs(state(h), bytes);
      expect(imported.events.single.toJson(), s.events.single.toJson());
      expect(importCsvLogs(imported, bytes).events.length, 1);
      final tampered = utf8.decode(bytes).replaceFirst('"1000"', '"999"');
      expect(
        () =>
            importCsvLogs(state(h), Uint8List.fromList(utf8.encode(tampered))),
        throwsFormatException,
      );
    },
  );
  test('CSV orphan/conflicting IDs refuse without changing current logs', () {
    final s = state(habit(), [event('2024-01-01')]),
        bytes = Uint8List.fromList(
          utf8.encode(csvLogs(s, '2024-01-01', '2024-01-02')),
        );
    expect(() => importCsvLogs(HabitState(), bytes), throwsFormatException);
    final changed = state(habit(), [
      HabitEvent(
        id: s.events.single.id,
        habit: 'h',
        day: '2024-01-01',
        value: 1000,
        note: 'changed',
      ),
    ]);
    expect(() => importCsvLogs(changed, bytes), throwsFormatException);
    expect(changed.events.single.note, 'changed');
  });
  test(
    'changing global week preference cannot rewrite existing weekly quota boundaries',
    () {
      final h = habit(kind: 'weekly', weekStart: 1),
          s = state(h, [
            event('2024-01-01'),
            event('2024-01-02'),
            event('2024-01-03'),
          ]);
      final before = metrics(h, '2024-01-09', 1, HabitIndex(s.events)),
          changed = s.copy({
            'settings': {'weekStart': 7},
          }),
          after = metrics(
            changed.habits.single,
            '2024-01-09',
            changed.weekStart,
            HabitIndex(changed.events),
          );
      expect(
        [after.current, after.completed, after.eligible],
        [before.current, before.completed, before.eligible],
      );
    },
  );
  for (final entry in {
    'daily': ['2024-01-01', '2024-01-02'],
    'weekdays': ['2024-01-01', '2024-01-03'],
    'interval': ['2024-01-01', '2024-01-03'],
    'weekly': ['2024-01-01', '2024-01-02'],
  }.entries) {
    test('${entry.key} recurrence and next due preserve date anchors', () {
      final h = habit(kind: entry.key);
      expect(isScheduledOn(h, entry.value[0]), true);
      expect(nextDueDate(h, '2024-01-02'), entry.value[1]);
      expect(isScheduledOn(h, '2023-12-31'), false);
    });
  }
  test('dates reject calendar normalization and quantities are exact', () {
    expect(() => date('2023-02-29'), throwsFormatException);
    expect(day(date('2024-02-29')), '2024-02-29');
    expect(quantity('0.1') * 10, 1000);
    for (final v in ['1e3', '-1', '0.0001', 'NaN']) {
      expect(() => quantity(v), throwsFormatException);
    }
  });
  test('UTC aliases and DST retain stable local reporting days', () {
    expect(
      localDay(DateTime.parse('2024-03-10T04:30:00Z'), 'America/New_York'),
      '2024-03-09',
    );
    expect(
      localDay(DateTime.parse('2024-03-10T07:30:00Z'), 'America/New_York'),
      '2024-03-10',
    );
    expect(localDay(DateTime.utc(2024), 'UTC'), '2024-01-01');
    expect(weekOf('2024-01-01', 7), '2023-12-31');
  });
  test('weekday strict streak ignores unscheduled and open today', () {
    final h = habit(kind: 'weekdays'),
        index = HabitIndex([
          event('2024-01-01'),
          event('2024-01-03'),
          event('2024-01-05'),
        ]),
        m = metrics(h, '2024-01-08', 1, index);
    expect([m.current, m.longest, m.completed, m.eligible], [3, 3, 3, 3]);
    expect(habitStatus(h, '2024-01-06', '2024-01-08', index), 'notScheduled');
  });
  test('skipped is neutral, never success, partial past breaks streak', () {
    final h = habit(type: 'count', target: 2000),
        index = HabitIndex([
          event('2024-01-01', value: 2000),
          event('2024-01-02', value: 0, skipped: true),
          event('2024-01-03', value: 1000),
          event('2024-01-04', value: 2000),
        ]),
        m = metrics(h, '2024-01-05', 1, index);
    expect([m.current, m.longest, m.completed, m.eligible], [1, 1, 2, 3]);
    expect(habitStatus(h, '2024-01-02', '2024-01-05', index), 'skipped');
    expect(habitStatus(h, '2024-01-03', '2024-01-05', index), 'partial');
    expect(habitStatus(h, '2024-01-06', '2024-01-05', index), 'future');
  });
  test('weekly quota counts distinct completed days, not repeated entries', () {
    final h = habit(kind: 'weekly', type: 'count'),
        index = HabitIndex([
          event('2024-01-01', id: 'a'),
          event('2024-01-01', id: 'b'),
          event('2024-01-02'),
        ]);
    final m = metrics(h, '2024-01-08', 1, index);
    expect([m.current, m.completed, m.eligible], [0, 0, 1]);
    expect(habitStatus(h, '2024-01-03', '2024-01-08', index), 'notScheduled');
  });
  test(
    'qualified current week counts, incomplete current week is not a failure',
    () {
      final h = habit(kind: 'weekly'),
          index = HabitIndex([
            for (final d in ['2024-01-01', '2024-01-02', '2024-01-03'])
              event(d),
          ]);
      expect(metrics(h, '2024-01-04', 1, index).current, 1);
      expect(metrics(h, '2024-01-09', 1, index).current, 1);
      expect(metrics(h, '2024-01-15', 1, index).current, 0);
    },
  );
  test(
    'first partial week excluded and Sunday week crosses year correctly',
    () {
      expect(
        metrics(
          habit(kind: 'weekly', start: '2024-01-03'),
          '2024-01-07',
          1,
          HabitIndex([]),
        ).eligible,
        0,
      );
      final h = habit(kind: 'weekly', start: '2023-12-31', weekStart: 7);
      expect(
        metrics(
          h,
          '2024-01-04',
          1,
          HabitIndex([
            event('2023-12-31'),
            event('2024-01-01'),
            event('2024-01-02'),
          ]),
        ).current,
        1,
      );
    },
  );
  test('effective schedule versions preserve old targets and dates', () {
    final h = habit(type: 'count').copy({
      'schedules': [
        habit(type: 'count').schedules.first.toJson(),
        Schedule(
          id: 'v2',
          from: '2024-01-04',
          kind: 'weekdays',
          weekdays: [4],
          target: 2000,
        ).toJson(),
      ],
    });
    final m = metrics(
      h,
      '2024-01-05',
      1,
      HabitIndex([
        event('2024-01-01'),
        event('2024-01-02'),
        event('2024-01-03'),
        event('2024-01-04', value: 2000),
      ]),
    );
    expect(m.current, 4);
    expect(scheduleOn(h, '2024-01-02')!.target, 1000);
  });
  test('archive pauses future eligibility without rewriting earlier dates', () {
    final original = habit(),
        archived = archiveHabit(original, '2024-01-03', true);
    expect(isScheduledOn(archived, '2024-01-03'), true);
    expect(isScheduledOn(archived, '2024-01-04'), false);
    final resumed = archiveHabit(archived, '2024-01-10', false);
    expect(isScheduledOn(resumed, '2024-01-09'), false);
    expect(isScheduledOn(resumed, '2024-01-10'), true);
    expect(
      metrics(
        resumed,
        '2024-01-10',
        1,
        HabitIndex([
          event('2024-01-01'),
          event('2024-01-02'),
          event('2024-01-03'),
        ]),
      ).current,
      3,
    );
  });
  test(
    'binary/count values and skip conflicts are refused transactionally',
    () {
      expect(
        () => state(habit(), [event('2024-01-01', value: 2000)]).validate(),
        throwsFormatException,
      );
      expect(
        () => state(habit(type: 'count'), [
          event('2024-01-01', value: 500),
        ]).validate(),
        throwsFormatException,
      );
      expect(
        () => state(habit(), [
          event('2024-01-01'),
          event('2024-01-01', id: 'skip', value: 0, skipped: true),
        ]).validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'same event retry is idempotent and future/backfill bounds are enforced',
    () {
      final s = state(habit()), e = event('2024-01-01');
      final next = record(s, e, today: '2024-01-01');
      expect(record(next, e, today: '2024-01-01').events.length, 1);
      expect(
        () => record(s, event('2024-01-03'), today: '2024-01-02'),
        throwsFormatException,
      );
      expect(() => record(s, e, today: '2025-01-01'), throwsFormatException);
    },
  );
  test(
    'manual total preserves linked contributions and refuses compensation overwrites',
    () {
      final e = HabitEvent(
            id: 'linked',
            habit: 'h',
            day: '2024-01-01',
            value: 1000,
            source: 'routine',
            session: 's',
            step: 'a',
          ),
          s = state(habit(type: 'count'), [e]);
      final next = setManualTotal(
        s,
        'h',
        '2024-01-01',
        3000,
        today: '2024-01-01',
      );
      expect(HabitIndex(next.events).value('h', '2024-01-01'), 3000);
      expect(next.events.first.toJson(), e.toJson());
      expect(
        () => setManualTotal(next, 'h', '2024-01-01', 0, today: '2024-01-01'),
        throwsFormatException,
      );
    },
  );
  test(
    'routine linked completion is once per expected step, including double tap',
    () {
      final r = routine(),
          session = startSession(r, '2024-01-01', DateTime.utc(2024)),
          s = putSession(state(habit()), session),
          first = completeStep(
            s,
            session.id,
            expectedStep: 'a',
            today: '2024-01-01',
            now: DateTime.utc(2024),
          );
      final repeated = completeStep(
        first,
        session.id,
        expectedStep: 'a',
        today: '2024-01-01',
        now: DateTime.utc(2024),
      );
      expect(repeated.events.length, 1);
      expect(repeated.sessions.single.cursor, 1);
      final second = completeStep(
        repeated,
        session.id,
        expectedStep: 'b',
        today: '2024-01-01',
        now: DateTime.utc(2024),
      );
      expect(second.events.length, 1);
      expect(
        closeSession(
          second,
          session.id,
          DateTime.utc(2024),
        ).sessions.single.status,
        'finished',
      );
    },
  );
  test(
    'step undo removes only unchanged linked event; abort retains completed history',
    () {
      final r = routine(),
          session = startSession(r, '2024-01-01', DateTime.utc(2024)),
          s = putSession(
            state(habit(type: 'count'), [event('2024-01-01', id: 'manual')]),
            session,
          ),
          next = completeStep(
            s,
            session.id,
            expectedStep: 'a',
            today: '2024-01-01',
            now: DateTime.utc(2024),
            addExtra: true,
          ),
          undone = undoStep(next, session.id, 0);
      expect(undone.events.single.id, 'manual');
      expect(
        closeSession(
          next,
          session.id,
          DateTime.utc(2024),
          abort: true,
        ).events.length,
        2,
      );
      final edited = next.copy({
        'events': [
          next.events.first.toJson(),
          {...next.events.last.toJson(), 'note': 'modified'},
        ],
      });
      expect(() => undoStep(edited, session.id, 0), throwsFormatException);
    },
  );
  test('deleting linked habit never fabricates a replacement check-in', () {
    final r = routine(),
        session = startSession(r, '2024-01-01', DateTime.utc(2024)),
        s = HabitState(sessions: [session]);
    final next = completeStep(
      s,
      session.id,
      expectedStep: 'a',
      today: '2024-01-01',
      now: DateTime.utc(2024),
    );
    expect(next.events, isEmpty);
    expect(next.sessions.single.steps.first.status, 'completed');
  });
  test(
    'recovery pauses and never autocompletes; clock anomalies do not add time',
    () {
      final r = routine(),
          session = startSession(r, '2024-01-01', DateTime.utc(2024));
      final recovered = recoverSession(session, DateTime.utc(2024, 1, 1, 0, 2));
      expect(recovered.elapsed, 0);
      expect(recovered.running, false);
      expect(recovered.steps.first.status, 'pending');
      expect(recoverSession(session, DateTime.utc(2023)).elapsed, 0);
      expect(recoverSession(session, DateTime.utc(2025)).elapsed, 0);
    },
  );
  for (final zip in [false, true]) {
    test(
      '${zip ? 'ZIP' : 'JSON'} full roundtrip and future schema refusal',
      () {
        final s = state(habit(), [event('2024-01-01')]);
        expect(restore(backup(s, zip: zip), zip: zip).toJson(), s.toJson());
        expect(
          () => HabitState.fromJson({...s.toJson(), 'schema': 99}),
          throwsFormatException,
        );
      },
    );
  }
  test(
    'ZIP checksum, traversal, truncation and size guards refuse malformed backups',
    () {
      final archive = Archive()
        ..addFile(ArchiveFile('manifest.json', 2, utf8.encode('{}')))
        ..addFile(ArchiveFile('../data.json', 2, utf8.encode('{}')));
      expect(
        () => restore(Uint8List.fromList(ZipEncoder().encode(archive))),
        throwsFormatException,
      );
      expect(() => restore(Uint8List.fromList([80, 75, 1])), throwsA(anything));
    },
  );
  test(
    'merge remaps colliding IDs and linked provenance; repeated backup refused',
    () {
      final r = routine(),
          session = startSession(r, '2024-01-01', DateTime.utc(2024)),
          source = completeStep(
            putSession(state(habit()), session),
            session.id,
            expectedStep: 'a',
            today: '2024-01-01',
            now: DateTime.utc(2024),
          );
      final merged = merge(state(habit()), source);
      expect(merged.habits.length, 2);
      expect(merged.habits.map((h) => h.id).toSet().length, 2);
      expect(merged.events.single.habit, isNot('h'));
      expect(undoStep(merged, merged.sessions.single.id, 0).events, isEmpty);
      expect(() => merge(merged, source), throwsFormatException);
    },
  );
  test(
    'reminder quiet hours and weekdays reschedule without asking permission',
    () {
      final s = state(habit()).copy({
            'settings': {
              'zone': 'UTC',
              'quietStart': '22:00',
              'quietEnd': '07:00',
              'reminders': [
                Reminder(
                  id: 'n',
                  target: 'h',
                  type: 'habit',
                  time: '23:00',
                ).toJson(),
              ],
            },
          }),
          plan = dueReminders(s, DateTime.utc(2024, 1, 1, 12));
      expect(plan.first.when.hour, 7);
      expect(day(plan.first.when), '2024-01-02');
      expect(plan.length, lessThanOrEqualTo(50));
    },
  );
  test('DST missing reminder time is skipped, not silently shifted', () {
    final s = state(habit()).copy({
          'settings': {
            'zone': 'America/New_York',
            'quietStart': '00:00',
            'quietEnd': '00:00',
            'reminders': [
              Reminder(
                id: 'n',
                target: 'h',
                type: 'habit',
                time: '02:30',
              ).toJson(),
            ],
          },
        }),
        plan = dueReminders(s, DateTime.parse('2024-03-09T23:00:00Z'));
    expect(plan.any((r) => day(r.when) == '2024-03-10'), false);
    expect(plan.first.when.day, 11);
  });
  test('10k events aggregate once and keep exact per-day counts', () {
    final h = habit(type: 'count', target: 1000000),
        events = List.generate(
          10000,
          (i) => event(addDays('2024-01-01', i ~/ 100), id: 'e$i'),
        ),
        s = state(h, events);
    s.validate();
    final index = HabitIndex(s.events);
    expect(index.value('h', '2024-01-01'), 100000);
    expect(restore(backup(s)).events.length, 10000);
  });
  test('the week review counts kept and due days and names the hard day', () {
    // Daily from Monday 2024-01-01; the first week keeps four days, the
    // next only Monday and Tuesday.
    final h = habit(kind: 'daily', weekdays: const [1, 2, 3, 4, 5, 6, 7]);
    final s = state(h, [
      event('2024-01-01'),
      event('2024-01-02'),
      event('2024-01-04'),
      event('2024-01-05'),
      event('2024-01-08'),
      event('2024-01-09'),
    ]);
    expect(reviewWeekStart('2024-01-14', 1), '2024-01-08');
    expect(reviewWeekStart('2024-01-15', 1), '2024-01-08');
    final r = weekReview(s, HabitIndex.of(s), '2024-01-08', '2024-01-15');
    expect((r.kept, r.due), (2, 7));
    expect((r.keptBefore, r.dueBefore), (4, 7));
    expect(r.habits.single.struggling, isTrue);
    // One habit misses each day at most once: no day stands out.
    expect(r.hardestDay, isNull);
  });
}
