import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';
import 'words.dart';

/// The icon for what a save is: a video, a post, an article, a place, a
/// shop item, a picture, or a plain page.
IconData kindIcon(Bookmark b) {
  if (b.isImage) return Icons.image_outlined;
  return switch (b.contentType) {
    'video' => Icons.play_circle_outline,
    'post' => Icons.chat_bubble_outline,
    'article' => Icons.article_outlined,
    'place' => Icons.place_outlined,
    'product' => Icons.shopping_bag_outlined,
    _ => switch (b.platform) {
      'shopee' || 'lazada' || 'tiki' => Icons.shopping_bag_outlined,
      'github' => Icons.code,
      _ => Icons.public,
    },
  };
}

/// The colour index a source keeps everywhere (a site's saves look alike).
int sourceHue(Bookmark b) => HandyPalette.forKey(
  b.isImage
      ? 'picture'
      : (b.platform.isNotEmpty && b.platform != 'web'
            ? b.platform
            : b.sourceDomain),
);

/// What a save looks like when it has no picture: a pale field of its
/// source's colour with what it is (a play mark for a video, a bag for a
/// shop item) and where it is from. Never a fake photograph.
class SourceFace extends StatelessWidget {
  final Bookmark bookmark;

  /// Small faces (list thumbnails) show only the mark.
  final bool compact;
  const SourceFace(this.bookmark, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final hue = HandyPalette.of(context, sourceHue(bookmark));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Color.lerp(hue.mark, Colors.white, .35)! : hue.mark;
    final b = bookmark;
    final source = sourceName(b.platform).isNotEmpty
        ? sourceName(b.platform)
        : b.sourceDomain.replaceFirst(RegExp(r'^www\.'), '');
    return ExcludeSemantics(
      child: ColoredBox(
        color: dark
            ? Color.lerp(BookmarkPalette.dark.raised, hue.mark, .22)!
            : Color.lerp(Colors.white, hue.mark, .13)!,
        child: LayoutBuilder(
          builder: (context, box) {
            final small = compact || box.maxHeight < 90;
            final mark = Icon(
              kindIcon(b),
              color: ink,
              size: (box.biggest.shortestSide * (small ? .42 : .28)).clamp(
                16.0,
                44.0,
              ),
            );
            if (small || source.isEmpty) return Center(child: mark);
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  mark,
                  const Spacer(),
                  Text(
                    source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A save's picture: the stored preview of a picture, the page's small
/// thumbnail for a link, or its [SourceFace]. Only previews are decoded
/// here, never an original.
/// The last check found the page gone, or no site answered: shown greyed,
/// never removed. A moved page still opens, so it is not greyed.
bool linkDead(Bookmark b) {
  final s = b.linkCheck?.status;
  return s == 'gone' || s == 'unreachable';
}

const _grey = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

class ItemPicture extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final double radius;
  final bool compact;
  const ItemPicture(
    this.controller,
    this.bookmark, {
    super.key,
    this.radius = BookmarkRadii.thumb,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final face = SourceFace(bookmark, compact: compact);
    // Saved already; its page is being read for a title and picture.
    final reading = controller.fetching.containsKey(bookmark.id);
    final picture = reading
        ? ReadingShade(child: _picture(face))
        : _picture(face);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      // A link that no longer opens keeps its place, greyed and faded.
      child: linkDead(bookmark)
          ? Opacity(
              opacity: .5,
              child: ColorFiltered(colorFilter: _grey, child: picture),
            )
          : picture,
    );
  }

  Widget _picture(Widget face) => FutureBuilder<Uint8List?>(
    future: bookmark.media != null
        ? controller.mediaPreview(bookmark.media!.id)
        : controller.thumbnail(bookmark.id),
    builder: (context, snap) => snap.data == null
        ? face
        : Image.memory(
            snap.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => face,
          ),
  );
}

/// A picture being read for its title and cover: darkened, with a spinner
/// in the middle sized to the picture. The spinner holds still when the
/// system asks for less motion.
class ReadingShade extends StatelessWidget {
  final Widget child;
  const ReadingShade({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: tr(context, 'Reading the page', 'Đang đọc trang'),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .45),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final side = (box.biggest.shortestSide * .3).clamp(
                      14.0,
                      30.0,
                    );
                    return Center(
                      child: SizedBox.square(
                        dimension: side,
                        child: CircularProgressIndicator(
                          value: still ? .3 : null,
                          strokeWidth: side < 20 ? 2 : 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section's head: a sans-serif title, an optional one-line note under
/// it, and at most one action on the right.
class SectionHead extends StatelessWidget {
  final String title;
  final String? note;
  final Widget? action;
  const SectionHead(this.title, {super.key, this.note, this.action});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(
        crossAxisAlignment: note == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
