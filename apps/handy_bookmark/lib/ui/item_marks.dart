import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// Opened this many times or more: "seen often", with its count.
const seenOften = 3;

/// Saved in the last two days and not opened yet.
bool isNewSave(Bookmark b, DateTime now) {
  if (b.isRead || b.openedCount > 0) return false;
  final saved = DateTime.tryParse(b.savedAt);
  return saved != null && now.toUtc().difference(saved).inHours < 48;
}

/// Small marks before a card's source line: a note, how often it was
/// opened. Each is an icon with words for screen readers, never colour
/// alone.
List<InlineSpan> itemMarkSpans(BuildContext context, Bookmark b) {
  final p = BookmarkPalette.of(context);
  WidgetSpan icon(IconData i, String label) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(i, size: 15, color: p.muted, semanticLabel: label),
    ),
  );
  return [
    if (b.note.trim().isNotEmpty)
      icon(
        Icons.sticky_note_2_outlined,
        tr(context, 'Has a note', 'Có ghi chú'),
      ),
    if (b.openedCount >= seenOften) ...[
      icon(Icons.visibility_outlined, tr(context, 'Opened often', 'Xem nhiều')),
      TextSpan(text: '${b.openedCount} · '),
    ],
  ];
}

/// Marks on a card's picture, at its top right: New, and the favourite
/// star.
class ItemCornerMarks extends StatelessWidget {
  final Bookmark bookmark;
  const ItemCornerMarks(this.bookmark, {super.key});
  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final p = BookmarkPalette.of(context);
    final fresh = isNewSave(b, DateTime.now());
    if (!fresh && !b.isFavorite) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fresh)
          Container(
            key: Key('mark-new-${b.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: p.band,
              borderRadius: BorderRadius.circular(BookmarkRadii.chip),
            ),
            child: Text(
              tr(context, 'New', 'Mới'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: p.bandInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (fresh && b.isFavorite) const SizedBox(width: 6),
        if (b.isFavorite)
          Container(
            key: Key('mark-favourite-${b.id}'),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
            child: Icon(
              Icons.star_rounded,
              size: 16,
              color: p.gold,
              semanticLabel: tr(context, 'Favourite', 'Yêu thích'),
            ),
          ),
      ],
    );
  }
}
