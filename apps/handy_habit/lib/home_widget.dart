import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'design/studio_style.dart';
import 'insights/insight_dates.dart';

const habitWidgetClass = 'com.example.handysuite.habit.HandyWidget';
const singleHabitWidgetClass = 'com.example.handysuite.habit.SingleHabitWidget';
const routineWidgetClass = 'com.example.handysuite.habit.RoutineWidget';

List<Habit> widgetHabits(HabitState s) =>
    s.liveHabits.where((h) => !h.archived).toList();
List<Routine> widgetRoutines(HabitState s) =>
    s.liveRoutines.where((r) => !r.archived).toList();

/// Links carry IDs only. Quick check-in opens the app and its normal Undo flow.
String habitWidgetUri(Habit h, String today, HabitState s) {
  final available =
      isScheduledOn(h, today) && !HabitIndex.of(s).paused(h.id, today);
  final quick =
      available && !h.isNegative && (h.type == 'binary' || h.type == 'count');
  return 'handy-habit://${quick ? 'checkin' : 'habit'}/${Uri.encodeComponent(h.id)}';
}

/// Retained Today contract; counts are calculated from today's actual status.
HomeWidgetView habitWidgetView(HabitState s, String today, {required bool vi}) {
  final index = HabitIndex.of(s), habits = widgetHabits(s);
  final title = vi ? 'Handy Habit · Hôm nay' : 'Handy Habit · Today';
  final resting = restingNow(s, today);
  if (resting != null)
    return HomeWidgetView(
      title: title,
      value: vi ? 'Đang nghỉ' : 'On a break',
      detail: '${vi ? 'Đến hết' : 'Until'} ${insightDate(resting.$2, vi: vi)}',
      uri: 'handy-habit://today',
      progress: 0,
    );
  final due = habits
      .where((h) => isScheduledOn(h, today) && !index.paused(h.id, today))
      .toList();
  final open =
      due
          .where(
            (h) => const {
              'unknown',
              'overLimit',
              'withinLimit',
              'conflict',
              'open',
              'partial',
              'missed',
            }.contains(habitStatus(h, today, today, index)),
          )
          .toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));
  final kept = due
      .where(
        (h) => const {
          'completed',
          'withinLimit',
        }.contains(habitStatus(h, today, today, index)),
      )
      .length;
  final names = s.settings['widgetShowNames'] != false;
  if (habits.isEmpty)
    return HomeWidgetView(
      title: title,
      value: vi ? 'Chưa có thói quen' : 'No habits yet',
      detail: vi ? 'Chạm để tạo cái đầu tiên' : 'Tap to make the first one',
      uri: 'handy-habit://today',
      progress: 0,
    );
  final progress = due.isEmpty ? 0 : (100 * kept / due.length).round();
  return HomeWidgetView(
    title: title,
    value: due.isEmpty
        ? (vi ? 'Hôm nay không có lịch' : 'Nothing due today')
        : open.isEmpty
        ? (vi ? 'Xong hết' : 'All done')
        : (vi ? 'Còn ${open.length} việc' : '${open.length} left'),
    detail: vi
        ? '$kept/${due.length} đã giữ hôm nay'
        : '$kept/${due.length} kept today',
    uri: 'handy-habit://today',
    progress: progress,
    rows: [
      if (names)
        for (final h in open.take(3)) (h.title, habitWidgetUri(h, today, s)),
    ],
  );
}

/// All three feeds are allowlists: mood, notes, and routine step text never leave.
Map<String, HomeWidgetView> habitWidgetViews(
  HabitState s,
  String today, {
  required bool vi,
  required bool pro,
  bool dark = false,
}) {
  final names = s.settings['widgetShowNames'] != false;
  final habits = widgetHabits(s), routines = widgetRoutines(s);
  final chosenHabit = s.settings['widgetHabit'],
      chosenRoutine = s.settings['widgetRoutine'];
  // A removed selection is left empty rather than silently changing what a tap records.
  final h = chosenHabit == null
      ? habits.firstOrNull
      : habits.where((h) => h.id == chosenHabit).firstOrNull;
  final r = chosenRoutine == null
      ? routines.firstOrNull
      : routines.where((r) => r.id == chosenRoutine).firstOrNull;
  final status = h == null
      ? ''
      : habitStatus(h, today, today, HabitIndex.of(s));
  final active = r == null
      ? null
      : s.sessions
            .where((x) => x.routine == r.id && x.status == 'active')
            .firstOrNull;
  final available =
      h != null &&
      isScheduledOn(h, today) &&
      !HabitIndex.of(s).paused(h.id, today);
  final quick =
      h != null &&
      available &&
      !h.isNegative &&
      (h.type == 'binary' || h.type == 'count');
  final views = <String, HomeWidgetView>{
    'today': habitWidgetView(s, today, vi: vi),
    'habit': HomeWidgetView(
      title: vi ? 'Handy Habit · Một thói quen' : 'Handy Habit · One habit',
      value: h == null
          ? (vi ? 'Chọn một thói quen' : 'Choose a habit')
          : names
          ? h.title
          : (vi ? 'Thói quen hôm nay' : 'Today’s habit'),
      detail: h == null
          ? (vi ? 'Mở Cài đặt › Tiện ích' : 'Open Settings › Widgets')
          : !available
          ? (vi
                ? 'Hôm nay không đến lịch · chạm để xem'
                : 'Not due today · tap to view')
          : status == 'completed'
          ? (vi ? 'Đã giữ · chạm để xem' : 'Kept · tap to review')
          : quick
          ? (vi ? 'Chạm để ghi nhận trong app' : 'Tap to check in in the app')
          : (vi
                ? 'Chạm để xem và ghi nhận trong app'
                : 'Tap to view and record in the app'),
      uri: h == null ? 'handy-habit://widgets' : habitWidgetUri(h, today, s),
      progress: status == 'completed' ? 100 : 0,
    ),
    'routine': HomeWidgetView(
      title: vi ? 'Handy Habit · Quy trình' : 'Handy Habit · Routine',
      value: r == null
          ? (vi ? 'Chọn một quy trình' : 'Choose a routine')
          : names
          ? r.title
          : (vi ? 'Quy trình của bạn' : 'Your routine'),
      detail: r == null
          ? (vi ? 'Mở Cài đặt › Tiện ích' : 'Open Settings › Widgets')
          : active != null
          ? (vi ? 'Chạm để tiếp tục trong app' : 'Tap to resume in the app')
          : (vi
                ? '${r.steps.length} bước · chạm để mở'
                : '${r.steps.length} steps · tap to open'),
      uri: r == null
          ? 'handy-habit://widgets'
          : 'handy-habit://routine/${Uri.encodeComponent(r.id)}',
    ),
  };
  final style = StudioStyle.read(s.settings, pro: pro);
  Map<String, String> colours(bool night) {
    final p = studioPalette(style.palette, night);
    String hex(int n) => '#${n.toRadixString(16).padLeft(8, '0')}';
    return {
      'bg': hex(p.surface.toARGB32()),
      'ink': hex(p.ink.toARGB32()),
      'muted': hex(p.muted.toARGB32()),
      'accent': hex(p.vermilion.toARGB32()),
    };
  }

  final light = colours(false), night = colours(true);
  return {
    for (final e in views.entries)
      e.key: HomeWidgetView(
        title: e.value.title,
        value: e.value.value,
        detail: e.value.detail,
        uri: e.value.uri,
        rows: e.value.rows,
        progress: e.value.progress,
        style: dark ? night : light,
        extra: {
          'palette': style.palette,
          for (final c in light.entries) 'light_${c.key}': c.value,
          for (final c in night.entries) 'dark_${c.key}': c.value,
        },
      ),
  };
}
