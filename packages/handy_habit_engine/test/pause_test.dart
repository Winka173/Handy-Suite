import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

Habit daily([String id = 'h']) => Habit(
  id: id,
  title: 'Read $id',
  created: '2024-01-01',
  schedules: [Schedule(id: 'v$id', from: '2024-01-01')],
);

Habit weekly({int quota = 3}) => Habit(
  id: 'w',
  title: 'Run',
  created: '2024-01-01',
  schedules: [
    Schedule(id: 'vw', from: '2024-01-01', kind: 'weekly', weeklyTarget: quota),
  ],
);

HabitEvent done(String d, {String habit = 'h'}) => HabitEvent(
  id: '$habit:$d',
  habit: habit,
  day: d,
  value: 1000,
  updated: '2024-01-01T00:00:00Z',
);

Pause pause(
  String from,
  String until, {
  String id = 'p',
  List<String> habits = const [],
  String reason = '',
}) => Pause(id: id, from: from, until: until, habits: habits, reason: reason);

HabitState world({
  List<Habit>? habits,
  List<HabitEvent> events = const [],
  List<Pause> pauses = const [],
  Map<String, dynamic> settings = const {'zone': 'UTC'},
}) => HabitState(
  habits: habits ?? [daily()],
  events: events,
  pauses: pauses,
  settings: settings,
);

HabitMetrics daysOf(HabitState s, String today, [String id = 'h']) => metrics(
  s.habits.firstWhere((h) => h.id == id),
  today,
  s.weekStart,
  HabitIndex.of(s),
);

void main() {
  group('daily streaks across a pause', () {
    final events = [
      for (final d in ['2024-01-01', '2024-01-02', '2024-01-03']) done(d),
      done('2024-01-07'),
      done('2024-01-08'),
    ];
    test('paused days not done neither break nor count', () {
      final without = daysOf(world(events: events), '2024-01-08');
      expect((without.current, without.completed, without.eligible), (2, 5, 8));
      final s = world(
        events: events,
        pauses: [pause('2024-01-04', '2024-01-06')],
      );
      final m = daysOf(s, '2024-01-08');
      expect((m.current, m.longest, m.completed, m.eligible), (5, 5, 5, 5));
      final index = HabitIndex.of(s), h = s.habits.single;
      expect(habitStatus(h, '2024-01-05', '2024-01-08', index), 'paused');
      expect(habitStatus(h, '2024-01-03', '2024-01-08', index), 'completed');
      expect(habitStatus(h, '2024-01-07', '2024-01-08', index), 'completed');
    });
    test('a paused day done anyway still counts', () {
      final s = world(
        events: [...events, done('2024-01-05')],
        pauses: [pause('2024-01-04', '2024-01-06')],
      );
      final m = daysOf(s, '2024-01-08');
      expect((m.current, m.completed, m.eligible), (6, 6, 6));
      expect(
        habitStatus(
          s.habits.single,
          '2024-01-05',
          '2024-01-08',
          HabitIndex.of(s),
        ),
        'completed',
      );
    });
    test('the first day after a pause is an ordinary day', () {
      final s = world(
        events: [done('2024-01-01'), done('2024-01-02')],
        pauses: [pause('2024-01-03', '2024-01-05')],
      );
      // Today right after the pause, not yet done: open, the run holds.
      expect(daysOf(s, '2024-01-06').current, 2);
      expect(
        habitStatus(
          s.habits.single,
          '2024-01-06',
          '2024-01-06',
          HabitIndex.of(s),
        ),
        'open',
      );
      // A day after the pause not done is missed and breaks it.
      expect(daysOf(s, '2024-01-07').current, 0);
      expect(
        habitStatus(
          s.habits.single,
          '2024-01-06',
          '2024-01-07',
          HabitIndex.of(s),
        ),
        'missed',
      );
    });
    test('today inside a pause is paused, not open', () {
      final s = world(pauses: [pause('2024-01-08', '2024-01-10')]);
      expect(
        habitStatus(
          s.habits.single,
          '2024-01-08',
          '2024-01-08',
          HabitIndex.of(s),
        ),
        'paused',
      );
    });
    test('a pause for chosen habits leaves the others alone', () {
      final s = world(
        habits: [daily('h'), daily('k')],
        pauses: [
          pause('2024-01-02', '2024-01-03', habits: ['k']),
        ],
      );
      // Open today is left out for both; k also leaves out its two paused days.
      expect(daysOf(s, '2024-01-04', 'k').eligible, 1);
      expect(daysOf(s, '2024-01-04', 'h').eligible, 3);
    });
  });

  group('weekly quotas', () {
    test('a part-paused week needs a prorated quota, rounded up', () {
      final w = weekly();
      final s = world(
        habits: [w],
        events: [
          done('2024-01-05', habit: 'w'),
          done('2024-01-06', habit: 'w'),
        ],
        pauses: [pause('2024-01-01', '2024-01-04')],
      );
      final index = HabitIndex.of(s);
      // 3 × 3 unpaused days / 7 = 1.29, rounded up to 2.
      expect(weekQuota(w, '2024-01-01', index), 2);
      final m = metrics(w, '2024-01-08', 1, index);
      expect((m.current, m.completed, m.eligible), (1, 1, 1));
      // One paused day: 3 × 6 / 7 = 2.57 → 3, the same as no pause.
      expect(
        weekQuota(
          w,
          '2024-01-01',
          HabitIndex([], [pause('2024-01-01', '2024-01-01')]),
        ),
        3,
      );
    });
    test('a wholly paused week is skipped and keeps the run', () {
      final w = weekly(quota: 2);
      final s = world(
        habits: [w],
        events: [
          done('2024-01-01', habit: 'w'),
          done('2024-01-02', habit: 'w'),
          done('2024-01-15', habit: 'w'),
          done('2024-01-16', habit: 'w'),
        ],
        pauses: [pause('2024-01-08', '2024-01-14')],
      );
      final index = HabitIndex.of(s);
      expect(weekQuota(w, '2024-01-08', index), 0);
      final m = metrics(w, '2024-01-22', 1, index);
      expect((m.current, m.completed, m.eligible), (2, 2, 2));
      final unpaused = metrics(w, '2024-01-22', 1, HabitIndex(s.events));
      expect((unpaused.current, unpaused.eligible), (1, 3));
    });
  });

  group('editing pauses', () {
    final base = world(
      events: [done('2024-01-01'), done('2024-01-05')],
      pauses: [pause('2024-01-02', '2024-01-04')],
    );
    test('changing the range changes the counts; deleting restores misses', () {
      expect(daysOf(base, '2024-01-05').current, 2);
      final shorter = putPause(
        base,
        base.pauses.single.copy({'until': '2024-01-03'}),
        today: '2024-01-05',
      );
      expect(daysOf(shorter, '2024-01-05').current, 1);
      final gone = deletePause(base, 'p');
      expect(gone.pauses, isEmpty);
      expect(daysOf(gone, '2024-01-05').eligible, 5);
      expect(daysOf(gone, '2024-01-05').current, 1);
    });
    test('a new start cannot reach back past the fill-in window', () {
      final s = world(settings: {'zone': 'UTC', 'backfill': 3});
      expect(
        () =>
            putPause(s, pause('2024-01-01', '2024-01-09'), today: '2024-01-10'),
        throwsFormatException,
      );
      final ok = putPause(
        s,
        pause('2024-01-07', '2024-01-12'),
        today: '2024-01-10',
      );
      // Editing an old pause's end keeps its old start.
      final later = putPause(
        ok,
        ok.pauses.single.copy({'until': '2024-01-20'}),
        today: '2024-01-15',
      );
      expect(later.pauses.single.until, '2024-01-20');
      expect(
        () => putPause(
          s,
          pause('2024-01-10', '2024-01-12', habits: ['x']),
          today: '2024-01-10',
        ),
        throwsFormatException,
      );
    });
    test('ending early keeps the days before today; unstarted ones go', () {
      final s = world(
        pauses: [
          pause('2024-01-05', '2024-01-20'),
          pause('2024-01-10', '2024-01-12', id: 'today'),
          pause('2024-01-15', '2024-01-16', id: 'later'),
          pause('2024-01-01', '2024-01-03', id: 'over'),
        ],
      );
      var next = endPause(s, 'p', today: '2024-01-10');
      expect(next.pauses.firstWhere((p) => p.id == 'p').until, '2024-01-09');
      next = endPause(next, 'today', today: '2024-01-10');
      expect(next.pauses.any((p) => p.id == 'today'), isFalse);
      next = endPause(next, 'later', today: '2024-01-10');
      expect(next.pauses.any((p) => p.id == 'later'), isFalse);
      expect(
        endPause(next, 'over', today: '2024-01-10').toJson(),
        next.toJson(),
      );
      expect(restingNow(next, '2024-01-10'), isNull);
    });
    test('touching pauses read as one stretch', () {
      final s = world(
        pauses: [
          pause('2024-01-01', '2024-01-05'),
          pause('2024-01-06', '2024-01-09', id: 'q'),
          pause('2024-01-03', '2024-01-04', id: 'r', habits: ['h']),
        ],
      );
      expect(pausedUntil(s.pauses, 'h', '2024-01-02'), '2024-01-09');
      expect(pausedUntil(s.pauses, 'h', '2024-01-10'), isNull);
      final (_, until) = restingNow(s, '2024-01-04')!;
      expect(until, '2024-01-09');
    });
    test('a deleted habit leaves its pauses; a pause left empty goes', () {
      final s = world(
        habits: [daily('h'), daily('k')],
        pauses: [
          pause('2024-01-01', '2024-01-02', habits: ['h']),
          pause('2024-01-03', '2024-01-04', id: 'both', habits: ['h', 'k']),
          pause('2024-01-05', '2024-01-06', id: 'all'),
        ],
      );
      final next = dropHabitFromPauses(s, 'h');
      expect(next.pauses.map((p) => p.id), ['both', 'all']);
      expect(next.pauses.first.habits, ['k']);
      expect(next.pauses.last.everything, isTrue);
    });
    test('a pause is bounded and must name real habits', () {
      expect(() => pause('2024-01-05', '2024-01-04'), throwsFormatException);
      expect(() => pause('2024-01-01', '2025-01-01'), throwsFormatException);
      expect(() => pause('2024-01-01', '2024-12-31'), returnsNormally);
      expect(
        () => world(
          pauses: [
            pause('2024-01-01', '2024-01-02', habits: ['x']),
          ],
        ).validate(),
        throwsFormatException,
      );
    });
  });

  group('reminders', () {
    Map<String, dynamic> settings(String type, String target) => {
      'zone': 'UTC',
      'quietStart': '00:00',
      'quietEnd': '00:00',
      'reminders': [
        Reminder(id: 'n', target: target, type: type, time: '08:00').toJson(),
      ],
    };
    final r = Routine(
      id: 'r',
      title: 'Morning',
      steps: [RoutineStep(id: 'a', title: 'Stretch')],
    );
    test('a paused habit is not reminded; others still are', () {
      final s = world(
        habits: [daily('h'), daily('k')],
        pauses: [
          pause('2024-01-02', '2024-01-03', habits: ['h']),
        ],
        settings: settings('habit', 'h'),
      );
      final days = dueReminders(
        s,
        DateTime.utc(2024, 1, 1, 12),
      ).map((d) => day(d.when)).take(3).toList();
      expect(days, ['2024-01-04', '2024-01-05', '2024-01-06']);
    });
    test('a pause for everything also quiets routine reminders', () {
      HabitState with_(List<Pause> pauses) => HabitState(
        habits: [daily()],
        routines: [r],
        pauses: pauses,
        settings: settings('routine', 'r'),
      );
      List<String> first(HabitState s) => dueReminders(
        s,
        DateTime.utc(2024, 1, 1, 12),
      ).map((d) => day(d.when)).take(2).toList();
      expect(first(with_([pause('2024-01-02', '2024-01-04')])), [
        '2024-01-05',
        '2024-01-06',
      ]);
      expect(
        first(
          with_([
            pause('2024-01-02', '2024-01-04', habits: ['h']),
          ]),
        ),
        ['2024-01-02', '2024-01-03'],
      );
    });
    test('quiet hours read in the data time zone', () {
      final s = world(
        settings: {
          'zone': 'Asia/Ho_Chi_Minh',
          'quietStart': '22:00',
          'quietEnd': '07:00',
        },
      );
      expect(inQuietHours(s, DateTime.utc(2024, 1, 1, 16)), isTrue); // 23:00
      expect(inQuietHours(s, DateTime.utc(2024, 1, 1, 1)), isFalse); // 08:00
      final off = s.copy({
        'settings': {...s.settings, 'quietEnd': '22:00'},
      });
      expect(inQuietHours(off, DateTime.utc(2024, 1, 1, 16)), isFalse);
    });
  });

  group('schema and portability', () {
    final s = world(
      habits: [daily('h'), daily('k')],
      events: [done('2024-01-01')],
      pauses: [
        pause('2024-01-02', '2024-01-04', reason: 'Đi Đà Lạt, "nghỉ"'),
        pause('2024-01-06', '2024-01-07', id: 'q', habits: ['k']),
      ],
    );
    test('schema 1 data reads with no pauses and is written as schema 5', () {
      final old = s.toJson()
        ..['schema'] = 1
        ..remove('pauses');
      final read = HabitState.fromJson(old);
      expect(read.pauses, isEmpty);
      expect(read.toJson()['schema'], habitSchema);
      expect(
        () => HabitState.fromJson({...old, 'pauses': []}),
        throwsFormatException,
      );
      expect(
        () => HabitState.fromJson({...s.toJson(), 'schema': 99}),
        throwsFormatException,
      );
    });
    test('JSON and ZIP backups keep pauses exactly', () {
      for (final zip in [true, false]) {
        final back = restore(backup(s, zip: zip), zip: zip);
        expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
      }
    });
    test('a schema 1 ZIP backup still restores', () {
      final json = s.toJson()
        ..['schema'] = 1
        ..remove('pauses');
      final data = utf8.encode(jsonEncode(json)),
          manifest = utf8.encode(
            jsonEncode({
              'app': 'handy-habit',
              'schema': 1,
              'files': {'data.json': sha256.convert(data).toString()},
              'assets': [],
            }),
          );
      final zip = Uint8List.fromList(
        ZipEncoder().encode(
          Archive()
            ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
            ..addFile(ArchiveFile('data.json', data.length, data)),
        ),
      );
      final back = restore(zip);
      expect(back.pauses, isEmpty);
      expect(back.events.length, 1);
    });
    test('merge gives pauses new IDs and follows the habits', () {
      final merged = merge(world(habits: [daily('mine')]), s);
      expect(merged.pauses.length, 2);
      expect(
        merged.pauses.map((p) => p.id).toSet().intersection({'p', 'q'}),
        isEmpty,
      );
      final chosen = merged.pauses.firstWhere((p) => !p.everything);
      final k = merged.habits.firstWhere((h) => h.title == 'Read k');
      expect(chosen.habits, [k.id]);
      expect(
        merged.pauses.firstWhere((p) => p.everything).reason,
        'Đi Đà Lạt, "nghỉ"',
      );
    });
    test('CSV carries pauses as a second table and reads them back', () {
      final text = csvLogs(s, '2024-01-01', '2024-01-31');
      expect(text, contains('\r\n\r\n"pause_id","from","until"'));
      final bytes = Uint8List.fromList(utf8.encode(text));
      final into = world(habits: [daily('h'), daily('k')]);
      final back = importCsvLogs(into, bytes);
      expect(
        jsonEncode(back.pauses.map((p) => p.toJson()).toList()),
        jsonEncode(s.pauses.map((p) => p.toJson()).toList()),
      );
      expect(back.events.length, 1);
      // Importing twice adds nothing.
      expect(importCsvLogs(back, bytes).pauses.length, 2);
      // A range that misses both pauses leaves the table out.
      expect(
        csvLogs(s, '2024-01-20', '2024-01-31'),
        isNot(contains('pause_id')),
      );
    });
    test('CSV pause rows refuse tampering, conflicts and unknown habits', () {
      final text = csvLogs(s, '2024-01-01', '2024-01-31');
      final tampered = text.replaceFirst('"2024-01-04"', '"2024-01-09"');
      final into = world(habits: [daily('h'), daily('k')]);
      expect(
        () => importCsvLogs(into, Uint8List.fromList(utf8.encode(tampered))),
        throwsFormatException,
      );
      final conflicting = into.copy({
        'pauses': [pause('2024-02-01', '2024-02-02').toJson()],
      });
      expect(
        () => importCsvLogs(conflicting, Uint8List.fromList(utf8.encode(text))),
        throwsFormatException,
      );
      expect(conflicting.pauses.single.from, '2024-02-01');
      expect(
        () => importCsvLogs(
          world(habits: [daily('h')]),
          Uint8List.fromList(utf8.encode(text)),
        ),
        throwsFormatException,
      );
    });
    test('a CSV made before pauses still imports', () {
      final plain = world(events: [done('2024-01-01')]);
      final text = csvLogs(plain, '2024-01-01', '2024-01-31');
      expect(text, isNot(contains('pause_id')));
      expect(
        importCsvLogs(
          world(),
          Uint8List.fromList(utf8.encode(text)),
        ).events.length,
        1,
      );
    });
    test('Markdown lists pauses in range with the counting rule', () {
      final en = markdownReport(s, '2024-01-01', '2024-01-31');
      expect(en, contains('## Pauses'));
      expect(
        en,
        contains('- 2024-01-02 — 2024-01-04 · All habits · Đi Đà Lạt'),
      );
      expect(en, contains('- 2024-01-06 — 2024-01-07 · Read k'));
      final vi = markdownReport(
        s,
        '2024-01-01',
        '2024-01-31',
        vietnamese: true,
      );
      expect(vi, contains('## Kỳ nghỉ'));
      expect(vi, contains('Tất cả thói quen'));
      expect(
        markdownReport(world(), '2024-01-01', '2024-01-31'),
        isNot(contains('Pauses')),
      );
    });
  });
}
