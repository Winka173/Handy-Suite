import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

const a = 'b0000000-0000-4000-8000-00000000000a';
DateTime day(int d, [int h = 9]) => DateTime(2026, 11, d, h);

void main() {
  test('one picture a day, compared and cloned without touching the board', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('project')!,
      answers: {'title': 'Launch'},
      now: day(1),
      boardId: a,
    );
    final cols = columnsOf(s, a);
    final t1 = newTask(s, a, 'Write copy');
    s = saveTask(s, t1, now: day(1));
    final t2 = newTask(s, a, 'Old idea');
    s = saveTask(s, t2, now: day(1));
    s = captureSnapshots(s, day(1));
    expect(snapshotsOf(s, a), hasLength(1));
    // The same day again: nothing new.
    expect(captureSnapshots(s, day(1, 18)), same(s));
    // Next day: moves, a finish, a new card, a deletion.
    s = moveCard(s, t1.id, column: cols.last.id, index: 0, now: day(2));
    s = trashTasks(s, {t2.id}, now: day(2));
    final t3 = newTask(s, a, 'Press kit');
    s = saveTask(s, t3, now: day(2));
    s = captureSnapshots(s, day(2));
    final [newer, older] = snapshotsOf(s, a);
    final d = compareSnapshots(older, newer);
    expect(d.added, {t3.id});
    expect(d.gone, {t2.id});
    expect(d.finished, {t1.id});
    expect(d.moved, {t1.id});
    // A new board from yesterday's picture; the live one stays as it is.
    final before = topTasks(s, board: a).map((t) => t.id).toSet();
    s = boardFromSnapshot(s, older, 'Launch (1 Nov)', now: day(2));
    expect(topTasks(s, board: a).map((t) => t.id).toSet(), before);
    final copy = homeBoards(s).firstWhere((b) => b.id != a);
    expect(
      topTasks(s, board: copy.id).map((t) => t.str('title')),
      unorderedEquals(['Write copy', 'Old idea']),
    );
    expect(
      topTasks(s, board: copy.id).map((t) => t.id).toSet().intersection(before),
      isEmpty,
    );
    // Snapshots go with backups.
    expect(snapshotsOf(readBackup(exportBackup(s)), a), hasLength(2));
  });

  test('pruning keeps 30 days, then Mondays for a year', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('project')!,
      answers: {'title': 'P'},
      now: DateTime(2026, 1, 1),
      boardId: a,
    );
    var d = DateTime(2026, 1, 1, 9);
    for (var i = 0; i < 120; i++) {
      s = captureSnapshots(s, d);
      d = DateTime(d.year, d.month, d.day + 1, 9);
    }
    final list = snapshotsOf(s, a);
    final last = DateTime(2026, 4, 30);
    for (final r in list) {
      final at = DateTime.parse(r.str('at')).toLocal();
      final age = daysBetween(DateTime(at.year, at.month, at.day), last);
      expect(age <= 30 || at.weekday == DateTime.monday, isTrue, reason: '$at');
    }
    expect(list.length, lessThan(50));
  });
}
