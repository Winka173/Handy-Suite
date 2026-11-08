part of '../handy_boards_engine.dart';

// Board snapshots (browsing them is Pro): what a whole board looked like
// when the app was first opened on a day. Each is a compact copy of the
// board's columns, categories and card places, taken by the device, never
// reconstructed from guesses: before the first snapshot there is simply no
// picture. They live in the `templates` kind (`kind: 'snapshot'`) so they
// go with backups and leave with their board. Kept: every day for 30 days,
// then one a week (the Monday one) for a year; older ones are pruned as
// new ones arrive, which the History sheet says plainly.

const snapshotSchema = 1;

List<BoardRecord> snapshotsOf(BoardsState s, String board) =>
    s
        .rows('templates')
        .where((r) => r.str('kind') == 'snapshot' && r.str('board') == board)
        .toList()
      ..sort((a, b) => b.str('at').compareTo(a.str('at')));

/// The compact picture of [board] now.
BoardRecord snapshotOf(BoardsState s, String board, DateTime now) {
  final b = s.get('boards', board);
  return BoardRecord({
    'id': newId(),
    'kind': 'snapshot',
    'board': board,
    'schema': snapshotSchema,
    'at': now.toUtc().toIso8601String(),
    'title': b.str('title'),
    'columns': [
      for (final c in columnsOf(s, board))
        {'id': c.id, 'title': c.str('title'), 'done': c.flag('done')},
    ],
    'categories': [
      for (final c in categoriesOf(s, board))
        {'id': c.id, 'title': c.str('title')},
    ],
    'cards': [
      for (final t in topTasks(s, board: board))
        {
          'id': t.id,
          'title': t.str('title'),
          'status': t.str('status'),
          'order': t.number('order'),
          'category': t.data['category'],
          'scheduled': t.data['scheduled'],
          'due': _dueText(t.data['due']),
        },
    ],
  });
}

/// Once a day per board: the picture as the app finds it on the first
/// start or return of the day, then pruning. Unchanged state when every
/// board already has today's picture.
BoardsState captureSnapshots(BoardsState s, DateTime now) {
  final today = isoDay(calendarDay(now));
  BoardsEdit? e;
  for (final b in homeBoards(s)) {
    final list = snapshotsOf(s, b.id);
    final last = list.firstOrNull;
    if (last != null &&
        isoDay(DateTime.parse(last.str('at')).toLocal()) == today) {
      continue;
    }
    e ??= BoardsEdit(s);
    e.put('templates', snapshotOf(s, b.id, now));
    // Prune: every day for 30 days, Mondays for a year.
    for (final old in list) {
      final at = calendarDay(DateTime.parse(old.str('at')).toLocal());
      final age = daysBetween(at, calendarDay(now));
      if (age > 30 && (at.weekday != DateTime.monday || age > 366)) {
        e.remove('templates', old.id);
      }
    }
  }
  return e?.finish() ?? s;
}

/// How [later] differs from [earlier] (both snapshots, or a snapshot and
/// the board now via [snapshotOf]): cards added, gone, moved between
/// columns, and finished.
({Set<String> added, Set<String> gone, Set<String> moved, Set<String> finished})
compareSnapshots(BoardRecord earlier, BoardRecord later) {
  Map<String, Map> cards(BoardRecord r) => {
    for (final c in (r.data['cards'] as List)) '${(c as Map)['id']}': c,
  };
  Set<String> doneColumns(BoardRecord r) => {
    for (final c in (r.data['columns'] as List))
      if ((c as Map)['done'] == true) '${c['id']}',
  };
  final a = cards(earlier), b = cards(later);
  final doneA = doneColumns(earlier), doneB = doneColumns(later);
  return (
    added: b.keys.toSet().difference(a.keys.toSet()),
    gone: a.keys.toSet().difference(b.keys.toSet()),
    moved: {
      for (final id in a.keys)
        if (b[id] != null && b[id]!['status'] != a[id]!['status']) id,
    },
    finished: {
      for (final id in a.keys)
        if (b[id] != null &&
            !doneA.contains('${a[id]!['status']}') &&
            doneB.contains('${b[id]!['status']}'))
          id,
    },
  );
}

/// A NEW board from a snapshot: its columns, categories and cards (titles,
/// places, categories, dates) with fresh ids. The live board is untouched.
BoardsState boardFromSnapshot(
  BoardsState s,
  BoardRecord snap,
  String title, {
  DateTime? now,
}) {
  final columns = [
    for (final c in (snap.data['columns'] as List))
      ('${(c as Map)['title']}', c['done'] == true),
  ];
  final cats = [
    for (final c in (snap.data['categories'] as List)) '${(c as Map)['title']}',
  ];
  final plan = BoardPlan(
    title: title,
    template: 'blank',
    templateVersion: 1,
    columns: columns.isEmpty ? [('To Do', false), ('Done', true)] : columns,
    categories: [for (var i = 0; i < cats.length; i++) (cats[i], i % 8)],
    time: const TimePreset('week', pinned: false),
  );
  final id = newId();
  var next = buildBoard(s, plan, now: now, boardId: id);
  final newCols = columnsOf(next, id), newCats = categoriesOf(next, id);
  final colIndex = {
    for (final (i, c) in (snap.data['columns'] as List).indexed)
      '${(c as Map)['id']}': i,
  };
  final catIndex = {
    for (final (i, c) in (snap.data['categories'] as List).indexed)
      '${(c as Map)['id']}': i,
  };
  final e = BoardsEdit(next);
  for (final raw in (snap.data['cards'] as List)) {
    final c = raw as Map;
    final col = colIndex['${c['status']}'] ?? 0;
    final cat = catIndex['${c['category']}'];
    e.put(
      'tasks',
      newTask(
        next,
        id,
        '${c['title']}',
        category: cat == null ? null : newCats[cat].id,
      ).copy({
        'status': newCols[col.clamp(0, newCols.length - 1)].id,
        'order': c['order'] is int ? c['order'] : 0,
        'created': _now(now),
        'updated': _now(now),
        if (c['scheduled'] is String) 'scheduled': c['scheduled'],
        if (c['due'] is String) 'due': {'kind': 'day', 'day': c['due']},
      }),
    );
  }
  return e.finish();
}
