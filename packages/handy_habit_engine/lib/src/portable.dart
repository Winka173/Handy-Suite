part of '../handy_habit_engine.dart';

const backupLimit = 30000000;
Uint8List backup(HabitState s, {bool zip = true}) {
  s.validate();
  final data = Uint8List.fromList(utf8.encode(jsonEncode(s.toJson())));
  if (data.length > backupLimit - 4096)
    throw const FormatException('Backup exceeds 30MB');
  if (!zip) return data;
  final manifest = utf8.encode(
    jsonEncode({
      'app': 'handy-habit',
      'schema': 1,
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

HabitState restore(Uint8List bytes, {bool zip = true}) {
  if (bytes.length > backupLimit)
    throw const FormatException('Backup exceeds 30MB');
  var data = bytes;
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
        manifest['schema'] != 1 ||
        (manifest['files'] as Map)['data.json'] !=
            sha256.convert(files['data.json']!).toString())
      throw const FormatException('Backup checksum mismatch');
    data = files['data.json']!;
  }
  return HabitState.fromJson(
    Map<String, dynamic>.from(jsonDecode(utf8.decode(data)) as Map),
  );
}

HabitState merge(HabitState current, HabitState imported) {
  // All imported identities are remapped: never overwrite a live event/session.
  final existingBatches = List<String>.from(
        current.settings['imports'] as List? ?? [],
      ),
      digest = sha256.convert(backup(imported, zip: false)).toString();
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
    'settings': {
      ...current.settings,
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

String csvLogs(HabitState s, String from, String until) {
  String cell(String v) =>
      '"${(RegExp(r'^[\s]*[=+@\-]').hasMatch(v) ? "'$v" : v).replaceAll('"', '""')}"';
  final names = {for (final h in s.habits) h.id: h.title};
  return [
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
          utf8.encode(jsonEncode({'schema': 1, 'entry': e.toJson()})),
        ),
      ],
  ].map((row) => row.map(cell).join(',')).join('\r\n');
}

HabitState importCsvLogs(HabitState current, Uint8List bytes) {
  if (bytes.length > backupLimit) throw const FormatException('CSV limit');
  final rows = csvParse(utf8.decode(bytes));
  final expected = csvParse(
    csvLogs(HabitState(), '1900-01-01', '2200-12-31'),
  ).first;
  if (jsonEncode(rows.first) != jsonEncode(expected))
    throw const FormatException('Unknown Habit CSV schema');
  final entries = {for (final e in current.events) e.id: e};
  String safe(String v) => RegExp(r'^[\s]*[=+@\-]').hasMatch(v) ? "'$v" : v;
  for (final row in rows.skip(1)) {
    if (row.length != expected.length)
      throw const FormatException('Wrong CSV column count');
    final record = jsonDecode(utf8.decode(base64Decode(row.last))) as Map;
    if (record['schema'] != 1)
      throw const FormatException('Unknown log record schema');
    final e = HabitEvent.fromJson(
      Map<String, dynamic>.from(record['entry'] as Map),
    );
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
      if (i != 2 && row[i] != safe(values[i]))
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
  return current.copy({
    'events': entries.values.map((e) => e.toJson()).toList(),
  });
}

String markdownReport(
  HabitState s,
  String from,
  String until, {
  bool vietnamese = false,
}) {
  String escape(String v) => v.replaceAll('|', r'\|').replaceAll('\n', ' ');
  final index = HabitIndex(s.events);
  final headers = vietnamese
      ? 'Thói quen | Hoàn thành | Hợp lệ | Chuỗi'
      : 'Habit | Completed | Eligible | Streak';
  final note = vietnamese
      ? 'Ngày bỏ qua không phải thành công. Kỳ hiện tại chưa đóng không phải thất bại.'
      : 'Skipped dates are neutral, not successes. Open current periods are not failures.';
  return '# Handy Habit\n\n$from — $until · ${s.zone}\n\n| $headers |\n| --- | ---: | ---: | ---: |\n${s.habits.map((h) {
    final m = metrics(h, until, s.weekStart, index, from: from);
    final unit = vietnamese ? (m.unit == 'weeks' ? 'tuần' : 'ngày') : m.unit;
    return '| ${escape(h.title)} | ${m.completed} | ${m.eligible} | ${m.current} $unit |';
  }).join('\n')}\n\n$note\n';
}
