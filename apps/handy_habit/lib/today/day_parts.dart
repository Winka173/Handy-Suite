import 'package:handy_habit_engine/handy_habit_engine.dart';

/// Explicit choice wins, then the earliest habit reminder or linked routine.
String habitDayPart(HabitState s, Habit h) {
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
  if (times.isEmpty) return 'anytime';
  return times.first < 720
      ? 'morning'
      : times.first < 1080
      ? 'afternoon'
      : 'evening';
}
