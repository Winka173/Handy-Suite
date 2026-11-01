import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'l10n.dart';

String _day(DateTime d) => d.toIso8601String().substring(0, 10);

/// Asks for a calendar day and returns it as `YYYY-MM-DD`, or null when the
/// person backed out. iOS gets the wheel; everyone else the calendar.
Future<String?> pickHandyDate(BuildContext context, String value) async {
  final initial = DateTime.tryParse(value) ?? DateTime.now();
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    DateTime? chosen;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 280,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: initial,
            minimumYear: 1900,
            maximumYear: 2200,
            onDateTimeChanged: (d) => chosen = d,
          ),
        ),
      ),
    );
    // Closing the wheel without turning it keeps the date it showed.
    return _day(chosen ?? initial);
  }
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(2200),
  );
  return picked == null ? null : _day(picked);
}

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

/// `2026-10-20` → `20/10/2026` (vi) or `20 Oct 2026` (en); '' stays ''.
String formatDay(BuildContext context, String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return tr(
    context,
    '${d.day} ${_months[d.month - 1]} ${d.year}',
    '${d.day}/${d.month}/${d.year}',
  );
}

/// Days from today in words: "today", "in 12 days", "5 days ago".
String relativeDays(BuildContext context, int days) => switch (days) {
  0 => tr(context, 'today', 'hôm nay'),
  1 => tr(context, 'tomorrow', 'ngày mai'),
  -1 => tr(context, 'yesterday', 'hôm qua'),
  > 1 => tr(context, 'in $days days', 'còn $days ngày'),
  _ => tr(context, '${-days} days ago', '${-days} ngày trước'),
};
