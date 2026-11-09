import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import 'board_page.dart' show showUndo;
import 'week_bar.dart';

String timelineName(BuildContext context, String? unit, [int count = 1]) =>
    count > 1 && unit != null
    ? switch (unit) {
        'day' => tr(context, 'Every $count days', 'Mỗi $count ngày'),
        'month' => tr(context, 'Every $count months', 'Mỗi $count tháng'),
        _ => tr(context, 'Every $count weeks', 'Mỗi $count tuần'),
      }
    : switch (unit) {
        'day' => tr(context, 'By day', 'Theo ngày'),
        'week' => tr(context, 'By week', 'Theo tuần'),
        'month' => tr(context, 'By month', 'Theo tháng'),
        _ => tr(context, 'Off', 'Tắt'),
      };

/// The one place a board's timeline is set: a chip beside the board's
/// filters. It names the current choice ("By week") or, while off, offers
/// "Time".
class TimelineChip extends StatelessWidget {
  final BoardsScope scope;
  final String board;
  const TimelineChip({super.key, required this.scope, required this.board});
  @override
  Widget build(BuildContext context) {
    final unit = boardTimeline(scope.state.get('boards', board));
    return ActionChip(
      key: const Key('board-timeline'),
      avatar: Icon(
        unit == null ? Icons.schedule_outlined : Icons.schedule,
        size: 18,
      ),
      label: Text(
        unit == null
            ? tr(context, 'Time', 'Thời gian')
            : timelineName(
                context,
                unit,
                timelineCount(scope.state.get('boards', board)),
              ),
      ),
      tooltip: tr(
        context,
        'Lay this board out by day, week or month',
        'Xếp bảng này theo ngày, tuần hoặc tháng',
      ),
      onPressed: () => pickTimeline(context, scope, board),
    );
  }
}

/// Off, by day, by week or by month, each one tap. Turning it on (or to a
/// longer unit) brings the open work from earlier periods to today, with
/// one Undo. A shorter unit than the board has used is shown, disabled,
/// with the reason. Turning it off asks first and offers to archive the
/// finished cards of earlier periods.
Future<void> pickTimeline(
  BuildContext context,
  BoardsScope scope,
  String board,
) async {
  final b = scope.state.get('boards', board);
  final current = boardTimeline(b);
  final count = timelineCount(b);
  final floor = timelineFloor(b);
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final p = BoardsPalette.of(sheet);
      Widget option(String? unit, String help) {
        final allowed = unit == null || timelineAllowed(b, unit);
        final selected = unit == current && (unit == null || count == 1);
        return ListTile(
          key: Key('timeline-${unit ?? 'off'}'),
          enabled: allowed,
          selected: selected,
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? p.primary : null,
          ),
          title: Text(timelineName(sheet, unit)),
          subtitle: Text(
            allowed
                ? help
                : tr(
                    sheet,
                    'Not available: this board already plans by '
                        '${floor == 'month' ? 'month' : 'week'}, and a shorter '
                        'period would have to guess which day each card is for.',
                    'Không chọn được: bảng đã xếp việc theo '
                        '${floor == 'month' ? 'tháng' : 'tuần'}, chia nhỏ hơn thì '
                        'phải đoán mỗi thẻ thuộc ngày nào.',
                  ),
          ),
          onTap: selected
              ? () => Navigator.pop(sheet)
              : () => Navigator.pop(sheet, unit ?? 'off'),
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  tr(
                    sheet,
                    'Lay the board out by time',
                    'Xếp bảng theo thời gian',
                  ),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  tr(
                    sheet,
                    'Each card sits in its day, week or month, and ‹ › move between them. Earlier ones stay to look back on; unfinished work there can be brought forward. Open work from before moves to now when you turn it on.',
                    'Mỗi thẻ nằm ở ngày, tuần hoặc tháng của nó, ‹ › để đi qua lại. Kỳ đã qua giữ lại để xem; việc chưa xong ở đó đem qua kỳ hiện tại được. Khi bật, việc chưa xong từ trước sẽ về kỳ hiện tại.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
              ),
              option(
                'day',
                tr(sheet, 'For a day-by-day plan', 'Cho kế hoạch từng ngày'),
              ),
              option(
                'week',
                tr(
                  sheet,
                  'Sprints, study weeks, chores',
                  'Sprint, tuần học, việc nhà',
                ),
              ),
              option(
                'month',
                tr(
                  sheet,
                  'Longer plans, content calendars',
                  'Kế hoạch dài, lịch nội dung',
                ),
              ),
              ListTile(
                key: const Key('timeline-custom'),
                selected: current != null && count > 1,
                leading: Icon(
                  current != null && count > 1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: current != null && count > 1 ? p.primary : null,
                ),
                title: Text(
                  current != null && count > 1
                      ? '${tr(sheet, 'Custom', 'Tuỳ chỉnh')}: ${timelineName(sheet, current, count)}'
                      : tr(sheet, 'Custom…', 'Tuỳ chỉnh…'),
                ),
                subtitle: Text(
                  tr(
                    sheet,
                    'A span of your own: 10 days, 2-week sprints, 3 months…',
                    'Khoảng của riêng bạn: 10 ngày, sprint 2 tuần, 3 tháng…',
                  ),
                ),
                onTap: () => Navigator.pop(sheet, 'custom'),
              ),
              option(
                null,
                tr(
                  sheet,
                  'A plain Kanban: every card together',
                  'Kanban thường: mọi thẻ chung một bảng',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (picked == null || !context.mounted) return;
  var span = 1;
  String? unit;
  if (picked == 'custom') {
    final chosen = await _customSpan(context, b, current ?? 'week', count);
    if (chosen == null || !context.mounted) return;
    unit = chosen.$1;
    span = chosen.$2;
  } else {
    unit = picked == 'off' ? null : picked;
  }
  if (unit == current && span == count) return;
  final now = scope.clock();
  if (unit == null) {
    final sum = timelineOffSummary(scope.state, board, now);
    final archive = await _confirmOff(context, sum);
    if (archive == null || !context.mounted) return;
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => setTimeline(s, board, null, now: now, archiveDone: archive),
      ),
    );
    if (context.mounted)
      showUndo(
        context,
        scope,
        tr(context, 'Timeline off', 'Đã tắt xếp theo thời gian'),
      );
    return;
  }
  final first = span > 1 ? now : timelineWindow(unit, now).first;
  final moving = openBefore(scope.state, board, first).length;
  await scope.run(
    context,
    () => scope.controller.change(
      (s) => setTimeline(s, board, unit, now: now, count: span),
    ),
  );
  if (!context.mounted) return;
  final name = timelineName(context, unit, span);
  showUndo(
    context,
    scope,
    moving == 0
        ? name
        : tr(
            context,
            '$name · $moving brought ${toThisPeriod(context, unit, span)}',
            '$name · đã đem $moving việc ${toThisPeriod(context, unit, span)}',
          ),
  );
}

/// Turning the timeline off: what the plain board will hold, and whether
/// to archive the finished cards of earlier periods. Null when cancelled.
Future<bool?> _confirmOff(
  BuildContext context,
  ({int doneBefore, int openBefore, int later}) sum,
) {
  var archive = false;
  return showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, set) => AlertDialog(
        title: Text(
          tr(dialog, 'Turn the timeline off?', 'Tắt xếp theo thời gian?'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                dialog,
                'Every card shows on one board again: ${sum.openBefore} unfinished from earlier, ${sum.later} planned for later, ${sum.doneBefore} finished earlier. No card changes; turning it back on puts each in its period again.',
                'Mọi thẻ lại hiện chung một bảng: ${sum.openBefore} việc chưa xong từ trước, ${sum.later} việc cho sau này, ${sum.doneBefore} thẻ đã xong trước đó. Không thẻ nào bị đổi; bật lại thì thẻ nào về kỳ nấy.',
              ),
            ),
            if (sum.doneBefore > 0)
              CheckboxListTile(
                key: const Key('timeline-off-archive'),
                contentPadding: EdgeInsets.zero,
                value: archive,
                onChanged: (v) => set(() => archive = v == true),
                title: Text(
                  tr(
                    dialog,
                    'Archive the ${sum.doneBefore} finished earlier',
                    'Lưu trữ ${sum.doneBefore} thẻ đã xong trước đó',
                  ),
                ),
                subtitle: Text(
                  tr(
                    dialog,
                    'They come back from Settings › Data.',
                    'Lấy lại được ở Cài đặt › Dữ liệu.',
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(tr(dialog, 'Cancel', 'Huỷ')),
          ),
          FilledButton(
            key: const Key('timeline-off-confirm'),
            onPressed: () => Navigator.pop(dialog, archive),
            child: Text(tr(dialog, 'Turn off', 'Tắt')),
          ),
        ],
      ),
    ),
  );
}

/// A span of one's own: how many days, weeks or months one period holds.
/// Units shorter than the board has used are not offered.
Future<(String, int)?> _customSpan(
  BuildContext context,
  BoardRecord b,
  String unit,
  int count,
) {
  const limits = {'day': (2, 31), 'week': (2, 12), 'month': (2, 12)};
  var u = timelineAllowed(b, unit) ? unit : 'week';
  var n = count > 1 ? count : 2;
  return showDialog<(String, int)>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, set) {
        final (low, high) = limits[u]!;
        n = n.clamp(low, high);
        String unitName(String x) => switch (x) {
          'day' => tr(dialog, 'days', 'ngày'),
          'month' => tr(dialog, 'months', 'tháng'),
          _ => tr(dialog, 'weeks', 'tuần'),
        };
        return AlertDialog(
          title: Text(tr(dialog, 'A span of your own', 'Khoảng tuỳ chỉnh')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final x in const ['day', 'week', 'month'])
                    ChoiceChip(
                      key: Key('span-unit-$x'),
                      label: Text(unitName(x)),
                      selected: u == x,
                      onSelected: timelineAllowed(b, x)
                          ? (_) => set(() => u = x)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton.outlined(
                    key: const Key('span-less'),
                    tooltip: tr(dialog, 'Fewer', 'Bớt'),
                    onPressed: n > low ? () => set(() => n--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Text(
                      tr(
                        dialog,
                        'Every $n ${unitName(u)}',
                        'Mỗi $n ${unitName(u)}',
                      ),
                      key: const Key('span-value'),
                      textAlign: TextAlign.center,
                      style: Theme.of(dialog).textTheme.titleMedium,
                    ),
                  ),
                  IconButton.outlined(
                    key: const Key('span-more'),
                    tooltip: tr(dialog, 'More', 'Thêm'),
                    onPressed: n < high ? () => set(() => n++) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  dialog,
                  'Periods count from today, so the first one starts now.',
                  'Các kỳ tính từ hôm nay, nên kỳ đầu bắt đầu ngay.',
                ),
                style: Theme.of(dialog).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(tr(dialog, 'Cancel', 'Huỷ')),
            ),
            FilledButton(
              key: const Key('span-apply'),
              onPressed: () => Navigator.pop(dialog, (u, n)),
              child: Text(tr(dialog, 'Use it', 'Dùng')),
            ),
          ],
        );
      },
    ),
  );
}
