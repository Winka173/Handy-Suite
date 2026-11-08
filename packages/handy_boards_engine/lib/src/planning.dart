part of '../handy_boards_engine.dart';

void validateRecurrence(BoardRecord r) {
  day(r.str('start'));
  zone(r.str('zone'));
  if (!['daily', 'weekly', 'monthly'].contains(r.str('frequency')) ||
      r.number('interval', 1) < 1 ||
      r.number('interval', 1) > 366)
    throw const FormatException('Invalid recurrence');
  if (r.data['until'] != null &&
      day(r.str('until')).compareTo(r.str('start')) < 0)
    throw const FormatException('Recurrence end before start');
  if (r.data['clock'] != null)
    wallTime(
      r.str('start'),
      r.str('clock'),
      r.str('zone'),
      lateFold: r.data['lateFold'] as bool?,
    );
  for (final d in (r.data['weekdays'] as List? ?? []))
    if (d is! int || d < 1 || d > 7)
      throw const FormatException('Invalid weekday');
  for (final d in r.strings('exceptions')) day(d);
  if (r.number('count', 10000) < 1 || r.number('count', 10000) > 10000)
    throw const FormatException('Invalid recurrence count');
}

bool _occurs(BoardRecord rule, DateTime d) {
  final start = calendarDate(rule.str('start')),
      delta = d.difference(start).inDays,
      interval = rule.number('interval', 1);
  if (delta < 0) return false;
  return switch (rule.str('frequency')) {
    'daily' => delta % interval == 0,
    'weekly' =>
      (delta ~/ 7) % interval == 0 &&
          ((rule.data['weekdays'] as List? ?? [start.weekday]).contains(
            d.weekday,
          )),
    'monthly' =>
      d.day == start.day &&
          ((d.year - start.year) * 12 + d.month - start.month) % interval == 0,
    _ => false,
  };
}

BoardsState generateOccurrences(
  BoardsState s,
  String ruleId,
  String through, {
  int limit = 366,
}) {
  final r = s.get('recurrence', ruleId);
  validateRecurrence(r);
  day(through);
  final start = calendarDate(r.str('start')), end = calendarDate(through);
  if (end.difference(start).inDays > 3660 || limit < 1 || limit > 1000)
    throw const FormatException('Recurrence horizon too large');
  final base = s.get('tasks', r.str('task')),
      e = BoardsEdit(s),
      known = {
        for (final o in s.rows('occurrences'))
          '${o.str('rule')}/${o.str('day')}',
      };
  var made = 0, ordinal = 0;
  for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
    final date = d.toIso8601String().substring(0, 10);
    if (r.data['until'] != null && date.compareTo(r.str('until')) > 0) break;
    if (!_occurs(r, d)) continue;
    ordinal++;
    if (ordinal > r.number('count', 10000)) break;
    if (r.strings('exceptions').contains(date) ||
        known.contains('$ruleId/$date'))
      continue;
    if (++made > limit)
      throw const FormatException(
        'Too many occurrences; choose a smaller horizon',
      );
    final id = newId(),
        due = r.data['clock'] == null
            ? {'kind': 'day', 'day': date}
            : {
                'kind': 'time',
                'at': wallTime(
                  date,
                  r.str('clock'),
                  r.str('zone'),
                  lateFold: r.data['lateFold'] as bool?,
                ).toUtc().toIso8601String(),
                'zone': r.str('zone'),
              };
    e.put(
      'tasks',
      BoardRecord({
        'id': id,
        'board': base.str('board'),
        'category': base.data['category'],
        'parent': null,
        'title': base.str('title'),
        'notes': base.str('notes'),
        'status': r.str('status', base.str('status')),
        'priority': base.number('priority'),
        'tags': base.strings('tags'),
        'due': due,
        'estimate': base.number('estimate'),
        'created': DateTime.now().toUtc().toIso8601String(),
        'recurrenceSource': ruleId,
      }),
    );
    e.put(
      'occurrences',
      BoardRecord({
        'id': newId(),
        'rule': ruleId,
        'task': id,
        'day': date,
        'state': 'pending',
      }),
    );
  }
  return e.finish();
}

void validateGrade(BoardRecord g) {
  final w = g.data['weight'],
      possible = g.data['possible'],
      earned = g.data['earned'];
  if (w is! num ||
      !w.isFinite ||
      w < 0 ||
      w > 100 ||
      possible is! num ||
      !possible.isFinite ||
      possible <= 0 ||
      earned != null &&
          (earned is! num ||
              !earned.isFinite ||
              earned < 0 ||
              earned > possible))
    throw const FormatException('Invalid assessment weight/score');
}

void validateField(BoardsState s, BoardRecord f) {
  s.get('boards', f.str('board'));
  if (![
    'text',
    'number',
    'date',
    'checkbox',
    'single',
    'multi',
    'url',
  ].contains(f.str('type')))
    throw const FormatException('Unsupported custom field');
  if (f.strings('options').toSet().length != f.strings('options').length)
    throw const FormatException('Duplicate choices');
  if (f.data['default'] != null)
    validateCustomValues(
      s,
      BoardRecord({
        'id': 'field-default-validation',
        'board': f.str('board'),
        'custom': {f.id: f.data['default']},
      }),
    );
}

void validateCustomValues(BoardsState s, BoardRecord t) {
  for (final entry in object(t.data['custom'] ?? {}).entries) {
    final f = s.get('fields', entry.key), v = entry.value;
    if (f.str('board') != t.str('board'))
      throw const FormatException('Custom field board mismatch');
    switch (f.str('type')) {
      case 'text':
        text(v, max: 10000);
      case 'number':
        if (v is! String || !RegExp(r'^-?\d{1,20}(\.\d{1,10})?$').hasMatch(v))
          throw const FormatException('Decimal string required');
      case 'date':
        day(v as String);
      case 'checkbox':
        if (v is! bool) throw const FormatException('Boolean required');
      case 'single':
        if (!f.strings('options').contains(v))
          throw const FormatException('Unknown choice');
      case 'multi':
        if (v is! List ||
            v.toSet().length != v.length ||
            v.any((x) => !f.strings('options').contains(x)))
          throw const FormatException('Invalid choices');
      case 'url':
        safeUrl(v as String);
    }
  }
}

void validateAutomation(BoardsState s, BoardRecord rule) {
  s.get('boards', rule.str('board'));
  if (![...ruleTriggers, 'due changed', 'opened'].contains(rule.str('trigger')))
    throw const FormatException('Unknown trigger');
  if (rule.data['title'] != null) text(rule.data['title'], max: 80);
  final days = rule.data['days'];
  if (days != null && (days is! int || days < 0 || days > 14))
    throw const FormatException('Rule days 0..14');
  final when = rule.data['when'];
  if (when != null) {
    if (when is! Map) throw const FormatException('Invalid rule conditions');
    for (final entry in when.entries) {
      switch (entry.key) {
        case 'status' || 'category':
          final kind = entry.key == 'status' ? 'statuses' : 'categories';
          if (s.get(kind, entry.value as String).str('board') !=
              rule.str('board'))
            throw const FormatException('Automation scope mismatch');
        case 'priority':
          if (entry.value is! int || entry.value < 0 || entry.value > 3)
            throw const FormatException('Invalid priority');
        default:
          throw const FormatException('Invalid rule conditions');
      }
    }
  }
  final actions = rule.data['actions'];
  if (actions is! List || actions.length > 10)
    throw const FormatException('At most ten automation actions');
  for (final raw in actions) {
    final a = object(raw);
    if (![...ruleActions, 'tag', 'generate'].contains(a['type']))
      throw const FormatException('Unsupported action');
    if (a['type'] == 'priority' &&
        (a['value'] is! int || a['value'] < 0 || a['value'] > 3))
      throw const FormatException('Invalid priority');
    if (['category', 'tag', 'suggestStatus'].contains(a['type'])) {
      final kind = a['type'] == 'category'
          ? 'categories'
          : a['type'] == 'tag'
          ? 'tags'
          : 'statuses';
      if (s.get(kind, a['value'] as String).str('board') != rule.str('board'))
        throw const FormatException('Automation scope mismatch');
    }
    if (a['type'] == 'checklist') text(a['value'], empty: false, max: 200);
    if (a['type'] == 'template' && a['value'] is! String)
      throw const FormatException('Invalid card template');
    if (a['type'] == 'notify' &&
        (a['value'] != true || rule.str('trigger') != 'due soon'))
      throw const FormatException('Notify needs a due-soon rule');
    if (a['type'] == 'remindMinutes' &&
        (a['value'] is! int || a['value'] < 1 || a['value'] > 525600))
      throw const FormatException('Reminder offset 1..525600 minutes');
    if (a['type'] == 'generate' &&
        s.get('recurrence', a['value'] as String).str('board') !=
            rule.str('board'))
      throw const FormatException('Recurring rule board mismatch');
  }
}
