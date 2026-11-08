part of '../handy_boards_engine.dart';

// Custom fields (Pro): a few properties of a board's own on its cards.
// Text, number (a decimal string), date ('YYYY-MM-DD'), yes/no, one choice
// and link; no formulas, relations or roll-ups. A removed field is only
// set aside (`archived`), so its values stay readable, exportable and can
// come back; nothing is ever stripped from a card.

const fieldTypes = ['text', 'number', 'date', 'checkbox', 'single', 'url'];
const fieldLimit = 20;

/// The board's fields in order; [all] includes set-aside ones.
List<BoardRecord> fieldsOf(BoardsState s, String board, {bool all = false}) =>
    s
        .rows('fields')
        .where((f) => f.str('board') == board && (all || !f.flag('archived')))
        .toList()
      ..sort((a, b) => a.number('order').compareTo(b.number('order')));

BoardsState addField(
  BoardsState s,
  String board,
  String title,
  String type, {
  List<String> options = const [],
  bool onCard = false,
}) {
  if (!fieldTypes.contains(type))
    throw const FormatException('Unsupported custom field');
  final name = text(title.trim(), empty: false, max: 60);
  final live = fieldsOf(s, board);
  if (live.length >= fieldLimit)
    throw const FormatException('At most 20 fields per board');
  if (live.any((f) => f.str('title').toLowerCase() == name.toLowerCase()))
    throw const FormatException('A field with that name exists');
  return s.put(
    'fields',
    BoardRecord({
      'id': newId(),
      'board': board,
      'title': name,
      'type': type,
      'options': type == 'single'
          ? [
              for (final o in options)
                if (o.trim().isNotEmpty) o.trim(),
            ]
          : <String>[],
      'onCard': onCard,
      'order': fieldsOf(s, board, all: true).length,
    }),
  );
}

/// Renames, re-lists choices (a choice still in use cannot go) or shows a
/// field on the card front.
BoardsState updateField(
  BoardsState s,
  String id, {
  String? title,
  List<String>? options,
  bool? onCard,
}) {
  final f = s.get('fields', id);
  if (title != null) {
    final name = text(title.trim(), empty: false, max: 60);
    if (fieldsOf(s, f.str('board')).any(
      (o) => o.id != id && o.str('title').toLowerCase() == name.toLowerCase(),
    ))
      throw const FormatException('A field with that name exists');
  }
  final next = f.copy({
    if (title != null) 'title': title.trim(),
    if (options != null)
      'options': [
        for (final o in options)
          if (o.trim().isNotEmpty) o.trim(),
      ],
    if (onCard != null) 'onCard': onCard,
  });
  // validate() refuses a choice that a card still uses.
  return s.put('fields', next)..validate();
}

/// Sets a field aside (or back with [restore]); values on cards stay.
BoardsState archiveField(BoardsState s, String id, {bool restore = false}) =>
    s.put('fields', s.get('fields', id).copy({'archived': !restore}));

/// One card's value for a field; null clears it. Logged by field only, the
/// value itself stays out of the history.
BoardsState setFieldValue(
  BoardsState s,
  String card,
  String field,
  Object? value, {
  DateTime? now,
}) {
  final t = s.get('tasks', card), f = s.get('fields', field);
  if (f.str('board') != t.str('board'))
    throw const FormatException('Custom field board mismatch');
  final custom = {...object(t.data['custom'] ?? {})};
  if (value == null || (value is String && value.trim().isEmpty)) {
    custom.remove(field);
  } else {
    custom[field] = value is String ? value.trim() : value;
  }
  final e = BoardsEdit(s), at = now ?? DateTime.now();
  e.put('tasks', t.copy({'custom': custom, 'updated': _now(at)}));
  e.event(
    card,
    'field changed',
    at,
    details: {'field': field, 'name': f.str('title')},
  );
  return e.finish();
}

/// A value as words for the card and the detail view.
String fieldText(BoardRecord field, Object? value, {bool vi = false}) {
  if (value == null) return '';
  return switch (field.str('type')) {
    'checkbox' => value == true ? (vi ? 'Có' : 'Yes') : (vi ? 'Không' : 'No'),
    'date' => switch (DateTime.tryParse('$value')) {
      final d? => '${d.day}/${d.month}/${d.year}',
      null => '$value',
    },
    _ => '$value',
  };
}

// Saved filters (Pro) reuse the `views` kind: a name, AND/OR, and up to
// thirty conditions from [validateTaskFilter] (column, category, priority,
// due range, reminder...). No expression language.

List<BoardRecord> savedFilters(BoardsState s, String board) =>
    s.rows('views').where((v) => v.str('board') == board).toList()
      ..sort((a, b) => a.str('title').compareTo(b.str('title')));

BoardsState saveFilter(
  BoardsState s,
  String board,
  String title,
  List<Json> conditions, {
  bool any = false,
  String? id,
}) {
  final name = text(title.trim(), empty: false, max: 60);
  if (conditions.isEmpty) throw const FormatException('Choose a condition');
  return s.put(
    'views',
    BoardRecord({
      'id': id ?? newId(),
      'board': board,
      'title': name,
      'mode': any ? 'or' : 'and',
      'conditions': conditions,
      'sort': 'manual',
      'group': 'flat',
    }),
  )..validate();
}

BoardsState deleteFilter(BoardsState s, String id) => s.remove('views', {id});

/// Whether [t] passes saved filter [view]: all of its conditions, or any
/// of them in OR mode.
bool filterMatches(BoardsState s, BoardRecord view, BoardRecord t) {
  final conditions = [
    for (final c in (view.data['conditions'] as List? ?? const [])) object(c),
  ];
  if (conditions.isEmpty) return true;
  bool one(Json c) => taskMatches(s, t, filter: c);
  return view.str('mode', 'and') == 'or'
      ? conditions.any(one)
      : conditions.every(one);
}
