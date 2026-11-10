part of '../handy_habit_engine.dart';

/// Closed civil days only; compare the same elapsed portion of the prior period.
/// A shorter prior month/quarter is clamped, with exact dates exposed to the UI.
class InsightWindows {
  final String from, previousFrom;
  final String? until, previousUntil;
  const InsightWindows(
    this.from,
    this.until,
    this.previousFrom,
    this.previousUntil,
  );
}

InsightWindows insightWindows(String kind, String today) {
  final d = date(today);
  if (!['month', 'quarter'].contains(kind))
    throw const FormatException('Invalid comparison');
  final length = kind == 'month' ? 1 : 3;
  final month = kind == 'month' ? d.month : ((d.month - 1) ~/ 3) * 3 + 1;
  final start = DateTime.utc(d.year, month);
  final previous = DateTime.utc(d.year, month - length);
  final elapsed = d.difference(start).inDays;
  return InsightWindows(
    day(start),
    elapsed == 0 ? null : addDays(today, -1),
    day(previous),
    elapsed == 0
        ? null
        : day(
            previous.add(
              Duration(
                days: min(elapsed, start.difference(previous).inDays) - 1,
              ),
            ),
          ),
  );
}

class InsightCount {
  final int kept, eligible;
  const InsightCount(this.kept, this.eligible);
  int get missed => eligible - kept;
  int? get percent => eligible == 0 ? null : (100 * kept / eligible).round();
  String get difficulty => eligible < 7
      ? 'learning'
      : kept / eligible >= .8
      ? 'steady'
      : kept / eligible >= .5
      ? 'building'
      : 'stretch';
}

InsightCount insightCount(
  Iterable<Habit> habits,
  String from,
  String until,
  String today,
  HabitIndex index,
) {
  var kept = 0, eligible = 0;
  final closedUntil = until.compareTo(today) >= 0 ? addDays(today, -1) : until;
  if (closedUntil.compareTo(from) < 0) return const InsightCount(0, 0);
  for (final h in habits) {
    final c = progressCount(h, from, closedUntil, today, index);
    kept += c.kept;
    eligible += c.eligible;
  }
  return InsightCount(kept, eligible);
}

/// Daily-only evidence: never attribute an entire weekly quota/ceiling to a day.
InsightCount dailyInsight(Habit h, String d, String today, HabitIndex index) {
  if (d.compareTo(today) >= 0 ||
      !isScheduledOn(h, d) ||
      index.paused(h.id, d) ||
      index.skip(h.id, d) ||
      index.conflict(h.id, d))
    return const InsightCount(0, 0);
  if (h.isNegative
      ? negativeGoalOn(h, d)?.window != 'day'
      : scheduleOn(h, d)?.kind == 'weekly')
    return const InsightCount(0, 0);
  return insightCount([h], d, d, today, index);
}

List<InsightCount> weekdaySlips(
  Habit h,
  String from,
  String until,
  String today,
  HabitIndex index,
) {
  final kept = List.filled(7, 0), eligible = List.filled(7, 0);
  for (var d = from; d.compareTo(until) <= 0; d = addDays(d, 1)) {
    final c = dailyInsight(h, d, today, index), i = date(d).weekday - 1;
    kept[i] += c.kept;
    eligible[i] += c.eligible;
  }
  return [for (var i = 0; i < 7; i++) InsightCount(kept[i], eligible[i])];
}

/// Current grouping, not a claim about the time a historic check-in occurred.
String insightDayPart(HabitState s, Habit h) {
  final explicit = (s.settings['habitDayParts'] as Map?)?[h.id];
  if (['morning', 'afternoon', 'evening', 'anytime'].contains(explicit))
    return explicit as String;
  final times = [
    for (final r in objects(s.settings['reminders'] ?? []))
      if (r['enabled'] == true && r['type'] == 'habit' && r['target'] == h.id)
        minuteOfDay(r['time'] as String),
    for (final r in s.liveRoutines)
      if (!r.archived && r.steps.any((step) => step.habit == h.id))
        minuteOfDay(r.time),
  ]..sort();
  return times.isEmpty
      ? 'anytime'
      : times.first < 720
      ? 'morning'
      : times.first < 1080
      ? 'afternoon'
      : 'evening';
}

Map<String, InsightCount> insightGroups(
  HabitState s,
  String from,
  String until,
  String today, {
  required bool byCollection,
}) {
  final groups = <String, List<Habit>>{};
  for (final h in s.liveHabits) {
    final key = byCollection ? h.category : insightDayPart(s, h);
    groups.putIfAbsent(key, () => []).add(h);
  }
  final index = HabitIndex.of(s);
  return {
    for (final g in groups.entries)
      g.key: insightCount(g.value, from, until, today, index),
  };
}

class MoodCooccurrence {
  final int keptDays, otherDays, keptSum, otherSum;
  const MoodCooccurrence(
    this.keptDays,
    this.otherDays,
    this.keptSum,
    this.otherSum,
  );
  bool get enough =>
      keptDays + otherDays >= 14 && keptDays >= 3 && otherDays >= 3;
  double? get keptAverage => keptDays == 0 ? null : keptSum / keptDays;
  double? get otherAverage => otherDays == 0 ? null : otherSum / otherDays;
}

MoodCooccurrence moodCooccurrence(
  HabitState s,
  Habit h,
  String from,
  String until,
  String today,
) {
  final index = HabitIndex.of(s);
  final conflicts = moodSyncConflicts(s);
  var kept = 0, other = 0, keptSum = 0, otherSum = 0;
  for (final m in s.moods) {
    if (m.deleted || m.day.compareTo(from) < 0 || m.day.compareTo(until) > 0)
      continue;
    // A disputed mood revision is not a known observation.
    if (conflicts.containsKey(m.id)) continue;
    final c = dailyInsight(h, m.day, today, index);
    if (c.eligible == 0) continue;
    if (c.kept == 1) {
      kept++;
      keptSum += m.mood;
    } else {
      other++;
      otherSum += m.mood;
    }
  }
  return MoodCooccurrence(kept, other, keptSum, otherSum);
}

/// Filters describe current membership. Day/outcome filters never rewrite data.
class InsightFilter {
  final String collection, dayPart, direction, outcome;
  final int weekday;
  const InsightFilter({
    this.collection = '',
    this.dayPart = '',
    this.direction = '',
    this.outcome = '',
    this.weekday = 0,
  });
  List<Habit> habits(HabitState s) => s.liveHabits
      .where(
        (h) =>
            (collection.isEmpty || h.category == collection) &&
            (dayPart.isEmpty || insightDayPart(s, h) == dayPart) &&
            (direction.isEmpty || h.isNegative == (direction == 'reduce')),
      )
      .toList();
  List<HeatDay> days(HabitState s, String from, String until, String today) => [
    for (final d in progressDays(
      habits(s),
      from,
      until,
      today,
      HabitIndex.of(s),
    ))
      if ((weekday == 0 || date(d.day).weekday == weekday) &&
          (outcome.isEmpty ||
              switch (outcome) {
                'kept' => d.kept > 0,
                'missed' => d.eligible > d.kept,
                'unknown' => d.unknown > 0,
                _ => false,
              }))
        d,
  ];
}

class GoalSuggestion {
  final String habit, fingerprint, id;
  final int kept, eligible, target, proposed;
  const GoalSuggestion(
    this.habit,
    this.fingerprint,
    this.id,
    this.kept,
    this.eligible,
    this.target,
    this.proposed,
  );
}

GoalSuggestion? goalSuggestion(HabitState s, Habit h, String today) {
  final schedule = scheduleOn(h, today);
  if (h.isNegative ||
      h.archived ||
      !['count', 'quantity', 'duration'].contains(h.type) ||
      schedule == null ||
      schedule.kind == 'weekly' ||
      h.schedules.last.from.compareTo(today) > 0)
    return null;
  final index = HabitIndex.of(s);
  final results = <InsightCount>[];
  for (var i = 1; i <= 28 && results.length < 10; i++) {
    final d = addDays(today, -i);
    if (d.compareTo(schedule.from) < 0) break;
    final c = dailyInsight(h, d, today, index);
    if (c.eligible > 0) results.add(c);
  }
  if (results.length < 10) return null;
  final kept = results.fold(0, (int n, c) => n + c.kept);
  // Habit amounts, including minutes, are stored in thousandths.
  const quantum = 1000;
  final target = schedule.target;
  final proposed = kept >= 9
      ? ((target * 1.25 / quantum).ceil() * quantum)
      : kept <= 5
      ? ((target * .75 / quantum).floor() * quantum)
      : target;
  if (proposed < quantum || proposed == target || proposed > maxValue)
    return null;
  final fingerprint = sha256
      .convert(utf8.encode(jsonEncode(h.toJson())))
      .toString();
  final id = '$fingerprint:$kept:$target:$proposed';
  if ((s.settings['goalDecisions'] as Map?)?.containsKey(id) == true)
    return null;
  return GoalSuggestion(h.id, fingerprint, id, kept, 10, target, proposed);
}

HabitState decideGoal(
  HabitState s,
  GoalSuggestion offered,
  String today, {
  required bool accept,
}) {
  final h = s.liveHabits.where((h) => h.id == offered.habit).firstOrNull;
  final current = h == null ? null : goalSuggestion(s, h, today);
  if (current == null || current.id != offered.id)
    throw StateError(
      'Suggestion changed; reopen insights / Gợi ý đã đổi; mở lại phân tích',
    );
  final nextDay = addDays(today, 1);
  final decisions = <String, dynamic>{
    ...s.settings['goalDecisions'] as Map<String, dynamic>? ?? {},
    offered.id: accept ? 'accepted' : 'dismissed',
  };
  return s.copy({
    'settings': {...s.settings, 'goalDecisions': decisions},
    if (accept)
      'habits': [
        for (final item in s.habits)
          item.id != h!.id
              ? item.toJson()
              : item.copy({
                  'schedules': [
                    for (final old in item.schedules) old.toJson(),
                    {
                      ...scheduleOn(item, today)!.toJson(),
                      'id': uid(),
                      'from': nextDay,
                      'target': offered.proposed,
                    },
                  ],
                }).toJson(),
      ],
  });
}
