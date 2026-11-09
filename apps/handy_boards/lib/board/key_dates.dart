import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';

/// One key date under a board's title: its name, the day, and how far off
/// it is ("in 12 days", "today", "3 days ago").
/// A key date in words for the board's subtitle: "Semester ends 15/1, in
/// 67 days" (its label as written, the day, how far).
String keyDateLine(
  BuildContext context,
  String label,
  DateTime day,
  DateTime now, {
  int? minute,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(day.year, day.month, day.day).difference(today).inDays;
  final at = minute == null
      ? ''
      : tr(
          context,
          ' at ${minute ~/ 60}:${(minute % 60).toString().padLeft(2, '0')}',
          ' lúc ${minute ~/ 60}:${(minute % 60).toString().padLeft(2, '0')}',
        );
  String when;
  if (days == 0 && minute != null) {
    // On the day, with a time: the hours (or minutes) left.
    final left = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: minute)).difference(now);
    when = left.isNegative
        ? tr(context, 'today', 'hôm nay')
        : left.inHours >= 1
        ? tr(context, 'in ${left.inHours} h', 'còn ${left.inHours} giờ')
        : tr(
            context,
            'in ${left.inMinutes.clamp(1, 59)} min',
            'còn ${left.inMinutes.clamp(1, 59)} phút',
          );
  } else {
    when = days == 0
        ? tr(context, 'today', 'hôm nay')
        : tr(context, 'in $days days', 'còn $days ngày');
  }
  return '$label ${day.day}/${day.month}$at, $when';
}

class KeyDateChip extends StatelessWidget {
  final String label;
  final DateTime day, now;
  final VoidCallback onTap;
  const KeyDateChip({
    super.key,
    required this.label,
    required this.day,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(
      day.year,
      day.month,
      day.day,
    ).difference(today).inDays;
    final when = days == 0
        ? tr(context, 'today', 'hôm nay')
        : days > 0
        ? tr(context, 'in $days days', 'còn $days ngày')
        : tr(context, '${-days} days ago', '${-days} ngày trước');
    return ActionChip(
      key: Key('key-date-$label'),
      avatar: const Icon(Icons.flag_outlined, size: 16),
      label: Text(
        '$label · ${MaterialLocalizations.of(context).formatShortMonthDay(day)} · $when',
      ),
      onPressed: onTap,
    );
  }
}

/// While a category is picked: the board shows only its cards; this says
/// so, with a way back to every card.
class FocusBar extends StatelessWidget {
  final String name;
  final VoidCallback onClear;
  const FocusBar({super.key, required this.name, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(Icons.filter_alt, size: 18, color: p.ink),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr(context, 'Showing only $name', 'Đang lọc: chỉ $name'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
            IconButton(
              key: const Key('focus-clear'),
              tooltip: tr(context, 'Show every card', 'Hiện mọi thẻ'),
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

/// The board's key dates: name and day each, up to eight. Any board has
/// them; a template only suggests the first ones.
Future<void> editMilestones(
  BuildContext context,
  BoardsScope scope,
  String board,
) async {
  final saved = await showModalBottomSheet<List<KeyDate>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) =>
        _KeyDatesSheet(milestonesOf(scope.state.get('boards', board))),
  );
  if (saved != null && context.mounted)
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => setMilestones(s, board, saved, now: scope.clock()),
      ),
    );
}

/// The sheet owns its fields: they live until the sheet has gone, so a
/// field rebuilt while the sheet slides away (the keyboard closing) never
/// reads a disposed controller.
class _KeyDatesSheet extends StatefulWidget {
  final List<KeyDate> initial;
  const _KeyDatesSheet(this.initial);
  @override
  State<_KeyDatesSheet> createState() => _KeyDatesSheetState();
}

class _KeyDatesSheetState extends State<_KeyDatesSheet> {
  late final list = [
    for (final m in widget.initial)
      (
        label: TextEditingController(text: m.label),
        day: m.day,
        minute: m.minute,
      ),
  ];

  /// Every field ever made, removed ones too, disposed with the sheet.
  late final made = [for (final m in list) m.label];

  @override
  void dispose() {
    for (final c in made) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext sheet) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      16 + MediaQuery.viewInsetsOf(sheet).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(sheet, 'Key dates', 'Ngày quan trọng'),
          style: Theme.of(sheet).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            sheet,
            'Shown under the board name with the days left (the hours on '
                'the day, when a time is set). They never move cards or '
                'set due dates.',
            'Hiện dưới tên bảng kèm số ngày còn lại (đến ngày đó thì đếm '
                'giờ, nếu có đặt giờ). Không đổi cột hay hạn của thẻ nào.',
          ),
          style: Theme.of(
            sheet,
          ).textTheme.bodySmall?.copyWith(color: BoardsPalette.of(sheet).muted),
        ),
        const SizedBox(height: 8),
        // Each key date on two lines: its name (and Remove), then its day
        // and its optional time, so a phone never runs out of width.
        for (final (i, m) in list.indexed)
          Padding(
            key: ObjectKey(m.label),
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('key-date-name-$i'),
                        controller: m.label,
                        maxLength: 80,
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: tr(sheet, 'Name', 'Tên'),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr(sheet, 'Remove', 'Xoá'),
                      onPressed: () => setState(() => list.removeAt(i)),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final v = await pickHandyDate(sheet, isoDay(m.day));
                        if (v != null && mounted)
                          setState(
                            () => list[i] = (
                              label: m.label,
                              day: localDate(v),
                              minute: m.minute,
                            ),
                          );
                      },
                      child: Text(
                        MaterialLocalizations.of(sheet).formatShortDate(m.day),
                      ),
                    ),
                    // A time is optional: the line then counts down the hours.
                    TextButton(
                      key: Key('key-date-time-$i'),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: sheet,
                          initialTime: m.minute == null
                              ? const TimeOfDay(hour: 9, minute: 0)
                              : TimeOfDay(
                                  hour: m.minute! ~/ 60,
                                  minute: m.minute! % 60,
                                ),
                        );
                        if (t != null && mounted)
                          setState(
                            () => list[i] = (
                              label: m.label,
                              day: m.day,
                              minute: t.hour * 60 + t.minute,
                            ),
                          );
                      },
                      onLongPress: m.minute == null
                          ? null
                          : () => setState(
                              () => list[i] = (
                                label: m.label,
                                day: m.day,
                                minute: null,
                              ),
                            ),
                      child: Text(
                        m.minute == null
                            ? tr(sheet, '+ Time', '+ Giờ')
                            : MaterialLocalizations.of(sheet).formatTimeOfDay(
                                TimeOfDay(
                                  hour: m.minute! ~/ 60,
                                  minute: m.minute! % 60,
                                ),
                                alwaysUse24HourFormat: true,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (list.length < 8)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('key-date-add'),
              onPressed: () async {
                final v = await pickHandyDate(sheet, '');
                if (v == null || !mounted) return;
                final c = TextEditingController(
                  text: tr(context, 'Key date', 'Mốc'),
                );
                made.add(c);
                setState(
                  () => list.add((label: c, day: localDate(v), minute: null)),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(tr(sheet, 'Add a key date', 'Thêm ngày')),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('key-date-save'),
          onPressed: () => Navigator.pop(sheet, [
            for (final m in list)
              if (m.label.text.trim().isNotEmpty)
                (label: m.label.text.trim(), day: m.day, minute: m.minute),
          ]),
          child: Text(tr(sheet, 'Save', 'Lưu')),
        ),
      ],
    ),
  );
}
