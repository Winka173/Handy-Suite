import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

BoardsState fixture() =>
    createBoard(BoardsState(), 'Semester 1', template: 'study', boardId: 'b');
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
      expect(queryTasks(s).single.id, 't');
    },
  );
  test(
    'empty board and generic templates never create hidden example tasks',
    () {
      final s = createBoard(BoardsState(), 'Life', template: 'personal');
      expect(s.rows('tasks'), isEmpty);
      expect(s.rows('subjects'), isEmpty);
      expect(
        s.rows('categories').map((r) => r.str('title')),
        containsAll(['Home', 'Health', 'Money', 'Errands']),
      );
    },
  );
  test('subtask and checklist do not inflate denominator', () {
    var s = withTask(withTask(fixture()), id: 'child', parent: 't');
    s = s.put(
      'checklist',
      BoardRecord({'id': 'check', 'task': 't', 'title': 'Read'}),
    );
    s = toggleChecklist(s, 'check', true);
    expect(summary(s, s.rows('tasks'), now: DateTime.utc(2026))['total'], 1);
    expect(s.get('checklist', 'check').data['completedAt'], isNotNull);
  });
  test('dependency and parent cycles rejected without altering input', () {
    var s = withTask(withTask(fixture()), id: 'u');
    s = addDependency(s, 't', 'u');
    expect(() => addDependency(s, 'u', 't'), throwsFormatException);
    expect(s.rows('dependencies').length, 1);
    expect(
      () =>
          s.put('tasks', s.get('tasks', 't').copy({'parent': 't'})).validate(),
      throwsFormatException,
    );
  });
  test(
    'move subtree atomically preserves UUIDs and drops incompatible custom scope',
    () {
      var s = withTask(withTask(fixture()), id: 'child', parent: 't');
      s = createBoard(s, 'Personal', boardId: 'b2', template: 'personal');
      final category = s
          .rows('categories')
          .firstWhere((r) => r.str('board') == 'b2');
      final next = moveTasks(s, {'t'}, 'b2', category: category.id);
      expect(next.get('tasks', 'child').str('board'), 'b2');
      expect(next.get('tasks', 'child').str('parent'), 't');
      expect(s.get('tasks', 't').str('board'), 'b');
    },
  );
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
  test('grade validation and impossible remaining target', () {
    final grades = [
      BoardRecord({'id': 'g', 'weight': 50, 'possible': 10, 'earned': 2}),
      BoardRecord({'id': 'g2', 'weight': 50, 'possible': 10}),
    ];
    final p = gradePlan(grades, target: 90);
    expect(p['requiredPercent'], 160);
    expect(p['feasible'], false);
    expect(() => gradePlan([grades.first], target: 50), throwsFormatException);
    expect(
      () =>
          validateGrade(BoardRecord({'id': 'x', 'weight': -1, 'possible': 10})),
      throwsFormatException,
    );
  });
  test(
    'critical path uses explicit durations and returns warning if unknown',
    () {
      var s = withTask(withTask(fixture()), id: 'u');
      expect(criticalPath(s, 'b')['valid'], false);
      s = s
          .put('tasks', s.get('tasks', 't').copy({'estimate': 30}))
          .put('tasks', s.get('tasks', 'u').copy({'estimate': 40}));
      s = addDependency(s, 't', 'u');
      expect(criticalPath(s, 'b')['minutes'], 70);
    },
  );
  test(
    'focus timestamps survive restart; pause/resume do not double count',
    () {
      var s = startFocus(withTask(fixture()), 't', DateTime.utc(2026, 1, 1));
      final id = s.rows('sessions').single.id;
      s = pauseFocus(
        BoardsState.fromJson(s.toJson()),
        id,
        DateTime.utc(2026, 1, 1, 0, 2),
      );
      expect(s.get('sessions', id).number('elapsed'), 120);
      s = pauseFocus(s, id, DateTime.utc(2026, 1, 1, 0, 3));
      expect(s.get('sessions', id).number('elapsed'), 120);
      s = resumeFocus(s, id, DateTime.utc(2026, 1, 1, 0, 4));
      s = pauseFocus(s, id, DateTime.utc(2026, 1, 1, 0, 5));
      expect(s.get('sessions', id).number('elapsed'), 180);
    },
  );
  test('automation exactly once per event and no recursive execution', () {
    var s = withTask(fixture());
    s = s.put(
      'rules',
      BoardRecord({
        'id': 'r',
        'board': 'b',
        'trigger': 'created',
        'enabled': true,
        'actions': [
          {'type': 'priority', 'value': 3},
          {'type': 'checklist', 'value': 'Review'},
        ],
      }),
    );
    s = runAutomations(s, 't', 'created', 'event1', now: DateTime.utc(2026));
    expect(s.get('tasks', 't').number('priority'), 3);
    expect(s.rows('checklist').length, 1);
    s = runAutomations(s, 't', 'created', 'event1', now: DateTime.utc(2026));
    expect(s.rows('checklist').length, 1);
    expect(s.rows('executions').length, 1);
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
