import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

/// The payload of the weekly nudge; opening it goes to Focus.
const revisitPayload = 'revisit';

/// How far back "new" reaches for the weekly nudge.
const revisitWindow = Duration(days: 14);

/// When the next weekly nudge fires and how many new saves wait unread, or
/// null when nothing is waiting (then no nudge is scheduled at all).
/// [weekday] is 1 (Monday) to 7 (Sunday); the nudge is at [hour]:00 local
/// time, the first such moment after [now].
({DateTime at, int count})? planRevisit(
  List<Bookmark> bookmarks, {
  required DateTime now,
  int weekday = DateTime.sunday,
  int hour = 19,
}) {
  final since = now.subtract(revisitWindow);
  final count = bookmarks.where((b) {
    if (b.isRead || b.isArchived) return false;
    final saved = DateTime.tryParse(b.savedAt);
    return saved != null && saved.isAfter(since);
  }).length;
  if (count == 0) return null;
  var at = DateTime(now.year, now.month, now.day, hour);
  while (at.weekday != weekday || !at.isAfter(now)) {
    at = DateTime(at.year, at.month, at.day + 1, hour);
  }
  return (at: at, count: count);
}

/// The nudge's words: a count, never a title.
String revisitText(int count, {required bool vietnamese}) => vietnamese
    ? (count == 1
          ? 'Một mục bạn lưu gần đây còn chưa xem.'
          : '$count mục bạn lưu gần đây còn chưa xem.')
    : (count == 1
          ? 'One thing you saved recently is still waiting.'
          : '$count things you saved recently are still waiting.');
