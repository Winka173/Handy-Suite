import 'dart:convert';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';
import 'advanced_controls.dart';

/// Excludes ordinary title/note/schedule changes, but includes node order and
/// habit links used by stacking. The save gate rechecks the live entitlement.
String advancedFingerprint(Routine r) => jsonEncode({
  'steps': [
    for (final s in r.steps)
      {'id': s.id, 'habit': s.habit, 'logic': s.logic.toJson()},
  ],
  'blocks': r.blocks.map((b) => b.toJson()).toList(),
  'presets': r.presets.map((b) => b.toJson()).toList(),
});

class AdvancedRoutineLibrary extends StatelessWidget {
  final HabitScope scope;
  final Map<String, dynamic> values;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const AdvancedRoutineLibrary({
    super.key,
    required this.scope,
    required this.values,
    required this.onChanged,
  });
  List<StepBlock> saved(String kind) =>
      objects(values[kind]).map(StepBlock.fromJson).toList();
  Future<void> capture(BuildContext context, String kind) async {
    if (!scope.pro(context)) return;
    final steps = objects(values['steps']).map(RoutineStep.fromJson).toList();
    if (steps.isEmpty) {
      showHandyMessage(
        context,
        tr(context, 'Add steps first.', 'Hãy thêm bước trước.'),
      );
      return;
    }
    await showHabitForm(
      context,
      title: tr(context, 'Save these steps', 'Lưu các bước này'),
      fields: const [HabitField('name', 'Name', 'Tên')],
      initial: const {'name': ''},
      save: (v) async {
        if (!scope.pro(context))
          throw const FormatException('Pro is needed to edit advanced logic');
        final item = StepBlock(
          id: uid(),
          title: v['name'] as String,
          steps: steps,
        );
        onChanged({
          kind: [...saved(kind).map((b) => b.toJson()), item.toJson()],
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pro = scope.pro(context);
    Widget panel(String kind, String title, String help) {
      final bank = <String, StepBlock>{
        for (final r in scope.state.liveRoutines)
          for (final b in kind == 'blocks' ? r.blocks : r.presets) b.id: b,
        for (final b in saved(kind)) b.id: b,
      };
      return AdvancedPanel(
        pro: pro,
        title: title,
        help: help,
        children: [
          TextButton(
            key: Key('save-$kind'),
            onPressed: () => capture(context, kind),
            child: Text(tr(context, 'Save these steps', 'Lưu các bước này')),
          ),
          if (bank.isEmpty)
            Text(
              tr(
                context,
                'No saved steps yet. Save a set above to reuse it.',
                'Chưa lưu nhóm bước nào. Lưu các bước ở trên để dùng lại.',
              ),
            ),
          for (final b in bank.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(b.title),
              subtitle: Text(
                tr(
                  context,
                  '${b.steps.length} ${b.steps.length == 1 ? 'step' : 'steps'} · ${kind == 'blocks' ? 'Insert a copy' : 'Replace draft steps'}',
                  '${b.steps.length} bước · ${kind == 'blocks' ? 'Chèn bản sao' : 'Thay các bước trong nháp'}',
                ),
              ),
              onTap: () {
                if (!scope.pro(context)) return;
                final copy = b.insert(instance: uid());
                final next = kind == 'blocks'
                    ? [
                        ...objects(values['steps']).map(RoutineStep.fromJson),
                        ...copy,
                      ]
                    : copy;
                if (next.length > 200) {
                  showHandyMessage(
                    context,
                    tr(context, 'At most 200 steps.', 'Tối đa 200 bước.'),
                  );
                  return;
                }
                onChanged({'steps': next.map((s) => s.toJson()).toList()});
              },
              trailing: saved(kind).any((x) => x.id == b.id)
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: tr(
                        context,
                        'Remove saved set',
                        'Bỏ nhóm đã lưu',
                      ),
                      onPressed: () => onChanged({
                        kind: saved(kind)
                            .where((x) => x.id != b.id)
                            .map((b) => b.toJson())
                            .toList(),
                      }),
                    )
                  : null,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panel(
          'blocks',
          tr(context, 'Reusable step blocks', 'Nhóm bước dùng lại'),
          tr(
            context,
            'Save steps once, then insert independent copies in any routine.',
            'Lưu một lần, rồi chèn bản sao độc lập vào quy trình khác.',
          ),
        ),
        panel(
          'presets',
          tr(context, 'Saved presets', 'Cấu hình đã lưu'),
          tr(
            context,
            'Save an alternative plan; loading it replaces only this draft’s steps.',
            'Lưu phương án khác; khi chọn chỉ thay các bước trong nháp này.',
          ),
        ),
      ],
    );
  }
}
