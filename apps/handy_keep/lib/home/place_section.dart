import 'dart:typed_data';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/whereabouts.dart';
import '../ui/words.dart';

/// One place and the things in it. The place's name is the heading, set in
/// the display face: that is what the person came to read.
class PlaceSection extends StatelessWidget {
  final Place place;
  final Map<String, Uint8List> blobs;
  final String? selected;
  final ValueChanged<InventoryAsset> onOpen;
  final ValueChanged<InventoryBox>? onFocusBox;
  final List<HandyMenuItem> Function(InventoryBox)? boxActions;
  final bool hero;
  const PlaceSection({
    this.hero = false,
    super.key,
    required this.place,
    required this.blobs,
    required this.onOpen,
    this.selected,
    this.onFocusBox,
    this.boxActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final p = place;
    final box = p.box;
    final heading = Padding(
      padding: const EdgeInsets.fromLTRB(0, HandySpace.xl, 0, HandySpace.s),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: placeTitle(context, p),
                      style: theme.textTheme.titleLarge,
                    ),
                    TextSpan(
                      text:
                          '  ${[if (p.detail.isNotEmpty) p.detail, itemCount(context, p.items.length)].join(' · ')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (box != null && boxActions != null)
            HandyMenuButton(
              key: Key('box-menu-${box.id}'),
              tooltip: tr(context, 'Box actions', 'Thao tác với thùng'),
              items: boxActions!(box),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (box != null && onFocusBox != null)
          InkWell(
            key: Key('box-${box.id}'),
            onTap: () => onFocusBox!(box),
            child: heading,
          )
        else
          heading,
        if (p.items.isEmpty)
          Text(
            tr(context, 'Nothing packed yet.', 'Chưa có gì trong thùng.'),
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          )
        else
          HandyGroup(
            children: [
              for (final a in p.items)
                _ItemRow(
                  item: a,
                  blobs: blobs,
                  selected: a.id == selected,
                  hero: hero,
                  onTap: () => onOpen(a),
                ),
            ],
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final InventoryAsset item;
  final Map<String, Uint8List> blobs;
  final bool selected, hero;
  final VoidCallback onTap;
  const _ItemRow({
    required this.hero,
    required this.item,
    required this.blobs,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final a = item;
    final note = a.borrower.isNotEmpty && a.returnDue.isNotEmpty
        ? tr(
            context,
            'back by ${formatDay(context, a.returnDue)}',
            'hẹn trả ${formatDay(context, a.returnDue)}',
          )
        : null;
    return ListTile(
      key: Key('item-${a.id}'),
      selected: selected,
      selectedTileColor: c.select,
      selectedColor: c.selectInk,
      leading: ItemThumb(a, blobs, hero: hero),
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: note == null ? null : Text(note),
      onTap: onTap,
    );
  }
}
