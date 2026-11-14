import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ui/item_marks.dart';
import '../bookmark/item_menu.dart';
import '../controller.dart';
import '../design/theme.dart';
import '../ui/card_head.dart';
import '../ui/collection_picker.dart';
import '../ui/words.dart';

/// A save as a gallery card: its picture large (or its source's face),
/// two lines of title and one of where it is from. Tapping opens the
/// original (or the picture); the corner "…" opens its menu (details,
/// rename, share, move, delete).
class LinkCard extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final bool selecting, selected;
  final VoidCallback onOpen, onDetails, onToggle;

  /// Not sorted: its "Put in" beside the menu.
  final Widget? putIn;
  const LinkCard({
    this.putIn,
    super.key,
    required this.controller,
    required this.bookmark,
    required this.onOpen,
    required this.onDetails,
    required this.onToggle,
    this.selecting = false,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final home = collectionOf(controller.library, b.collectionId);
    Widget badge(Widget child) => DecoratedBox(
      decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
      child: child,
    );
    return Material(
      key: ValueKey('card-${b.id}'),
      color: selected ? p.tint : p.surface,
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selecting ? onToggle : onOpen,
        onLongPress: onToggle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardHead(
              controller: controller,
              bookmark: b,
              aspectRatio: 1.28,
              overlay: [
                if (selecting)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: badge(
                      Checkbox(
                        value: selected,
                        shape: const CircleBorder(),
                        onChanged: (_) => onToggle(),
                      ),
                    ),
                  ),
                if (!selecting)
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 0, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Without a picture the title has the room.
                          itemTitle(
                            context,
                            b,
                            maxLines: CardHead.pictured(controller, b) ? 2 : 4,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.28,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text.rich(
                            TextSpan(
                              children: [
                                ...itemMarkSpans(context, b),
                                if (home != null) collectionSpan(context, home),
                                TextSpan(
                                  text: b.isImage
                                      ? tr(context, 'Picture', 'Ảnh')
                                      : sourceLine(b),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    // 48 × 48 (the least a finger needs): the card's
                    // corner, nudged up into the padding.
                    Transform.translate(
                      offset: const Offset(0, -6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ?putIn,
                          ItemMenuButton(
                            bookmark: b,
                            onDetails: onDetails,
                            width: 48,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
