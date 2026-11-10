import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'decision_text.dart';

/// Immutable session results, including the links that actually earned credit.
class SessionPage extends StatelessWidget {
  final HabitScope scope;
  final String id;
  const SessionPage({super.key, required this.scope, required this.id});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final s = scope.state.sessions.where((x) => x.id == id).firstOrNull;
    if (s == null)
      return HandyPage(
        title: tr(context, 'Run', 'Phiên'),
        children: [
          HandyEmpty(
            title: tr(context, 'This run is gone', 'Phiên này không còn'),
          ),
        ],
      );
    final credited = {
      for (final step in s.steps)
        if (step.status == 'completed' &&
            step.event != null &&
            step.plan.habit != null)
          step.plan.habit!,
    };
    return HandyPage(
      title: s.title,
      subtitle:
          '${formatDay(context, s.day)} · ${statusLabel(context, s.status)}',
      children: [
        HandyAppear(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, 'Run summary', 'Tổng kết phiên'),
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                tr(
                  context,
                  '${s.steps.where((x) => x.status == 'completed').length} completed · ${s.steps.where((x) => x.status == 'skipped').length} skipped',
                  '${s.steps.where((x) => x.status == 'completed').length} đã xong · ${s.steps.where((x) => x.status == 'skipped').length} bỏ qua',
                ),
              ),
              Text(
                tr(
                  context,
                  '${clockText(s.elapsed)} actual · ${clockText(s.planned)} planned',
                  '${clockText(s.elapsed)} thực tế · ${clockText(s.planned)} dự kiến',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: tabular,
                ),
              ),
            ],
          ),
        ),
        HandySection(
          title: tr(context, 'Habits checked in', 'Thói quen đã ghi nhận'),
          children: [
            if (credited.isEmpty)
              Padding(
                padding: const EdgeInsets.all(HandySpace.m),
                child: Text(
                  tr(
                    context,
                    'No linked habits were checked in.',
                    'Không có thói quen liên kết được ghi nhận.',
                  ),
                ),
              ),
            for (final habitId in credited)
              ListTile(
                key: Key('summary-habit-$habitId'),
                leading: const Icon(Icons.check),
                title: Text(
                  (s.inputs['habitTitles'] as Map?)?[habitId] as String? ??
                      scope.state.habits
                          .where((h) => h.id == habitId)
                          .firstOrNull
                          ?.title ??
                      tr(context, 'Removed habit', 'Thói quen đã xóa'),
                ),
              ),
          ],
        ),
        HandySection(
          title: tr(context, 'Steps', 'Các bước'),
          children: [
            for (final step in s.steps)
              Padding(
                padding: const EdgeInsets.all(HandySpace.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(step.plan.title, style: theme.textTheme.titleMedium),
                    Text(
                      '${statusLabel(context, step.status)} · ${clockText(step.elapsed)} / ${clockText(step.plan.seconds)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: c.muted,
                        fontFeatures: tabular,
                      ),
                    ),
                    if (step.note.isNotEmpty) Text(step.note),
                    if (step.reason.isNotEmpty)
                      Text(decisionText(context, step.reason)),
                    if (step.plan.habit != null)
                      Text(
                        step.event != null
                            ? tr(context, 'Check-in recorded', 'Đã ghi nhận')
                            : tr(
                                context,
                                'No check-in: skipped, unavailable, or target already reached.',
                                'Không ghi nhận: đã bỏ qua, không còn khả dụng hoặc đã đạt mục tiêu.',
                              ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (s.trace.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(tr(context, 'Saved decisions', 'Quyết định đã lưu')),
            children: [
              for (final entry in s.trace)
                if (entry['kind'] == 'choice')
                  ListTile(
                    title: Text('${entry['branch']} · ${entry['option']}'),
                  )
                else if (entry['kind'] == 'evaluate' && entry['reason'] != '')
                  ListTile(
                    title: Text(
                      s.steps
                              .where((x) => x.plan.id == entry['step'])
                              .firstOrNull
                              ?.plan
                              .title ??
                          '',
                    ),
                    subtitle: Text(
                      decisionText(context, entry['reason'] as String),
                    ),
                  ),
            ],
          ),
        Text(
          tr(
            context,
            'A stopped run keeps what it recorded. Later changes to history are kept separately.',
            'Phiên đã dừng vẫn giữ phần đã ghi. Thay đổi lịch sử sau đó được lưu riêng.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
