import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_page.dart' show showUndo;
import '../board/key_dates.dart' show keyDateLine;
import '../design/theme.dart';
import '../scope.dart';
import '../ui/look.dart';

/// Settings › Data › Archived boards: each board put away, with enough to
/// recognise it (its cover, how far it got, its groups and key dates,
/// when it was put away and last changed) and two ways out: Restore, or
/// Delete for good after a question.
class ArchivedBoardsPage extends StatelessWidget {
  final BoardsScope scope;
  const ArchivedBoardsPage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.state;
      final boards = [
        for (final b in s.rows('boards'))
          if (b.flag('archived')) b,
      ]..sort((a, b) => b.str('archivedAt').compareTo(a.str('archivedAt')));
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Archived boards', 'Bảng đã lưu trữ')),
        ),
        body: boards.isEmpty
            ? HandyEmpty(
                title: tr(
                  context,
                  'No archived boards',
                  'Không có bảng nào đã lưu trữ',
                ),
              )
            : LayoutBuilder(
                builder: (context, box) {
                  final across = box.maxWidth >= 840 ? 2 : 1;
                  return ListView(
                    key: const Key('archived-boards'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      Text(
                        tr(
                          context,
                          'Archived boards are kept as they were, off Your boards. Restore puts one back; nothing in it changed.',
                          'Bảng đã lưu trữ được giữ nguyên, chỉ ẩn khỏi Bảng của bạn. Khôi phục đưa bảng trở lại, không đổi gì bên trong.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BoardsPalette.of(context).muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final b in boards)
                            SizedBox(
                              width:
                                  (box.maxWidth - 32 - 16 * (across - 1)) /
                                  across,
                              child: _ArchivedBoard(scope: scope, board: b),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
      );
    },
  );
}

class _ArchivedBoard extends StatelessWidget {
  final BoardsScope scope;
  final BoardRecord board;
  const _ArchivedBoard({required this.scope, required this.board});

  String _day(BuildContext context, String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null
        ? ''
        : MaterialLocalizations.of(context).formatMediumDate(d);
  }

  Future<void> _restore(BuildContext context) async {
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => s.put(
          'boards',
          s.get('boards', board.id).copy({'archived': false}),
        ),
      ),
    );
    if (context.mounted)
      showUndo(
        context,
        scope,
        tr(
          context,
          'Board is back on Your boards',
          'Bảng đã trở lại Bảng của bạn',
        ),
      );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Delete “${board.str('title')}” for good?',
        'Xoá vĩnh viễn “${board.str('title')}”?',
      ),
      message: tr(
        context,
        'The board and every card in it go. Undo works right after; backups keep their own copy.',
        'Bảng và mọi thẻ bên trong sẽ mất. Có thể hoàn tác ngay sau đó; bản sao lưu vẫn giữ bản riêng.',
      ),
      confirmLabel: tr(context, 'Delete', 'Xoá'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => deleteBoard(s, board.id, confirmed: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final p = BoardsPalette.of(context);
    final theme = Theme.of(context);
    final now = scope.clock();
    final sum = boardSummary(s, board.id, now: now);
    final open = sum.cards - sum.done;
    final groups = [
      for (final c in s.rows('categories'))
        if (c.str('board') == board.id) c.str('title'),
    ];
    final next = [
      for (final m in milestonesOf(board))
        if (!m.day.isBefore(DateTime(now.year, now.month, now.day))) m,
    ];
    final archived = _day(context, board.str('archivedAt'));
    final changed = _day(context, board.str('updated'));
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    return Material(
      key: Key('archived-${board.id}'),
      color: p.surface,
      borderRadius: BorderRadius.circular(BoardsRadii.tile),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 88,
                    height: 66,
                    child: boardCover(board),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        board.str('title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          context,
                          '${sum.cards} cards · ${sum.done} done · $open open',
                          '${sum.cards} thẻ · ${sum.done} xong · $open đang mở',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (groups.isNotEmpty)
              line(
                Icons.label_outline,
                '${tr(context, 'Groups', 'Nhóm')}: ${groups.join(', ')}',
              ),
            if (next.isNotEmpty)
              line(
                Icons.flag_outlined,
                keyDateLine(
                  context,
                  next.first.label,
                  next.first.day,
                  now,
                  minute: next.first.minute,
                ),
              ),
            line(
              Icons.inventory_2_outlined,
              [
                if (archived.isNotEmpty)
                  tr(context, 'Archived $archived', 'Lưu trữ $archived'),
                if (changed.isNotEmpty)
                  tr(context, 'last changed $changed', 'sửa lần cuối $changed'),
              ].join(' · '),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    key: Key('restore-${board.id}'),
                    onPressed: () => _restore(context),
                    child: Text(tr(context, 'Restore', 'Khôi phục')),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: Key('archived-delete-${board.id}'),
                  style: TextButton.styleFrom(foregroundColor: p.danger),
                  onPressed: () => _delete(context),
                  child: Text(tr(context, 'Delete for good', 'Xoá vĩnh viễn')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
