part of '../handy_habit_engine.dart';

const habitSyncRoot = 'handy-habit';
const habitSyncVersion = 1;
const _syncKinds = [
  'habits',
  'events',
  'routines',
  'sessions',
  'pauses',
  'moods',
  'trash',
  'tombstones',
  'days',
  'order',
];

/// Preferences, clocks, reminders, permissions and sync credentials stay local.
/// Event civil dates and session snapshots already capture their recording policy.
bool _syncedOperation(HabitOperation o) => _syncKinds.contains(o.kind);

/// Seed pre-ledger rows once, with deterministic identities. Existing edits use
/// their original before-image, never a later materialized snapshot as a seed.
HabitState prepareHabitSync(HabitState s) {
  final ops = s.operations.toList();
  final histories = <String, List<HabitOperation>>{};
  for (final o in ops) {
    histories.putIfAbsent('${o.kind}/${o.entity}', () => []).add(o);
  }
  final json = s.toJson();
  for (final kind in _syncKinds.where((k) => k != 'days' && k != 'order')) {
    final rows = _rows(json, kind);
    final entities = {
      ...rows.keys,
      ...ops.where((o) => o.kind == kind).map((o) => o.entity),
    };
    for (final id in entities) {
      final history = (histories['$kind/$id'] ?? []).toList()
        ..sort(_operationOrder);
      if (history.any((o) => o.actor.startsWith('seed:')) ||
          history.any((o) => o.before == null))
        continue;
      final payload = history.isEmpty ? rows[id] : history.first.before;
      if (payload == null) continue;
      final key = sha256.convert(utf8.encode('$kind/$id')).toString();
      ops.add(
        HabitOperation(
          id: 'seed:$key',
          actor: 'seed:$key',
          sequence: 1,
          lamport: 1,
          kind: kind,
          entity: id,
          batch: 'seed:$key',
          intent: 'legacy',
          after: payload,
        ),
      );
    }
  }
  return s.copy({
    'operations': unionOperations(
      ops,
      const [],
    ).map((o) => o.toJson()).toList(),
  });
}

int _operationOrder(HabitOperation a, HabitOperation b) {
  final seed = (a.actor.startsWith('seed:') ? 0 : 1).compareTo(
    b.actor.startsWith('seed:') ? 0 : 1,
  );
  if (seed != 0) return seed;
  final order = a.lamport.compareTo(b.lamport);
  return order == 0 ? a.id.compareTo(b.id) : order;
}

List<HabitOperation> _heads(List<HabitOperation> ops) {
  final parents = {for (final o in ops) ...o.parents};
  return ops
      .where((o) => !parents.contains(o.id) && !o.actor.startsWith('seed:'))
      .toList();
}

/// Same-day moods have no arbitrary winner. Every maximal version stays in the
/// ledger and is offered for review; a new edit observes all versions.
Map<String, List<HabitOperation>> moodSyncConflicts(HabitState s) {
  final groups = <String, List<HabitOperation>>{};
  for (final o in s.operations.where((o) => o.kind == 'moods' && !o.redacted)) {
    groups.putIfAbsent(o.entity, () => []).add(o);
  }
  return {
    for (final e in groups.entries)
      if (_heads(e.value).map((o) => _canonical(o.after)).toSet().length > 1)
        e.key: _heads(e.value),
  };
}

/// Explicit review also supports choosing an Undo/removal candidate with no row.
HabitState resolveMoodSyncConflict(
  HabitState s,
  String entity,
  String candidate,
) {
  final choices =
      moodSyncConflicts(s)[entity] ??
      (throw StateError('Mood conflict changed'));
  final chosen = choices.firstWhere((o) => o.id == candidate);
  final id = uid();
  final op = HabitOperation(
    id: id,
    actor: 'review:$id',
    sequence: 1,
    lamport: s.operations.fold(0, (n, o) => max(n, o.lamport)) + 1,
    kind: 'moods',
    entity: entity,
    batch: id,
    intent: chosen.after == null ? 'remove' : 'put',
    parents: choices.map((o) => o.id).toList(),
    after: chosen.after,
  );
  return materializeHabitOperations(s, unionOperations(s.operations, [op]));
}

dynamic _patchValue(dynamic current, dynamic before, dynamic after) {
  if (before is Map && after is Map && current is Map) {
    final out = Map<String, dynamic>.from(current);
    for (final key in {...before.keys, ...after.keys}.cast<String>()) {
      if (_same(before[key], after[key])) continue;
      if (!after.containsKey(key)) {
        out.remove(key);
        continue;
      }
      out[key] = _patchValue(out[key], before[key], after[key]);
    }
    return out;
  }
  String? identity(dynamic v) =>
      v is Map ? (v['id'] ?? (v['plan'] as Map?)?['id']) as String? : null;
  if (current is List &&
      before is List &&
      after is List &&
      [...current, ...before, ...after].every((v) => identity(v) != null)) {
    final out = {for (final v in current) identity(v)!: v},
        old = {for (final v in before) identity(v)!: v},
        next = {for (final v in after) identity(v)!: v};
    for (final id in {...old.keys, ...next.keys}) {
      if (_same(old[id], next[id])) continue;
      if (!next.containsKey(id)) {
        out.remove(id);
        continue;
      }
      out[id] = _patchValue(out[id], old[id], next[id]);
    }
    // Preserve the explicit latest order; concurrently inserted IDs follow by ID.
    final extra = out.keys.where((id) => !next.containsKey(id)).toList()
      ..sort();
    return [
      for (final id in [...next.keys, ...extra])
        if (out.containsKey(id)) out[id],
    ];
  }
  return after;
}

/// Three-way causal merge: base operations are immutable ancestors and cannot
/// disappear through an incomplete local/remote snapshot. Content union is
/// associative, commutative and idempotent. Reduction never uses wall clocks.
HabitState mergeHabitStates(
  HabitState local,
  HabitState remote, {
  List<HabitOperation> base = const [],
}) {
  final a = prepareHabitSync(local), b = prepareHabitSync(remote);
  final ops = unionOperations(
    unionOperations(
      a.operations.where(_syncedOperation),
      b.operations.where(_syncedOperation),
    ),
    base.where(_syncedOperation),
  );
  return materializeHabitOperations(local, ops);
}

HabitState materializeHabitOperations(
  HabitState local,
  List<HabitOperation> input,
) {
  var ops = unionOperations(input, const []);
  final permanent = [
    for (final o in ops)
      if (o.kind == 'tombstones' && o.after != null) o.after!,
  ];
  if (permanent.isNotEmpty) {
    ops = [
      for (final o in ops)
        if (permanent.any(
          (t) =>
              o.kind == '${t['kind']}s' && o.entity == t['entity'] ||
              t['kind'] == 'habit' &&
                  ['events', 'days'].contains(o.kind) &&
                  (o.before?['habit'] == t['entity'] ||
                      o.after?['habit'] == t['entity']) ||
              o.kind == 'trash' &&
                  (o.entity == t['id'] ||
                      o.after?['entity'] == t['entity'] &&
                          o.after?['kind'] == t['kind']),
        ))
          HabitOperation.fromJson({
            ...o.toJson(),
            'redacted': true,
            'before': null,
            'after': null,
          })
        else
          o,
    ];
  }
  final ordered = ops.toList()..sort(_operationOrder);
  final groups = <String, List<HabitOperation>>{};
  for (final o in ordered.where(
    (o) => _syncedOperation(o) && o.kind != 'days' && o.kind != 'order',
  )) {
    groups.putIfAbsent('${o.kind}/${o.entity}', () => []).add(o);
  }
  final tables = {for (final k in _syncKinds) k: <String, Json>{}};
  for (final history in groups.values) {
    final creations = history.where(
      (o) =>
          !o.redacted &&
          o.before == null &&
          o.after != null &&
          !o.actor.startsWith('seed:'),
    );
    Json? identityPayload(HabitOperation o) {
      final row = o.after == null ? null : {...o.after!};
      if (row?['source'] == 'routine') row!.remove('updated');
      return row;
    }

    if ([
          'events',
          'habits',
          'routines',
          'sessions',
        ].contains(history.first.kind) &&
        creations.map((o) => _canonical(identityPayload(o))).toSet().length >
            1) {
      throw const FormatException('Duplicate entity ID has different contents');
    }
    Json? row;
    for (final o in history.where((o) => !o.redacted)) {
      if (o.after == null) {
        row = null;
        continue;
      }
      row = Map<String, dynamic>.from(
        _patchValue(row, o.before, o.after) as Map,
      );
    }
    // Concurrent removal dominates an edit; an observed restore supersedes it.
    final heads = _heads(history);
    if (heads.any((o) => !o.redacted && o.after == null)) row = null;
    if (history.first.kind == 'moods' &&
        heads.map((o) => _canonical(o.after)).toSet().length > 1)
      row = null;
    if (row != null) tables[history.first.kind]![history.first.entity] = row;
  }
  final deadHabits = {
    for (final t in tables['tombstones']!.values)
      if (t['kind'] == 'habit') t['entity'],
  };
  final deadRoutines = {
    for (final t in tables['tombstones']!.values)
      if (t['kind'] == 'routine') t['entity'],
  };
  final habits = tables['habits']!
    ..removeWhere((id, _) => deadHabits.contains(id));
  final routines = tables['routines']!
    ..removeWhere((id, _) => deadRoutines.contains(id));
  final conflicts = dayOperationConflicts(ops).keys.toSet();
  final events = tables['events']!;
  final byId = {for (final o in ops) o.id: o};
  bool observes(HabitOperation later, String earlier) {
    final pending = later.parents.toList(), seen = <String>{};
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (id == earlier) return true;
      if (seen.add(id)) pending.addAll(byId[id]!.parents);
    }
    return false;
  }

  final days = ops.where((o) => o.kind == 'days' && !o.redacted).toList();
  final retracted = {
    for (final o in ops)
      if (o.undoOf != null) o.undoOf!,
  };
  final supersededBatches = {
    for (final o in days)
      if (retracted.contains(o.id) ||
          days.any(
            (later) =>
                later.entity == o.entity &&
                later.intent == 'setManualTotal' &&
                !retracted.contains(later.id) &&
                observes(later, o.id),
          ))
        o.batch,
  };
  final suppressedEvents = {
    for (final o in ops)
      if (o.kind == 'events' &&
          o.before == null &&
          o.after != null &&
          supersededBatches.contains(o.batch))
        o.entity,
  };
  events.removeWhere(
    (_, e) =>
        suppressedEvents.contains(e['id']) ||
        !habits.containsKey(e['habit']) ||
        e['source'] == 'manual' &&
            conflicts.contains('${e['habit']}:${e['day']}'),
  );
  // A skip only applies to the manual contributions it observed. Linked/new
  // contributions survive; a conflicting skip is held for review in the ledger.
  final positiveDays = {
    for (final e in events.values)
      if (e['value'] > 0) '${e['habit']}:${e['day']}',
  };
  events.removeWhere(
    (_, e) =>
        e['skipped'] == true &&
        positiveDays.contains('${e['habit']}:${e['day']}'),
  );
  for (final r in routines.values) {
    r['steps'] = [
      for (final step in objects(r['steps']))
        {
          ...step,
          if (step['habit'] != null && !habits.containsKey(step['habit']))
            'habit': null,
        },
    ];
  }
  tables['pauses']!.removeWhere(
    (_, p) =>
        (p['habits'] as List).isNotEmpty &&
        !(p['habits'] as List).any(habits.containsKey),
  );
  for (final p in tables['pauses']!.values) {
    p['habits'] = [
      for (final id in p['habits'] as List)
        if (habits.containsKey(id)) id,
    ];
  }
  final trashEntities = <String>{};
  tables['trash']!.removeWhere(
    (_, t) =>
        !(t['kind'] == 'habit' ? habits : routines).containsKey(t['entity']) ||
        !trashEntities.add('${t['kind']}:${t['entity']}'),
  );
  final sessions = tables['sessions']!.values.toList();
  var active = false;
  for (final s in sessions) {
    s['steps'] = [
      for (final step in objects(s['steps']))
        {
          ...step,
          if (step['event'] != null && events[step['event']] != null)
            'eventHash': sha256
                .convert(utf8.encode(jsonEncode(events[step['event']])))
                .toString(),
        },
    ];
    if (s['status'] == 'active') {
      if (active) {
        s['status'] = 'aborted';
        s['recoveryWarning'] = true;
      }
      active = true;
    }
    // Timer anchors belong to the recording device; receiving never runs time.
    if (!local.sessions.any(
      (old) => old.id == s['id'] && old.anchor == s['anchor'],
    ))
      s['anchor'] = null;
    if (s['status'] != 'active') s['anchor'] = null;
  }
  // Schedules/goal histories remain ordered by effective day. Same-day edits
  // choose a stable ID for projection; all original candidates remain in ops.
  for (final h in habits.values) {
    for (final field in ['schedules', 'negativeGoals']) {
      if (h[field] is! List) continue;
      final rows = objects(h[field])
        ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
      final byDay = {for (final r in rows) r['from']: r};
      h[field] = byDay.values.toList()
        ..sort((a, b) => '${a['from']}'.compareTo('${b['from']}'));
    }
  }
  List<Json> rows(String k) {
    final table = tables[k]!, ids = table.keys.toList()..sort();
    final orders = ordered.where(
      (o) =>
          o.kind == 'order' && o.entity == k && !o.redacted && o.after != null,
    );
    final preferred = orders.lastOrNull?.after?['ids'] as List? ?? const [];
    return [
      for (final id in [
        ...preferred.where(table.containsKey),
        ...ids.where((id) => !preferred.contains(id)),
      ])
        table[id]!,
    ];
  }

  final settings = {...local.settings};
  settings['reminders'] = [
    for (final r in objects(settings['reminders'] ?? []))
      if ((r['type'] == 'habit' ? habits : routines).containsKey(r['target']))
        r,
  ];
  return local.copy({
    for (final k in _syncKinds.where((k) => k != 'days' && k != 'order'))
      k: rows(k),
    'settings': settings,
    'operations': unionOperations(
      ops,
      local.operations.where((o) => !_syncedOperation(o)),
    ).map((o) => o.toJson()).toList(),
  });
}

class NewerHabitSync implements Exception {
  const NewerHabitSync();
  @override
  String toString() =>
      'Update Handy Habit on this device before syncing. The newer Drive data was not overwritten.';
}

Uint8List encodeHabitSync(HabitState state) {
  final ops = prepareHabitSync(
    state,
  ).operations.where(_syncedOperation).map((o) => o.toJson()).toList();
  final payload = _canonical(ops), bytes = utf8.encode(payload);
  return Uint8List.fromList(
    utf8.encode(
      _canonical({
        'format': 'handy-habit-sync',
        'version': habitSyncVersion,
        'minReader': 1,
        'schema': habitSchema,
        'size': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
        'operations': ops,
      }),
    ),
  );
}

HabitState decodeHabitSync(Uint8List bytes) {
  if (bytes.length > backupLimit)
    throw const FormatException('Sync file exceeds 30MB');
  final j = jsonDecode(utf8.decode(bytes));
  if (j is! Map || j['format'] != 'handy-habit-sync')
    throw const FormatException('Not a Habit sync file');
  if (integer(j['version'], min: 1) > habitSyncVersion ||
      integer(j['schema'], min: 1) > habitSchema ||
      integer(j['minReader'] ?? 1, min: 1) > habitSyncVersion)
    throw const NewerHabitSync();
  final raw = objects(j['operations']);
  final payload = utf8.encode(_canonical(raw));
  if (payload.length != j['size'] ||
      sha256.convert(payload).toString() != j['sha256'])
    throw const FormatException('Incomplete or damaged Habit sync file');
  final ops = raw.map(HabitOperation.fromJson).toList();
  if (ops.any((o) => !_syncedOperation(o)))
    throw const FormatException('Unexpected device settings in sync');
  validateOperations(ops);
  return materializeHabitOperations(HabitState(), ops);
}

abstract interface class HabitSyncProvider {
  Future<Uint8List?> read(String path);

  /// Immutable create-or-verify. An existing different body must never change.
  Future<void> put(String path, Uint8List bytes);

  /// Complete paginated listing, or an exception. Missing files are not deletions.
  Future<Set<String>> list(String folder);
}

class HabitSyncResult {
  final HabitState state;
  final List<HabitOperation> base;
  final int received;
  const HabitSyncResult(this.state, this.base, this.received);
}

/// Every generation is immutable and content addressed, under its device ID.
/// Concurrent writers never share a mutable data file. No unsafe compaction or
/// remote deletion: a crash at any stage can only leave an extra full generation.
Future<HabitSyncResult> syncHabitOnce({
  required HabitState local,
  required List<HabitOperation> base,
  required String device,
  required HabitSyncProvider remote,
}) async {
  if (!RegExp(r'^[a-zA-Z0-9-]{1,200}$').hasMatch(device))
    throw const FormatException('Invalid sync device');
  var merged = mergeHabitStates(local, HabitState(), base: base);
  final receipts = await remote.list('$habitSyncRoot/versions');
  final referenced = <String>{};
  for (final name in receipts) {
    final receipt = await remote.read('$habitSyncRoot/versions/$name');
    if (receipt == null || receipt.length > 4096)
      throw const FormatException('Incomplete Drive version file');
    final j = jsonDecode(utf8.decode(receipt));
    if (j is! Map || j['format'] != 'handy-habit-device-version')
      throw const FormatException('Damaged Drive version file');
    if (integer(j['version'], min: 1) > habitSyncVersion ||
        integer(j['schema'], min: 1) > habitSchema)
      throw const NewerHabitSync();
    if (j['device'] is! String ||
        j['generation'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(j['generation'] as String) ||
        name != '${j['device']}-${j['generation']}.json')
      throw const FormatException('Invalid Drive version identity');
    referenced.add(name);
  }
  final names = (await remote.list('$habitSyncRoot/commits')).toList()..sort();
  if (!names.toSet().containsAll(referenced))
    throw const FormatException('Partial Drive listing; retry before syncing');
  for (final name in names) {
    final bytes = await remote.read('$habitSyncRoot/commits/$name');
    if (bytes == null)
      throw const FormatException('Incomplete Drive download; try again');
    final state = decodeHabitSync(
      bytes,
    ); // refuses future schemas before any upload
    if (!name.endsWith('-${sha256.convert(bytes)}.json'))
      throw const FormatException('Sync filename checksum mismatch');
    merged = mergeHabitStates(merged, state, base: base);
  }
  final bytes = encodeHabitSync(merged);
  if (bytes.length > backupLimit)
    throw const FormatException('Sync exceeds 30MB; local data is safe');
  final hash = sha256.convert(bytes).toString();
  await remote.put('$habitSyncRoot/commits/$device-$hash.json', bytes);
  // Immutable per-device version receipt replaces a shared mutable lock file:
  // it records exactly which generation was committed, without a two-writer
  // check-then-PATCH race. Interrupted receipts do not hide committed data.
  await remote.put(
    '$habitSyncRoot/versions/$device-$hash.json',
    Uint8List.fromList(
      utf8.encode(
        _canonical({
          'format': 'handy-habit-device-version',
          'version': habitSyncVersion,
          'schema': habitSchema,
          'device': device,
          'generation': hash,
        }),
      ),
    ),
  );
  return HabitSyncResult(
    merged,
    merged.operations.where(_syncedOperation).toList(),
    names.length,
  );
}

class MemoryHabitSyncProvider implements HabitSyncProvider {
  final files = <String, Uint8List>{};
  int writes = 0, failWrites = 0;
  Future<void> Function()? beforePut;
  @override
  Future<Uint8List?> read(String path) async =>
      files[path] == null ? null : Uint8List.fromList(files[path]!);
  @override
  Future<void> put(String path, Uint8List bytes) async {
    final hook = beforePut;
    beforePut = null;
    await hook?.call();
    if (failWrites > 0) {
      failWrites--;
      throw StateError('Connection lost');
    }
    if (files[path] != null && !_same(files[path]!.toList(), bytes.toList()))
      throw const FormatException('Immutable sync file changed');
    files[path] = Uint8List.fromList(bytes);
    writes++;
  }

  @override
  Future<Set<String>> list(String folder) async => {
    for (final p in files.keys)
      if (p.startsWith('$folder/')) p.substring(folder.length + 1),
  };
}
