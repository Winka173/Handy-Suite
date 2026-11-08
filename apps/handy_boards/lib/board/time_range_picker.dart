import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// A range's name: "2 days", "1 month", or a custom span's dates.
String rangeLabel(BuildContext context, TimeRange r) {
  if (r.custom) {
    final a = r.first!, b = r.last!;
    return '${a.day}/${a.month} – ${b.day}/${b.month}${a.year != b.year ? '/${b.year}' : ''}';
  }
  final n = r.count;
  return switch (r.unit) {
    'day' => tr(context, n == 1 ? '1 day' : '$n days', '$n ngày'),
    'week' => tr(context, n == 1 ? '1 week' : '$n weeks', '$n tuần'),
    _ => tr(context, n == 1 ? '1 month' : '$n months', '$n tháng'),
  };
}

/// The range chip: the eight direct ranges and Custom.
class TimeRangeButton extends StatelessWidget {
  final TimeRange range;
  final ValueChanged<TimeRange> onRange;

  /// Where a new custom span starts: the first day on screen.
  final DateTime from;
  const TimeRangeButton({
    super.key,
    required this.range,
    required this.onRange,
    required this.from,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<Object>(
    key: const Key('time-span'),
    tooltip: tr(context, 'How long to show', 'Khoảng thời gian'),
    onSelected: (v) async {
      if (v is TimeRange) return onRange(v);
      final picked = await pickTimeRange(context, range, from);
      if (picked != null) onRange(picked);
    },
    itemBuilder: (context) => [
      for (final r in TimeRange.presets)
        CheckedPopupMenuItem<Object>(
          key: Key('span-${r.unit}-${r.count}'),
          value: r,
          checked: r == range,
          child: Text(rangeLabel(context, r)),
        ),
      const PopupMenuDivider(),
      CheckedPopupMenuItem<Object>(
        key: const Key('span-custom'),
        value: 'custom',
        checked: !TimeRange.presets.contains(range),
        child: Text(
          TimeRange.presets.contains(range)
              ? tr(context, 'Custom…', 'Tuỳ chỉnh…')
              : '${tr(context, 'Custom', 'Tuỳ chỉnh')} · ${rangeLabel(context, range)}',
        ),
      ),
    ],
    child: Chip(
      avatar: const Icon(Icons.date_range, size: 18),
      label: Text(rangeLabel(context, range)),
    ),
  );
}

/// Custom: a length (1–12 days, weeks or months) or a start and end date
/// (inclusive, up to a year). Starts from the range in use.
Future<TimeRange?> pickTimeRange(
  BuildContext context,
  TimeRange current,
  DateTime from,
) => showDialog<TimeRange>(
  context: context,
  builder: (_) => _CustomRange(current: current, from: from),
);

class _CustomRange extends StatefulWidget {
  final TimeRange current;
  final DateTime from;
  const _CustomRange({required this.current, required this.from});
  @override
  State<_CustomRange> createState() => _CustomRangeState();
}

class _CustomRangeState extends State<_CustomRange> {
  late bool dates = widget.current.custom;
  late String unit = widget.current.custom ? 'week' : widget.current.unit;
  late int count = widget.current.custom ? 1 : widget.current.count;
  late DateTime first = widget.current.first ?? calendarDay(widget.from);
  late DateTime last = widget.current.last ?? addDays(first, 13);

  int get days => daysBetween(first, last) + 1;
  String? get problem => days < 1
      ? tr(
          context,
          'The end comes before the start.',
          'Ngày kết thúc trước ngày bắt đầu.',
        )
      : days > TimeRange.maxCustomDays
      ? tr(context, 'Up to one year at a time.', 'Tối đa một năm mỗi lần.')
      : null;

  Future<void> _pick(bool start) async {
    final v = await pickHandyDate(context, isoDay(start ? first : last));
    if (v == null || v.isEmpty || !mounted) return;
    final d = calendarDay(DateTime.parse(v));
    setState(() => start ? first = d : last = d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final loc = MaterialLocalizations.of(context);
    Widget dateRow(String label, DateTime d, bool start, Key key) => ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(loc.formatMediumDate(d)),
      onTap: () => _pick(start),
    );
    return AlertDialog(
      title: Text(tr(context, 'Show how long', 'Xem khoảng bao lâu')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              key: const Key('span-mode'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(tr(context, 'Length', 'Độ dài')),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(tr(context, 'From – to', 'Từ ngày – đến ngày')),
                ),
              ],
              selected: {dates},
              onSelectionChanged: (v) => setState(() => dates = v.first),
            ),
            const SizedBox(height: 16),
            if (!dates) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    key: const Key('span-less'),
                    tooltip: tr(context, 'Fewer', 'Bớt'),
                    onPressed: count > 1 ? () => setState(() => count--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$count',
                      key: const Key('span-count'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    key: const Key('span-more'),
                    tooltip: tr(context, 'More', 'Thêm'),
                    onPressed: count < 12
                        ? () => setState(() => count++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                key: const Key('span-unit'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'day',
                    label: Text(tr(context, 'Days', 'Ngày')),
                  ),
                  ButtonSegment(
                    value: 'week',
                    label: Text(tr(context, 'Weeks', 'Tuần')),
                  ),
                  ButtonSegment(
                    value: 'month',
                    label: Text(tr(context, 'Months', 'Tháng')),
                  ),
                ],
                selected: {unit},
                onSelectionChanged: (v) => setState(() => unit = v.first),
              ),
            ] else ...[
              dateRow(
                tr(context, 'From', 'Từ ngày'),
                first,
                true,
                const Key('custom-first'),
              ),
              dateRow(
                tr(context, 'To (included)', 'Đến ngày (tính cả ngày này)'),
                last,
                false,
                const Key('custom-last'),
              ),
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Text(
                  problem ??
                      tr(
                        context,
                        '$days days · next and back move by $days days',
                        '$days ngày · Trước/Sau đi đúng $days ngày',
                      ),
                  key: const Key('custom-summary'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: problem == null ? p.muted : p.danger,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Huỷ')),
        ),
        FilledButton(
          key: const Key('span-apply'),
          onPressed: dates && problem != null
              ? null
              : () => Navigator.pop(
                  context,
                  dates
                      ? TimeRange.custom(first, last)
                      : TimeRange(unit, count),
                ),
          child: Text(tr(context, 'Show', 'Xem')),
        ),
      ],
    );
  }
}
