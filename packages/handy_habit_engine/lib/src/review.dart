part of '../handy_habit_engine.dart';

/// One habit across the reviewed week: each day's status and how many of
/// its due check-ins it kept.
class HabitWeek {
  final Habit habit;
  final List<String> days;
  final int kept, due;
  const HabitWeek(this.habit, this.days, this.kept, this.due);

  /// Kept under half of what was due: worth making smaller.
  bool get struggling => due >= 2 && kept * 2 < due;
}

/// A look back at one week, with the week before for comparison.
class WeekReview {
  final String start;
  final List<HabitWeek> habits;
  final int kept, due, keptBefore, dueBefore;

  /// The weekday (1 Monday … 7 Sunday) with the most missed check-ins,
  /// when at least two were missed on it.
  final int? hardestDay;
  const WeekReview(
    this.start,
    this.habits,
    this.kept,
    this.due,
    this.keptBefore,
    this.dueBefore,
    this.hardestDay,
  );
  String get end => addDays(start, 6);
}

/// The week to look back on: this one on its last day, else the one before.
String reviewWeekStart(String today, int weekStart) {
  final start = weekOf(today, weekStart);
  return addDays(today, 1) == addDays(start, 7) ? start : addDays(start, -7);
}

/// Kept and due check-ins of [h] in the week from [start], counted up to
/// [today]. A days-a-week habit is due its quota; a daily one each
/// scheduled day that was not skipped or paused.
(List<String>, int, int) _habitWeek(
  Habit h,
  String start,
  String today,
  HabitIndex index,
) {
  final days = [
    for (var i = 0; i < 7; i++) habitStatus(h, addDays(start, i), today, index),
  ];
  final kept = days.where((d) => d == 'completed').length;
  final weekly = (scheduleOn(h, start) ?? h.schedules.first).kind == 'weekly';
  final due = weekly
      ? weekQuota(h, start, index)
      : days
            .where((d) => const {'completed', 'partial', 'missed'}.contains(d))
            .length;
  return (days, min(kept, due), due);
}

WeekReview weekReview(
  HabitState s,
  HabitIndex index,
  String start,
  String today,
) {
  final end = addDays(start, 6), before = addDays(start, -7);
  final live = s.habits
      .where(
        (h) =>
            !h.archived &&
            h.created.compareTo(end) <= 0 &&
            (h.end == null || h.end!.compareTo(start) >= 0),
      )
      .toList();
  final weeks = <HabitWeek>[];
  var keptBefore = 0, dueBefore = 0;
  final missed = List.filled(8, 0);
  for (final h in live) {
    final (days, kept, due) = _habitWeek(h, start, today, index);
    if (due == 0 && kept == 0) continue;
    weeks.add(HabitWeek(h, days, kept, due));
    for (var i = 0; i < 7; i++) {
      if (days[i] == 'missed') missed[date(addDays(start, i)).weekday]++;
    }
    if (h.created.compareTo(before) <= 0) {
      final (_, k, d) = _habitWeek(h, before, today, index);
      keptBefore += k;
      dueBefore += d;
    }
  }
  var hardest = 0;
  for (var d = 1; d <= 7; d++) {
    if (missed[d] > missed[hardest]) hardest = d;
  }
  return WeekReview(
    start,
    weeks,
    weeks.fold(0, (a, w) => a + w.kept),
    weeks.fold(0, (a, w) => a + w.due),
    keptBefore,
    dueBefore,
    missed[hardest] >= 2 ? hardest : null,
  );
}
