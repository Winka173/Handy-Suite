import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../routines/run.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'beads.dart';
import 'check_in.dart';
import '../habits/habit_appearance.dart';

/// Days done this week out of the quota, for a days-a-week habit.
int doneThisWeek(Habit h, String today, HabitIndex index, int weekStart) {
  var n = 0;
  for (
    var d = weekOf(today, weekStart);
    d.compareTo(today) <= 0;
    d = addDays(d, 1)
  ) {
    final s = scheduleOn(h, d);
    if (s != null && index.value(h.id, d) >= s.target) n++;
  }
  return n;
}

/// The line under a habit's name: today's progress and its run of days.
String habitLine(
  BuildContext context,
  HabitScope scope,
  Habit h,
  HabitIndex index,
) {
  final today = scope.today;
  final s = scheduleOn(h, today) ?? h.schedules.last;
  final parts = <String>[];
  // A pause for everything is said once, in the greeting; a pause for
  // this habit is said on its row.
  final restUntil =
      index.pauses.any((p) => !p.everything && p.covers(h.id, today))
      ? pausedUntil(index.pauses, h.id, today)
      : null;
  if (restUntil != null)
    parts.add(
      tr(
        context,
        'Paused until ${formatDay(context, restUntil)}',
        'Nghỉ đến ${formatDay(context, restUntil)}',
      ),
    );
  if (s.kind == 'weekly') {
    // The quota shrinks with the week's paused days.
    final quota = weekQuota(h, weekOf(today, s.weekStart), index);
    if (quota > 0)
      parts.add(
        tr(
          context,
          '${doneThisWeek(h, today, index, s.weekStart)} of $quota days this week',
          '${doneThisWeek(h, today, index, s.weekStart)}/$quota ngày tuần này',
        ),
      );
  } else if (h.type != 'binary') {
    parts.add(progressText(context, h, index.value(h.id, today), s.target));
  }
  final m = metrics(h, today, scope.state.weekStart, index);
  if (m.current > 1)
    parts.add(
      m.unit == 'weeks'
          ? tr(context, '${m.current} weeks running', 'chuỗi ${m.current} tuần')
          : tr(context, '${m.current} days running', 'chuỗi ${m.current} ngày'),
    );
  if (parts.isEmpty) parts.add(scheduleText(context, s));
  return parts.join(' · ');
}

/// A habit on a day: name and progress, its recent beads, and today's
/// bead as the one button.
class HabitRow extends StatelessWidget {
  final HabitScope scope;
  final Habit habit;
  final HabitIndex index;
  final VoidCallback onOpen;
  final bool selected;
  const HabitRow({
    super.key,
    required this.scope,
    required this.habit,
    required this.index,
    required this.onOpen,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final h = habit;
    final scheduled = isScheduledOn(h, scope.today);
    return Material(
      color: selected ? c.select : Colors.transparent,
      child: InkWell(
        key: Key('habit-${h.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            10,
            HandySpace.s,
            10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          habitIcon(h.icon),
                          size: 18,
                          color: habitInk(h.color, theme.colorScheme.surface),
                        ),
                        const SizedBox(width: HandySpace.s),
                        Flexible(
                          child: Text(
                            h.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      habitLine(context, scope, h, index),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    EarlierBeads(data: HabitDay(h, scope.today, index)),
                  ],
                ),
              ),
              if (scheduled && !h.archived)
                TodayBead(
                  scope: scope,
                  habit: h,
                  index: index,
                  onTap: () => checkIn(context, scope, h),
                  onLongPress: () => editDay(context, scope, h, scope.today),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HandySpace.s),
                  child: Text(
                    h.archived
                        ? tr(context, 'Archived', 'Đã lưu trữ')
                        : tr(context, 'Not today', 'Không phải hôm nay'),
                    style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A routine: when, how long, how many steps, and Start.
class RoutineRow extends StatelessWidget {
  final HabitScope scope;
  final Routine routine;
  final VoidCallback onOpen;
  final bool primary, selected;
  const RoutineRow({
    super.key,
    required this.scope,
    required this.routine,
    required this.onOpen,
    this.primary = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final r = routine;
    final ranToday = scope.state.sessions.any(
      (s) =>
          s.routine == r.id && s.day == scope.today && s.status == 'finished',
    );
    final meta = [
      if (r.weekdays.isNotEmpty) r.time,
      tr(context, '${r.steps.length} steps', '${r.steps.length} bước'),
      minutesText(context, r.planned),
      if (ranToday) tr(context, 'done today', 'hôm nay đã chạy'),
    ].join(' · ');
    final start = r.steps.isEmpty || r.archived
        ? null
        : () => startRoutine(context, scope, r);
    return Material(
      color: selected ? c.select : Colors.transparent,
      child: InkWell(
        key: Key('routine-${r.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            10,
            HandySpace.m,
            10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          habitIcon(r.icon),
                          size: 20,
                          color: habitInk(r.color, theme.colorScheme.surface),
                        ),
                        const SizedBox(width: HandySpace.s),
                        Flexible(
                          child: Text(
                            r.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HandySpace.s),
              if (primary && !ranToday)
                FilledButton(
                  key: Key('start-${r.id}'),
                  onPressed: start,
                  child: Text(tr(context, 'Start', 'Bắt đầu')),
                )
              else
                OutlinedButton(
                  key: Key('start-${r.id}'),
                  onPressed: start,
                  child: Text(tr(context, 'Start', 'Bắt đầu')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
