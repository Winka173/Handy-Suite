import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

void main() {
  test(
    'import and active session reject incompatible fractional linked counts',
    () {
      final h = Habit(
        id: 'h',
        title: 'Read',
        type: 'count',
        created: '2024-01-01',
        schedules: [Schedule(id: 'v', from: '2024-01-01')],
      );
      final r = Routine(
        id: 'r',
        title: 'Read',
        steps: [
          RoutineStep(id: 's', title: 'Read', habit: 'h', linkedValue: 1500),
        ],
      );
      expect(
        () => HabitState(habits: [h], routines: [r]).validate(),
        throwsFormatException,
      );
      final session = startSession(r, '2024-01-01', DateTime.utc(2024));
      expect(
        () => HabitState(habits: [h], sessions: [session]).validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'long-interval reminder plans its next eligible occurrence beyond one month',
    () {
      final h = Habit(
        id: 'annual',
        title: 'Annual practice',
        created: '2024-01-01',
        schedules: [
          Schedule(id: 'v', from: '2024-01-01', kind: 'interval', interval: 90),
        ],
      );
      final s = HabitState(
        habits: [h],
        settings: {
          'zone': 'UTC',
          'reminders': [
            Reminder(
              id: 'r',
              target: h.id,
              type: 'habit',
              time: '09:00',
            ).toJson(),
          ],
        },
      );
      final result = dueReminders(s, DateTime.utc(2024, 1, 2));
      expect(day(result.first.when), '2024-03-31');
      expect(result.length, lessThanOrEqualTo(50));
    },
  );
  test(
    'weekly filtered range excludes the partial first week and earlier check-ins',
    () {
      final h = Habit(
        id: 'h',
        title: 'Read',
        created: '2024-01-01',
        schedules: [
          Schedule(
            id: 'v',
            from: '2024-01-01',
            kind: 'weekly',
            weeklyTarget: 1,
          ),
        ],
      );
      final index = HabitIndex([
        HabitEvent(id: 'e', habit: 'h', day: '2024-01-01', value: 1000),
      ]);
      final result = metrics(h, '2024-01-14', 1, index, from: '2024-01-03');
      expect(result.completed, 0);
      expect(result.eligible, 0); // second week remains open on its Sunday.
    },
  );
  test('settings snapshots deeply reject mutation', () {
    final state = HabitState(
      settings: {
        'nested': {
          'items': [1],
        },
      },
    );
    expect(
      () => (state.settings['nested'] as Map)['items'].add(2),
      throwsUnsupportedError,
    );
  });
  test('timestamp import rejects normalization and impossible UTC offsets', () {
    for (final value in [
      '2024-01-01T25:00:00Z',
      '2024-01-01T12:60:00Z',
      '2024-01-01T12:00:60Z',
      '2024-01-01T12:00:00+99:00',
      '2024-01-01T12:00:00+14:01',
      '2024-02-30T12:00:00Z',
      '2024-01-01T12:00:00',
    ]) {
      expect(() => timestamp(value), throwsFormatException, reason: value);
    }
    expect(timestamp('2024-01-01T12:00:00+07:00'), '2024-01-01T05:00:00.000Z');
    expect(
      timestamp('2024-01-01T12:00:00.123456-03:30'),
      '2024-01-01T15:30:00.123456Z',
    );
  });
  test(
    'long session completion and recovery stay bounded without losing history',
    () {
      final routine = Routine(
        id: 'r',
        title: 'Read',
        steps: [RoutineStep(id: 's', title: 'Read')],
      );
      final session = startSession(routine, '2024-01-01', DateTime.utc(2024));
      var state = HabitState(routines: [routine], sessions: [session]);
      state = completeStep(
        state,
        session.id,
        expectedStep: 's',
        today: '2024-01-01',
        now: DateTime.utc(2024),
        elapsed: 86400 * 8,
      );
      expect(state.sessions.single.steps.single.elapsed, 86400 * 8);
      final saturated = session.copy({
        'steps': [
          session.steps.single.copy({'elapsed': maxElapsed}).toJson(),
        ],
      });
      expect(
        recoverSession(
          saturated,
          DateTime.utc(2024).add(const Duration(hours: 1)),
        ).steps.single.elapsed,
        maxElapsed,
      );
    },
  );
}
