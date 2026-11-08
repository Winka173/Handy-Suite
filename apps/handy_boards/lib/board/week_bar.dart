import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import 'time_actions.dart';
import 'time_range_picker.dart';

/// The window in words: its real dates, never "previous week".
String windowLabel(BuildContext context, TimeWindow w, DateTime now) {
  String day(DateTime d) {
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const vi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return tr(
      context,
      '${en[d.weekday - 1]} ${d.day}/${d.month}',
      '${vi[d.weekday - 1]} ${d.day}/${d.month}',
    );
  }

  final last = w.last;
  if (w.first == last) return day(w.first);
  final wholeMonths =
      w.first.day == 1 && addDays(last, 1).day == 1 && w.days > 27;
  if (wholeMonths && w.first.month == last.month) {
    return tr(
      context,
      '${w.first.month}/${w.first.year}',
      'Tháng ${w.first.month}/${w.first.year}',
    );
  }
  final year = last.year != now.year || w.first.year != last.year;
  return '${w.first.day}/${w.first.month}${w.first.year != last.year ? '/${w.first.year}' : ''}'
      ' – ${last.day}/${last.month}${year ? '/${last.year}' : ''}';
}

/// Above the board: which stretch of time it shows. ‹ and › go one whole
/// span back or on; "This week" (or day, month) comes back; the span
/// button sets 1 day to 3 months or one's own dates; "All" shows every
/// card. A board with no dated card has no bar.
class WeekBar extends StatelessWidget {
  final TimeRange range;

  /// The window shown, or null for every card.
  final TimeWindow? window;
  final DateTime now;
  final ValueChanged<TimeWindow?> onWindow;
  final ValueChanged<TimeRange> onRange;
  const WeekBar({
    super.key,
    required this.range,
    required this.window,
    required this.now,
    required this.onWindow,
    required this.onRange,
  });

  String _thisOne(BuildContext context) => switch (range.unit) {
    'day' => tr(context, 'Today', 'Hôm nay'),
    'month' => tr(context, 'This month', 'Tháng này'),
    _ => tr(context, 'This week', 'Tuần này'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final current = currentWindow(range, now);
    final w = window;
    final atCurrent = w != null && w.first == current.first;
    final nav = [
      IconButton(
        key: const Key('week-prev'),
        tooltip: tr(context, 'Earlier', 'Trước'),
        onPressed: () => onWindow(shiftWindow(range, w ?? current, -1)),
        icon: const Icon(Icons.chevron_left),
      ),
      Flexible(
        child: Semantics(
          liveRegion: true,
          child: Text(
            w == null
                ? tr(context, 'All cards', 'Mọi thẻ')
                : windowLabel(context, w, now),
            key: const Key('week-label'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
      ),
      IconButton(
        key: const Key('week-next'),
        tooltip: tr(context, 'Later', 'Sau'),
        onPressed: () => onWindow(shiftWindow(range, w ?? current, 1)),
        icon: const Icon(Icons.chevron_right),
      ),
    ];
    // A narrow phone keeps one row: "this week" and the span become icons
    // (their tooltips say what they do); the label gives way first.
    final narrow =
        MediaQuery.sizeOf(context).width < 560 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final tools = [
      if (!atCurrent)
        narrow
            ? IconButton(
                key: const Key('week-current'),
                tooltip: _thisOne(context),
                onPressed: () => onWindow(current),
                icon: const Icon(Icons.today_outlined),
              )
            : TextButton(
                key: const Key('week-current'),
                onPressed: () => onWindow(current),
                child: Text(_thisOne(context)),
              ),
      TimeRangeButton(
        range: range,
        onRange: onRange,
        from: (w ?? current).first,
        compact: narrow,
        all: narrow ? w == null : null,
        onAll: (v) => onWindow(v ? null : current),
      ),
      if (!narrow) ...[
        const SizedBox(width: 4),
        FilterChip(
          key: const Key('week-all'),
          label: Text(tr(context, 'All', 'Tất cả')),
          selected: w == null,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: p.line),
          onSelected: (v) => onWindow(v ? null : current),
        ),
      ],
    ];
    return Padding(
      key: const Key('week-bar'),
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
      child: Row(
        children: [
          Expanded(child: Row(children: nav)),
          ...tools,
        ],
      ),
    );
  }
}

/// Above the board, only while there is any: "3 still open from before",
/// with "Move to today" (one Undo; a card with only a due date asks first)
/// and "See them" (the list, each card a tap away).
class BacklogLine extends StatelessWidget {
  final BoardsScope scope;
  final String board;
  final bool Function(BoardRecord card) shows;
  const BacklogLine({
    super.key,
    required this.scope,
    required this.board,
    required this.shows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final today = calendarDay(scope.clock());
    // A card already planned for today or later is being handled; only
    // work with no plan from today on is "from before".
    final items = [
      for (final i in backlogOf(scope.state, board, today, shows: shows))
        if (i.planned == null || i.planned!.isBefore(today)) i,
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final n = items.length;
    return Padding(
      key: const Key('backlog-line'),
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Row(
        children: [
          // The words open the list; the button moves them all.
          Expanded(
            child: InkWell(
              key: const Key('backlog-see'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => showBacklog(context, scope, board, shows: shows),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18, color: p.danger),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tr(
                          context,
                          n == 1
                              ? '1 still open from before'
                              : '$n still open from before',
                          '$n việc chưa xong từ trước',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: p.muted),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            key: const Key('backlog-today'),
            onPressed: () => quickSchedule(context, scope, [
              for (final i in items) i.card.id,
            ], reason: 'move to now'),
            child: Text(tr(context, 'Move to today', 'Về hôm nay')),
          ),
        ],
      ),
    );
  }
}
