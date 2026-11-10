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
        ![1, 2, 3, 4, habitSchema].contains(manifest['schema']) ||
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
  RoutineStep step(RoutineStep s) => s.copy({
    'id': stepId(s.id),
    'habit': s.habit == null ? null : habits[s.habit],
  });
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
        }),
      )
      .toList();
  final incomingSessions = imported.sessions
      .map(
        (s) => s.copy({
          'id': sessions[s.id],
          'routine': routines[s.routine] ?? uid(),
          'anchor': null,
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
              'schema': byId[e.habit]!.isNegative ? habitSchema : 1,
              'entry': e.toJson(),
              if (byId[e.habit]!.isNegative && metadataSent.add(e.habit))
                'negativeHabit': byId[e.habit]!.toJson(),
            }),
          ),
        ),
      ],
  ].map((row) => row.map(_csvCell).join(',')).join('\r\n');
  if (pauses.isEmpty) return logs;
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
  return '$logs\r\n\r\n$table';
}

/// Adds the records (and pauses) of a Habit CSV. Every row is checked
/// against its portable record first; nothing is written on a refusal.
HabitState importCsvLogs(HabitState current, Uint8List bytes) {
  if (bytes.length > backupLimit) throw const FormatException('CSV limit');
  final rows = csvParse(utf8.decode(bytes));
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
    if (![2, 3, 4, habitSchema].contains(record['schema']))
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
}) {
  String escape(String v) => v.replaceAll('|', r'\|').replaceAll('\n', ' ');
  final index = HabitIndex.of(s);
  final headers = vietnamese
      ? 'Thói quen | Hoàn thành | Hợp lệ | Chuỗi'
      : 'Habit | Completed | Eligible | Streak';
  final note = vietnamese
      ? 'Ngày bỏ qua không phải thành công. Kỳ hiện tại chưa đóng không phải thất bại.'
      : 'Skipped dates are neutral, not successes. Open current periods are not failures.';
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
    final m = metrics(h, until, s.weekStart, index, from: from);
    final unit = vietnamese ? (m.unit == 'weeks' ? 'tuần' : 'ngày') : m.unit;
    return '| ${escape(h.title)} | ${m.completed} | ${m.eligible} | ${m.current} $unit |';
  }).join('\n')}\n\n$note\n$pauseSection';
}
