part of '../handy_boards_engine.dart';

// The Time Navigator: one optional view over the SAME cards of any board.
// It reads three independent dates of a card and never invents any:
//
// - `due`        the deadline (a day or an instant), as before;
// - `scheduled`  the day the person means to work on it ('YYYY-MM-DD'), a
//                plan and never a second deadline; null on older cards;
// - `completedAt` when it really reached a finished column (set and cleared
//                by the column rules, never guessed for old cards).
//
// Days are calendar days at local midnight. All arithmetic goes through the
// calendar fields (DateTime(y, m, d + n)) and day counts through UTC dates,
// never through Duration.inHours / 24, so daylight saving, month ends and
// leap years come out exact. Weeks start on Monday in every language (the
// Vietnamese norm and ISO 8601); the templates' "week start" agrees.

DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Whole calendar days from [a] to [b] (negative when [b] is earlier).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int monthsBetween(DateTime a, DateTime b) =>
    (b.year - a.year) * 12 + b.month - a.month;

/// The Monday of [d]'s week.
DateTime mondayOf(DateTime d) => addDays(calendarDay(d), -(d.weekday - 1));

int _floorDiv(int a, int b) => (a / b).floor();

/// How much the time view shows: [count] days, weeks or calendar months,
/// or a custom span of exact days from [first] to [last] (inclusive).

class TimeRange {
  final String unit; // 'day' | 'week' | 'month' | 'custom'
  final int count;
  final DateTime? first, last;
  const TimeRange(this.unit, [this.count = 1]) : first = null, last = null;
  TimeRange.custom(DateTime from, DateTime to)
    : unit = 'custom',
      count = 0,
      first = calendarDay(from),
      last = calendarDay(to);

  static const standard = TimeRange('week');

  /// The ranges offered directly; Custom adds the rest.
  static const presets = [
    TimeRange('day'),
    TimeRange('day', 2),
    TimeRange('day', 3),
    TimeRange('week'),
    TimeRange('week', 2),
    TimeRange('month'),
    TimeRange('month', 2),
    TimeRange('month', 3),
  ];

  /// A custom span may cover up to a year.
  static const maxCustomDays = 366;

  bool get custom => unit == 'custom';

  /// Days in one window, for the units that have a fixed length.
  int? get days => switch (unit) {
    'day' => count,
    'week' => 7 * count,
    'custom' => daysBetween(first!, last!) + 1,
    _ => null,
  };

  /// What a board stores; anything unreadable falls back to a week.
  static TimeRange read(Object? raw) {
    if (raw is! Map) return standard;
    if (raw['unit'] == 'custom') {
      final a = DateTime.tryParse('${raw['first']}'),
          b = DateTime.tryParse('${raw['last']}');
      if (a == null || b == null) return standard;
      final n = daysBetween(a, b) + 1;
      if (n < 1 || n > maxCustomDays) return standard;
      return TimeRange.custom(a, b);
    }
    if (const {'day', 'week', 'month'}.contains(raw['unit']) &&
        raw['count'] is int) {
      return TimeRange(
        raw['unit'] as String,
        (raw['count'] as int).clamp(1, 12),
      );
    }
    return standard;
  }

  Json toJson() => custom
      ? {'unit': unit, 'first': isoDay(first!), 'last': isoDay(last!)}
      : {'unit': unit, 'count': count};

  @override
  bool operator ==(Object other) =>
      other is TimeRange &&
      other.unit == unit &&
      other.count == count &&
      other.first == first &&
      other.last == last;
  @override
  int get hashCode => Object.hash(unit, count, first, last);
}

/// One window of the time view: the days from [first] up to, not
/// including, [end].

class TimeWindow {
  final DateTime first, end;
  TimeWindow(DateTime first, DateTime end)
    : first = calendarDay(first),
      end = calendarDay(end);
  DateTime get last => addDays(end, -1);
  int get days => daysBetween(first, end);
  bool contains(DateTime day) =>
      !calendarDay(day).isBefore(first) && calendarDay(day).isBefore(end);
  @override
  bool operator ==(Object other) =>
      other is TimeWindow && other.first == first && other.end == end;
  @override
  int get hashCode => Object.hash(first, end);
  @override
  String toString() => '${isoDay(first)}..${isoDay(last)}';
}

/// The window that holds [today]: days start today (a stable anchor),
/// weeks on Monday, months on the 1st; a custom range is its own dates.
TimeWindow currentWindow(TimeRange r, DateTime today) {
  final d = calendarDay(today);
  return switch (r.unit) {
    'week' => TimeWindow(mondayOf(d), addDays(mondayOf(d), 7 * r.count)),
    'month' => TimeWindow(
      DateTime(d.year, d.month),
      DateTime(d.year, d.month + r.count),
    ),
    'custom' => TimeWindow(r.first!, addDays(r.last!, 1)),
    _ => TimeWindow(d, addDays(d, r.count)),
  };
}

/// The window [steps] windows after [w] (before, when negative): next to
/// it, never overlapping, never leaving a day out.
TimeWindow shiftWindow(TimeRange r, TimeWindow w, int steps) {
  if (r.unit == 'month') {
    final first = DateTime(w.first.year, w.first.month + steps * r.count);
    return TimeWindow(first, DateTime(first.year, first.month + r.count));
  }
  final n = r.days!;
  final first = addDays(w.first, steps * n);
  return TimeWindow(first, addDays(first, n));
}

/// Which window, counted from [anchor] (0), holds [day].
int windowIndex(TimeRange r, TimeWindow anchor, DateTime day) =>
    r.unit == 'month'
    ? _floorDiv(monthsBetween(anchor.first, day), r.count)
    : _floorDiv(daysBetween(anchor.first, day), r.days!);

/// The day a card is planned for, or null.
DateTime? scheduledDay(BoardRecord card) {
  final v = card.data['scheduled'];
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : calendarDay(d);
}

/// Not finished, not archived, not in the trash.
bool isOpenCard(BoardsState s, BoardRecord t) =>
    activeTask(t) && !completed(s, t);

/// One card still open from an earlier day: planned for a day gone by
/// ([pastPlan]), past its deadline ([overdue]), or both. Counted once.
class BacklogItem {
  final BoardRecord card;
  final DateTime? planned, due;
  final bool pastPlan, overdue;
  const BacklogItem(
    this.card, {
    this.planned,
    this.due,
    required this.pastPlan,
    required this.overdue,
  });

  /// The earliest of its past dates: where it first fell behind.
  DateTime get since => [
    if (pastPlan) planned!,
    if (overdue) due!,
  ].reduce((a, b) => a.isBefore(b) ? a : b);
}

/// Every card of [board] still open from before [today], oldest first.
/// [shows] applies the board's filter (category, search) when given.
List<BacklogItem> backlogOf(
  BoardsState s,
  String board,
  DateTime today, {
  bool Function(BoardRecord card)? shows,
}) {
  final d = calendarDay(today);
  final items = <BacklogItem>[];
  for (final t in topTasks(s, board: board)) {
    if (!isOpenCard(s, t) || (shows != null && !shows(t))) continue;
    final planned = scheduledDay(t), due = dueDay(t);
    final pastPlan = planned != null && planned.isBefore(d);
    final overdue = due != null && due.isBefore(d);
    if (pastPlan || overdue) {
      items.add(
        BacklogItem(
          t,
          planned: planned,
          due: due,
          pastPlan: pastPlan,
          overdue: overdue,
        ),
      );
    }
  }
  items.sort((a, b) => a.since.compareTo(b.since));
  return items;
}

/// What one other window holds, for the navigator's markers. Past windows
/// count cards whose plan or deadline falls there: [open] still open today
/// (of which [overdue] past their deadline there) and [done] finished;
/// later windows count the open cards planned or due there ([later]).
/// Each card counts once per window, however many of its dates fall in it.
class PeriodMark {
  final int index;
  final TimeWindow window;
  int open = 0, overdue = 0, done = 0, later = 0;
  PeriodMark(this.index, this.window);
  bool get past => index < 0;
}

List<PeriodMark> periodMarks(
  BoardsState s,
  String board,
  TimeRange r,
  TimeWindow current,
  DateTime today, {
  bool Function(BoardRecord card)? shows,
}) {
  final d = calendarDay(today);
  final marks = <int, PeriodMark>{};
  PeriodMark mark(int i) =>
      marks[i] ??= PeriodMark(i, shiftWindow(r, current, i));
  for (final t in topTasks(s, board: board)) {
    if (shows != null && !shows(t)) continue;
    final open = !completed(s, t);
    final planned = scheduledDay(t), due = dueDay(t);
    final at = <int, bool>{}; // window -> overdue there
    if (planned != null) at[windowIndex(r, current, planned)] = false;
    if (due != null) {
      final i = windowIndex(r, current, due);
      at[i] = (at[i] ?? false) || (open && due.isBefore(d));
    }
    for (final MapEntry(key: i, value: late) in at.entries) {
      if (i == 0) continue;
      final m = mark(i);
      if (i < 0) {
        if (open) {
          m.open++;
          if (late) m.overdue++;
        } else {
          m.done++;
        }
      } else if (open) {
        m.later++;
      }
    }
  }
  return marks.values.where((m) => m.open + m.done + m.later > 0).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
}

/// Plans [ids] for [day] (null clears the plan). Only `scheduled` changes:
/// never the deadline, the column, the category, the subtasks or the
/// completion. Each change is logged with its [reason] ('move to now',
/// 'do early', 'manual', 'undo'); cards changed together share a group id.
BoardsState scheduleCards(
  BoardsState s,
  Iterable<String> ids,
  DateTime? day, {
  String reason = 'manual',
  DateTime? now,
}) {
  final at = now ?? DateTime.now(), e = BoardsEdit(s), group = newId();
  final to = day == null ? null : isoDay(calendarDay(day));
  var changed = false;
  for (final id in ids.toSet()) {
    final t = s.get('tasks', id);
    final from = t.data['scheduled'] as String?;
    if (from == to) continue;
    changed = true;
    e.put(
      'tasks',
      t.copy({'scheduled': to, 'updated': at.toUtc().toIso8601String()}),
    );
    e.event(
      id,
      'scheduled',
      at,
      details: {'from': from, 'to': to, 'reason': reason, 'group': group},
    );
  }
  return changed ? e.finish() : s;
}

/// The plans of [ids] as they are, for an Undo.
Map<String, String?> plansOf(BoardsState s, Iterable<String> ids) => {
  for (final id in ids) id: s.get('tasks', id).data['scheduled'] as String?,
};

/// Puts plans back as [before] had them, logged as an undo (the history
/// keeps both the move and its reversal). Cards gone since are skipped.
BoardsState restorePlans(
  BoardsState s,
  Map<String, String?> before, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now(), e = BoardsEdit(s), group = newId();
  var changed = false;
  for (final MapEntry(key: id, value: to) in before.entries) {
    final t = s.maybe('tasks', id);
    if (t == null) continue;
    final from = t.data['scheduled'] as String?;
    if (from == to) continue;
    changed = true;
    e.put(
      'tasks',
      t.copy({'scheduled': to, 'updated': at.toUtc().toIso8601String()}),
    );
    e.event(
      id,
      'scheduled',
      at,
      details: {'from': from, 'to': to, 'reason': 'undo', 'group': group},
    );
  }
  return changed ? e.finish() : s;
}

/// A card's history, oldest first: only what really happened since the
/// app started keeping it. [historyFromStart] says whether it reaches back
/// to the card's creation (older cards begin part-way).
List<BoardRecord> cardHistory(BoardsState s, String card) =>
    s.rows('events').where((r) => r.str('task') == card).toList()
      ..sort((a, b) => a.str('at').compareTo(b.str('at')));

bool historyFromStart(BoardsState s, String card) => s
    .rows('events')
    .any((r) => r.str('task') == card && r.str('action') == 'created');

/// The day of a deadline value as 'YYYY-MM-DD' (for history details).
String? _dueText(Object? due) {
  if (due is! Map) return null;
  if (due['kind'] == 'day') return '${due['day']}';
  final at = DateTime.tryParse('${due['at']}')?.toLocal();
  return at == null ? null : isoDay(at);
}

/// What changed between two versions of a card, as history events. The
/// note's text, attachments and subtask titles are never copied in.
void _logCardChanges(
  BoardsEdit e,
  BoardsState s,
  BoardRecord old,
  BoardRecord next,
  DateTime at,
) {
  final group = newId();
  var logged = false;
  void log(String action, Json details) {
    logged = true;
    e.event(next.id, action, at, details: {...details, 'group': group});
  }

  if (old.str('status') != next.str('status')) {
    final from = s.maybe('statuses', old.str('status')),
        to = s.maybe('statuses', next.str('status'));
    log(
      to?.flag('done') == true
          ? 'completed'
          : from?.flag('done') == true
          ? 'reopened'
          : 'status changed',
      {
        'from': old.str('status'),
        'to': next.str('status'),
        'fromName': from?.str('title'),
        'toName': to?.str('title'),
      },
    );
  }
  final dueFrom = _dueText(old.data['due']), dueTo = _dueText(next.data['due']);
  if (dueFrom != dueTo) log('due changed', {'from': dueFrom, 'to': dueTo});
  if (old.data['scheduled'] != next.data['scheduled']) {
    log('scheduled', {
      'from': old.data['scheduled'],
      'to': next.data['scheduled'],
      'reason': 'manual',
    });
  }
  if (old.data['category'] != next.data['category']) {
    log('category changed', {
      'from': old.data['category'],
      'to': next.data['category'],
      'fromName': s
          .maybe('categories', '${old.data['category']}')
          ?.str('title'),
      'toName': s.maybe('categories', '${next.data['category']}')?.str('title'),
    });
  }
  if (old.flag('archived') != next.flag('archived')) {
    log(next.flag('archived') ? 'archived' : 'unarchived', {});
  }
  if (!logged &&
      (old.str('title') != next.str('title') ||
          old.str('notes') != next.str('notes'))) {
    log('edited', {});
  }
}

/// One card in My Work: where it lives and why it is listed. Each card is
/// listed once, in the first section that fits it.
class WorkItem {
  final BoardRecord card, board;
  final DateTime? planned, due;
  final bool overdue;

  /// Listed for today only because it is due today (no plan): labelled so.
  final bool dueOnly;
  const WorkItem(
    this.card,
    this.board, {
    this.planned,
    this.due,
    this.overdue = false,
    this.dueOnly = false,
  });
}

/// My Work across boards (a derived view, never a board): open cards
/// planned for [today] (or due today without a plan), those left behind
/// (planned or due earlier), and those coming up in the next [days] days.
/// [boards] narrows the scope (null = every board).
({List<WorkItem> today, List<WorkItem> behind, List<WorkItem> upcoming}) myWork(
  BoardsState s,
  DateTime today, {
  Set<String>? boards,
  int days = 14,
  bool Function(BoardRecord card)? shows,
}) {
  final d = calendarDay(today), end = addDays(d, days);
  final now = <WorkItem>[], behind = <WorkItem>[], later = <WorkItem>[];
  for (final t in topTasks(s)) {
    final b = t.str('board');
    if (boards != null && !boards.contains(b)) continue;
    if (!isOpenCard(s, t) || (shows != null && !shows(t))) continue;
    final board = s.get('boards', b);
    final planned = scheduledDay(t), due = dueDay(t);
    final late = due != null && due.isBefore(d);
    if ((planned != null && planned.isBefore(d)) || late) {
      behind.add(WorkItem(t, board, planned: planned, due: due, overdue: late));
    } else if (planned == d || (planned == null && due == d)) {
      now.add(
        WorkItem(
          t,
          board,
          planned: planned,
          due: due,
          dueOnly: planned == null,
        ),
      );
    } else {
      final next = planned ?? due;
      if (next != null && next.isAfter(d) && next.isBefore(end))
        later.add(WorkItem(t, board, planned: planned, due: due));
    }
  }
  int by(WorkItem a, WorkItem b) =>
      (a.planned ?? a.due!).compareTo(b.planned ?? b.due!);
  behind.sort(by);
  later.sort(by);
  return (today: now, behind: behind, upcoming: later);
}

/// Smart carry-over (Pro): which cards a run would move to [today] — open
/// cards planned for an earlier day (a deadline alone never moves; it is
/// offered with a question in the review instead), on [boards] when given.
/// A card already re-planned for today or later is not touched.
List<BoardRecord> carryOverCandidates(
  BoardsState s,
  DateTime today, {
  Set<String>? boards,
  int max = 200,
}) {
  final d = calendarDay(today);
  final out = <BoardRecord>[];
  for (final t in topTasks(s)) {
    if (boards != null && !boards.contains(t.str('board'))) continue;
    if (!isOpenCard(s, t)) continue;
    final planned = scheduledDay(t);
    if (planned != null && planned.isBefore(d)) out.add(t);
    if (out.length >= max) break;
  }
  return out;
}

/// The key of the period a carry-over runs in: one run per day, so opening
/// the app again never moves cards twice.
String carryOverPeriod(DateTime today) => isoDay(calendarDay(today));

/// Runs the automatic carry-over once for [today]: moves the candidates'
/// plans to today, logs it ('carry over') and records the period in
/// preferences so another open the same day does nothing. Returns the state
/// unchanged when it already ran, is off, or has nothing to move.
({BoardsState state, Map<String, String?> before}) runCarryOver(
  BoardsState s,
  DateTime today, {
  DateTime? now,
}) {
  final pref = object(s.preferences['carryOver'] ?? {});
  final period = carryOverPeriod(today);
  if (pref['mode'] != 'auto' || pref['last'] == period) {
    return (state: s, before: const {});
  }
  final boards = pref['boards'] is List
      ? {for (final b in pref['boards'] as List) '$b'}
      : null;
  final ids = [
    for (final t in carryOverCandidates(s, today, boards: boards)) t.id,
  ];
  final before = plansOf(s, ids);
  var next = ids.isEmpty
      ? s
      : scheduleCards(s, ids, today, reason: 'carry over', now: now);
  next = next.copy(
    preferences: {
      ...next.preferences,
      'carryOver': {...pref, 'last': period, 'moved': ids.length},
    },
  );
  return (state: next, before: before);
}

/// Cards finished per week for the last [weeks] weeks (Monday first,
/// oldest first), counted from the real completion time of cards that are
/// finished now. A card reopened since is not counted; weeks before the
/// board existed show zero.
List<(DateTime monday, int finished)> weeklyThroughput(
  BoardsState s,
  String board,
  DateTime now, {
  int weeks = 8,
}) {
  final first = addDays(mondayOf(now), -7 * (weeks - 1));
  final counts = List<int>.filled(weeks, 0);
  for (final t in topTasks(s, board: board)) {
    if (!completed(s, t)) continue;
    final at = DateTime.tryParse(t.str('completedAt'))?.toLocal();
    if (at == null) continue;
    final i = daysBetween(first, at) ~/ 7;
    if (!at.isBefore(first) && i < weeks) counts[i]++;
  }
  return [for (var i = 0; i < weeks; i++) (addDays(first, 7 * i), counts[i])];
}
