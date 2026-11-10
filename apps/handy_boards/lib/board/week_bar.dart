import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import 'time_actions.dart';

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

/// "This week", "Today" or "This month" for a timeline unit.
String thisPeriod(BuildContext context, String unit, [int count = 1]) =>
    count > 1
    ? tr(context, 'This span', 'Kỳ này')
    : switch (unit) {
        'day' => tr(context, 'Today', 'Hôm nay'),
        'month' => tr(context, 'This month', 'Tháng này'),
        _ => tr(context, 'This week', 'Tuần này'),
      };

/// "to this week", "to today", "to this month".
String toThisPeriod(BuildContext context, String unit, [int count = 1]) =>
    count > 1
    ? tr(context, 'to this span', 'qua kỳ này')
    : switch (unit) {
        'day' => tr(context, 'to today', 'về hôm nay'),
        'month' => tr(context, 'to this month', 'qua tháng này'),
        _ => tr(context, 'to this week', 'qua tuần này'),
      };

/// Where a period stands against today.
enum PeriodKind { past, current, future }

PeriodKind periodKind(
  String unit,
  TimeWindow w,
  DateTime now, {
  TimeWindow? current,
}) {
  current ??= timelineWindow(unit, now);
  if (!w.end.isAfter(current.first)) return PeriodKind.past;
  if (!w.first.isBefore(current.end)) return PeriodKind.future;
  return PeriodKind.current;
}

/// Above a board on a timeline: the period shown with its dates, ‹ and ›
/// one period back or on, and the way back to the current one. A period
/// gone by says it is read-only; a later one that it is ahead.
class TimelineBar extends StatelessWidget {
  final String unit;
  final TimeWindow window;
  final DateTime now;
  final ValueChanged<TimeWindow> onWindow;

  /// Units per period (a custom span), and the period holding today.
  final int count;
  final TimeWindow? current;

  /// Tapping the dates opens the board's time settings.
  final VoidCallback? onSetup;
  const TimelineBar({
    super.key,
    required this.unit,
    required this.window,
    required this.now,
    required this.onWindow,
    this.count = 1,
    this.current,
    this.onSetup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final range = TimeRange(unit, count);
    final today = current ?? timelineWindow(unit, now);
    final kind = periodKind(unit, window, now, current: today);
    final note = switch (kind) {
      PeriodKind.current => thisPeriod(context, unit, count),
      PeriodKind.past => tr(context, 'Gone by · read only', 'Đã qua · chỉ xem'),
      PeriodKind.future => tr(context, 'Ahead', 'Sắp tới'),
    };
    return Padding(
      key: const Key('week-bar'),
      // The chevron's glyph on the page's 16 pt margin.
      padding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
      child: Row(
        children: [
          IconButton(
            key: const Key('week-prev'),
            tooltip: tr(context, 'Earlier', 'Trước'),
            onPressed: () => onWindow(shiftWindow(range, window, -1)),
            icon: const Icon(Icons.chevron_left),
          ),
          // One line: the dates in ink, then where they stand.
          Flexible(
            child: InkWell(
              key: const Key('week-setup'),
              borderRadius: BorderRadius.circular(8),
              onTap: onSetup,
              child: Semantics(
                liveRegion: true,
                hint: onSetup == null
                    ? null
                    : tr(
                        context,
                        'Change the time span',
                        'Đổi khoảng thời gian',
                      ),
                child: LayoutBuilder(
                  builder: (context, box) => Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // The dates keep their room (up to most of the row); the
                      // note takes what is left, not a fixed share of it.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: box.maxWidth * .7,
                        ),
                        child: Text(
                          windowLabel(context, window, now),
                          key: const Key('week-label'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          note,
                          key: const Key('week-kind'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: kind == PeriodKind.current ? p.ink : p.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('week-next'),
            tooltip: tr(context, 'Later', 'Sau'),
            onPressed: () => onWindow(shiftWindow(range, window, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 4),
          // Beside the chevrons, never adrift mid-row. A narrow phone or
          // large text keeps one row: the way back is an icon whose tooltip
          // says it.
          if (kind != PeriodKind.current)
            MediaQuery.sizeOf(context).width < 560 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? IconButton(
                    key: const Key('week-current'),
                    tooltip: thisPeriod(context, unit, count),
                    onPressed: () => onWindow(today),
                    icon: const Icon(Icons.today_outlined),
                  )
                : TextButton(
                    key: const Key('week-current'),
                    onPressed: () => onWindow(today),
                    child: Text(thisPeriod(context, unit, count)),
                  ),
        ],
      ),
    );
  }
}

/// Unfinished work on a timeline, with one button that brings it to the
/// current period: in a period gone by, its own open cards; in the current
/// one, everything still open from before it.
class CarryLine extends StatelessWidget {
  final String unit;
  final int count;
  final bool pastPeriod;
  final VoidCallback onCarry;
  const CarryLine({
    super.key,
    required this.unit,
    required this.count,
    required this.pastPeriod,
    required this.onCarry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    if (count == 0) return const SizedBox.shrink();
    final before = switch (unit) {
      'day' => tr(context, 'from earlier days', 'từ những ngày trước'),
      'month' => tr(context, 'from earlier months', 'từ những tháng trước'),
      _ => tr(context, 'from earlier weeks', 'từ những tuần trước'),
    };
    return Padding(
      key: const Key('carry-line'),
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Row(
        children: [
          Icon(Icons.history, size: 18, color: p.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pastPeriod
                  ? tr(
                      context,
                      count == 1
                          ? '1 not finished here'
                          : '$count not finished here',
                      '$count việc chưa xong ở kỳ này',
                    )
                  : tr(
                      context,
                      count == 1
                          ? '1 not finished $before'
                          : '$count not finished $before',
                      '$count việc chưa xong $before',
                    ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
          TextButton(
            key: const Key('carry-all'),
            onPressed: onCarry,
            child: Text(
              tr(
                context,
                'Bring ${pastPeriod ? 'all ' : ''}${toThisPeriod(context, unit)}',
                'Đem ${pastPeriod ? 'tất cả ' : ''}${toThisPeriod(context, unit)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Above a board that is not on a timeline, only while there is any:
/// "3 still open from before", with "Move to today" (one Undo; a card with
/// only a due date asks first) and "See them" (the list, each card a tap
/// away).
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
