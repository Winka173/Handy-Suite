/// "Remind me" for one bookmark: the fixed choices and their real times.
/// Off is the default and is never chosen for the person.
library;

/// One choice with the moment it stands for (local time).
class ReadLaterChoice {
  /// `tonight`, `tomorrow` or `weekend`.
  final String id;
  final DateTime at;
  const ReadLaterChoice(this.id, this.at);
}

/// Tonight at 20:00 (only before 19:30), tomorrow at 09:00 and the coming
/// Saturday at 09:00 (today when it is Saturday before 09:00).
List<ReadLaterChoice> readLaterChoices(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tonight = DateTime(now.year, now.month, now.day, 20);
  var saturday = DateTime(
    today.year,
    today.month,
    today.day + ((DateTime.saturday - today.weekday) % 7),
    9,
  );
  if (!saturday.isAfter(now)) {
    saturday = DateTime(saturday.year, saturday.month, saturday.day + 7, 9);
  }
  return [
    if (now.isBefore(DateTime(now.year, now.month, now.day, 19, 30)))
      ReadLaterChoice('tonight', tonight),
    ReadLaterChoice(
      'tomorrow',
      DateTime(today.year, today.month, today.day + 1, 9),
    ),
    ReadLaterChoice('weekend', saturday),
  ];
}

/// The choice a stored reminder matches, if any (to the minute).
String? readLaterChoiceOf(DateTime? at, DateTime now) {
  if (at == null) return null;
  final local = at.toLocal();
  for (final c in readLaterChoices(now)) {
    if (c.at.difference(local).inMinutes.abs() < 1) return c.id;
  }
  return 'custom';
}

/// "Remind in 1 hour" from a notification.
const snoozeFor = Duration(hours: 1);
