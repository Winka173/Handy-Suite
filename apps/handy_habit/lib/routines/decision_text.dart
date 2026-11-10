import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ui/words.dart';

String decisionText(BuildContext context, String reason) {
  if (reason.startsWith('weekday:')) {
    final d = int.parse(reason.split(':').last);
    return tr(
      context,
      "Skipped: it's ${weekdayLong(context, d)}",
      'Bỏ qua: hôm nay là ${weekdayLong(context, d)}',
    );
  }
  if (reason.startsWith('branch:'))
    return tr(
      context,
      'Skipped: chose path ${reason.split(':').last}',
      'Bỏ qua: đã chọn nhánh ${reason.split(':').last}',
    );
  return switch (reason) {
    'habitDone' => tr(
      context,
      'Skipped: the habit is already done',
      'Bỏ qua: thói quen đã hoàn thành',
    ),
    'habitUnavailable' => tr(
      context,
      'Skipped: the habit is unavailable',
      'Bỏ qua: thói quen không còn khả dụng',
    ),
    'timeLeft' => tr(
      context,
      'Skipped: not enough time left in the plan',
      'Bỏ qua: kế hoạch không còn đủ thời gian',
    ),
    'dependency' => tr(
      context,
      'Skipped: an earlier required step was not completed',
      'Bỏ qua: một bước cần xong trước chưa hoàn thành',
    ),
    _ => '',
  };
}

class BranchChoice extends StatelessWidget {
  final RoutineSession session;
  final ValueChanged<String>? onChoose;
  const BranchChoice({super.key, required this.session, this.onChoose});
  @override
  Widget build(BuildContext context) {
    final branch = pendingBranch(session)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'Choose a path: $branch', 'Chọn nhánh: $branch'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          tr(
            context,
            'The timer waits for your choice.',
            'Đồng hồ chờ bạn chọn.',
          ),
        ),
        for (final option in ['A', 'B'])
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              key: Key('branch-$option'),
              onPressed: onChoose == null ? null : () => onChoose!(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '$option · ${session.steps.where((s) => s.plan.logic.branch == branch && s.plan.logic.option == option).map((s) => s.plan.title).join(', ')}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
