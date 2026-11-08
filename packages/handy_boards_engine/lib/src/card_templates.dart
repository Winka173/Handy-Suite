part of '../handy_boards_engine.dart';

// Personal card templates (Pro): the person's own reusable card patterns,
// kept in the `templates` kind with `kind: 'card'`, for every board. A
// template holds only a pattern: a title, a note, subtask titles, a
// priority, a category *name*, a drawn cover, days from "today" for the
// plan and the due date, and custom values keyed by field name and type.
// It never holds ids of the card it came from, its dates, its completion,
// its history, reminders, photos or file paths.

const cardTemplateLimit = 200;

List<BoardRecord> cardTemplates(BoardsState s) =>
    s.rows('templates').where((r) => r.str('kind') == 'card').toList()
      ..sort((a, b) {
        final o = a.number('order').compareTo(b.number('order'));
        return o != 0 ? o : a.str('title').compareTo(b.str('title'));
      });

void validateCardTemplate(BoardRecord r) {
  text(r.data['title'], empty: false, max: 200);
  text(r.data['notes'] ?? '', max: 20000);
  final list = r.data['checklist'] ?? const [];
  if (list is! List || list.length > 100 || list.any((v) => v is! String))
    throw const FormatException('Invalid template checklist');
  for (final v in list) text(v, empty: false, max: 1000);
  for (final key in ['planIn', 'dueIn'])
    if (r.data[key] != null &&
        (r.data[key] is! int ||
            (r.data[key] as int) < 0 ||
            (r.data[key] as int) > 365))
      throw const FormatException('Template day offset 0..365');
  final p = r.data['priority'];
  if (p != null && (p is! int || p < 0 || p > 3))
    throw const FormatException('Invalid template priority');
  if (r.data['category'] != null) text(r.data['category'], max: 200);
  final cover = r.data['cover'];
  if (cover != null && (cover is! String || !_coverValue.hasMatch(cover)))
    throw const FormatException('Invalid template cover');
  final custom = r.data['custom'] ?? const [];
  if (custom is! List || custom.length > 50)
    throw const FormatException('Invalid template fields');
  for (final c in custom) {
    if (c is! Map || c['name'] is! String || c['type'] is! String)
      throw const FormatException('Invalid template field');
  }
}

/// Saves a template (new when [id] is null).
BoardsState saveCardTemplate(
  BoardsState s, {
  String? id,
  required String title,
  String notes = '',
  List<String> checklist = const [],
  int? planIn,
  int? dueIn,
  int? priority,
  String? category,
  String? cover,
  List<Json> custom = const [],
  DateTime? now,
}) {
  final at = _now(now), old = id == null ? null : s.maybe('templates', id);
  if (old == null && cardTemplates(s).length >= cardTemplateLimit)
    throw const FormatException('At most 200 card templates');
  final r = BoardRecord({
    'id': id ?? newId(),
    'kind': 'card',
    'title': title.trim(),
    'notes': notes,
    'checklist': [
      for (final c in checklist)
        if (c.trim().isNotEmpty) c.trim(),
    ],
    'planIn': planIn,
    'dueIn': dueIn,
    'priority': priority,
    'category': category,
    'cover': cover,
    'custom': custom,
    'order': old?.data['order'] ?? cardTemplates(s).length,
    'created': old?.data['created'] ?? at,
    'updated': at,
  });
  validateCardTemplate(r);
  return s.put('templates', r);
}

/// The pattern of [card]: its words, subtask titles, priority, category
/// name, drawn cover and custom values; none of its ids, dates, state or
/// history.
BoardsState cardTemplateFromCard(
  BoardsState s,
  String card, {
  String? title,
  DateTime? now,
}) {
  final t = s.get('tasks', card);
  final category = t.data['category'] == null
      ? null
      : s.maybe('categories', t.str('category'))?.str('title');
  final cover = t.data['cover'];
  return saveCardTemplate(
    s,
    title: title ?? t.str('title'),
    notes: t.str('notes'),
    checklist: [for (final c in subtasksOf(s, card)) c.str('title')],
    priority: t.data['priority'] is int ? t.number('priority') : null,
    category: category,
    cover: cover is String && !cover.startsWith('photo:') ? cover : null,
    custom: [
      for (final e in object(t.data['custom'] ?? {}).entries)
        if (s.maybe('fields', e.key) case final f?)
          {'name': f.str('title'), 'type': f.str('type'), 'value': e.value},
    ],
    now: now,
  );
}

BoardsState deleteCardTemplate(BoardsState s, String id) =>
    s.remove('templates', {id});

/// What applying a template could not carry over: custom values whose
/// field (same name and type) is not on the target board.
class TemplateApply {
  final BoardsState state;
  final String card;
  final List<String> skippedFields;
  const TemplateApply(this.state, this.card, this.skippedFields);
}

/// A fresh card from template [id] at the top of [column]: new ids,
/// subtasks unticked, the plan and due date counted from [now], the
/// category by name on this board (or [category] when given), custom
/// values only where this board has the same field.
TemplateApply applyCardTemplate(
  BoardsState s,
  String id,
  String column, {
  String? category,
  DateTime? now,
}) {
  final tpl = s.get('templates', id);
  final col = s.get('statuses', column), board = col.str('board');
  final today = calendarDay(now ?? DateTime.now());
  final cat =
      category ??
      (tpl.data['category'] == null
          ? null
          : categoriesOf(s, board)
                .where(
                  (c) =>
                      c.str('title').toLowerCase() ==
                      tpl.str('category').toLowerCase(),
                )
                .firstOrNull
                ?.id);
  final fields = s.rows('fields').where((f) => f.str('board') == board);
  final custom = <String, Object?>{};
  final skipped = <String>[];
  for (final raw in (tpl.data['custom'] as List? ?? const [])) {
    final c = raw as Map;
    final f = fields
        .where((f) => f.str('title') == c['name'] && f.str('type') == c['type'])
        .firstOrNull;
    if (f == null) {
      skipped.add('${c['name']}');
    } else {
      custom[f.id] = c['value'];
    }
  }
  final planIn = tpl.data['planIn'] as int?, dueIn = tpl.data['dueIn'] as int?;
  var t = newTask(s, board, tpl.str('title'), category: cat).copy({
    'status': column,
    'notes': tpl.str('notes'),
    'order': -1,
    if (tpl.data['priority'] != null) 'priority': tpl.data['priority'],
    if (tpl.data['cover'] != null) 'cover': tpl.data['cover'],
    'custom': {...object(newTask(s, board, '').data['custom']), ...custom},
    if (planIn != null) 'scheduled': isoDay(addDays(today, planIn)),
    if (dueIn != null)
      'due': {'kind': 'day', 'day': isoDay(addDays(today, dueIn))},
  });
  var next = saveTask(s, t, now: now);
  final e = BoardsEdit(next);
  var i = 0;
  for (final title in (tpl.data['checklist'] as List? ?? const [])) {
    e.put(
      'checklist',
      BoardRecord({
        'id': newId(),
        'task': t.id,
        'title': title,
        'done': false,
        'order': i++,
      }),
    );
  }
  e.event(
    t.id,
    'from template',
    now ?? DateTime.now(),
    details: {'template': id},
  );
  next = e.finish();
  // Renumber the column so the new card sits first.
  final ordered = cardsIn(next, column);
  final e2 = BoardsEdit(next);
  for (var j = 0; j < ordered.length; j++)
    e2.put('tasks', ordered[j].copy({'order': j}));
  return TemplateApply(e2.finish(), t.id, skipped);
}
