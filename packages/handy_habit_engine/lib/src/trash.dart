part of '../handy_habit_engine.dart';

const trashRetention = Duration(days: 30);

class HabitTrash {
  final String id, kind, entity, deletedAt, expiresAt, localDay;
  HabitTrash({
    required this.id,
    required this.kind,
    required this.entity,
    required this.deletedAt,
    required this.expiresAt,
    required this.localDay,
  }) {
    if (!['habit', 'routine'].contains(kind) ||
        id.isEmpty ||
        entity.isEmpty ||
        DateTime.parse(
              timestamp(expiresAt),
            ).difference(DateTime.parse(timestamp(deletedAt))) !=
            trashRetention) {
      throw const FormatException('Invalid trash entry');
    }
    date(localDay);
  }
  int daysLeft(DateTime now) =>
      (DateTime.parse(expiresAt).difference(now.toUtc()).inMilliseconds /
              Duration.millisecondsPerDay)
          .ceil()
          .clamp(0, 30);
  Json toJson() => {
    'id': id,
    'kind': kind,
    'entity': entity,
    'deletedAt': deletedAt,
    'expiresAt': expiresAt,
    'localDay': localDay,
  };
  factory HabitTrash.fromJson(Json j) => HabitTrash(
    id: text(j['id']),
    kind: text(j['kind']),
    entity: text(j['entity']),
    deletedAt: timestamp(j['deletedAt']),
    expiresAt: timestamp(j['expiresAt']),
    localDay: text(j['localDay']),
  );
}

HabitState trashEntity(HabitState s, String kind, String id, DateTime now) {
  if (s.isTrashed(kind, id)) return s;
  if (!(kind == 'habit'
      ? s.habits.any((h) => h.id == id)
      : kind == 'routine' && s.routines.any((r) => r.id == id))) {
    throw StateError('Item no longer exists');
  }
  if (s.sessions.any(
    (session) =>
        session.status == 'active' &&
        (kind == 'routine'
            ? session.routine == id
            : session.steps.any((step) => step.plan.habit == id)),
  )) {
    throw StateError(
      'Finish or end the active routine before deleting / Hãy kết thúc phiên đang chạy trước khi xóa',
    );
  }
  final entry = HabitTrash(
    id: uid(),
    kind: kind,
    entity: id,
    deletedAt: now.toUtc().toIso8601String(),
    expiresAt: now.toUtc().add(trashRetention).toIso8601String(),
    localDay: habitDayAt(s, now),
  );
  return s.copy({
    'trash': [...s.trash.map((t) => t.toJson()), entry.toJson()],
  });
}

HabitState restoreTrash(HabitState s, String id, DateTime now) {
  final entry = s.trash.firstWhere((t) => t.id == id);
  if (!DateTime.parse(entry.expiresAt).isAfter(now.toUtc()))
    throw StateError('This item has expired');
  // Original entities and references stayed in place, so restoration cannot overwrite edits.
  return s.copy({
    // Concurrent deletions have distinct Trash IDs but refer to one logical
    // item. Retract every observed hidden duplicate as well as the visible row.
    'operations': _restoreDuplicateTrash(
      s,
      entry,
    ).map((o) => o.toJson()).toList(),
    if (entry.kind == 'habit' &&
        date(habitDayAt(s, now)).difference(date(entry.localDay)).inDays > 1)
      'habits': [
        for (final h in s.habits)
          if (h.id == entry.entity)
            h.copy({
              'archivedPeriods': [
                ...h.archivedPeriods,
                {
                  'from': addDays(entry.localDay, 1),
                  'until': addDays(habitDayAt(s, now), -1),
                },
              ],
            }).toJson()
          else
            h.toJson(),
      ],
    'trash': [
      for (final t in s.trash)
        if (t.id != id) t.toJson(),
    ],
  });
}

List<HabitOperation> _restoreDuplicateTrash(HabitState s, HabitTrash visible) {
  final groups = <String, List<HabitOperation>>{};
  for (final o in s.operations.where((o) => o.kind == 'trash')) {
    groups.putIfAbsent(o.entity, () => []).add(o);
  }
  final ops = s.operations.toList();
  var clock = ops.fold(0, (n, o) => max(n, o.lamport));
  for (final e in groups.entries.where((e) => e.key != visible.id)) {
    final parents = {for (final o in e.value) ...o.parents};
    final heads = e.value.where((o) => !parents.contains(o.id)).toList()
      ..sort(_operationOrder);
    if (heads.any((o) => o.after == null)) continue;
    final row = heads.lastOrNull?.after;
    if (row?['entity'] != visible.entity || row?['kind'] != visible.kind)
      continue;
    final command = uid();
    ops.add(
      HabitOperation(
        id: command,
        actor: 'restore:$command',
        sequence: 1,
        lamport: ++clock,
        kind: 'trash',
        entity: e.key,
        batch: command,
        intent: 'remove',
        parents: heads.map((o) => o.id).toList(),
        before: row,
      ),
    );
  }
  return ops;
}

HabitState deleteTrash(HabitState s, String id) {
  final t = s.trash.firstWhere((t) => t.id == id);
  var next = s;
  if (t.kind == 'habit') {
    next = dropHabitFromPauses(s, t.entity);
  }
  final json = next.toJson();
  json['trash'] = [
    for (final e in s.trash)
      if (e.id != id) e.toJson(),
  ];
  json['tombstones'] = [
    ...s.tombstones,
    {'id': t.id, 'kind': t.kind, 'entity': t.entity, 'deletedAt': t.deletedAt},
  ];
  if (t.kind == 'habit') {
    json['habits'] = [
      for (final h in next.habits)
        if (h.id != t.entity) h.toJson(),
    ];
    json['events'] = [
      for (final e in next.events)
        if (e.habit != t.entity) e.toJson(),
    ];
    json['routines'] = [
      for (final r in next.routines)
        r.copy({
          'steps': [
            for (final step in r.steps)
              step.copy({
                'habit': step.habit == t.entity ? null : step.habit,
              }).toJson(),
          ],
          for (final kind in ['blocks', 'presets'])
            kind: [
              for (final b in kind == 'blocks' ? r.blocks : r.presets)
                {
                  ...b.toJson(),
                  'steps': [
                    for (final step in b.steps)
                      step.copy({
                        'habit': step.habit == t.entity ? null : step.habit,
                      }).toJson(),
                  ],
                },
            ],
        }).toJson(),
    ];
  } else {
    json['routines'] = [
      for (final r in next.routines)
        if (r.id != t.entity) r.toJson(),
    ];
  }
  json['settings'] = {
    ...next.settings,
    'reminders': [
      for (final r in objects(next.settings['reminders'] ?? []))
        if (!(r['type'] == t.kind && r['target'] == t.entity)) r,
    ],
  };
  // Expiry removes this item's inverse payloads, keeping ancestry and hashes.
  // Tombstones remain after the 30-day UI retention window.
  json['operations'] = [
    for (final op in s.operations)
      if (op.kind == '${t.kind}s' && op.entity == t.entity ||
          t.kind == 'habit' &&
              op.kind == 'events' &&
              (op.before?['habit'] == t.entity ||
                  op.after?['habit'] == t.entity) ||
          t.kind == 'habit' &&
              op.kind == 'days' &&
              op.after?['habit'] == t.entity ||
          op.kind == 'trash' && op.entity == t.id)
        {...op.toJson(), 'redacted': true, 'before': null, 'after': null}
      else
        op.toJson(),
  ];
  json['undoBatch'] = null;
  json['entityOrder'] = {
    for (final kind in ['habits', 'routines'])
      kind: [for (final row in objects(json[kind])) row['id']],
  };
  return HabitState.fromJson(json);
}

HabitState purgeTrash(HabitState s, DateTime now) {
  for (final t in s.trash.where(
    (t) => !DateTime.parse(t.expiresAt).isAfter(now.toUtc()),
  )) {
    s = deleteTrash(s, t.id);
  }
  return s;
}
