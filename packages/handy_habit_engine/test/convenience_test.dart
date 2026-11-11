import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:test/test.dart';

HabitState seed() => HabitState(
  habits: [
    Habit(
      id: 'water',
      title: 'Water',
      type: 'count',
      created: '2024-01-01',
      category: 'Gym',
      schedules: [Schedule(id: 'g', from: '2024-01-01', target: 8000)],
    ),
  ],
  routines: [
    Routine(
      id: 'morning',
      title: 'Morning',
      steps: [RoutineStep(id: 'step', title: 'Breathe')],
    ),
  ],
);
void main() {
  const today = '2024-01-08';
  test('batch preview is atomic, stale-safe and has one durable Undo', () {
    final s = seed();
    final next = recordChange(
      s,
      batchHabits(
        s,
        {'water'},
        'collection',
        'Home',
        expectedRevision: 0,
        today: today,
      ),
      actor: 'a',
    );
    expect(next.habits.single.category, 'Home');
    expect(
      undoChange(
        HabitState.fromJson(next.toJson()),
        next.undoBatch!,
        actor: 'a',
      ).habits.single.category,
      'Gym',
    );
    expect(
      () => batchHabits(
        s,
        {'water'},
        'archive',
        '',
        expectedRevision: 1,
        today: today,
      ),
      throwsStateError,
    );
    expect(
      () => batchHabits(
        s,
        {'missing'},
        'archive',
        '',
        expectedRevision: 0,
        today: today,
      ),
      throwsStateError,
    );
  });
  test('holiday and reminder batches preserve rules and undo together', () {
    final s = seed().copy({
      'settings': {
        'reminders': [
          Reminder(
            id: 'rem',
            target: 'water',
            type: 'habit',
            enabled: false,
          ).toJson(),
        ],
      },
    });
    final r = batchHabits(
      s,
      {'water'},
      'reminder',
      '10:30',
      expectedRevision: 0,
      today: today,
    );
    expect((r.settings['reminders'] as List).single['enabled'], false);
    expect((r.settings['reminders'] as List).single['time'], '10:30');
    final p = batchHabits(
      s,
      {'water'},
      'pause',
      today,
      until: '2024-01-12',
      expectedRevision: 0,
      today: today,
    );
    expect(p.pauses.single.habits, ['water']);
  });
  test(
    'routine rule runs once, names effect, survives restore and Undo cannot replay',
    () {
      final initial = seed();
      final session = startSession(
        initial.routines.single,
        today,
        DateTime.utc(2024, 1, 8),
      );
      final rule = ConvenienceRule(
        id: 'r',
        name: 'Morning water',
        kind: 'routine',
        source: 'morning',
        target: 'water',
      );
      final before = initial.copy({
        'sessions': [session.toJson()],
        'settings': {
          'convenienceRules': [rule.toJson()],
        },
      });
      final proposed = before.copy({
        'sessions': [
          session.copy({'status': 'finished', 'anchor': null}).toJson(),
        ],
      });
      final first = evaluateConvenience(before, proposed, today);
      final retry = evaluateConvenience(before, proposed, today);
      expect(first.events.single.toJson(), retry.events.single.toJson());
      final effects = recordChange(
        proposed,
        evaluateConvenience(before, proposed, today),
        actor: 'a',
      );
      expect(effects.events.single.note, 'Morning water');
      expect(convenienceHistory(effects).single.$2, 'Morning water');
      final reopened = restore(backup(effects));
      expect(evaluateConvenience(before, reopened, today).events.length, 1);
      final undone = undoChange(reopened, effects.undoBatch!, actor: 'a');
      expect(undone.events, isEmpty);
      expect(evaluateConvenience(before, undone, today).events, isEmpty);
    },
  );
  test(
    'disabled and newly added routine rules never replay old finished sessions',
    () {
      final s = seed();
      final rule = ConvenienceRule(
        id: 'r',
        name: 'Off',
        kind: 'routine',
        source: 'morning',
        target: 'water',
        enabled: false,
      );
      final next = s.copy({
        'settings': {
          'convenienceRules': [rule.toJson()],
        },
      });
      expect(evaluateConvenience(s, next, today).events, isEmpty);
      expect(evaluateConvenience(next, next, today).events, isEmpty);
    },
  );
  test(
    'holiday rule only affects named collection and cannot replay after Undo',
    () {
      final s = seed().copy({
        'settings': {
          'convenienceRules': [
            ConvenienceRule(
              id: 'h',
              name: 'Gym holiday',
              kind: 'holiday',
              source: 'Gym',
              from: today,
              until: '2024-01-12',
            ).toJson(),
          ],
        },
      });
      final effects = recordChange(
        s,
        evaluateConvenience(s, s, today),
        actor: 'a',
      );
      expect(effects.pauses.single.reason, 'Gym holiday');
      final undone = undoChange(effects, effects.undoBatch!, actor: 'a');
      expect(evaluateConvenience(undone, undone, today).pauses, isEmpty);
    },
  );
}
