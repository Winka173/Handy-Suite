import 'dart:typed_data';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'collection_actions.dart';

/// The cover of a collection: its chosen item, else its first owned item
/// with a photo, else its first owned item (a wish is never the cover
/// unless nothing is owned yet).
InventoryAsset? coverOf(KeepState s, InventoryCollection c) {
  final all = collectionItems(s, c.id);
  final owned = all.where((a) => a.owned).toList();
  final items = owned.isEmpty ? all : owned;
  if (c.coverAssetId.isNotEmpty) {
    final chosen = items.where((a) => a.id == c.coverAssetId).firstOrNull;
    if (chosen != null) return chosen;
  }
  return items.where((a) => a.photoUri.isNotEmpty).firstOrNull ??
      items.firstOrNull;
}

/// Collections on the home screen, as covers standing on a shelf. With no
/// collection yet it is one quiet row, so a home without collections is
/// not cluttered.
class CollectionShelf extends StatelessWidget {
  final KeepScope scope;
  const CollectionShelf({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final c = HandyColors.of(context);
    final wanted = s.assets.where((a) => !a.owned).length;
    if (s.collections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: HandySpace.l),
        child: HandyGroup(
          children: [
            HandyTile(
              key: const Key('shelf-start'),
              icon: Icons.collections_bookmark_outlined,
              title: tr(context, 'Collect something?', 'Sưu tầm thứ gì?'),
              subtitle: tr(
                context,
                'Figures, cards, books, games: see them as a shelf, with what is still missing',
                'Figure, thẻ, sách, game: xem như một kệ, biết còn thiếu món nào',
              ),
              navigates: true,
              onTap: () => _new(context),
            ),
            HandyTile(
              key: const Key('shelf-sample'),
              icon: Icons.play_circle_outline,
              title: tr(context, 'Try a sample shelf', 'Thử một kệ mẫu'),
              subtitle: tr(
                context,
                'Four board games; remove it in one tap',
                'Bốn board game; gỡ bằng một chạm',
              ),
              onTap: () => scope.addSample(context),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(
          tr(context, 'Collections', 'Bộ sưu tập'),
          trailing: TextButton(
            key: const Key('collection-new'),
            onPressed: () => _new(context),
            child: Text(tr(context, 'New', 'Tạo bộ')),
          ),
        ),
        SizedBox(
          height: 176,
          child: Stack(
            children: [
              // The shelf board the covers stand on.
              Positioned(
                left: 0,
                right: 0,
                top: 120,
                child: Container(height: 6, color: c.border),
              ),
              ListView(
                key: const Key('collection-shelf'),
                scrollDirection: Axis.horizontal,
                children: [
                  if (wanted > 0)
                    _Cover(
                      key: const Key('shelf-wishlist'),
                      title: tr(context, 'Wishlist', 'Muốn có'),
                      line: itemCount(context, wanted),
                      icon: Icons.favorite_border,
                      onTap: () => Navigator.pushNamed(context, '/wishlist'),
                    ),
                  for (final col in s.collections)
                    _Cover(
                      key: Key('shelf-${col.id}'),
                      title: col.name,
                      line: switch (collectionCompletion(s, col.id)) {
                        final d when d.target > 0 => '${d.owned}/${d.target}',
                        final d => itemCount(context, d.owned),
                      },
                      cover: coverOf(s, col),
                      hue: col.hue < 0 ? null : col.hue,
                      blobs: scope.store.library!.blobs,
                      onTap: () =>
                          Navigator.pushNamed(context, '/collection/${col.id}'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _new(BuildContext context) async {
    final made = await scope.editCollection(context);
    if (made != null && context.mounted) {
      await Navigator.pushNamed(context, '/collection/${made.id}');
    }
  }
}

class _Cover extends StatelessWidget {
  final String title, line;
  final InventoryAsset? cover;
  final IconData? icon;
  final int? hue;
  final Map<String, Uint8List> blobs;
  final VoidCallback onTap;
  const _Cover({
    super.key,
    required this.title,
    required this.line,
    required this.onTap,
    this.cover,
    this.icon,
    this.hue,
    this.blobs = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final tint = hue == null ? c.select : HandyPalette.of(context, hue!).tint;
    return Semantics(
      button: true,
      label: '$title, $line',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: HandySpace.m),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(HandyRadius.control),
            child: SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 120,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: cover != null
                          ? CoverTile(
                              item: cover!,
                              blobs: blobs,
                              size: 104,
                              hue: hue,
                            )
                          : Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: tint,
                                borderRadius: BorderRadius.circular(
                                  HandyRadius.control,
                                ),
                              ),
                              child: Icon(icon ?? Icons.collections_outlined),
                            ),
                    ),
                  ),
                  const SizedBox(height: HandySpace.s + 6),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An item's photo, or for an item without one a pale tile of the
/// collection's hue with the initial in its mark colour: quiet enough that
/// a grid of them still reads as a shelf, not as a row of letters.
class CoverTile extends StatelessWidget {
  final InventoryAsset item;
  final Map<String, Uint8List> blobs;
  final double size;
  final int? hue;
  const CoverTile({
    super.key,
    required this.item,
    required this.blobs,
    required this.size,
    this.hue,
  });

  @override
  Widget build(BuildContext context) {
    if (blobs[item.photoUri] != null) {
      return ItemThumb(item, blobs, size: size, hue: hue);
    }
    final c = HandyColors.of(context);
    final h = hue == null ? null : HandyPalette.of(context, hue!);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: h?.tint ?? c.select,
        borderRadius: BorderRadius.circular(HandyRadius.control),
      ),
      child: ExcludeSemantics(
        child: Text(
          item.name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: h?.mark ?? c.muted,
            fontSize: (size * 0.22).clamp(18, 36),
          ),
        ),
      ),
    );
  }
}
