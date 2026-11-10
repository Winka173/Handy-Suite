import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../habits/habit_appearance.dart';
import '../pro/entitlements.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'smart_demo.dart';
import 'smart_review.dart';
import 'smart_report.dart';
import 'progress_calendar.dart';
import 'insight_dates.dart';
import 'insight_filters.dart';

class HabitSmartPage extends StatefulWidget {
  final HabitScope scope;
  const HabitSmartPage({super.key, required this.scope});
  @override
  State<HabitSmartPage> createState() => _HabitSmartPageState();
}

class _HabitSmartPageState extends State<HabitSmartPage> {
  String kind = 'month';
  InsightFilter filter = const InsightFilter();
  bool acting = false;
  Future<void> decide(GoalSuggestion g, bool accept) async {
    if (!widget.scope.pro(context) || acting) return;
    if (accept &&
        !await confirmHandy(
          context,
          title: tr(
            context,
            'Try this goal from tomorrow?',
            'Thử mục tiêu này từ ngày mai?',
          ),
          message: tr(
            context,
            'Past targets and history stay as recorded. You can change the new goal in the habit editor.',
            'Mục tiêu và lịch sử đã qua giữ nguyên. Bạn có thể sửa mục tiêu mới trong trình sửa thói quen.',
          ),
          confirmLabel: tr(context, 'Accept goal', 'Nhận mục tiêu'),
        ))
      return;
    if (!mounted) return;
    setState(() => acting = true);
    await widget.scope.write(
      context,
      (s) {
        if (!widget.scope.pro(context))
          throw StateError('Pro required / Cần Pro');
        return decideGoal(s, g, widget.scope.today, accept: accept);
      },
      done: (c) => tr(
        c,
        accept ? 'New goal starts tomorrow.' : 'Suggestion dismissed.',
        accept ? 'Mục tiêu mới bắt đầu từ ngày mai.' : 'Đã bỏ qua gợi ý.',
      ),
    );
    if (mounted) setState(() => acting = false);
  }

  Future<void> method(int i) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (c) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(c, 'How is this counted?', 'Số này được tính thế nào?'),
            style: Theme.of(c).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(insightMethods(c)[i]),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(c, 'Done', 'Xong')),
          ),
        ],
      ),
    ),
  );
  Widget how(int i) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton(
      key: Key('smart-method-$i'),
      onPressed: () => method(i),
      child: Text(
        tr(context, 'How is this counted?', 'Số này được tính thế nào?'),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    String t(String en, String vi) => tr(context, en, vi);
    final scope = widget.scope, pro = scope.pro(context);
    final s = pro ? scope.state : smartDemoState(),
        today = pro ? scope.today : smartDemoToday;
    final review = smartReview(context, s, today, kind);
    Widget evidence(int i) => Padding(
      key: Key('smart-section-$i'),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              review[i].$1,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          for (var j = 0; j < review[i].$2.length; j++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                review[i].$2[j],
                style: i == 4 && j == review[i].$2.length - 1
                    ? Theme.of(context).textTheme.bodySmall
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          how(
            i == 2
                ? 1
                : i > 2
                ? i - 1
                : i,
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(t('Smart insights', 'Phân tích'))),
      body: SingleChildScrollView(
        key: const Key('smart-scroll'),
        padding: const EdgeInsets.all(16),
        child: HandyContent(
          maxWidth: 1000,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!pro) ...[
                Text(
                  t(
                    'Example history · not your data',
                    'Lịch sử ví dụ · không phải dữ liệu của bạn',
                  ),
                  key: const Key('smart-demo-label'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const HabitProBadge(feature: HabitProFeature.comparisons),
              ],
              Wrap(
                spacing: 8,
                children: [
                  for (final (id, en, vi) in [
                    ('month', 'Month', 'Tháng'),
                    ('quarter', 'Quarter', 'Quý'),
                  ])
                    ChoiceChip(
                      key: Key('smart-$id'),
                      label: Text(t(en, vi)),
                      selected: kind == id,
                      onSelected: (_) => setState(() => kind = id),
                    ),
                ],
              ),
              evidence(0),
              if (!pro) ...[
                Text(
                  t(
                    'Try 8 pages a day? You kept 9 of the last 10 days at 6.',
                    'Thử 8 trang mỗi ngày? Bạn giữ 9 trong 10 ngày gần nhất ở mức 6.',
                  ),
                ),
                FilledButton(
                  key: const Key('smart-get-pro'),
                  onPressed: () =>
                      openHabitPro(context, HabitProFeature.comparisons),
                  child: Text(t('Explore Pro', 'Khám phá Pro')),
                ),
              ] else ...[
                const Divider(),
                Padding(
                  key: const Key('smart-goals'),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t('A goal to try', 'Mục tiêu để thử'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (![
                        for (final h in s.liveHabits)
                          goalSuggestion(s, h, today),
                      ].any((g) => g != null))
                        Text(
                          t(
                            'No adjustment suggested right now.',
                            'Hiện chưa có gợi ý điều chỉnh.',
                          ),
                        ),
                      for (final h in s.liveHabits)
                        if (goalSuggestion(s, h, today) case final g?) ...[
                          Text(
                            t(
                              'Try ${figure(context, g.proposed)} ${unitOf(context, h, value: g.proposed)} a day for ${h.title}? You kept ${g.kept} of the last ${g.eligible} days at ${figure(context, g.target)}.',
                              'Thử ${figure(context, g.proposed)} ${unitOf(context, h, value: g.proposed)} mỗi ngày cho ${h.title}? Bạn giữ ${g.kept} trong ${g.eligible} ngày gần nhất ở mức ${figure(context, g.target)}.',
                            ),
                            key: Key('goal-${g.habit}'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                key: Key('goal-accept-${g.habit}'),
                                onPressed: acting
                                    ? null
                                    : () => decide(g, true),
                                child: Text(t('Accept', 'Nhận')),
                              ),
                              TextButton(
                                key: Key('goal-dismiss-${g.habit}'),
                                onPressed: acting
                                    ? null
                                    : () => decide(g, false),
                                child: Text(t('Not now', 'Để sau')),
                              ),
                            ],
                          ),
                          Text(
                            t(
                              'Changes start tomorrow.',
                              'Thay đổi từ ngày mai.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      how(4),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, box) {
                    if (box.maxWidth < 760)
                      return Column(
                        children: [
                          for (var i = 1; i < review.length; i++) ...[
                            const Divider(),
                            evidence(i),
                          ],
                        ],
                      );
                    return Column(
                      children: [
                        for (var i = 1; i < review.length; i += 2) ...[
                          const Divider(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: evidence(i)),
                              const SizedBox(width: 32),
                              Expanded(child: evidence(i + 1)),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const Divider(),
                const SizedBox(height: 20),
                Text(
                  t(
                    'Find your rhythm, one day at a time.',
                    'Nhìn nhịp sống qua từng ngày.',
                  ),
                  key: const Key('smart-heat-title'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  insightDates(
                    context,
                    addDays(today, -28),
                    addDays(today, -1),
                  ),
                ),
                const SizedBox(height: 12),
                InsightFilters(
                  state: s,
                  value: filter,
                  onChanged: (v) => setState(() => filter = v),
                ),
                const SizedBox(height: 12),
                _heat(context, s, today),
                how(5),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: const Key('smart-report'),
                  icon: const Icon(Icons.description_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SmartReportPage(
                        scope: scope,
                        sections: review,
                        today: today,
                      ),
                    ),
                  ),
                  label: Text(
                    t('Preview PDF review', 'Xem trước bản nhìn lại PDF'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heat(BuildContext context, HabitState s, String today) {
    final from = addDays(today, -28), until = addDays(today, -1);
    final days = filter.days(s, from, until, today),
        habits = filter.habits(s),
        index = HabitIndex.of(s);
    if (days.isEmpty || habits.isEmpty)
      return Text(
        tr(
          context,
          'No matching days. Try clearing a filter.',
          'Không có ngày phù hợp. Hãy xóa bớt bộ lọc.',
        ),
        key: const Key('smart-heat-empty'),
      );
    return Column(
      key: const Key('smart-heatmap'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, '${days.length} days shown', 'Hiện ${days.length} ngày'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            for (final h in habits)
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      h.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 36,
                          child: Column(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.textScalerOf(context).scale(14) +
                                    12,
                              ),
                              for (var i = 0; i < 7; i++)
                                SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: Text(
                                      weekdayShort(
                                        context,
                                        (s.weekStart + i - 1) % 7 + 1,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: YearHeatmap(
                            days: progressDays([h], from, until, today, index),
                            today: today,
                            weekStart: s.weekStart,
                            hue: habitMark(context, h),
                            visibleDays: days.map((d) => d.day).toSet(),
                            cellKeyPrefix: 'smart-cell-${h.id}',
                            onDay: (cell) => showModalBottomSheet<void>(
                              context: context,
                              useSafeArea: true,
                              constraints: const BoxConstraints(maxWidth: 560),
                              builder: (c) => Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      h.title,
                                      style: Theme.of(c).textTheme.titleLarge,
                                    ),
                                    Text(heatDayLabel(c, cell, today)),
                                    Text(
                                      tr(
                                        c,
                                        '${cell.kept} kept · ${cell.eligible} known goals · ${cell.unknown} unknown',
                                        '${cell.kept} đã giữ · ${cell.eligible} mục tiêu đã rõ · ${cell.unknown} chưa rõ',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: Text(tr(c, 'Done', 'Xong')),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            context,
            'Colour: kept · Neutral: not kept · Hollow: unknown · Tap for details',
            'Màu: đã giữ · Trung tính: chưa giữ · Rỗng: chưa rõ · Chạm để xem',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
