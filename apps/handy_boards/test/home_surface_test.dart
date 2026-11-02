import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/platform/home_surface.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  test(
    'home widget is private by default and respects board-local due days',
    () {
      var s = createBoard(BoardsState(), 'Board', boardId: 'b');
      s = s.put(
        'boards',
        s.get('boards', 'b').copy({'zone': 'America/Los_Angeles'}),
      );
      s = saveTask(
        s,
        newTask(s, 'b', 'Private title').copy({
          'id': 'due',
          'due': {'kind': 'day', 'day': '2026-11-01'},
        }),
      );
      s = saveTask(
        s,
        newTask(s, 'b', 'Tomorrow title').copy({
          'id': 'future',
          'due': {'kind': 'day', 'day': '2026-11-02'},
        }),
      );
      final now = DateTime.utc(2026, 11, 2, 1);
      expect(boardsHomeView(s, now, vi: true).rows, isEmpty);
      s = s.copy(preferences: {'homeWidget': true});
      final view = boardsHomeView(s, now, vi: true);
      expect(view.rows.single.$1, 'Private title');
      expect(view.rows.single.$2, 'handy-boards://task?id=due');
      s = trashTasks(s, {'due'}, now: now);
      expect(boardsHomeView(s, now, vi: false).rows, isEmpty);
      final incoming = restoreBackup(
        s,
        readBackup(exportBackup(s)),
        replace: true,
        confirmed: true,
      );
      expect(incoming.preferences['homeWidget'], false);
    },
  );
}
