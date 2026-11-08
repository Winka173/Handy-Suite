import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

final now = DateTime(2026, 11, 9, 8); // Monday 08:00
const a = 'b0000000-0000-4000-8000-00000000000a';

BoardsState base(Json notify) {
  var s = createFromTemplate(
    BoardsState(),
    templateById('project')!,
    answers: {'title': 'A'},
    now: now,
    boardId: a,
  );
  return s.copy(
    preferences: {...s.preferences, 'notifications': true, 'notify': notify},
  );
}

BoardsState card(
  BoardsState s,
  String title, {
  DateTime? planned,
  DateTime? due,
}) => saveTask(
  s,
  newTask(s, a, title).copy({
    if (planned != null) 'scheduled': isoDay(planned),
    if (due != null) 'due': {'kind': 'day', 'day': isoDay(due)},
  }),
  now: now,
);

void main() {
  test('off unless switched on; nothing without work', () {
    var s = base({'daily': true});
    expect(
      planNotifications(
        s.copy(preferences: {...s.preferences, 'notifications': false}),
        now,
        vi: false,
      ),
      isEmpty,
    );
    expect(planNotifications(s, now, vi: false), isEmpty);
  });

  test('today summary counts each card once, on the right days', () {
    var s = base({'daily': true, 'at': '09:00'});
    s = card(s, 'A', planned: DateTime(2026, 11, 9));
    s = card(s, 'B', due: DateTime(2026, 11, 9));
    s = card(
      s,
      'C',
      planned: DateTime(2026, 11, 10),
      due: DateTime(2026, 11, 9),
    );
    final notes = planNotifications(s, now, vi: true);
    final mon = notes.firstWhere((n) => n.key == 'boards:daily:2026-11-09');
    expect(mon.body, 'Hôm nay bạn có 2 việc');
    expect(mon.at, DateTime(2026, 11, 9, 9));
    expect(
      notes.where((n) => n.key == 'boards:daily:2026-11-10').single.body,
      'Hôm nay bạn có 1 việc',
    );
  });

  test('due soon, privacy, quiet hours and muted boards', () {
    var s = base({
      'dueLead': 1,
      'at': '23:00',
      'quietFrom': '22:00',
      'quietTo': '07:00',
      'private': true,
    });
    s = card(s, 'Secret essay', due: DateTime(2026, 11, 12));
    final n = planNotifications(s, now, vi: false).single;
    expect(n.body, isNot(contains('Secret')));
    // 23:00 on the 11th is quiet: it waits until 07:00 on the 12th.
    expect(n.at, DateTime(2026, 11, 12, 7));
    s = s.copy(
      preferences: {
        ...s.preferences,
        'notify': {
          ...notifyPrefs(s),
          'muted': [a],
        },
      },
    );
    expect(planNotifications(s, now, vi: false), isEmpty);
  });

  test('left behind once; the weekly review only with Pro; a cap', () {
    var s = base({'backlog': true, 'weekly': true});
    s = card(s, 'Old', planned: DateTime(2026, 11, 2));
    final free = planNotifications(s, now, vi: false);
    expect(free.map((n) => n.key), ['boards:backlog']);
    expect(
      planNotifications(s, now, vi: false, pro: true).map((n) => n.key),
      containsAll(['boards:backlog', 'boards:weekly']),
    );
    var many = base({'dueLead': 0});
    for (var i = 0; i < 60; i++) {
      many = card(many, 'C$i', due: DateTime(2026, 11, 10 + i % 10));
    }
    expect(planNotifications(many, now, vi: false), hasLength(notifyCap));
  });
}
