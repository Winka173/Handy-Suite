import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'today/beads.dart' show earlierDays;

/// What the home-screen widgets draw, beyond their words: bead strings as
/// one letter a day, today's fill, the habit's colour and what a tap does.
/// The native side (HabitWidgets.kt) draws exactly this and nothing else;
/// no mood, note or step text ever leaves.
///
/// Bead letters: c kept, p part done, o not done (or unknown), s skipped,
/// z paused, v over a limit, n nothing planned, x before the habit began.
String beadLetter(String status) => switch (status) {
  'completed' || 'withinLimit' => 'c',
  'partial' => 'p',
  'skipped' => 's',
  'paused' => 'z',
  'overLimit' => 'v',
  'notScheduled' || 'future' => 'n',
  _ => 'o',
};

String _hex(int argb) =>
    '#${(argb & 0xffffffff).toRadixString(16).padLeft(8, '0')}';

/// What one tap on today's bead does from the widget: `tap` records at
/// once (done or not, one more, one incident); `open` opens the habit
/// (minutes and amounts ask how much; a full or skipped day opens it).
String widgetTapMode(Habit h, String today, HabitIndex index) {
  if (!isScheduledOn(h, today) || index.paused(h.id, today)) return 'open';
  if (index.skip(h.id, today)) return 'open';
  if (h.isNegative) return 'tap';
  if (h.type != 'binary' && h.type != 'count') return 'open';
  final target = scheduleOn(h, today)?.target ?? 1000;
  return index.value(h.id, today) >= target ? 'open' : 'tap';
}

/// One habit as the widgets draw it, under [key] (`h0_`, `habit_`…).
Map<String, String> habitBeadData(
  String key,
  Habit h,
  String today,
  HabitIndex index, {
  required bool names,
  required String neutral,
  int earlier = 6,
}) {
  final days = earlierDays(h, today, count: earlier);
  final status = habitStatus(h, today, today, index);
  final target = scheduleOn(h, today)?.target ?? 1000;
  final value = index.value(h.id, today);
  final fill = h.isNegative
      ? (index.known(h.id, today) ? 100 : 0)
      : (100 * value / target).clamp(0, 100).round();
  return {
    '${key}id': h.id,
    '${key}name': names ? h.title : neutral,
    '${key}beads':
        'x' * (earlier - days.length) +
        days.map((d) => beadLetter(habitStatus(h, d, today, index))).join(),
    '${key}state': beadLetter(status),
    '${key}fill': '$fill',
    // One tap's share of the goal, so the widget can fill ahead of the app.
    '${key}step': h.type == 'count' && !h.isNegative
        ? '${(100 * 1000 / target).clamp(1, 100).round()}'
        : '100',
    '${key}color': _hex(h.color),
    '${key}mode': widgetTapMode(h, today, index),
    '${key}open': 'handy-habit://habit/${Uri.encodeComponent(h.id)}',
  };
}

/// Week (Pro): the last seven calendar days for up to six habits.
Map<String, String> weekData(
  HabitState s,
  String today, {
  required bool vi,
  required bool names,
  required bool pro,
}) {
  final index = HabitIndex.of(s);
  final habits = s.liveHabits.where((h) => !h.archived).toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));
  final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
  const en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const vn = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final shown = habits.take(6).toList();
  return {
    'title': vi ? 'Tuần này' : 'This week',
    'pro': pro ? '1' : '0',
    'locked': vi
        ? 'Tuần là của Pro · chạm để xem'
        : 'Week comes with Pro · tap to see',
    'uri': pro ? 'handy-habit://progress' : 'handy-habit://pro?feature=heatmap',
    'days': days.map((d) => (vi ? vn : en)[date(d).weekday - 1]).join('|'),
    'count': '${shown.length}',
    for (final (i, h) in shown.indexed) ...{
      'w${i}_name': names
          ? h.title
          : (vi ? 'Thói quen ${i + 1}' : 'Habit ${i + 1}'),
      'w${i}_beads': days
          .map(
            (d) => d.compareTo(h.created) < 0
                ? 'x'
                : beadLetter(habitStatus(h, d, today, index)),
          )
          .join(),
      'w${i}_color': _hex(h.color),
      'w${i}_uri': 'handy-habit://habit/${Uri.encodeComponent(h.id)}',
    },
  };
}

/// Year (Pro): sixteen weeks of one habit, a column per week from the
/// week start, a row per weekday.
Map<String, String> yearData(
  HabitState s,
  Habit? h,
  String today, {
  required bool vi,
  required bool names,
  required bool pro,
}) {
  const weeks = 16;
  final index = HabitIndex.of(s);
  var start = addDays(today, -(weeks - 1) * 7);
  while (date(start).weekday != s.weekStart) {
    start = addDays(start, -1);
  }
  final grid = StringBuffer();
  var kept = 0, planned = 0;
  if (h != null)
    for (var w = 0; w < weeks; w++) {
      for (var d = 0; d < 7; d++) {
        final dd = addDays(start, w * 7 + d);
        if (dd.compareTo(today) > 0 || dd.compareTo(h.created) < 0) {
          grid.write('x');
          continue;
        }
        final letter = beadLetter(habitStatus(h, dd, today, index));
        if (letter == 'c') kept++;
        if (letter != 'n' && letter != 'z') planned++;
        grid.write(letter);
      }
    }
  return {
    'title': vi ? '16 tuần' : '16 weeks',
    'pro': pro ? '1' : '0',
    'locked': vi
        ? 'Bản đồ năm là của Pro · chạm để xem'
        : 'The year map comes with Pro · tap to see',
    'name': h == null
        ? (vi ? 'Chọn một thói quen' : 'Choose a habit')
        : names
        ? h.title
        : (vi ? 'Thói quen của bạn' : 'Your habit'),
    'detail': h == null
        ? ''
        : (vi
              ? 'Giữ được $kept/$planned ngày'
              : '$kept of $planned ${planned == 1 ? 'day' : 'days'} kept'),
    'grid': grid.toString(),
    'color': h == null ? '#FFB42318' : _hex(h.color),
    'uri': !pro
        ? 'handy-habit://pro?feature=heatmap'
        : h == null
        ? 'handy-habit://widgets'
        : 'handy-habit://habit/${Uri.encodeComponent(h.id)}',
  };
}
