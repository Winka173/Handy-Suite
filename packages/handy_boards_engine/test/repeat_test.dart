import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

const a = 'b0000000-0000-4000-8000-00000000000a';
final now = DateTime(2026, 11, 9, 9);

void main() {
  test('weekdays, intervals and month ends', () {
    // Monday 9 Nov, Mon/Wed/Fri: Wed 11, then Fri 13, then Mon 16.
    var d = DateTime(2026, 11, 9);
    final seen = <int>[];
    for (var i = 0; i < 4; i++) {
      d = nextRepeatDay(d, 'weekly', days: [1, 3, 5]);
      seen.add(d.day);
    }
    expect(seen, [11, 13, 16, 18]);
    // Every 2 weeks on Tuesday, from Tuesday 10 Nov: 24 Nov.
    expect(
      nextRepeatDay(DateTime(2026, 11, 10), 'weekly', n: 2, days: [2]),
      DateTime(2026, 11, 24),
    );
    expect(
      nextRepeatDay(DateTime(2026, 11, 9), 'daily', n: 3),
      DateTime(2026, 11, 12),
    );
    expect(
      nextRepeatDay(DateTime(2027, 1, 31), 'monthly'),
      DateTime(2027, 2, 28),
    );
  });

  test('a repeat stops at its end date or after its count', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('project')!,
      answers: {'title': 'P'},
      now: now,
      boardId: a,
    );
    final done = columnsOf(s, a).firstWhere((c) => c.flag('done')).id;
    var t = newTask(s, a, 'Water plants').copy({
      'due': {'kind': 'day', 'day': '2026-11-09'},
      'repeat': 'daily',
      'repeatEvery': 2,
      'repeatLeft': 1,
    });
    s = saveTask(s, t, now: now);
    s = moveCard(s, t.id, column: done, index: 0, now: now);
    final next = s.get('tasks', s.get('tasks', t.id).str('repeatedAs'));
    expect(dueDay(next), DateTime(2026, 11, 11));
    expect(next.data['repeatLeft'], 0);
    // The last one makes no more.
    s = moveCard(s, next.id, column: done, index: 0, now: now);
    expect(s.get('tasks', next.id).data['repeatedAs'], isNull);
    // An end date before the next time: none either.
    var u = newTask(s, a, 'Report').copy({
      'due': {'kind': 'day', 'day': '2026-11-09'},
      'repeat': 'weekly',
      'repeatUntil': '2026-11-10',
    });
    s = saveTask(s, u, now: now);
    s = moveCard(s, u.id, column: done, index: 0, now: now);
    expect(s.get('tasks', u.id).data['repeatedAs'], isNull);
  });
}
