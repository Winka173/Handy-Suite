import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../ui/collection_picker.dart';
import '../ui/words.dart';

/// A link as a card: its picture large, for collections of videos,
/// products and places that are recognised by sight.
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
    final c = HandyColors.of(context);
    return Card(
      key: ValueKey('card-${b.id}'),
      color: selected ? c.select : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selecting ? onToggle : onOpen,
        onLongPress: onToggle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  LinkThumb(controller, b, size: box.maxWidth, height: 128),
                  if (selecting)
                    Positioned(
                      top: HandySpace.xs,
                      left: HandySpace.xs,
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => onToggle(),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HandySpace.m,
                HandySpace.s,
                0,
                0,
              ),
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
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              if (collectionOf(
                                    controller.library,
                                    b.collectionId,
                                  )
                                  case final of?)
                                collectionSpan(context, of),
                              TextSpan(text: sourceLine(b)),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('details-${b.id}'),
                    tooltip: tr(context, 'Details', 'Chi tiết'),
                    icon: const Icon(Icons.more_vert),
                    onPressed: onDetails,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
