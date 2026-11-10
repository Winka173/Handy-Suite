import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';

bool isVi(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'vi';

/// An engine amount (thousandths) as people read it: `2,5` in Vietnamese.
String figure(BuildContext context, int milli) {
  final text = amount(milli);
  return isVi(context) ? text.replaceAll('.', ',') : text;
}

/// What a habit counts in, for a figure: "pages", "min", "times".
String unitOf(BuildContext context, Habit h, {int? value}) => switch (h.type) {
  'binary' => '',
  'count' => tr(context, value == 1000 ? 'time' : 'times', 'lần'),
  'duration' => tr(context, 'min', 'phút'),
  _ => h.unit,
};

/// "3 / 10 pages", or "Done" / "Not yet" for a yes-or-no habit.
String progressText(BuildContext context, Habit h, int value, int target) {
  if (h.type == 'binary')
    return value >= target
        ? tr(context, 'Done', 'Đã xong')
        : tr(context, 'Not yet', 'Chưa làm');
  return '${figure(context, value)} / ${figure(context, target)} ${unitOf(context, h, value: target)}'
      .trim();
}

String typeLabel(BuildContext context, String type) => switch (type) {
  'binary' => tr(context, 'Done or not', 'Có hoặc chưa'),
  'count' => tr(context, 'A number of times', 'Số lần'),
  'duration' => tr(context, 'Minutes', 'Số phút'),
  _ => tr(context, 'An amount', 'Số lượng'),
};

const _en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String weekdayShort(BuildContext context, int d) =>
    tr(context, _en[d - 1], d == 7 ? 'CN' : 'T${d + 1}');

const _enLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
String weekdayLong(BuildContext context, int d) =>
    tr(context, _enLong[d - 1], d == 7 ? 'Chủ nhật' : 'Thứ ${d + 1}');

/// The days a list of weekdays covers, in words.
String weekdaysText(BuildContext context, List<int> days) {
  if (days.length == 7) return tr(context, 'Every day', 'Mỗi ngày');
  if (days.isEmpty) return tr(context, 'No set days', 'Không theo lịch');
  final sorted = [...days]..sort();
  if (sorted.join() == '12345') return tr(context, 'Weekdays', 'Ngày thường');
  if (sorted.join() == '67') return tr(context, 'Weekends', 'Cuối tuần');
  return sorted.map((d) => weekdayShort(context, d)).join(', ');
}

/// How often, in words: "Every day", "Mon, Wed, Fri", "3 days a week".
String scheduleText(BuildContext context, Schedule s) => switch (s.kind) {
  'weekdays' => weekdaysText(context, s.weekdays),
  'weekly' => tr(
    context,
    '${s.weeklyTarget} days a week',
    '${s.weeklyTarget} ngày mỗi tuần',
  ),
  'interval' => tr(
    context,
    'Every ${s.interval} days',
    'Mỗi ${s.interval} ngày',
  ),
  _ => tr(context, 'Every day', 'Mỗi ngày'),
};

/// "5 min", "1 h 5 min", "Untimed".
String minutesText(BuildContext context, int seconds) {
  if (seconds == 0) return tr(context, 'untimed', 'không tính giờ');
  final m = (seconds / 60).ceil();
  if (m < 60) return tr(context, '$m min', '$m phút');
  return tr(
    context,
    '${m ~/ 60} h ${m % 60} min',
    '${m ~/ 60} giờ ${m % 60} phút',
  );
}

/// A running clock: `4:05`, `1:02:03`.
String clockText(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

String statusLabel(BuildContext context, String status) => switch (status) {
  'completed' => tr(context, 'Done', 'Đã xong'),
  'partial' => tr(context, 'Part done', 'Làm dở'),
  'skipped' => tr(context, 'Skipped, with a reason', 'Bỏ qua có lý do'),
  'missed' => tr(context, 'Not done', 'Chưa làm'),
  'paused' => tr(context, 'Paused', 'Nghỉ'),
  'future' => tr(context, 'Later', 'Sắp tới'),
  'notScheduled' => tr(context, 'Not planned', 'Không có lịch'),
  'finished' => tr(context, 'Finished', 'Đã xong'),
  'aborted' => tr(context, 'Stopped', 'Đã dừng'),
  'active' => tr(context, 'In progress', 'Đang dở'),
  'pending' => tr(context, 'Not done', 'Chưa làm'),
  _ => tr(context, 'Open', 'Chưa làm'),
};

/// A date the short way: "today", "yesterday", or the day.
String dayText(BuildContext context, String iso, String today) {
  final days = date(iso).difference(date(today)).inDays;
  if (days.abs() <= 1) {
    final w = relativeDays(context, days);
    return '${w[0].toUpperCase()}${w.substring(1)}';
  }
  return formatDay(context, iso);
}
