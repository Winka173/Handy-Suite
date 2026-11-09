import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  test('a custom span keeps its periods as days go by', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('semester')!,
      answers: {'title': 'Semester 1'},
      now: DateTime(2026, 11, 11),
    );
    final board = s.rows('boards').single.id;
    s = setTimeline(s, board, 'week', count: 2, now: DateTime(2026, 11, 11));
    final b = s.get('boards', board);
    expect(timelineCount(b), 2);
    final w = boardWindow(b, DateTime(2026, 11, 11));
    expect(w.first, DateTime(2026, 11, 9), reason: 'from that Monday');
    expect(w.days, 14);
    // A week later, still the same sprint; the next one after that.
    expect(boardWindow(b, DateTime(2026, 11, 20)), w);
    expect(
      boardWindow(b, DateTime(2026, 11, 23)).first,
      DateTime(2026, 11, 23),
    );
    expect(shiftWindow(boardRange(b), w, 1).first, DateTime(2026, 11, 23));
    // Ten days.
    s = setTimeline(s, board, 'week', now: DateTime(2026, 11, 11));
    expect(timelineCount(s.get('boards', board)), 1);
    expect(s.get('boards', board).data['timelineStart'], isNull);
  });

  test('every N months counts from the month it was set', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('semester')!,
      answers: {'title': 'S'},
      now: DateTime(2026, 11, 11),
    );
    final board = s.rows('boards').single.id;
    s = setTimeline(s, board, 'month', count: 3, now: DateTime(2026, 11, 11));
    final b = s.get('boards', board);
    final w = boardWindow(b, DateTime(2027, 1, 30));
    expect(w.first, DateTime(2026, 11));
    expect(w.end, DateTime(2027, 2));
  });
}
