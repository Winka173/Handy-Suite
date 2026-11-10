part of '../handy_habit_engine.dart';

/// The data schema written by this version. Schema 1 (no pauses) still
/// reads; it is upgraded on the next save.
const habitSchema = 4;
const maxPauseDays = 366;
const maxPauses = 1000;

/// A stretch of days off, for every habit ([habits] empty) or for the
/// chosen ones. Paused days are neutral: a day not done is left out of
/// every count, a day done anyway still counts. See DATA_SCHEMA.md.
class Pause {
  final String id, from, until, reason;
  final List<String> habits;
  Pause({
    required this.id,
    required this.from,
    required this.until,
    this.reason = '',
    List<String> habits = const [],
  }) : habits = List.unmodifiable(habits) {
    text(id, max: 200);
    text(reason, max: 200);
    final a = date(from), b = date(until);
    if (b.isBefore(a) ||
        b.difference(a).inDays + 1 > maxPauseDays ||
        habits.length > 1000 ||
        habits.toSet().length != habits.length ||
        habits.any((h) => h.isEmpty))
      throw const FormatException('Invalid pause');
  }

  bool get everything => habits.isEmpty;
  bool coversDay(String d) => d.compareTo(from) >= 0 && d.compareTo(until) <= 0;
  bool covers(String habit, String d) =>
      coversDay(d) && (everything || habits.contains(habit));

  /// 'upcoming', 'current' or 'past', seen from [today].
  String phase(String today) => today.compareTo(from) < 0
      ? 'upcoming'
      : today.compareTo(until) > 0
      ? 'past'
      : 'current';

  Json toJson() => {
    'id': id,
    'from': from,
    'until': until,
    'reason': reason,
    'habits': habits,
  };
  Pause copy(Json changes) => Pause.fromJson({...toJson(), ...changes});
  factory Pause.fromJson(Json j) => Pause(
    id: text(j['id']),
    from: text(j['from']),
    until: text(j['until']),
    reason: text(j['reason'] ?? '', max: 200),
    habits: [for (final h in j['habits'] as List? ?? []) text(h, max: 200)],
  );
}

/// The last day of the paused stretch that holds [d] for [habit],
/// following pauses that overlap or touch; null when [d] is not paused.
String? pausedUntil(Iterable<Pause> pauses, String habit, String d) {
  String? end;
  var probe = d;
  for (var guard = 0; guard < maxPauses + 1; guard++) {
    final covering = pauses.where((p) => p.covers(habit, probe));
    if (covering.isEmpty) break;
    final last = covering
        .map((p) => p.until)
        .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    if (end != null && last.compareTo(end) <= 0) break;
    end = last;
    probe = addDays(last, 1);
  }
  return end;
}

/// The pause for every habit that holds [today], if any, with the last
/// day of that stretch (pauses for every habit that touch are one stretch).
(Pause, String)? restingNow(HabitState s, String today) {
  final p = s.pauses
      .where((p) => p.everything && p.coversDay(today))
      .fold<Pause?>(
        null,
        (a, b) => a == null || b.until.compareTo(a.until) > 0 ? b : a,
      );
  if (p == null) return null;
  final everything = s.pauses.where((p) => p.everything);
  return (p, pausedUntil(everything, '', today) ?? p.until);
}

/// Adds or changes a pause. A new start may not reach back past the
/// fill-in window, the same limit as filling in a day.
HabitState putPause(HabitState s, Pause pause, {required String today}) {
  final old = s.pauses.where((p) => p.id == pause.id).firstOrNull;
  final earliest = addDays(today, -s.backfill);
  if ((old == null || old.from != pause.from) &&
      pause.from.compareTo(earliest) < 0)
    throw const FormatException(
      'Start is before the fill-in window / Ngày bắt đầu trước khoảng ghi bù',
    );
  for (final h in pause.habits) {
    if (!s.habits.any((x) => x.id == h))
      throw const FormatException('Unknown habit in pause');
  }
  return s.copy({
    'pauses': [
      for (final p in s.pauses)
        if (p.id != pause.id) p.toJson(),
      pause.toJson(),
    ],
  });
}

HabitState deletePause(HabitState s, String id) => s.copy({
  'pauses': [
    for (final p in s.pauses)
      if (p.id != id) p.toJson(),
  ],
});

/// Ends a pause before its last day: today is an ordinary day again. A
/// pause that has not begun, or began today, goes; one already over stays.
HabitState endPause(HabitState s, String id, {required String today}) {
  final p = s.pauses.firstWhere((p) => p.id == id);
  if (p.until.compareTo(today) < 0) return s;
  final yesterday = addDays(today, -1);
  if (p.from.compareTo(yesterday) > 0) return deletePause(s, id);
  return s.copy({
    'pauses': [
      for (final x in s.pauses)
        x.id == id ? x.copy({'until': yesterday}).toJson() : x.toJson(),
    ],
  });
}

/// A deleted habit leaves the pauses it was named in; a pause left with
/// no habit goes, so it never turns into a pause for everything.
HabitState dropHabitFromPauses(HabitState s, String habit) => s.copy({
  'pauses': [
    for (final p in s.pauses)
      if (!p.habits.contains(habit))
        p.toJson()
      else if (p.habits.length > 1)
        p.copy({
          'habits': [...p.habits.where((h) => h != habit)],
        }).toJson(),
  ],
});

/// The days-a-week quota for the week starting [week]: prorated by the
/// paused days, rounded up; 0 when the whole week is paused.
int weekQuota(Habit h, String week, HabitIndex index) {
  final s = scheduleOn(h, week) ?? h.schedules.first;
  var paused = 0;
  for (var i = 0; i < 7; i++) {
    final d = addDays(week, i);
    if (index.paused(h.id, d)) paused++;
  }
  return (s.weeklyTarget * (7 - paused) + 6) ~/ 7;
}

/// Whether [now] falls in the quiet hours set in [s] (the same rule
/// reminders use; one time twice turns them off).
bool inQuietHours(HabitState s, DateTime now) {
  final at = tz.TZDateTime.from(now, location(s.zone));
  return _quiet(
    at.hour * 60 + at.minute,
    minuteOfDay(s.settings['quietStart'] as String? ?? '22:00'),
    minuteOfDay(s.settings['quietEnd'] as String? ?? '07:00'),
  );
}

bool _quiet(int m, int start, int end) => start == end
    ? false
    : start < end
    ? m >= start && m < end
    : m >= start || m < end;
