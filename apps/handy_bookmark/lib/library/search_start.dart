import 'package:handy_ui/kit.dart';
import '../design/clipping.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/visual.dart';

/// Search before a word is typed: what the library holds (each figure
/// opens its place), the tags to tap, and what was saved last as
/// clippings. Typing or a chip turns it into results.
class SearchStart extends StatelessWidget {
  final SaveScope scope;
  const SearchStart({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final theme = Theme.of(context);
      final p = BookmarkPalette.of(context);
      final l = scope.library;
      final live = [
        for (final b in l.bookmarks)
          if (!b.isArchived) b,
      ];
      final tags = <String, int>{};
      for (final b in live) {
        for (final t in b.tags) {
          tags[t] = (tags[t] ?? 0) + 1;
        }
      }
      final tagged = tags.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final recent = [...live]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return Column(
        key: const Key('search-start'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Overview(
            cells: [
              (
                'start-collections',
                tr(context, 'Collections', 'Bộ sưu tập'),
                l.collections.length,
                '/library',
              ),
              (
                'start-items',
                tr(context, 'Saved', 'Đã lưu'),
                live.length,
                '/place/all',
              ),
              (
                'start-favorites',
                tr(context, 'Favourites', 'Yêu thích'),
                live.where((b) => b.isFavorite).length,
                '/place/favorites',
              ),
              (
                'start-unread',
                tr(context, 'Not opened', 'Chưa xem'),
                live.where((b) => !b.isRead).length,
                '/place/unread',
              ),
            ],
          ),
          if (tagged.isNotEmpty) ...[
            const SizedBox(height: HandySpace.xl),
            SectionHead(tr(context, 'Tags', 'Thẻ')),
            Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [
                for (final e in tagged.take(24))
                  ActionChip(
                    key: Key('start-tag-${e.key}'),
                    label: Text('#${e.key}  ${e.value}'),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/tag/${Uri.encodeComponent(e.key)}',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: HandySpace.xl),
          if (recent.isEmpty)
            Text(
              tr(
                context,
                'Nothing saved yet. What you save is found here by a word from its title, site, tag or note.',
                'Chưa lưu gì. Thứ bạn lưu sẽ tìm lại ở đây bằng một chữ trong tiêu đề, tên trang, thẻ hoặc ghi chú.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            )
          else ...[
            SectionHead(tr(context, 'Saved lately', 'Mới lưu')),
            LayoutBuilder(
              builder: (context, box) {
                final columns = (box.maxWidth / 180).floor().clamp(2, 5);
                const gap = HandySpace.m;
                final width = (box.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final b in recent.take(columns * 2))
                      SizedBox(
                        width: width,
                        child: ClippingTile(
                          controller: scope.c,
                          bookmark: b,
                          onTap: () =>
                              Navigator.pushNamed(context, '/bookmark/${b.id}'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: HandySpace.xl),
        ],
      );
    },
  );
}

/// One panel split into four figures, label under number; each opens its
/// place.
class _Overview extends StatelessWidget {
  final List<(String, String, int, String)> cells;
  const _Overview({required this.cells});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return Material(
      key: const Key('search-overview'),
      color: p.surface,
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (key, label, n, route)) in cells.indexed) ...[
              if (i > 0) VerticalDivider(width: 1, color: p.line),
              Expanded(
                child: InkWell(
                  key: Key(key),
                  onTap: () => Navigator.pushNamed(context, route),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: HandySpace.m,
                      horizontal: HandySpace.xs,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatFigure(context, n.toString()),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
