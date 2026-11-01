import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../habits/habit_editor.dart';
import '../routines/run.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'rows.dart';

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
          s.habits.where((h) => !h.archived && isScheduledOn(h, today)).toList()
            ..sort((a, b) {
              int rank(Habit h) =>
                  switch (habitStatus(h, today, today, index)) {
                    'completed' || 'skipped' => 1,
                    _ => 0,
                  };
              final r = rank(a).compareTo(rank(b));
              return r != 0 ? r : b.priority.compareTo(a.priority);
            });
      final routines =
          s.routines
              .where(
                (r) =>
                    !r.archived &&
                    r.steps.isNotEmpty &&
                    r.weekdays.contains(date(today).weekday),
              )
              .toList()
            ..sort((a, b) => a.time.compareTo(b.time));
      final notToday = s.habits
          .where((h) => !h.archived && !isScheduledOn(h, today))
          .length;
      final wide = size.maxWidth >= 1000;
      final left = [
        _Greeting(scope: scope, due: due, routines: routines, index: index),
        if (scope.activeSession != null) _Resume(scope: scope),
        _Habits(scope: scope, due: due, index: index, notToday: notToday),
      ];
      final right = [
        _Routines(scope: scope, routines: routines),
        _NextReminder(scope: scope),
      ];
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.xl,
          HandySpace.l,
          HandySpace.xxl,
        ),
        children: [
          HandyContent(
            maxWidth: HandySpace.contentWide,
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: left,
                        ),
                      ),
                      const SizedBox(width: HandySpace.xl),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 72),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: right,
                          ),
                        ),
                      ),
                    ],
                  )
                // On a phone the routine to start comes before the list,
                // inside the first screen.
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...left.take(left.length - 1),
                      if (routines.isNotEmpty) right.first,
                      left.last,
                      if (routines.isEmpty) right.first,
                      ...right.skip(1),
                    ],
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
    final c = HandyColors.of(context);
    final today = scope.today;
    final hour = scope.hour;
    final hello = hour < 11
        ? tr(context, 'Good morning.', 'Chào buổi sáng.')
        : hour < 17
        ? tr(context, 'Good afternoon.', 'Chào buổi chiều.')
        : tr(context, 'Good evening.', 'Chào buổi tối.');
    final left = due
        .where(
          (h) => !{
            'completed',
            'skipped',
          }.contains(habitStatus(h, today, today, index)),
        )
        .length;
    final ran = {
      for (final s in scope.state.sessions)
        if (s.day == today && s.status == 'finished') s.routine,
    };
    final next = routines.where((r) => !ran.contains(r.id)).firstOrNull;
    final facts = [
      if (due.isEmpty)
        tr(context, 'Nothing planned today', 'Hôm nay không có lịch')
      else if (left == 0)
        tr(context, 'All ${due.length} done', 'Xong cả ${due.length} việc')
      else
        tr(context, '$left left to do', 'Còn $left việc'),
      if (next != null)
        tr(
          context,
          '${next.title} at ${next.time}',
          '${next.title} lúc ${next.time}',
        ),
    ];
    final d = date(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            hello,
            key: const Key('today-greeting'),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: HandySpace.xs),
        // The day's one fact, then the date, in a line under the greeting.
        Text(
          '${facts.join(' · ')}.',
          key: const Key('today-fact'),
          style: theme.textTheme.titleMedium,
        ),
        Text(
          '${weekdayLong(context, d.weekday)}, ${formatDay(context, today)}',
          style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
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
    final done = s.steps.where((x) => x.status != 'pending').length;
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.l),
      child: HandyNotice(
        tr(
          context,
          '${s.title} is not finished: step ${s.cursor + 1} of ${s.steps.length}, $done done.',
          '${s.title} còn dở: bước ${s.cursor + 1}/${s.steps.length}, đã xong $done.',
        ),
        action: TextButton(
          key: const Key('resume-session'),
          onPressed: () => openSession(context, scope, s.id),
          child: Text(tr(context, 'Continue', 'Tiếp tục')),
        ),
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
    if (scope.state.habits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: HandySpace.xl),
        child: HandyEmpty(
          title: tr(context, 'No habits yet', 'Chưa có thói quen'),
          message: tr(
            context,
            'Start with one small thing you want to do most days.',
            'Bắt đầu bằng một việc nhỏ bạn muốn làm gần như mỗi ngày.',
          ),
          action: FilledButton.icon(
            key: const Key('today-add-habit'),
            onPressed: () => openHabitEditor(context, scope),
            icon: const Icon(Icons.add),
            label: Text(tr(context, 'New habit', 'Thói quen mới')),
          ),
        ),
      );
    }
    return HandySection(
      title: tr(context, 'To do today', 'Việc hôm nay'),
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
        for (final h in due)
          HabitRow(
            scope: scope,
            habit: h,
            index: index,
            onOpen: () => Navigator.pushNamed(context, '/habit/${h.id}'),
          ),
        if (notToday > 0)
          InkWell(
            key: const Key('today-others'),
            onTap: () => scope.area.value = 1,
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
    final next = routines.where((r) => !ran.contains(r.id)).firstOrNull;
    return HandySection(
      title: tr(context, 'Routines today', 'Quy trình hôm nay'),
      trailing: TextButton(
        onPressed: () => scope.area.value = 2,
        child: Text(tr(context, 'All routines', 'Tất cả')),
      ),
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
        for (final r in routines)
          RoutineRow(
            scope: scope,
            routine: r,
            primary: r.id == next?.id,
            onOpen: () => Navigator.pushNamed(context, '/routine/${r.id}'),
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
