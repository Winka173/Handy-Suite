import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/capped.dart';
import 'mood_sheet.dart';

class TodayMood extends StatelessWidget {
  final HabitScope scope;
  const TodayMood({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    final entry = moodOn(scope.state, scope.today);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        key: const Key('today-mood'),
        onPressed: scope.controller.busy
            ? null
            : () => openMood(context, scope, scope.today),
        child: Text(
          entry == null
              ? tr(context, 'How’s today?', 'Hôm nay bạn thấy sao?')
              : tr(
                  context,
                  'Today: ${moodLabel(context, entry.mood)}',
                  'Hôm nay: ${moodLabel(context, entry.mood)}',
                ),
        ),
      ),
    );
  }
}

class MoodHistory extends StatefulWidget {
  final HabitScope scope;
  final String from, until;
  const MoodHistory({
    super.key,
    required this.scope,
    required this.from,
    required this.until,
  });
  @override
  State<MoodHistory> createState() => _MoodHistoryState();
}

class _MoodHistoryState extends State<MoodHistory> {
  bool deleted = false;
  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final rows =
        scope.state.moods
            .where(
              (m) =>
                  m.day.compareTo(widget.from) >= 0 &&
                  m.day.compareTo(widget.until) <= 0,
            )
            .toList()
          ..sort((a, b) => b.day.compareTo(a.day));
    final live = rows.where((m) => !m.deleted).toList(),
        trash = rows.where((m) => m.deleted).toList();
    return Column(
      key: const Key('mood-history'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(tr(context, 'Mood', 'Tâm trạng')),
        Text(
          tr(
            context,
            '${live.length} days recorded. Blank days stay blank.',
            'Đã ghi ${live.length} ngày. Ngày trống vẫn để trống.',
          ),
        ),
        if (live.isEmpty)
          Text(
            tr(
              context,
              'Record a feeling whenever you want to. Habits work without it.',
              'Ghi cảm nhận khi bạn muốn. Thói quen vẫn hoạt động khi không ghi.',
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('mood-log-today'),
            onPressed: () => openMood(context, scope, scope.today),
            child: Text(tr(context, 'Log today', 'Ghi hôm nay')),
          ),
        ),
        Capped(
          key: ValueKey('${widget.from}/${widget.until}'),
          count: live.length,
          max: 5,
          name: 'mood-history',
          builder: (context, shown) => Column(
            children: [
              for (final m in live.take(shown))
                ListTile(
                  key: Key('mood-row-${m.day}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${formatDay(context, m.day)} · ${moodLabel(context, m.mood)}',
                  ),
                  subtitle: m.energy == null && m.tags.isEmpty
                      ? null
                      : Text(
                          [
                            if (m.energy != null)
                              tr(
                                context,
                                'Energy ${m.energy}/5',
                                'Năng lượng ${m.energy}/5',
                              ),
                            ...m.tags,
                          ].join(' · '),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openMood(context, scope, m.day),
                ),
            ],
          ),
        ),
        if (trash.isNotEmpty) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('mood-show-deleted'),
              onPressed: () => setState(() => deleted = !deleted),
              child: Text(
                tr(
                  context,
                  'Deleted entries (${trash.length})',
                  'Bản ghi đã xóa (${trash.length})',
                ),
              ),
            ),
          ),
          if (deleted)
            Capped(
              count: trash.length,
              max: 5,
              name: 'mood-trash',
              builder: (context, shown) => Column(
                children: [
                  for (final m in trash.take(shown))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${formatDay(context, m.day)} · ${moodLabel(context, m.mood)}',
                      ),
                      subtitle: TextButton(
                        key: Key('mood-restore-${m.day}'),
                        onPressed: scope.controller.busy
                            ? null
                            : () => scope.write(
                                context,
                                (s) => restoreMood(
                                  s,
                                  m.day,
                                  now: scope.clock(),
                                  expectedRevision: m.revision,
                                ),
                                done: (c) => tr(
                                  c,
                                  'Mood restored.',
                                  'Đã khôi phục tâm trạng.',
                                ),
                              ),
                        child: Text(tr(context, 'Restore', 'Khôi phục')),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
