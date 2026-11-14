import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ui/item_marks.dart';
import '../ui/read_later_ribbon.dart';
import 'pastel_blocks.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../library/bookmark_tile.dart';
import '../ui/card_head.dart';
import '../ui/view_toggle.dart';
import '../ui/words.dart';

/// The last few saves, newest first: a short confirmation of what just
/// came in, not a feed. As cards (two rows of them) or as rows, the
/// person's choice beside the heading, kept for Home on its own.
class RecentlySaved extends StatelessWidget {
  final SaveScope scope;
  final ValueChanged<Bookmark> onOpen;
  final VoidCallback onAll;

  /// Up to this many across (six on the wide overview).
  final int maxColumns;
  const RecentlySaved({
    super.key,
    required this.scope,
    required this.onOpen,
    required this.onAll,
    this.maxColumns = 4,
  });

  /// Where Home keeps the choice.
  static const pref = 'cards:home';

  @override
  Widget build(BuildContext context) {
    final l = scope.library;
    final c = scope.c;
    final recent = [
      for (final b in l.bookmarks)
        if (!b.isArchived) b,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (recent.isEmpty) return const SizedBox.shrink();
    final cards = c.preferences[pref] != false;
    return HomePanel(
      key: const Key('recent'),
      title: tr(context, 'Recently saved', 'Mới lưu'),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ViewToggle(
            cards: cards,
            onChanged: (v) =>
                c.update((l) => l, prefs: {...c.preferences, pref: v}),
          ),
          const SizedBox(width: HandySpace.xs),
          Flexible(
            child: TextButton(
              key: const Key('recent-all'),
              onPressed: onAll,
              child: Text(
                tr(context, 'See all', 'Xem tất cả'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
      child: HandySwap(
        child: KeyedSubtree(
          key: ValueKey('recent-$cards'),
          child: cards ? _cards(context, recent) : _rows(recent),
        ),
      ),
    );
  }

  Widget _rows(List<Bookmark> recent) => HandyGroup(
    children: [
      for (final b in recent.take(6))
        BookmarkTile(
          key: ValueKey('in-${b.id}'),
          controller: scope.c,
          bookmark: b,
          onOpen: () => onOpen(b),
          onDetails: () => onOpen(b),
          onToggle: () => onOpen(b),
        ),
    ],
  );

  /// Two rows of cards: two across on a phone, more on a wider screen.
  /// Each row is as tall as its tallest card, so the rows end level.
  Widget _cards(BuildContext context, List<Bookmark> recent) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = (box.maxWidth / (140 * scale.clamp(1.0, 2.0)))
          .floor()
          .clamp(1, maxColumns);
      const gap = HandySpace.m;
      final shown = recent.take(columns * 2).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shown.length; i += columns) ...[
            if (i > 0) const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var k = i; k < i + columns; k++) ...[
                    if (k > i) const SizedBox(width: gap),
                    Expanded(
                      child: k < shown.length
                          ? HandyAppear(
                              key: ValueKey('in-${shown[k].id}'),
                              child: _RecentCard(
                                scope: scope,
                                bookmark: shown[k],
                                onOpen: () => onOpen(shown[k]),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// One recent save as a card: its picture (or a low strip of where it is
/// from), title and where it went.
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
    final title = theme.textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.w600,
    );
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
            CardHead(
              controller: scope.c,
              bookmark: b,
              aspectRatio: 4 / 3,
              overlay: [
                if (later != null)
                  Positioned(top: 0, left: 10, child: ReadLaterRibbon(later)),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  // Bounded, so a long broken-link mark shortens.
                  child: Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: ItemCornerMarks(b),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: itemTitle(
                context,
                b,
                maxLines: CardHead.pictured(scope.c, b) ? 2 : 4,
                style: title,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text.rich(
                TextSpan(
                  children: [
                    ...itemMarkSpans(context, b),
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
