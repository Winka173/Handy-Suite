part of '../handy_habit_engine.dart';

/// An upper bound, distinct from a positive schedule's minimum/quota.
class NegativeGoal {
  final String id, from, window;
  final int limit, weekStart;
  NegativeGoal({
    required this.id,
    required this.from,
    this.window = 'day',
    this.limit = 0,
    this.weekStart = 1,
  }) {
    text(id, max: 200);
    date(from);
    if (id.isEmpty ||
        !['day', 'week'].contains(window) ||
        limit < 0 ||
        limit > maxValue ||
        limit % 1000 != 0 ||
        weekStart < 1 ||
        weekStart > 7)
      throw const FormatException('Invalid negative goal');
  }
  Json toJson() => {
    'id': id,
    'from': from,
    'window': window,
    'limit': limit,
    'weekStart': weekStart,
  };
  factory NegativeGoal.fromJson(Json j) => NegativeGoal(
    id: text(j['id']),
    from: text(j['from']),
    window: text(j['window']),
    limit: integer(j['limit']),
    weekStart: integer(j['weekStart'], min: 1, max: 7),
  );
}

NegativeGoal? negativeGoalOn(Habit h, String d) =>
    h.negativeGoals.where((g) => g.from.compareTo(d) <= 0).lastOrNull;

/// Closed whole weeks infer blank days as no incident. Daily blanks stay unknown.
class NegativePeriod {
  final String start, end, status;
  final int total, known, unknown;
  const NegativePeriod(
    this.start,
    this.end,
    this.status,
    this.total,
    this.known,
    this.unknown,
  );
}

NegativePeriod negativePeriod(
  Habit h,
  String d,
  String today,
  HabitIndex index,
) {
  final g = negativeGoalOn(h, d);
  if (g == null) return NegativePeriod(d, d, 'notScheduled', 0, 0, 0);
  final start = g.window == 'week' ? weekOf(d, g.weekStart) : d;
  final end = g.window == 'week' ? addDays(start, 6) : d;
  var total = 0, known = 0, unknown = 0;
  var excluded = false, conflict = false;
  for (var v = start; v.compareTo(end) <= 0; v = addDays(v, 1)) {
    if (!isScheduledOn(h, v) ||
        negativeGoalOn(h, v)?.id != g.id ||
        index.paused(h.id, v) ||
        index.skip(h.id, v))
      excluded = true;
    if (v.compareTo(today) > 0) continue;
    total += index.value(h.id, v);
    if (index.known(h.id, v)) {
      known++;
    } else {
      unknown++;
    }
    conflict |= index.conflict(h.id, v);
  }
  final status = conflict
      ? 'conflict'
      : excluded
      ? 'paused'
      : total > g.limit
      ? 'overLimit'
      : end.compareTo(today) >= 0
      ? 'open'
      : unknown > 0 && g.window == 'day'
      ? 'unknown'
      : 'withinLimit';
  return NegativePeriod(start, end, status, total, known, unknown);
}

String negativeDayStatus(Habit h, String d, String today, HabitIndex index) {
  if (d.compareTo(today) > 0) return 'future';
  if (!isScheduledOn(h, d)) return 'notScheduled';
  if (index.conflict(h.id, d)) return 'conflict';
  if (index.skip(h.id, d)) return 'skipped';
  if (index.paused(h.id, d)) return 'paused';
  final goal = negativeGoalOn(h, d)!;
  if (goal.window == 'week' &&
      addDays(weekOf(d, goal.weekStart), 6).compareTo(today) < 0) {
    return negativePeriod(h, d, today, index).status;
  }
  if (!index.known(h.id, d)) return 'unknown';
  final g = negativeGoalOn(h, d)!;
  var total = index.value(h.id, d);
  if (g.window == 'week') {
    total = 0;
    for (
      var v = weekOf(d, g.weekStart);
      v.compareTo(d) <= 0;
      v = addDays(v, 1)
    ) {
      if (index.conflict(h.id, v)) return 'conflict';
      total += index.value(h.id, v);
    }
  }
  return total > g.limit ? 'overLimit' : 'withinLimit';
}

HabitMetrics negativeMetrics(
  Habit h,
  String today,
  HabitIndex index, {
  String? from,
}) {
  var run = 0, longest = 0, completed = 0, eligible = 0;
  var unit = negativeGoalOn(h, today)?.window == 'week' ? 'weeks' : 'days';
  var segment = h.created;
  for (var i = 1; i < h.negativeGoals.length; i++) {
    final g = h.negativeGoals[i], prev = h.negativeGoals[i - 1];
    if (g.from.compareTo(today) > 0) break;
    if (g.window != prev.window ||
        g.window == 'week' && g.weekStart != prev.weekStart)
      segment = g.from;
  }
  var d = from != null && from.compareTo(segment) > 0 ? from : segment;
  while (d.compareTo(today) < 0) {
    final p = negativePeriod(h, d, today, index);
    if (p.start.compareTo(d) < 0) {
      d = addDays(p.end, 1);
      continue;
    }
    if (p.end.compareTo(today) >= 0) break;
    if (const ['withinLimit', 'overLimit'].contains(p.status)) {
      eligible++;
      if (p.status == 'withinLimit') {
        completed++;
        run++;
        longest = max(longest, run);
      } else {
        run = 0;
      }
    }
    d = addDays(p.end, 1);
  }
  return HabitMetrics(run, longest, completed, eligible, unit);
}
