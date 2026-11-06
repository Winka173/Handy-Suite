import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';

/// One saved link: its picture, title, where it is from and when. Tapping
/// opens the original; the trailing button opens its details. While some
/// links are selected, tapping toggles instead.
class BookmarkTile extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final bool selecting, selected, current;
  final VoidCallback onOpen, onDetails, onToggle;
  const BookmarkTile({
    super.key,
    required this.controller,
    required this.bookmark,
    required this.onOpen,
    required this.onDetails,
    required this.onToggle,
    this.selecting = false,
    this.selected = false,
    this.current = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    final check = b.linkCheck;
    final broken = check != null && check.broken;
    final meta = [
      sourceLine(b),
      ago(context, b.savedAt),
      if (b.tags.isNotEmpty) b.tags.take(2).map((t) => '#$t').join(' '),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Semantics(
      selected: selected,
      child: ListTile(
        key: ValueKey('bookmark-${b.id}'),
        selected: selected || current,
        selectedTileColor: c.select,
        selectedColor: theme.colorScheme.onSurface,
        minVerticalPadding: HandySpace.m,
        onTap: selecting ? onToggle : onOpen,
        onLongPress: onToggle,
        leading: selecting
            ? SizedBox(
                width: 48,
                child: Checkbox(value: selected, onChanged: (_) => onToggle()),
              )
            : SizedBox(
                width: 60,
                height: 60,
                child: ItemPicture(controller, b, compact: true),
              ),
        title: Text(
          b.title.isEmpty ? b.sourceDomain : b.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          // Unread saves stand a little bolder than ones already read.
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 15.5,
            height: 1.3,
            fontWeight: b.isRead ? FontWeight.w500 : FontWeight.w600,
          ),
        ),
        subtitle: Text.rich(
          TextSpan(
            children: [
              // The check leads; only "gone" takes the warning colour, so
              // each row carries one mark at most.
              if (broken)
                TextSpan(
                  text: '${linkCheckLine(context, check)} · ',
                  style: TextStyle(
                    color: check.status == 'gone'
                        ? c.negative
                        : theme.colorScheme.onSurface,
                  ),
                ),
              if (collectionOf(controller.library, b.collectionId)
                  case final of?)
                collectionSpan(context, of),
              TextSpan(text: meta),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.readingIds.containsKey(b.id))
              Icon(
                Icons.offline_pin_outlined,
                size: 16,
                color: c.muted,
                semanticLabel: tr(context, 'Saved offline', 'Có bản offline'),
              ),
            if (b.isPinned)
              Icon(
                Icons.push_pin,
                size: 16,
                color: c.muted,
                semanticLabel: tr(context, 'Pinned', 'Đã ghim'),
              ),
            if (b.isFavorite)
              Icon(
                Icons.star,
                size: 16,
                color: c.muted,
                semanticLabel: tr(context, 'Favourite', 'Yêu thích'),
              ),
            IconButton(
              key: Key('details-${b.id}'),
              tooltip: tr(context, 'Details', 'Chi tiết'),
              icon: const Icon(Icons.chevron_right),
              onPressed: onDetails,
            ),
          ],
        ),
      ),
    );
  }
}
