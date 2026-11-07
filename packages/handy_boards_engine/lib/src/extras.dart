part of '../handy_boards_engine.dart';

String recurrenceHorizon(BoardsState s, BoardRecord rule, DateTime now) =>
    calendarDate(
      localDay(now, rule.str('zone')),
    ).add(const Duration(days: 7)).toIso8601String().substring(0, 10);

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
