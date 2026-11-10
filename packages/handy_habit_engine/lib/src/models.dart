part of '../handy_habit_engine.dart';

class Schedule {
  final String id, from, kind;
  final List<int> weekdays;
  final int weeklyTarget, interval, target, weekStart;
  Schedule({
    required this.id,
    required this.from,
    this.kind = 'daily',
    List<int> weekdays = const [1, 2, 3, 4, 5],
    this.weeklyTarget = 3,
    this.interval = 2,
    this.target = 1000,
    this.weekStart = 1,
  }) : weekdays = List.unmodifiable(weekdays) {
    date(from);
    text(id, max: 200);
    if (!['daily', 'weekdays', 'weekly', 'interval'].contains(kind) ||
        weekStart < 1 ||
        weekStart > 7 ||
        target < 1 ||
        target > maxValue ||
        weeklyTarget < 1 ||
        weeklyTarget > 7 ||
        interval < 1 ||
        interval > 366 ||
        weekdays.isEmpty ||
        weekdays.toSet().length != weekdays.length ||
        weekdays.any((v) => v < 1 || v > 7))
      throw const FormatException('Invalid schedule');
  }
  Json toJson() => {
    'id': id,
    'from': from,
    'kind': kind,
    'weekdays': weekdays,
    'weeklyTarget': weeklyTarget,
    'interval': interval,
    'target': target,
    'weekStart': weekStart,
  };
  factory Schedule.fromJson(Json j) => Schedule(
    id: text(j['id']),
    from: text(j['from']),
    kind: text(j['kind']),
    weekdays: List<int>.from(j['weekdays'] as List),
    weeklyTarget: integer(j['weeklyTarget'], min: 1, max: 7),
    interval: integer(j['interval'], min: 1, max: 366),
    target: integer(j['target'], min: 1),
    weekStart: integer(j['weekStart'] ?? 1, min: 1, max: 7),
  );
}

class Habit {
  final String id, title, note, type, unit, category, created;
  final String direction;
  final List<NegativeGoal> negativeGoals;
  bool get isNegative => direction == 'reduce';
  final int icon, color, priority;
  final bool archived;
  final String? end;
  final String? archivedFrom;
  final List<Json> archivedPeriods;
  final List<Schedule> schedules;
  Habit({
    required this.id,
    required this.title,
    required this.created,
    required List<Schedule> schedules,
    this.note = '',
    this.type = 'binary',
    this.direction = 'build',
    List<NegativeGoal> negativeGoals = const [],
    this.unit = '',
    this.category = '',
    this.icon = 0xe876,
    this.color = 0xff0d9488,
    this.priority = 1,
    this.archived = false,
    this.end,
    this.archivedFrom,
    List<Json> archivedPeriods = const [],
  }) : negativeGoals = List.unmodifiable(negativeGoals),
       archivedPeriods = List.unmodifiable(
         archivedPeriods.map((p) => Map<String, dynamic>.unmodifiable(p)),
       ),
       schedules = List.unmodifiable(schedules) {
    if (!['build', 'reduce'].contains(direction) ||
        isNegative &&
            (type != 'count' ||
                negativeGoals.isEmpty ||
                negativeGoals.length > 1000) ||
        !isNegative && negativeGoals.isNotEmpty)
      throw const FormatException('Invalid habit direction/goals');
    var goalFrom = '';
    NegativeGoal? previousGoal;
    for (final g in negativeGoals) {
      if (g.from.compareTo(created) < 0 ||
          g.from.compareTo(goalFrom) <= 0 ||
          goalFrom.isEmpty && g.from != created)
        throw const FormatException('Invalid negative goal history');
      if (previousGoal != null &&
          (g.window == 'week' && date(g.from).weekday != g.weekStart ||
              previousGoal.window == 'week' &&
                  date(g.from).weekday != previousGoal.weekStart))
        throw const FormatException(
          'Negative weekly changes require week boundary',
        );
      goalFrom = g.from;
      previousGoal = g;
    }
    if (negativeGoals.map((g) => g.id).toSet().length != negativeGoals.length)
      throw const FormatException('Duplicate negative goal ID');
    if (archivedFrom != null) date(archivedFrom!);
    for (final p in archivedPeriods) {
      if (date(text(p['until'])).isBefore(date(text(p['from']))))
        throw const FormatException('Invalid archive period');
    }
    if (title.trim().isEmpty ||
        type == 'quantity' && unit.trim().isEmpty ||
        title.length > 200 ||
        !['binary', 'count', 'duration', 'quantity'].contains(type) ||
        schedules.isEmpty ||
        schedules.length > 1000 ||
        priority < 0 ||
        priority > 9)
      throw const FormatException('Invalid habit');
    text(id, max: 200);
    text(note);
    text(unit, max: 40);
    text(category, max: 100);
    date(created);
    if (end != null && (date(end!).isBefore(date(created))))
      throw const FormatException('End before start');
    var previous = '';
    for (final s in schedules) {
      if (s.from.compareTo(created) < 0 ||
          s.from.compareTo(previous) <= 0 ||
          type == 'binary' && s.target != 1000 ||
          type == 'count' && s.target % 1000 != 0)
        throw const FormatException('Invalid schedule history');
      previous = s.from;
    }
  }
  Json toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'type': type,
    if (isNegative) 'direction': direction,
    if (isNegative)
      'negativeGoals': negativeGoals.map((g) => g.toJson()).toList(),
    'unit': unit,
    'category': category,
    'created': created,
    'end': end,
    'icon': icon,
    'color': color,
    'priority': priority,
    'archived': archived,
    'archivedFrom': archivedFrom,
    'archivedPeriods': archivedPeriods,
    'schedules': schedules.map((s) => s.toJson()).toList(),
  };
  Habit copy(Json changes) => Habit.fromJson({...toJson(), ...changes});
  factory Habit.fromJson(Json j) => Habit(
    id: text(j['id']),
    title: text(j['title']),
    created: text(j['created']),
    schedules: objects(j['schedules']).map(Schedule.fromJson).toList(),
    note: text(j['note'] ?? ''),
    type: text(j['type']),
    direction: text(j['direction'] ?? 'build'),
    negativeGoals: objects(
      j['negativeGoals'] ?? [],
    ).map(NegativeGoal.fromJson).toList(),
    unit: text(j['unit'] ?? ''),
    category: text(j['category'] ?? ''),
    icon: integer(j['icon'] ?? 0xe876, max: 0x10ffff),
    color: integer(j['color'] ?? 0xff0d9488, max: 0xffffffff),
    priority: integer(j['priority'] ?? 1, max: 9),
    archived: j['archived'] == true,
    archivedFrom: j['archivedFrom'] as String?,
    archivedPeriods: objects(j['archivedPeriods'] ?? []),
    end: j['end'] as String?,
  );
}

class HabitEvent {
  final String id, habit, day, source, note, updated;
  final String? session, step;
  final int value;
  final bool skipped;
  HabitEvent({
    required this.id,
    required this.habit,
    required this.day,
    required this.value,
    this.source = 'manual',
    this.note = '',
    String? updated,
    this.session,
    this.step,
    this.skipped = false,
  }) : updated = timestamp(
         updated ?? DateTime.now().toUtc().toIso8601String(),
       ) {
    date(day);
    text(id, max: 300);
    text(note);
    if (value < 0 ||
        value > maxValue ||
        skipped && value != 0 ||
        !['manual', 'routine'].contains(source) ||
        source == 'routine' && (session == null || step == null))
      throw const FormatException('Invalid check-in');
  }
  Json toJson() => {
    'id': id,
    'habit': habit,
    'day': day,
    'value': value,
    'source': source,
    'note': note,
    'updated': updated,
    'session': session,
    'step': step,
    'skipped': skipped,
  };
  factory HabitEvent.fromJson(Json j) => HabitEvent(
    id: text(j['id']),
    habit: text(j['habit']),
    day: text(j['day']),
    value: integer(j['value']),
    source: text(j['source']),
    note: text(j['note'] ?? ''),
    updated: timestamp(j['updated']),
    session: j['session'] as String?,
    step: j['step'] as String?,
    skipped: j['skipped'] == true,
  );
}

class RoutineStep {
  final String id, title, note;
  final int seconds, minimum, priority, icon, linkedValue;
  final bool required, canSkip;
  final String? habit;
  RoutineStep({
    required this.id,
    required this.title,
    this.note = '',
    this.seconds = 60,
    this.minimum = 60,
    this.priority = 1,
    this.icon = 0xe876,
    this.required = true,
    this.canSkip = true,
    this.habit,
    this.linkedValue = 1000,
  }) {
    if (title.trim().isEmpty ||
        title.length > 200 ||
        seconds < 0 ||
        seconds > 86400 ||
        minimum < 0 ||
        minimum > seconds ||
        priority < 0 ||
        priority > 9 ||
        linkedValue < 1 ||
        linkedValue > maxValue)
      throw const FormatException('Invalid routine step');
    text(id, max: 200);
    text(note);
  }
  Json toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'seconds': seconds,
    'minimum': minimum,
    'priority': priority,
    'icon': icon,
    'required': required,
    'canSkip': canSkip,
    'habit': habit,
    'linkedValue': linkedValue,
  };
  RoutineStep copy(Json changes) =>
      RoutineStep.fromJson({...toJson(), ...changes});
  factory RoutineStep.fromJson(Json j) => RoutineStep(
    id: text(j['id']),
    title: text(j['title']),
    note: text(j['note'] ?? ''),
    seconds: integer(j['seconds'], max: 86400),
    minimum: integer(j['minimum'], max: 86400),
    priority: integer(j['priority'] ?? 1, max: 9),
    icon: integer(j['icon'] ?? 0xe876, max: 0x10ffff),
    required: j['required'] != false,
    canSkip: j['canSkip'] != false,
    habit: j['habit'] as String?,
    linkedValue: integer(j['linkedValue'] ?? 1000, min: 1),
  );
}

class Routine {
  final String id, title, note, category;
  final List<RoutineStep> steps;
  final List<int> weekdays;
  final int icon, color;
  final bool archived;
  final String time;
  Routine({
    required this.id,
    required this.title,
    List<RoutineStep> steps = const [],
    List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.note = '',
    this.category = '',
    this.time = '08:00',
    this.icon = 0xe037,
    this.color = 0xff0d9488,
    this.archived = false,
  }) : steps = List.unmodifiable(steps),
       weekdays = List.unmodifiable(weekdays) {
    if (title.trim().isEmpty ||
        title.length > 200 ||
        steps.length > 200 ||
        steps.map((s) => s.id).toSet().length != steps.length ||
        weekdays.any((d) => d < 1 || d > 7))
      throw const FormatException('Invalid routine');
    minuteOfDay(time);
    text(note);
    text(category, max: 100);
  }
  int get planned => steps.fold(0, (a, b) => a + b.seconds);
  Json toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'category': category,
    'time': time,
    'icon': icon,
    'color': color,
    'archived': archived,
    'weekdays': weekdays,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
  Routine copy(Json c) => Routine.fromJson({...toJson(), ...c});
  factory Routine.fromJson(Json j) => Routine(
    id: text(j['id']),
    title: text(j['title']),
    note: text(j['note'] ?? ''),
    category: text(j['category'] ?? ''),
    time: text(j['time'] ?? '08:00'),
    icon: integer(j['icon'] ?? 0xe037, max: 0x10ffff),
    color: integer(j['color'] ?? 0xff0d9488, max: 0xffffffff),
    archived: j['archived'] == true,
    weekdays: List<int>.from(j['weekdays'] as List),
    steps: objects(j['steps']).map(RoutineStep.fromJson).toList(),
  );
}

class StepRun {
  final RoutineStep plan;
  final String status;
  final int elapsed;
  final String? event;
  final String? eventHash;
  final String note;
  StepRun({
    required this.plan,
    this.status = 'pending',
    this.elapsed = 0,
    this.event,
    this.eventHash,
    this.note = '',
  }) {
    if (!['pending', 'completed', 'skipped'].contains(status) ||
        elapsed < 0 ||
        elapsed > maxElapsed)
      throw const FormatException('Invalid step state');
  }
  Json toJson() => {
    'plan': plan.toJson(),
    'status': status,
    'elapsed': elapsed,
    'event': event,
    'eventHash': eventHash,
    'note': note,
  };
  StepRun copy(Json c) => StepRun.fromJson({...toJson(), ...c});
  factory StepRun.fromJson(Json j) => StepRun(
    plan: RoutineStep.fromJson(Map<String, dynamic>.from(j['plan'] as Map)),
    status: text(j['status']),
    elapsed: integer(j['elapsed'], max: maxElapsed),
    event: j['event'] as String?,
    eventHash: j['eventHash'] as String?,
    note: text(j['note'] ?? ''),
  );
}

class RoutineSession {
  final String id, routine, title, started, day, status, note;
  final String? anchor, ended;
  final List<StepRun> steps;
  final int cursor;
  final bool autoNext, recoveryWarning;
  RoutineSession({
    required this.id,
    required this.routine,
    required this.title,
    required this.started,
    required this.day,
    required List<StepRun> steps,
    this.cursor = 0,
    this.status = 'active',
    this.anchor,
    this.ended,
    this.note = '',
    this.autoNext = false,
    this.recoveryWarning = false,
  }) : steps = List.unmodifiable(steps) {
    timestamp(started);
    date(day);
    if (anchor != null) timestamp(anchor);
    if (ended != null) timestamp(ended);
    if (steps.isEmpty ||
        steps.length > 200 ||
        cursor < 0 ||
        cursor >= steps.length ||
        !['active', 'finished', 'aborted'].contains(status) ||
        status != 'active' && anchor != null)
      throw const FormatException('Invalid session');
  }
  bool get running => anchor != null && status == 'active';
  int get elapsed => steps.fold(0, (a, b) => a + b.elapsed);
  int get planned => steps.fold(0, (a, b) => a + b.plan.seconds);
  Json toJson() => {
    'id': id,
    'routine': routine,
    'title': title,
    'started': started,
    'day': day,
    'steps': steps.map((s) => s.toJson()).toList(),
    'cursor': cursor,
    'status': status,
    'anchor': anchor,
    'ended': ended,
    'note': note,
    'autoNext': autoNext,
    'recoveryWarning': recoveryWarning,
  };
  RoutineSession copy(Json c) => RoutineSession.fromJson({...toJson(), ...c});
  factory RoutineSession.fromJson(Json j) => RoutineSession(
    id: text(j['id']),
    routine: text(j['routine']),
    title: text(j['title']),
    started: timestamp(j['started']),
    day: text(j['day']),
    steps: objects(j['steps']).map(StepRun.fromJson).toList(),
    cursor: integer(j['cursor'], max: 199),
    status: text(j['status']),
    anchor: j['anchor'] as String?,
    ended: j['ended'] as String?,
    note: text(j['note'] ?? ''),
    autoNext: j['autoNext'] == true,
    recoveryWarning: j['recoveryWarning'] == true,
  );
}

class HabitState {
  final int revision;
  final List<HabitOperation> operations;
  final List<HabitTrash> trash;
  final List<Json> tombstones;
  final List<Json> clockPolicies;
  final String? undoBatch;
  bool isTrashed(String kind, String id) =>
      trash.any((t) => t.kind == kind && t.entity == id);
  Iterable<Habit> get liveHabits =>
      habits.where((h) => !isTrashed('habit', h.id));
  Iterable<Routine> get liveRoutines =>
      routines.where((r) => !isTrashed('routine', r.id));
  final List<Habit> habits;
  final List<HabitEvent> events;
  final List<Routine> routines;
  final List<RoutineSession> sessions;
  final List<Pause> pauses;
  final Map<String, dynamic> settings;
  HabitState({
    this.revision = 0,
    List<HabitOperation> operations = const [],
    List<HabitTrash> trash = const [],
    List<Json> tombstones = const [],
    List<Json>? clockPolicies,
    this.undoBatch,
    List<Habit> habits = const [],
    List<HabitEvent> events = const [],
    List<Routine> routines = const [],
    List<RoutineSession> sessions = const [],
    List<Pause> pauses = const [],
    Json settings = const {},
  }) : clockPolicies = List.unmodifiable(
         (clockPolicies ??
                 [
                   {
                     'id': 'legacy-clock',
                     'zone': settings['zone'] ?? 'Asia/Ho_Chi_Minh',
                     'dayBoundaryMinutes': settings['dayBoundaryMinutes'] ?? 0,
                     'effectiveFrom': '1900-01-01T00:00:00.000Z',
                   },
                 ])
             .map((v) => freezeJson(v) as Json),
       ),
       operations = List.unmodifiable(operations),
       trash = List.unmodifiable(trash),
       tombstones = List.unmodifiable(
         tombstones.map((t) => freezeJson(t) as Json),
       ),
       habits = List.unmodifiable(habits),
       pauses = List.unmodifiable(pauses),
       events = List.unmodifiable(events),
       routines = List.unmodifiable(routines),
       sessions = List.unmodifiable(sessions),
       settings = freezeJson(settings) as Json;
  String get zone => settings['zone'] as String? ?? 'Asia/Ho_Chi_Minh';
  int get weekStart => settings['weekStart'] as int? ?? 1;
  int get backfill => settings['backfill'] as int? ?? 90;
  int get dayBoundaryMinutes => settings['dayBoundaryMinutes'] as int? ?? 0;
  Json toJson() => {
    'app': 'handy-habit',
    'schema': habitSchema,
    'revision': revision,
    'operations': operations.map((o) => o.toJson()).toList(),
    'trash': trash.map((t) => t.toJson()).toList(),
    'tombstones': tombstones,
    'clockPolicies': clockPolicies,
    'undoBatch': undoBatch,
    'entityOrder': {
      'habits': habits.map((h) => h.id).toList(),
      'routines': routines.map((r) => r.id).toList(),
    },
    'habits': habits.map((e) => e.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'routines': routines.map((e) => e.toJson()).toList(),
    'sessions': sessions.map((e) => e.toJson()).toList(),
    'pauses': pauses.map((e) => e.toJson()).toList(),
    'settings': settings,
  };
  HabitState copy(Json c) {
    final j = {...toJson(), ...c};
    j['entityOrder'] = {
      ...toJson()['entityOrder'] as Map,
      for (final kind in ['habits', 'routines'])
        if (c.containsKey(kind))
          kind: [for (final row in objects(c[kind])) row['id']],
    };
    return HabitState.fromJson(j);
  }

  factory HabitState.fromJson(Json j) {
    if (j['app'] != 'handy-habit' ||
        ![1, 2, 3, 4, 5].contains(j['schema']) ||
        j['schema'] == 1 && j['pauses'] != null) {
      throw const FormatException('Unsupported Habit backup/schema');
    }
    final old = (j['schema'] as int) < 3;
    final s = HabitState(
      revision: integer(j['revision']),
      operations: objects(
        old ? legacyOperations(j) : j['operations'] ?? [],
      ).map(HabitOperation.fromJson).toList(),
      trash: objects(j['trash'] ?? []).map(HabitTrash.fromJson).toList(),
      tombstones: objects(j['tombstones'] ?? []),
      clockPolicies: j['clockPolicies'] == null
          ? null
          : objects(j['clockPolicies']),
      undoBatch: j['undoBatch'] as String?,
      habits: orderedHabitRows(j, 'habits').map(Habit.fromJson).toList(),
      events: objects(j['events']).map(HabitEvent.fromJson).toList(),
      routines: orderedHabitRows(j, 'routines').map(Routine.fromJson).toList(),
      sessions: objects(j['sessions']).map(RoutineSession.fromJson).toList(),
      pauses: objects(j['pauses'] ?? []).map(Pause.fromJson).toList(),
      settings: Map<String, dynamic>.from(j['settings'] as Map),
    );
    s.validate();
    return s;
  }
  void validate() {
    location(zone);
    integer(dayBoundaryMinutes, max: 1439);
    validateOperations(operations);
    if (clockPolicies.isEmpty || clockPolicies.length > 1000)
      throw const FormatException('Invalid clock policies');
    final policyIds = <String>{};
    DateTime? previousPolicy;
    for (final p in clockPolicies) {
      if (!policyIds.add(text(p['id'])))
        throw const FormatException('Duplicate clock policy');
      location(text(p['zone']));
      integer(p['dayBoundaryMinutes'], max: 1439);
      final effective = DateTime.parse(timestamp(p['effectiveFrom']));
      if (previousPolicy != null && !effective.isAfter(previousPolicy))
        throw const FormatException(
          'Clock policies must have increasing effective instants',
        );
      previousPolicy = effective;
    }
    for (final t in tombstones) {
      text(t['id']);
      text(t['entity']);
      timestamp(t['deletedAt']);
      if (t['kind'] == 'habit' && habits.any((h) => h.id == t['entity']) ||
          t['kind'] == 'routine' && routines.any((r) => r.id == t['entity'])) {
        throw const FormatException('Deleted identity cannot be reused');
      }
      if (!['habit', 'routine'].contains(t['kind']))
        throw const FormatException('Invalid tombstone');
    }
    final trashKeys = <String>{};
    for (final t in trash) {
      if (!trashKeys.add('${t.kind}:${t.entity}') ||
          !(t.kind == 'habit'
              ? habits.any((h) => h.id == t.entity)
              : routines.any((r) => r.id == t.entity))) {
        throw const FormatException('Invalid trash reference');
      }
    }
    if (!['system', 'en', 'vi'].contains(settings['locale'] ?? 'system') ||
        !['system', 'light', 'dark'].contains(settings['theme'] ?? 'system'))
      throw const FormatException('Invalid preferences');
    for (final key in ['reportFrom', 'reportUntil']) {
      if (settings[key] != null) date(text(settings[key]));
    }
    if (settings['runNotice'] != null && settings['runNotice'] is! bool)
      throw const FormatException('Invalid preferences');
    if (settings['quietStart'] != null)
      minuteOfDay(text(settings['quietStart']));
    if (settings['quietEnd'] != null) minuteOfDay(text(settings['quietEnd']));
    integer(weekStart, min: 1, max: 7);
    integer(backfill, min: 1, max: 3660);
    for (final list in [
      habits.map((e) => e.id),
      events.map((e) => e.id),
      routines.map((e) => e.id),
      sessions.map((e) => e.id),
      pauses.map((e) => e.id),
      trash.map((e) => e.id),
      tombstones.map((e) => text(e['id'])),
    ]) {
      if (list.any((id) => id.isEmpty) || list.toSet().length != list.length)
        throw const FormatException('Duplicate/empty ID');
    }
    if (sessions.where((s) => s.status == 'active').length > 1)
      throw const FormatException('Only one active routine');
    final byId = {for (final h in habits) h.id: h},
        keys = <String>{},
        totals = <String, int>{},
        skips = <String>{};
    for (final h in habits) {
      for (final s in h.schedules.skip(1)) {
        final prev = h.schedules[h.schedules.indexOf(s) - 1];
        if ((s.kind == 'weekly' || prev.kind == 'weekly') &&
            date(s.from).weekday != s.weekStart)
          throw const FormatException('Weekly changes require week boundary');
      }
    }
    for (final e in events) {
      final h = byId[e.habit];
      if (h == null ||
          e.day.compareTo(h.created) < 0 ||
          h.type == 'binary' && e.value != 0 && e.value != 1000 ||
          h.type == 'count' && e.value % 1000 != 0 ||
          h.isNegative && e.source != 'manual')
        throw const FormatException('Incompatible entry');
      final k = '${e.habit}:${e.day}';
      totals[k] = (totals[k] ?? 0) + e.value;
      if (e.skipped) skips.add(k);
      if (e.source == 'routine' && !keys.add('${e.session}:${e.step}'))
        throw const FormatException('Duplicate linked entry');
    }
    if (totals.entries.any(
      (e) => e.value > maxValue || skips.contains(e.key) && e.value != 0,
    ))
      throw const FormatException('Invalid day total');
    for (final h in habits.where((h) => h.type == 'binary')) {
      if (totals.entries.any(
        (e) => e.key.substring(0, e.key.length - 11) == h.id && e.value > 1000,
      ))
        throw const FormatException(
          'Binary progress cannot exceed one completion',
        );
    }
    if (pauses.length > maxPauses)
      throw const FormatException('At most 1000 pauses');
    for (final p in pauses) {
      if (p.habits.any((h) => !byId.containsKey(h)))
        throw const FormatException('Unknown habit in pause');
    }
    for (final r in routines) {
      for (final step in r.steps) {
        if (step.habit != null && !byId.containsKey(step.habit))
          throw const FormatException('Unknown linked habit');
        validateMapping(step);
      }
    }
    for (final s in sessions) {
      if (s.steps.map((e) => e.plan.id).toSet().length != s.steps.length)
        throw const FormatException('Duplicate step snapshot');
      if (s.status == 'active') {
        for (final step in s.steps.where((v) => v.status == 'pending')) {
          validateMapping(step.plan);
        }
      }
    }
    final reminderIds = <String>{};
    final reminderRows = objects(settings['reminders'] ?? []);
    if (reminderRows.length > 200)
      throw const FormatException('At most 200 reminder rules');
    for (final raw in reminderRows) {
      final r = Reminder.fromJson(raw);
      if (r.id.isEmpty ||
          !reminderIds.add(r.id) ||
          !(r.type == 'habit'
              ? byId.containsKey(r.target)
              : routines.any((v) => v.id == r.target)))
        throw const FormatException('Invalid reminder reference or ID');
    }
  }

  void validateMapping(RoutineStep step) {
    final habit = habits.where((h) => h.id == step.habit).firstOrNull;
    if (habit != null &&
        (habit.isNegative ||
            habit.type == 'binary' && step.linkedValue != 1000 ||
            habit.type == 'count' && step.linkedValue % 1000 != 0))
      throw const FormatException(
        'Linked value is incompatible with habit type',
      );
  }
}
