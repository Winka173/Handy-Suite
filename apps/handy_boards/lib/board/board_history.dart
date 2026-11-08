import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import 'board_menus.dart' show askText, ProBadge;

/// Board ⋮ › Board history (Pro to open a picture): the board as the app
/// found it on each day it was opened, read only, compared with now, and
/// copied into a NEW board on request. Never a rollback of the live board.
class BoardHistoryPage extends StatelessWidget {
  final BoardsScope scope;
  final String board;
  const BoardHistoryPage({super.key, required this.scope, required this.board});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final loc = MaterialLocalizations.of(context);
    final list = snapshotsOf(scope.state, board);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Board history', 'Lịch sử bảng')),
        actions: [
          if (!hasPro(context)) const ProBadge(),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        key: const Key('board-history'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(
            list.isEmpty
                ? tr(
                    context,
                    'No pictures yet. From today the app keeps one each day '
                        'it is opened; earlier days were not recorded.',
                    'Chưa có ảnh chụp. Từ hôm nay app giữ mỗi ngày một ảnh khi '
                        'được mở; những ngày trước không được ghi lại.',
                  )
                : tr(
                    context,
                    'The board as it was when the app was first opened on each '
                        'day. Kept daily for 30 days, then weekly for a year. '
                        'Nothing before ${loc.formatMediumDate(DateTime.parse(list.last.str('at')).toLocal())} was recorded.',
                    'Bảng lúc app được mở lần đầu mỗi ngày. Giữ mỗi ngày trong '
                        '30 ngày, sau đó mỗi tuần trong một năm. Trước '
                        '${loc.formatMediumDate(DateTime.parse(list.last.str('at')).toLocal())} không có ghi lại.',
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
          for (final snap in list)
            ListTile(
              key: Key('snapshot-${snap.id}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(
                loc.formatFullDate(DateTime.parse(snap.str('at')).toLocal()),
              ),
              subtitle: Text(
                tr(
                  context,
                  '${(snap.data['cards'] as List).length} cards',
                  '${(snap.data['cards'] as List).length} thẻ',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (!await requirePro(context, ProFeature.history) ||
                    !context.mounted) {
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        _SnapshotPage(scope: scope, board: board, snap: snap),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SnapshotPage extends StatelessWidget {
  final BoardsScope scope;
  final String board;
  final BoardRecord snap;
  const _SnapshotPage({
    required this.scope,
    required this.board,
    required this.snap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final loc = MaterialLocalizations.of(context);
    final at = DateTime.parse(snap.str('at')).toLocal();
    final now = snapshotOf(scope.state, board, scope.clock());
    final diff = compareSnapshots(snap, now);
    final cards = [for (final c in (snap.data['cards'] as List)) c as Map]
      ..sort(
        (a, b) =>
            ((a['order'] ?? 0) as int).compareTo((b['order'] ?? 0) as int),
      );
    String? since(String id) => diff.gone.contains(id)
        ? tr(context, 'gone since', 'đã xoá từ đó')
        : diff.finished.contains(id)
        ? tr(context, 'finished since', 'đã xong từ đó')
        : diff.moved.contains(id)
        ? tr(context, 'moved since', 'đã chuyển cột từ đó')
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(loc.formatMediumDate(at))),
      body: ListView(
        key: const Key('snapshot-view'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Text(
            tr(
              context,
              'Read only. ${diff.added.length} cards were added since.',
              'Chỉ xem. Từ đó đến nay có thêm ${diff.added.length} thẻ.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
          ),
          for (final col in (snap.data['columns'] as List).cast<Map>()) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Semantics(
                header: true,
                child: Text(
                  '${col['title']}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            for (final c in cards.where((c) => c['status'] == col['id']))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${c['title']}'),
                subtitle: since('${c['id']}') == null
                    ? null
                    : Text(
                        since('${c['id']}')!,
                        style: TextStyle(color: p.muted),
                      ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const Key('snapshot-clone'),
            onPressed: () async {
              final title = await askText(
                context,
                title: tr(context, 'Name the new board', 'Đặt tên bảng mới'),
                value: '${snap.str('title')} (${at.day}/${at.month})',
                max: 200,
              );
              if (title == null || title.trim().isEmpty || !context.mounted)
                return;
              await scope.run(
                context,
                () => scope.controller.change(
                  (s) => boardFromSnapshot(
                    s,
                    snap,
                    title.trim(),
                    now: scope.clock(),
                  ),
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tr(
                        context,
                        'A new board was made; this one is unchanged.',
                        'Đã tạo một bảng mới; bảng này giữ nguyên.',
                      ),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(
              tr(context, 'Copy into a new board', 'Tạo bảng mới từ đây'),
            ),
          ),
        ),
      ),
    );
  }
}
