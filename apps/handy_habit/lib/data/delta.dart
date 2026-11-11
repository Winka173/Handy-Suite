import 'dart:convert';
import 'package:handy_habit_engine/handy_habit_engine.dart';

const habitTables = ['habits', 'events', 'routines', 'sessions', 'operations'];

/// Keep typed writes within the same per-list guard as HabitState.fromJson.
/// Otherwise a successful commit could become unreadable on the next launch.
void validateStoredCounts(HabitState s) {
  for (final rows in [
    s.habits,
    s.events,
    s.routines,
    s.sessions,
    s.operations,
    s.pauses,
    s.moods,
    s.trash,
    s.tombstones,
  ]) {
    if (rows.length > 200000) {
      throw const FormatException(
        'History exceeds storage capacity; local data is preserved',
      );
    }
  }
}

Map<String, dynamic> _items(HabitState s, String kind) => switch (kind) {
  'habits' => {for (final x in s.habits) x.id: x},
  'events' => {for (final x in s.events) x.id: x},
  'routines' => {for (final x in s.routines) x.id: x},
  'sessions' => {for (final x in s.sessions) x.id: x},
  'operations' => {for (final x in s.operations) x.id: x},
  _ => throw ArgumentError(kind),
};

/// Derived only from the store's last committed immutable snapshot. CAS in the
/// storage transaction rejects a second writer before any delta is applied.
class HabitDelta {
  final changed = <String, List<Json>>{}, removed = <String, Set<String>>{};
  HabitDelta(HabitState before, HabitState after) {
    for (final kind in habitTables) {
      final a = _items(before, kind), b = _items(after, kind);
      removed[kind] = a.keys.where((id) => !b.containsKey(id)).toSet();
      changed[kind] = [
        for (final e in b.entries)
          if (!identical(a[e.key], e.value) &&
              (a[e.key] == null ||
                  jsonEncode(a[e.key].toJson()) !=
                      jsonEncode(e.value.toJson())))
            Map<String, dynamic>.from(e.value.toJson() as Map),
      ];
    }
  }
}
