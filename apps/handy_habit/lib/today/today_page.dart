import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../habits/preset_sheet.dart';
import '../insights/week_review.dart';
import '../pauses/pauses.dart';
import '../routines/run.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'rows.dart';
import 'day_parts.dart';
import '../ui/capped.dart';
import '../design/palette.dart';
import 'beads.dart';
import '../mood/mood_history.dart';

/// Today: what is left to do, each habit as a string of beads with today's
/// bead to tap, and the routines to start.
class TodayPage extends StatelessWidget {
  final HabitScope scope;
  const TodayPage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final s = scope.state, today = scope.today, index = scope.index;
      final due =
          s.liveHabits
              .where((h) => !h.archived && isScheduledOn(h, today))
              .toList()
            ..sort((a, b) => b.priority.compareTo(a.priority));
      final routines =
          s.liveRoutines
              .where(
                (r) =>
                    !r.archived &&
                    r.steps.isNotEmpty &&
                    r.weekdays.contains(date(today).weekday),
              )
              .toList()
            ..sort((a, b) => a.time.compareTo(b.time));
      final notToday = s.liveHabits
          .where((h) => !h.archived && !isScheduledOn(h, today))
          .length;
      // 1440 - 224 sidebar - 32 gutters = 1184; 1024 content gives
      // (1024 - 24) * 3/5 = 600px habits and 400px secondary column.
      final wide = size.maxWidth >= 900;
      final left = [
        _Greeting(scope: scope, due: due, routines: routines, index: index),
        if (s.settings['showMoodToday'] != false) TodayMood(scope: scope),
        if (scope.activeSession != null) _Resume(scope: scope),
        _Habits(scope: scope, due: due, index: index, notToday: notToday),
      ];
      final right = [
        _Routines(scope: scope, routines: routines),
        if (reviewDue(scope) case final review?)
          WeekReviewRow(scope: scope, review: review),
        _NextReminder(scope: scope),
      ];
      return ListView(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
          HandySpace.l,
          MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
          104,
        ),
        children: [
          HandyContent(
            maxWidth: wide ? 1024 : 680,
            // The greeting spans both columns, so the two sections below
            // start on one line whatever the greeting holds.
            child: wide
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left.first,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: left.skip(1).toList(),
                            ),
                          ),
                          const SizedBox(width: HandySpace.xl),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [...left, ...right],
                  ),
          ),
        ],
      );
    },
  );
}

/// "Good morning." and the day's one fact, built from the data.
class _Greeting extends StatelessWidget {
  final HabitScope scope;
  final List<Habit> due;
  final List<Routine> routines;
  final HabitIndex index;
  const _Greeting({
    required this.scope,
    required this.due,
    required this.routines,
    required this.index,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    final today = scope.today;
    final hour = scope.hour;
    final hello = hour < 11
        ? tr(context, 'Good morning.', 'Chào buổi sáng.')
        : hour < 17
        ? tr(context, 'Good afternoon.', 'Chào buổi chiều.')
        : tr(context, 'Good evening.', 'Chào buổi tối.');
    final buildDue = due.where((h) => !h.isNegative).toList();
    final reductions = due.where((h) => h.isNegative).toList();
    final observedReductions = reductions
        .where((h) => index.known(h.id, today))
        .length;
    final left = due
        .where(
          (h) => h.isNegative
              ? negativeGoalOn(h, today)?.window != 'week' &&
                    !index.known(h.id, today) &&
                    !index.paused(h.id, today) &&
                    !index.skip(h.id, today)
              : !{
                  'completed',
                  'skipped',
                  'paused',
                }.contains(habitStatus(h, today, today, index)),
        )
        .length;
    final resting = restingNow(scope.state, today);
    final facts = resting != null
        ? [
            tr(
              context,
              'Paused until ${weekdayLong(context, date(resting.$2).weekday)}, ${formatDay(context, resting.$2)}',
              'Đang nghỉ đến ${weekdayLong(context, date(resting.$2).weekday)}, ${formatDay(context, resting.$2)}',
            ),
            tr(context, 'nothing to do', 'không có gì phải làm'),
          ]
        : [
            if (due.isEmpty)
              tr(context, 'Nothing planned today', 'Hôm nay không có lịch')
            else if (left == 0)
              tr(
                context,
                reductions.isEmpty
                    ? 'All ${due.length} done'
                    : 'All done for today',
                reductions.isEmpty
                    ? 'Xong cả ${due.length} việc'
                    : 'Hôm nay đã xong',
              )
            else
              tr(
                context,
                reductions.isEmpty
                    ? '$left left to do'
                    : left == 1
                    ? '1 habit still needs a check-in'
                    : '$left habits still need a check-in',
                reductions.isEmpty
                    ? 'Còn $left việc'
                    : 'Còn $left thói quen chưa ghi hôm nay',
              ),
          ];
    final d = date(today);
    final kept = buildDue
        .where((h) => habitStatus(h, today, today, index) == 'completed')
        .length;
    final keptText = buildDue.isEmpty && reductions.isNotEmpty
        ? tr(
            context,
            '$observedReductions of ${reductions.length} recorded',
            '$observedReductions/${reductions.length} đã ghi',
          )
        : tr(
            context,
            '$kept of ${buildDue.length} kept',
            '$kept / ${buildDue.length} đã giữ',
          );
    final reductionText = reductions.isEmpty
        ? ''
        : tr(
            context,
            'Cutting back: $observedReductions of ${reductions.length} recorded today.',
            'Đang bớt: đã ghi $observedReductions/${reductions.length} hôm nay.',
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            hello,
            key: const Key('today-greeting'),
            // Editorial greeting: Nunito bold in Habit's warm anchor.
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize:
                  MediaQuery.sizeOf(context).width /
                          MediaQuery.textScalerOf(context).scale(1) <
                      240
                  ? 26
                  : MediaQuery.sizeOf(context).width < 400
                  ? 34
                  : 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
              color: p.anchor,
              height: 1.1,
            ),
          ),
        ),
        if (due.isNotEmpty && resting == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Semantics(
              label: '$keptText. $reductionText ${facts.join(' · ')}',
              excludeSemantics: true,
              child: Row(
                children: [
                  DayRing(
                    fill: buildDue.isEmpty
                        ? (reductions.isEmpty
                              ? 0
                              : observedReductions / reductions.length)
                        : kept / buildDue.length,
                    color: p.vermilion,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          keptText,
                          key: const Key('today-kept'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: p.vermilion,
                          ),
                        ),
                        Text(
                          [
                            if (reductionText.isNotEmpty && buildDue.isNotEmpty)
                              reductionText,
                            '${facts.join(' · ')}.',
                          ].join(' '),
                          key: const Key('today-fact'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: HandySpace.xs),
        // The day's one fact, then the date, in a line under the greeting.
        if (due.isEmpty || resting != null)
          Text(
            [
              if (reductionText.isNotEmpty && buildDue.isNotEmpty)
                reductionText,
              '${facts.join(' · ')}.',
            ].join(' '),
            key: const Key('today-fact'),
            style: theme.textTheme.titleMedium,
          ),
        Text(
          [
            '${weekdayShort(context, d.weekday)}, ${formatDay(context, today)}',
            if (resting != null && resting.$1.reason.isNotEmpty)
              resting.$1.reason,
          ].join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(color: p.ochre),
        ),
        if (resting != null)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.xs),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const Key('pause-end-today'),
                // Its words line up with the lines above; the target
                // stays 48 px tall.
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 48),
                  alignment: AlignmentDirectional.centerStart,
                ),
                onPressed: () => endPauseNow(context, scope, resting.$1),
                child: Text(tr(context, 'End early', 'Kết thúc sớm')),
              ),
            ),
          ),
      ],
    );
  }
}

class _Resume extends StatelessWidget {
  final HabitScope scope;
  const _Resume({required this.scope});
  @override
  Widget build(BuildContext context) {
    final s = scope.activeSession!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${s.title} · ${s.cursor + 1}/${s.steps.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            key: const Key('resume-session'),
            onPressed: () => openSession(context, scope, s.id),
            child: Text(tr(context, 'Continue', 'Tiếp tục')),
          ),
        ],
      ),
    );
  }
}

class _Habits extends StatelessWidget {
  final HabitScope scope;
  final List<Habit> due;
  final HabitIndex index;
  final int notToday;
  const _Habits({
    required this.scope,
    required this.due,
    required this.index,
    required this.notToday,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    if (scope.state.liveHabits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: HandySpace.xl),
        child: HandyEmpty(
          title: tr(context, 'No habits yet', 'Chưa có thói quen'),
          message: tr(
            context,
            'Start with one small thing you want to do most days.',
            'Bắt đầu bằng một việc nhỏ bạn muốn làm gần như mỗi ngày.',
          ),
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                key: const Key('today-add-habit'),
                onPressed: () => addHabit(context, scope),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'New habit', 'Thói quen mới')),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final (id, en, vi, collection) in const [
                    ('sleep', 'Sleep', 'Ngủ', 'sleep'),
                    ('move', 'Move', 'Vận động', 'fitness'),
                    ('focus', 'Focus', 'Tập trung', 'focus'),
                    ('read', 'Read', 'Đọc', 'reading'),
                    ('water', 'Water', 'Uống nước', 'nutrition'),
                    ('phone', 'Less phone', 'Bớt điện thoại', 'digital'),
                  ])
                    ActionChip(
                      key: Key('goal-$id'),
                      label: Text(tr(context, en, vi)),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/templates?collection=$collection',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    tr(context, 'Habits', 'Thói quen'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const Key('today-all-habits'),
                    onPressed: () => Navigator.pushNamed(context, '/habits'),
                    child: Text(tr(context, 'All habits', 'Tất cả')),
                  ),
                ),
              ),
            ],
          ),
        ),
        HandyGroup(
          children: [
            if (due.isEmpty)
              Padding(
                padding: const EdgeInsets.all(HandySpace.l),
                child: Text(
                  tr(
                    context,
                    'Nothing is planned today. Your other habits are under Habits.',
                    'Hôm nay không có lịch. Các thói quen khác ở mục Thói quen.',
                  ),
                ),
              ),
            Capped(
              count: due.length,
              max: 6,
              name: 'today-habits',
              builder: (context, shown) {
                final parts = ['morning', 'afternoon', 'evening', 'anytime'];
                final grouped = due.any(
                  (h) => habitDayPart(scope.state, h) != 'anytime',
                );
                final ordered = [...due]
                  ..sort(
                    (a, b) => parts
                        .indexOf(habitDayPart(scope.state, a))
                        .compareTo(parts.indexOf(habitDayPart(scope.state, b))),
                  );
                final visible = ordered.take(shown).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final part in parts) ...[
                      if (grouped &&
                          visible.any(
                            (h) => habitDayPart(scope.state, h) == part,
                          ))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(switch (part) {
                            'morning' => tr(context, 'Morning', 'Buổi sáng'),
                            'afternoon' => tr(
                              context,
                              'Afternoon',
                              'Buổi chiều',
                            ),
                            'evening' => tr(context, 'Evening', 'Buổi tối'),
                            _ => tr(context, 'Any time', 'Bất kỳ lúc nào'),
                          }, style: Theme.of(context).textTheme.labelLarge),
                        ),
                      for (final h in visible.where(
                        (h) => habitDayPart(scope.state, h) == part,
                      ))
                        HandyAppear(
                          key: ValueKey(h.id),
                          child: HabitRow(
                            scope: scope,
                            habit: h,
                            index: index,
                            onOpen: () =>
                                Navigator.pushNamed(context, '/habit/${h.id}'),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
            if (notToday > 0)
              InkWell(
                key: const Key('today-others'),
                onTap: () => Navigator.pushNamed(context, '/habits'),
                child: Padding(
                  padding: const EdgeInsets.all(HandySpace.l),
                  child: Text(
                    tr(
                      context,
                      '$notToday more not planned today',
                      'Thêm $notToday thói quen không có lịch hôm nay',
                    ),
                    style: TextStyle(color: c.muted),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Routines extends StatelessWidget {
  final HabitScope scope;
  final List<Routine> routines;
  const _Routines({required this.scope, required this.routines});
  @override
  Widget build(BuildContext context) {
    final ran = {
      for (final s in scope.state.sessions)
        if (s.day == scope.today && s.status == 'finished') s.routine,
    };
    // While everything is paused no routine is pressed on anyone.
    final next = restingNow(scope.state, scope.today) != null
        ? null
        : routines.where((r) => !ran.contains(r.id)).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    tr(context, 'Routines today', 'Quy trình hôm nay'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/routines'),
                    child: Text(tr(context, 'All routines', 'Tất cả')),
                  ),
                ),
              ),
            ],
          ),
        ),
        HandyGroup(
          children: [
            if (routines.isEmpty)
              Padding(
                padding: const EdgeInsets.all(HandySpace.l),
                child: Text(
                  tr(
                    context,
                    'No routine planned today. A routine is a few steps in order, like a morning.',
                    'Hôm nay không có quy trình. Quy trình là vài bước theo thứ tự, như buổi sáng.',
                  ),
                ),
              ),
            Capped(
              count: routines.length,
              max: 2,
              name: 'today-routines',
              builder: (context, shown) => Column(
                children: [
                  for (final r in routines.take(shown))
                    RoutineRow(
                      key: ValueKey(r.id),
                      scope: scope,
                      routine: r,
                      primary: r.id == next?.id,
                      onOpen: () =>
                          Navigator.pushNamed(context, '/routine/${r.id}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The next reminder, in the app, for where the system cannot remind.
class _NextReminder extends StatelessWidget {
  final HabitScope scope;
  const _NextReminder({required this.scope});
  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final next = dueReminders(s, scope.clock()).firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final id = next.key.split(':').first;
    final rule = objects(
      s.settings['reminders'] ?? [],
    ).where((r) => r['id'] == id).firstOrNull;
    final name = rule == null
        ? ''
        : rule['type'] == 'habit'
        ? scope.habit(rule['target'] as String?)?.title ?? ''
        : scope.routine(rule['target'] as String?)?.title ?? '';
    final at =
        '${next.when.hour.toString().padLeft(2, '0')}:${next.when.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.l),
      child: Row(
        children: [
          Icon(
            Icons.notifications_none,
            size: 18,
            color: HandyColors.of(context).muted,
          ),
          const SizedBox(width: HandySpace.s),
          Expanded(
            child: Text(
              tr(
                context,
                'Next reminder: ${dayText(context, day(next.when), scope.today).toLowerCase()} at $at${name.isEmpty ? '' : ', $name'}',
                'Nhắc tiếp theo: $at ${dayText(context, day(next.when), scope.today).toLowerCase()}${name.isEmpty ? '' : ', $name'}',
              ),
              style: TextStyle(color: HandyColors.of(context).muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's kept/due ring: it runs to each new value, and when the day is
/// full it swells once. Still when motion is reduced.
class DayRing extends StatefulWidget {
  final double fill;
  final Color color;
  const DayRing({super.key, required this.fill, required this.color});
  @override
  State<DayRing> createState() => _DayRingState();
}

class _DayRingState extends State<DayRing> with SingleTickerProviderStateMixin {
  late final AnimationController pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(DayRing old) {
    super.didUpdateWidget(old);
    if (old.fill < .999 &&
        widget.fill >= .999 &&
        MediaQuery.maybeDisableAnimationsOf(context) != true) {
      pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pop,
    builder: (context, child) => Transform.scale(
      scale: 1 + .14 * Curves.easeOut.transform(1 - (2 * pop.value - 1).abs()),
      child: child,
    ),
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: widget.fill),
      duration: HandyMotion.of(context, const Duration(milliseconds: 480)),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Bead(status: 'progress', fill: v, size: 52, color: widget.color),
    ),
  );
}
