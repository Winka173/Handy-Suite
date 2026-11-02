import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../today/beads.dart';
import '../ui/words.dart';

/// One month of a habit as beads on a calendar. A day inside the window
/// that can still be edited opens it; other days only read.
class MonthGrid extends StatefulWidget {
  final Habit habit;
  final String today;
  final int weekStart, backfill;
  final HabitIndex index;
  final void Function(String day)? onDay;
  const MonthGrid({
    super.key,
    required this.habit,
    required this.today,
    required this.weekStart,
    required this.backfill,
    required this.index,
    this.onDay,
  });
  @override
  State<MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<MonthGrid> {
  // Early in a month the one before says more, if the habit was there.
  late DateTime month = () {
    final t = date(widget.today);
    final previous = DateTime.utc(t.year, t.month - 1);
    return t.day <= 10 &&
            day(previous)
                    .substring(0, 7)
                    .compareTo(widget.habit.created.substring(0, 7)) >=
                0
        ? previous
        : DateTime.utc(t.year, t.month);
  }();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final first = day(month);
    final lead = (month.weekday - widget.weekStart + 7) % 7;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final earliest = addDays(widget.today, -widget.backfill);
    final created = widget.habit.created;
    final canBack =
        first.substring(0, 7).compareTo(created.substring(0, 7)) > 0;
    final canNext =
        first.substring(0, 7).compareTo(widget.today.substring(0, 7)) < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('grid-prev'),
              tooltip: tr(context, 'Previous month', 'Tháng trước'),
              onPressed: canBack
                  ? () => setState(
                      () => month = DateTime.utc(month.year, month.month - 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                tr(
                  context,
                  '${month.month}/${month.year}',
                  'Tháng ${month.month}, ${month.year}',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('grid-next'),
              tooltip: tr(context, 'Next month', 'Tháng sau'),
              onPressed: canNext
                  ? () => setState(
                      () => month = DateTime.utc(month.year, month.month + 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: [
            for (var i = 0; i < 7; i++)
              Center(
                child: Text(
                  weekdayShort(context, (widget.weekStart - 1 + i) % 7 + 1),
                  style: theme.textTheme.labelSmall?.copyWith(color: c.muted),
                ),
              ),
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var n = 1; n <= days; n++)
              _Day(
                habit: widget.habit,
                day: day(DateTime.utc(month.year, month.month, n)),
                today: widget.today,
                index: widget.index,
                editable:
                    widget.onDay != null &&
                    !widget.habit.archived &&
                    day(
                          DateTime.utc(month.year, month.month, n),
                        ).compareTo(widget.today) <=
                        0 &&
                    day(
                          DateTime.utc(month.year, month.month, n),
                        ).compareTo(earliest) >=
                        0 &&
                    day(
                          DateTime.utc(month.year, month.month, n),
                        ).compareTo(created) >=
                        0,
                onTap: widget.onDay,
              ),
          ],
        ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  final Habit habit;
  final String day, today;
  final HabitIndex index;
  final bool editable;
  final void Function(String)? onTap;
  const _Day({
    required this.habit,
    required this.day,
    required this.today,
    required this.index,
    required this.editable,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    var status = habitStatus(habit, day, today, index);
    // A pause already set shows ahead, so the days off read as one band.
    if (status == 'future' &&
        isScheduledOn(habit, day) &&
        index.paused(habit.id, day))
      status = 'paused';
    final planned = !{'notScheduled', 'future'}.contains(status);
    final isToday = day == today;
    return Semantics(
      button: editable,
      label: '${formatDay(context, day)}: ${statusLabel(context, status)}',
      excludeSemantics: true,
      child: InkResponse(
        key: Key('day-$day'),
        onTap: editable ? () => onTap!(day) : null,
        radius: 22,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (planned)
              Bead(
                status: status,
                fill: dayFill(habit, day, index),
                size: 30,
                color: isToday
                    ? c.accent
                    : theme.colorScheme.onSurface.withValues(alpha: .78),
              ),
            Text(
              '${int.parse(day.substring(8))}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isToday ? FontWeight.w700 : null,
                color: status == 'completed'
                    ? theme.colorScheme.surface
                    : planned
                    ? null
                    : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
