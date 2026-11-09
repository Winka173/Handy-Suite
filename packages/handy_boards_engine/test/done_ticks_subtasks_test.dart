import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  test('a card moved to the finished column has every subtask ticked', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('semester')!,
      answers: {'title': 'Semester 1'},
      examples: true,
      now: DateTime(2026, 11, 9),
    );
    final board = s.rows('boards').single.id;
    final columns = columnsOf(s, board);
    final done = columns.firstWhere((c) => c.flag('done'));
    final card = topTasks(s, board: board).firstWhere(
      (t) =>
          t.str('status') != done.id &&
          subtasksOf(s, t.id).any((x) => !x.flag('done')),
    );
    s = moveCard(s, card.id, column: done.id, index: 0);
    expect(subtasksOf(s, card.id).every((x) => x.flag('done')), isTrue);
    // Moving it back leaves them as they are.
    s = moveCard(s, card.id, column: columns.first.id, index: 0);
    expect(subtasksOf(s, card.id).every((x) => x.flag('done')), isTrue);
  });
}
