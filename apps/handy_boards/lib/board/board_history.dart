import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import 'time_actions.dart' show eventText, eventIcon;

/// Board ⋮ › Board history (Pro): what happened on this board, newest
/// first, grouped by day. Read only: nothing here can be tapped to change
/// anything. It is the cards' real recorded history, from the version that
/// started keeping it; nothing earlier is made up.
class BoardHistoryPage extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  const BoardHistoryPage({super.key, required this.scope, required this.board});
  @override
  State<BoardHistoryPage> createState() => _BoardHistoryPageState();
}

class _BoardHistoryPageState extends State<BoardHistoryPage> {
  /// How far back: 7 or 30 days, or everything (null).
  int? days = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final loc = MaterialLocalizations.of(context);
    final s = widget.scope.state, now = widget.scope.clock();
    final since = days == null ? null : addDays(calendarDay(now), -(days! - 1));
    final events = boardHistory(s, widget.board, since: since);
    String dayTitle(DateTime d) => switch (daysBetween(d, calendarDay(now))) {
      0 => tr(context, 'Today', 'Hôm nay'),
      1 => tr(context, 'Yesterday', 'Hôm qua'),
      _ => loc.formatFullDate(d),
    };
    final rows = <Widget>[];
    DateTime? shown;
    for (final e in events) {
      final at = DateTime.parse(e.str('at')).toLocal();
      final d = calendarDay(at);
      if (d != shown) {
        shown = d;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Semantics(
              header: true,
              child: Text(dayTitle(d), style: theme.textTheme.titleSmall),
            ),
          ),
        );
      }
      final card = s.maybe('tasks', e.str('task'));
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(eventIcon(e.str('action')), size: 20, color: p.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card?.str('title') ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(eventText(context, e)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                loc.formatTimeOfDay(
                  TimeOfDay.fromDateTime(at),
                  alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                    context,
                  ),
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Board history', 'Lịch sử bảng'))),
      body: ListView(
        key: const Key('board-history'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(
            tr(
              context,
              'What happened on this board, newest first. Only what the app '
                  'recorded from this version on; a card deleted for good '
                  'takes its history with it.',
              'Những gì đã xảy ra trên bảng, mới nhất trước. Chỉ những gì app '
                  'ghi lại từ phiên bản này; thẻ đã xoá vĩnh viễn mang theo '
                  'lịch sử của nó.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int?>(
            key: const Key('history-range'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 7,
                label: Text(tr(context, '7 days', '7 ngày')),
              ),
              ButtonSegment(
                value: 30,
                label: Text(tr(context, '30 days', '30 ngày')),
              ),
              ButtonSegment(
                value: null,
                label: Text(tr(context, 'All', 'Tất cả')),
              ),
            ],
            selected: {days},
            onSelectionChanged: (v) => setState(() => days = v.first),
          ),
          if (events.isEmpty)
            Padding(
              key: const Key('board-history-empty'),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                tr(
                  context,
                  'Nothing recorded in this time.',
                  'Không có gì được ghi trong khoảng này.',
                ),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ...rows,
        ],
      ),
    );
  }
}
