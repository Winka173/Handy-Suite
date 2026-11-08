import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';

/// One key date under a board's title: its name, the day, and how far off
/// it is ("in 12 days", "today", "3 days ago").
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

/// While a category is in focus: which one, the explicit "only this one"
/// filter (with its own words when it is on), and a way out. Focus never
/// hides cards by itself.
class FocusBar extends StatelessWidget {
  final String name;
  final bool only;
  final VoidCallback onOnly, onClear;
  const FocusBar({
    super.key,
    required this.name,
    required this.only,
    required this.onOnly,
    required this.onClear,
  });

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
            Icon(
              only ? Icons.filter_alt : Icons.center_focus_strong_outlined,
              size: 18,
              color: p.ink,
            ),
            const SizedBox(width: 6),
            // The button drops under the name when they do not fit side
            // by side (a narrow phone, large text).
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    only
                        ? tr(context, 'Only $name', 'Đang lọc: chỉ $name')
                        : tr(context, 'Focus: $name', 'Đang làm nổi: $name'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                  TextButton(
                    key: const Key('focus-only'),
                    onPressed: onOnly,
                    child: Text(
                      only
                          ? tr(context, 'Show all cards', 'Hiện mọi thẻ')
                          : tr(context, 'Only this one', 'Chỉ hiện nhóm này'),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('focus-clear'),
              tooltip: tr(context, 'Clear', 'Bỏ chọn'),
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
  final list = [
    for (final m in milestonesOf(scope.state.get('boards', board)))
      (label: TextEditingController(text: m.label), day: m.day),
  ];
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => Padding(
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
                'Shown under the board name with the days left. They never '
                    'move cards or set due dates.',
                'Hiện dưới tên bảng kèm số ngày còn lại. Không đổi cột hay '
                    'hạn của thẻ nào.',
              ),
              style: Theme.of(sheet).textTheme.bodySmall?.copyWith(
                color: BoardsPalette.of(sheet).muted,
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, m) in list.indexed)
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
                  TextButton(
                    onPressed: () async {
                      final v = await pickHandyDate(sheet, isoDay(m.day));
                      if (v != null)
                        setSheet(
                          () => list[i] = (label: m.label, day: localDate(v)),
                        );
                    },
                    child: Text(
                      MaterialLocalizations.of(sheet).formatShortDate(m.day),
                    ),
                  ),
                  IconButton(
                    tooltip: tr(sheet, 'Remove', 'Xoá'),
                    onPressed: () => setSheet(() => list.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            if (list.length < 8)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('key-date-add'),
                  onPressed: () async {
                    final v = await pickHandyDate(sheet, '');
                    if (v == null) return;
                    setSheet(
                      () => list.add((
                        label: TextEditingController(
                          text: tr(sheet, 'Key date', 'Mốc'),
                        ),
                        day: localDate(v),
                      )),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(tr(sheet, 'Add a key date', 'Thêm ngày')),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('key-date-save'),
              onPressed: () => Navigator.pop(sheet, true),
              child: Text(tr(sheet, 'Save', 'Lưu')),
            ),
          ],
        ),
      ),
    ),
  );
  if (saved == true && context.mounted)
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => setMilestones(s, board, [
          for (final m in list)
            if (m.label.text.trim().isNotEmpty)
              (label: m.label.text.trim(), day: m.day),
        ], now: scope.clock()),
      ),
    );
  for (final m in list) m.label.dispose();
}
