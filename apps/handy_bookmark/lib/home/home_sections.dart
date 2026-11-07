import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';
import 'triage_strip.dart';

/// How many saves wait to be opened, from the real read state, as one
/// compact card into Focus. With nothing waiting it is one calm line.
class FocusNudge extends StatelessWidget {
  final SaveScope scope;
  final VoidCallback onOpen;
  const FocusNudge({super.key, required this.scope, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final waiting = [
      for (final b in scope.library.bookmarks)
        if (!b.isArchived && !b.isRead) b,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final n = waiting.length;
    if (n == 0) {
      return Semantics(
        button: true,
        child: InkWell(
          key: const Key('place-focus'),
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20, color: p.sage),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(
                      context,
                      'All caught up. Nothing waiting in Focus.',
                      'Đã xem hết. Không còn gì chờ trong Tập trung.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final count = formatFigure(context, '$n');
    final title = tr(
      context,
      n == 1
          ? '1 thing waiting to revisit'
          : '$count things waiting to revisit',
      '$count mục chờ bạn xem lại',
    );
    // Fewer faces on narrow screens, so the words keep their room.
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final faces = waiting.take(narrow ? 1 : 3).toList();
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: p.tint,
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('place-focus'),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 44.0 + 20 * (faces.length - 1),
                  height: 44,
                  child: Stack(
                    children: [
                      for (final (i, b) in faces.indexed.toList().reversed)
                        Positioned(
                          left: 20.0 * i,
                          child: Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: p.tint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ItemPicture(
                              scope.c,
                              b,
                              radius: 10,
                              compact: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(
                          context,
                          'One at a time, in Focus',
                          'Từng mục một, trong Tập trung',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: p.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    return Column(
      key: const Key('recent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHead(
          tr(context, 'Recently saved', 'Mới lưu'),
          action: TextButton(
            key: const Key('recent-all'),
            onPressed: onAll,
            child: Text(tr(context, 'See all', 'Xem tất cả')),
          ),
        ),
        // Cards, as everywhere else: two across on a phone, more on a
        // wider screen, two rows.
        LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final columns = (box.maxWidth / (165 * scale.clamp(1.0, 2.0)))
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
      ],
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
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('recent-${b.id}'),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 4 / 3, child: ItemPicture(scope.c, b)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
            if (b.collectionId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: PutIn(
                  controller: scope.c,
                  bookmark: b,
                  onFile: scope.file,
                  compact: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
