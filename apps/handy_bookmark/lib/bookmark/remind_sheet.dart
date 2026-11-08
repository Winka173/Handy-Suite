import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../services/read_later.dart';

/// "Remind me" for one item: Off (the default), Tonight, Tomorrow, This
/// weekend, or a day and time picked. Each line shows the real moment.
/// One tap picks; the custom line asks for the day, then the time.
class RemindChoices extends StatelessWidget {
  /// The reminder set now (local), or null for Off.
  final DateTime? current;
  final DateTime now;

  /// Called with the chosen moment, or null for Off.
  final ValueChanged<DateTime?> onPick;
  const RemindChoices({
    super.key,
    required this.current,
    required this.now,
    required this.onPick,
  });

  static String when(BuildContext context, DateTime at, DateTime now) {
    final loc = MaterialLocalizations.of(context);
    final time = loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(at),
      alwaysUse24HourFormat: true,
    );
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final d = day.difference(today).inDays;
    if (d == 0) return tr(context, 'Today, $time', 'Hôm nay, $time');
    if (d == 1) return tr(context, 'Tomorrow, $time', 'Ngày mai, $time');
    return '${loc.formatMediumDate(at)}, $time';
  }

  Future<void> _custom(BuildContext context) async {
    final start = current ?? now.add(const Duration(hours: 2));
    final day = await pickHandyDate(
      context,
      start.toIso8601String().substring(0, 10),
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time == null || !context.mounted) return;
    final d = DateTime.parse(day);
    final at = DateTime(d.year, d.month, d.day, time.hour, time.minute);
    if (!at.isAfter(DateTime.now())) {
      showHandyMessage(
        context,
        tr(
          context,
          'That time has passed. Pick a later one.',
          'Giờ đó đã qua. Hãy chọn giờ sau.',
        ),
      );
      return;
    }
    onPick(at);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final choices = readLaterChoices(now);
    final selected = readLaterChoiceOf(current, now) ?? 'off';
    String name(String id) => switch (id) {
      'tonight' => tr(context, 'Tonight', 'Tối nay'),
      'tomorrow' => tr(context, 'Tomorrow', 'Ngày mai'),
      'weekend' => tr(context, 'This weekend', 'Cuối tuần'),
      _ => id,
    };
    final taps = <String, VoidCallback>{};
    // A plain row with its radio: the row's tap picks, even the line
    // already chosen (to pick another custom time).
    Widget row(String id, String title, String? subtitle, VoidCallback tap) {
      taps[id] = tap;
      return ListTile(
        key: Key('remind-$id'),
        contentPadding: EdgeInsets.zero,
        leading: Radio<String>(value: id),
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
              ),
        onTap: tap,
      );
    }

    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (v) => taps[v]?.call(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('off', tr(context, 'Don\'t remind me', 'Không nhắc'), null, () {
            onPick(null);
          }),
          for (final c in choices)
            row(c.id, name(c.id), when(context, c.at, now), () => onPick(c.at)),
          row(
            'custom',
            tr(context, 'Pick a day and time', 'Chọn ngày và giờ'),
            selected == 'custom' && current != null
                ? when(context, current!, now)
                : null,
            () => _custom(context),
          ),
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.xs),
            child: Text(
              tr(
                context,
                'Only this bookmark is reminded. Others are not affected.',
                'Chỉ bookmark này được nhắc. Các bookmark khác không bị ảnh hưởng.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The item's "Remind me" sheet; one tap sets it and closes.
Future<void> showRemindSheet(
  BuildContext context,
  SaveScope scope,
  Bookmark b,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => SingleChildScrollView(
    key: const Key('remind-sheet'),
    padding: const EdgeInsets.fromLTRB(
      HandySpace.l,
      0,
      HandySpace.l,
      HandySpace.l,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(sheet, 'Remind me', 'Nhắc tôi'),
          style: Theme.of(sheet).textTheme.titleLarge,
        ),
        const SizedBox(height: HandySpace.s),
        RemindChoices(
          current: b.reminderAt == null
              ? null
              : DateTime.tryParse(b.reminderAt!)?.toLocal(),
          now: DateTime.now(),
          onPick: (at) {
            Navigator.pop(sheet);
            scope.remind(context, b, at);
          },
        ),
      ],
    ),
  ),
);
