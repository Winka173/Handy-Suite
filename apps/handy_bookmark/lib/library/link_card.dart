import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';

/// A save as a gallery card: its picture large (or its source's face),
/// two lines of title and one of where it is from. Tapping opens the
/// original (or the picture); the corner button opens its details.
class LinkCard extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final bool selecting, selected;
  final VoidCallback onOpen, onDetails, onToggle;
  const LinkCard({
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
            AspectRatio(
              aspectRatio: 1.28,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ItemPicture(controller, b, radius: 0),
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
                  if (b.isFavorite && !selecting)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: badge(
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: p.warm,
                            semanticLabel: tr(
                              context,
                              'Favourite',
                              'Yêu thích',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
                          Text(
                            b.title.isEmpty ? b.sourceDomain : b.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.28,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text.rich(
                            TextSpan(
                              children: [
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
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        key: Key('details-${b.id}'),
                        tooltip: tr(context, 'Details', 'Chi tiết'),
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_horiz, color: p.muted),
                        onPressed: onDetails,
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
