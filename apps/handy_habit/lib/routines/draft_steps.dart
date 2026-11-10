import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'routine_editor.dart';
import 'advanced_controls.dart';
import 'advanced_library.dart';
import '../pro/entitlements.dart';

/// Structured edits stay inside HabitForm's draft until its single Save.
class DraftSteps extends StatefulWidget {
  final HabitScope scope;
  final Map<String, dynamic> values;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool templates;
  const DraftSteps({
    super.key,
    required this.scope,
    required this.values,
    required this.onChanged,
    required this.templates,
  });
  @override
  State<DraftSteps> createState() => _DraftStepsState();
}

class _DraftStepsState extends State<DraftSteps> {
  HabitScope get scope => widget.scope;
  Map<String, dynamic> get values => widget.values;
  ValueChanged<Map<String, dynamic>> get onChanged => widget.onChanged;
  bool get templates => widget.templates;
  bool advanced = false;

  List<RoutineStep> get steps => [
    for (final v in values['steps'] as List)
      RoutineStep.fromJson(Map<String, dynamic>.from(v as Map)),
  ];
  void update(List<RoutineStep> next) => onChanged({
    'steps': [for (final s in next) s.toJson()],
  });
  Future<void> edit(BuildContext context, [int? index]) async {
    final result = await editRoutineStep(
      context,
      scope,
      index == null ? null : steps[index],
      index == null ? steps : steps.take(index).toList(),
    );
    if (result == null || !context.mounted) return;
    final next = steps;
    index == null ? next.add(result) : next[index] = result;
    update(next);
  }

  void move(int from, int to) {
    final next = steps;
    next.insert(to, next.removeAt(from));
    update(next);
  }

  @override
  Widget build(BuildContext context) {
    final items = steps;
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (templates && items.isEmpty)
          ExpansionTile(
            key: const Key('routine-starters'),
            tilePadding: EdgeInsets.zero,
            title: Text(tr(context, 'Start from a template', 'Bắt đầu từ mẫu')),
            children: [
              for (final r in routineTemplates(vietnamese: isVi(context)))
                ListTile(
                  key: Key('draft-template-${r.title}'),
                  title: Text(r.title),
                  subtitle: Text(r.steps.map((s) => s.title).join(' · ')),
                  onTap: () => onChanged({
                    'title': r.title,
                    'steps': [for (final s in r.steps) s.toJson()],
                  }),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: HandySpace.m),
          child: Text(
            tr(
              context,
              '${items.length} ${items.length == 1 ? 'step' : 'steps'} · ${minutesText(context, items.fold(0, (n, s) => n + s.seconds))}',
              '${items.length} bước · ${minutesText(context, items.fold(0, (n, s) => n + s.seconds))}',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        DurationStrip(steps: items, color: c.accent),
        SwitchListTile.adaptive(
          key: const Key('routine-advanced'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'Advanced mode', 'Chế độ nâng cao')),
          subtitle: Text(
            tr(
              context,
              'Conditions, choices and reusable plans. Basic is the default.',
              'Điều kiện, lựa chọn và phương án dùng lại. Mặc định là Cơ bản.',
            ),
          ),
          value: advanced,
          onChanged: (v) => setState(() => advanced = v),
        ),
        if (advanced)
          TextButton(
            key: const Key('builder-learn-pro'),
            onPressed: () => openHabitPro(context),
            child: Text(tr(context, 'Learn about Pro', 'Tìm hiểu Pro')),
          ),
        if (advanced)
          HandyReveal(
            child: AdvancedRoutineLibrary(
              scope: scope,
              values: values,
              onChanged: onChanged,
            ),
          ),
        const SizedBox(height: HandySpace.m),
        if (items.isEmpty)
          Text(tr(context, 'Add your first step.', 'Thêm bước đầu tiên.')),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorderItem: move,
          itemBuilder: (context, i) {
            final step = items[i];
            final h = scope.habit(step.habit);
            return HandyAppear(
              key: ValueKey(step.id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: HandySpace.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.drag_indicator,
                              semanticLabel: tr(
                                context,
                                'Drag ${step.title}',
                                'Kéo ${step.title}',
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            key: Key('draft-edit-${step.id}'),
                            style: TextButton.styleFrom(
                              alignment: AlignmentDirectional.centerStart,
                            ),
                            onPressed: () => edit(context, i),
                            child: Text(step.title),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      [
                        minutesText(context, step.seconds),
                        if (h != null)
                          tr(
                            context,
                            'Counts for ${h.title}',
                            'Tính cho ${h.title}',
                          ),
                        if (!step.canSkip)
                          tr(context, 'Cannot skip', 'Không thể bỏ qua'),
                      ].join(' · '),
                    ),
                    if (advanced && step.logic.advanced)
                      Text(logicDescription(context, step)),
                    Wrap(
                      children: [
                        IconButton(
                          key: Key('draft-up-${step.id}'),
                          tooltip: tr(
                            context,
                            'Move ${step.title} up',
                            'Đưa ${step.title} lên',
                          ),
                          onPressed: i == 0 ? null : () => move(i, i - 1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          key: Key('draft-down-${step.id}'),
                          tooltip: tr(
                            context,
                            'Move ${step.title} down',
                            'Đưa ${step.title} xuống',
                          ),
                          onPressed: i == items.length - 1
                              ? null
                              : () => move(i, i + 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          key: Key('draft-remove-${step.id}'),
                          tooltip: tr(
                            context,
                            'Remove ${step.title}',
                            'Bỏ ${step.title}',
                          ),
                          onPressed: () => update([...items]..removeAt(i)),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        OutlinedButton.icon(
          key: const Key('step-add'),
          onPressed: items.length >= 200 ? null : () => edit(context),
          icon: const Icon(Icons.add),
          label: Text(tr(context, 'Add step', 'Thêm bước')),
        ),
      ],
    );
  }
}
