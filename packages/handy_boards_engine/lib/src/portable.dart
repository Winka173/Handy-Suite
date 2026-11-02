part of '../handy_boards_engine.dart';

/// Browser-safe export: original bodies are read asynchronously and the caller
/// may cancel between records/assets. Browser downloads retain a 30 MB bound.
Future<Uint8List> exportBackupAsync(
  BoardsState s, {
  bool zip = true,
  void Function()? check,
  void Function(double)? progress,
}) async {
  s.validate();
  check?.call();
  final metadata = BytesBuilder(copy: false), assets = <String, Uint8List>{};
  void append(BytesBuilder target, String value, int limit) {
    final bytes = utf8.encode(value);
    if (target.length + bytes.length > limit)
      throw const FormatException('Backup exceeds portable bounds');
    target.add(bytes);
  }

  append(
    metadata,
    '{"app":"handy-boards","schema":2,"revision":${s.revision},"preferences":${jsonEncode(s.preferences)}',
    28000000,
  );
  for (final kind in kinds) {
    append(metadata, ',${jsonEncode(kind)}:[', 28000000);
    var first = true, n = 0;
    for (final r in s.rows(kind)) {
      check?.call();
      append(metadata, '${first ? '' : ','}${jsonEncode(r.data)}', 28000000);
      first = false;
      if (++n % 250 == 0) await Future<void>.delayed(Duration.zero);
    }
    append(metadata, ']', 28000000);
  }
  append(metadata, '}', 28000000);
  final metadataBytes = metadata.takeBytes();
  var total = metadataBytes.length, count = 0;
  for (final path in s.filePaths) {
    check?.call();
    final bytes = await s.readFile(path);
    total += bytes.length;
    if (total > 28000000 || assets.length >= 997)
      throw const FormatException('Backup exceeds portable bounds');
    assets[path] = bytes;
    progress?.call(++count / (s.filePaths.length + 1));
    await Future<void>.delayed(Duration.zero);
  }
  check?.call();
  if (!zip) {
    final output = BytesBuilder(copy: false)
      ..add(Uint8List.sublistView(metadataBytes, 0, metadataBytes.length - 1));
    append(output, ',"files":{', 30000000);
    var first = true;
    for (final e in assets.entries) {
      check?.call();
      if (output.length + ((e.value.length + 2) ~/ 3) * 4 + e.key.length + 8 >
          30000000)
        throw const FormatException('Backup exceeds 30 MB');
      append(
        output,
        '${first ? '' : ','}${jsonEncode(e.key)}:${jsonEncode(base64Encode(e.value))}',
        30000000,
      );
      first = false;
      await Future<void>.delayed(Duration.zero);
    }
    append(output, '}}', 30000000);
    final result = output.takeBytes();
    check?.call();
    return result;
  }
  final entries = {'boards.json': metadataBytes, ...assets};
  if (entries.values.fold<int>(0, (n, v) => n + v.length) > 28000000)
    throw const FormatException('Backup exceeds portable bounds');
  final manifest = {
    'app': 'handy-boards',
    'schema': 2,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'files': {
      for (final e in entries.entries)
        e.key: {
          'bytes': e.value.length,
          'sha256': sha256.convert(e.value).toString(),
        },
    },
  };
  entries['manifest.json'] = Uint8List.fromList(
    utf8.encode(jsonEncode(manifest)),
  );
  final archive = Archive();
  for (final e in entries.entries) {
    check?.call();
    archive.addFile(ArchiveFile.noCompress(e.key, e.value.length, e.value));
    await Future<void>.delayed(Duration.zero);
  }
  final result = Uint8List.fromList(ZipEncoder().encode(archive));
  check?.call();
  progress?.call(1);
  return result;
}

Uint8List exportBackup(BoardsState s, {bool zip = true}) {
  s.validate();
  if (!zip) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(s.toJson())));
    if (bytes.length > 30000000)
      throw const FormatException('Backup exceeds 30 MB');
    return bytes;
  }
  final entries = <String, Uint8List>{
    'boards.json': Uint8List.fromList(
      utf8.encode(jsonEncode(s.toJson(includeFiles: false))),
    ),
    ...s._files,
  };
  if (entries.length > 998 ||
      entries.values.fold<int>(0, (n, v) => n + v.length) > 28000000)
    throw const FormatException('Backup exceeds portable bounds');
  final manifest = {
    'app': 'handy-boards',
    'schema': 2,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'files': {
      for (final e in entries.entries)
        e.key: {
          'sha256': sha256.convert(e.value).toString(),
          'bytes': e.value.length,
        },
    },
  };
  entries['manifest.json'] = Uint8List.fromList(
    utf8.encode(jsonEncode(manifest)),
  );
  final archive = Archive();
  for (final e in entries.entries)
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  final result = Uint8List.fromList(ZipEncoder().encode(archive));
  if (result.length > 30000000)
    throw const FormatException('Backup exceeds 30 MB');
  return result;
}

BoardsState readBackup(Uint8List bytes) {
  if (bytes.length > 30000000)
    throw const FormatException('Backup exceeds 30 MB');
  if (bytes.length >= 2 && bytes[0] == 80 && bytes[1] == 75) {
    final entries = decodePortableZip(
      bytes,
      isAllowedPath: (p) =>
          p == 'manifest.json' ||
          p == 'boards.json' ||
          RegExp(r'^assets/[a-zA-Z0-9_-]{1,120}\.[a-z0-9]{1,8}$').hasMatch(p),
      maxEntries: 1000,
      maxEntryBytes: 28000000,
    );
    if (!entries.containsKey('manifest.json') ||
        !entries.containsKey('boards.json'))
      throw const FormatException('Incomplete backup');
    final manifest = object(
      jsonDecode(utf8.decode(entries.remove('manifest.json')!)),
    );
    if (manifest['app'] != 'handy-boards' ||
        ![1, 2].contains(manifest['schema']))
      throw const FormatException('Unsupported manifest');
    final checks = object(manifest['files']);
    if (checks.length != entries.length)
      throw const FormatException('Manifest entry mismatch');
    for (final e in entries.entries) {
      final check = object(checks[e.key]);
      if (check['bytes'] != e.value.length ||
          check['sha256'] != sha256.convert(e.value).toString())
        throw const FormatException('Backup checksum mismatch');
    }
    final state = object(
      jsonDecode(utf8.decode(entries.remove('boards.json')!)),
    );
    return BoardsState.fromJson(state, files: entries);
  }
  return BoardsState.fromJson(jsonDecode(utf8.decode(bytes)));
}

BoardsState restoreBackup(
  BoardsState current,
  BoardsState incoming, {
  required bool replace,
  required bool confirmed,
}) {
  if (!confirmed) throw const FormatException('Restore requires confirmation');
  incoming.validate();
  if (replace)
    return incoming.copy(
      revision: current.revision,
      preferences: {
        ...incoming.preferences,
        'notifications': false,
        'homeWidget': false,
      },
    );
  final ids = {
        for (final k in kinds)
          for (final r in incoming.rows(k)) r.id: newId(),
      },
      paths = {
        for (final k in incoming._files.keys)
          k: 'assets/${newId()}.${k.split('.').last}',
      };
  final e = BoardsEdit(
    current.withAssetSource(_RelocatedAssets(current, incoming, paths)),
  );
  dynamic remap(dynamic v, {String key = ''}) {
    const references = {
      'id',
      'workspace',
      'board',
      'category',
      'status',
      'parent',
      'task',
      'before',
      'after',
      'rule',
      'recurrenceSource',
      'suggestedStatus',
      'fromBoard',
      'toBoard',
      'from',
      'to',
    };
    if (v is String)
      return key == 'path' || key == 'preview'
          ? paths[v] ?? v
          : references.contains(key)
          ? ids[v] ?? v
          : v;
    if (v is List)
      return key == 'tags'
          ? v.map((id) => ids[id] ?? id).toList()
          : v.map((x) => remap(x)).toList();
    if (v is Map) {
      if (key == 'custom')
        return {for (final e in v.entries) ids[e.key] ?? e.key: e.value};
      return {
        for (final e in v.entries)
          e.key:
              e.key == 'value' &&
                  [
                    'category',
                    'tag',
                    'suggestStatus',
                    'generate',
                  ].contains(v['type'])
              ? ids[e.value] ?? e.value
              : remap(e.value, key: e.key as String),
      };
    }
    return v;
  }

  for (final k in kinds)
    for (final r in incoming.rows(k)) {
      final data = object(remap(r.data));
      if (k == 'reminders') data['enabled'] = false;
      e.put(k, BoardRecord(data));
    }
  return e.finish();
}

String _csvCell(String v) => '"${v.replaceAll('"', '""')}"';
String exportTaskCsv(BoardsState s, String board, {Set<String>? taskIds}) {
  final rows = queryTasks(
    s,
    board: board,
  ).where((t) => taskIds == null || taskIds.contains(t.id));
  String cell(String v) =>
      _csvCell(RegExp(r'^[=+@\-\t\r]').hasMatch(v) ? "'$v" : v);
  return [
    [
      'id',
      'title',
      'category',
      'status',
      'priority',
      'due',
      'notes',
      'record_b64',
    ].join(','),
    for (final t in rows)
      [
        t.id,
        t.str('title'),
        s.maybe('categories', t.data['category'])?.str('title') ?? '',
        s.get('statuses', t.str('status')).str('title'),
        t.number('priority').toString(),
        t.data['due'] == null ? '' : deadlineSort(object(t.data['due'])),
        t.str('notes'),
        base64Encode(utf8.encode(jsonEncode(t.data))),
      ].map(cell).join(','),
  ].join('\r\n');
}

BoardsState importOwnTaskCsv(
  BoardsState s,
  String board,
  List<List<String>> rows,
) {
  const expected = 'id,title,category,status,priority,due,notes,record_b64';
  if (rows.isEmpty || rows.first.join(',') != expected)
    throw const FormatException('Unsupported Handy Boards CSV columns');
  final edit = BoardsEdit(s), seen = <String>{};
  String display(String v) => RegExp(r'^[=+@\-\t\r]').hasMatch(v) ? "'$v" : v;
  for (final row in rows.skip(1)) {
    if (row.length != 8) throw const FormatException('Incomplete task CSV row');
    final t = BoardRecord(
      object(jsonDecode(utf8.decode(base64Decode(row[7])))),
    );
    if (t.str('board') != board ||
        s.maybe('tasks', t.id) != null ||
        !seen.add(t.id))
      throw const FormatException(
        'CSV requires original board dictionaries and nonconflicting task IDs; use full ZIP for another device',
      );
    final check = [
      t.id,
      t.str('title'),
      s.maybe('categories', t.data['category'])?.str('title') ?? '',
      s.get('statuses', t.str('status')).str('title'),
      '${t.number('priority')}',
      t.data['due'] == null ? '' : deadlineSort(object(t.data['due'])),
      t.str('notes'),
    ].map(display).toList();
    for (var i = 0; i < 7; i++)
      if (row[i] != check[i])
        throw const FormatException(
          'Edited display columns conflict with canonical CSV payload; use mapped CSV instead',
        );
    edit.put('tasks', t);
  }
  return edit.finish();
}

List<List<String>> parseCsv(String source) {
  if (utf8.encode(source).length > 3000000)
    throw const FormatException('CSV exceeds 3 MB');
  final rows = <List<String>>[], row = <String>[];
  var field = StringBuffer(), quoted = false, closed = false;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(c);
      }
      continue;
    }
    if (c == '"') {
      if (field.isNotEmpty || closed)
        throw const FormatException('Malformed CSV');
      quoted = true;
      continue;
    }
    if (c == ',' || c == '\n' || c == '\r') {
      row.add(field.toString());
      field = StringBuffer();
      closed = false;
      if (c != ',') {
        if (c == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
        rows.add(List.of(row));
        row.clear();
      }
      continue;
    }
    if (closed)
      throw const FormatException('Unexpected text after quoted field');
    field.write(c);
  }
  if (quoted) throw const FormatException('Unterminated CSV quote');
  if (field.isNotEmpty || row.isNotEmpty || closed) {
    row.add(field.toString());
    rows.add(row);
  }
  if (rows.length > 50001)
    throw const FormatException('CSV exceeds 50000 rows');
  return rows;
}

BoardsState importLines(
  BoardsState s,
  String board,
  String source, {
  String? category,
  bool markdown = false,
}) {
  if (utf8.encode(source).length > 3000000)
    throw const FormatException('Text exceeds 3 MB');
  final e = BoardsEdit(s);
  var count = 0;
  for (final line in const LineSplitter().convert(source)) {
    if (line.trim().isEmpty) continue;
    final match = RegExp(r'^\s*[-*] \[([ xX])\] (.+)$').firstMatch(line);
    if (markdown && match == null) continue;
    final title = markdown ? match![2]! : line.trim();
    text(title, empty: false);
    var t = newTask(
      s,
      board,
      title,
      category: category,
    ).copy({'order': s.rows('tasks').length + count});
    if (markdown && match![1]!.toLowerCase() == 'x')
      t = t.copy({
        'status': s
            .rows('statuses')
            .firstWhere((r) => r.str('board') == board && r.flag('done'))
            .id,
      });
    e.put('tasks', t);
    if (++count > 50000) throw const FormatException('Too many tasks');
  }
  return e.finish();
}

BoardsState importMappedCsv(
  BoardsState s,
  String board,
  List<List<String>> rows,
  Map<String, int> columns, {
  String? category,
}) {
  if (!columns.containsKey('title'))
    throw const FormatException('Map a title column');
  final e = BoardsEdit(s);
  String value(List<String> row, String name) {
    final i = columns[name];
    if (i == null) return '';
    if (i < 0 || i >= row.length)
      throw const FormatException('Missing mapped cell');
    return row[i];
  }

  var n = 0;
  for (final row in rows.skip(1)) {
    if (row.every((v) => v.isEmpty)) continue;
    var t = newTask(s, board, value(row, 'title'), category: category).copy({
      'notes': value(row, 'notes'),
      'order': s.rows('tasks').length + n++,
    });
    final due = value(row, 'due');
    if (due.isNotEmpty)
      t = t.copy({
        'due': {'kind': 'day', 'day': day(due)},
      });
    final status = value(row, 'status');
    if (status.isNotEmpty) {
      final found = s
          .rows('statuses')
          .where((r) => r.str('board') == board && r.str('title') == status);
      if (found.length != 1)
        throw const FormatException('Unknown/ambiguous status');
      t = t.copy({'status': found.single.id});
    }
    e.put('tasks', t);
  }
  return e.finish();
}

String exportMarkdown(
  BoardsState s,
  String board,
) => queryTasks(s, board: board)
    .map(
      (t) =>
          '- [${completed(s, t) ? 'x' : ' '}] ${t.str('title').replaceAll(RegExp(r'[\r\n]'), ' ')}',
    )
    .join('\n');

String exportIcs(BoardsState s, String board) {
  String escape(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll('\r\n', '\n')
      .replaceAll('\n', r'\n')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;');
  String fold(String line) {
    final out = StringBuffer();
    var width = 0;
    for (final rune in line.runes) {
      final c = String.fromCharCode(rune), n = utf8.encode(c).length;
      if (width + n > 73) {
        out.write('\r\n ');
        width = 1;
      }
      out.write(c);
      width += n;
    }
    return out.toString();
  }

  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Handy Suite//Boards//EN',
  ];
  for (final t in queryTasks(
    s,
    board: board,
  ).where((t) => t.data['due'] != null)) {
    final d = object(t.data['due']);
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${t.id}@handy-boards',
      'DTSTAMP:${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z',
      'SUMMARY:${escape(t.str('title'))}',
      d['kind'] == 'day'
          ? 'DTSTART;VALUE=DATE:${(d['day'] as String).replaceAll('-', '')}'
          : 'DTSTART:${_instant(d['at']).toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(fold).join('\r\n')}\r\n';
}

Json exportBoardTemplate(
  BoardsState s,
  String board, {
  bool includeRecurrence = false,
}) {
  s.validate();
  final categories = s
          .rows('categories')
          .where((r) => r.str('board') == board)
          .toList(),
      statuses = s
          .rows('statuses')
          .where((r) => r.str('board') == board)
          .toList(),
      tasks = s
          .rows('tasks')
          .where(
            (r) =>
                r.str('board') == board &&
                activeTask(r) &&
                r.data['recurrenceSource'] == null,
          )
          .toList(),
      fields = s.rows('fields').where((r) => r.str('board') == board).toList();
  final ids = <String, String>{
    for (var i = 0; i < categories.length; i++) categories[i].id: 'c$i',
    for (var i = 0; i < statuses.length; i++) statuses[i].id: 's$i',
    for (var i = 0; i < tasks.length; i++) tasks[i].id: 't$i',
    for (var i = 0; i < fields.length; i++) fields[i].id: 'f$i',
  };
  Json safe(BoardRecord r, List<String> keys) => {
    for (final k in keys)
      if (r.data[k] != null) k: r.data[k],
  };
  return {
    'app': 'handy-boards-template',
    'schema': 1,
    'title': s.get('boards', board).str('title'),
    'zone': s.get('boards', board).str('zone'),
    'categories': [
      for (final c in categories)
        {
          ...safe(c, ['title', 'color', 'order', 'preview', 'priorityWeight']),
          'id': ids[c.id],
        },
    ],
    'statuses': [
      for (final r in statuses)
        {
          ...safe(r, ['title', 'done', 'order', 'color', 'wip']),
          'id': ids[r.id],
        },
    ],
    'fields': [
      for (final f in fields)
        {
          ...safe(f, ['title', 'type', 'options', 'default']),
          'id': ids[f.id],
        },
    ],
    'tasks': [
      for (final t in tasks)
        {
          ...safe(t, ['title', 'estimate', 'priority', 'kind', 'order']),
          'id': ids[t.id],
          'parent': ids[t.data['parent']],
          'category': ids[t.data['category']],
        },
    ],
    'recurrenceIncluded': includeRecurrence,
    'checklist': [
      for (final c
          in s.rows('checklist').where((r) => ids.containsKey(r.str('task'))))
        {
          'task': ids[c.str('task')],
          'title': c.str('title'),
          'order': c.number('order'),
        },
    ],
    'recurrence': includeRecurrence
        ? [
            for (final (i, r)
                in s
                    .rows('recurrence')
                    .where(
                      (r) =>
                          r.str('board') == board &&
                          ids.containsKey(r.str('task')),
                    )
                    .indexed)
              {
                ...safe(r, [
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
                ]),
                'id': 'r$i',
                'task': ids[r.str('task')],
              },
          ]
        : [],
  };
  // Deliberately excludes personal notes, values, assignees, history and media.
}

Uint8List exportTemplatePackage(
  BoardsState s,
  String board, {
  bool includeRecurrence = false,
}) {
  final payload = Uint8List.fromList(
    utf8.encode(
      jsonEncode(
        exportBoardTemplate(s, board, includeRecurrence: includeRecurrence),
      ),
    ),
  );
  if (payload.length > 3000000)
    throw const FormatException('Template exceeds 3 MB');
  final manifest = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'app': 'handy-boards-template-package',
        'schema': 1,
        'file': 'template.json',
        'bytes': payload.length,
        'sha256': sha256.convert(payload).toString(),
      }),
    ),
  );
  final archive = Archive()
    ..addFile(ArchiveFile('template.json', payload.length, payload))
    ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Returns null for an ordinary full backup, while rejecting unsafe ZIP entries.
Json? readTemplatePackage(Uint8List bytes) {
  final entries = decodePortableZip(
    bytes,
    isAllowedPath: (p) =>
        ['manifest.json', 'template.json', 'boards.json'].contains(p) ||
        RegExp(r'^assets/[a-zA-Z0-9_-]{1,120}\.[a-z0-9]{1,8}$').hasMatch(p),
    maxEntries: 1000,
    maxEntryBytes: 28000000,
  );
  if (!entries.containsKey('manifest.json'))
    throw const FormatException('Missing manifest');
  final manifest = object(jsonDecode(utf8.decode(entries['manifest.json']!)));
  if (manifest['app'] == 'handy-boards') return null;
  if (manifest['app'] != 'handy-boards-template-package' ||
      manifest['schema'] != 1 ||
      entries.length != 2 ||
      !entries.containsKey('template.json'))
    throw const FormatException('Invalid template package');
  final payload = entries['template.json']!;
  if (payload.length > 3000000 ||
      manifest['bytes'] != payload.length ||
      manifest['sha256'] != sha256.convert(payload).toString())
    throw const FormatException('Template checksum/size mismatch');
  return object(jsonDecode(utf8.decode(payload)));
}
