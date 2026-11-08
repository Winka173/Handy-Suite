part of '../handy_boards_engine.dart';

/// Kanban vocabulary over the stored records: a board's columns are its
/// `statuses`, a card is a top-level task, a card's subtasks are its
/// `checklist` rows (one level only), and categories stay independent of
/// columns. Nothing here moves a card between columns on its own.

/// A card's cover: a built-in art id, one of the eight identity hues, or a
/// photo the person chose (an attachment of the card, see [setCardCover]).
final _coverValue = RegExp(r'^(art:[a-z0-9][a-z0-9.-]{0,79}|color:[0-7])$');

/// The board's columns, left to right.
List<BoardRecord> columnsOf(BoardsState s, String board) =>
    s.rows('statuses').where((c) => c.str('board') == board).toList()
      ..sort((a, b) => a.number('order').compareTo(b.number('order')));

/// The board's categories, in the person's order.
List<BoardRecord> categoriesOf(BoardsState s, String board) =>
    s.rows('categories').where((c) => c.str('board') == board).toList()
      ..sort((a, b) => a.number('order').compareTo(b.number('order')));

/// Active cards of one column, top to bottom.
List<BoardRecord> cardsIn(BoardsState s, String column) {
  final board = s.get('statuses', column).str('board');
  return topTasks(
    s,
    board: board,
  ).where((t) => t.str('status') == column).toList()..sort((a, b) {
    final by = a.number('order').compareTo(b.number('order'));
    return by != 0 ? by : a.str('created').compareTo(b.str('created'));
  });
}

/// A card's subtasks, in order.
List<BoardRecord> subtasksOf(BoardsState s, String card) =>
    s.related('checklist', card).toList()
      ..sort((a, b) => a.number('order').compareTo(b.number('order')));

/// Ticked and total subtasks of a card.
({int done, int total}) subtaskProgress(BoardsState s, String card) {
  final items = s.related('checklist', card);
  return (done: items.where((c) => c.flag('done')).length, total: items.length);
}

/// The figures a board shows on its card at home and in its header.
class BoardSummary {
  final int categories, cards, done, dueToday, overdue;
  final DateTime? updated;
  const BoardSummary({
    required this.categories,
    required this.cards,
    required this.done,
    required this.dueToday,
    required this.overdue,
    this.updated,
  });
}

/// The calendar day a card is due (in the device's day for a timed one),
/// or null.
DateTime? dueDay(BoardRecord card) {
  final due = card.data['due'];
  if (due is! Map) return null;
  if (due['kind'] == 'day') {
    final d = DateTime.tryParse('${due['day']}');
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }
  final at = DateTime.tryParse('${due['at']}')?.toLocal();
  return at == null ? null : DateTime(at.year, at.month, at.day);
}

BoardSummary boardSummary(BoardsState s, String board, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  var cards = 0, done = 0, dueToday = 0, overdue = 0;
  final columns = {for (final c in columnsOf(s, board)) c.id: c.flag('done')};
  for (final t in topTasks(s, board: board)) {
    cards++;
    final finished = columns[t.str('status')] ?? false;
    if (finished) {
      done++;
      continue;
    }
    final d = dueDay(t);
    if (d == null) continue;
    if (d == day) dueToday++;
    if (d.isBefore(day)) overdue++;
  }
  final b = s.get('boards', board);
  return BoardSummary(
    categories: categoriesOf(s, board).length,
    cards: cards,
    done: done,
    dueToday: dueToday,
    overdue: overdue,
    updated: DateTime.tryParse(b.str('updated')),
  );
}

/// One block of the category strip: a category (null = Uncategorised) and
/// how many of its cards are in a done column.
class CategoryProgress {
  final BoardRecord? category;
  final int done, total;
  const CategoryProgress(this.category, this.done, this.total);
}

/// Every category of the board in order, then Uncategorised when any card
/// has none. Counts cover every column: a category keeps its cards
/// wherever they are.
List<CategoryProgress> categoryProgress(BoardsState s, String board) {
  final done = {for (final c in columnsOf(s, board)) c.id: c.flag('done')};
  final totals = <String?, int>{}, finished = <String?, int>{};
  for (final t in topTasks(s, board: board)) {
    final k = t.data['category'] as String?;
    totals[k] = (totals[k] ?? 0) + 1;
    if (done[t.str('status')] ?? false) finished[k] = (finished[k] ?? 0) + 1;
  }
  return [
    for (final c in categoriesOf(s, board))
      CategoryProgress(c, finished[c.id] ?? 0, totals[c.id] ?? 0),
    if ((totals[null] ?? 0) > 0)
      CategoryProgress(null, finished[null] ?? 0, totals[null]!),
  ];
}

/// Boards the person has not archived, pinned first, then the most
/// recently changed.
List<BoardRecord> homeBoards(BoardsState s) =>
    s.rows('boards').where((b) => !b.flag('archived')).toList()..sort((a, b) {
      final pin = (b.flag('pinned') ? 1 : 0) - (a.flag('pinned') ? 1 : 0);
      if (pin != 0) return pin;
      return b.str('updated').compareTo(a.str('updated'));
    });

String _now(DateTime? now) => (now ?? DateTime.now()).toUtc().toIso8601String();

void _touch(BoardsEdit e, String board, DateTime? now) {
  final b = e.data['boards']![board]!;
  e.put('boards', b.copy({'updated': _now(now)}));
}

/// Moves a card to [index] of [column] (on the same board), renumbering the
/// column. Its category, subtasks and cover stay as they are.
BoardsState moveCard(
  BoardsState s,
  String card, {
  required String column,
  required int index,
  DateTime? now,
}) {
  final t = s.get('tasks', card), target = s.get('statuses', column);
  if (target.str('board') != t.str('board'))
    throw const FormatException('Column outside board');
  if (t.data['parent'] != null) throw const FormatException('Not a card');
  var next = t.str('status') == column
      ? s
      : changeStatus(s, card, column, now: now);
  final ordered = cardsIn(next, column).where((c) => c.id != card).toList();
  ordered.insert(index.clamp(0, ordered.length), next.get('tasks', card));
  final e = BoardsEdit(next);
  for (var i = 0; i < ordered.length; i++)
    if (ordered[i].number('order') != i || ordered[i].id == card)
      e.put('tasks', e.data['tasks']![ordered[i].id]!.copy({'order': i}));
  _touch(e, t.str('board'), now);
  final moved = e.finish();
  return t.str('status') != column && target.flag('done')
      ? repeatIfDone(moved, card, now: now)
      : moved;
}

/// A copy of a card just under it: same column, category, note, cover and
/// subtasks (all unticked), new ids. Photos are shared, not copied.
BoardsState duplicateCard(BoardsState s, String card, {DateTime? now}) {
  final t = s.get('tasks', card), at = _now(now), id = newId();
  final e = BoardsEdit(s);
  final ids = <String, String>{};
  for (final a in s.related('attachments', card)) {
    ids[a.id] = newId();
    e.put('attachments', a.copy({'id': ids[a.id], 'task': id}));
  }
  e.put(
    'tasks',
    BoardRecord({
      ...t.toJson(),
      'id': id,
      'created': at,
      'updated': at,
      'completedAt': null,
      'archived': false,
      'trashed': false,
      'trashedAt': null,
      'trashBatch': null,
      'suggestedStatus': null,
      'coverPhoto': ids[t.data['coverPhoto']],
    }),
  );
  for (final c in s.related('checklist', card))
    e.put(
      'checklist',
      c.copy({'id': newId(), 'task': id, 'done': false, 'completedAt': null}),
    );
  e.event(id, 'created', now ?? DateTime.now(), details: {'copyOf': card});
  final copied = e.finish();
  final column = cardsIn(copied, t.str('status'));
  final at0 = column.indexWhere((c) => c.id == card);
  return moveCard(
    copied,
    id,
    column: t.str('status'),
    index: at0 + 1,
    now: now,
  );
}

/// A copy of a whole board: columns, categories and active cards with their
/// subtasks (unticked) and covers, every id new, references kept inside the
/// copy. Archived and trashed cards stay behind.
BoardsState duplicateBoard(
  BoardsState s,
  String board, {
  required String title,
  DateTime? now,
}) {
  text(title, empty: false);
  final b = s.get('boards', board), at = _now(now), e = BoardsEdit(s);
  final ids = <String, String>{board: newId()};
  String map(String id) => ids.putIfAbsent(id, newId);
  e.put(
    'boards',
    b.copy({
      'id': ids[board],
      'title': title.trim(),
      'created': at,
      'updated': at,
      'pinned': false,
      'archived': false,
    }),
  );
  for (final c in columnsOf(s, board))
    e.put('statuses', c.copy({'id': map(c.id), 'board': ids[board]}));
  for (final c in categoriesOf(s, board))
    e.put('categories', c.copy({'id': map(c.id), 'board': ids[board]}));
  for (final t in topTasks(s, board: board)) {
    final id = map(t.id);
    for (final a in s.related('attachments', t.id))
      e.put(
        'attachments',
        a.copy({'id': map(a.id), 'task': id, 'board': ids[board]}),
      );
    final cat = t.data['category'] as String?, photo = t.data['coverPhoto'];
    e.put(
      'tasks',
      BoardRecord({
        ...t.toJson(),
        'id': id,
        'board': ids[board],
        'status': map(t.str('status')),
        'category': cat == null ? null : map(cat),
        'parent': null,
        'created': at,
        'updated': at,
        'completedAt': null,
        'tags': <String>[],
        'custom': <String, dynamic>{},
        'suggestedStatus': null,
        'coverPhoto': photo is String ? ids[photo] : null,
      }),
    );
    for (final c in s.related('checklist', t.id))
      e.put(
        'checklist',
        c.copy({'id': newId(), 'task': id, 'done': false, 'completedAt': null}),
      );
  }
  return e.finish();
}

/// Adds a column at the right end.
BoardsState addColumn(BoardsState s, String board, String title) {
  text(title, empty: false, max: 200);
  s.get('boards', board);
  final columns = columnsOf(s, board);
  return s.put(
    'statuses',
    BoardRecord({
      'id': newId(),
      'board': board,
      'title': title.trim(),
      'order': columns.isEmpty ? 0 : columns.last.number('order') + 1,
      'done': false,
    }),
  );
}

/// Removes a column. Its cards (archived and trashed ones too) move to
/// [moveTo] first; a column that holds cards cannot go without one, and a
/// board keeps at least one column.
BoardsState deleteColumn(BoardsState s, String column, {String? moveTo}) {
  final c = s.get('statuses', column), board = c.str('board');
  if (columnsOf(s, board).length < 2)
    throw const FormatException('A board needs a column');
  final cards = s
      .rows('tasks')
      .where((t) => t.str('status') == column)
      .toList();
  if (cards.isNotEmpty) {
    if (moveTo == null || moveTo == column)
      throw const FormatException('Choose where its cards go');
    if (s.get('statuses', moveTo).str('board') != board)
      throw const FormatException('Column outside board');
  }
  final e = BoardsEdit(s);
  final base = moveTo == null ? 0 : cardsIn(s, moveTo).length;
  for (var i = 0; i < cards.length; i++)
    e.put('tasks', cards[i].copy({'status': moveTo, 'order': base + i}));
  for (final r in s.rows('recurrence').where((r) => r.str('status') == column))
    e.put('recurrence', r.copy({'status': moveTo}));
  for (final t
      in s.rows('tasks').where((t) => t.str('suggestedStatus') == column))
    e.put(
      'tasks',
      (e.data['tasks']![t.id] ?? t).copy({'suggestedStatus': null}),
    );
  e.remove('statuses', column);
  pruneRuleRefs(e, board);
  return e.finish();
}

/// Sets a card's cover: an art id, a colour (0–7), a photo attachment of
/// the card, or none. A previous photo stays attached until the person
/// removes it; it is no longer the cover.
BoardsState setCardCover(
  BoardsState s,
  String card, {
  String? art,
  int? color,
  String? photo,
  DateTime? now,
}) {
  final t = s.get('tasks', card);
  if ([art, color, photo].where((v) => v != null).length > 1)
    throw const FormatException('One cover at a time');
  if (photo != null && s.get('attachments', photo).str('task') != card)
    throw const FormatException('Photo belongs to another card');
  return s.put(
    'tasks',
    t.copy({
      'cover': art != null
          ? 'art:$art'
          : color != null
          ? 'color:$color'
          : null,
      'coverPhoto': photo,
      'updated': _now(now),
    }),
  );
}

/// Board-level look: cover art, compact or detailed cards, pinned.
BoardsState setBoardLook(
  BoardsState s,
  String board, {
  Object? cover = _keep,
  Object? appearance = _keep,
  String? view,
  Json? span,
  String? presentation,
  bool? pinned,
  bool? timePinned,
  DateTime? now,
}) {
  final b = s.get('boards', board);
  return s.put(
    'boards',
    b.copy({
      if (!identical(cover, _keep)) 'cover': cover,
      if (!identical(appearance, _keep)) 'appearance': appearance,
      'view': ?view,
      'span': ?span,
      'presentation': ?presentation,
      'pinned': ?pinned,
      'timePinned': ?timePinned,
      'updated': _now(now),
    }),
  );
}

const _keep = Object();

/// Removes a board and everything that belongs to it. Undo lives in the
/// controller's history; backups keep their own copy.
BoardsState deleteBoard(
  BoardsState s,
  String board, {
  required bool confirmed,
}) {
  if (!confirmed)
    throw const FormatException('Deleting a board needs confirmation');
  s.get('boards', board);
  final tasks = {
    for (final t in s.rows('tasks'))
      if (t.str('board') == board) t.id,
  };
  final owned = {
    board,
    ...tasks,
    for (final k in const [
      'statuses',
      'categories',
      'subjects',
      'classes',
      'grades',
      'views',
      'fields',
      'rules',
      'tags',
    ])
      for (final r in s.rows(k))
        if (r.str('board') == board) r.id,
  };
  final e = BoardsEdit(s);
  for (final k in kinds)
    for (final r in s.rows(k))
      if (owned.contains(r.id) ||
          owned.contains(r.str('board')) ||
          tasks.contains(r.str('task')) ||
          k == 'dependencies' &&
              (tasks.contains(r.str('before')) ||
                  tasks.contains(r.str('after'))))
        e.remove(k, r.id);
  for (final r in s.rows('occurrences'))
    if (!e.data['tasks']!.containsKey(r.str('task')) ||
        !e.data['recurrence']!.containsKey(r.str('rule')))
      e.remove('occurrences', r.id);
  final retained = e.data['attachments']!.values
      .expand((r) => [r.str('path'), r.str('preview')])
      .toSet();
  for (final path in e.files.keys.toList())
    if (!retained.contains(path)) e.removeFile(path);
  return e.finish();
}

/// Makes stored data fit the one-level Kanban: a nested task becomes a
/// subtask (checklist row) of its top-level card, ticked when it was done,
/// and the old task is archived with a pointer to that row, so nothing is
/// lost. Returns [s] itself when nothing needs changing.
BoardsState kanbanize(BoardsState s, {DateTime? now}) {
  final nested = s
      .rows('tasks')
      .where(
        (t) =>
            t.data['parent'] != null &&
            !t.flag('archived') &&
            !t.flag('trashed') &&
            t.data['mergedInto'] == null,
      )
      .toList();
  if (nested.isEmpty) return s;
  final e = BoardsEdit(s), at = _now(now);
  String top(BoardRecord t) {
    var node = t;
    final seen = <String>{};
    while (node.data['parent'] != null && seen.add(node.id))
      node = s.get('tasks', node.str('parent'));
    return node.id;
  }

  final next = <String, int>{};
  for (final t
      in nested
        ..sort((a, b) => a.number('order').compareTo(b.number('order')))) {
    final card = top(t);
    final order = next[card] ??= s.related('checklist', card).length;
    next[card] = order + 1;
    final id = newId(), done = completed(s, t);
    e.put(
      'checklist',
      BoardRecord({
        'id': id,
        'task': card,
        'title': t.str('title'),
        'order': order,
        'done': done,
        if (done) 'completedAt': t.data['completedAt'] ?? at,
      }),
    );
    e.put('tasks', t.copy({'archived': true, 'mergedInto': id, 'updated': at}));
  }
  return e.finish();
}

/// Checks the Kanban fields (called from [BoardsState.validate]).
void validateKanban(BoardsState s) {
  for (final r in s.rows('templates'))
    if (r.str('kind') == 'card') validateCardTemplate(r);
  for (final b in s.rows('boards')) {
    final cover = b.data['cover'];
    if (cover != null &&
        (cover is! String ||
            !RegExp(r'^[a-z0-9][a-z0-9.-]{0,79}$').hasMatch(cover)))
      throw const FormatException('Invalid board cover');
    final look = b.data['presentation'];
    if (look != null && look != 'compact' && look != 'detailed')
      throw const FormatException('Invalid card presentation');
    final pack = b.data['appearance'];
    if (pack != null &&
        (pack is! String || !RegExp(r'^[a-z][a-z-]{0,39}$').hasMatch(pack)))
      throw const FormatException('Invalid board appearance');
    final view = b.data['view'];
    if (view != null && view != 'board' && view != 'time')
      throw const FormatException('Invalid board view');
    final span = b.data['span'];
    if (span != null) {
      final custom = span is Map && span['unit'] == 'custom';
      if (span is! Map ||
          (custom
              ? TimeRange.read(span) == TimeRange.standard
              : (!const {'day', 'week', 'month'}.contains(span['unit']) ||
                    span['count'] is! int ||
                    (span['count'] as int) < 1 ||
                    (span['count'] as int) > 12)))
        throw const FormatException('Invalid time span');
    }
    final template = b.data['template'];
    if (template != null && (template is! String || template.length > 80))
      throw const FormatException('Invalid template id');
    for (final k in ['timeline', 'timelineFloor']) {
      final v = b.data[k];
      if (v != null && !timelineUnits.contains(v))
        throw const FormatException('Invalid timeline');
    }
  }
  for (final t in s.rows('tasks')) {
    final every = t.data['repeatEvery'], left = t.data['repeatLeft'];
    if (every != null && (every is! int || every < 1 || every > 30))
      throw const FormatException('Repeat every 1..30');
    if (left != null && (left is! int || left < 0 || left > 999))
      throw const FormatException('Repeat count 0..999');
    final days = t.data['repeatDays'];
    if (days != null &&
        (days is! List || days.any((d) => d is! int || d < 1 || d > 7)))
      throw const FormatException('Repeat weekdays 1..7');
    if (t.data['repeatUntil'] != null &&
        DateTime.tryParse('${t.data['repeatUntil']}') == null)
      throw const FormatException('Repeat end date');
    final cover = t.data['cover'];
    if (cover != null && (cover is! String || !_coverValue.hasMatch(cover)))
      throw const FormatException('Invalid card cover');
    final photo = t.data['coverPhoto'];
    if (photo != null &&
        (photo is! String || s.get('attachments', photo).str('task') != t.id))
      throw const FormatException('Invalid cover photo');
    final repeat = t.data['repeat'];
    if (repeat != null && !repeatEvery.contains(repeat))
      throw const FormatException('Invalid repeat');
    final next = t.data['repeatedAs'];
    if (next != null && next is! String)
      throw const FormatException('Invalid repeat pointer');
    final merged = t.data['mergedInto'];
    if (merged != null && merged is! String)
      throw const FormatException('Invalid merge pointer');
  }
  validateTemplateFields(s);
}

/// The automation presets the person turned on (Pro), read from
/// preferences: `{'subtasksDone': bool, 'archiveDone': bool}`.
bool automationOn(BoardsState s, String key) {
  final a = s.preferences['automation'];
  return a is Map && a[key] == true;
}

/// Preset "finish a card when its subtasks are done": when every subtask
/// of [card] is ticked, it moves to the board's last finished column.
/// Does nothing unless the preset is on, the card has subtasks, or it is
/// already in a finished column.
BoardsState finishWhenSubtasksDone(
  BoardsState s,
  String card, {
  DateTime? now,
}) {
  if (!automationOn(s, 'subtasksDone')) return s;
  final t = s.maybe('tasks', card);
  if (t == null || t.data['parent'] != null) return s;
  final p = subtaskProgress(s, card);
  if (p.total == 0 || p.done < p.total) return s;
  final columns = columnsOf(s, t.str('board'));
  if (columns.any((c) => c.id == t.str('status') && c.flag('done'))) return s;
  final done = columns.lastWhere(
    (c) => c.flag('done'),
    orElse: () => columns.last,
  );
  if (done.id == t.str('status')) return s;
  return moveCard(s, card, column: done.id, index: 0, now: now);
}

/// Preset "archive finished cards after [days] days": cards in a finished
/// column whose completion is older than that are archived (never
/// deleted; they come back from Settings › Data).
BoardsState archiveFinished(BoardsState s, {int days = 14, DateTime? now}) {
  if (!automationOn(s, 'archiveDone')) return s;
  final limit = (now ?? DateTime.now()).toUtc().subtract(Duration(days: days));
  final finished = {
    for (final c in s.rows('statuses'))
      if (c.flag('done')) c.id,
  };
  final old = topTasks(s).where((t) {
    if (!finished.contains(t.str('status'))) return false;
    final at = DateTime.tryParse(t.str('completedAt'));
    return at != null && at.isBefore(limit);
  }).toList();
  if (old.isEmpty) return s;
  final e = BoardsEdit(s);
  for (final t in old)
    e.put('tasks', t.copy({'archived': true, 'updated': _now(now)}));
  return e.finish();
}

/// How often a repeating card comes back.
const repeatEvery = {'daily', 'weekly', 'monthly'};

/// The next day of a repeat with its options: every [n] periods, and for
/// weekly repeats only on [days] (1 = Monday ... 7 = Sunday) when given.
DateTime nextRepeatDay(
  DateTime d,
  String every, {
  int n = 1,
  List<int> days = const [],
}) {
  if (every == 'weekly' && days.isNotEmpty) {
    final chosen = days.toSet();
    // Later in the same week (Monday to Sunday)...
    for (var w = d.weekday + 1; w <= 7; w++) {
      if (chosen.contains(w))
        return DateTime(d.year, d.month, d.day + w - d.weekday);
    }
    // ...else the first chosen day of the week n weeks on.
    final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1) + 7 * n);
    for (var w = 1; w <= 7; w++) {
      if (chosen.contains(w))
        return DateTime(monday.year, monday.month, monday.day + w - 1);
    }
  }
  var next = d;
  for (var i = 0; i < n; i++) next = _nextDay(next, every);
  return next;
}

DateTime _nextDay(DateTime d, String every) => switch (every) {
  'daily' => DateTime(d.year, d.month, d.day + 1),
  'weekly' => DateTime(d.year, d.month, d.day + 7),
  // The same day next month, or its last day when that month is shorter.
  _ => DateTime(
    d.year,
    d.month + 1,
    d.day.clamp(1, DateTime(d.year, d.month + 2, 0).day),
  ),
};

/// A repeating card that reached a finished column makes its next time: a
/// copy at the top of the first unfinished column, subtasks unticked, the
/// due day one period later (no due day stays none). Each card makes its
/// next one once, so moving it back and forth never multiplies it.
BoardsState repeatIfDone(BoardsState s, String card, {DateTime? now}) {
  final t = s.maybe('tasks', card);
  final every = t?.data['repeat'] as String?;
  if (t == null || every == null || t.data['repeatedAs'] != null) return s;
  final columns = columnsOf(s, t.str('board'));
  if (!columns.any((c) => c.id == t.str('status') && c.flag('done'))) return s;
  final first = columns.firstWhere(
    (c) => !c.flag('done'),
    orElse: () => columns.first,
  );
  final id = newId(), at = _now(now), e = BoardsEdit(s);
  final due = dueDay(t);
  // Pro options: every n periods, chosen weekdays, an end date or a count.
  final n = t.data['repeatEvery'] is int ? t.data['repeatEvery'] as int : 1;
  final days = [
    for (final v in (t.data['repeatDays'] as List? ?? const []))
      if (v is int) v,
  ];
  DateTime step(DateTime d) => nextRepeatDay(d, every, n: n, days: days);
  final board = s.maybe('boards', t.str('board'));
  final onTimeline = board != null && boardTimeline(board) != null;
  final left = t.data['repeatLeft'];
  if (left is int && left <= 0) return s;
  final until = DateTime.tryParse('${t.data['repeatUntil'] ?? ''}');
  final anchor = due ?? scheduledDay(t);
  if (until != null && anchor != null && step(anchor).isAfter(until)) return s;
  Json? nextDue;
  if (due != null) {
    final n = step(due);
    final old = t.data['due'] as Map;
    nextDue = old['kind'] == 'day'
        ? {
            'kind': 'day',
            'day':
                '${n.year.toString().padLeft(4, '0')}-'
                '${n.month.toString().padLeft(2, '0')}-'
                '${n.day.toString().padLeft(2, '0')}',
          }
        : {
            ...Map<String, dynamic>.from(old),
            'at': DateTime.parse(
              old['at'] as String,
            ).add(step(due).difference(due)).toUtc().toIso8601String(),
          };
  }
  final ids = <String, String>{};
  for (final a in s.related('attachments', card)) {
    ids[a.id] = newId();
    e.put('attachments', a.copy({'id': ids[a.id], 'task': id}));
  }
  e.put(
    'tasks',
    BoardRecord({
      ...t.toJson(),
      'id': id,
      'status': first.id,
      'order': -1,
      'created': at,
      'updated': at,
      'completedAt': null,
      'due': nextDue,
      // A plan moves with its repeat, one period on.
      // On a timeline a card without a plan sits in the period it was
      // made, so its next one is planned one repeat on from that day.
      'scheduled': switch (scheduledDay(t)) {
        final d? => isoDay(step(d)),
        null when onTimeline => isoDay(step(cardDay(t, fallback: now))),
        null => null,
      },
      if (left is int) 'repeatLeft': left - 1,
      'repeatedAs': null,
      'suggestedStatus': null,
      'coverPhoto': ids[t.data['coverPhoto']],
    }),
  );
  for (final c in s.related('checklist', card))
    e.put(
      'checklist',
      c.copy({'id': newId(), 'task': id, 'done': false, 'completedAt': null}),
    );
  e.put('tasks', t.copy({'repeatedAs': id}));
  e.event(id, 'created', now ?? DateTime.now(), details: {'repeatOf': card});
  return e.finish();
}

/// Sets a card's due day (a whole day, no time), or takes it off with
/// null: what dropping a card on a day of the week view does.
BoardsState setDueDay(
  BoardsState s,
  String card,
  DateTime? day, {
  DateTime? now,
}) {
  final t = s.get('tasks', card);
  return saveTask(
    s,
    t.copy({
      'due': day == null
          ? null
          : {
              'kind': 'day',
              'day':
                  '${day.year.toString().padLeft(4, '0')}-'
                  '${day.month.toString().padLeft(2, '0')}-'
                  '${day.day.toString().padLeft(2, '0')}',
            },
    }),
    now: now,
  );
}
