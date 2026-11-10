import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../settings/data.dart';
import '../ui/form.dart';
import '../ui/words.dart';
import 'week_review.dart';

/// What actually happened over a range: days with any check-in each week,
/// each habit as done out of planned (never a score), and routine runs.
class InsightsPage extends StatelessWidget {
  final HabitScope scope;
  const InsightsPage({super.key, required this.scope});

  (String, String) range() {
    final s = scope.state, today = scope.today;
    final until = s.settings['reportUntil'] as String? ?? today;
    return (
      s.settings['reportFrom'] as String? ?? addDays(today, -29),
      until.compareTo(today) > 0 ? today : until,
    );
  }

  Future<void> setRange(BuildContext context, String from, String until) =>
      scope.write(
        context,
        (s) => s.copy({
          'settings': {...s.settings, 'reportFrom': from, 'reportUntil': until},
        }),
        remember: false,
      );

  Future<void> custom(BuildContext context) {
    final (from, until) = range();
    return showHabitForm(
      context,
      title: tr(context, 'Range', 'Khoảng ngày'),
      saveLabel: tr(context, 'Show', 'Xem'),
      fields: const [
        HabitField('from', 'From', 'Từ ngày', kind: FieldKind.date),
        HabitField('until', 'To', 'Đến hết ngày', kind: FieldKind.date),
      ],
      initial: {'from': from, 'until': until},
      save: (v) async {
        final a = v['from'] as String, b = v['until'] as String;
        if (b.compareTo(a) < 0 || b.compareTo(scope.today) > 0)
          throw const FormatException(
            'Choose a range that has passed / Chọn khoảng ngày đã qua',
          );
        await scope.controller.change(
          (s) => s.copy({
            'settings': {...s.settings, 'reportFrom': a, 'reportUntil': b},
          }),
          remember: false,
        );
      },
    );
  }

  Future<void> export(BuildContext context, String format) async {
    final (from, until) = range();
    try {
      final message = await exportHabits(
        context,
        scope,
        format,
        from: from,
        until: until,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final s = scope.state, today = scope.today;
    final (from, until) = range();
    final span = date(until).difference(date(from)).inDays + 1;
    final index = scope.index;
    final habits = s.habits
        .where((h) => h.created.compareTo(until) <= 0)
        .toList();
    final sessions = s.sessions
        .where((x) => x.day.compareTo(from) >= 0 && x.day.compareTo(until) <= 0)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        HandySpace.l,
        HandySpace.l,
        HandySpace.xxl,
      ),
      children: [
        HandyContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  '${formatDay(context, from)} – ${formatDay(context, until)}',
                  key: const Key('insights-range'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: HandySpace.s),
              Wrap(
                spacing: HandySpace.s,
                runSpacing: HandySpace.s,
                children: [
                  for (final d in [7, 30, 90])
                    ChoiceChip(
                      key: Key('range-$d'),
                      label: Text(tr(context, '$d days', '$d ngày')),
                      selected: until == today && span == d,
                      onSelected: (_) =>
                          setRange(context, addDays(today, -(d - 1)), today),
                    ),
                  ChoiceChip(
                    key: const Key('range-custom'),
                    label: Text(tr(context, 'Other…', 'Khác…')),
                    selected: !(until == today && [7, 30, 90].contains(span)),
                    onSelected: (_) => custom(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: HandySpace.m),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: const Key('insights-week-review'),
                    onPressed: () => openWeekReview(context, scope),
                    icon: const Icon(Icons.event_note_outlined),
                    label: Text(
                      tr(context, 'Look back at the week', 'Nhìn lại tuần'),
                    ),
                  ),
                ),
              ),
              HandyLabel(
                tr(
                  context,
                  'Days with a check-in, each week',
                  'Số ngày có ghi nhận mỗi tuần',
                ),
              ),
              _Weeks(scope: scope, from: from, until: until),
              HandySection(
                title: tr(context, 'Each habit', 'Từng thói quen'),
                children: [
                  if (habits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(HandySpace.l),
                      child: Text(
                        tr(
                          context,
                          'No habit in this range.',
                          'Không có thói quen trong khoảng này.',
                        ),
                      ),
                    ),
                  for (final h in habits)
                    Builder(
                      builder: (context) {
                        final m = metrics(
                          h,
                          until,
                          s.weekStart,
                          index,
                          from: from,
                        );
                        final unit = m.unit == 'weeks'
                            ? tr(context, 'weeks', 'tuần')
                            : tr(context, 'days', 'ngày');
                        return InkWell(
                          key: Key('insight-${h.id}'),
                          onTap: () =>
                              Navigator.pushNamed(context, '/habit/${h.id}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: HandySpace.l,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    HandyDot(scope.habitHue(h.id), size: 8),
                                    const SizedBox(width: HandySpace.s),
                                    Expanded(
                                      child: Text(
                                        h.title,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      tr(
                                        context,
                                        '${m.completed} of ${m.eligible} $unit',
                                        '${m.completed}/${m.eligible} $unit',
                                      ),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontFeatures: tabular),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: SizedBox(
                                    height: 3,
                                    child: Stack(
                                      children: [
                                        Container(color: c.raised),
                                        FractionallySizedBox(
                                          widthFactor: m.eligible == 0
                                              ? 0
                                              : m.completed / m.eligible,
                                          child: Container(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: .7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tr(
                                    context,
                                    'Running ${m.current} · longest ${m.longest} $unit',
                                    'Chuỗi ${m.current} · dài nhất ${m.longest} $unit',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: c.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              HandySection(
                title: tr(context, 'Routine runs', 'Các lần chạy quy trình'),
                children: [
                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(HandySpace.l),
                      child: Text(
                        tr(
                          context,
                          'No runs in this range.',
                          'Không có lần chạy nào trong khoảng này.',
                        ),
                      ),
                    ),
                  for (final r in s.routines.where(
                    (r) => sessions.any((x) => x.routine == r.id),
                  ))
                    Builder(
                      builder: (context) {
                        final mine = sessions
                            .where((x) => x.routine == r.id)
                            .toList();
                        final finished = mine
                            .where((x) => x.status == 'finished')
                            .length;
                        return ListTile(
                          title: Text(r.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(
                                  context,
                                  '$finished finished of ${mine.length} started',
                                  'Xong $finished trên ${mine.length} lần bắt đầu',
                                ),
                              ),
                              Text(
                                tr(
                                  context,
                                  '${minutesText(context, mine.fold(0, (v, x) => v + x.elapsed))} spent · ${minutesText(context, mine.fold(0, (v, x) => v + x.planned))} planned',
                                  'Đã chạy ${minutesText(context, mine.fold(0, (v, x) => v + x.elapsed))} · dự kiến ${minutesText(context, mine.fold(0, (v, x) => v + x.planned))}',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFeatures: tabular,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: HandySpace.m),
                child: Text(
                  tr(
                    context,
                    'Skipped days are neither done nor missed. A days-a-week habit counts whole weeks; the week still open is left out until it is done.',
                    'Ngày bỏ qua không tính là xong hay lỡ. Thói quen theo số ngày mỗi tuần tính theo tuần trọn; tuần đang mở chỉ được tính khi đã đủ.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                ),
              ),
              HandyLabel(tr(context, 'Export this range', 'Xuất khoảng này')),
              Wrap(
                spacing: HandySpace.s,
                runSpacing: HandySpace.s,
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
      ],
    );
  }
}

/// Days with any check-in in each week of the range, out of seven; the
/// current week in the app's hue.
class _Weeks extends StatelessWidget {
  final HabitScope scope;
  final String from, until;
  const _Weeks({required this.scope, required this.from, required this.until});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final s = scope.state;
    final days = <String, Set<String>>{};
    for (final e in s.events) {
      if (e.value <= 0 ||
          e.day.compareTo(from) < 0 ||
          e.day.compareTo(until) > 0)
        continue;
      days.putIfAbsent(weekOf(e.day, s.weekStart), () => {}).add(e.day);
    }
    final weeks = <String>[];
    for (
      var w = weekOf(from, s.weekStart);
      w.compareTo(until) <= 0;
      w = addDays(w, 7)
    ) {
      weeks.add(w);
    }
    final shown = weeks.length > 26 ? weeks.sublist(weeks.length - 26) : weeks;
    final current = weekOf(scope.today, s.weekStart);
    final labelHeight = MediaQuery.textScalerOf(context).scale(12) * 1.4 + 4;
    final stride = (shown.length / 4).ceil().clamp(1, 26);
    return Semantics(
      label: [
        for (final w in shown)
          '${formatDay(context, w)}: ${days[w]?.length ?? 0}/7',
      ].join('; '),
      excludeSemantics: true,
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: HandySpace.s,
                bottom: labelHeight + 5,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '7',
                    style: theme.textTheme.labelSmall?.copyWith(color: c.muted),
                  ),
                  Text(
                    '0',
                    style: theme.textTheme.labelSmall?.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            for (final w in shown)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: (days[w]?.length ?? 0) / 7,
                            child: Container(
                              decoration: BoxDecoration(
                                color: w == current
                                    ? c.accent
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: .22,
                                      ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(height: 1, color: c.border),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: labelHeight,
                        child:
                            shown.indexOf(w) == 0 ||
                                shown.indexOf(w) == shown.length - 1 ||
                                shown.indexOf(w) % stride == 0 &&
                                    shown.indexOf(w) < shown.length - stride
                            ? OverflowBox(
                                minWidth: 0,
                                maxWidth: MediaQuery.textScalerOf(
                                  context,
                                ).scale(90),
                                alignment: shown.indexOf(w) == 0
                                    ? Alignment.centerLeft
                                    : shown.indexOf(w) == shown.length - 1
                                    ? Alignment.centerRight
                                    : Alignment.center,
                                child: Text(
                                  '${date(w).day}/${date(w).month}',
                                  textAlign: shown.indexOf(w) == 0
                                      ? TextAlign.start
                                      : shown.indexOf(w) == shown.length - 1
                                      ? TextAlign.end
                                      : TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: c.muted,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
