import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../settings/data.dart';
import '../today/check_in.dart';
import '../habits/habit_appearance.dart';
import '../design/palette.dart';
import '../ui/capped.dart';
import '../ui/words.dart';
import 'progress_calendar.dart';
import 'week_review.dart';
import '../mood/mood_history.dart';

class InsightsPage extends StatefulWidget {
  final HabitScope scope;
  const InsightsPage({super.key, required this.scope});
  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  HabitScope get scope => widget.scope;
  String kind = 'month';
  late String anchor = scope.today;
  String? habit;
  (String, String) get range =>
      progressRange(kind, anchor, scope.state.weekStart);
  void move(int direction) {
    final d = date(anchor);
    setState(
      () => anchor = kind == 'week'
          ? addDays(anchor, direction * 7)
          : kind == 'month'
          ? day(DateTime.utc(d.year, d.month + direction))
          : day(DateTime.utc(d.year + direction, 1)),
    );
  }

  Future<void> export(BuildContext context, String format) async {
    final (from, until) = range;
    try {
      final message = await exportHabits(
        context,
        scope,
        format,
        from: from,
        until: until.compareTo(scope.today) > 0 ? scope.today : until,
      );
      if (message != null && context.mounted)
        showHandyMessage(context, message);
    } catch (e) {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Not exported: ${errorText(context, e)}.',
            'Chưa xuất: ${errorText(context, e)}.',
          ),
        );
    }
  }

  Future<void> showDay(HeatDay d, List<Habit> habits) async {
    final picked = await showModalBottomSheet<Habit>(
      context: context,
      sheetAnimationStyle: AnimationStyle(
        duration: HandyMotion.of(context),
        reverseDuration: HandyMotion.of(context),
      ),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  heatDayLabel(context, d, scope.today),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final h in habits)
                      ListTile(
                        title: Text(h.title),
                        subtitle: Text(
                          statusLabel(
                            context,
                            habitStatus(h, d.day, scope.today, scope.index),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, h),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (!picked.archived &&
        d.day.compareTo(scope.today) <= 0 &&
        d.day.compareTo(addDays(scope.today, -scope.state.backfill)) >= 0 &&
        d.day.compareTo(picked.created) >= 0) {
      await editDay(context, scope, picked, d.day);
    } else {
      await Navigator.pushNamed(context, '/habit/${picked.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = scope.state, today = scope.today, index = scope.index;
    final (from, until) = range;
    final habits = s.liveHabits
        .where((h) => h.created.compareTo(until) <= 0)
        .toList();
    final counts = {
      for (final h in habits) h.id: progressCount(h, from, until, today, index),
    };
    final kept = counts.values.fold(0, (n, m) => n + m.kept),
        due = counts.values.fold(0, (n, m) => n + m.eligible);
    final shownHabit = habit == null
        ? null
        : habits.where((h) => h.id == habit).firstOrNull;
    final selected = shownHabit == null ? habits : [shownHabit];
    final hue = shownHabit == null
        ? HabitPalette.of(context).vermilion
        : habitMark(context, shownHabit);
    final days = progressDays(selected, from, until, today, index);
    final sessions = s.sessions
        .where(
          (x) =>
              x.day.compareTo(from) >= 0 &&
              x.day.compareTo(until) <= 0 &&
              x.day.compareTo(today) <= 0,
        )
        .toList();
    final routineIds = sessions.map((x) => x.routine).toSet().toList();
    final finished = sessions.where((x) => x.status == 'finished').length;
    final theme = Theme.of(context), p = HabitPalette.of(context);
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'Kept $kept of $due goals.',
            'Giữ được $kept trên $due mục tiêu.',
          ),
          key: const Key('progress-finding'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: p.anchor,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            'Each day or whole week counts once. Pauses, unknown days and unfinished periods are left out; only full weeks inside this range count.',
            'Mỗi ngày hoặc tuần trọn tính một lần. Bỏ qua ngày nghỉ, ngày chưa rõ và khoảng chưa hết; chỉ tính tuần trọn trong khoảng đã chọn.',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        if (habits.any((h) => h.negativeGoals.any((g) => g.window == 'week')))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr(
                context,
                'Weekly limits: counted from what you recorded.',
                'Giới hạn tuần: tính từ những lần bạn đã ghi.',
              ),
              key: const Key('weekly-inference-note'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (habits.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            tr(
              context,
              s.liveHabits.isEmpty
                  ? 'Your first habit will give this page a starting point.'
                  : 'No habit was planned in this period.',
              s.liveHabits.isEmpty
                  ? 'Thói quen đầu tiên sẽ là điểm bắt đầu cho trang này.'
                  : 'Khoảng này chưa có thói quen nào có lịch.',
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('progress-create'),
              onPressed: () => Navigator.pushNamed(context, '/templates'),
              child: Text(
                tr(context, 'Find a small start', 'Chọn một khởi đầu nhỏ'),
              ),
            ),
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('insights-week-review'),
            onPressed: () => openWeekReview(context, scope),
            icon: const Icon(Icons.event_note_outlined, size: 18),
            label: Text(tr(context, 'Look back at the week', 'Nhìn lại tuần')),
          ),
        ),
      ],
    );
    final selectedCount = shownHabit == null ? null : counts[shownHabit.id];
    final weeklyOnly =
        shownHabit?.isNegative == true && selectedCount?.unit == 'weeks';
    final keptDays = days.where((d) => d.kept > 0).length;
    final calendarFinding = weeklyOnly
        ? selectedCount!.eligible == 0
              ? tr(
                  context,
                  'No finished weeks to count yet.',
                  'Chưa có tuần trọn để tính.',
                )
              : tr(
                  context,
                  '${selectedCount.kept} of ${selectedCount.eligible} weeks within your limit.',
                  'Giữ giới hạn ${selectedCount.kept}/${selectedCount.eligible} tuần.',
                )
        : tr(
            context,
            '$keptDays ${keptDays == 1 ? 'day' : 'days'} with a kept goal in this $kind.',
            '$keptDays ngày giữ được mục tiêu trong ${kind == 'year'
                ? 'năm'
                : kind == 'month'
                ? 'tháng'
                : 'tuần'} này.',
          );
    final calendar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(
          kind == 'year'
              ? tr(context, 'A year of small steps', 'Một năm từng bước nhỏ')
              : kind == 'month'
              ? tr(context, 'Your month, day by day', 'Từng ngày trong tháng')
              : tr(context, 'Your week, day by day', 'Từng ngày trong tuần'),
        ),
        DropdownButtonFormField<String>(
          key: const Key('progress-habit-filter'),
          initialValue: shownHabit?.id ?? '',
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr(context, 'Whose rhythm?', 'Nhịp thói quen nào?'),
          ),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(tr(context, 'All habits', 'Tất cả thói quen')),
            ),
            for (final h in habits)
              DropdownMenuItem(
                value: h.id,
                child: Text(h.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => habit = v == '' ? null : v),
        ),
        const SizedBox(height: 12),
        Text(
          calendarFinding,
          key: const Key('calendar-finding'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (kind == 'year')
          YearHeatmap(
            days: days,
            today: today,
            weekStart: s.weekStart,
            hue: hue,
            onDay: (d) => showDay(d, selected),
          )
        else
          ProgressCalendar(
            days: days,
            weekStart: s.weekStart,
            today: today,
            hue: hue,
            onDay: (d) => showDay(d, selected),
          ),
        const SizedBox(height: 12),
        Text(
          tr(
            context,
            'More colour means more goals kept. Hollow means unknown; grey means none kept, rest or later. Tap a date for details.',
            'Màu đậm hơn là giữ được nhiều mục tiêu hơn. Ô rỗng là chưa rõ; xám là chưa đạt, ngày nghỉ hoặc sắp tới. Chạm ngày để xem.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        if (selected.any((h) => h.negativeGoals.any((g) => g.window == 'week')))
          Text(
            tr(
              context,
              'A closed weekly limit shades all seven days of its week.',
              'Giới hạn tuần tô màu cả bảy ngày khi tuần đã hết.',
            ),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
    final habitRows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(tr(context, 'Each habit', 'Từng thói quen')),
        Text(
          tr(
            context,
            'Your streaks continue across pauses and unknown days.',
            'Ngày nghỉ và ngày chưa rõ không làm đứt chuỗi.',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        Capped(
          count: habits.length,
          max: 5,
          name: 'progress-habits',
          builder: (context, shown) => Column(
            children: [
              for (final h in habits.take(shown))
                _HabitProgress(scope: scope, habit: h, count: counts[h.id]!),
            ],
          ),
        ),
      ],
    );
    final routineRows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(tr(context, 'Routine completion', 'Hoàn thành quy trình')),
        Text(
          tr(
            context,
            '$finished finished of ${sessions.length} started.',
            'Xong $finished trên ${sessions.length} lần bắt đầu.',
          ),
          key: const Key('routine-finding'),
          style: theme.textTheme.titleMedium,
        ),
        if (sessions.isEmpty)
          Text(
            tr(
              context,
              'Your next routine run will appear here.',
              'Lần chạy quy trình tiếp theo sẽ xuất hiện ở đây.',
            ),
          ),
        Capped(
          count: routineIds.length,
          max: 5,
          name: 'progress-routines',
          builder: (context, shown) => Column(
            children: [
              for (final id in routineIds.take(shown))
                Builder(
                  builder: (context) {
                    final mine = sessions
                        .where((x) => x.routine == id)
                        .toList();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(mine.last.title),
                      subtitle: Text(
                        tr(
                          context,
                          '${mine.where((x) => x.status == 'finished').length} of ${mine.length} runs finished · ${minutesText(context, mine.fold(0, (n, x) => n + x.elapsed))} spent',
                          'Xong ${mine.where((x) => x.status == 'finished').length}/${mine.length} lần · đã chạy ${minutesText(context, mine.fold(0, (n, x) => n + x.elapsed))}',
                        ),
                      ),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/session/${mine.last.id}',
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
        16,
        MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
        40,
      ),
      children: [
        HandyContent(
          maxWidth: 1120,
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (id, en, vi) in const [
                      ('week', 'Week', 'Tuần'),
                      ('month', 'Month', 'Tháng'),
                      ('year', 'Year', 'Năm'),
                    ])
                      ChoiceChip(
                        key: Key('range-$id'),
                        selected: kind == id,
                        label: Text(tr(context, en, vi)),
                        onSelected: (_) => setState(() => kind = id),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      key: const Key('progress-prev'),
                      tooltip: tr(context, 'Previous period', 'Khoảng trước'),
                      onPressed: date(from).year > 1900 ? () => move(-1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${formatDay(context, from)} – ${formatDay(context, until)}',
                        key: const Key('insights-range'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      key: const Key('progress-next'),
                      tooltip: tr(context, 'Next period', 'Khoảng sau'),
                      onPressed: until.compareTo(today) < 0
                          ? () => move(1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12), summary,
                // At 1440: 1120 content = 548 + 24 + 548. Each block keeps its own height.
                if (constraints.maxWidth >= 900)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            calendar,
                            MoodHistory(scope: scope, from: from, until: until),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [habitRows, routineRows],
                        ),
                      ),
                    ],
                  )
                else ...[
                  calendar,
                  habitRows,
                  routineRows,
                  MoodHistory(scope: scope, from: from, until: until),
                ],
                HandyLabel(tr(context, 'Export this range', 'Xuất khoảng này')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (f, name) in const [
                      ('csv', 'CSV'),
                      ('md', 'Markdown'),
                      ('pdf', 'PDF'),
                    ])
                      OutlinedButton.icon(
                        key: Key('export-$f'),
                        onPressed: () => export(context, f),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: Text(name),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HabitProgress extends StatelessWidget {
  final HabitScope scope;
  final Habit habit;
  final ProgressCount count;
  const _HabitProgress({
    required this.scope,
    required this.habit,
    required this.count,
  });
  @override
  Widget build(BuildContext context) {
    final h = habit,
        m = metrics(habit, scope.today, scope.state.weekStart, scope.index);
    final unit = count.unit == 'goals'
        ? tr(context, 'goals', 'mục tiêu')
        : count.unit == 'weeks'
        ? tr(context, count.eligible == 1 ? 'week' : 'weeks', 'tuần')
        : tr(context, count.eligible == 1 ? 'day' : 'days', 'ngày');
    final streakUnit = m.unit == 'weeks'
        ? tr(context, 'weeks', 'tuần')
        : tr(context, 'days', 'ngày');
    return InkWell(
      key: Key('insight-${h.id}'),
      onTap: () => Navigator.pushNamed(context, '/habit/${h.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: habitMark(context, h),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    h.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              count.eligible == 0
                  ? tr(
                      context,
                      'No finished $unit to count yet.',
                      'Chưa có $unit hoàn tất để tính.',
                    )
                  : tr(
                      context,
                      '${count.kept} of ${count.eligible} $unit kept · ${formatFigure(context, (count.kept * 100 / count.eligible).round().toString())}% consistency',
                      'Giữ ${count.kept}/${count.eligible} $unit · đều đặn ${formatFigure(context, (count.kept * 100 / count.eligible).round().toString())}%',
                    ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontFeatures: tabular),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                context,
                'Current ${m.current} · best ${m.longest} $streakUnit',
                'Hiện tại ${m.current} · dài nhất ${m.longest} $streakUnit',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFeatures: tabular),
            ),
          ],
        ),
      ),
    );
  }
}
