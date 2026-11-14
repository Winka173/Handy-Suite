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

/// Small marks before a card's source line: the favourite star, a note,
/// how often it was opened. Each is an icon with words for screen readers,
/// never colour alone; nothing is laid over the picture.
List<InlineSpan> itemMarkSpans(BuildContext context, Bookmark b) {
  final p = BookmarkPalette.of(context);
  WidgetSpan icon(IconData i, String label, {Color? color, Key? key}) =>
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          key: key,
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            i,
            size: 15,
            color: color ?? p.muted,
            semanticLabel: label,
          ),
        ),
      );
  return [
    if (b.isFavorite)
      icon(
        Icons.star_rounded,
        tr(context, 'Favourite', 'Yêu thích'),
        color: p.gold,
        key: Key('mark-favourite-${b.id}'),
      ),
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

/// A card's title in [style]; a save not opened yet (saved in the last two
/// days) has a small dot in the app's hue before it, centred on the first
/// line, read as "New".
Widget itemTitle(
  BuildContext context,
  Bookmark b, {
  required TextStyle? style,
  int maxLines = 2,
}) {
  final text = Text(
    b.title.isEmpty ? b.sourceDomain : b.title,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
  if (!isNewSave(b, DateTime.now())) return text;
  final line = MediaQuery.textScalerOf(
    context,
  ).scale((style?.fontSize ?? BookmarkType.body) * (style?.height ?? 1.3));
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        key: Key('mark-new-${b.id}'),
        padding: EdgeInsetsDirectional.only(top: (line - 8) / 2, end: 6),
        child: Semantics(
          label: tr(context, 'New', 'Mới'),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: BookmarkPalette.of(context).primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      Expanded(child: text),
    ],
  );
}

/// The one mark left on a card's picture, at its top right: a broken link,
/// in words with an icon, since it changes what tapping will do.
class ItemCornerMarks extends StatelessWidget {
  final Bookmark bookmark;
  const ItemCornerMarks(this.bookmark, {super.key});
  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final p = BookmarkPalette.of(context);
    final check = b.linkCheck;
    if (check == null || !check.broken) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
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
    );
  }
}
