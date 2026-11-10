import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Civil dates never shift through UTC/local.
String insightDate(String iso, {required bool vi, bool year = false}) {
  final d = date(iso);
  final label = vi
      ? '${d.day} thg ${d.month}'
      : '${_months[d.month - 1]} ${d.day}';
  return year ? '$label, ${d.year}' : label;
}

String insightRange(String from, String until, {required bool vi}) {
  final a = date(from), b = date(until);
  if (from == until) return insightDate(from, vi: vi, year: true);
  if (a.year == b.year && a.month == b.month) {
    return vi
        ? '${a.day}–${b.day} thg ${a.month}, ${a.year}'
        : '${a.day}–${b.day} ${_months[a.month - 1]}, ${a.year}';
  }
  return '${insightDate(from, vi: vi, year: a.year != b.year)} – ${insightDate(until, vi: vi, year: true)}';
}

String insightDates(BuildContext c, String from, String until) => insightRange(
  from,
  until,
  vi: Localizations.localeOf(c).languageCode == 'vi',
);
