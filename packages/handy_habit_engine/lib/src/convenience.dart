part of '../handy_habit_engine.dart';

/// Local configuration. Effects use ordinary causal rows, so backup and Undo
/// remain atomic. Rules never trigger other rules.
class ConvenienceRule {
  final String id, name, kind, source, target;
  final String? from, until;
  final bool enabled;
  ConvenienceRule({
    required this.id,
    required this.name,
    required this.kind,
    required this.source,
    this.target = '',
    this.from,
    this.until,
    this.enabled = true,
  }) {
    text(id, max: 100);
    text(name, max: 100);
    text(source, max: 100);
    if (id.isEmpty ||
        name.trim().isEmpty ||
        source.isEmpty ||
        !['routine', 'holiday'].contains(kind)) {
      throw const FormatException('Invalid convenience rule');
    }
    if (kind == 'routine' && target.isEmpty)
      throw const FormatException('Missing rule habit');
    if (kind == 'holiday' && (from == null || until == null))
      throw const FormatException('Missing holiday dates');
    if (kind == 'holiday') Pause(id: id, from: from!, until: until!);
  }
  Json toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'source': source,
    'target': target,
    'from': from,
    'until': until,
    'enabled': enabled,
  };
  factory ConvenienceRule.fromJson(Json j) => ConvenienceRule(
    id: text(j['id']),
    name: text(j['name']),
    kind: text(j['kind']),
    source: text(j['source']),
    target: text(j['target'] ?? ''),
    from: j['from'] as String?,
    until: j['until'] as String?,
    enabled: j['enabled'] == true,
  );
}

List<ConvenienceRule> convenienceRules(HabitState s) => objects(
  s.settings['convenienceRules'] ?? [],
).map(ConvenienceRule.fromJson).toList();

void validateConvenience(Json settings) {
  final rules = objects(
    settings['convenienceRules'] ?? [],
  ).map(ConvenienceRule.fromJson).toList();
  if (rules.length > 50 ||
      rules.map((r) => r.id).toSet().length != rules.length) {
    throw const FormatException('At most 50 distinct rules');
  }
  final filters = objects(settings['savedFilters'] ?? []);
  if (filters.length > 100 ||
      filters.map((f) => f['id']).toSet().length != filters.length) {
    throw const FormatException('At most 100 saved filters');
  }
  for (final f in filters) {
    text(f['id'], max: 100);
    text(f['name'], max: 100);
    if ((f['id'] as String).isEmpty || (f['name'] as String).trim().isEmpty)
      throw const FormatException('Saved view needs a name');
    if (!['habits', 'progress'].contains(f['area']) || f['values'] is! Map)
      throw const FormatException('Invalid saved filter');
    final v = Map<String, dynamic>.from(f['values'] as Map);
    if (f['area'] == 'habits') {
      text(v['search'] ?? '', max: 200);
      if (v['archived'] is! bool ||
          !['manual', 'title', 'priority', 'created'].contains(v['order']))
        throw const FormatException('Invalid habit filter');
    } else {
      date(text(v['anchor']));
      if (!['week', 'month', 'year'].contains(v['kind']) ||
          v['habit'] != null && v['habit'] is! String)
        throw const FormatException('Invalid progress filter');
    }
  }
}

/// A preview holds a revision and explicit IDs. Applying stale previews fails
/// before any write; all changed entities are recorded as one normal batch.
HabitState batchHabits(
  HabitState s,
  Set<String> ids,
  String action,
  String value, {
  required int expectedRevision,
  required String today,
  String? until,
}) {
  if (s.revision != expectedRevision)
    throw StateError('Data changed; preview again');
  final picked = s.liveHabits.where((h) => ids.contains(h.id)).toList();
  if (picked.isEmpty || picked.length != ids.length)
    throw StateError('Selection changed');
  if (action == 'pause')
    return putPause(
      s,
      Pause(
        id: uid(),
        from: value,
        until: until!,
        habits: ids.toList(),
        reason: 'Holiday',
      ),
      today: today,
    );
  if (action == 'reminder') {
    minuteOfDay(value);
    return s.copy({
      'settings': {
        ...s.settings,
        'reminders': [
          for (final r in objects(s.settings['reminders'] ?? []))
            if (r['type'] == 'habit' && ids.contains(r['target']))
              {...r, 'time': value}
            else
              r,
        ],
      },
    });
  }
  if (!['archive', 'collection'].contains(action))
    throw const FormatException('Invalid batch action');
  return s.copy({
    'habits': [
      for (final h in s.habits)
        (ids.contains(h.id)
                ? action == 'archive'
                      ? archiveHabit(h, today, true)
                      : h.copy({'category': value.trim()})
                : h)
            .toJson(),
    ],
  });
}

/// Called within a successful foreground write. An effect marker and its data
/// share one transaction. Undo retains the marker, preventing replay after reopen.
HabitState evaluateConvenience(
  HabitState before,
  HabitState proposed,
  String today, {
  String? ruleId,
}) {
  var next = proposed;
  final markers = <Json>[];
  for (final rule in convenienceRules(
    proposed,
  ).where((r) => r.enabled && (ruleId == null || r.id == ruleId))) {
    final triggers = rule.kind == 'routine'
        ? proposed.sessions
              .where(
                (x) =>
                    x.routine == rule.source &&
                    x.status == 'finished' &&
                    before.sessions.any(
                      (b) => b.id == x.id && b.status == 'active',
                    ),
              )
              .map((x) => x.id)
        : (today.compareTo(rule.from!) >= 0 && today.compareTo(rule.until!) <= 0
              ? [rule.from!]
              : <String>[]);
    for (final trigger in triggers) {
      final key = 'rule:${rule.id}:$trigger';
      final effectId = 'rule:${sha256.convert(utf8.encode(key))}';
      if (proposed.operations.any(
            (o) => o.kind == 'settings' && o.entity == key,
          ) ||
          markers.any((m) => m['key'] == key))
        continue;
      var affected = <String>[];
      String? actualFrom;
      if (rule.kind == 'routine') {
        final h = next.liveHabits
            .where(
              (h) =>
                  h.id == rule.target &&
                  !h.archived &&
                  !h.isNegative &&
                  h.type == 'count',
            )
            .firstOrNull;
        final index = HabitIndex.of(next);
        if (h == null ||
            !isScheduledOn(h, today) ||
            index.paused(h.id, today) ||
            index.skip(h.id, today) ||
            index.conflict(h.id, today) ||
            index.value(h.id, today) > maxValue - 1000)
          continue;
        affected = [h.title];
        next = record(
          next,
          HabitEvent(
            id: effectId,
            habit: h.id,
            day: today,
            value: 1000,
            note: rule.name,
            updated: proposed.sessions
                .firstWhere((s) => s.id == trigger)
                .started,
          ),
          today: today,
          allowExtra: true,
        );
      } else {
        final ids = next.liveHabits
            .where((h) => h.category == rule.source && !h.archived)
            .map((h) => h.id)
            .toList();
        if (ids.isEmpty) continue;
        affected = next.liveHabits
            .where((h) => ids.contains(h.id))
            .map((h) => h.title)
            .toList();
        final earliest = addDays(today, -next.backfill);
        actualFrom = rule.from!.compareTo(earliest) < 0 ? earliest : rule.from!;
        next = putPause(
          next,
          Pause(
            id: effectId,
            from: actualFrom,
            until: rule.until!,
            habits: ids,
            reason: rule.name,
          ),
          today: today,
        );
      }
      markers.add({
        'key': key,
        'name': rule.name,
        'day': today,
        'rule': rule.id,
        'habits': affected,
        'kind': rule.kind,
        'from': actualFrom,
        'until': rule.until,
      });
    }
  }
  if (markers.isEmpty) return next;
  return next.copy({
    'settings': {
      ...next.settings,
      for (final m in markers) m['key'] as String: m,
    },
  });
}

List<(HabitOperation, String)> convenienceHistory(HabitState s) => [
  for (final o in s.operations)
    if (o.kind == 'settings' &&
        o.entity.startsWith('rule:') &&
        o.intent == 'put' &&
        o.after?['value'] is Map)
      (o, (o.after!['value'] as Map)['name'] as String),
];
