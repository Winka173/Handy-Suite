part of '../handy_habit_engine.dart';

/// Calendar ranges use civil dates, never elapsed local hours (including DST).
(String, String) progressRange(String kind, String anchor, int weekStart) {
  final d = date(anchor);
  return switch (kind) {
    'week' => (
      weekOf(anchor, weekStart),
      addDays(weekOf(anchor, weekStart), 6),
    ),
    'month' => (
      day(DateTime.utc(d.year, d.month)),
      day(DateTime.utc(d.year, d.month + 1, 0)),
    ),
    'year' => ('${d.year}-01-01', '${d.year}-12-31'),
    _ => throw const FormatException('Unknown progress range'),
  };
}

class ProgressCount {
  final int kept, eligible;
  final String unit;
  const ProgressCount(this.kept, this.eligible, this.unit);
}

/// Counts opportunities inside the range, as known on [today]. A range end
/// is not a pretend "today": a past Sunday can include its closed week.
ProgressCount progressCount(
  Habit h,
  String from,
  String until,
  String today,
  HabitIndex index,
) {
  date(from);
  date(until);
  date(today);
  if (until.compareTo(from) < 0) throw const FormatException('Reversed range');
  var kept = 0, eligible = 0;
  final units = <String>{};
  for (
    var d = from;
    d.compareTo(until) <= 0 && d.compareTo(today) <= 0;
    d = addDays(d, 1)
  ) {
    if (h.isNegative) {
      final g = negativeGoalOn(h, d);
      if (g == null) continue;
      units.add(g.window == 'week' ? 'weeks' : 'days');
      final p = negativePeriod(h, d, today, index);
      if (p.end != d ||
          p.start.compareTo(from) < 0 ||
          p.end.compareTo(today) >= 0)
        continue;
      if (!const ['withinLimit', 'overLimit'].contains(p.status)) continue;
      eligible++;
      if (p.status == 'withinLimit') kept++;
    } else {
      final s = scheduleOn(h, d);
      if (s == null) continue;
      if (s.kind == 'weekly') {
        units.add('weeks');
        final start = weekOf(d, s.weekStart), end = addDays(start, 6);
        if (end != d && d != today ||
            start.compareTo(from) < 0 ||
            end.compareTo(until) > 0)
          continue;
        final quota = weekQuota(h, start, index);
        if (quota == 0 ||
            List.generate(
              7,
              (i) => addDays(start, i),
            ).any((d) => index.conflict(h.id, d)))
          continue;
        var done = 0;
        for (var v = start; v.compareTo(end) <= 0; v = addDays(v, 1)) {
          if (habitStatus(h, v, today, index) == 'completed') done++;
        }
        if (end.compareTo(today) >= 0 && done < quota) continue;
        eligible++;
        if (done >= quota) kept++;
      } else {
        units.add('days');
        final status = habitStatus(h, d, today, index);
        if (const ['completed', 'missed', 'partial'].contains(status) &&
            (d != today || status == 'completed')) {
          eligible++;
          if (status == 'completed') kept++;
        }
      }
    }
  }
  return ProgressCount(
    kept,
    eligible,
    units.length > 1 ? 'goals' : units.firstOrNull ?? 'days',
  );
}

class HeatDay {
  final String day;
  final int kept, eligible, unknown, paused;
  const HeatDay(this.day, this.kept, this.eligible, this.unknown, this.paused);
  double get ratio => eligible == 0 ? 0 : kept / eligible;
}

/// Daily evidence for a calendar/heatmap. Closed weekly limits use the final
/// whole-week result on each day; open weeks never look like earned success.
List<HeatDay> progressDays(
  Iterable<Habit> habits,
  String from,
  String until,
  String today,
  HabitIndex index,
) {
  date(from);
  date(until);
  date(today);
  final span = date(until).difference(date(from)).inDays;
  if (span < 0 || span > 3660)
    throw const FormatException('Invalid heatmap range');
  final list = habits.toList();
  return [
    for (var i = 0; i <= span; i++)
      (() {
        final d = addDays(from, i);
        var kept = 0, eligible = 0, unknown = 0, paused = 0;
        for (final h in list) {
          var status = habitStatus(h, d, today, index);
          if (h.isNegative && isScheduledOn(h, d) && d.compareTo(today) <= 0) {
            final p = negativePeriod(h, d, today, index);
            if (p.end.compareTo(today) >= 0 &&
                !const [
                  'paused',
                  'skipped',
                  'conflict',
                  'unknown',
                ].contains(status))
              status = 'open';
          }
          if (const [
            'completed',
            'withinLimit',
            'missed',
            'partial',
            'overLimit',
          ].contains(status))
            eligible++;
          if (status == 'completed' || status == 'withinLimit') kept++;
          if (status == 'unknown' || status == 'conflict') unknown++;
          if (status == 'paused' || status == 'skipped') paused++;
        }
        return HeatDay(d, kept, eligible, unknown, paused);
      })(),
  ];
}

List<HeatDay> yearHeatmap(
  Iterable<Habit> habits,
  int year,
  String today,
  HabitIndex index,
) => progressDays(habits, '$year-01-01', '$year-12-31', today, index);
