import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

HabitState clockState(String zone, int boundary) => HabitState(
  settings: {'zone': zone, 'dayBoundaryMinutes': boundary},
  clockPolicies: [
    {
      'id': 'initial',
      'zone': zone,
      'dayBoundaryMinutes': boundary,
      'effectiveFrom': '1900-01-01T00:00:00.000Z',
    },
  ],
);

void main() {
  test('overnight reminders and trash use the same habit day as check-in', () {
    final h = Habit(
      id: 'h',
      title: 'Read',
      created: '2026-11-01',
      schedules: [
        Schedule(id: 'v', from: '2026-11-01', kind: 'weekdays', weekdays: [1]),
      ],
    );
    final s = clockState('UTC', 240).copy({
      'habits': [h.toJson()],
      'settings': {
        'zone': 'UTC',
        'dayBoundaryMinutes': 240,
        'quietStart': '00:00',
        'quietEnd': '00:00',
        'reminders': [
          Reminder(
            id: 'r',
            target: 'h',
            type: 'habit',
            time: '02:00',
            weekdays: [1],
          ).toJson(),
        ],
      },
    });
    final next = dueReminders(s, DateTime.utc(2026, 11, 2, 12)).first;
    expect(next.when.toUtc(), DateTime.utc(2026, 11, 3, 2));
    final removed = trashEntity(s, 'habit', 'h', next.when);
    expect(removed.trash.single.localDay, '2026-11-02');
  });

  test('copy-merge remaps day-part overrides and keeps the receiver clock', () {
    final h = Habit(
      id: 'h',
      title: 'Read',
      created: '2026-11-01',
      schedules: [Schedule(id: 'v', from: '2026-11-01')],
    );
    final imported = clockState('UTC', 240).copy({
      'habits': [h.toJson()],
      'settings': {
        'zone': 'UTC',
        'dayBoundaryMinutes': 240,
        'habitDayParts': {'h': 'evening'},
      },
    });
    final receiver = clockState('Asia/Ho_Chi_Minh', 0);
    final result = merge(receiver, imported);
    expect(result.clockPolicies, receiver.clockPolicies);
    expect(result.settings['habitDayParts'], {
      result.habits.single.id: 'evening',
    });
    expect(result.habits.single.id, isNot('h'));
  });
  test('wall-clock boundary and date/week/year rollover', () {
    final s = clockState('Asia/Ho_Chi_Minh', 240);
    expect(habitDayAt(s, DateTime.utc(2026, 12, 31, 20, 59)), '2026-12-31');
    expect(habitDayAt(s, DateTime.utc(2026, 12, 31, 21)), '2027-01-01');
    expect(habitDayAt(clockState('UTC', 0), DateTime.utc(2027)), '2027-01-01');
    expect(
      habitDayAt(clockState('UTC', 1439), DateTime.utc(2027, 1, 1, 23, 58)),
      '2026-12-31',
    );
  });

  test('DST spring gap and repeated autumn hour compare local clock', () {
    final s = clockState('America/New_York', 150);
    // Spring skips02:30: the cutoff moves forward by the one-hour gap.
    expect(habitDayAt(s, DateTime.utc(2026, 3, 8, 6, 59)), '2026-03-07');
    expect(habitDayAt(s, DateTime.utc(2026, 3, 8, 7)), '2026-03-07');
    expect(habitDayAt(s, DateTime.utc(2026, 3, 8, 7, 30)), '2026-03-08');
    // Both occurrences of 01:30 remain on the previous habit day.
    expect(habitDayAt(s, DateTime.utc(2026, 11, 1, 5, 30)), '2026-10-31');
    expect(habitDayAt(s, DateTime.utc(2026, 11, 1, 6, 30)), '2026-10-31');
    expect(habitDayAt(s, DateTime.utc(2026, 11, 1, 7, 30)), '2026-11-01');
    final early = clockState('America/New_York', 90);
    expect(habitDayAt(early, DateTime.utc(2026, 11, 1, 5, 29)), '2026-10-31');
    expect(habitDayAt(early, DateTime.utc(2026, 11, 1, 5, 30)), '2026-11-01');
    expect(habitDayAt(early, DateTime.utc(2026, 11, 1, 6)), '2026-11-01');
    final southern = clockState('Australia/Sydney', 150);
    expect(
      habitDayAt(southern, DateTime.utc(2026, 4, 4, 15, 29)),
      '2026-04-04',
    );
    expect(
      habitDayAt(southern, DateTime.utc(2026, 4, 4, 15, 30)),
      '2026-04-05',
    );
    expect(habitDayAt(southern, DateTime.utc(2026, 4, 4, 16)), '2026-04-05');
  });

  test(
    'version is selected by instant; policy edits never move stored days',
    () {
      final before = clockState('UTC', 0).copy({
        'habits': [
          Habit(
            id: 'h',
            title: 'Read',
            created: '2026-01-01',
            schedules: [Schedule(id: 'v', from: '2026-01-01')],
          ).toJson(),
        ],
        'events': [
          HabitEvent(
            id: 'e',
            habit: 'h',
            day: '2026-11-01',
            value: 1000,
          ).toJson(),
        ],
      });
      final at = DateTime.utc(2026, 11, 2, 2);
      final after = recordChange(
        before,
        before.copy({
          'settings': {
            ...before.settings,
            'zone': 'America/New_York',
            'dayBoundaryMinutes': 240,
          },
        }),
        actor: 'device',
        now: at,
        undoable: false,
      );
      expect(after.clockPolicies, hasLength(2));
      expect(
        habitDayAt(after, at.subtract(const Duration(seconds: 1))),
        '2026-11-02',
      );
      expect(habitDayAt(after, at), '2026-11-01');
      expect(after.events.single.toJson(), before.events.single.toJson());
      for (final zip in [false, true]) {
        final read = restore(backup(after, zip: zip), zip: zip);
        expect(read.toJson(), after.toJson());
        expect(habitDayAt(read, at), '2026-11-01');
      }
    },
  );

  test('v3 retains causal history and midnight policy on upgrade', () {
    final before = clockState('UTC', 0);
    final legacy = before.toJson()..['schema'] = 3;
    final read = HabitState.fromJson(legacy);
    expect(read.toJson()['schema'], 5);
    expect(read.clockPolicies, before.clockPolicies);
    expect(habitDayAt(read, DateTime.utc(2026, 11, 2)), '2026-11-02');
    expect(restore(backup(read)).toJson(), read.toJson());
  });

  test(
    'invalid boundary and retrograde policy history reject before write',
    () {
      for (final value in [-1, 1440]) {
        expect(
          () => clockState('UTC', value).validate(),
          throwsFormatException,
        );
      }
      final s = clockState('UTC', 0);
      expect(
        () => s.copy({
          'clockPolicies': [
            ...s.clockPolicies,
            {...s.clockPolicies.single, 'id': 'second'},
          ],
        }),
        throwsFormatException,
      );
    },
  );

  test('schedule effective targets keep earlier completion meaningful', () {
    final h = Habit(
      id: 'h',
      title: 'Water',
      type: 'count',
      created: '2026-11-01',
      schedules: [
        Schedule(id: 'v1', from: '2026-11-01', target: 2000),
        Schedule(id: 'v2', from: '2026-11-02', target: 4000),
      ],
    );
    final index = HabitIndex([
      HabitEvent(id: 'a', habit: 'h', day: '2026-11-01', value: 2000),
      HabitEvent(id: 'b', habit: 'h', day: '2026-11-02', value: 2000),
    ]);
    expect(habitStatus(h, '2026-11-01', '2026-11-02', index), 'completed');
    expect(habitStatus(h, '2026-11-02', '2026-11-02', index), 'partial');
  });
}
