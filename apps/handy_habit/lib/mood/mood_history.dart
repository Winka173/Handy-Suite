import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/capped.dart';
import 'package:flutter/services.dart';
import '../design/palette.dart';
import 'mood_faces.dart';
import 'mood_sheet.dart';

/// How today felt, on Today itself: five faces, one tap saves (Undo in
/// the message), the chosen one marked; Details opens the full sheet for
/// energy, a note and tags.
class TodayMood extends StatelessWidget {
  final HabitScope scope;
  const TodayMood({super.key, required this.scope});

  Future<void> _pick(BuildContext context, int value) async {
    final entry = moodOn(scope.state, scope.today, includeDeleted: true);
    final live = entry?.deleted == false ? entry : null;
    if (live?.mood == value) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) != true)
      HapticFeedback.selectionClick();
    await scope.write(
      context,
      (s) => saveMood(
        s,
        scope.today,
        value,
        energy: live?.energy,
        note: live?.note ?? '',
        tags: live?.tags ?? [],
        now: scope.clock(),
        expectedRevision: entry?.revision ?? 0,
      ),
      done: (c) => tr(
        c,
        'Today: ${moodLabel(c, value)}.',
        'Hôm nay: ${moodLabel(c, value)}.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    final entry = moodOn(scope.state, scope.today);
    final busy = scope.controller.busy;
    return Padding(
      key: const Key('today-mood-row'),
      padding: const EdgeInsets.only(top: HandySpace.s),
      child: Wrap(
        spacing: 2,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Text(
              entry == null
                  ? tr(context, 'How’s today?', 'Hôm nay thấy sao?')
                  : tr(context, 'Today', 'Hôm nay'),
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (var n = 1; n <= 5; n++)
            Semantics(
              button: true,
              selected: entry?.mood == n,
              label: moodLabel(context, n),
              excludeSemantics: true,
              child: InkResponse(
                key: Key('today-mood-$n'),
                radius: 24,
                onTap: busy ? null : () => _pick(context, n),
                child: AnimatedContainer(
                  duration: HandyMotion.of(context, HandyMotion.short),
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry?.mood == n ? p.ochreField : null,
                    border: Border.all(
                      color: entry?.mood == n ? p.anchor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Opacity(
                    opacity: entry == null || entry.mood == n ? 1 : .45,
                    child: MoodFace(value: n, size: 30),
                  ),
                ),
              ),
            ),
          IconButton(
            key: const Key('today-mood'),
            tooltip: tr(
              context,
              'Energy, a note, tags',
              'Năng lượng, ghi chú, nhãn',
            ),
            onPressed: busy
                ? null
                : () => openMood(context, scope, scope.today),
            icon: const Icon(Icons.edit_note),
          ),
        ],
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
            '${live.length} ${live.length == 1 ? 'day' : 'days'} recorded. Blank days stay blank.',
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
