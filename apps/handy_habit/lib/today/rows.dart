import '../ui/row_menu.dart';
import '../habits/habit_view.dart' show HabitMenu;
import '../routines/routine_view.dart' show RoutineMenu;
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../routines/run.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'beads.dart';
import 'check_in.dart';
import '../habits/habit_appearance.dart';
import '../design/studio_style.dart';
import '../design/palette.dart';

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
  if (h.isNegative) return negativeLine(context, h, today, index);
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
          '${doneThisWeek(h, today, index, s.weekStart)} of $quota ${quota == 1 ? 'day' : 'days'} this week',
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
          : tr(
              context,
              '${m.current} ${m.current == 1 ? 'day' : 'days'} running',
              'chuỗi ${m.current} ngày',
            ),
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
    final studio = StudioStyle.of(context);
    final scheduled = isScheduledOn(h, scope.today);
    return HabitContextMenu(
      items: HabitMenu(scope: scope, habit: h).items(context),
      child: Material(
        color: selected
            ? c.select
            : studio.layout == 'cards'
            ? HabitPalette.of(context).surface
            : Colors.transparent,
        shape: studio.layout == 'cards'
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: HabitPalette.of(context).line),
              )
            : null,
        child: InkWell(
          key: Key('habit-${h.id}'),
          onTap: onOpen,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              HandySpace.l,
              studio.spacing == 'airy'
                  ? 20
                  : scope.state.settings['density'] == 'compact'
                  ? 6
                  : 10,
              HandySpace.s,
              studio.spacing == 'airy'
                  ? 20
                  : scope.state.settings['density'] == 'compact'
                  ? 6
                  : 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasHabitIcon(h) || studio.icons.containsKey(h.id))
                            Icon(
                              studioExtraIcons[studio.icons[h.id]] ??
                                  habitIcon(h.icon),
                              size: 22,
                              color: habitMark(context, h),
                            )
                          else
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: habitMark(context, h),
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: HandySpace.s),
                          Flexible(
                            child: Text(
                              h.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        habitLine(context, scope, h, index),
                        maxLines: h.isNegative ? null : 2,
                        overflow: h.isNegative ? null : TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      EarlierBeads(data: HabitDay(h, scope.today, index)),
                      if (h.isNegative &&
                          scheduled &&
                          !index.known(h.id, scope.today) &&
                          !index.skip(h.id, scope.today))
                        TextButton(
                          key: Key('none-${h.id}'),
                          onPressed: () => scope.write(
                            context,
                            (s) => setManualTotal(
                              s,
                              h.id,
                              scope.today,
                              0,
                              today: scope.today,
                            ),
                            done: (c) => tr(
                              c,
                              '${h.title}: none today.',
                              '${h.title}: hôm nay không có.',
                            ),
                          ),
                          child: Text(
                            tr(context, 'None today', 'Hôm nay không có'),
                          ),
                        ),
                    ],
                  ),
                ),
                Flex(
                  direction:
                      MediaQuery.sizeOf(context).width /
                              MediaQuery.textScalerOf(context).scale(1) <
                          360
                      ? Axis.vertical
                      : Axis.horizontal,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (scheduled && !h.archived)
                      TodayBead(
                        scope: scope,
                        habit: h,
                        index: index,
                        onTap: () => checkIn(context, scope, h),
                        onLongPress: () =>
                            editDay(context, scope, h, scope.today),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: HandySpace.s,
                        ),
                        child: Text(
                          h.archived
                              ? tr(context, 'Archived', 'Đã lưu trữ')
                              : tr(context, 'Not today', 'Không phải hôm nay'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ),
                    HabitMenu(
                      key: Key('habit-more-${h.id}'),
                      scope: scope,
                      habit: h,
                    ),
                  ],
                ),
              ],
            ),
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
    final recent = scope.state.sessions.where((s) => s.routine == r.id).toList()
      ..sort((a, b) => b.started.compareTo(a.started));
    final latest = recent.firstOrNull;
    final resume = scope.activeSession?.routine == r.id;
    final ranToday = scope.state.sessions.any(
      (s) =>
          s.routine == r.id && s.day == scope.today && s.status == 'finished',
    );
    final meta = [
      if (r.weekdays.isNotEmpty) r.time,
      tr(
        context,
        '${r.steps.length} ${r.steps.length == 1 ? 'step' : 'steps'}',
        '${r.steps.length} bước',
      ),
      minutesText(context, r.planned),
      if (latest != null)
        tr(
          context,
          'Last run: ${formatDay(context, latest.day)} · ${statusLabel(context, latest.status)}',
          'Phiên gần nhất: ${formatDay(context, latest.day)} · ${statusLabel(context, latest.status)}',
        )
      else
        tr(context, 'Not run yet', 'Chưa chạy'),
    ].join(' · ');
    final start = r.steps.isEmpty || r.archived
        ? null
        : () => startRoutine(context, scope, r);
    final hasIcon = [
      ...habitIcons,
      ...templateIcons,
    ].any((i) => i.codePoint == r.icon && i != Icons.check);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasIcon ? habitIcon(r.icon) : Icons.format_list_numbered,
              size: 20,
              color: hasIcon
                  ? habitInk(r.color, theme.colorScheme.surface)
                  : c.muted,
            ),
            const SizedBox(width: HandySpace.s),
            Expanded(
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
        Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: c.muted)),
      ],
    );
    final label = Text(
      resume
          ? tr(context, 'Resume', 'Tiếp tục')
          : tr(context, 'Start', 'Bắt đầu'),
    );
    final action = primary && !ranToday
        ? FilledButton(
            key: Key('start-${r.id}'),
            onPressed: start,
            child: label,
          )
        : OutlinedButton(
            key: Key('start-${r.id}'),
            onPressed: start,
            child: label,
          );
    return HabitContextMenu(
      items: RoutineMenu(scope: scope, routine: r).items(context),
      child: Material(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth /
                        MediaQuery.textScalerOf(context).scale(1) <
                    280;
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          details,
                          const SizedBox(height: HandySpace.s),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                action,
                                RoutineMenu(
                                  key: Key('routine-more-${r.id}'),
                                  scope: scope,
                                  routine: r,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: HandySpace.s),
                          action,
                          RoutineMenu(
                            key: Key('routine-more-${r.id}'),
                            scope: scope,
                            routine: r,
                          ),
                        ],
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}
