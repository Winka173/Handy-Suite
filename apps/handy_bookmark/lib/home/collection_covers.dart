import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../collections/collection_actions.dart';
import '../controller.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';

/// The library as a shelf: every collection with a cover made from what is
/// in it (its newest pictures, or its newest titles set like a front page
/// when it has no pictures), its name and how much it holds.
class CollectionCovers extends StatelessWidget {
  final SaveScope scope;
  final ValueChanged<SaveCollection> onOpen;
  const CollectionCovers({
    super.key,
    required this.scope,
    required this.onOpen,
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
        HandyLabel(
          tr(context, 'Collections', 'Bộ sưu tập'),
          trailing: IconButton(
            key: const Key('collection-new'),
            tooltip: tr(context, 'New collection', 'Bộ sưu tập mới'),
            icon: const Icon(Icons.add),
            onPressed: () => scope.editCollection(context),
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
              final columns = (box.maxWidth / 180).floor().clamp(2, 5);
              const gap = HandySpace.m;
              final width = (box.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: HandySpace.l,
                children: [
                  for (final (col, _) in collectionTree(l))
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
  final VoidCallback onOpen;
  const _Cover({
    required this.scope,
    required this.collection,
    required this.parent,
    required this.hue,
    required this.items,
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
        tr(context, '$links links', '$links link'),
      if (pictures > 0) tr(context, '$pictures pictures', '$pictures ảnh'),
    ].join(' · ');
    // Pictures first: a cover is what the collection looks like.
    final shown = [
      ...items.where((b) => b.media != null || b.thumbnailUrl != null),
      ...items.where((b) => b.media == null && b.thumbnailUrl == null),
    ].take(3).toList();
    return Semantics(
      button: true,
      label: '${collection.name}, $count',
      excludeSemantics: true,
      child: InkWell(
        key: Key('collection-${collection.id}'),
        onTap: onOpen,
        onLongPress: () => scope.editCollection(context, collection),
        borderRadius: BorderRadius.circular(HandyRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(HandyRadius.card),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(HandyRadius.card),
                  child: shown.isEmpty
                      ? Center(
                          child: Text(
                            tr(context, 'Empty', 'Chưa có gì'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: c.muted,
                            ),
                          ),
                        )
                      : _mosaic(shown),
                ),
              ),
            ),
            const SizedBox(height: HandySpace.s),
            Row(
              children: [
                HandyDot(hue, size: 8),
                const SizedBox(width: HandySpace.xs),
                Expanded(
                  child: Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
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
          const SizedBox(width: 2),
          Expanded(child: cell(shown[1])),
        ],
      ),
      _ => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: cell(shown[0])),
          const SizedBox(width: 2),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cell(shown[1])),
                const SizedBox(height: 2),
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
