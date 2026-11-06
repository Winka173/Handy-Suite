import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../collections/collection_actions.dart';
import '../controller.dart';
import '../scope.dart';
import '../design/theme.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHead(
          tr(context, 'Collections', 'Bộ sưu tập'),
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onAll != null)
                TextButton(
                  key: const Key('home-library'),
                  onPressed: onAll,
                  child: Text(tr(context, 'See all', 'Xem tất cả')),
                ),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: BookmarkPalette.of(context).surface,
                ),
                key: const Key('collection-new'),
                tooltip: tr(context, 'New collection', 'Bộ sưu tập mới'),
                // A folder, not a plus: the one + on Home is Save.
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () => scope.editCollection(context),
              ),
            ],
          ),
        ),
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
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final columns = (box.maxWidth / 170).floor().clamp(
                box.maxWidth < 300 ? 1 : 2,
                5,
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
                      width: width,
                      child: _Cover(
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
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  final SaveScope scope;
  final SaveCollection collection;
  final String? parent;
  final int hue;
  final List<Bookmark> items;

  /// The picture the person chose for this cover, if it is still here.
  final Bookmark? cover;
  final VoidCallback onOpen;
  const _Cover({
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
    final c = HandyColors.of(context);
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
    return Semantics(
      button: true,
      label: '${collection.name}, $count',
      excludeSemantics: true,
      child: InkWell(
        key: Key('collection-${collection.id}'),
        onTap: onOpen,
        onLongPress: () => scope.editCollection(context, collection),
        borderRadius: BorderRadius.circular(BookmarkRadii.collection),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(BookmarkRadii.collection),
                child: shown.isEmpty
                    ? _EmptyCover(name: collection.name, hue: hue)
                    : _mosaic(shown),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                HandyDot(hue, size: 9),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              [if (parent != null) parent!, count].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mosaic(List<Bookmark> shown) {
    Widget cell(Bookmark b) => _CoverCell(controller: scope.c, bookmark: b);
    return switch (shown.length) {
      1 => cell(shown[0]),
      2 => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cell(shown[0])),
          const SizedBox(width: 3),
          Expanded(child: cell(shown[1])),
        ],
      ),
      _ => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: cell(shown[0])),
          const SizedBox(width: 3),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cell(shown[1])),
                const SizedBox(height: 3),
                Expanded(child: cell(shown[2])),
              ],
            ),
          ),
        ],
      ),
    };
  }
}

/// One item on a cover: its picture, or its title set in the title face
/// on paper when it has none (never a letter in a box).
class _CoverCell extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  const _CoverCell({required this.controller, required this.bookmark});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final b = bookmark;
    final typeset = Container(
      color: c.raised,
      padding: const EdgeInsets.all(HandySpace.s),
      alignment: AlignmentDirectional.topStart,
      child: Text(
        b.title.isNotEmpty ? b.title : b.sourceDomain,
        maxLines: 4,
        overflow: TextOverflow.fade,
        style: theme.textTheme.titleSmall?.copyWith(
          fontFamily: handyFontFamily('Newsreader'),
          height: 1.15,
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

/// A collection with nothing in it yet: its own colour, a folder and its
/// first letter, so even an empty shelf has a face.
class _EmptyCover extends StatelessWidget {
  final String name;
  final int hue;
  const _EmptyCover({required this.name, required this.hue});
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
            Icon(Icons.folder_outlined, color: ink, size: 22),
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
