import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/sheet.dart';
import '../ui/words.dart';
import 'routine_editor.dart';
import 'run.dart';

/// The quick version: how many minutes there are, and what the routine
/// becomes to fit them. The routine itself is never changed.
Future<void> openLite(
  BuildContext context,
  HabitScope scope,
  Routine routine,
) async {
  final plan = await openSheet<List<RoutineStep>>(
    context,
    (_) => _LiteSheet(scope: scope, routine: routine),
  );
  if (plan != null && context.mounted)
    await startRoutine(context, scope, routine, plan: plan);
}

class _LiteSheet extends StatefulWidget {
  final HabitScope scope;
  final Routine routine;
  const _LiteSheet({required this.scope, required this.routine});
  @override
  State<_LiteSheet> createState() => _LiteSheetState();
}

class _LiteSheetState extends State<_LiteSheet> {
  late int minutes = ((widget.routine.planned / 60) * .6).round().clamp(5, 90);

  Future<void> saveVariant(LitePlan plan) async {
    final r = widget.routine;
    final ok = await widget.scope.write(
      context,
      (s) => s.copy({
        'routines': [
          ...s.routines.map((x) => x.toJson()),
          r.copy({
            'id': uid(),
            'title': tr(
              context,
              '${r.title} · $minutes min',
              '${r.title} · $minutes phút',
            ),
            'steps': [
              for (final s in plan.steps) s.copy({'id': uid()}).toJson(),
            ],
          }).toJson(),
        ],
      }),
      done: (c) =>
          tr(c, 'Saved as its own routine.', 'Đã lưu thành quy trình riêng.'),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final r = widget.routine;
    final plan = routineLite(r, minutes * 60);
    final pro = widget.scope.pro(context);
    return SheetFrame(
      title: tr(context, 'Quick ${r.title}', '${r.title} rút gọn'),
      actions: [
        if (pro)
          TextButton(
            key: const Key('lite-save'),
            onPressed: plan.feasible && plan.steps.isNotEmpty
                ? () => saveVariant(plan)
                : null,
            child: Text(tr(context, 'Save as routine', 'Lưu thành quy trình')),
          ),
      ],
      primary: FilledButton(
        key: const Key('lite-start'),
        onPressed: plan.feasible && plan.steps.isNotEmpty
            ? () => Navigator.pop(context, plan.steps)
            : null,
        child: Text(tr(context, 'Start this once', 'Chạy bản này một lần')),
      ),
      children: [
        Text(
          tr(context, '$minutes minutes', '$minutes phút'),
          style: theme.textTheme.headlineMedium,
        ),
        Slider(
          key: const Key('lite-minutes'),
          value: minutes.toDouble(),
          min: 5,
          max: 90,
          divisions: 85,
          label: '$minutes',
          semanticFormatterCallback: (v) =>
              tr(context, '${v.round()} minutes', '${v.round()} phút'),
          onChanged: (v) => setState(() => minutes = v.round()),
        ),
        Text(
          plan.feasible
              ? tr(
                  context,
                  'Fits: ${minutesText(context, plan.total)} of ${minutesText(context, r.planned)}.',
                  'Vừa: ${minutesText(context, plan.total)} trên ${minutesText(context, r.planned)}.',
                )
              : tr(
                  context,
                  'Does not fit: the steps you keep need more than $minutes minutes even at their shortest.',
                  'Không vừa: các bước phải giữ vẫn cần hơn $minutes phút dù rút ngắn nhất.',
                ),
          key: const Key('lite-result'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: plan.feasible ? null : c.negative,
          ),
        ),
        const SizedBox(height: HandySpace.m),
        DurationStrip(steps: plan.steps, color: c.accent),
        const SizedBox(height: HandySpace.m),
        for (final step in r.steps)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              step.title,
              style: TextStyle(
                color: plan.omitted.contains(step.id) ? c.muted : null,
                decoration: plan.omitted.contains(step.id)
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            trailing: Text(
              plan.omitted.contains(step.id)
                  ? tr(context, 'left out', 'bỏ')
                  : plan.shrunk.contains(step.id)
                  // Nunito has no arrow: the change is said in words.
                  ? tr(
                      context,
                      '${minutesText(context, plan.steps.firstWhere((s) => s.id == step.id).seconds)}, not ${minutesText(context, step.seconds)}',
                      '${minutesText(context, plan.steps.firstWhere((s) => s.id == step.id).seconds)} thay vì ${minutesText(context, step.seconds)}',
                    )
                  : minutesText(context, step.seconds),
              style: TextStyle(color: c.muted),
            ),
          ),
        if (!pro)
          Text(
            tr(
              context,
              'Saving a quick version as its own routine comes with Pro.',
              'Lưu bản rút gọn thành quy trình riêng có trong Pro.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
      ],
    );
  }
}
