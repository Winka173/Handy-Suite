import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

BoardsState fixture({String title = 'Semester 1'}) {
  final s = createKanbanBoard(
    BoardsState(),
    title: title,
    preset: presetById('study'),
    boardId: 'b',
  );
  // These tests supply their own cards; keep the preset's columns/categories.
  return s
      .remove('checklist', s.rows('checklist').map((r) => r.id).toSet())
      .remove('tasks', s.rows('tasks').map((r) => r.id).toSet());
}

BoardsState withTask(BoardsState s, {String id = 't', String? parent}) =>
    saveTask(
      s,
      newTask(
        s,
        'b',
        'Bài tập toán',
        category: s.rows('categories').first.id,
        parent: parent,
      ).copy({'id': id}),
    );
void main() {
  test(
    'four categories and category/status independence across canonical views',
    () {
      var s = withTask(fixture());
      expect(s.rows('categories').length, 4);
      final category = s.get('tasks', 't').str('category');
      final doing = s
          .rows('statuses')
          .firstWhere((r) => r.str('title') == 'Doing');
      s = changeStatus(s, 't', doing.id);
      expect(s.get('tasks', 't').str('category'), category);
      expect(changeStatus(s, 't', doing.id), same(s));
      expect(queryTasks(s).single.id, 't');
    },
  );
  test('a blank Kanban board never creates hidden example tasks', () {
    final s = createKanbanBoard(BoardsState(), title: 'Life');
    expect(s.rows('tasks'), isEmpty);
    expect(s.rows('subjects'), isEmpty);
    expect(s.rows('categories'), isEmpty);
  });
  test('subtask and checklist do not inflate denominator', () {
    var s = withTask(withTask(fixture()), id: 'child', parent: 't');
    s = s.put(
      'checklist',
      BoardRecord({'id': 'check', 'task': 't', 'title': 'Read'}),
    );
    s = toggleChecklist(s, 'check', true);
    expect(boardSummary(s, 'b', now: DateTime.utc(2026)).cards, 1);
    expect(s.get('checklist', 'check').data['completedAt'], isNotNull);
  });
  test('dependency and parent cycles rejected without altering input', () {
    var s = withTask(withTask(fixture()), id: 'u');
    s = s.put(
      'dependencies',
      BoardRecord({'id': 'dep', 'before': 't', 'after': 'u'}),
    );
    s.validate();
    expect(
      () => s
          .put(
            'dependencies',
            BoardRecord({'id': 'reverse', 'before': 'u', 'after': 't'}),
          )
          .validate(),
      throwsFormatException,
    );
    expect(s.rows('dependencies').length, 1);
    expect(
      () =>
          s.put('tasks', s.get('tasks', 't').copy({'parent': 't'})).validate(),
      throwsFormatException,
    );
  });

  test('category deletion moves to uncategorized without removing tasks', () {
    final s = withTask(fixture()),
        c = s.get('tasks', 't').str('category'),
        next = deleteCategory(s, c);
    expect(next.get('tasks', 't').data['category'], isNull);
  });
  test('trash restore and confirmed hard delete', () {
    var s = withTask(fixture());
    s = trashTasks(s, {'t'});
    expect(queryTasks(s), isEmpty);
    expect(
      () => permanentlyDelete(s, {'t'}, confirmed: false),
      throwsFormatException,
    );
    s = trashTasks(s, {'t'}, restore: true);
    expect(queryTasks(s).length, 1);
    s = permanentlyDelete(trashTasks(s, {'t'}), {'t'}, confirmed: true);
    expect(s.rows('tasks'), isEmpty);
    expect(s.rows('events'), isEmpty);
  });
  test('Vietnamese accent search and stable category/status filters', () {
    final s = withTask(fixture());
    expect(queryTasks(s, search: 'bai tap toan').single.id, 't');
    expect(queryTasks(s, filter: {'priority': 3}), isEmpty);
  });
  test('strict dates DST gaps and folds require explicit choice', () {
    expect(() => day('2026-02-30'), throwsFormatException);
    expect(
      () => wallTime('2026-03-08', '02:30', 'America/New_York'),
      throwsFormatException,
    );
    expect(
      () => wallTime('2026-11-01', '01:30', 'America/New_York'),
      throwsFormatException,
    );
    expect(
      wallTime('2026-11-01', '01:30', 'America/New_York', lateFold: true)
          .difference(
            wallTime(
              '2026-11-01',
              '01:30',
              'America/New_York',
              lateFold: false,
            ),
          )
          .inHours,
      1,
    );
  });
  test(
    'recurrence generation bounded and idempotent across serialization/restart',
    () {
      var s = withTask(fixture());
      s = s.put(
        'recurrence',
        BoardRecord({
          'id': 'r',
          'task': 't',
          'board': 'b',
          'frequency': 'daily',
          'start': '2026-11-01',
          'zone': 'Asia/Ho_Chi_Minh',
          'interval': 1,
          'exceptions': ['2026-11-02'],
        }),
      );
      s = generateOccurrences(s, 'r', '2026-11-04');
      expect(s.rows('occurrences').length, 3);
      final restored = BoardsState.fromJson(s.toJson());
      expect(
        generateOccurrences(restored, 'r', '2026-11-04').toJson(),
        restored.toJson(),
      );
      expect(
        () => generateOccurrences(s, 'r', '2038-01-01'),
        throwsFormatException,
      );
    },
  );
  test('legacy grades still validate assessment weights and scores', () {
    final valid = BoardRecord({
      'id': 'g',
      'weight': 50,
      'possible': 10,
      'earned': 2,
    });
    validateGrade(valid);
    for (final changes in [
      {'weight': -1},
      {'possible': 0},
      {'earned': 11},
    ]) {
      expect(() => validateGrade(valid.copy(changes)), throwsFormatException);
    }
  });

  test(
    'JSON ZIP exact round trips, merge remaps references, corruption rejected',
    () {
      final s = withTask(fixture());
      for (final zip in [true, false])
        expect(readBackup(exportBackup(s, zip: zip)).toJson(), s.toJson());
      final merged = restoreBackup(
        s,
        readBackup(exportBackup(s)),
        replace: false,
        confirmed: true,
      );
      expect(merged.rows('tasks').length, 2);
      expect(merged.rows('categories').length, 8);
      merged.validate();
      expect(
        () => readBackup(Uint8List.fromList([80, 75, 1, 2, 3])),
        throwsFormatException,
      );
      expect(
        () => BoardsState.fromJson({...s.toJson(), 'schema': 99}),
        throwsFormatException,
      );
    },
  );
  test('Markdown checkbox import/export and malformed CSV', () {
    var s = fixture();
    s = importLines(s, 'b', '- [ ] Bài tập\n- [x] Đã đọc', markdown: true);
    expect(exportMarkdown(s, 'b'), contains('- [x] Đã đọc'));
    expect(queryTasks(s).length, 2);
    expect(parseCsv('title,notes\r\n"Toán","a,b\nline"')[1], [
      'Toán',
      'a,b\nline',
    ]);
    expect(() => parseCsv('"bad'), throwsFormatException);
  });
}
