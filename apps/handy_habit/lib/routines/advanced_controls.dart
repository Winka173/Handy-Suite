import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/words.dart';
import '../pro/entitlements.dart';

/// Human-readable saved rules are also visible after an entitlement expires.
String logicDescription(BuildContext context, RoutineStep step) {
  final r = step.logic;
  return [
    if (r.weekdays.isNotEmpty)
      r.weekdays.map((d) => weekdayShort(context, d)).join(', '),
    if (r.habitNotDone != null)
      tr(context, 'Only if habit is unfinished', 'Chỉ khi thói quen chưa xong'),
    if (r.minimumRemaining > 0)
      tr(
        context,
        'At least ${r.minimumRemaining ~/ 60} min left',
        'Còn ít nhất ${r.minimumRemaining ~/ 60} phút',
      ),
    if (r.branch.isNotEmpty) '${r.branch} · ${r.option}',
    if (r.dependencies.isNotEmpty)
      tr(
        context,
        '${r.dependencies.length} prerequisites',
        '${r.dependencies.length} bước cần xong trước',
      ),
    if (r.stackAfter != null)
      tr(context, 'After the linked habit', 'Sau thói quen liên kết'),
    if (r.durations.isNotEmpty)
      tr(context, 'Duration varies by day', 'Thời lượng theo ngày'),
    if (r.block.isNotEmpty)
      tr(context, 'From a saved block', 'Từ nhóm bước đã lưu'),
  ].join(' · ');
}

class AdvancedPanel extends StatelessWidget {
  final bool pro;
  final String title, help;
  final List<Widget> children;
  final HabitProFeature feature;
  const AdvancedPanel({
    super.key,
    required this.pro,
    required this.title,
    required this.help,
    required this.children,
    required this.feature,
  });
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(title)),
        if (!pro) const SizedBox(width: 8),
        if (!pro) HabitProBadge(feature: feature),
      ],
    ),
    subtitle: Text(help),
    children: pro ? children : [const LogicDemo()],
  );
}

/// A working local example, never a draft mutation or fake entitlement switch.
class LogicDemo extends StatefulWidget {
  const LogicDemo({super.key});
  @override
  State<LogicDemo> createState() => _LogicDemoState();
}

class _LogicDemoState extends State<LogicDemo> {
  bool saturday = true;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'Demo: a weekday-only walk',
            'Ví dụ: đi bộ vào ngày trong tuần',
          ),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final value in [false, true])
              ChoiceChip(
                label: Text(weekdayLong(context, value ? 6 : 1)),
                selected: saturday == value,
                onSelected: (_) => setState(() => saturday = value),
              ),
          ],
        ),
        Text(
          saturday
              ? tr(
                  context,
                  "Skipped: it's Saturday",
                  'Bỏ qua: hôm nay là thứ Bảy',
                )
              : tr(
                  context,
                  'Ready: walk for 10 minutes',
                  'Sẵn sàng: đi bộ 10 phút',
                ),
        ),
        Text(
          tr(
            context,
            'Pro is needed to create or edit rules. Saved routines keep running for everyone.',
            'Cần Pro để tạo hoặc sửa quy tắc. Mọi người vẫn chạy được quy trình đã lưu.',
          ),
        ),
      ],
    ),
  );
}

class AdvancedStepControls extends StatefulWidget {
  final HabitScope scope;
  final RoutineStep? old;
  final List<RoutineStep> prior;
  final Map<String, dynamic> values;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const AdvancedStepControls({
    super.key,
    required this.scope,
    required this.old,
    required this.prior,
    required this.values,
    required this.onChanged,
  });
  @override
  State<AdvancedStepControls> createState() => _AdvancedStepControlsState();
}

class _AdvancedStepControlsState extends State<AdvancedStepControls> {
  bool advanced = false;
  StepLogic get rule => StepLogic.fromJson(
    Map<String, dynamic>.from(widget.values['logic'] as Map),
  );
  void patch(Map<String, dynamic> changes) {
    if (!widget.scope.pro(context)) return;
    widget.onChanged({
      'logic': {...rule.toJson(), ...changes},
    });
  }

  Future<void> form(
    List<HabitField> fields,
    Map<String, dynamic> initial,
    void Function(Map<String, dynamic>) save,
  ) async {
    await showHabitForm(
      context,
      title: tr(context, 'Step rule', 'Quy tắc bước'),
      fields: fields,
      initial: initial,
      save: (v) async {
        if (widget.scope.pro(context)) save(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pro = widget.scope.pro(context), r = rule;
    final prior = {for (final s in widget.prior) s.id: s.title};
    Widget panel(
      String en,
      String vi,
      String helpEn,
      String helpVi,
      List<Widget> children,
    ) => AdvancedPanel(
      feature: switch (en) {
        'Days to run' => HabitProFeature.days,
        'Unfinished habit' => HabitProFeature.unfinished,
        'Time left' => HabitProFeature.timeLeft,
        'Choose A or B' => HabitProFeature.choices,
        'Dependencies' => HabitProFeature.dependencies,
        'After a habit' => HabitProFeature.stacking,
        _ => HabitProFeature.durations,
      },
      pro: pro,
      title: tr(context, en, vi),
      help: tr(context, helpEn, helpVi),
      children: children,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          key: const Key('step-advanced'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'Advanced mode', 'Chế độ nâng cao')),
          subtitle: Text(
            tr(
              context,
              'Optional rules for this step. Basic stays simple.',
              'Quy tắc tùy chọn cho bước này. Cơ bản luôn đơn giản.',
            ),
          ),
          value: advanced,
          onChanged: (v) => setState(() => advanced = v),
        ),
        HandyReveal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (advanced) ...[
                panel(
                  'Days to run',
                  'Ngày thực hiện',
                  'Run only on the days you choose; no selection means every day.',
                  'Chỉ chạy vào ngày bạn chọn; để trống nghĩa là mỗi ngày.',
                  [
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          FilterChip(
                            key: Key('logic-weekday-$d'),
                            label: Text(weekdayShort(context, d)),
                            tooltip: weekdayLong(context, d),
                            selected: r.weekdays.contains(d),
                            onSelected: (on) => patch({
                              'weekdays':
                                  (on
                                        ? [...r.weekdays, d]
                                        : r.weekdays
                                              .where((x) => x != d)
                                              .toList())
                                    ..sort(),
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
                panel(
                  'Unfinished habit',
                  'Thói quen chưa xong',
                  'Skip when the chosen habit has already reached its target.',
                  'Bỏ qua khi thói quen đã chọn đã đạt mục tiêu.',
                  [
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(tr(context, 'Always', 'Luôn thực hiện')),
                          selected: r.habitNotDone == null,
                          onSelected: (_) => patch({'habitNotDone': null}),
                        ),
                        for (final h in widget.scope.state.liveHabits.where(
                          (h) => !h.isNegative && !h.archived,
                        ))
                          ChoiceChip(
                            label: Text(h.title),
                            selected: r.habitNotDone == h.id,
                            onSelected: (_) => patch({'habitNotDone': h.id}),
                          ),
                      ],
                    ),
                  ],
                ),
                panel(
                  'Time left',
                  'Thời gian còn lại',
                  'Run only if the session budget has enough minutes remaining.',
                  'Chỉ chạy nếu thời gian dự kiến của phiên còn đủ số phút.',
                  [
                    TextButton(
                      key: const Key('logic-time'),
                      onPressed: () => form(
                        [
                          const HabitField(
                            'minutes',
                            'Minimum minutes left',
                            'Số phút còn lại tối thiểu',
                            kind: FieldKind.count,
                          ),
                        ],
                        {'minutes': r.minimumRemaining ~/ 60},
                        (v) {
                          final n = v['minutes'] as int;
                          if (n < 0 || n > 1440)
                            throw const FormatException('0–1440 minutes');
                          patch({'minimumRemaining': n * 60});
                        },
                      ),
                      child: Text(
                        tr(
                          context,
                          '${r.minimumRemaining ~/ 60} min · Change',
                          '${r.minimumRemaining ~/ 60} phút · Đổi',
                        ),
                      ),
                    ),
                  ],
                ),
                panel(
                  'Choose A or B',
                  'Chọn A hoặc B',
                  'Steps with the same choice name form two alternative paths.',
                  'Các bước cùng tên lựa chọn tạo thành hai nhánh thay thế.',
                  [
                    TextButton(
                      key: const Key('logic-branch'),
                      onPressed: () => form(
                        [
                          const HabitField(
                            'branch',
                            'Choice name (empty to remove)',
                            'Tên lựa chọn (để trống để bỏ)',
                            required: false,
                          ),
                          HabitField(
                            'option',
                            'Path',
                            'Nhánh',
                            kind: FieldKind.choice,
                            options: {
                              'A': tr(context, 'A', 'A'),
                              'B': tr(context, 'B', 'B'),
                            },
                          ),
                        ],
                        {
                          'branch': r.branch,
                          'option': r.option.isEmpty ? 'A' : r.option,
                        },
                        (v) => patch({
                          'branch': v['branch'],
                          'option': (v['branch'] as String).isEmpty
                              ? ''
                              : v['option'],
                        }),
                      ),
                      child: Text(
                        r.branch.isEmpty
                            ? tr(context, 'Add a choice', 'Thêm lựa chọn')
                            : '${r.branch} · ${r.option}',
                      ),
                    ),
                    Text(
                      tr(
                        context,
                        'Add at least one step to each path before saving the routine.',
                        'Thêm ít nhất một bước cho mỗi nhánh trước khi lưu quy trình.',
                      ),
                    ),
                  ],
                ),
                panel(
                  'Dependencies',
                  'Bước cần xong trước',
                  'Skip this step unless all chosen earlier steps were completed.',
                  'Bỏ qua bước này nếu các bước trước đã chọn chưa hoàn thành.',
                  [
                    if (prior.isEmpty)
                      Text(
                        tr(
                          context,
                          'Add an earlier step first.',
                          'Hãy thêm bước trước đó.',
                        ),
                      ),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final e in prior.entries)
                          FilterChip(
                            label: Text(e.value),
                            selected: r.dependencies.contains(e.key),
                            onSelected: (on) => patch({
                              'dependencies': on
                                  ? [...r.dependencies, e.key]
                                  : r.dependencies
                                        .where((x) => x != e.key)
                                        .toList(),
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
                panel(
                  'After a habit',
                  'Sau một thói quen',
                  'After a linked habit step, prompt this next action.',
                  'Sau bước có liên kết thói quen, nhắc hành động tiếp theo.',
                  [
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(
                            tr(context, 'No stack', 'Không nối bước'),
                          ),
                          selected: r.stackAfter == null,
                          onSelected: (_) => patch({'stackAfter': null}),
                        ),
                        for (final s in widget.prior.where(
                          (s) => s.habit != null,
                        ))
                          ChoiceChip(
                            label: Text(s.title),
                            selected: r.stackAfter == s.id,
                            onSelected: (_) => patch({'stackAfter': s.id}),
                          ),
                      ],
                    ),
                  ],
                ),
                panel(
                  'Duration by day',
                  'Thời lượng theo ngày',
                  'Use a different duration on selected weekdays; other days keep the basic duration.',
                  'Đổi thời lượng theo ngày; ngày khác giữ thời lượng cơ bản.',
                  [
                    for (final e in r.durations.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${weekdayLong(context, e.key)} · ${minutesText(context, e.value)}',
                        ),
                        trailing: IconButton(
                          tooltip: tr(
                            context,
                            'Remove override',
                            'Bỏ thời lượng riêng',
                          ),
                          icon: const Icon(Icons.close),
                          onPressed: () => patch({
                            'durations': {...r.toJson()['durations'] as Map}
                              ..remove('${e.key}'),
                          }),
                        ),
                      ),
                    TextButton(
                      key: const Key('logic-duration'),
                      onPressed: () => form(
                        [
                          HabitField(
                            'day',
                            'Weekday',
                            'Ngày trong tuần',
                            kind: FieldKind.choice,
                            options: {
                              for (var d = 1; d <= 7; d++)
                                '$d': weekdayLong(context, d),
                            },
                          ),
                          const HabitField(
                            'minutes',
                            'Minutes',
                            'Phút',
                            kind: FieldKind.amount,
                          ),
                        ],
                        {'day': '1', 'minutes': 5000},
                        (v) {
                          final secs = ((v['minutes'] as int) * 60 / 1000)
                              .round();
                          integer(secs, max: 86400);
                          patch({
                            'durations': {
                              ...r.toJson()['durations'] as Map,
                              v['day']: secs,
                            },
                          });
                        },
                      ),
                      child: Text(
                        tr(
                          context,
                          'Set a weekday duration',
                          'Đặt thời lượng cho một ngày',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
