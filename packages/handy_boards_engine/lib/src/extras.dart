part of '../handy_boards_engine.dart';

Json parseGradeThresholds(String input) {
  final result = <String, dynamic>{};
  for (final line
      in input.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
    final split = line.lastIndexOf('=');
    if (split < 1)
      throw const FormatException('Use one grade per line: A = 90');
    final label = line.substring(0, split).trim(),
        value = double.tryParse(line.substring(split + 1).trim());
    text(label, max: 20, empty: false);
    if (result.containsKey(label) ||
        value == null ||
        !value.isFinite ||
        value < 0 ||
        value > 100 ||
        result.values.contains(value))
      throw const FormatException(
        'Unique labels/thresholds between 0 and 100 required',
      );
    result[label] = value;
  }
  return result;
}

Map<String, Json> workloadBuckets(Json report, {bool weekly = false}) {
  final result = <String, Json>{};
  for (final entry in object(report['days']).entries) {
    final date = calendarDate(entry.key),
        key = weekly
            ? date
                  .subtract(Duration(days: date.weekday - 1))
                  .toIso8601String()
                  .substring(0, 10)
            : entry.key;
    final row = object(entry.value),
        bucket = result.putIfAbsent(
          key,
          () => {
            'minutes': 0,
            'actualSeconds': 0,
            'unknown': 0,
            'tasks': 0,
            'overloadedDays': 0,
          },
        );
    for (final field in ['minutes', 'actualSeconds', 'unknown', 'tasks'])
      bucket[field] += (row[field] as int? ?? 0);
    if (row['overloaded'] == true) bucket['overloadedDays']++;
    bucket['overloaded'] = bucket['overloadedDays'] > 0;
  }
  return result;
}

/// Retained completion transitions, not a reconstructed historical completion %.
Map<String, int> completionHistory(
  BoardsState s,
  DateTime now, {
  String? board,
  int days = 14,
}) {
  if (days < 1 || days > 366)
    throw const FormatException('History window 1..366 days');
  final name = board == null ? 'UTC' : s.get('boards', board).str('zone'),
      last = calendarDate(localDay(now, name));
  final result = {
    for (var i = days - 1; i >= 0; i--)
      last.subtract(Duration(days: i)).toIso8601String().substring(0, 10): 0,
  };
  for (final event
      in s.rows('events').where((e) => e.str('action') == 'completed')) {
    final task = s.get('tasks', event.str('task'));
    if (task.data['parent'] != null ||
        board != null && task.str('board') != board)
      continue;
    final date = localDay(DateTime.parse(event.str('at')), name);
    if (result.containsKey(date)) result[date] = result[date]! + 1;
  }
  return result;
}

BoardsState shiftTaskDates(
  BoardsState s,
  String task,
  int days, {
  bool resizeEnd = false,
  bool? lateFold,
  DateTime? now,
}) {
  if (days.abs() > 366) throw const FormatException('Move at most 366 days');
  final t = s.get('tasks', task),
      name = s.get('boards', t.str('board')).str('zone');
  Json shifted(dynamic raw) {
    final d = object(raw),
        date = calendarDate(
          deadlineDay(d, name),
        ).add(Duration(days: days)).toIso8601String().substring(0, 10);
    day(date);
    if (d['kind'] == 'day') return {'kind': 'day', 'day': date};
    final old = tz.TZDateTime.from(DateTime.parse(d['at']), zone(name)),
        clock =
            '${old.hour.toString().padLeft(2, '0')}:${old.minute.toString().padLeft(2, '0')}';
    return {
      'kind': 'time',
      'zone': name,
      'at': wallTime(date, clock, name, lateFold: lateFold)
          .add(
            Duration(
              seconds: old.second,
              milliseconds: old.millisecond,
              microseconds: old.microsecond,
            ),
          )
          .toUtc()
          .toIso8601String(),
    };
  }

  if (t.data['start'] == null || t.data['due'] == null)
    throw const FormatException('Set both dates first');
  return saveTask(
    s,
    t.copy({
      'start': resizeEnd ? t.data['start'] : shifted(t.data['start']),
      'due': shifted(t.data['due']),
    }),
    now: now,
  );
}

BoardsState rescheduleTask(
  BoardsState s,
  String task,
  String day, {
  bool? lateFold,
  DateTime? now,
}) {
  calendarDate(day);
  final t = s.get('tasks', task),
      due = object(t.data['due']),
      name = s.get('boards', t.str('board')).str('zone');
  final Json next;
  if (due['kind'] == 'day') {
    next = {'kind': 'day', 'day': day};
  } else {
    final local = tz.TZDateTime.from(DateTime.parse(due['at']), zone(name));
    final instant =
        wallTime(
          day,
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
          name,
          lateFold: lateFold,
        ).add(
          Duration(
            seconds: local.second,
            milliseconds: local.millisecond,
            microseconds: local.microsecond,
          ),
        );
    next = {
      'kind': 'time',
      'at': instant.toUtc().toIso8601String(),
      'zone': name,
    };
  }
  return saveTask(s, t.copy({'due': next}), now: now);
}

BoardsState reconcileOpenRules(
  BoardsState s,
  DateTime now, {
  int taskLimit = 100,
}) {
  if (taskLimit < 1 || taskLimit > 500)
    throw const FormatException('App-open batch limit 1..500');
  final rules = s
          .rows('rules')
          .where((r) => r.flag('enabled') && r.str('trigger') == 'opened')
          .toList(),
      tokens = s.rows('executions').map((r) => r.str('token')).toSet();
  var next = s, count = 0;
  for (final task in s.rows('tasks').where(activeTask)) {
    final date = localDay(now, s.get('boards', task.str('board')).str('zone')),
        event = 'opened:$date/${task.id}';
    if (!rules.any(
      (r) =>
          r.str('board') == task.str('board') &&
          !tokens.contains('$event/${r.id}'),
    ))
      continue;
    if (count++ >= taskLimit) break;
    next = runAutomations(next, task.id, 'opened', event, now: now);
  }
  return next;
}

String recurrenceHorizon(BoardsState s, BoardRecord rule, DateTime now) =>
    calendarDate(
      localDay(now, rule.str('zone')),
    ).add(const Duration(days: 7)).toIso8601String().substring(0, 10);
bool recurrencePending(BoardsState s, BoardRecord rule, DateTime now) =>
    rule.data['enabled'] != false &&
    !rule.flag('reviewRequired') &&
    activeTask(s.get('tasks', rule.str('task'))) &&
    rule.str('generatedThrough').compareTo(recurrenceHorizon(s, rule, now)) < 0;
BoardsState reconcileRecurrences(
  BoardsState s,
  DateTime now, {
  int ruleLimit = 20,
}) {
  if (ruleLimit < 1 || ruleLimit > 100)
    throw const FormatException('Reconcile 1..100 rules per batch');
  final pending = s
      .rows('recurrence')
      .where((r) => recurrencePending(s, r, now))
      .take(ruleLimit)
      .toList();
  var next = s;
  for (final rule in pending) {
    final through = recurrenceHorizon(next, rule, now);
    try {
      next = generateOccurrences(next, rule.id, through);
      next = next.put(
        'recurrence',
        next.get('recurrence', rule.id).copy({
          'generatedThrough': through,
          'lastError': null,
        }),
      );
    } on FormatException catch (e) {
      next = next.put(
        'recurrence',
        next.get('recurrence', rule.id).copy({
          'reviewRequired': true,
          'lastError': e.message,
        }),
      );
    }
  }
  next.validate();
  return next;
}

Json deadlineRadar(BoardsState s, DateTime now, {String? board}) {
  final groups = <String, List<String>>{
    'overdue': [],
    '24h': [],
    '3d': [],
    '7d': [],
    'atRisk': [],
  };
  for (final task in topTasks(
    s,
    board: board,
  ).where((t) => !completed(s, t) && t.data['due'] != null)) {
    final due = object(task.data['due']),
        name = s.get('boards', task.str('board')).str('zone');
    final date = due['kind'] == 'day' ? calendarDate(due['day']) : null;
    final end = date == null
        ? _instant(due['at'])
        : tz.TZDateTime(
            zone(name),
            date.year,
            date.month,
            date.day + 1,
          ).toUtc();
    final seconds = end.difference(now).inSeconds;
    if (seconds < 0) {
      groups['overdue']!.add(task.id);
    } else if (seconds <= 86400) {
      groups['24h']!.add(task.id);
    } else if (seconds <= 259200) {
      groups['3d']!.add(task.id);
    } else if (seconds <= 604800) {
      groups['7d']!.add(task.id);
    }
    if (seconds >= 0 && seconds <= 604800 && blocked(s, task))
      groups['atRisk']!.add(task.id);
  }
  return {
    'groups': groups,
    'atRiskDefinition':
        'Blocked by unfinished work with a deadline within seven days; not a prediction',
    'allDayDefinition': 'Through end of due day in the task board timezone',
  };
}

Uint8List attachmentPreview(Uint8List bytes) {
  try {
    return _attachmentPreview(bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Cannot decode image');
  }
}

Uint8List _attachmentPreview(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 12000000)
    throw const FormatException('Image exceeds 12 MB');
  final decoder = img.findDecoderForData(bytes),
      info = decoder?.startDecode(bytes);
  if (info == null ||
      info.numFrames != 1 ||
      info.width < 1 ||
      info.height < 1 ||
      info.width * info.height > 16000000 ||
      !['jpeg', 'png', 'webp'].contains(decoder!.format.name))
    throw const FormatException('Static JPEG/PNG/WebP up to 16 MP required');
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Cannot decode image');
  final oriented = img.bakeOrientation(decoded),
      resized = oriented.width <= 640 && oriented.height <= 640
          ? oriented
          : img.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? 640 : null,
              height: oriented.height > oriented.width ? 640 : null,
            );
  final flat = img.Image(
    width: resized.width,
    height: resized.height,
    numChannels: 3,
  );
  img.fill(flat, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, resized);
  return Uint8List.fromList(img.encodeJpg(flat, quality: 80));
}

BoardsState reviewInterruptedFocus(
  BoardsState s,
  String id,
  int additionalSeconds,
  DateTime now,
) {
  final session = s.get('sessions', id);
  if (session.data['runningAt'] == null ||
      additionalSeconds < 0 ||
      additionalSeconds > 86400)
    throw const FormatException(
      'Review an active session with 0..86400 additional seconds',
    );
  return s.put(
    'sessions',
    session.copy({
      'elapsed': session.number('elapsed') + additionalSeconds,
      'runningAt': null,
      'pausedAt': now.toUtc().toIso8601String(),
      'reviewed': true,
    }),
  );
}

Json workloadReport(BoardsState s, String board, {int? dailyCapacity}) {
  final days = workload(s, board, dailyCapacity: dailyCapacity),
      location = zone(s.get('boards', board).str('zone'));
  var unknown = 0, running = 0;
  for (final session
      in s
          .rows('sessions')
          .where((r) => s.get('tasks', r.str('task')).str('board') == board)) {
    var allocated = 0;
    if (session.data['runningAt'] != null) running++;
    for (final raw in session.data['segments'] as List? ?? []) {
      final segment = object(raw), end = DateTime.parse(segment['end']);
      var cursor = DateTime.parse(segment['start']);
      final seconds = end.difference(cursor).inSeconds;
      if (seconds < 0 || seconds > 86400 || segment['seconds'] != seconds)
        throw const FormatException('Invalid focus segment');
      allocated += seconds;
      while (cursor.isBefore(end)) {
        final local = tz.TZDateTime.from(cursor, location),
            next = tz.TZDateTime(
              location,
              local.year,
              local.month,
              local.day + 1,
            ).toUtc(),
            stop = next.isBefore(end) ? next : end;
        if (!stop.isAfter(cursor))
          throw const FormatException('Invalid local day boundary');
        final date = local.toIso8601String().substring(0, 10),
            row = days.putIfAbsent(
              date,
              () => {
                'minutes': 0,
                'unknown': 0,
                'tasks': 0,
                'overloaded': dailyCapacity == null ? null : false,
              },
            );
        row['actualSeconds'] =
            (row['actualSeconds'] as int? ?? 0) +
            stop.difference(cursor).inSeconds;
        cursor = stop;
      }
    }
    unknown += (session.number('elapsed') - allocated).clamp(
      0,
      session.number('elapsed'),
    );
  }
  return {
    'days': days,
    'unallocatedActualSeconds': unknown,
    'runningSessions': running,
  };
}

BoardsState duplicateTask(BoardsState s, String id, {DateTime? now}) {
  final ids = taskDescendants(s, {id}),
      mapping = {for (final id in ids) id: newId()},
      edit = BoardsEdit(s),
      at = now ?? DateTime.now();
  for (final sourceId in ids) {
    final old = s.get('tasks', sourceId),
        base = newTask(
          s,
          old.str('board'),
          old.str('title'),
          category: old.data['category'],
        );
    edit.put(
      'tasks',
      base.copy({
        'id': mapping[sourceId],
        for (final key in [
          'notes',
          'priority',
          'estimate',
          'tags',
          'custom',
          'assignee',
          'start',
          'due',
          'kind',
        ])
          if (old.data.containsKey(key)) key: old.data[key],
        'parent': mapping[old.str('parent')],
        'created': at.toUtc().toIso8601String(),
        'updated': at.toUtc().toIso8601String(),
      }),
    );
    edit.event(mapping[sourceId]!, 'created', at);
  }
  for (final item
      in s.rows('checklist').where((r) => ids.contains(r.str('task'))))
    edit.put(
      'checklist',
      item.copy({
        'id': newId(),
        'task': mapping[item.str('task')],
        'done': false,
        'completedAt': null,
      }),
    );
  return edit.finish();
}

BoardsState addComment(
  BoardsState s,
  String task,
  String body, {
  required DateTime now,
}) {
  s.get('tasks', task);
  text(body, max: 10000, empty: false);
  return s.put(
    'events',
    BoardRecord({
      'id': newId(),
      'task': task,
      'action': 'comment',
      'at': now.toUtc().toIso8601String(),
      'body': body,
    }),
  );
}

BoardsState retainActivity(BoardsState s, int days, DateTime now) {
  if (days < 0 || days > 3650)
    throw const FormatException('Retention must be 0..3650 days');
  if (days == 0) return s;
  final cutoff = now.subtract(Duration(days: days));
  final remove = s
      .rows('events')
      .where(
        (r) =>
            r.str('action') != 'comment' &&
            DateTime.parse(r.str('at')).isBefore(cutoff),
      )
      .map((r) => r.id)
      .toSet();
  return s.remove('events', remove);
}

String presentGrade(double? percent, String scale, {Json letters = const {}}) {
  if (percent == null) return '—';
  if (!percent.isFinite || percent < 0 || percent > 100)
    throw const FormatException('Percentage out of bounds');
  if (scale == 'letter') {
    final thresholds = letters.entries.toList();
    if (thresholds.isEmpty)
      throw const FormatException('Define your own letter thresholds');
    for (final e in thresholds) {
      text(e.key, max: 20, empty: false);
      if (e.value is! num ||
          !(e.value as num).isFinite ||
          e.value < 0 ||
          e.value > 100)
        throw const FormatException('Invalid letter threshold');
    }
    thresholds.sort((a, b) => (b.value as num).compareTo(a.value as num));
    return thresholds.where((e) => percent >= e.value).firstOrNull?.key ?? '—';
  }
  final max = double.tryParse(scale);
  if (max == null || ![4.0, 10.0, 100.0].contains(max))
    throw const FormatException('Unsupported presentation scale');
  return '${(percent * max / 100).toStringAsFixed(2)} / ${max.toInt()}';
}

BoardsState assignTags(BoardsState s, String task, String commaSeparated) {
  final t = s.get('tasks', task),
      e = BoardsEdit(s),
      names = commaSeparated
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toSet();
  if (names.length > 100)
    throw const FormatException('At most 100 tags per task');
  final ids = <String>[];
  for (final name in names) {
    text(name, max: 100, empty: false);
    final existing = s
        .rows('tags')
        .where(
          (r) => r.str('board') == t.str('board') && r.str('title') == name,
        )
        .firstOrNull;
    final id = existing?.id ?? newId();
    if (existing == null)
      e.put(
        'tags',
        BoardRecord({'id': id, 'board': t.str('board'), 'title': name}),
      );
    ids.add(id);
  }
  e.put('tasks', t.copy({'tags': ids}));
  return e.finish();
}

List<BoardRecord> smartViewTasks(BoardsState s, BoardRecord view) {
  final conditions = (view.data['conditions'] as List? ?? [])
      .map(object)
      .toList();
  if (conditions.length > 30)
    throw const FormatException('View condition limit');
  final sets = [
    for (final c in conditions)
      queryTasks(
        s,
        board: view.str('board'),
        filter: c,
        includeTrash: true,
      ).map((t) => t.id).toSet(),
  ];
  return queryTasks(
        s,
        board: view.str('board'),
        search: view.str('search'),
        sort: view.str('sort', 'manual'),
        includeTrash: conditions.any((c) => c['archived'] == true),
      )
      .where(
        (t) =>
            !t.flag('trashed') &&
            (sets.isEmpty ||
                (view.str('mode', 'and') == 'or'
                    ? sets.any((set) => set.contains(t.id))
                    : sets.every((set) => set.contains(t.id)))),
      )
      .toList();
}

BoardsState applyBoardTemplate(
  BoardsState s,
  dynamic input, {
  required String title,
  bool confirmed = false,
  bool includeRecurrence = false,
}) {
  if (!confirmed) throw const FormatException('Review template first');
  final j = object(input);
  if (j['app'] != 'handy-boards-template' || j['schema'] != 1)
    throw const FormatException('Unsupported template');
  final cs = (j['categories'] as List).map(object).toList(),
      ss = (j['statuses'] as List).map(object).toList(),
      ts = (j['tasks'] as List).map(object).toList(),
      fs = (j['fields'] as List? ?? []).map(object).toList(),
      rs = (j['recurrence'] as List? ?? []).map(object).toList(),
      checks = (j['checklist'] as List? ?? []).map(object).toList();
  if (checks.length > 50000)
    throw const FormatException('Template checklist bounds');
  if (fs.length > 100 || rs.length > 10000)
    throw const FormatException('Template field/recurrence bounds');
  if (cs.length > 1000 || ss.isEmpty || ss.length > 100 || ts.length > 10000)
    throw const FormatException('Template bounds');
  final taskKeys = ts.map((t) => t['id']).whereType<String>().toSet();
  final ids = <String, String>{};
  for (final r in [
    ...cs,
    ...ss,
    ...fs,
    ...ts.where((r) => r['id'] != null),
    ...rs,
  ]) {
    final id = text(r['id'], empty: false);
    if (ids.containsKey(id))
      throw const FormatException('Duplicate template IDs');
    ids[id] = newId();
  }
  final b = newId(),
      base = createBoard(s, title, boardId: b),
      e = BoardsEdit(base);
  e.put(
    'boards',
    base.get('boards', b).copy({
      'zone': j['zone'] as String? ?? 'Asia/Ho_Chi_Minh',
    }),
  );
  for (final r in base.rows('statuses').where((r) => r.str('board') == b))
    e.remove('statuses', r.id);
  for (final r in cs)
    e.put(
      'categories',
      BoardRecord({
        'id': ids[r['id']],
        'board': b,
        'title': text(r['title'], empty: false),
        'color': r['color'] ?? 0,
        'order': r['order'] ?? 0,
        'preview': r['preview'] ?? 3,
        'priorityWeight': r['priorityWeight'] ?? 0,
      }),
    );
  for (final r in ss)
    e.put(
      'statuses',
      BoardRecord({
        'id': ids[r['id']],
        'board': b,
        'title': text(r['title'], empty: false),
        'done': r['done'] == true,
        'order': r['order'] ?? 0,
        'color': r['color'] ?? 7,
        'wip': r['wip'] ?? 0,
      }),
    );
  for (final f in fs)
    e.put(
      'fields',
      BoardRecord({
        'id': ids[f['id']],
        'board': b,
        for (final key in ['title', 'type', 'options', 'default'])
          if (f[key] != null) key: f[key],
      }),
    );
  final status = ss.firstWhere(
    (r) => r['done'] != true,
    orElse: () => ss.first,
  );
  for (final r in ts) {
    final category = r['category'];
    if (category != null && !cs.any((c) => c['id'] == category))
      throw const FormatException('Unknown template category');
    e.put(
      'tasks',
      BoardRecord({
        'id': ids[r['id']] ?? newId(),
        'board': b,
        'parent': r['parent'] == null
            ? null
            : ids[r['parent']] ??
                  (throw const FormatException('Missing template parent')),
        'category': ids[category],
        'status': ids[status['id']],
        'title': text(r['title'], empty: false),
        'priority': r['priority'] ?? 1,
        'estimate': r['estimate'] ?? 0,
        'kind': r['kind'] ?? 'task',
        'order': r['order'] ?? 0,
        'custom': {
          for (final f in fs)
            if (f['default'] != null) ids[f['id']]!: f['default'],
        },
      }),
    );
  }
  for (final c in checks) {
    if (!taskKeys.contains(c['task']))
      throw const FormatException('Missing template checklist task');
    e.put(
      'checklist',
      BoardRecord({
        'id': newId(),
        'task': ids[c['task']],
        'title': text(c['title'], empty: false),
        'order': c['order'] ?? 0,
        'done': false,
      }),
    );
  }
  if (includeRecurrence)
    for (final r in rs) {
      if (!taskKeys.contains(r['task']))
        throw const FormatException('Missing recurring template task');
      e.put(
        'recurrence',
        BoardRecord({
          'id': ids[r['id']],
          'board': b,
          'task': ids[r['task']],
          'enabled': false,
          for (final key in [
            'frequency',
            'start',
            'until',
            'interval',
            'count',
            'weekdays',
            'exceptions',
            'clock',
            'zone',
            'lateFold',
          ])
            if (r[key] != null) key: r[key],
        }),
      );
    }
  return e.finish();
}

Uint8List exportXlsx(BoardsState s, String board) {
  final tasks = queryTasks(s, board: board);
  if (tasks.length > 50000)
    throw const FormatException('XLSX exceeds 50000 tasks');
  String xml(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  final rows = <List<String>>[
    ['Task', 'Category', 'Status', 'Priority', 'Due', 'Estimate minutes'],
    for (final t in tasks)
      [
        t.str('title'),
        s.maybe('categories', t.data['category'])?.str('title') ?? '',
        s.get('statuses', t.str('status')).str('title'),
        '${t.number('priority')}',
        t.data['due'] == null ? '' : deadlineSort(object(t.data['due'])),
        '${t.number('estimate')}',
      ],
  ];
  final sheet = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (var i = 0; i < rows.length; i++) {
    sheet.write('<row r="${i + 1}">');
    for (var c = 0; c < rows[i].length; c++)
      sheet.write(
        '<c r="${String.fromCharCode(65 + c)}${i + 1}" t="inlineStr"><is><t xml:space="preserve">${xml(rows[i][c])}</t></is></c>',
      );
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');
  final files = {
    '[Content_Types].xml':
        '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
    '_rels/.rels':
        '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml':
        '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Tasks" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
    'xl/worksheets/sheet1.xml': sheet.toString(),
  };
  final a = Archive();
  for (final e in files.entries) {
    final b = utf8.encode(e.value);
    a.addFile(ArchiveFile(e.key, b.length, b));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}
