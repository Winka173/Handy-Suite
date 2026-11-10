part of '../handy_habit_engine.dart';

DateTime date(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s))
    throw const FormatException('Invalid calendar date');
  final p = s.split('-').map(int.parse).toList(),
      d = DateTime.utc(p[0], p[1], p[2]);
  if (d.year < 1900 ||
      d.year > 2200 ||
      d.toIso8601String().substring(0, 10) != s)
    throw const FormatException('Invalid calendar date');
  return d;
}

String day(DateTime d) => d.toIso8601String().substring(0, 10);
String addDays(String d, int count) => day(date(d).add(Duration(days: count)));
bool _zonesReady = false;
tz.Location location(String zone) {
  if (zone == 'UTC' || zone == 'Etc/UTC') return tz.UTC;
  if (!_zonesReady) {
    zones.initializeTimeZones();
    _zonesReady = true;
  }
  return tz.getLocation(zone);
}

String localDay(DateTime now, String zone) =>
    day(tz.TZDateTime.from(now, location(zone)));

/// Chooses a version by instant and constructs that local day's cutoff. A DST
/// gap moves the cutoff forward by the gap; a repeated time uses its first
/// occurrence, so the habit day cannot roll back during the repeated hour.
/// Saved event days are never derived again from timestamps.
String habitDayAt(HabitState s, DateTime instant) {
  final eligible = s.clockPolicies
      .where(
        (p) => !DateTime.parse(timestamp(p['effectiveFrom'])).isAfter(instant),
      )
      .toList();
  eligible.sort(
    (a, b) => DateTime.parse(
      timestamp(a['effectiveFrom']),
    ).compareTo(DateTime.parse(timestamp(b['effectiveFrom']))),
  );
  final policy = eligible.isEmpty ? s.clockPolicies.first : eligible.last;
  final local = tz.TZDateTime.from(instant, location(policy['zone'] as String));
  final calendar = day(local);
  final minutes = policy['dayBoundaryMinutes'] as int;
  var cutoff = tz.TZDateTime(
    local.location,
    local.year,
    local.month,
    local.day,
    minutes ~/ 60,
    minutes % 60,
  );
  // TZDateTime chooses different sides of an ambiguous time across hemispheres.
  // Resolve matching wall times explicitly, taking the earliest occurrence.
  final wall = DateTime.utc(
    local.year,
    local.month,
    local.day,
    minutes ~/ 60,
    minutes % 60,
  );
  final offsets = {
    for (final shift in [-2, 0, 2])
      tz.TZDateTime.from(
        cutoff.add(Duration(days: shift)),
        local.location,
      ).timeZoneOffset,
  };
  for (final offset in offsets) {
    final candidate = tz.TZDateTime.from(wall.subtract(offset), local.location);
    if (candidate.year == local.year &&
        candidate.month == local.month &&
        candidate.day == local.day &&
        candidate.hour * 60 + candidate.minute == minutes &&
        candidate.isBefore(cutoff))
      cutoff = candidate;
  }
  return instant.isBefore(cutoff) ? addDays(calendar, -1) : calendar;
}

String weekOf(String d, int weekStart) =>
    addDays(d, -((date(d).weekday - weekStart + 7) % 7));
Schedule? scheduleOn(Habit h, String d) =>
    h.schedules.where((s) => s.from.compareTo(d) <= 0).lastOrNull;
bool isScheduledOn(Habit h, String d) {
  if (h.archivedFrom != null && d.compareTo(h.archivedFrom!) >= 0 ||
      h.archivedPeriods.any(
        (p) =>
            d.compareTo(p['from'] as String) >= 0 &&
            d.compareTo(p['until'] as String) <= 0,
      ))
    return false;
  final s = scheduleOn(h, d);
  if (s == null ||
      d.compareTo(h.created) < 0 ||
      h.end != null && d.compareTo(h.end!) > 0)
    return false;
  return switch (s.kind) {
    'weekdays' => s.weekdays.contains(date(d).weekday),
    'interval' => date(d).difference(date(s.from)).inDays % s.interval == 0,
    _ => true,
  };
}

String? nextDueDate(Habit h, String from) {
  for (var i = 0; i <= 3660; i++) {
    final d = addDays(from, i);
    if (isScheduledOn(h, d)) return d;
  }
  return null;
}

class HabitIndex {
  final Map<String, int> totals = {};
  final Set<String> skipped = {};
  final List<Pause> pauses;
  Map<String, String> deletedAfter = {};
  HabitIndex(Iterable<HabitEvent> events, [Iterable<Pause> pauses = const []])
    : pauses = List.unmodifiable(pauses) {
    for (final e in events) {
      final k = '${e.habit}:${e.day}';
      totals[k] = (totals[k] ?? 0) + e.value;
      if (e.skipped) skipped.add(k);
    }
  }

  /// Records and pauses of [s]: what statuses and metrics read.
  factory HabitIndex.of(HabitState s) => HabitIndex(s.events, s.pauses)
    ..deletedAfter = {
      for (final t in s.trash.where((t) => t.kind == 'habit'))
        t.entity: t.localDay,
    };
  int value(String habit, String d) => totals['$habit:$d'] ?? 0;
  bool skip(String habit, String d) => skipped.contains('$habit:$d');
  bool paused(String habit, String d) =>
      deletedAfter[habit] != null && d.compareTo(deletedAfter[habit]!) > 0 ||
      pauses.any((p) => p.covers(habit, d));
}

Habit archiveHabit(Habit h, String today, bool archived) {
  if (archived) {
    final from = addDays(today, 1);
    return h.copy({
      'archived': true,
      'archivedFrom': from.compareTo(h.created) < 0 ? h.created : from,
    });
  }
  final periods = [...h.archivedPeriods];
  if (h.archivedFrom != null && h.archivedFrom!.compareTo(today) < 0)
    periods.add({'from': h.archivedFrom, 'until': addDays(today, -1)});
  return h.copy({
    'archived': false,
    'archivedFrom': null,
    'archivedPeriods': periods,
  });
}

String habitStatus(Habit h, String d, String today, HabitIndex index) {
  if (d.compareTo(today) > 0) return 'future';
  if (!isScheduledOn(h, d)) return 'notScheduled';
  if (index.skip(h.id, d)) return 'skipped';
  final s = scheduleOn(h, d)!, v = index.value(h.id, d);
  if (v >= s.target) return 'completed';
  if (v > 0) return 'partial';
  if (index.paused(h.id, d)) return 'paused';
  if (s.kind == 'weekly') return d == today ? 'open' : 'notScheduled';
  return d.compareTo(today) < 0 ? 'missed' : 'open';
}

class HabitMetrics {
  final int current, longest, completed, eligible;
  final String unit;
  const HabitMetrics(
    this.current,
    this.longest,
    this.completed,
    this.eligible,
    this.unit,
  );
}

HabitMetrics metrics(
  Habit h,
  String today,
  int weekStart,
  HabitIndex index, {
  String? from,
}) {
  date(today);
  final latest = scheduleOn(h, today);
  if (latest == null) return const HabitMetrics(0, 0, 0, 0, 'days');
  final weekly = latest.kind == 'weekly';
  if (weekly) weekStart = latest.weekStart;
  var segment = h.created;
  for (var i = 1; i < h.schedules.length; i++) {
    final s = h.schedules[i];
    if (s.from.compareTo(today) > 0) break;
    if ((s.kind == 'weekly') != (h.schedules[i - 1].kind == 'weekly') ||
        s.kind == 'weekly' && s.weekStart != h.schedules[i - 1].weekStart)
      segment = s.from;
  }
  final begin = from != null && from.compareTo(segment) > 0 ? from : segment;
  if (date(today).difference(date(begin)).inDays > 110000)
    throw const FormatException('History range too large');
  var run = 0, longest = 0, completed = 0, eligible = 0;
  if (weekly) {
    var w = weekOf(begin, weekStart);
    if (w.compareTo(begin) < 0) w = addDays(w, 7);
    final currentWeek = weekOf(today, weekStart);
    for (; w.compareTo(currentWeek) <= 0; w = addDays(w, 7)) {
      final s = scheduleOn(h, w);
      if (s == null || s.kind != 'weekly') continue;
      // Paused days shrink the quota (rounded up) and are no chance to
      // miss; a paused day done anyway still counts.
      var count = 0, opportunities = 0;
      for (var i = 0; i < 7; i++) {
        final d = addDays(w, i);
        if (isScheduledOn(h, d) && !index.skip(h.id, d)) {
          final done =
              d.compareTo(today) <= 0 &&
              index.value(h.id, d) >= scheduleOn(h, d)!.target;
          if (done) count++;
          if (done || !index.paused(h.id, d)) opportunities++;
        }
      }
      final quota = weekQuota(h, w, index);
      if (quota == 0 || opportunities < quota) continue;
      final qualifies = count >= quota,
          closed = addDays(w, 6).compareTo(today) < 0;
      if (!closed && !qualifies) continue;
      eligible++;
      if (qualifies) {
        completed++;
        run++;
        longest = max(longest, run);
      } else {
        run = 0;
      }
    }
  } else {
    for (var d = begin; d.compareTo(today) <= 0; d = addDays(d, 1)) {
      final s = scheduleOn(h, d);
      if (s == null ||
          s.kind == 'weekly' ||
          !isScheduledOn(h, d) ||
          index.skip(h.id, d))
        continue;
      final ok = index.value(h.id, d) >= s.target;
      // A paused day not done is neither kept nor broken.
      if (!ok && index.paused(h.id, d)) continue;
      if (d == today && !ok) continue;
      eligible++;
      if (ok) {
        completed++;
        run++;
        longest = max(longest, run);
      } else {
        run = 0;
      }
    }
  }
  return HabitMetrics(
    run,
    longest,
    completed,
    eligible,
    weekly ? 'weeks' : 'days',
  );
}

HabitState record(
  HabitState state,
  HabitEvent event, {
  required String today,
  bool allowExtra = false,
}) {
  if (state.isTrashed('habit', event.habit))
    throw StateError('Habit is in Trash');
  final existing = state.events.where((e) => e.id == event.id).firstOrNull;
  if (existing != null) {
    if (jsonEncode(existing.toJson()) != jsonEncode(event.toJson()))
      throw const FormatException('Conflicting event ID');
    return state;
  }
  final h = state.habits.firstWhere((h) => h.id == event.habit),
      index = HabitIndex(state.events);
  if (h.archived ||
      event.day.compareTo(today) > 0 ||
      date(today).difference(date(event.day)).inDays > state.backfill)
    throw const FormatException('Outside editable check-in window');
  if (!allowExtra &&
      index.value(h.id, event.day) >=
          (scheduleOn(h, event.day)?.target ?? 1000))
    return state;
  return recordDayIntent(
    state,
    state.copy({
      'events': [...state.events.map((e) => e.toJson()), event.toJson()],
    }),
    event.habit,
    event.day,
    'addDelta',
    event.value,
    event: event.id,
    skipped: event.skipped,
  );
}

HabitState setManualTotal(
  HabitState s,
  String habit,
  String d,
  int total, {
  required String today,
  String note = '',
  bool skipped = false,
}) {
  final h = s.habits.firstWhere((h) => h.id == habit);
  if (s.isTrashed('habit', h.id) ||
      h.archived ||
      d.compareTo(today) > 0 ||
      date(today).difference(date(d)).inDays > s.backfill ||
      d.compareTo(h.created) < 0)
    throw const FormatException('Date outside backfill window');
  final linked = s.events
      .where((e) => e.habit == habit && e.day == d && e.source != 'manual')
      .fold(0, (v, e) => v + e.value);
  if (total < linked || skipped && linked > 0)
    throw const FormatException(
      'Undo linked routine progress in its session first',
    );
  final entries = s.events
      .where((e) => !(e.habit == habit && e.day == d && e.source == 'manual'))
      .map((e) => e.toJson())
      .toList();
  if (total > linked || skipped || note.isNotEmpty)
    entries.add(
      HabitEvent(
        id: uid(),
        habit: habit,
        day: d,
        value: total - linked,
        skipped: skipped,
        note: note,
      ).toJson(),
    );
  return recordDayIntent(
    s,
    s.copy({'events': entries}),
    habit,
    d,
    'setManualTotal',
    total,
    skipped: skipped,
  );
}

int minuteOfDay(String s) {
  if (!RegExp(r'^\d\d:\d\d$').hasMatch(s))
    throw const FormatException('Use HH:mm');
  final a = s.split(':').map(int.parse).toList();
  if (a[0] > 23 || a[1] > 59)
    throw const FormatException('Invalid reminder time');
  return a[0] * 60 + a[1];
}

class Reminder {
  final String id, target, type, time;
  final List<int> weekdays;
  final bool enabled;
  final String? snooze;
  Reminder({
    required this.id,
    required this.target,
    required this.type,
    this.time = '08:00',
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
    this.snooze,
  }) {
    minuteOfDay(time);
    if (!['habit', 'routine'].contains(type) ||
        weekdays.any((d) => d < 1 || d > 7))
      throw const FormatException('Invalid reminder');
    if (snooze != null) timestamp(snooze);
  }
  Json toJson() => {
    'id': id,
    'target': target,
    'type': type,
    'time': time,
    'weekdays': weekdays,
    'enabled': enabled,
    'snooze': snooze,
  };
  factory Reminder.fromJson(Json j) => Reminder(
    id: text(j['id']),
    target: text(j['target']),
    type: text(j['type']),
    time: text(j['time']),
    weekdays: List<int>.from(j['weekdays'] as List),
    enabled: j['enabled'] == true,
    snooze: j['snooze'] as String?,
  );
}

class DueReminder {
  final String key;
  final tz.TZDateTime when;
  const DueReminder(this.key, this.when);
}

List<DueReminder> dueReminders(HabitState s, DateTime now) {
  final loc = location(s.zone),
      local = tz.TZDateTime.from(now, loc),
      result = <DueReminder>[];
  final quietStart = minuteOfDay(
        s.settings['quietStart'] as String? ?? '22:00',
      ),
      quietEnd = minuteOfDay(s.settings['quietEnd'] as String? ?? '07:00');
  bool quiet(tz.TZDateTime at) =>
      _quiet(at.hour * 60 + at.minute, quietStart, quietEnd);

  for (final r in objects(
    s.settings['reminders'] ?? [],
  ).map(Reminder.fromJson).where((r) => r.enabled)) {
    bool eligible(String d) {
      if (!r.weekdays.contains(date(d).weekday)) return false;
      if (r.type == 'habit') {
        final h = s.habits
            .where(
              (h) =>
                  h.id == r.target &&
                  !h.archived &&
                  !s.isTrashed('habit', h.id),
            )
            .firstOrNull;
        return h != null &&
            isScheduledOn(h, d) &&
            !s.pauses.any((p) => p.covers(h.id, d));
      }
      final routine = s.routines
          .where(
            (v) =>
                v.id == r.target &&
                !v.archived &&
                !s.isTrashed('routine', v.id),
          )
          .firstOrNull;
      return routine != null &&
          routine.weekdays.contains(date(d).weekday) &&
          !s.pauses.any((p) => p.everything && p.coversDay(d));
    }

    void add(String key, tz.TZDateTime at) {
      if (quiet(at))
        at = tz.TZDateTime(
          loc,
          at.year,
          at.month,
          at.day +
              (at.hour * 60 + at.minute >= quietStart && quietStart > quietEnd
                  ? 1
                  : 0),
          quietEnd ~/ 60,
          quietEnd % 60,
        );
      if (at.isAfter(local) && eligible(habitDayAt(s, at)))
        result.add(DueReminder(key, at));
    }

    if (r.snooze != null) {
      final at = tz.TZDateTime.from(DateTime.parse(r.snooze!), loc);
      if (at.isAfter(local)) {
        add('${r.id}:snooze', at);
        continue;
      }
    }
    final minutes = minuteOfDay(r.time);
    var scheduled = 0;
    for (var i = 0; i < 400 && scheduled < 50; i++) {
      final d = day(DateTime.utc(local.year, local.month, local.day + i));
      final a = date(d);
      var at = tz.TZDateTime(
        loc,
        a.year,
        a.month,
        a.day,
        minutes ~/ 60,
        minutes % 60,
      );
      if (at.hour * 60 + at.minute != minutes) continue;
      final before = result.length;
      add('${r.id}:$d', at);
      if (result.length > before) scheduled++;
    }
  }
  result.sort((a, b) => a.when.compareTo(b.when));
  final seen = <String>{};
  return result
      .where(
        (r) => seen.add(
          '${r.key.substring(0, r.key.lastIndexOf(':'))}:${r.when.toIso8601String()}',
        ),
      )
      .take(50)
      .toList();
}
