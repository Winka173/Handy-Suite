import 'dart:convert';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 7, 9);

BoardsState studyBoard({bool vi = true}) => createFromTemplate(
  BoardsState(),
  templateById('semester')!,
  answers: {'title': vi ? 'Học kỳ 1' : 'Semester 1'},
  vi: vi,
  examples: true,
  now: now,
  boardId: 'b0000000-0000-4000-8000-000000000001',
);

String boardOf(BoardsState s) => s.rows('boards').single.id;

void main() {
  test('a blank board has To Do / Doing / Done and nothing else', () {
    final s = createKanbanBoard(BoardsState(), title: 'Mine', now: now);
    final b = boardOf(s);
    expect(columnsOf(s, b).map((c) => c.str('title')), [
      'To Do',
      'Doing',
      'Done',
    ]);
    expect(columnsOf(s, b).last.flag('done'), isTrue);
    expect(categoriesOf(s, b), isEmpty);
    expect(topTasks(s, board: b), isEmpty);
    final vi = createKanbanBoard(BoardsState(), title: 'Của tôi', vi: true);
    expect(columnsOf(vi, boardOf(vi)).map((c) => c.str('title')), [
      'Cần làm',
      'Đang làm',
      'Xong',
    ]);
  });

  test('the semester template makes subjects as categories', () {
    final s = studyBoard(), b = boardOf(s);
    expect(categoriesOf(s, b).map((c) => c.str('title')), [
      'Lập trình Web',
      'Cơ sở dữ liệu',
      'Tiếng Anh',
      'Toán cao cấp',
    ]);
    final progress = categoryProgress(s, b);
    expect(progress.where((p) => p.category != null), hasLength(4));
    expect(
      progress.fold<int>(0, (n, p) => n + p.total),
      topTasks(s, board: b).length,
    );
    expect(boardSummary(s, b, now: now).categories, 4);
  });

  test('moving a card to Done keeps its category and subtasks', () {
    var s = studyBoard();
    final b = boardOf(s), done = columnsOf(s, b).last.id;
    final card = topTasks(
      s,
      board: b,
    ).firstWhere((t) => t.data['category'] != null && t.str('status') != done);
    final before = subtaskProgress(s, card.id);
    s = moveCard(s, card.id, column: done, index: 0, now: now);
    final moved = s.get('tasks', card.id);
    expect(moved.str('status'), done);
    expect(moved.str('category'), card.str('category'));
    expect(subtaskProgress(s, card.id), before);
    expect(cardsIn(s, done).first.id, card.id);
    expect(moved.data['completedAt'], isNotNull);
  });

  test('reordering inside a column is stable', () {
    var s = createKanbanBoard(BoardsState(), title: 'X', now: now);
    final b = boardOf(s), todo = columnsOf(s, b).first.id;
    for (final title in ['a', 'b', 'c'])
      s = saveTask(s, newTask(s, b, title).copy({'status': todo}), now: now);
    s = moveCard(s, cardsIn(s, todo).last.id, column: todo, index: 0);
    expect(cardsIn(s, todo).map((t) => t.str('title')), ['c', 'a', 'b']);
  });

  test('ticking a subtask never moves the card', () {
    var s = studyBoard();
    final b = boardOf(s);
    final card = topTasks(
      s,
      board: b,
    ).firstWhere((t) => s.related('checklist', t.id).isNotEmpty);
    for (final c in subtasksOf(s, card.id))
      s = toggleChecklist(s, c.id, true, now: now);
    expect(s.get('tasks', card.id).str('status'), card.str('status'));
    final p = subtaskProgress(s, card.id);
    expect(p.done, p.total);
  });

  test('a duplicated card sits under the original with unticked subtasks', () {
    var s = studyBoard();
    final b = boardOf(s);
    final card = topTasks(
      s,
      board: b,
    ).firstWhere((t) => subtaskProgress(s, t.id).done > 0);
    s = duplicateCard(s, card.id, now: now);
    final column = cardsIn(s, card.str('status'));
    final at = column.indexWhere((c) => c.id == card.id);
    final copy = column[at + 1];
    expect(copy.id, isNot(card.id));
    expect(copy.str('title'), card.str('title'));
    expect(copy.str('category'), card.str('category'));
    expect(subtaskProgress(s, copy.id).done, 0);
    expect(
      subtaskProgress(s, copy.id).total,
      subtaskProgress(s, card.id).total,
    );
  });

  test('a duplicated board copies columns, categories and cards with new '
      'ids', () {
    var s = studyBoard();
    final b = boardOf(s);
    s = duplicateBoard(s, b, title: 'Học kỳ 2', now: now);
    final copy = s.rows('boards').firstWhere((x) => x.id != b).id;
    expect(columnsOf(s, copy), hasLength(columnsOf(s, b).length));
    expect(categoriesOf(s, copy), hasLength(4));
    expect(topTasks(s, board: copy), hasLength(topTasks(s, board: b).length));
    final ids = {for (final k in kinds) ...s.rows(k).map((r) => r.id)};
    expect(ids.length, kinds.fold<int>(0, (n, k) => n + s.rows(k).length));
    final copyColumns = columnsOf(s, copy).map((c) => c.id).toSet();
    for (final t in topTasks(s, board: copy))
      expect(copyColumns, contains(t.str('status')));
  });

  test('deleting a category keeps its cards', () {
    var s = studyBoard();
    final b = boardOf(s), maths = categoriesOf(s, b).first;
    final cards = topTasks(
      s,
      board: b,
    ).where((t) => t.str('category') == maths.id).map((t) => t.id).toSet();
    expect(cards, isNotEmpty);
    s = deleteCategory(s, maths.id);
    for (final id in cards) expect(s.get('tasks', id).data['category'], isNull);
    final last = categoryProgress(s, b).last;
    expect(last.category, isNull);
    expect(last.total, greaterThanOrEqualTo(cards.length));
  });

  test('a column with cards only goes once its cards have somewhere to go', () {
    var s = studyBoard();
    final b = boardOf(s), cols = columnsOf(s, b);
    final busy = cols.firstWhere((c) => cardsIn(s, c.id).isNotEmpty);
    expect(() => deleteColumn(s, busy.id), throwsFormatException);
    final target = cols.firstWhere((c) => c.id != busy.id);
    final count = cardsIn(s, busy.id).length + cardsIn(s, target.id).length;
    s = deleteColumn(s, busy.id, moveTo: target.id);
    expect(cardsIn(s, target.id), hasLength(count));
    var one = createKanbanBoard(BoardsState(), title: 'One');
    final ob = boardOf(one);
    one = deleteColumn(one, columnsOf(one, ob)[0].id);
    one = deleteColumn(one, columnsOf(one, ob)[0].id);
    expect(
      () => deleteColumn(one, columnsOf(one, ob)[0].id),
      throwsFormatException,
    );
  });

  test('covers: art, colour or none; nonsense is refused', () {
    var s = studyBoard();
    final card = topTasks(s).first.id;
    s = setCardCover(s, card, art: 'study.notebook-grid');
    expect(s.get('tasks', card).str('cover'), 'art:study.notebook-grid');
    s = setCardCover(s, card, color: 3);
    expect(s.get('tasks', card).str('cover'), 'color:3');
    s = setCardCover(s, card);
    expect(s.get('tasks', card).data['cover'], isNull);
    expect(
      () => s
          .put('tasks', s.get('tasks', card).copy({'cover': 'http://x'}))
          .validate(),
      throwsFormatException,
    );
    expect(
      () => s
          .put('tasks', s.get('tasks', card).copy({'coverPhoto': 'nope'}))
          .validate(),
      throwsA(anything),
    );
  });

  test('deleting a board removes only that board', () {
    var s = studyBoard();
    s = createKanbanBoard(s, title: 'Other', now: now);
    final study = s
        .rows('boards')
        .firstWhere((b) => b.str('title') == 'Học kỳ 1');
    expect(
      () => deleteBoard(s, study.id, confirmed: false),
      throwsFormatException,
    );
    s = deleteBoard(s, study.id, confirmed: true);
    expect(s.rows('boards').single.str('title'), 'Other');
    expect(s.rows('tasks').where((t) => t.str('board') == study.id), isEmpty);
    expect(s.rows('checklist'), isEmpty);
  });

  test('nested tasks become subtasks of their card; nothing is lost', () {
    var s = createKanbanBoard(BoardsState(), title: 'Old', now: now);
    final b = boardOf(s), done = columnsOf(s, b).last.id;
    final parent = newTask(s, b, 'Parent');
    s = saveTask(s, parent, now: now);
    final child = newTask(s, b, 'Child', parent: parent.id);
    s = saveTask(s, child.copy({'status': done}), now: now);
    final grandchild = newTask(s, b, 'Grandchild', parent: child.id);
    s = saveTask(s, grandchild, now: now);
    final next = kanbanize(s, now: now);
    expect(
      subtasksOf(next, parent.id).map((c) => (c.str('title'), c.flag('done'))),
      [('Child', true), ('Grandchild', false)],
    );
    expect(next.get('tasks', child.id).flag('archived'), isTrue);
    expect(next.get('tasks', child.id).data['mergedInto'], isNotNull);
    expect(identical(kanbanize(next), next), isTrue);
  });

  test('schema 4 round-trips covers and looks; schema 2 still opens', () {
    var s = studyBoard();
    final b = boardOf(s);
    s = setBoardLook(s, b, presentation: 'detailed', pinned: true);
    s = setCardCover(s, topTasks(s).first.id, color: 2);
    final json = jsonDecode(jsonEncode(s.toJson()));
    expect(json['schema'], 4);
    final back = BoardsState.fromJson(json);
    expect(back.get('boards', b).str('presentation'), 'detailed');
    expect(back.get('boards', b).flag('pinned'), isTrue);
    expect(back.get('tasks', topTasks(s).first.id).str('cover'), 'color:2');
    final old = jsonDecode(
      jsonEncode(createKanbanBoard(BoardsState(), title: 'v2').toJson()),
    )..['schema'] = 2;
    expect(BoardsState.fromJson(old).rows('boards'), hasLength(1));
    final zip = exportBackup(s);
    expect(
      readBackup(zip).get('boards', b).str('cover'),
      s.get('boards', b).str('cover'),
    );
  });

  test('home lists pinned boards first, then the latest changed', () {
    var s = createKanbanBoard(BoardsState(), title: 'A', now: now);
    s = createKanbanBoard(
      s,
      title: 'B',
      now: now.add(const Duration(hours: 1)),
    );
    s = createKanbanBoard(
      s,
      title: 'C',
      now: now.add(const Duration(hours: 2)),
    );
    expect(homeBoards(s).map((b) => b.str('title')), ['C', 'B', 'A']);
    final a = s.rows('boards').firstWhere((b) => b.str('title') == 'A').id;
    s = setBoardLook(s, a, pinned: true, now: now);
    expect(homeBoards(s).first.str('title'), 'A');
  });

  test('automations do nothing until turned on, then act as named', () {
    var s = studyBoard();
    final b = boardOf(s), done = columnsOf(s, b).last.id;
    final card = topTasks(s, board: b).firstWhere(
      (t) => s.related('checklist', t.id).isNotEmpty && t.str('status') != done,
    );
    for (final c in subtasksOf(s, card.id))
      s = toggleChecklist(s, c.id, true, now: now);
    expect(identical(finishWhenSubtasksDone(s, card.id), s), isTrue);
    s = s.copy(
      preferences: {
        ...s.preferences,
        'automation': {'subtasksDone': true, 'archiveDone': true},
      },
    );
    s = finishWhenSubtasksDone(s, card.id, now: now);
    expect(s.get('tasks', card.id).str('status'), done);
    expect(s.get('tasks', card.id).str('category'), card.str('category'));
    s = archiveFinished(s, now: now.add(const Duration(days: 15)));
    expect(s.get('tasks', card.id).flag('archived'), isTrue);
    expect(s.get('tasks', card.id).flag('trashed'), isFalse);
  });

  test('a repeating card comes back once, a period later, unticked', () {
    var s = studyBoard(vi: false);
    final b = boardOf(s),
        done = columnsOf(s, b).last.id,
        todo = columnsOf(s, b).first.id;
    final card = topTasks(s, board: b).firstWhere(
      (t) => s.related('checklist', t.id).isNotEmpty && t.str('status') != done,
    );
    s = s.put(
      'tasks',
      s.get('tasks', card.id).copy({
        'repeat': 'monthly',
        'due': {'kind': 'day', 'day': '2026-01-31'},
      }),
    );
    for (final c in subtasksOf(s, card.id)) s = toggleChecklist(s, c.id, true);
    s = moveCard(s, card.id, column: done, index: 0, now: now);
    final next = s.get('tasks', s.get('tasks', card.id).str('repeatedAs'));
    expect(next.str('status'), todo);
    expect(next.str('title'), card.str('title'));
    expect(next.str('category'), card.str('category'));
    expect(next.data['due'], {'kind': 'day', 'day': '2026-02-28'});
    expect(next.str('repeat'), 'monthly');
    expect(subtaskProgress(s, next.id).done, 0);
    expect(cardsIn(s, todo).first.id, next.id);
    // Back and forth: no second copy.
    final count = topTasks(s, board: b).length;
    s = moveCard(s, card.id, column: todo, index: 0);
    s = moveCard(s, card.id, column: done, index: 0);
    expect(topTasks(s, board: b), hasLength(count));
    expect(
      () => s
          .put('tasks', s.get('tasks', card.id).copy({'repeat': 'hourly'}))
          .validate(),
      throwsFormatException,
    );
  });

  test('a due day set from the week view, and taken off', () {
    var s = studyBoard(vi: false);
    final card = topTasks(s).first.id;
    s = setDueDay(s, card, DateTime(2026, 11, 13));
    expect(dueDay(s.get('tasks', card)), DateTime(2026, 11, 13));
    s = setDueDay(s, card, null);
    expect(dueDay(s.get('tasks', card)), isNull);
    s = setBoardLook(
      s,
      boardOf(s),
      view: 'time',
      span: {'unit': 'week', 'count': 2},
    );
    expect(s.get('boards', boardOf(s)).str('view'), 'time');
    expect(s.get('boards', boardOf(s)).data['span'], {
      'unit': 'week',
      'count': 2,
    });
    expect(
      () => s
          .put(
            'boards',
            s.get('boards', boardOf(s)).copy({
              'span': {'unit': 'year', 'count': 1},
            }),
          )
          .validate(),
      throwsFormatException,
    );
    expect(
      () => s
          .put('boards', s.get('boards', boardOf(s)).copy({'view': 'gantt'}))
          .validate(),
      throwsFormatException,
    );
  });
}
