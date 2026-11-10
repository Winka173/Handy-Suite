import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';

/// The fully qualified Android widget class (debug builds change the
/// package name, not the class).
const habitWidgetClass = 'com.example.handysuite.habit.HandyWidget';

/// What the home-screen widget shows: what is left today, the first three
/// open habits as tappable lines. Done-or-not habits check in from the
/// line; the others open their page, since they ask how much.
HomeWidgetView habitWidgetView(HabitState s, String today, {required bool vi}) {
  final index = HabitIndex.of(s);
  final title = vi ? 'Handy Habit · Hôm nay' : 'Handy Habit · Today';
  final resting = restingNow(s, today);
  if (resting != null) {
    final until = resting.$2.substring(5).split('-').reversed.join('/');
    return HomeWidgetView(
      title: title,
      value: vi ? 'Đang nghỉ' : 'On a break',
      detail: vi ? 'Đến hết $until' : 'Until $until',
      uri: 'handy-habit://today',
    );
  }
  final open =
      s.liveHabits
          .where(
            (h) =>
                !h.archived &&
                isScheduledOn(h, today) &&
                const {
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
  if (s.liveHabits.where((h) => !h.archived).isEmpty)
    return HomeWidgetView(
      title: title,
      value: vi ? 'Chưa có thói quen' : 'No habits yet',
      detail: vi ? 'Chạm để tạo cái đầu tiên' : 'Tap to make the first one',
      uri: 'handy-habit://today',
    );
  if (open.isEmpty)
    return HomeWidgetView(
      title: title,
      value: vi ? 'Xong hết' : 'All done',
      detail: vi ? 'Hôm nay không còn việc' : 'Nothing left today',
      uri: 'handy-habit://today',
    );
  return HomeWidgetView(
    title: title,
    value: vi ? 'Còn ${open.length} việc' : '${open.length} left',
    uri: 'handy-habit://today',
    rows: [
      for (final h in open.take(3))
        (
          '○  ${h.title}',
          h.type == 'binary' || h.type == 'count'
              ? 'handy-habit://checkin/${h.id}'
              : 'handy-habit://habit/${h.id}',
        ),
    ],
  );
}
