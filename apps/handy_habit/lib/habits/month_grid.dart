import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../today/beads.dart';
import '../ui/words.dart';
import '../ui/capped.dart';
import 'habit_appearance.dart';

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
  bool? asList;
  // Always this month first; the arrows go back.
  late DateTime month = () {
    final t = date(widget.today);
    return DateTime.utc(t.year, t.month);
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
    final list =
        asList ??
        (MediaQuery.sizeOf(context).width < 368 ||
            MediaQuery.textScalerOf(context).scale(14) > 18);
    bool editable(String d) =>
        widget.onDay != null &&
        !widget.habit.archived &&
        d.compareTo(widget.today) <= 0 &&
        d.compareTo(earliest) >= 0 &&
        d.compareTo(created) >= 0;
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
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('month-view-toggle'),
            icon: Icon(
              list ? Icons.calendar_month_outlined : Icons.list,
              size: 20,
            ),
            label: Text(
              list
                  ? tr(context, 'Calendar', 'Lịch tháng')
                  : tr(context, 'Days as list', 'Danh sách ngày'),
            ),
            onPressed: () => setState(() => asList = !list),
          ),
        ),
        if (list)
          Capped(
            key: ValueKey(first),
            count: days,
            max: 7,
            name: 'month-days',
            builder: (context, shown) => Column(
              children: [
                for (var i = days; i > days - shown; i--)
                  Builder(
                    builder: (context) {
                      final d = day(DateTime.utc(month.year, month.month, i));
                      final status = habitStatus(
                        widget.habit,
                        d,
                        widget.today,
                        widget.index,
                      );
                      final target = scheduleOn(widget.habit, d)?.target;
                      return ListTile(
                        key: Key('day-$d'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        minTileHeight: 48,
                        title: Text(formatDay(context, d)),
                        subtitle: Text(
                          [
                            statusLabel(context, status),
                            if (widget.habit.isNegative &&
                                widget.index.known(widget.habit.id, d) &&
                                negativeGoalOn(widget.habit, d) != null)
                              '${figure(context, widget.index.value(widget.habit.id, d))} ${unitOf(context, widget.habit, value: widget.index.value(widget.habit.id, d))} · ${negativeLimitText(context, negativeGoalOn(widget.habit, d)!)}',
                            if (widget.habit.isNegative &&
                                !widget.index.known(widget.habit.id, d) &&
                                negativeGoalOn(widget.habit, d) != null)
                              negativeLimitText(
                                context,
                                negativeGoalOn(widget.habit, d)!,
                              ),
                            if (!widget.habit.isNegative &&
                                target != null &&
                                widget.habit.type != 'binary')
                              progressText(
                                context,
                                widget.habit,
                                widget.index.value(widget.habit.id, d),
                                target,
                              ),
                          ].join(' · '),
                        ),
                        trailing: editable(d)
                            ? const Icon(Icons.edit_outlined, size: 18)
                            : null,
                        onTap: editable(d) ? () => widget.onDay!(d) : null,
                      );
                    },
                  ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: box.maxWidth.clamp(336, double.infinity),
                child: GridView(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: 48,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < 7; i++)
                      Center(
                        child: Text(
                          weekdayShort(
                            context,
                            (widget.weekStart - 1 + i) % 7 + 1,
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: c.muted,
                          ),
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
              ),
            ),
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
      label:
          '${formatDay(context, day)}: ${statusLabel(context, status)}, ${habit.isNegative ? (index.known(habit.id, day) ? '${figure(context, index.value(habit.id, day))} ${unitOf(context, habit, value: index.value(habit.id, day))}' : '') : progressText(context, habit, index.value(habit.id, day), scheduleOn(habit, day)?.target ?? 1000)}',
      excludeSemantics: true,
      child: InkResponse(
        key: Key('day-$day'),
        onTap: editable ? () => onTap!(day) : null,
        radius: 22,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (planned)
              // The habit's own colour; a part-done day is a ring that
              // fills, so its number stays readable.
              Bead(
                status: status == 'partial' ? 'progress' : status,
                fill: dayFill(habit, day, index),
                size: 30,
                color: habitMark(context, habit),
              ),
            if (isToday && status != 'completed')
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.accent, width: 2),
                ),
              ),
            Text(
              '${int.parse(day.substring(8))}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isToday ? FontWeight.w700 : null,
                color: status == 'withinLimit' || status == 'completed'
                    ? (habitMark(context, habit).computeLuminance() > .179
                          ? Colors.black
                          : Colors.white)
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
