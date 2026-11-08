part of '../handy_boards_engine.dart';

// Local notifications, planned from the cards (the source of truth), never
// from what the OS happens to hold. The app cancels what is no longer
// planned and schedules what is, under stable keys, on every change, at
// start and on resume, so nothing duplicates.
//
// Preferences (`preferences['notify']`, on this device):
//   daily      bool    today's work at [at] (planned today + due today)
//   at         'HH:MM' the clock time for summaries and day reminders (09:00)
//   dueLead    int     days before a due day to remind (0 = on the day,
//                      null = off)
//   backlog    bool    one nudge the next morning when work is left behind
//   quietFrom, quietTo 'HH:MM' summaries never ring inside this window
//   private    bool    no card titles in notifications
//   muted      [board] boards that never notify
//   weekly     bool    Pro: a Monday review of what was left behind
// The master switch stays `preferences['notifications']`. Reminders set on
// a card keep their exact time and are not moved by quiet hours.

class PlannedNote {
  final String key, title, body, link, channel;
  final DateTime at; // local wall time
  const PlannedNote(
    this.key,
    this.at,
    this.title,
    this.body,
    this.link, {
    this.channel = 'summary',
  });
}

/// The most notifications kept scheduled at once (iOS keeps 64; Android has
/// no hard cap but the nearest ones matter). The rest are planned again
/// when the app next opens.
const notifyCap = 48;

Json notifyPrefs(BoardsState s) => object(s.preferences['notify'] ?? {});

(int, int) _clockOf(Object? v, (int, int) fallback) {
  final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch('${v ?? ''}');
  if (m == null) return fallback;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  return h < 24 && min < 60 ? (h, min) : fallback;
}

/// [at] moved out of the quiet window, if it falls inside it.
DateTime _outOfQuiet(DateTime at, Json p) {
  if (p['quietFrom'] == null || p['quietTo'] == null) return at;
  final (fh, fm) = _clockOf(p['quietFrom'], (22, 0));
  final (th, tm) = _clockOf(p['quietTo'], (7, 0));
  final from = fh * 60 + fm, to = th * 60 + tm, t = at.hour * 60 + at.minute;
  final inside = from <= to ? (t >= from && t < to) : (t >= from || t < to);
  if (!inside) return at;
  // The end of the quiet time: today, or tomorrow when it wraps midnight.
  final end = DateTime(at.year, at.month, at.day, th, tm);
  return t >= from && from > to ? addDaysAt(end, 1) : end;
}

DateTime addDaysAt(DateTime d, int n) =>
    DateTime(d.year, d.month, d.day + n, d.hour, d.minute);

/// What should be scheduled from [now] on, nearest first, at most
/// [notifyCap]. [pro] adds the weekly review.
List<PlannedNote> planNotifications(
  BoardsState s,
  DateTime now, {
  required bool vi,
  bool pro = false,
  int days = 14,
}) {
  if (s.preferences['notifications'] != true) return const [];
  final p = notifyPrefs(s);
  final muted = {for (final b in (p['muted'] as List? ?? const [])) '$b'};
  final private = p['private'] == true;
  final (h, m) = _clockOf(p['at'], (9, 0));
  final today = calendarDay(now);
  String t(String en, String v) => vi ? v : en;
  final open = [
    for (final c in topTasks(s))
      if (!muted.contains(c.str('board')) && isOpenCard(s, c)) c,
  ];
  final out = <PlannedNote>[];

  // Reminders set on cards: their exact time, never moved.
  for (final r in s.rows('reminders')) {
    final c = s.maybe('tasks', r.str('task'));
    final at = DateTime.tryParse(r.str('at'))?.toLocal();
    if (!r.flag('enabled') || c == null || at == null || !at.isAfter(now))
      continue;
    if (muted.contains(c.str('board')) || !isOpenCard(s, c)) continue;
    out.add(
      PlannedNote(
        'boards:${r.id}',
        at,
        'Handy Boards',
        private ? t('A card reminder', 'Nhắc một thẻ') : c.str('title'),
        'handy-boards://task?id=${c.id}',
        channel: 'reminders',
      ),
    );
  }

  DateTime morning(DateTime day) =>
      _outOfQuiet(DateTime(day.year, day.month, day.day, h, m), p);

  // Today's work, each day it has some.
  if (p['daily'] == true) {
    for (var i = 0; i < days; i++) {
      final day = addDays(today, i), at = morning(day);
      if (!at.isAfter(now)) continue;
      final n = open.where((c) {
        final planned = scheduledDay(c), due = dueDay(c);
        return planned == day || (planned == null && due == day);
      }).length;
      if (n == 0) continue;
      out.add(
        PlannedNote(
          'boards:daily:${isoDay(day)}',
          at,
          t('Today', 'Hôm nay'),
          t(
            n == 1 ? 'You have 1 task today' : 'You have $n tasks today',
            'Hôm nay bạn có $n việc',
          ),
          'handy-boards://my-work',
        ),
      );
    }
  }

  // Due soon: [dueLead] days ahead, at the reminder time.
  final lead = p['dueLead'];
  if (lead is int && lead >= 0 && lead <= 14) {
    for (final c in open) {
      final due = dueDay(c);
      if (due == null) continue;
      final day = addDays(due, -lead), at = morning(day);
      if (!at.isAfter(now) || daysBetween(today, day) >= days) continue;
      final when = switch (lead) {
        0 => t('today', 'hôm nay'),
        1 => t('tomorrow', 'ngày mai'),
        _ => t('in $lead days', 'sau $lead ngày'),
      };
      out.add(
        PlannedNote(
          'boards:due:${c.id}:${isoDay(due)}:$lead',
          at,
          t('Due $when', 'Đến hạn $when'),
          private
              ? t('A card is due $when', 'Một thẻ đến hạn $when')
              : t(
                  '${c.str('title')} is due $when',
                  '${c.str('title')} đến hạn $when',
                ),
          'handy-boards://task?id=${c.id}',
          channel: 'reminders',
        ),
      );
    }
  }

  // Left behind: one nudge, the next morning, while there is any.
  final behind = open.where((c) {
    final planned = scheduledDay(c), due = dueDay(c);
    return (planned != null && planned.isBefore(today)) ||
        (due != null && due.isBefore(today));
  }).length;
  if (p['backlog'] == true && behind > 0) {
    var at = morning(today);
    if (!at.isAfter(now)) at = morning(addDays(today, 1));
    out.add(
      PlannedNote(
        'boards:backlog',
        at,
        t('Left behind', 'Còn tồn'),
        t(
          behind == 1
              ? '1 task from earlier days is not done yet'
              : '$behind tasks from earlier days are not done yet',
          'Còn $behind việc từ hôm trước chưa xong',
        ),
        'handy-boards://my-work',
      ),
    );
  }

  // Pro: a Monday review.
  if (pro && p['weekly'] == true) {
    final monday = addDays(mondayOf(today), 7);
    final at0 = morning(mondayOf(today));
    final at = at0.isAfter(now) ? at0 : morning(monday);
    out.add(
      PlannedNote(
        'boards:weekly',
        at,
        t('Weekly review', 'Xem lại đầu tuần'),
        behind > 0
            ? t('$behind tasks to look at again', '$behind việc cần xem lại')
            : t('Plan the week ahead', 'Lên kế hoạch cho tuần này'),
        'handy-boards://my-work',
      ),
    );
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return out.take(notifyCap).toList();
}
