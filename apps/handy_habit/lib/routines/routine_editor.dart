import 'dart:convert';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/words.dart';
import 'draft_steps.dart';

HabitState replaceRoutine(HabitState state, Routine r) => state.copy({
  'routines': [
    for (final x in state.routines) x.id == r.id ? r.toJson() : x.toJson(),
  ],
});

/// One atomic routine draft, including its ordered steps.
Future<String?> openRoutineEditor(
  BuildContext context,
  HabitScope scope, [
  Routine? old,
]) async => Navigator.pushNamed<String>(
  context,
  old == null ? '/routine/new' : '/routine/${old.id}/edit',
);

Widget buildRoutineEditor(
  BuildContext context,
  HabitScope scope, [
  Routine? old,
]) {
  String? id;
  final baseline = old == null ? null : jsonEncode(old.toJson());
  return HabitForm(
    result: () => id,
    title: old == null
        ? tr(context, 'New routine', 'Quy trình mới')
        : tr(context, 'Edit ${old.title}', 'Sửa ${old.title}'),
    fields: const [
      HabitField('title', 'Name', 'Tên'),
      HabitField(
        'weekdays',
        'On',
        'Vào',
        kind: FieldKind.weekdays,
        advanced: true,
        required: false,
        helpEn: 'No day chosen: it is only started by hand.',
        helpVi: 'Không chọn ngày: chỉ bắt đầu khi bạn bấm.',
      ),
      HabitField(
        'time',
        'Around',
        'Khoảng',
        kind: FieldKind.time,
        advanced: true,
      ),
      HabitField('category', 'Group', 'Nhóm', required: false, advanced: true),
      HabitField(
        'note',
        'Note',
        'Ghi chú',
        kind: FieldKind.note,
        advanced: true,
        required: false,
      ),
    ],
    initial: {
      'steps': [
        for (final step in old?.steps ?? <RoutineStep>[]) step.toJson(),
      ],
      'title': old?.title ?? '',
      'weekdays': old?.weekdays ?? const [1, 2, 3, 4, 5, 6, 7],
      'time': old?.time ?? '07:00',
      'category': old?.category ?? '',
      'note': old?.note ?? '',
    },
    draftContent: (context, values, update) => DraftSteps(
      scope: scope,
      values: values,
      onChanged: update,
      templates: old == null,
    ),
    save: (v) async {
      final r = Routine(
        id: old?.id ?? uid(),
        title: v['title'] as String,
        weekdays: List<int>.from(v['weekdays'] as List),
        time: v['time'] as String,
        category: v['category'] as String,
        note: v['note'] as String,
        steps: [
          for (final step in v['steps'] as List)
            RoutineStep.fromJson(Map<String, dynamic>.from(step as Map)),
        ],
        icon: old?.icon ?? 0xe037,
        color: old?.color ?? 0xffb42318,
        archived: old?.archived ?? false,
      );
      await scope.controller.change((s) {
        final latest = s.liveRoutines.where((x) => x.id == old?.id).firstOrNull;
        if (old != null &&
            (latest == null || jsonEncode(latest.toJson()) != baseline)) {
          throw StateError('Routine changed; reopen the editor');
        }
        return s.copy({
          'routines': [
            for (final x in s.routines)
              if (x.id != r.id) x.toJson(),
            r.toJson(),
          ],
        });
      });
      id = r.id;
    },
  );
}

/// One step: how long it usually takes, how short it may get, and whether
/// finishing it counts towards a habit.
Future<RoutineStep?> editRoutineStep(
  BuildContext context,
  HabitScope scope, [
  RoutineStep? old,
]) async {
  RoutineStep? result;
  final habits = {
    for (final h in scope.state.liveHabits.where(
      (h) => !h.archived || h.id == old?.habit,
    ))
      h.id: h.title,
  };
  int seconds(int milliMinutes) => (milliMinutes * 60 / 1000).round();
  int minutes(int seconds) => (seconds * 1000 / 60).round();
  final saved = await showHabitForm(
    context,
    title: old == null ? tr(context, 'New step', 'Bước mới') : old.title,
    fields: [
      const HabitField('title', 'Step', 'Bước'),
      const HabitField(
        'minutes',
        'Minutes it takes',
        'Mất bao nhiêu phút',
        kind: FieldKind.amount,
        required: false,
        helpEn: 'Empty or 0: no timer, it ends when you say so.',
        helpVi: 'Để trống hoặc 0: không đếm giờ, xong khi bạn bấm.',
      ),
      const HabitField(
        'shortest',
        'At least, when short of time',
        'Tối thiểu khi gấp',
        kind: FieldKind.amount,
        required: false,
        helpEn: 'The quick version never cuts it below this.',
        helpVi: 'Bản rút gọn không cắt ngắn hơn mức này.',
      ),
      const HabitField(
        'required',
        'Keep it in the quick version',
        'Giữ trong bản rút gọn',
        kind: FieldKind.toggle,
      ),
      const HabitField(
        'skip',
        'May be skipped while running',
        'Được bỏ qua khi đang chạy',
        kind: FieldKind.toggle,
      ),
      const HabitField(
        'priority',
        'Priority',
        'Ưu tiên',
        kind: FieldKind.count,
        helpEn: '0 to 9; the quick version shortens lower ones first.',
        helpVi: 'Từ 0 đến 9; bản rút gọn cắt bước ưu tiên thấp trước.',
      ),
      HabitField(
        'habit',
        'Counts towards',
        'Tính cho thói quen',
        kind: FieldKind.choice,
        required: false,
        options: {'': tr(context, 'No habit', 'Không'), ...habits},
        helpEn: 'Finishing the step records it once.',
        helpVi: 'Xong bước thì ghi cho thói quen đúng một lần.',
      ),
      HabitField(
        'value',
        'How much it adds',
        'Cộng bao nhiêu',
        kind: FieldKind.amount,
        when: (v) =>
            (v['habit'] as String? ?? '').isNotEmpty &&
            scope.habit(v['habit'] as String?)?.type != 'binary',
      ),
      const HabitField(
        'note',
        'What to do',
        'Làm gì',
        kind: FieldKind.note,
        required: false,
      ),
    ],
    initial: {
      'title': old?.title ?? '',
      'minutes': old == null ? 5000 : minutes(old.seconds),
      'shortest': old == null ? 2000 : minutes(old.minimum),
      'required': old?.required ?? true,
      'skip': old?.canSkip ?? true,
      'priority': '${old?.priority ?? 1}',
      'habit': old?.habit ?? '',
      'value': old?.linkedValue ?? 1000,
      'note': old?.note ?? '',
    },
    save: (v) async {
      final linked = (v['habit'] as String).isEmpty
          ? null
          : v['habit'] as String;
      final h = scope.habit(linked);
      final value = h == null || h.type == 'binary' ? 1000 : v['value'] as int;
      final secs = seconds(v['minutes'] as int? ?? 0);
      result = RoutineStep(
        id: old?.id ?? uid(),
        title: v['title'] as String,
        note: v['note'] as String,
        seconds: secs,
        minimum: seconds(v['shortest'] as int? ?? 0).clamp(0, secs),
        priority: int.parse('${v['priority']}'),
        icon: old?.icon ?? 0xe876,
        required: v['required'] == true,
        canSkip: v['skip'] == true,
        habit: linked,
        linkedValue: value,
      );
    },
  );
  return saved ? result : null;
}

/// The routine's steps as one strip, each as long as its minutes.
class DurationStrip extends StatelessWidget {
  final List<RoutineStep> steps;
  final Color color;
  const DurationStrip({super.key, required this.steps, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final total = steps.fold(0, (a, s) => a + s.seconds);
    return Semantics(
      label: steps
          .map((s) => '${s.title}: ${minutesText(context, s.seconds)}')
          .join('; '),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 14,
          child: Row(
            children: [
              for (final (i, s) in steps.indexed) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: total == 0
                      ? 1
                      : (s.seconds == 0
                            ? 6
                            : (s.seconds * 1000 ~/ total).clamp(6, 1000)),
                  child: Container(
                    color: s.seconds == 0
                        ? c.raised
                        : s.required
                        ? color
                        : color.withValues(alpha: .45),
                  ),
                ),
              ],
              if (steps.isEmpty) Expanded(child: Container(color: c.raised)),
            ],
          ),
        ),
      ),
    );
  }
}
