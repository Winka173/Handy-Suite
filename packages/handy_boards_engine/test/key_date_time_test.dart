import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  test('a key date keeps its time; one without stays a whole day', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('semester')!,
      answers: {'title': 'Semester 1'},
      now: DateTime(2026, 11, 9),
    );
    final board = s.rows('boards').single.id;
    s = setMilestones(s, board, [
      (label: 'Exam', day: DateTime(2026, 12, 3), minute: 8 * 60 + 30),
      (label: 'Break', day: DateTime(2026, 12, 20), minute: null),
    ]);
    final back = milestonesOf(s.get('boards', board));
    expect(back.first.minute, 510);
    expect(back.last.minute, isNull);
    expect(s.get('boards', board).data['milestones'][0]['time'], '08:30');
    expect(
      () => setMilestones(s, board, [
        (label: 'Bad', day: DateTime(2026, 12, 3), minute: 24 * 60),
      ]),
      throwsFormatException,
    );
  });
}
