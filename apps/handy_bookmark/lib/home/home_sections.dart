import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ui/read_later_ribbon.dart';
import 'pastel_blocks.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';

/// The last few saves, newest first: a short confirmation of what just
/// came in, not a feed. Unsorted ones can be put in a collection here.
class RecentlySaved extends StatelessWidget {
  final SaveScope scope;
  final ValueChanged<Bookmark> onOpen;
  final VoidCallback onAll;
  static const shown = 4;
  const RecentlySaved({
    super.key,
    required this.scope,
    required this.onOpen,
    required this.onAll,
  });

  @override
  Widget build(BuildContext context) {
    final l = scope.library;
    final recent = [
      for (final b in l.bookmarks)
        if (!b.isArchived) b,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.l),
      child: HomePanel(
        key: const Key('recent'),
        title: tr(context, 'Recently saved', 'Mới lưu'),
        action: TextButton(
          key: const Key('recent-all'),
          onPressed: onAll,
          child: Text(tr(context, 'See all', 'Xem tất cả')),
        ),
        // Cards, as everywhere else: two across on a phone, more on a
        // wider screen, two rows.
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final columns = (box.maxWidth / (140 * scale.clamp(1.0, 2.0)))
                .floor()
                .clamp(1, 4);
            const gap = HandySpace.m;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final b in recent.take(columns * 2))
                  SizedBox(
                    width: width,
                    child: _RecentCard(
                      scope: scope,
                      bookmark: b,
                      onOpen: () => onOpen(b),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One recent save as a card: its picture, title and where it is from or
/// where it went; "Put in" under it while it is not sorted.
class _RecentCard extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  final VoidCallback onOpen;
  const _RecentCard({
    required this.scope,
    required this.bookmark,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final b = bookmark;
    final home = collectionOf(scope.library, b.collectionId);
    final later = readLaterAt(b, DateTime.now());
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(BookmarkRadii.thumb),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('recent-${b.id}'),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ItemPicture(scope.c, b, radius: BookmarkRadii.thumb),
                  if (later != null)
                    Positioned(top: 0, left: 10, child: ReadLaterRibbon(later)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
              child: Text(
                b.title.isEmpty ? b.sourceDomain : b.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    if (home != null) collectionSpan(context, home),
                    TextSpan(
                      text: [
                        if (!b.isImage) sourceLine(b),
                        ago(context, b.savedAt),
                      ].join(' · '),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
