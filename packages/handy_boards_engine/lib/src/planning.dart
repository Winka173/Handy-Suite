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

BoardsState skipOccurrence(BoardsState s, String id) {
  final r = s.get('occurrences', id),
      e = BoardsEdit(s),
      t = s.get('tasks', r.str('task'));
  e.put('occurrences', r.copy({'state': 'skipped'}));
  e.put('tasks', t.copy({'archived': true}));
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

Json gradePlan(
  Iterable<BoardRecord> grades, {
  required double target,
  bool normalize = false,
}) {
  if (!target.isFinite || target < 0 || target > 100)
    throw const FormatException('Target must be 0..100');
  final rows = grades.toList();
  for (final g in rows) validateGrade(g);
  final weight = rows.fold<double>(0, (v, g) => v + (g.data['weight'] as num));
  if (weight <= 0 || !normalize && (weight - 100).abs() > 0.000001)
    throw const FormatException(
      'Weights must total 100; explicit normalization required otherwise',
    );
  var earned = 0.0, remaining = 0.0, gradedWeight = 0.0;
  for (final g in rows) {
    final w = (g.data['weight'] as num) * 100 / weight;
    if (g.data['earned'] == null) {
      remaining += w;
    } else {
      earned += (g.data['earned'] as num) / (g.data['possible'] as num) * w;
      gradedWeight += w;
    }
  }
  final needed = remaining == 0 ? null : (target - earned) / remaining * 100;
  return {
    'earnedWeighted': earned,
    'gradedWeight': gradedWeight,
    'remainingWeight': remaining,
    'requiredPercent': needed,
    'currentPercent': gradedWeight == 0 ? null : earned / gradedWeight * 100,
    'feasible': needed == null ? earned >= target : needed <= 100,
    'targetReached': earned >= target,
    'official': false,
  };
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

Json smartPriority(
  BoardsState s,
  BoardRecord t,
  DateTime now, {
  Json weights = const {},
}) {
  double weight(String key, double fallback) {
    final v = weights[key] ?? fallback;
    if (v is! num || !v.isFinite || v < 0 || v > 1000)
      throw const FormatException('Invalid score weight');
    return v.toDouble();
  }

  var score = t.number('priority') * weight('priority', 10);
  final reasons = <String>['priority:${t.number('priority')}'];
  final name = s.get('boards', t.str('board')).str('zone');
  if (t.data['start'] != null &&
      deadlineDay(object(t.data['start']), name) == localDay(now, name)) {
    score += weight('planned', 15);
    reasons.add('planned today');
  }
  final category = s.maybe('categories', t.data['category']),
      categoryWeight = (category?.data['priorityWeight'] as num? ?? 0)
          .toDouble();
  if (categoryWeight > 0) {
    score += categoryWeight * weight('category', 1);
    reasons.add('category weight:$categoryWeight');
  }
  if (t.flag('pinned')) {
    score += weight('pin', 50);
    reasons.add('pinned');
  }
  if (blocked(s, t)) {
    score -= weight('blocked', 100);
    reasons.add('blocked');
  }
  if (t.data['due'] != null) {
    final d = object(t.data['due']),
        diff =
            calendarDate(
                  deadlineDay(d, s.get('boards', t.str('board')).str('zone')),
                )
                .difference(
                  calendarDate(
                    localDay(now, s.get('boards', t.str('board')).str('zone')),
                  ),
                )
                .inDays;
    if (diff < 0 || d['kind'] == 'time' && _instant(d['at']).isBefore(now)) {
      score += weight('overdue', 40);
      reasons.add('overdue');
    } else if (diff <= 3) {
      score += weight('soon', 20);
      reasons.add('due:$diff days');
    }
  }
  if (t.number('estimate') > 0 && t.number('estimate') <= 30) {
    score += weight('short', 5);
    reasons.add('estimate<=30m');
  }
  return {'score': score, 'reasons': reasons, 'ai': false};
}

BoardsState startFocus(BoardsState s, String task, DateTime now) {
  s.get('tasks', task);
  if (s.rows('sessions').any((r) => r.data['runningAt'] != null))
    throw const FormatException('Pause current session first');
  final next = s.put(
    'sessions',
    BoardRecord({
      'id': newId(),
      'task': task,
      'elapsed': 0,
      'runningAt': now.toUtc().toIso8601String(),
      'created': now.toUtc().toIso8601String(),
    }),
  );
  next.validate();
  return next;
}

BoardsState pauseFocus(BoardsState s, String id, DateTime now) {
  final r = s.get('sessions', id);
  if (r.data['runningAt'] == null) return s;
  final delta = now.difference(_instant(r.str('runningAt'))).inSeconds;
  if (delta < 0 || delta > 86400)
    throw const FormatException(
      'Clock changed or session over 24h; review duration',
    );
  return s.put(
    'sessions',
    r.copy({
      'elapsed': r.number('elapsed') + delta,
      'segments': [
        ...?r.data['segments'] as List?,
        {
          'start': r.str('runningAt'),
          'end': now.toUtc().toIso8601String(),
          'seconds': delta,
        },
      ],
      'runningAt': null,
      'pausedAt': now.toUtc().toIso8601String(),
    }),
  );
}

BoardsState resumeFocus(BoardsState s, String id, DateTime now) {
  final r = s.get('sessions', id);
  if (r.data['runningAt'] != null) return s;
  if (s.rows('sessions').any((r) => r.data['runningAt'] != null))
    throw const FormatException('Another session is running');
  return s.put(
    'sessions',
    r.copy({'runningAt': now.toUtc().toIso8601String()}),
  );
}

void validateAutomation(BoardsState s, BoardRecord rule) {
  s.get('boards', rule.str('board'));
  if (![
    'created',
    'moved',
    'completed',
    'due changed',
    'opened',
  ].contains(rule.str('trigger')))
    throw const FormatException('Unknown trigger');
  final actions = rule.data['actions'];
  if (actions is! List || actions.length > 10)
    throw const FormatException('At most ten automation actions');
  for (final raw in actions) {
    final a = object(raw);
    if (![
      'priority',
      'category',
      'tag',
      'checklist',
      'suggestStatus',
      'remindMinutes',
      'generate',
    ].contains(a['type']))
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
    if (a['type'] == 'checklist') text(a['value'], empty: false);
    if (a['type'] == 'remindMinutes' &&
        (a['value'] is! int || a['value'] < 1 || a['value'] > 525600))
      throw const FormatException('Reminder offset 1..525600 minutes');
    if (a['type'] == 'generate' &&
        s.get('recurrence', a['value'] as String).str('board') !=
            rule.str('board'))
      throw const FormatException('Recurring rule board mismatch');
  }
}

BoardsState runAutomations(
  BoardsState s,
  String task,
  String trigger,
  String eventId, {
  required DateTime now,
  bool preview = false,
}) {
  text(eventId, max: 120, empty: false);
  final t = s.get('tasks', task), e = BoardsEdit(s);
  var current = t, count = 0;
  final generation = <String>{};
  for (final rule
      in s
          .rows('rules')
          .where(
            (r) =>
                r.flag('enabled') &&
                r.str('board') == t.str('board') &&
                r.str('trigger') == trigger,
          )) {
    validateAutomation(s, rule);
    final token = '$eventId/${rule.id}';
    if (s.rows('executions').any((r) => r.str('token') == token)) continue;
    if (++count > 50)
      throw const FormatException('Automation batch exceeds fifty rules');
    for (final raw in rule.data['actions'] as List) {
      final a = object(raw);
      switch (a['type']) {
        case 'priority':
          current = current.copy({'priority': a['value']});
        case 'category':
          current = current.copy({'category': a['value']});
        case 'tag':
          current = current.copy({
            'tags': {...current.strings('tags'), a['value']}.toList(),
          });
        case 'checklist':
          e.put(
            'checklist',
            BoardRecord({
              'id': newId(),
              'task': task,
              'title': a['value'],
              'done': false,
            }),
          );
        case 'suggestStatus':
          current = current.copy({'suggestedStatus': a['value']});
        case 'remindMinutes':
          e.put(
            'reminders',
            BoardRecord({
              'id': newId(),
              'task': task,
              'board': t.str('board'),
              'at': now
                  .add(Duration(minutes: a['value'] as int))
                  .toUtc()
                  .toIso8601String(),
              'zone': s.get('boards', t.str('board')).str('zone'),
              'enabled': true,
            }),
          );
        case 'generate':
          generation.add(a['value'] as String);
      }
    }
    e.put(
      'executions',
      BoardRecord({
        'id': newId(),
        'rule': rule.id,
        'task': task,
        'token': token,
        'at': now.toUtc().toIso8601String(),
        'delayed': trigger == 'opened',
      }),
    );
  }
  e.put('tasks', current);
  var next = e.finish();
  for (final id in generation)
    next = generateOccurrences(
      next,
      id,
      recurrenceHorizon(next, next.get('recurrence', id), now),
    );
  return next;
  // Actions do not recursively trigger rules; no event loop or background promise.
}
