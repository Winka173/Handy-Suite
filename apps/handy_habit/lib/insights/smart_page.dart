import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../pro/entitlements.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'smart_demo.dart';
import 'smart_review.dart';
import 'smart_report.dart';
import 'progress_calendar.dart';

class HabitSmartPage extends StatefulWidget {
  final HabitScope scope;
  const HabitSmartPage({super.key, required this.scope});
  @override
  State<HabitSmartPage> createState() => _HabitSmartPageState();
}

class _HabitSmartPageState extends State<HabitSmartPage> {
  String kind = 'month',
      collection = '',
      part = '',
      direction = '',
      outcome = '';
  int weekday = 0;
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

  @override
  Widget build(BuildContext context) {
    String t(String en, String vi) => tr(context, en, vi);
    final scope = widget.scope, pro = scope.pro(context);
    final s = pro ? scope.state : smartDemoState(),
        today = pro ? scope.today : smartDemoToday;
    final review = smartReview(context, s, today, kind);
    final from = addDays(today, -28), until = addDays(today, -1);
    final suggestions = [
      for (final h in s.liveHabits)
        if (goalSuggestion(s, h, today) case final g?) g,
    ];
    Widget evidence(ReviewSection section, {bool expanded = false}) =>
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 16),
          initiallyExpanded: expanded,
          title: Text(
            section.$1,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          children: [
            for (final line in section.$2.where((l) => l.isNotEmpty))
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line),
                ),
              ),
          ],
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
                Text(
                  t(
                    'Explore one local example. Core Progress stays free.',
                    'Khám phá một ví dụ tính trên máy. Tiến bộ cốt lõi luôn miễn phí.',
                  ),
                ),
              ],
              Text(
                t('One small adjustment.', 'Một điều chỉnh nhỏ.'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                t(
                  'Counts first. Suggestions stay yours to choose.',
                  'Số liệu rõ ràng. Gợi ý do bạn quyết định.',
                ),
              ),
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
              evidence(review.first, expanded: true),
              if (!pro) ...[
                Text(
                  t(
                    'Read: keep 9/10 at 6 pages — try 8?',
                    'Đọc: giữ 9/10 ở mức 6 trang — thử 8?',
                  ),
                ),
                Text(
                  t(
                    'A sample rule, never an automatic change. Pro adds your groups, weekday patterns, mood co-occurrence, filters and PDF reviews.',
                    'Quy tắc ví dụ, không tự đổi mục tiêu. Pro thêm nhóm, mẫu theo thứ, tâm trạng cùng xuất hiện, bộ lọc và PDF của bạn.',
                  ),
                ),
                FilledButton(
                  key: const Key('smart-get-pro'),
                  onPressed: () =>
                      openHabitPro(context, HabitProFeature.comparisons),
                  child: Text(t('Explore Pro', 'Khám phá Pro')),
                ),
              ] else ...[
                if (s.liveHabits.isEmpty)
                  Text(
                    t(
                      'Your first habit starts the story. No figure is estimated.',
                      'Thói quen đầu tiên bắt đầu câu chuyện. Không ước đoán số liệu.',
                    ),
                  ),
                Semantics(
                  header: true,
                  child: Text(
                    t('A goal to try', 'Mục tiêu để thử'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  t(
                    'After 10 comparable daily goals in the last 28 days: ≥9 kept suggests +25%; ≤5 suggests −25%, rounded to whole units (one minute for timers). Binary, reduction and weekly goals are excluded. Changes start tomorrow.',
                    'Sau 10 mục tiêu ngày tương đương trong 28 ngày qua: giữ ≥9 gợi ý +25%; ≤5 gợi ý −25%, làm tròn đơn vị (một phút cho bộ đếm). Bỏ mục tiêu có/không, giảm và theo tuần. Thay đổi từ ngày mai.',
                  ),
                ),
                if (suggestions.isEmpty)
                  Text(
                    t(
                      'No adjustment suggested right now.',
                      'Hiện chưa có gợi ý điều chỉnh.',
                    ),
                  ),
                for (final g in suggestions) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${scope.habit(g.habit)!.title}: ${g.kept}/${g.eligible} · ${figure(context, g.target)} ${t('to', 'thành')} ${figure(context, g.proposed)} ${unitOf(context, scope.habit(g.habit)!, value: g.proposed)}',
                    key: Key('goal-${g.habit}'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        key: Key('goal-accept-${g.habit}'),
                        onPressed: acting ? null : () => decide(g, true),
                        child: Text(t('Accept', 'Nhận')),
                      ),
                      TextButton(
                        key: Key('goal-dismiss-${g.habit}'),
                        onPressed: acting ? null : () => decide(g, false),
                        child: Text(t('Dismiss', 'Bỏ qua')),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                for (final section in review.skip(1)) evidence(section),
                const SizedBox(height: 16),
                Text(
                  t(
                    'Focused heatmap · last 28 days',
                    'Biểu đồ nhiệt · 28 ngày qua',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  t(
                    'Combine filters. Counts describe known goals on shown dates; weekly goals repeat their closed week result. Hollow cells mean unknown or no closed goal; missed cells stay neutral.',
                    'Kết hợp bộ lọc. Số liệu mô tả mục tiêu đã rõ ở ngày hiển thị; mục tiêu tuần lặp kết quả tuần đã hết. Ô rỗng là chưa rõ hoặc chưa có mục tiêu đã hết; ngày lỡ luôn trung tính.',
                  ),
                ),
                _filters(context, s),
                const SizedBox(height: 12),
                _heat(context, s, today, from, until),
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

  Widget _filters(BuildContext context, HabitState s) {
    String t(String en, String vi) => tr(context, en, vi);
    Widget choice(
      String id,
      String label,
      String value,
      Map<String, String> options,
      ValueChanged<String> set,
    ) => SizedBox(
      width: MediaQuery.textScalerOf(context).scale(210).clamp(210, 280),
      child: DropdownButtonFormField<String>(
        key: Key('smart-filter-$id-$value'),
        initialValue: options.containsKey(value) ? value : '',
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(
              value: e.key,
              child: Text(e.value, softWrap: true),
            ),
        ],
        onChanged: (v) => setState(() => set(v!)),
      ),
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        choice('collection', t('Collection', 'Nhóm'), collection, {
          '': t('All collections', 'Mọi nhóm'),
          for (final h in s.liveHabits)
            if (h.category.isNotEmpty) h.category: h.category,
        }, (v) => collection = v),
        choice('time', t('Time of day', 'Buổi'), part, {
          '': t('Any time', 'Mọi buổi'),
          for (final p in ['morning', 'afternoon', 'evening', 'anytime'])
            p: dayPartText(context, p),
        }, (v) => part = v),
        choice('direction', t('Direction', 'Hướng'), direction, {
          '': t('Build and reduce', 'Xây và giảm'),
          'build': t('Build', 'Xây'),
          'reduce': t('Reduce', 'Giảm'),
        }, (v) => direction = v),
        choice(
          'weekday',
          t('Weekday', 'Thứ'),
          weekday == 0 ? '' : '$weekday',
          {
            '': t('All weekdays', 'Mọi thứ'),
            for (var i = 1; i <= 7; i++) '$i': weekdayLong(context, i),
          },
          (v) => weekday = int.tryParse(v) ?? 0,
        ),
        choice('outcome', t('Recorded outcome', 'Kết quả'), outcome, {
          '': t('All outcomes', 'Mọi kết quả'),
          'kept': t('Kept', 'Đã giữ'),
          'missed': t('Missed', 'Đã lỡ'),
          'unknown': t('Unknown', 'Chưa rõ'),
        }, (v) => outcome = v),
        TextButton(
          onPressed: () => setState(() {
            collection = '';
            part = '';
            direction = '';
            outcome = '';
            weekday = 0;
          }),
          child: Text(t('Clear filters', 'Xóa bộ lọc')),
        ),
      ],
    );
  }

  Widget _heat(
    BuildContext context,
    HabitState s,
    String today,
    String from,
    String until,
  ) {
    final filter = InsightFilter(
      collection: collection,
      dayPart: part,
      direction: direction,
      outcome: outcome,
      weekday: weekday,
    );
    final days = filter.days(s, from, until, today),
        p = HabitPalette.of(context);
    if (days.isEmpty || filter.habits(s).isEmpty)
      return Text(
        tr(
          context,
          'No matching days. Try clearing a filter.',
          'Không có ngày phù hợp. Hãy xóa bớt bộ lọc.',
        ),
        key: const Key('smart-heat-empty'),
      );
    return Wrap(
      key: const Key('smart-heatmap'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in days)
          Semantics(
            label: heatDayLabel(context, d, today),
            excludeSemantics: true,
            child: Tooltip(
              message: heatDayLabel(context, d, today),
              child: Container(
                width: MediaQuery.textScalerOf(context).scale(74),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: d.kept > 0 ? p.tint : p.raised,
                  border: Border.all(color: d.unknown > 0 ? p.control : p.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(d.day.substring(5)),
                    Text(
                      d.eligible == 0 ? '—' : '${d.kept}/${d.eligible}',
                      style: TextStyle(color: p.ink),
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
