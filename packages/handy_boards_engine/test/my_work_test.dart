import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

final now = DateTime(2026, 11, 9, 9);
final today = DateTime(2026, 11, 9);
const a = 'b0000000-0000-4000-8000-00000000000a';
const b = 'b0000000-0000-4000-8000-00000000000b';

(BoardsState, String) add(
  BoardsState s,
  String board,
  String title, {
  DateTime? planned,
  DateTime? due,
}) {
  final t = newTask(s, board, title).copy({
    if (planned != null) 'scheduled': isoDay(planned),
    if (due != null) 'due': {'kind': 'day', 'day': isoDay(due)},
  });
  return (saveTask(s, t, now: now), t.id);
}

BoardsState two() {
  var s = createFromTemplate(
    BoardsState(),
    templateById('semester')!,
    answers: {'title': 'A'},
    now: now,
    boardId: a,
  );
  return createFromTemplate(
    s,
    templateById('project')!,
    answers: {'title': 'B'},
    now: now,
    boardId: b,
  );
}

void main() {
  test('My Work lists each card once, from every board, with its board', () {
    var s = two();
    String t1, t2, t3, t4, t5;
    (s, t1) = add(s, a, 'Planned today', planned: today, due: today);
    (s, t2) = add(s, b, 'Due today only', due: today);
    (s, t3) = add(
      s,
      a,
      'Moved today, due last week',
      planned: today,
      due: DateTime(2026, 11, 2),
    );
    (s, t4) = add(s, b, 'Next week', planned: DateTime(2026, 11, 16));
    (s, t5) = add(s, b, 'Far away', planned: DateTime(2027, 3, 1));
    final w = myWork(s, today);
    expect(w.today.map((i) => i.card.id), unorderedEquals([t1, t2]));
    expect(w.today.firstWhere((i) => i.card.id == t2).dueOnly, isTrue);
    expect(w.behind.single.card.id, t3, reason: 'still overdue, listed once');
    expect(w.upcoming.single.card.id, t4);
    expect(w.upcoming.single.board.id, b);
    expect(
      [...w.today, ...w.behind, ...w.upcoming].map((i) => i.card.id),
      isNot(contains(t5)),
    );
    expect(myWork(s, today, boards: {a}).today.single.card.id, t1);
  });

  test('carry-over moves past plans once a day, never a deadline', () {
    var s = two();
    String p, d;
    (s, p) = add(
      s,
      a,
      'Planned Friday',
      planned: DateTime(2026, 11, 6),
      due: DateTime(2026, 11, 20),
    );
    (s, d) = add(s, a, 'Only due', due: DateTime(2026, 11, 5));
    // Off: nothing happens.
    expect(runCarryOver(s, today, now: now).state, same(s));
    s = s.copy(
      preferences: {
        ...s.preferences,
        'carryOver': {'mode': 'auto'},
      },
    );
    final run = runCarryOver(s, today, now: now);
    s = run.state;
    expect(s.get('tasks', p).str('scheduled'), '2026-11-09');
    expect(dueDay(s.get('tasks', p)), DateTime(2026, 11, 20));
    expect(s.get('tasks', d).data['scheduled'], isNull);
    expect(run.before, {p: '2026-11-06'});
    // Opening the app again the same day changes nothing.
    final again = runCarryOver(s, today, now: now);
    expect(again.state, same(s));
    expect(cardHistory(s, p).last.data['details']['reason'], 'carry over');
    // Undo puts the plan back.
    s = restorePlans(s, run.before, now: now);
    expect(s.get('tasks', p).str('scheduled'), '2026-11-06');
  });
}
