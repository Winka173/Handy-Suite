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
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
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
        for (final b in recent.take(shown))
          InkWell(
            key: Key('recent-${b.id}'),
            borderRadius: BorderRadius.circular(BookmarkRadii.item),
            onTap: () => onOpen(b),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: ItemPicture(scope.c, b, compact: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.title.isEmpty ? b.sourceDomain : b.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (!b.isImage) sourceLine(b),
                            ago(context, b.savedAt),
                            if (collectionOf(l, b.collectionId) case final c?)
                              c.$1.name,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (b.collectionId == null)
                    PutIn(
                      controller: scope.c,
                      bookmark: b,
                      onFile: scope.file,
                      compact: true,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
