import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';

/// How a run went: each step's real time against its plan, and its note.
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
    return HandyPage(
      title: s.title,
      subtitle:
          '${formatDay(context, s.day)} · ${statusLabel(context, s.status)} · ${tr(context, '${clockText(s.elapsed)} of ${clockText(s.planned)} planned', '${clockText(s.elapsed)} trên ${clockText(s.planned)} dự kiến')}',
      children: [
        HandySection(
          children: [
            for (final step in s.steps)
              ListTile(
                title: Text(step.plan.title),
                subtitle: step.note.isEmpty ? null : Text(step.note),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      statusLabel(context, step.status),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      '${clockText(step.elapsed)} / ${clockText(step.plan.seconds)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.l),
          child: Text(
            tr(
              context,
              'Only steps finished with a linked habit recorded progress. A stopped run keeps what it recorded.',
              'Chỉ bước đã xong có liên kết mới ghi tiến độ. Phiên đã dừng vẫn giữ phần đã ghi.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
        ),
      ],
    );
  }
}
