import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import 'words.dart';

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

/// Marks on a card's picture, at its top right: a broken link (in words,
/// with an icon), New, and the favourite star.
class ItemCornerMarks extends StatelessWidget {
  final Bookmark bookmark;
  const ItemCornerMarks(this.bookmark, {super.key});
  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final p = BookmarkPalette.of(context);
    final fresh = isNewSave(b, DateTime.now());
    final check = b.linkCheck;
    final broken = check != null && check.broken;
    if (!fresh && !b.isFavorite && !broken) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (broken)
          Flexible(
            child: Container(
              key: Key('mark-broken-${b.id}'),
              padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(BookmarkRadii.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    check.status == 'moved' ? Icons.turn_right : Icons.link_off,
                    size: 15,
                    color: check.status == 'gone'
                        ? HandyColors.of(context).negative
                        : p.ink,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      check.status == 'unreachable'
                          ? tr(context, 'Not reachable', 'Không mở được')
                          : linkStatusWords(context, check),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (broken && (fresh || b.isFavorite)) const SizedBox(width: 6),
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
