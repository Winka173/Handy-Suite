import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_page.dart' show showUndo;
import '../card/card_sheet.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/look.dart';

/// Every active card on every board whose title or notes match.
class SearchPage extends StatefulWidget {
  final BoardsScope scope;
  const SearchPage({super.key, required this.scope});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final query = TextEditingController();
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.scope.controller,
    builder: (context, _) {
      final s = widget.scope.state;
      final p = BoardsPalette.of(context);
      final q = query.text.trim().toLowerCase();
      final live = {
        for (final b in s.rows('boards'))
          if (!b.flag('archived')) b.id: b,
      };
      final hits = q.isEmpty
          ? const <BoardRecord>[]
          : topTasks(s)
                .where(
                  (t) =>
                      live.containsKey(t.str('board')) &&
                      (t.str('title').toLowerCase().contains(q) ||
                          t.str('notes').toLowerCase().contains(q)),
                )
                .take(200)
                .toList();
      return Scaffold(
        appBar: AppBar(
          title: TextField(
            key: const Key('search-field'),
            controller: query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: tr(context, 'Search every board', 'Tìm trong mọi bảng'),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        body: q.isEmpty
            ? const SizedBox.shrink()
            : hits.isEmpty
            ? HandyEmpty(
                title: tr(context, 'No card matches', 'Không có thẻ nào khớp'),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: hits.length,
                separatorBuilder: (_, _) => const Divider(indent: 16),
                itemBuilder: (context, i) {
                  final t = hits[i];
                  final b = live[t.str('board')]!;
                  return ListTile(
                    title: Text(
                      t.str('title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${b.str('title')} · ${s.get('statuses', t.str('status')).str('title')}',
                      style: TextStyle(color: p.muted),
                    ),
                    trailing: t.data['category'] == null
                        ? null
                        : CategoryChip(
                            s.maybe('categories', t.str('category')),
                          ),
                    onTap: () => openCard(context, widget.scope, t.id),
                  );
                },
              ),
      );
    },
  );
}

/// Cards in the trash: put back, or gone for good after a confirmation.
class TrashPage extends StatelessWidget {
  final BoardsScope scope;
  const TrashPage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.state;
      final cards =
          s
              .rows('tasks')
              .where((t) => t.flag('trashed') && t.data['parent'] == null)
              .toList()
            ..sort((a, b) => b.str('trashedAt').compareTo(a.str('trashedAt')));
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Trash', 'Thùng rác')),
          actions: [
            if (cards.isNotEmpty)
              TextButton(
                key: const Key('trash-empty'),
                onPressed: () async {
                  final ok = await confirmHandy(
                    context,
                    title: tr(
                      context,
                      'Empty the trash?',
                      'Dọn sạch thùng rác?',
                    ),
                    message: tr(
                      context,
                      '${cards.length} cards and their photos are removed from this device.',
                      '${cards.length} thẻ và ảnh của chúng sẽ bị xoá khỏi máy này.',
                    ),
                    confirmLabel: tr(context, 'Empty trash', 'Dọn sạch'),
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  await scope.run(
                    context,
                    () => scope.controller.change(
                      (s) => permanentlyDelete(
                        s,
                        cards.map((c) => c.id).toSet(),
                        confirmed: true,
                      ),
                    ),
                  );
                },
                child: Text(tr(context, 'Empty', 'Dọn sạch')),
              ),
          ],
        ),
        body: cards.isEmpty
            ? HandyEmpty(
                title: tr(context, 'The trash is empty', 'Thùng rác trống'),
              )
            : ListView.separated(
                itemCount: cards.length,
                separatorBuilder: (_, _) => const Divider(indent: 16),
                itemBuilder: (context, i) {
                  final t = cards[i];
                  final b = s.maybe('boards', t.str('board'));
                  return ListTile(
                    title: Text(
                      t.str('title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(b?.str('title') ?? ''),
                    trailing: TextButton(
                      onPressed: () async {
                        await scope.run(
                          context,
                          () => scope.controller.change(
                            (s) => trashTasks(
                              s,
                              {t.id},
                              restore: true,
                              now: scope.clock(),
                            ),
                          ),
                        );
                        if (context.mounted)
                          showUndo(
                            context,
                            scope,
                            tr(context, 'Card put back', 'Đã đưa thẻ trở lại'),
                          );
                      },
                      child: Text(tr(context, 'Put back', 'Khôi phục')),
                    ),
                  );
                },
              ),
      );
    },
  );
}

/// Pro: per category, how much is done, overdue and finished this week,
/// counted from the board's own cards.
class InsightsPage extends StatelessWidget {
  final BoardsScope scope;
  final String board;
  const InsightsPage({super.key, required this.scope, required this.board});
  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final now = scope.clock();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = now.toUtc().subtract(const Duration(days: 7));
    final b = s.get('boards', board);
    final finished = {
      for (final c in columnsOf(s, board))
        if (c.flag('done')) c.id,
    };
    final rows = [
      for (final cp in categoryProgress(s, board))
        () {
          final cards = topTasks(
            s,
            board: board,
          ).where((t) => t.data['category'] == cp.category?.id);
          final overdue = cards.where((t) {
            final d = dueDay(t);
            return !finished.contains(t.str('status')) &&
                d != null &&
                d.isBefore(today);
          }).length;
          final week = cards.where((t) {
            final at = DateTime.tryParse(t.str('completedAt'));
            return finished.contains(t.str('status')) &&
                at != null &&
                at.isAfter(weekAgo);
          }).length;
          return (cp, overdue, week);
        }(),
    ];
    final total = rows.fold<int>(0, (n, r) => n + r.$1.total);
    final done = rows.fold<int>(0, (n, r) => n + r.$1.done);
    return Scaffold(
      appBar: AppBar(title: Text(b.str('title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'Insights', 'Thống kê'),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              context,
              '$done of $total cards done',
              'Xong $done trên $total thẻ',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 16),
          // Finished per week, from the cards' real completion times.
          Text(
            tr(context, 'Finished per week', 'Hoàn thành mỗi tuần'),
            style: theme.textTheme.titleMedium,
          ),
          Text(
            tr(
              context,
              'Counted from when cards reached a finished column; a card '
                  'reopened since is not counted. ${backlogOf(s, board, now).length} '
                  'left behind today.',
              'Tính từ lúc thẻ vào cột xong; thẻ đã mở lại không tính. Hôm nay '
                  'còn ${backlogOf(s, board, now).length} việc tồn.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
          ),
          for (final (monday, n) in weeklyThroughput(s, board, now))
            Padding(
              key: Key('insight-week-${isoDay(monday)}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        'Week of ${monday.day}/${monday.month}',
                        'Tuần ${monday.day}/${monday.month}',
                      ),
                    ),
                  ),
                  Text(
                    '$n',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(BoardsRadii.tile),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, 'Category', 'Nhóm'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      for (final h in [
                        tr(context, 'Done', 'Xong'),
                        tr(context, 'Overdue', 'Quá hạn'),
                        tr(context, 'This week', 'Tuần này'),
                      ])
                        SizedBox(
                          width: 72,
                          child: Text(
                            h,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                for (final (cp, overdue, week) in rows) ...[
                  const Divider(indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: CategoryChip(cp.category),
                          ),
                        ),
                        for (final (v, bad) in [
                          ('${cp.done}/${cp.total}', false),
                          (overdue == 0 ? '—' : '$overdue', overdue > 0),
                          ('$week', false),
                        ])
                          SizedBox(
                            width: 72,
                            child: Text(
                              v,
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: bad ? p.danger : null,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
