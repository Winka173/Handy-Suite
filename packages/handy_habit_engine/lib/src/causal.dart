part of '../handy_habit_engine.dart';

const causalKinds = [
  'habits',
  'events',
  'routines',
  'sessions',
  'pauses',
  'trash',
  'tombstones',
  'settings',
  'clockPolicies',
];

/// Immutable row revision. Parents describe observed ancestry, never wall time.
class HabitOperation {
  final String id, actor, kind, entity, batch, intent;
  final int sequence, lamport;
  final List<String> parents;
  final Json? before, after;
  final String? undoOf;
  final String beforeHash, afterHash;
  final bool redacted;
  HabitOperation({
    required this.id,
    required this.actor,
    required this.sequence,
    required this.lamport,
    required this.kind,
    required this.entity,
    required this.batch,
    required this.intent,
    List<String> parents = const [],
    Json? before,
    Json? after,
    this.undoOf,
    String? beforeHash,
    String? afterHash,
    this.redacted = false,
  }) : parents = List.unmodifiable(parents),
       beforeHash =
           beforeHash ??
           sha256.convert(utf8.encode(_canonical(before))).toString(),
       afterHash =
           afterHash ??
           sha256.convert(utf8.encode(_canonical(after))).toString(),
       before = before == null ? null : freezeJson(before) as Json,
       after = after == null ? null : freezeJson(after) as Json {
    if (id.isEmpty ||
        actor.isEmpty ||
        entity.isEmpty ||
        batch.isEmpty ||
        ![...causalKinds, 'days', 'order'].contains(kind) ||
        ![
          'put',
          'remove',
          'legacy',
          'undo',
          'addDelta',
          'setManualTotal',
        ].contains(intent)) {
      throw const FormatException('Invalid operation');
    }
    integer(sequence, min: 1);
    integer(lamport, min: 1);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(this.beforeHash) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(this.afterHash) ||
        redacted && (before != null || after != null)) {
      throw const FormatException('Invalid operation payload hashes');
    }
  }
  Json toJson() => {
    'id': id,
    'actor': actor,
    'sequence': sequence,
    'lamport': lamport,
    'kind': kind,
    'entity': entity,
    'batch': batch,
    'intent': intent,
    'parents': parents,
    'before': before,
    'after': after,
    'beforeHash': beforeHash,
    'afterHash': afterHash,
    'redacted': redacted,
    'undoOf': undoOf,
    'format': 1,
  };
  factory HabitOperation.fromJson(Json j) {
    if (j['format'] != 1) throw const FormatException('Unsupported operation');
    return HabitOperation(
      id: text(j['id'], max: 200),
      actor: text(j['actor'], max: 200),
      sequence: integer(j['sequence'], min: 1),
      lamport: integer(j['lamport'], min: 1),
      kind: text(j['kind']),
      entity: text(j['entity'], max: 240),
      batch: text(j['batch'], max: 200),
      intent: text(j['intent']),
      parents: List<String>.unmodifiable(j['parents'] as List),
      before: j['before'] == null
          ? null
          : Map<String, dynamic>.from(j['before'] as Map),
      after: j['after'] == null
          ? null
          : Map<String, dynamic>.from(j['after'] as Map),
      undoOf: j['undoOf'] as String?,
      beforeHash: j['beforeHash'] as String?,
      afterHash: j['afterHash'] as String?,
      redacted: j['redacted'] == true,
    );
  }
}

/// Semantic intent survives row materialization: absolute edits carry the exact
/// observed contributions, while additions remain independent deltas.
HabitState recordDayIntent(
  HabitState before,
  HabitState next,
  String habit,
  String day,
  String intent,
  int value, {
  String? event,
  bool skipped = false,
}) {
  final entity = '$habit:$day', id = uid();
  final prior = before.operations
      .where((o) => o.kind == 'days' && o.entity == entity)
      .toList();
  final ancestors = {for (final o in prior) ...o.parents};
  final op = HabitOperation(
    id: id,
    actor: 'command:$id',
    sequence: 1,
    lamport: before.operations.fold(0, (n, o) => max(n, o.lamport)) + 1,
    kind: 'days',
    entity: entity,
    batch: id,
    intent: intent,
    parents: prior
        .where((o) => !ancestors.contains(o.id))
        .map((o) => o.id)
        .toList(),
    before: {
      'observed': [
        for (final e in before.events)
          if (e.habit == habit && e.day == day && e.source == 'manual') e.id,
      ],
    },
    after: {
      'habit': habit,
      'day': day,
      'value': value,
      'event': event,
      'skipped': skipped,
    },
  );
  return next.copy({
    'operations': [...next.operations.map((o) => o.toJson()), op.toJson()],
  });
}

String _canonical(dynamic value) {
  dynamic sorted(dynamic v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: sorted(v[k])};
    }
    if (v is List) return v.map(sorted).toList();
    return v;
  }

  return jsonEncode(sorted(value));
}

bool _same(dynamic a, dynamic b) => _canonical(a) == _canonical(b);

/// Storage key/row order is not presentation order (notably IndexedDB getAll).
List<Json> orderedHabitRows(Json state, String kind) {
  final rows = objects(state[kind]);
  final order = (state['entityOrder'] as Map?)?[kind];
  if (order == null) return rows;
  final ids = List<String>.from(order as List),
      byId = {for (final r in rows) text(r['id']): r};
  if (ids.length != rows.length ||
      ids.toSet().length != ids.length ||
      ids.any((id) => !byId.containsKey(id))) {
    throw const FormatException('Invalid entity order');
  }
  return ids.map((id) => byId[id]!).toList();
}

Map<String, Json> _rows(Json state, String kind) => kind == 'settings'
    ? {
        for (final k in (state[kind] as Map).keys.cast<String>())
          k: {'value': state[kind][k]},
      }
    : {for (final row in objects(state[kind])) text(row['id']): row};

/// Every legacy event has a stable logical ID and a content-derived revision ID.
List<Json> legacyOperations(Json j) {
  final rows = objects(j['events']);
  return [
    for (final row in rows)
      HabitOperation(
        id: 'legacy:${sha256.convert(utf8.encode(_canonical(row)))}',
        actor: 'legacy:${sha256.convert(utf8.encode(text(row['id'])))}',
        sequence: 1,
        lamport: 1,
        kind: 'events',
        entity: text(row['id']),
        batch: 'legacy:${sha256.convert(utf8.encode(text(row['id'])))}',
        intent: 'legacy',
        after: row,
      ).toJson(),
  ];
}

/// Collision checks are shared by local recording and the later sync union.
void validateOperations(List<HabitOperation> operations) {
  if (operations.length > 200000)
    throw const FormatException('Too many operations');
  final ids = <String, HabitOperation>{}, sequences = <String>{};
  for (final op in operations) {
    if (op.kind == 'order' && !op.redacted) {
      if (!['habits', 'routines'].contains(op.entity) ||
          op.before?['ids'] is! List ||
          op.after?['ids'] is! List) {
        throw const FormatException('Invalid order operation');
      }
      final a = List<String>.from(op.before!['ids'] as List),
          b = List<String>.from(op.after!['ids'] as List);
      if (a.length > 200000 ||
          a.length != b.length ||
          a.toSet().length != a.length ||
          b.toSet().length != b.length ||
          !a.toSet().containsAll(b)) {
        throw const FormatException('Invalid order identities');
      }
    }
    if (op.kind == 'days' && !op.redacted && op.intent != 'undo') {
      final payload =
          op.after ?? (throw const FormatException('Missing day intent'));
      date(text(payload['day']));
      text(payload['habit'], max: 200);
      integer(payload['value']);
      if (op.entity != '${payload['habit']}:${payload['day']}' ||
          !['addDelta', 'setManualTotal'].contains(op.intent) ||
          payload['skipped'] is! bool ||
          op.before?['observed'] is! List) {
        throw const FormatException('Invalid day intent');
      }
      for (final id in op.before!['observed'] as List) {
        text(id, max: 200);
      }
    }
    if (!op.redacted &&
        (op.beforeHash !=
                sha256.convert(utf8.encode(_canonical(op.before))).toString() ||
            op.afterHash !=
                sha256.convert(utf8.encode(_canonical(op.after))).toString()))
      throw const FormatException('Operation payload hash mismatch');
    if (ids.containsKey(op.id) ||
        !sequences.add('${op.actor}:${op.sequence}')) {
      throw const FormatException('Duplicate operation or actor sequence');
    }
    ids[op.id] = op;
  }
  for (final op in operations) {
    if (op.parents.toSet().length != op.parents.length ||
        op.parents.any(
          (p) =>
              ids[p] == null ||
              ids[p]!.lamport >= op.lamport ||
              ids[p]!.kind != op.kind ||
              ids[p]!.entity != op.entity,
        )) {
      throw const FormatException('Invalid operation ancestry');
    }
    if (op.undoOf != null && !ids.containsKey(op.undoOf)) {
      throw const FormatException('Unknown Undo operation');
    }
  }
}

/// Deterministic identity union only; the sync slice owns materialized reduction.
/// Redaction keeps the immutable header/hashes and never restores purged payloads.
List<HabitOperation> unionOperations(
  Iterable<HabitOperation> a,
  Iterable<HabitOperation> b,
) {
  final rows = <String, HabitOperation>{};
  for (final op in [...a, ...b]) {
    final existing = rows[op.id];
    if (existing != null) {
      final x = existing.toJson(), y = op.toJson();
      for (final key in ['before', 'after', 'redacted']) {
        x.remove(key);
        y.remove(key);
      }
      if (!_same(x, y)) throw const FormatException('Operation ID collision');
    }
    rows[op.id] = existing?.redacted == true ? existing! : op;
  }
  final result = rows.values.toList()
    ..sort((a, b) {
      final order = a.lamport.compareTo(b.lamport);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
  validateOperations(result);
  return List.unmodifiable(result);
}

/// Exposes unresolved absolute-edit/skip candidates without choosing a clock winner.
Map<String, List<HabitOperation>> dayOperationConflicts(
  List<HabitOperation> operations,
) {
  validateOperations(operations);
  final byId = {for (final o in operations) o.id: o};
  bool observes(HabitOperation later, String earlier) {
    final pending = later.parents.toList(), seen = <String>{};
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (id == earlier) return true;
      if (seen.add(id)) pending.addAll(byId[id]!.parents);
    }
    return false;
  }

  final retracted = {
    for (final o in operations)
      if (o.undoOf != null) o.undoOf!,
  };
  final days = <String, List<HabitOperation>>{};
  for (final op in operations.where(
    (o) =>
        o.kind == 'days' &&
        !o.redacted &&
        o.intent != 'undo' &&
        !retracted.contains(o.id),
  )) {
    days.putIfAbsent(op.entity, () => []).add(op);
  }
  final result = <String, List<HabitOperation>>{};
  for (final entry in days.entries) {
    final conflicts = <String, HabitOperation>{};
    final rows = entry.value
        .where(
          (o) => !entry.value.any(
            (later) =>
                later.intent == 'setManualTotal' &&
                later.id != o.id &&
                observes(later, o.id),
          ),
        )
        .toList();
    for (var i = 0; i < rows.length; i++) {
      for (var j = i + 1; j < rows.length; j++) {
        final a = rows[i], b = rows[j];
        if (observes(a, b.id) || observes(b, a.id)) continue;
        if (a.intent == 'setManualTotal' && b.intent == 'setManualTotal' ||
            a.after!['skipped'] == true && b.after!['value'] > 0 ||
            b.after!['skipped'] == true && a.after!['value'] > 0) {
          conflicts[a.id] = a;
          conflicts[b.id] = b;
        }
      }
    }
    if (conflicts.isNotEmpty)
      result[entry.key] = List.unmodifiable(conflicts.values);
  }
  return Map.unmodifiable(result);
}

HabitState recordChange(
  HabitState before,
  HabitState proposed, {
  required String actor,
  String? undoBatch,
  bool undoable = true,
}) {
  if (before.zone != proposed.zone) {
    proposed = proposed.copy({
      'clockPolicies': [
        ...before.clockPolicies,
        {
          'id': uid(),
          'zone': proposed.zone,
          'dayBoundaryMinutes': 0,
          'effectiveFrom': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    });
  }
  final a = before.toJson(), b = proposed.toJson();
  final purging = proposed.tombstones.length > before.tombstones.length;
  final ops = (purging ? proposed.operations : before.operations).toList(),
      batch = uid();
  // Imported ledgers retain their stable IDs. Same IDs with changed payload fail.
  final byId = {for (final op in ops) op.id: op};
  for (final op in proposed.operations) {
    if (byId[op.id] != null && !_same(byId[op.id]!.toJson(), op.toJson())) {
      throw const FormatException('Operation ID collision');
    }
    if (!byId.containsKey(op.id)) {
      final grouped = op.kind == 'days'
          ? HabitOperation.fromJson({...op.toJson(), 'batch': batch})
          : op;
      ops.add(grouped);
      byId[op.id] = grouped;
    }
  }
  var sequence = ops
      .where((o) => o.actor == actor)
      .fold(0, (n, o) => max(n, o.sequence));
  var lamport = ops.fold(0, (n, o) => max(n, o.lamport));
  final removedParents = {for (final o in ops) ...o.parents};
  for (final kind in purging ? ['tombstones'] : causalKinds) {
    final old = _rows(a, kind), next = _rows(b, kind);
    for (final id in {...old.keys, ...next.keys}) {
      if (_same(old[id], next[id])) continue;
      final parents = ops
          .where(
            (o) =>
                o.kind == kind &&
                o.entity == id &&
                !removedParents.contains(o.id),
          )
          .map((o) => o.id)
          .toList();
      final target = undoBatch == null
          ? null
          : before.operations
                .where(
                  (o) =>
                      o.batch == undoBatch && o.kind == kind && o.entity == id,
                )
                .firstOrNull;
      ops.add(
        HabitOperation(
          id: uid(),
          actor: actor,
          sequence: ++sequence,
          lamport: ++lamport,
          kind: kind,
          entity: id,
          batch: batch,
          parents: parents,
          intent: undoBatch != null
              ? 'undo'
              : next[id] == null
              ? 'remove'
              : 'put',
          before: old[id],
          after: next[id],
          undoOf: target?.id,
        ),
      );
    }
  }
  if (!purging) {
    for (final kind in ['habits', 'routines']) {
      final oldIds = _rows(a, kind).keys.toList(),
          nextIds = _rows(b, kind).keys.toList();
      if (oldIds.length != nextIds.length ||
          !oldIds.toSet().containsAll(nextIds) ||
          _same(oldIds, nextIds))
        continue;
      final target = undoBatch == null
          ? null
          : before.operations
                .where(
                  (o) =>
                      o.batch == undoBatch &&
                      o.kind == 'order' &&
                      o.entity == kind,
                )
                .firstOrNull;
      ops.add(
        HabitOperation(
          id: uid(),
          actor: actor,
          sequence: ++sequence,
          lamport: ++lamport,
          kind: 'order',
          entity: kind,
          batch: batch,
          intent: undoBatch == null ? 'put' : 'undo',
          parents: ops
              .where(
                (o) =>
                    o.kind == 'order' &&
                    o.entity == kind &&
                    !removedParents.contains(o.id),
              )
              .map((o) => o.id)
              .toList(),
          before: {'ids': oldIds},
          after: {'ids': nextIds},
          undoOf: target?.id,
        ),
      );
    }
  }
  final result = proposed.copy({
    'operations': ops.map((o) => o.toJson()).toList(),
    'undoBatch': !purging && undoable && ops.length > before.operations.length
        ? batch
        : null,
  });
  return result;
}

/// Invert only this batch's rows. Never restore a whole state or another actor's edits.
HabitState undoChange(HabitState state, String batch, {required String actor}) {
  final targets = state.operations.where((o) => o.batch == batch).toList();
  if (targets.isEmpty ||
      targets.any((o) => o.intent == 'legacy' || o.redacted) ||
      state.operations.any((o) => targets.any((t) => t.id == o.undoOf))) {
    throw StateError('Undo is no longer available');
  }
  final json = state.toJson();
  for (final op in targets.reversed) {
    if (op.kind == 'days') continue;
    if (op.kind == 'order') {
      final rows = _rows(json, op.entity);
      if (!_same(rows.keys.toList(), op.after?['ids']))
        throw StateError('Newer order prevents Undo');
      final ids = List<String>.from(op.before!['ids'] as List);
      if (ids.any((id) => !rows.containsKey(id)))
        throw StateError('Items changed since reordering');
      json[op.entity] = [for (final id in ids) rows[id]];
      json['entityOrder'] = {...json['entityOrder'] as Map, op.entity: ids};
      continue;
    }
    final rows = _rows(json, op.kind);
    if (!_same(rows[op.entity], op.after))
      throw StateError('Newer edits prevent Undo');
    if (op.before == null) {
      rows.remove(op.entity);
    } else {
      rows[op.entity] = op.before!;
    }
    json[op.kind] = op.kind == 'settings'
        ? {for (final e in rows.entries) e.key: e.value['value']}
        : rows.values.toList();
  }
  json['entityOrder'] = {
    for (final kind in ['habits', 'routines'])
      kind: _rows(json, kind).keys.toList(),
  };
  final result = recordChange(
    state,
    HabitState.fromJson(json),
    actor: actor,
    undoBatch: batch,
    undoable: false,
  );
  final ops = result.operations.toList();
  var sequence = ops
      .where((o) => o.actor == actor)
      .fold(0, (n, o) => max(n, o.sequence));
  var lamport = ops.fold(0, (n, o) => max(n, o.lamport));
  for (final target in targets.where((o) => o.kind == 'days')) {
    final ancestors = {for (final o in ops) ...o.parents};
    ops.add(
      HabitOperation(
        id: uid(),
        actor: actor,
        sequence: ++sequence,
        lamport: ++lamport,
        kind: 'days',
        entity: target.entity,
        batch: uid(),
        intent: 'undo',
        undoOf: target.id,
        parents: ops
            .where(
              (o) =>
                  o.kind == 'days' &&
                  o.entity == target.entity &&
                  !ancestors.contains(o.id),
            )
            .map((o) => o.id)
            .toList(),
        before: target.after,
      ),
    );
  }
  return result.copy({'operations': ops.map((o) => o.toJson()).toList()});
}
