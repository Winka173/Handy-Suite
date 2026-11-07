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
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: reading ? ReadingSweep(child: _picture(face)) : _picture(face),
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

/// A soft band of light passing over a picture while its page is read,
/// as a skeleton does. Still (a faint veil) when the system asks for less
/// motion. Says "Reading the page" to screen readers.
class ReadingSweep extends StatefulWidget {
  final Widget child;
  const ReadingSweep({super.key, required this.child});
  @override
  State<ReadingSweep> createState() => _ReadingSweepState();
}

class _ReadingSweepState extends State<ReadingSweep>
    with SingleTickerProviderStateMixin {
  late final _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _run.stop();
    } else if (!_run.isAnimating) {
      _run.repeat();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final glow = (light ? Colors.white : Colors.white24).withValues(
      alpha: light ? 0.55 : 0.18,
    );
    return Semantics(
      label: tr(context, 'Reading the page', 'Đang đọc trang'),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _run,
                builder: (context, _) {
                  final t = _run.isAnimating ? _run.value * 2.6 - 1.3 : 0.0;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(t - 1, -0.4),
                        end: Alignment(t + 1, 0.4),
                        colors: [
                          glow.withValues(alpha: 0),
                          _run.isAnimating ? glow : glow.withValues(alpha: 0.2),
                          glow.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  );
                },
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
