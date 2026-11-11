part of '../handy_habit_engine.dart';

const backupLimit = 30000000;
Uint8List backup(HabitState s, {bool zip = true}) {
  s.validate();
  final data = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        ...s.toJson(),
        'backupCreatedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    ),
  );
  if (data.length > backupLimit - 4096)
    throw const FormatException('Backup exceeds 30MB');
  if (!zip) return data;
  final manifest = utf8.encode(
    jsonEncode({
      'app': 'handy-habit',
      'schema': habitSchema,
      'files': {'data.json': sha256.convert(data).toString()},
      'assets': [],
    }),
  );
  return Uint8List.fromList(
    ZipEncoder().encode(
      Archive()
        ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
        ..addFile(ArchiveFile('data.json', data.length, data)),
    ),
  );
}

class HabitBackupPreview {
  final HabitState state;
  final int size, schema;
  final String? createdAt;
  HabitBackupPreview(this.state, this.size, this.schema, this.createdAt);
}

HabitState restore(Uint8List bytes, {bool zip = true}) =>
    inspectBackup(bytes, zip: zip).state;
HabitBackupPreview inspectBackup(Uint8List bytes, {bool zip = true}) {
  if (bytes.length > backupLimit)
    throw const FormatException('Backup exceeds 30MB');
  var data = bytes;
  int? manifestSchema;
  if (zip) {
    final files = decodePortableZip(
      bytes,
      isAllowedPath: (p) => p == 'manifest.json' || p == 'data.json',
      maxEntries: 2,
      maxEntryBytes: backupLimit - 4096,
    );
    if (files.length != 2) throw const FormatException('Missing backup files');
    final manifest = jsonDecode(utf8.decode(files['manifest.json']!)) as Map;
    if (manifest['app'] != 'handy-habit' ||
        ![1, 2, 3, 4, 5, 6, 7, 8, habitSchema].contains(manifest['schema']) ||
        (manifest['files'] as Map)['data.json'] !=
            sha256.convert(files['data.json']!).toString())
      throw const FormatException('Backup checksum mismatch');
    data = files['data.json']!;
    manifestSchema = manifest['schema'] as int;
  }
  final raw = Map<String, dynamic>.from(jsonDecode(utf8.decode(data)) as Map);
  if (manifestSchema != null && manifestSchema != raw['schema'])
    throw const FormatException('Backup schema mismatch');
  return HabitBackupPreview(
    HabitState.fromJson(raw),
    bytes.length,
    integer(raw['schema'], min: 1),
    raw['backupCreatedAt'] == null ? null : timestamp(raw['backupCreatedAt']),
  );
}

HabitState merge(HabitState current, HabitState imported) {
  // Date identities cannot be remapped. Refuse conflicting reflections rather
  // than silently replacing either person's text (including deleted entries).
  final moods = {for (final m in current.moods) m.day: m};
  for (final m in imported.moods) {
    if (moods[m.day] != null && !_same(moods[m.day]!.toJson(), m.toJson())) {
      throw const FormatException(
        'Conflicting mood date; existing data preserved / Tâm trạng cùng ngày khác nhau; giữ nguyên dữ liệu',
      );
    }
    moods[m.day] = m;
  }
  // All imported identities are remapped: never overwrite a live event/session.
  final existingBatches = List<String>.from(
        current.settings['imports'] as List? ?? [],
      ),
      digest = sha256
          .convert(utf8.encode(_canonical(imported.toJson())))
          .toString();
  if (existingBatches.contains(digest))
    throw const FormatException('This backup was already merged');
  if (imported.sessions.any((s) => s.status == 'active') &&
      current.sessions.any((s) => s.status == 'active'))
    throw const FormatException('Resolve one active session before merging');
  final habits = {for (final h in imported.habits) h.id: uid()},
      routines = {for (final r in imported.routines) r.id: uid()},
      sessions = {for (final s in imported.sessions) s.id: uid()},
      events = {for (final e in imported.events) e.id: uid()},
      steps = <String, String>{};
  String stepId(String id) => steps.putIfAbsent(id, uid);
  final blocks = <String, String>{};
  String blockId(String id) => blocks.putIfAbsent(id, uid);
  RoutineStep step(RoutineStep s) => s.copy({
    'id': stepId(s.id),
    'habit': s.habit == null ? null : habits[s.habit],
    'logic': {
      ...s.logic.toJson(),
      'dependencies': s.logic.dependencies.map(stepId).toList(),
      'stackAfter': s.logic.stackAfter == null
          ? null
          : stepId(s.logic.stackAfter!),
      'habitNotDone': s.logic.habitNotDone == null
          ? null
          : habits[s.logic.habitNotDone] ?? s.logic.habitNotDone,
      'block': s.logic.block.isEmpty ? '' : blockId(s.logic.block),
    },
  });
  Json block(StepBlock b) => {
    ...b.toJson(),
    'id': blockId(b.id),
    'steps': b.steps.map((s) => step(s).toJson()).toList(),
  };
  Json inputs(Json i) => i.isEmpty
      ? {}
      : {
          ...i,
          'doneHabits': [
            for (final h in i['doneHabits'] as List? ?? []) habits[h] ?? h,
          ],
          for (final key in ['habitValues', 'habitTargets', 'habitTitles'])
            key: <String, dynamic>{
              for (final e in (i[key] as Map? ?? {}).entries)
                (habits[e.key] ?? e.key as String): e.value,
            },
        };
  Json trace(Json entry) => {
    ...entry,
    if (entry['step'] != null) 'step': stepId(entry['step'] as String),
    if (entry['event'] != null) 'event': events[entry['event']],
    if (entry['plan'] != null)
      'plan': [
        for (final p in objects(entry['plan']))
          step(RoutineStep.fromJson(p)).toJson(),
      ],
    if (entry['inputs'] != null)
      'inputs': inputs(Map<String, dynamic>.from(entry['inputs'] as Map)),
    if (entry['doneHabits'] != null)
      'doneHabits': [
        for (final h in entry['doneHabits'] as List) habits[h] ?? h,
      ],
  };
  final incomingHabits = imported.habits
      .map(
        (h) => h.copy({
          'id': habits[h.id],
          'schedules': [
            for (final s in h.schedules) {...s.toJson(), 'id': uid()},
          ],
        }),
      )
      .toList();
  final incomingRoutines = imported.routines
      .map(
        (r) => r.copy({
          'id': routines[r.id],
          'steps': r.steps.map((s) => step(s).toJson()).toList(),
          'blocks': r.blocks.map(block).toList(),
          'presets': r.presets.map(block).toList(),
        }),
      )
      .toList();
  final incomingSessions = imported.sessions
      .map(
        (s) => s.copy({
          'id': sessions[s.id],
          'routine': routines[s.routine] ?? uid(),
          'anchor': null,
          'inputs': inputs(s.inputs),
          'trace': s.trace.map(trace).toList(),
          'steps': [
            for (final v in s.steps)
              {
                ...v.toJson(),
                'plan': step(v.plan).toJson(),
                'event': v.event == null ? null : events[v.event],
              },
          ],
        }),
      )
      .toList();
  final incomingEvents = imported.events
      .map(
        (e) => HabitEvent.fromJson({
          ...e.toJson(),
          'id': events[e.id],
          'habit': habits[e.habit],
          'session': e.session == null ? null : sessions[e.session],
          'step': e.step == null ? null : stepId(e.step!),
        }),
      )
      .toList();
  final incomingPauses = [
    for (final p in imported.pauses)
      p.copy({
        'id': uid(),
        'habits': [for (final h in p.habits) habits[h]],
      }),
  ];
  final eventById = {for (final e in incomingEvents) e.id: e};
  final fixedSessions = incomingSessions
      .map(
        (session) => session.copy({
          'recoveryWarning':
              session.status == 'active' || session.recoveryWarning,
          'steps': session.steps
              .map(
                (step) => step.copy({
                  'eventHash':
                      step.event == null || !eventById.containsKey(step.event)
                      ? null
                      : sha256
                            .convert(
                              utf8.encode(
                                jsonEncode(eventById[step.event]!.toJson()),
                              ),
                            )
                            .toString(),
                }).toJson(),
              )
              .toList(),
        }),
      )
      .toList();
  return current.copy({
    'moods': moods.values.map((m) => m.toJson()).toList(),
    'trash': [
      ...current.trash.map((t) => t.toJson()),
      for (final t in imported.trash)
        {
          ...t.toJson(),
          'id': uid(),
          'entity': t.kind == 'habit' ? habits[t.entity] : routines[t.entity],
        },
    ],
    'tombstones': [
      ...current.tombstones,
      for (final t in imported.tombstones) {...t, 'id': uid(), 'entity': uid()},
    ],
    'operations': [
      ...current.operations.map((o) => o.toJson()),
      ...legacyOperations({
        'events': incomingEvents.map((e) => e.toJson()).toList(),
      }),
    ],
    'habits': [
      ...current.habits.map((e) => e.toJson()),
      ...incomingHabits.map((e) => e.toJson()),
    ],
    'events': [
      ...current.events.map((e) => e.toJson()),
      ...incomingEvents.map((e) => e.toJson()),
    ],
    'routines': [
      ...current.routines.map((e) => e.toJson()),
      ...incomingRoutines.map((e) => e.toJson()),
    ],
    'sessions': [
      ...current.sessions.map((e) => e.toJson()),
      ...fixedSessions.map((e) => e.toJson()),
    ],
    'pauses': [
      ...current.pauses.map((e) => e.toJson()),
      ...incomingPauses.map((e) => e.toJson()),
    ],
    'settings': {
      ...current.settings,
      if (current.settings['habitDayParts'] != null ||
          imported.settings['habitDayParts'] != null)
        'habitDayParts': <String, dynamic>{
          ...Map<String, dynamic>.from(
            current.settings['habitDayParts'] as Map? ?? {},
          ),
          for (final entry
              in (imported.settings['habitDayParts'] as Map? ?? {}).entries)
            if (habits.containsKey(entry.key)) habits[entry.key]!: entry.value,
        },
      'imports': [...existingBatches, digest],
      'reminders': [
        ...objects(current.settings['reminders'] ?? []),
        for (final r in objects(imported.settings['reminders'] ?? []))
          {
            ...r,
            'id': uid(),
            'target': r['type'] == 'habit'
                ? habits[r['target']]
                : routines[r['target']],
            'enabled': false,
          },
      ],
    },
  });
}

String _csvCell(String v) => '"${_csvSafe(v).replaceAll('"', '""')}"';
String _csvSafe(String v) => RegExp(r'^[\s]*[=+@\-]').hasMatch(v) ? "'$v" : v;

const _moodHeader = [
  'mood_id',
  'local_date',
  'mood',
  'energy',
  'note',
  'tags',
  'revision',
  'recorded_at',
  'updated_at',
  'deleted_at',
  'record_b64',
];
List<String> _moodCells(MoodEntry m) => [
  m.id,
  m.day,
  '${m.mood}',
  m.energy == null ? '' : '${m.energy}',
  m.note,
  jsonEncode(m.tags),
  '${m.revision}',
  m.recordedAt,
  m.updatedAt,
  m.deletedAt ?? '',
];

const _pauseHeader = [
  'pause_id',
  'from',
  'until',
  'scope',
  'habit_ids',
  'habits',
  'reason',
  'record_b64',
];

/// The visible cells of a pause row, before the portable record.
List<String> _pauseCells(Pause p, Map<String, String> names) => [
  p.id,
  p.from,
  p.until,
  p.everything ? 'all' : 'chosen',
  p.habits.join(' '),
  p.habits.map((h) => names[h] ?? '').join('; '),
  p.reason,
];

/// Records in the range, then (when any overlap the range) the pauses as
/// a second table after a blank line, with their own header.
String csvLogs(HabitState s, String from, String until) {
  final names = {for (final h in s.habits) h.id: h.title};
  final byId = {for (final h in s.habits) h.id: h};
  final metadataSent = <String>{};
  final pauses = s.pauses.where(
    (p) => p.until.compareTo(from) >= 0 && p.from.compareTo(until) <= 0,
  );
  final logs = [
    [
      'id',
      'habit_id',
      'habit',
      'local_date',
      'value_milli',
      'source',
      'skipped',
      'session_id',
      'step_id',
      'note',
      'updated_at',
      'record_b64',
    ],
    for (final e in s.events.where(
      (e) => e.day.compareTo(from) >= 0 && e.day.compareTo(until) <= 0,
    ))
      [
        e.id,
        e.habit,
        names[e.habit] ?? '',
        e.day,
        '${e.value}',
        e.source,
        '${e.skipped}',
        e.session ?? '',
        e.step ?? '',
        e.note,
        e.updated,
        base64Encode(
          utf8.encode(
            jsonEncode({
              'schema': byId[e.habit]!.isNegative ? 5 : 1,
              'entry': e.toJson(),
              if (byId[e.habit]!.isNegative && metadataSent.add(e.habit))
                'negativeHabit': byId[e.habit]!.toJson(),
            }),
          ),
        ),
      ],
  ].map((row) => row.map(_csvCell).join(',')).join('\r\n');
  final moods = s.moods.where(
    (m) => m.day.compareTo(from) >= 0 && m.day.compareTo(until) <= 0,
  );
  final moodTable = moods.isEmpty
      ? ''
      : '\r\n\r\n${[
          _moodHeader,
          for (final m in moods) [
              ..._moodCells(m),
              base64Encode(utf8.encode(jsonEncode({'schema': habitSchema, 'mood': m.toJson()}))),
            ],
        ].map((r) => r.map(_csvCell).join(',')).join('\r\n')}';
  if (pauses.isEmpty) return '$logs$moodTable';
  final table = [
    _pauseHeader,
    for (final p in pauses)
      [
        ..._pauseCells(p, names),
        base64Encode(
          utf8.encode(jsonEncode({'schema': habitSchema, 'pause': p.toJson()})),
        ),
      ],
  ].map((row) => row.map(_csvCell).join(',')).join('\r\n');
  return '$logs\r\n\r\n$table$moodTable';
}

/// Adds the records (and pauses) of a Habit CSV. Every row is checked
/// against its portable record first; nothing is written on a refusal.
HabitState importCsvLogs(HabitState current, Uint8List bytes) {
  if (bytes.length > backupLimit) throw const FormatException('CSV limit');
  final rows = csvParse(utf8.decode(bytes));
  final moodSplit = rows.indexWhere(
    (r) => jsonEncode(r) == jsonEncode(_moodHeader),
  );
  final moodRows = moodSplit < 0
      ? <List<String>>[]
      : rows.sublist(moodSplit + 1);
  if (moodSplit >= 0) rows.removeRange(moodSplit, rows.length);
  final moods = {for (final m in current.moods) m.day: m};
  for (final row in moodRows) {
    if (row.length != _moodHeader.length)
      throw const FormatException('Wrong mood CSV column count');
    final record = jsonDecode(utf8.decode(base64Decode(row.last))) as Map;
    if (![6, 7, habitSchema].contains(record['schema']))
      throw const FormatException('Unknown mood record schema');
    final m = MoodEntry.fromJson(
      Map<String, dynamic>.from(record['mood'] as Map),
    );
    if (jsonEncode(row.take(row.length - 1).toList()) !=
        jsonEncode(_moodCells(m).map(_csvSafe).toList())) {
      throw const FormatException(
        'Mood CSV visible values differ from portable record',
      );
    }
    if (moods[m.day] != null && !_same(moods[m.day]!.toJson(), m.toJson())) {
      throw const FormatException(
        'Conflicting mood date; existing data preserved / Tâm trạng cùng ngày khác nhau; giữ nguyên dữ liệu',
      );
    }
    moods[m.day] = m;
  }
  final expected = csvParse(
    csvLogs(HabitState(), '1900-01-01', '2200-12-31'),
  ).first;
  if (jsonEncode(rows.first) != jsonEncode(expected))
    throw const FormatException('Unknown Habit CSV schema');
  final split = rows.indexWhere(
    (r) => jsonEncode(r) == jsonEncode(_pauseHeader),
  );
  final logRows = rows.sublist(1, split < 0 ? rows.length : split),
      pauseRows = split < 0 ? <List<String>>[] : rows.sublist(split + 1);
  final habits = {for (final h in current.habits) h.id: h};
  final entries = {for (final e in current.events) e.id: e};
  for (final row in logRows) {
    if (row.length != expected.length)
      throw const FormatException('Wrong CSV column count');
    final record = jsonDecode(utf8.decode(base64Decode(row.last))) as Map;
    if (![1, 5].contains(record['schema']))
      throw const FormatException('Unknown log record schema');
    final e = HabitEvent.fromJson(
      Map<String, dynamic>.from(record['entry'] as Map),
    );
    if (record['schema'] == 5) {
      final h = record['negativeHabit'] == null
          ? habits[e.habit]
          : Habit.fromJson(
              Map<String, dynamic>.from(record['negativeHabit'] as Map),
            );
      if (h == null ||
          !h.isNegative ||
          h.id != e.habit ||
          habits[h.id] != null && !_same(habits[h.id]!.toJson(), h.toJson()))
        throw const FormatException('Conflicting negative habit in CSV');
      habits[h.id] = h;
    } else if (habits[e.habit]?.isNegative == true) {
      throw const FormatException('Negative log requires its goal metadata');
    }
    final values = [
      e.id,
      e.habit,
      row[2],
      e.day,
      '${e.value}',
      e.source,
      '${e.skipped}',
      e.session ?? '',
      e.step ?? '',
      e.note,
      e.updated,
    ];
    for (var i = 0; i < values.length; i++) {
      if (i != 2 && row[i] != _csvSafe(values[i]))
        throw const FormatException(
          'CSV visible values differ from portable record; edit in app',
        );
    }
    final old = entries[e.id];
    if (old != null && jsonEncode(old.toJson()) != jsonEncode(e.toJson()))
      throw const FormatException(
        'Conflicting log ID; existing data preserved',
      );
    entries[e.id] = e;
  }
  final pauses = {for (final p in current.pauses) p.id: p};
  for (final row in pauseRows) {
    if (row.length != _pauseHeader.length)
      throw const FormatException('Wrong CSV column count');
    final record = jsonDecode(utf8.decode(base64Decode(row.last))) as Map;
    if (![2, 3, 4, 5, 6, 7, habitSchema].contains(record['schema']))
      throw const FormatException('Unknown pause record schema');
    final p = Pause.fromJson(Map<String, dynamic>.from(record['pause'] as Map));
    // Habit names (column 5) may differ between devices; IDs may not.
    final visible = _pauseCells(p, const {});
    for (var i = 0; i < visible.length; i++) {
      if (i != 5 && row[i] != _csvSafe(visible[i]))
        throw const FormatException(
          'CSV visible values differ from portable record; edit in app',
        );
    }
    final old = pauses[p.id];
    if (old != null && jsonEncode(old.toJson()) != jsonEncode(p.toJson()))
      throw const FormatException(
        'Conflicting pause ID; existing data preserved',
      );
    pauses[p.id] = p;
  }
  return current.copy({
    'moods': moods.values.map((m) => m.toJson()).toList(),
    'habits': habits.values.map((h) => h.toJson()).toList(),
    'events': entries.values.map((e) => e.toJson()).toList(),
    'pauses': pauses.values.map((p) => p.toJson()).toList(),
  });
}

String markdownReport(
  HabitState s,
  String from,
  String until, {
  bool vietnamese = false,
  String? today,
}) {
  String escape(String v) => v.replaceAll('|', r'\|').replaceAll('\n', ' ');
  final index = HabitIndex.of(s);
  final asOf = today ?? until;
  final headers = vietnamese
      ? 'Thói quen | Hoàn thành | Hợp lệ | Chuỗi'
      : 'Habit | Completed | Eligible | Streak';
  final note = vietnamese
      ? 'Bỏ qua ngày nghỉ, ngày chưa rõ và khoảng chưa kết thúc. Giới hạn tuần tính số lần đã ghi; khi hết tuần, ngày trống hiểu là không có.'
      : 'Pauses, skips, unknown daily dates and unfinished periods are left out. Weekly limits count recorded incidents, with blanks treated as none when the week closes.';
  final pauseNote = vietnamese
      ? 'Ngày nghỉ chưa làm không tính vào đâu; ngày nghỉ vẫn làm thì vẫn tính. Hạn mức tuần giảm theo số ngày nghỉ, làm tròn lên.'
      : 'Paused days not done are left out; a paused day done anyway still counts. Weekly quotas shrink with paused days, rounded up.';
  final names = {for (final h in s.habits) h.id: h.title};
  final pauses =
      s.pauses
          .where(
            (p) => p.until.compareTo(from) >= 0 && p.from.compareTo(until) <= 0,
          )
          .toList()
        ..sort((a, b) => a.from.compareTo(b.from));
  final pauseLines = pauses.map((p) {
    final who = p.everything
        ? (vietnamese ? 'Tất cả thói quen' : 'All habits')
        : p.habits.map((h) => escape(names[h] ?? '')).join(', ');
    final why = p.reason.isEmpty ? '' : ' · ${escape(p.reason)}';
    return '- ${p.from} — ${p.until} · $who$why';
  });
  final pauseSection = pauses.isEmpty
      ? ''
      : '\n## ${vietnamese ? 'Kỳ nghỉ' : 'Pauses'}\n\n${pauseLines.join('\n')}\n\n$pauseNote\n';
  return '# Handy Habit\n\n$from — $until · ${s.zone}\n\n| $headers |\n| --- | ---: | ---: | ---: |\n${s.habits.map((h) {
    final m = metrics(h, asOf, s.weekStart, index);
    final c = progressCount(h, from, until, asOf, index);
    final unit = vietnamese ? (m.unit == 'weeks' ? 'tuần' : 'ngày') : m.unit;
    return '| ${escape(h.title)} | ${c.kept} | ${c.eligible} | ${m.current} $unit |';
  }).join('\n')}\n\n$note\n$pauseSection';
}
