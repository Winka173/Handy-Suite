import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';
import '../design/palette.dart';
import 'habit_appearance.dart';

String presetGoal(BuildContext context, HabitPreset p) {
  if (p.direction == 'reduce')
    return negativeLimitText(
      context,
      NegativeGoal(
        id: 'preview',
        from: '2024-01-01',
        window: p.window,
        limit: p.limit * 1000,
      ),
    );
  final schedule = scheduleText(
    context,
    Schedule(
      id: 'preview',
      from: '2024-01-01',
      kind: p.schedule,
      target: p.stored,
      weekdays: p.weekdays,
      weeklyTarget: p.perWeek,
    ),
  );
  final goal = p.type == 'binary'
      ? tr(context, 'One small action', 'Một việc nhỏ')
      : '${figure(context, p.stored)} ${p.type == 'duration'
            ? tr(context, 'min', 'phút')
            : p.type == 'count'
            ? tr(context, 'times', 'lần')
            : tr(context, p.unitEn, p.unitVi)}';
  return '$goal · $schedule';
}

class TemplatePreviewPage extends StatefulWidget {
  final HabitScope scope;
  final HabitPreset? habit;
  final RoutineTemplateInfo? routine;
  const TemplatePreviewPage({
    super.key,
    required this.scope,
    this.habit,
    this.routine,
  });
  @override
  State<TemplatePreviewPage> createState() => _TemplatePreviewPageState();
}

class _TemplatePreviewPageState extends State<TemplatePreviewPage> {
  bool opening = false;
  Future<void> customise() async {
    if (opening) return;
    setState(() => opening = true);
    final saved = widget.habit != null
        ? await Navigator.pushNamed<bool>(
                context,
                '/habit/new',
                arguments: widget.habit,
              ) ==
              true
        : await Navigator.pushNamed<String>(
                context,
                '/routine/new',
                arguments: widget.routine!.instantiate(
                  vietnamese: isVi(context),
                ),
              ) !=
              null;
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.habit, r = widget.routine;
    final c = templateCollections[h?.collection ?? r!.collection]!;
    final title = h != null
        ? tr(context, h.en, h.vi)
        : tr(context, r!.en, r.vi);
    final p = HabitPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Preview', 'Xem trước'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HandyContent(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(habitIcon(c.icon), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(context, c.en, c.vi),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  key: const Key('template-preview-title'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(tr(context, c.descriptionEn, c.descriptionVi)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: p.raised,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr(
                          context,
                          'Your starting goal',
                          'Mục tiêu để bắt đầu',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        h != null
                            ? presetGoal(context, h)
                            : '${r!.steps.length} ${tr(context, 'steps', 'bước')} · ${minutesText(context, r.seconds)}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (r != null) ...[
                        const SizedBox(height: 8),
                        Text(weekdaysText(context, r.weekdays)),
                      ],
                      if (h?.direction == 'reduce' && h?.window == 'week') ...[
                        const SizedBox(height: 12),
                        Text(
                          tr(
                            context,
                            'Counted from what you recorded when the week ends.',
                            'Khi hết tuần, tính từ những lần bạn đã ghi.',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (r != null) ...[
                  HandyLabel(tr(context, 'In this order', 'Theo thứ tự này')),
                  for (var i = 0; i < r.steps.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text('${i + 1}.'),
                      title: Text(tr(context, r.steps[i].$1, r.steps[i].$2)),
                      subtitle: Text(minutesText(context, r.steps[i].$3)),
                    ),
                ],
                const SizedBox(height: 24),
                Text(
                  tr(
                    context,
                    'Change the name, goal or schedule before saving. Reminders start off.',
                    'Bạn có thể sửa tên, mục tiêu hoặc lịch trước khi lưu. Nhắc nhở mặc định tắt.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('template-customise'),
                  onPressed: opening ? null : customise,
                  child: Text(tr(context, 'Customise', 'Tùy chỉnh')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
