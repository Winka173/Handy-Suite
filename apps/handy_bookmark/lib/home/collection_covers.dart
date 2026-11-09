import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../collections/collection_actions.dart';
import '../collections/identity.dart';
import '../collections/share_collection.dart';
import '../controller.dart';
import '../scope.dart';
import '../design/theme.dart';
import '../ui/collection_picker.dart';
import 'pastel_blocks.dart';
import '../view/library_view.dart';

/// The library as a shelf: every collection with a cover made from what is
/// in it (its newest pictures, or its newest titles set like a front page
/// when it has no pictures), its name and how much it holds.
class CollectionCovers extends StatelessWidget {
  final SaveScope scope;
  final ValueChanged<SaveCollection> onOpen;

  /// The whole list (Home shows its top-level collections, at most [limit],
  /// in the person's own order, and a See all).
  final VoidCallback? onAll;
  final int? limit;
  const CollectionCovers({
    super.key,
    required this.scope,
    required this.onOpen,
    this.onAll,
    this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final l = scope.library;
    final byCollection = <String, List<Bookmark>>{};
    for (final b in l.bookmarks) {
      if (b.collectionId != null && !b.isArchived)
        (byCollection[b.collectionId!] ??= []).add(b);
    }
    for (final list in byCollection.values) {
      list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    }
    final names = {for (final c in l.collections) c.id: c.name};
    // See all at the right of the heading; making one is a tile of its
    // own at the end of the grid, its words written out.
    final action = onAll == null
        ? null
        : TextButton(
            key: const Key('home-library'),
            onPressed: onAll,
            child: Text(
              tr(context, 'See all', 'Xem tất cả'),
              overflow: TextOverflow.ellipsis,
            ),
          );
    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (l.collections.isEmpty)
          Text(
            tr(
              context,
              'Group what you save by topic: Recipes, Trips, To buy…',
              'Gom đồ đã lưu theo chủ đề: Món ngon, Du lịch, Cần mua…',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HandyColors.of(context).muted,
            ),
          ),
        if (l.collections.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.m),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                width: 180,
                child: _NewCollectionTile(
                  onTap: () => scope.editCollection(context),
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final columns = (box.maxWidth / 170).floor().clamp(
                box.maxWidth < 300 ? 1 : 2,
                limit == null ? 5 : 6,
              );
              const gap = HandySpace.m;
              final width = (box.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: HandySpace.l,
                children: [
                  for (final (col, _) in [
                    for (final e in collectionTree(l))
                      if (limit == null || e.$1.parentId == null) e,
                  ].take(limit ?? 1 << 20))
                    SizedBox(
                      key: ValueKey('in-${col.id}'),
                      width: width,
                      child: HandyAppear(
                        child: CollectionCover(
                          scope: scope,
                          collection: col,
                          parent: col.parentId == null
                              ? null
                              : names[col.parentId],
                          hue: collectionHue(l, col.id),
                          items: byCollection[col.id] ?? const [],
                          cover: scope.view.chosenCover(col.id),
                          onOpen: () => onOpen(col),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: width,
                    child: _NewCollectionTile(
                      onTap: () => scope.editCollection(context),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
    // Home's shelf sits in a panel like Home's other blocks.
    return Padding(
      padding: EdgeInsets.zero,
      child: HomePanel(
        title: tr(context, 'Collections', 'Bộ sưu tập'),
        action: action,
        child: Padding(padding: const EdgeInsets.only(top: 4), child: grid),
      ),
    );
  }
}

/// A collection as it stands on the shelf: its cover (the chosen picture,
/// else up to three of its saves, else its colour and mark) over its name
/// and count. Without [onOpen] it is a still picture, as in the editor's
/// preview.
class CollectionCover extends StatelessWidget {
  final SaveScope scope;
  final SaveCollection collection;
  final String? parent;
  final int hue;
  final List<Bookmark> items;

  /// The picture the person chose for this cover, if it is still here.
  final Bookmark? cover;
  final VoidCallback? onOpen;
  const CollectionCover({
    super.key,
    required this.scope,
    required this.collection,
    required this.parent,
    required this.hue,
    required this.items,
    required this.cover,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pictures = items.where((b) => b.isImage).length;
    final links = items.length - pictures;
    final count = [
      if (links > 0 || pictures == 0)
        tr(context, links == 1 ? '1 link' : '$links links', '$links link'),
      if (pictures > 0)
        tr(
          context,
          pictures == 1 ? '1 picture' : '$pictures pictures',
          '$pictures ảnh',
        ),
    ].join(' · ');
    // The chosen picture alone; else pictures first, since a cover is what
    // the collection looks like.
    final shown = cover != null
        ? [cover!]
        : [
            ...items.where(hasPicture),
            ...items.where((b) => !hasPicture(b)),
          ].take(3).toList();
    final mark = markOf(collection.icon);
    // Not opened yet, as Focus counts them.
    final fresh = items.where((b) => !b.isRead && b.openedCount == 0).length;
    final freshWords = fresh == 0
        ? ''
        : tr(context, ', $fresh not opened', ', $fresh mục chưa xem');
    final f = hueField(context, hue);
    final dark = theme.brightness == Brightness.dark;
    final paper = dark
        ? Color.lerp(f.field, Colors.white, .06)!
        : Color.lerp(f.field, Colors.white, .45)!;
    // Up to two saves, pictures first: each shows its picture, or its title
    // set on paper in the tile when it has none; empty, its mark.
    final Widget face = shown.isEmpty
        ? _EmptyCover(hue: hue, mark: mark)
        : _mosaic([
            for (final b in shown.take(2))
              _CoverCell(
                controller: scope.c,
                bookmark: b,
                paper: paper,
                ink: f.ink,
              ),
          ]);
    return Semantics(
      button: onOpen != null,
      label: '${collection.name}, $count$freshWords',
      excludeSemantics: true,
      child: Material(
        color: f.field,
        borderRadius: BorderRadius.circular(BookmarkRadii.collection),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('collection-${collection.id}'),
          onTap: onOpen,
          // Held down or right-clicked: Send to friends, Edit.
          onLongPress: onOpen == null
              ? null
              : () => showCollectionQuick(context, scope, collection),
          onSecondaryTap: onOpen == null
              ? null
              : () => showCollectionQuick(context, scope, collection),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.55,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: face,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (mark != null) ...[
                            CollectionBadge(hue: hue, mark: mark, size: 9),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              collection.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: f.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              [if (parent != null) parent!, count].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: f.ink.withValues(alpha: .9),
                              ),
                            ),
                          ),
                          if (fresh > 0) ...[
                            const SizedBox(width: 6),
                            _New(
                              fresh,
                              key: Key('collection-new-${collection.id}'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mosaic(List<Widget> cells) => cells.length == 1
      ? cells.first
      : Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cells[0]),
            const SizedBox(width: 3),
            Expanded(child: cells[1]),
          ],
        );
}

/// One item on a cover: its picture, or its title set in the title face
/// on paper when it has none (never a letter in a box).
class _CoverCell extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final Color paper, ink;
  const _CoverCell({
    required this.controller,
    required this.bookmark,
    required this.paper,
    required this.ink,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = bookmark;
    final typeset = Container(
      color: paper,
      padding: const EdgeInsets.all(HandySpace.s),
      alignment: AlignmentDirectional.topStart,
      child: Text(
        b.title.isNotEmpty ? b.title : b.sourceDomain,
        maxLines: 4,
        overflow: TextOverflow.fade,
        style: theme.textTheme.bodySmall?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    );
    return FutureBuilder<Uint8List?>(
      future: b.media != null
          ? controller.mediaPreview(b.media!.id)
          : controller.thumbnail(b.id),
      builder: (context, snap) => snap.data == null
          ? typeset
          : Image.memory(
              snap.data!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => typeset,
            ),
    );
  }
}

/// A collection with nothing in it yet: its own colour and its mark (or a
/// folder), so even an empty shelf has a face.
class _EmptyCover extends StatelessWidget {
  final int hue;
  final CollectionMark? mark;
  const _EmptyCover({required this.hue, this.mark});
  @override
  Widget build(BuildContext context) {
    final h = HandyPalette.of(context, hue);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Color.lerp(h.mark, Colors.white, .35)! : h.mark;
    return ColoredBox(
      color: dark
          ? Color.lerp(BookmarkPalette.dark.raised, h.mark, .22)!
          : Color.lerp(Colors.white, h.mark, .14)!,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            switch (mark) {
              EmojiMark(:final emoji) => Text(
                emoji,
                style: const TextStyle(fontSize: 34, height: 1),
              ),
              IconMark(:final icon) => Icon(icon, color: ink, size: 30),
              null => Icon(Icons.folder_outlined, color: ink, size: 22),
            },
            Flexible(
              child: Text(
                tr(context, 'Nothing here yet', 'Chưa có gì'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How many saves in a collection are not opened yet: a small pale pill
/// in the app's hue, beside the count.
class _New extends StatelessWidget {
  final int count;
  const _New(this.count, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tr(context, '$count new', '$count mới'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: dark ? p.ink : p.pressed,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The last tile of the grid: make a collection, said in full.
class _NewCollectionTile extends StatelessWidget {
  final VoidCallback onTap;
  const _NewCollectionTile({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BookmarkRadii.collection),
        side: BorderSide(color: p.control, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('collection-new'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.55,
                child: Center(
                  child: Icon(
                    Icons.create_new_folder_outlined,
                    size: 34,
                    color: theme.brightness == Brightness.dark
                        ? p.primary
                        : p.pressed,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  tr(context, 'New collection', 'Bộ sưu tập mới'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.brightness == Brightness.dark
                        ? p.primary
                        : p.pressed,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  tr(
                    context,
                    'A name, an icon, a colour',
                    'Tên, biểu tượng, màu',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
