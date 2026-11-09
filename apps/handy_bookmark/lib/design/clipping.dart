import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../ui/visual.dart';
import '../ui/words.dart';
import 'theme.dart';

/// The onboarding's face, for the app's own sheets: a Newsreader title
/// with a pale band under its key words, saved things as paper clippings
/// (picture, the source by name, the title in Newsreader), and one tall
/// primary button. Colours come from the theme, so dark mode follows.

/// A sheet's title: [before], then [words] over a pale band of the hue.
class SheetTitle extends StatelessWidget {
  final String before, words, after;
  const SheetTitle({
    super.key,
    this.before = '',
    required this.words,
    this.after = '',
  });

  static TextStyle style(BuildContext context) => TextStyle(
    fontFamily: handyFontFamily('Newsreader'),
    fontSize: 28,
    height: 1.1,
    letterSpacing: -.4,
    fontWeight: FontWeight.w500,
    color: BookmarkPalette.of(context).ink,
  );

  @override
  Widget build(BuildContext context) {
    final s = style(context);
    return Semantics(
      header: true,
      label: '$before$words$after',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: s,
          children: [
            TextSpan(text: before),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: CustomPaint(
                painter: _Band(BookmarkPalette.of(context).tint),
                child: Text('$words$after', style: s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Band extends CustomPainter {
  final Color color;
  const _Band(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * .34;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -2,
          size.height - h - size.height * .08,
          size.width + 4,
          h,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_Band old) => old.color != color;
}

/// The primary button of a sheet, as in the onboarding: tall and full
/// width.
ButtonStyle sheetButtonStyle(BuildContext context) => FilledButton.styleFrom(
  minimumSize: const Size(double.infinity, 56),
  textStyle: Theme.of(
    context,
  ).textTheme.labelLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

/// Where a save came from, by name in its colour (never a logo): the
/// platform, "Picture" for a picture, else the site.
class SourceTag extends StatelessWidget {
  final Bookmark bookmark;
  const SourceTag(this.bookmark, {super.key});

  static Color colorOf(Bookmark b) => switch (b.platform) {
    'tiktok' || 'x' || 'threads' => const Color(0xFF111111),
    'facebook' => const Color(0xFF1877F2),
    'youtube' => const Color(0xFFD9251D),
    'instagram' => const Color(0xFFC13584),
    'reddit' => const Color(0xFFD93A00),
    'pinterest' => const Color(0xFFBD081C),
    'spotify' => const Color(0xFF1C7C45),
    _ => const Color(0xFF5B5E63),
  };

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final name = b.isImage
        ? tr(context, 'Picture', 'Ảnh chụp')
        : sourceName(b.platform).isNotEmpty
        ? sourceName(b.platform)
        : b.sourceDomain;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorOf(b),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A saved thing as a paper clipping, side by side: its picture, then its
/// source and its title in Newsreader.
class Clipping extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;

  /// Shown under the title instead of nothing (for example "and 2 more").
  final String? note;
  const Clipping({
    super.key,
    required this.controller,
    required this.bookmark,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final b = bookmark;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1F0B2A33),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 88,
              height: 66,
              child: ItemPicture(controller, b, compact: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SourceTag(b),
                const SizedBox(height: 6),
                Text(
                  b.title.isEmpty ? b.sourceDomain : b.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: handyFontFamily('Newsreader'),
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                    color: p.ink,
                  ),
                ),
                if (note != null)
                  Text(
                    note!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: p.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A saved thing as a standing clipping, as in the onboarding's cards:
/// its picture (4:3), its source by name, its title in Newsreader.
class ClippingTile extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final VoidCallback onTap;
  const ClippingTile({
    super.key,
    required this.controller,
    required this.bookmark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final b = bookmark;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = b.title.isEmpty ? b.sourceDomain : b.title;
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      // The onboarding's soft, wide shadow (none on dark grounds).
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: dark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x1F0B2A33),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: Key('clip-${b.id}'),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      // Only the mark: the source is named just below.
                      child: ItemPicture(controller, b, compact: true),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SourceTag(b),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: handyFontFamily('Newsreader'),
                      fontSize: 16,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                      color: p.ink,
                    ),
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
