import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

const a = 'b0000000-0000-4000-8000-00000000000a';
const b = 'b0000000-0000-4000-8000-00000000000b';
DateTime day(int d, [int h = 9]) => DateTime(2026, 11, d, h);

void main() {
  test('board history: the cards\' real events, newest first, by board', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('project')!,
      answers: {'title': 'A'},
      now: day(1),
      boardId: a,
    );
    s = createFromTemplate(
      s,
      templateById('project')!,
      answers: {'title': 'B'},
      now: day(1),
      boardId: b,
    );
    final cols = columnsOf(s, a);
    final t = newTask(s, a, 'Write copy');
    s = saveTask(s, t, now: day(1));
    s = moveCard(s, t.id, column: cols.last.id, index: 0, now: day(3));
    final other = newTask(s, b, 'Elsewhere');
    s = saveTask(s, other, now: day(2));
    final h = boardHistory(s, a);
    expect(h.map((e) => e.str('action')), ['completed', 'created']);
    expect(h.every((e) => e.str('task') == t.id), isTrue);
    expect(boardHistory(s, a, since: day(2)).map((e) => e.str('action')), [
      'completed',
    ]);
    // Trashed cards keep their history; deleted for good, it goes.
    s = trashTasks(s, {t.id}, now: day(4));
    expect(boardHistory(s, a).first.str('action'), 'trashed');
    s = permanentlyDelete(s, {t.id}, confirmed: true);
    expect(boardHistory(s, a), isEmpty);
  });

  test('old board pictures are removed', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('project')!,
      answers: {'title': 'A'},
      now: day(1),
      boardId: a,
    );
    s = s.put(
      'templates',
      BoardRecord({'id': 'p1', 'kind': 'snapshot', 'board': a}),
    );
    s = saveCardTemplate(s, title: 'Keep me', now: day(1));
    s = dropBoardPictures(s);
    expect(s.rows('templates').map((r) => r.str('kind')), ['card']);
    expect(dropBoardPictures(s), same(s));
  });
}
