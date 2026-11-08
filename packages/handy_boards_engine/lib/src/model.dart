part of '../handy_boards_engine.dart';

class BoardRecord {
  final Json data;
  BoardRecord(Json input)
    : data = _freeze(jsonDecode(jsonEncode(input))) as Json {
    text(data['id'], max: 120, empty: false);
  }
  String get id => data['id'];
  String str(String key, [String fallback = '']) =>
      data[key] as String? ?? fallback;
  int number(String key, [int fallback = 0]) => data[key] as int? ?? fallback;
  bool flag(String key) => data[key] == true;
  List<String> strings(String key) =>
      (data[key] as List? ?? const []).cast<String>();
  BoardRecord copy(Json changes) => BoardRecord({...data, ...changes});
  Json toJson() => object(jsonDecode(jsonEncode(data)));
}

class BoardsState {
  final int revision;
  final Map<String, Map<String, BoardRecord>> records;
  final Json preferences;
  final Map<String, Uint8List> _files;
  final _related = <String, Map<String, List<BoardRecord>>>{};
  Iterable<BoardRecord> related(
    String kind,
    String id, {
    String field = 'task',
  }) {
    final key = '$kind/$field';
    final index = _related.putIfAbsent(key, () {
      final grouped = <String, List<BoardRecord>>{};
      for (final r in rows(kind))
        if (r.data[field] != null) (grouped[r.str(field)] ??= []).add(r);
      return Map.unmodifiable(
        grouped.map((k, v) => MapEntry(k, List<BoardRecord>.unmodifiable(v))),
      );
    });
    return index[id] ?? const <BoardRecord>[];
  }

  BoardsState._(this.revision, this.records, this.preferences, this._files);

  /// Only adapters providing immutable, version-addressable sources may use this.
  factory BoardsState.fromSnapshot({
    required int revision,
    required Map<String, BoardsSnapshotMap<BoardRecord>> data,
    required BoardsSnapshotMap<Uint8List> files,
    Json preferences = const {},
  }) {
    if (kinds.any((k) => !data.containsKey(k)))
      throw const FormatException('Incomplete snapshot');
    return BoardsState._(
      revision,
      Map.unmodifiable(data),
      _freeze(jsonDecode(jsonEncode(preferences))) as Json,
      files,
    );
  }
  BoardsState({
    this.revision = 0,
    Map<String, Iterable<BoardRecord>> data = const {},
    Json preferences = const {},
    Map<String, Uint8List> files = const {},
  }) : records = Map.unmodifiable({
         for (final kind in kinds)
           kind: Map<String, BoardRecord>.unmodifiable({
             for (final r in data[kind] ?? const <BoardRecord>[]) r.id: r,
           }),
       }),
       preferences = _freeze(jsonDecode(jsonEncode(preferences))) as Json,
       _files = Map.unmodifiable(
         files.map((k, v) => MapEntry(k, Uint8List.fromList(v))),
       ) {
    for (final e in data.entries) {
      if (!kinds.contains(e.key) || e.value.length != records[e.key]!.length)
        throw const FormatException('Unknown collection or duplicate ID');
    }
  }
  Iterable<BoardRecord> rows(String kind) =>
      records[kind]?.values ?? (throw ArgumentError('Unknown kind'));
  BoardRecord get(String kind, String id) =>
      records[kind]?[id] ?? (throw FormatException('Missing $kind record'));
  BoardRecord? maybe(String kind, String? id) => records[kind]?[id];
  Map<String, Uint8List> get files => Map.unmodifiable(
    _files.map((k, v) => MapEntry(k, Uint8List.fromList(v))),
  );
  Uint8List file(String path) => Uint8List.fromList(
    _files[path] ?? (throw const FormatException('Missing asset')),
  );
  bool hasFile(String path) => _files.containsKey(path);
  BoardsState withAssetSource(BoardsAssetMap files) =>
      BoardsState._(revision, records, preferences, files);
  BoardsState copy({
    Map<String, Iterable<BoardRecord>>? data,
    Json? preferences,
    Map<String, Uint8List>? files,
    int? revision,
  }) {
    if (data == null)
      return BoardsState._(
        revision ?? this.revision,
        records,
        preferences == null
            ? this.preferences
            : _freeze(jsonDecode(jsonEncode(preferences))) as Json,
        files == null
            ? _files
            : Map.unmodifiable(
                files.map((k, v) => MapEntry(k, Uint8List.fromList(v))),
              ),
      );
    final proposed = BoardsState(
      revision: revision ?? this.revision,
      data: data,
      preferences: preferences ?? this.preferences,
      files: files ?? const {},
    );
    // Existing bytes are privately owned; immutable snapshots can safely share
    // them. Public input/getters always copy, so Undo does not clone 300 MB.
    return files == null
        ? BoardsState._(
            proposed.revision,
            proposed.records,
            proposed.preferences,
            _files,
          )
        : proposed;
  }

  BoardsState put(String kind, BoardRecord record) {
    if (!kinds.contains(kind)) throw ArgumentError('Unknown collection');
    final values = _OverlayMap(records[kind]!)..[record.id] = record;
    return BoardsState._(
      revision,
      Map.unmodifiable({...records, kind: values.freeze()}),
      preferences,
      _files,
    );
  }

  BoardsState remove(String kind, Set<String> ids) {
    if (!kinds.contains(kind)) throw ArgumentError('Unknown collection');
    final values = _OverlayMap(records[kind]!);
    for (final id in ids) values.remove(id);
    return BoardsState._(
      revision,
      Map.unmodifiable({...records, kind: values.freeze()}),
      preferences,
      _files,
    );
  }

  Json toJson({bool includeFiles = true}) => {
    'app': 'handy-boards',
    'schema': 4,
    'revision': revision,
    'preferences': preferences,
    for (final k in kinds) k: rows(k).map((r) => r.data).toList(),
    if (includeFiles)
      'files': {for (final e in _files.entries) e.key: base64Encode(e.value)},
  };
  factory BoardsState.fromJson(dynamic input, {Map<String, Uint8List>? files}) {
    final j = object(input);
    if (j['app'] != 'handy-boards' || ![1, 2, 3, 4].contains(j['schema']))
      throw const FormatException('Unsupported Boards schema');
    final s = BoardsState(
      revision: j['revision'] as int? ?? 0,
      preferences: object(j['preferences'] ?? {}),
      data: {
        for (final k in kinds)
          k: ((j[k] ?? []) as List).map((r) => BoardRecord(object(r))),
      },
      files:
          files ??
          object(
            j['files'] ?? {},
          ).map((k, v) => MapEntry(k, base64Decode(v as String))),
    );
    s.validate();
    return s;
  }
  void validate() {
    if (revision < 0) throw const FormatException('Invalid revision');
    final ids = <String>{};
    for (final kind in kinds)
      for (final r in rows(kind)) {
        if (!ids.add(r.id))
          throw const FormatException(
            'IDs must be globally unique across kinds',
          );
        for (final key in ['title', 'name'])
          if (r.data[key] != null) text(r.data[key], max: 1000, empty: false);
        if (r.data['board'] != null) get('boards', r.str('board'));
        if (r.data['task'] != null) {
          final task = get('tasks', r.str('task'));
          if (r.data['board'] != null && r.str('board') != task.str('board'))
            throw const FormatException('Task board mismatch');
        }
      }
    for (final b in rows('boards')) {
      get('workspaces', b.str('workspace'));
      zone(b.str('zone', 'Asia/Ho_Chi_Minh'));
      if (b.data['workingCalendar'] != null)
        validateWorkingCalendar(object(b.data['workingCalendar']));
      final resources = object(b.data['resourceCalendars'] ?? {});
      if (resources.length > 100)
        throw const FormatException('At most 100 resource calendars');
      for (final entry in resources.entries) {
        text(entry.key, max: 1000, empty: false);
        validateWorkingCalendar(object(entry.value));
      }
      for (final weight in object(b.data['priorityWeights'] ?? {}).values)
        if (weight is! num || !weight.isFinite || weight < 0 || weight > 1000)
          throw const FormatException('Invalid priority weight');
    }
    for (final key in ['locale', 'theme'])
      if (preferences[key] != null && preferences[key] is! String)
        throw const FormatException('Invalid display preference');
    if (preferences['locale'] != null &&
            !['system', 'en', 'vi'].contains(preferences['locale']) ||
        preferences['theme'] != null &&
            !['system', 'light', 'dark'].contains(preferences['theme']))
      throw const FormatException('Invalid display preference');
    for (final key in ['notifications', 'homeWidget'])
      if (preferences[key] != null && preferences[key] is! bool)
        throw const FormatException('Invalid preferences');
    if (preferences['historyDays'] != null &&
        (preferences['historyDays'] is! int ||
            preferences['historyDays'] < 0 ||
            preferences['historyDays'] > 3650))
      throw const FormatException('Invalid activity retention');
    for (final value in object(preferences['tableColumns'] ?? {}).values)
      if (value is! List || value.any((v) => v is! String))
        throw const FormatException('Invalid table columns');
    for (final raw in object(preferences['categoryLayout'] ?? {}).values) {
      final layout = object(raw);
      if (layout['collapsed'] != null &&
          (layout['collapsed'] is! List ||
              (layout['collapsed'] as List).any((v) => v is! String)))
        throw const FormatException('Invalid collapsed category preferences');
    }
    for (final kind in kinds)
      for (final r in rows(kind)) {
        for (final key in [
          'order',
          'color',
          'wip',
          'priority',
          'estimate',
          'credits',
          'weekday',
          'startMinute',
          'endMinute',
          'elapsed',
          'interval',
          'count',
          'capacity',
        ])
          if (r.data[key] != null && r.data[key] is! int)
            throw FormatException('Invalid integer field: $key');
        for (final key in [
          'done',
          'archived',
          'trashed',
          'pinned',
          'enabled',
          'normalize',
          'lateFold',
          'reviewRequired',
          'delayed',
          'priorityEnabled',
        ])
          if (r.data[key] != null && r.data[key] is! bool)
            throw FormatException('Invalid boolean field: $key');
        if (kind == 'categories' &&
            r.data['preview'] != null &&
            (r.data['preview'] is! int ||
                (r.number('preview') < 0 || r.number('preview') > 3)))
          throw const FormatException('Preview 0..3');
        if (r.data['priorityWeight'] != null &&
            (r.data['priorityWeight'] is! num ||
                !(r.data['priorityWeight'] as num).isFinite ||
                r.data['priorityWeight'] < 0 ||
                r.data['priorityWeight'] > 1000))
          throw const FormatException('Category priority boost 0..1000');
      }
    for (final t in rows('tasks')) {
      get('boards', t.str('board'));
      text(t.data['title'], max: 1000, empty: false);
      text(t.data['notes'] ?? '', max: 100000);
      if (t.data['exam'] != null) {
        final exam = object(t.data['exam']), duration = exam['durationMinutes'];
        if (duration != null &&
            (duration is! int || duration < 1 || duration > 1440))
          throw const FormatException('Exam duration 1..1440 minutes');
        text(exam['location'] ?? '', max: 1000);
        text(exam['materials'] ?? '', max: 10000);
      }
      final status = get('statuses', t.str('status'));
      if (t.data['suggestedStatus'] != null &&
          get('statuses', t.str('suggestedStatus')).str('board') !=
              t.str('board'))
        throw const FormatException('Suggested status outside board');
      if (status.str('board') != t.str('board'))
        throw const FormatException('Status is outside task board');
      for (final field in ['category', 'parent'])
        if (t.data[field] != null) {
          final ref = get(
            field == 'category' ? 'categories' : 'tasks',
            t.str(field),
          );
          if (ref.str('board') != t.str('board') || ref.id == t.id)
            throw const FormatException('Invalid category or parent');
        }
      for (final tag in t.strings('tags'))
        if (get('tags', tag).str('board') != t.str('board'))
          throw const FormatException('Tag board mismatch');
      if (t.number('priority') < 0 ||
          t.number('priority') > 3 ||
          t.number('estimate') < 0 ||
          t.number('estimate') > 525600)
        throw const FormatException('Invalid priority/estimate');
      for (final key in ['start', 'due'])
        if (t.data[key] != null) validateDeadline(object(t.data[key]));
      if (t.data['start'] != null && t.data['due'] != null) {
        final a = object(t.data['start']), b = object(t.data['due']);
        if (a['kind'] == b['kind'] &&
            deadlineSort(a).compareTo(deadlineSort(b)) > 0)
          throw const FormatException('Start follows due');
        if (a['kind'] != b['kind']) {
          final name = get('boards', t.str('board')).str('zone');
          if (deadlineDay(a, name).compareTo(deadlineDay(b, name)) > 0)
            throw const FormatException('Start follows due');
        }
      }
    }
    for (final c in rows('checklist')) {
      get('tasks', c.str('task'));
      text(c.data['title'], empty: false);
    }
    for (final d in rows('dependencies')) {
      final a = get('tasks', d.str('before')), b = get('tasks', d.str('after'));
      if (a.str('board') != b.str('board') || a.id == b.id)
        throw const FormatException('Invalid dependency');
    }
    _acyclic({
      for (final t in rows('tasks'))
        t.id: t.data['parent'] == null ? <String>[] : [t.str('parent')],
    });
    final edges = <String, List<String>>{};
    final depths = <String, int>{};
    for (final task in rows('tasks')) {
      final path = <String>[];
      BoardRecord? node = task;
      while (node != null && !depths.containsKey(node.id)) {
        path.add(node.id);
        if (path.length > 32)
          throw const FormatException('Subtask depth exceeds 32');
        node = maybe('tasks', node.data['parent']);
      }
      var depth = node == null ? 0 : depths[node.id]!;
      for (final id in path.reversed) {
        depths[id] = ++depth;
        if (depth > 32) throw const FormatException('Subtask depth exceeds 32');
      }
    }
    for (final d in rows('dependencies'))
      (edges[d.str('after')] ??= []).add(d.str('before'));
    _acyclic(edges);
    for (final r in rows('reminders')) {
      get('tasks', r.str('task'));
      _instant(r.str('at'));
    }
    for (final r in rows('recurrence')) {
      validateRecurrence(r);
      final t = get('tasks', r.str('task'));
      if (r.data['status'] != null &&
          get('statuses', r.str('status')).str('board') != t.str('board'))
        throw const FormatException('Recurrence status mismatch');
    }
    for (final r in rows('occurrences')) {
      get('recurrence', r.str('rule'));
      get('tasks', r.str('task'));
      day(r.str('day'));
    }
    for (final r in rows('sessions')) {
      get('tasks', r.str('task'));
      if (r.number('elapsed') < 0)
        throw const FormatException('Invalid work duration');
      if (r.data['runningAt'] != null) _instant(r.str('runningAt'));
      var allocated = 0;
      for (final raw in r.data['segments'] as List? ?? []) {
        final segment = object(raw),
            start = _instant(segment['start']),
            end = _instant(segment['end']),
            seconds = end.difference(start).inSeconds;
        if (seconds < 0 || seconds > 86400 || segment['seconds'] != seconds)
          throw const FormatException('Invalid focus segment');
        allocated += seconds;
      }
      if (allocated > r.number('elapsed'))
        throw const FormatException('Focus segments exceed saved duration');
    }
    for (final f in rows('fields')) validateField(this, f);
    for (final t in rows('tasks')) validateCustomValues(this, t);
    for (final g in rows('grades')) {
      validateGrade(g);
      get('categories', g.str('category'));
    }
    for (final view in rows('views')) {
      if (![
            'manual',
            'due',
            'priority',
            'title',
            'created',
            'updated',
          ].contains(view.str('sort', 'manual')) ||
          ![
            'flat',
            'category',
            'status',
            'date',
          ].contains(view.str('group', 'flat')))
        throw const FormatException('Unsupported saved view layout');
      if (!['and', 'or'].contains(view.str('mode', 'and')) ||
          (view.data['conditions'] as List? ?? []).length > 30)
        throw const FormatException('Invalid smart view');
      for (final raw in view.data['conditions'] as List? ?? []) {
        final condition = object(raw);
        validateTaskFilter(condition);
        for (final entry in condition.entries)
          if (['category', 'status', 'tag'].contains(entry.key) &&
              entry.value != null) {
            final kind = entry.key == 'category'
                ? 'categories'
                : entry.key == 'status'
                ? 'statuses'
                : 'tags';
            if (get(kind, entry.value as String).str('board') !=
                view.str('board'))
              throw const FormatException('Smart view scope mismatch');
          }
      }
    }
    for (final kind in ['events', 'executions'])
      for (final r in rows(kind)) {
        get('tasks', r.str('task'));
        _instant(r.str('at'));
      }
    for (final r in rows('executions')) get('rules', r.str('rule'));
    for (final c in rows('classes')) {
      get('categories', c.str('category'));
      zone(c.str('zone'));
      if (c.number('weekday') < 1 ||
          c.number('weekday') > 7 ||
          c.number('startMinute') < 0 ||
          c.number('endMinute') > 1440 ||
          c.number('endMinute') <= c.number('startMinute'))
        throw const FormatException('Invalid class session');
    }
    for (final subject in rows('subjects'))
      get('categories', subject.str('category'));
    for (final rule in rows('rules')) validateAutomation(this, rule);
    var bytes = 0;
    final assetDescriptors = <String, Json>{};
    for (final path in _files.keys) {
      final info = _assetDescriptor(_files, path)!;
      assetDescriptors[path] = info;
      if (!RegExp(
            r'^assets/[a-zA-Z0-9_-]{1,120}\.[a-z0-9]{1,8}$',
          ).hasMatch(path) ||
          info['bytes'] is! int ||
          info['bytes'] < 0 ||
          info['bytes'] > 12000000 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(info['sha256'] as String))
        throw const FormatException('Invalid managed asset');
      bytes += info['bytes'] as int;
    }
    if (bytes > 300000000)
      throw const FormatException('Managed assets exceed 300 MB');
    for (final a in rows('attachments')) {
      get('tasks', a.str('task'));
      if (a.data['path'] != null) {
        final info = assetDescriptors[a.str('path')];
        if (info == null || info['sha256'] != a.str('sha256'))
          throw const FormatException('Attachment checksum mismatch');
      } else
        safeUrl(a.str('url'));
    }
    if (!['en', 'vi', 'system'].contains(preferences['locale'] ?? 'system') ||
        !['light', 'dark', 'system'].contains(preferences['theme'] ?? 'system'))
      throw const FormatException('Invalid preferences');
    validateKanban(this);
  }
}

void _acyclic(Map<String, List<String>> edges) {
  final nodes = {...edges.keys, ...edges.values.expand((v) => v)},
      degree = <String, int>{},
      reverse = <String, List<String>>{};
  for (final n in nodes) degree[n] = edges[n]?.length ?? 0;
  for (final e in edges.entries)
    for (final p in e.value) (reverse[p] ??= []).add(e.key);
  final queue = nodes.where((n) => degree[n] == 0).toList();
  var count = 0;
  for (var i = 0; i < queue.length; i++) {
    count++;
    for (final n in reverse[queue[i]] ?? const <String>[])
      if ((degree[n] = degree[n]! - 1) == 0) queue.add(n);
  }
  if (count != nodes.length) throw const FormatException('Cycle detected');
}

DateTime _instant(String v) {
  if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(v))
    throw const FormatException('Timezone offset required');
  final d = DateTime.parse(v);
  if (d.year < 1900 || d.year > 2200)
    throw const FormatException('Invalid instant');
  return d;
}

void validateDeadline(Json d) {
  if (d['kind'] == 'day') {
    day(d['day'] as String);
  } else if (d['kind'] == 'time') {
    _instant(d['at'] as String);
    zone(d['zone'] as String);
  } else
    throw const FormatException('Invalid deadline');
}

String deadlineSort(Json d) => d['kind'] == 'day'
    ? d['day'] as String
    : _instant(d['at']).toUtc().toIso8601String();
String deadlineDay(Json d, String viewZone) =>
    d['kind'] == 'day' ? d['day'] : localDay(_instant(d['at']), viewZone);
Uri safeUrl(String v) {
  final u = Uri.tryParse(v);
  if (u == null ||
      !['http', 'https'].contains(u.scheme) ||
      u.host.isEmpty ||
      u.userInfo.isNotEmpty)
    throw const FormatException('HTTP(S) URL required');
  return u;
}
