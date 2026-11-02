import 'package:handy_ui/kit.dart';

/// When to be reminded: later today, tomorrow morning, this weekend, or a
/// chosen day and time (which must be in the future). Null when dismissed.
Future<DateTime?> pickReminder(BuildContext context) async {
  final now = DateTime.now();
  final toSaturday = (DateTime.saturday - now.weekday + 7) % 7;
  final presets = [
    (
      'today',
      tr(context, 'Later today', 'Lát nữa hôm nay'),
      now.add(const Duration(hours: 3)),
    ),
    (
      'tomorrow',
      tr(context, 'Tomorrow, 9:00', 'Ngày mai, 9:00'),
      DateTime(now.year, now.month, now.day + 1, 9),
    ),
    (
      'weekend',
      tr(context, 'This weekend, 9:00', 'Cuối tuần này, 9:00'),
      DateTime(
        now.year,
        now.month,
        now.day + (toSaturday == 0 ? 7 : toSaturday),
        9,
      ),
    ),
  ];
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              0,
              HandySpace.l,
              HandySpace.s,
            ),
            child: Text(
              tr(context, 'Remind me', 'Nhắc tôi'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final (id, label, _) in presets)
            ListTile(
              key: Key('remind-$id'),
              leading: const Icon(Icons.schedule),
              title: Text(label),
              onTap: () => Navigator.pop(context, id),
            ),
          ListTile(
            key: const Key('remind-custom'),
            leading: const Icon(Icons.event_outlined),
            title: Text(tr(context, 'Pick a day and time', 'Chọn ngày giờ')),
            onTap: () => Navigator.pop(context, 'custom'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice != 'custom') return presets.firstWhere((p) => p.$1 == choice).$3;
  final day = await pickHandyDate(
    context,
    now.add(const Duration(days: 1)).toIso8601String().substring(0, 10),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
  );
  if (time == null) return null;
  final d = DateTime.parse(day);
  final at = DateTime(d.year, d.month, d.day, time.hour, time.minute);
  if (!at.isAfter(DateTime.now())) {
    throw const FormatException(
      'Pick a time that has not passed / Chọn một thời điểm chưa qua',
    );
  }
  return at;
}
