import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';

/// One saved thing in the Focus deck: its picture edge to edge, its title,
/// where it is from and when it was saved, a little of its description,
/// and Open. On a small card or with large text the description goes
/// first, then the picture shrinks; the words never overflow.
class FocusCard extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;

  /// The top card floats, so it alone carries a soft shadow.
  final bool lifted;
  const FocusCard({
    super.key,
    required this.scope,
    required this.bookmark,
    this.lifted = false,
  });
  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final dark = theme.brightness == Brightness.dark;
    final home = collectionOf(scope.library, b.collectionId);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BookmarkRadii.focus),
        boxShadow: lifted
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .28 : .10),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(BookmarkRadii.focus),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, box) {
            final roomy = box.maxHeight > 300 * scale.clamp(1.0, 2.0) + 160;
            final words = Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      b.title.isNotEmpty
                          ? b.title
                          : b.isImage
                          ? tr(context, 'Picture', 'Ảnh')
                          : b.sourceDomain,
                      maxLines: roomy ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 21,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (home != null) collectionSpan(context, home),
                        TextSpan(
                          text:
                              '${b.isImage ? tr(context, 'Picture', 'Ảnh') : sourceLine(b)} · ${tr(context, 'saved', 'lưu')} ${ago(context, b.savedAt)}',
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (roomy && (b.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: HandySpace.s),
                    Text(
                      b.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const Key('focus-open'),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.tint,
                      foregroundColor: dark ? p.ink : p.pressed,
                      minimumSize: const Size(48, 44),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => scope.open(context, b),
                    icon: Icon(
                      b.hasUrl ? Icons.open_in_new : Icons.fullscreen,
                      size: 20,
                    ),
                    label: Text(
                      b.hasUrl
                          ? tr(context, 'Open original', 'Mở bản gốc')
                          : tr(context, 'View picture', 'Xem ảnh'),
                    ),
                  ),
                ],
              ),
            );
            // Too short for a picture (a small window, very large text):
            // the words alone, scrolling if they must.
            if (box.maxHeight < 180 * scale.clamp(1.0, 3.0) + 120)
              return SingleChildScrollView(child: words);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ItemPicture(scope.c, b, radius: 0)),
                words,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The word that appears on the card while it is dragged toward a side:
/// it grows in as the card nears the point where letting go counts.
class SwipeLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final double opacity;
  final Color background, foreground;
  const SwipeLabel({
    super.key,
    required this.text,
    required this.icon,
    required this.opacity,
    required this.background,
    required this.foreground,
  });
  @override
  Widget build(BuildContext context) {
    final o = opacity.clamp(0.0, 1.0);
    return IgnorePointer(
      child: Opacity(
        opacity: o,
        child: Transform.scale(
          scale: .9 + .1 * o,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: ShapeDecoration(
              color: background,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
