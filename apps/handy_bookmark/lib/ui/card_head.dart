import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';
import '../view/library_view.dart';
import 'visual.dart';
import 'words.dart';

/// The top of a save's card: its picture at [aspectRatio]; or, when it has
/// none, a low strip saying what it is and where it is from, so the title
/// moves up instead of sitting under a large grey field. [overlay] lies
/// over either (a checkbox, a broken-link mark). A link's picture is the
/// thumbnail kept on this device: until the first look at it, the card
/// goes by whether the page named one.
class CardHead extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final double aspectRatio;
  final List<Widget> overlay;
  const CardHead({
    super.key,
    required this.controller,
    required this.bookmark,
    required this.aspectRatio,
    this.overlay = const [],
  });

  /// The strip's height, for lists that size their cards ahead.
  static const strip = 56.0;

  /// Whether [b] shows a picture now (as far as is known yet).
  static bool pictured(SaveController c, Bookmark b) =>
      b.media != null || (c.hasThumbnail(b.id) ?? hasPicture(b));

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    if (b.media != null) return _picture();
    final known = controller.hasThumbnail(b.id);
    if (known != null) return known ? _picture() : _strip(context);
    return FutureBuilder<Uint8List?>(
      future: controller.thumbnail(b.id),
      builder: (context, snap) => snap.connectionState == ConnectionState.done
          ? (snap.data != null ? _picture() : _strip(context))
          : (hasPicture(b) ? _picture() : _strip(context)),
    );
  }

  Widget _picture() => AspectRatio(
    aspectRatio: aspectRatio,
    child: Stack(
      fit: StackFit.expand,
      children: [ItemPicture(controller, bookmark, radius: 0), ...overlay],
    ),
  );

  Widget _strip(BuildContext context) {
    final b = bookmark;
    final p = BookmarkPalette.of(context);
    final source = b.isImage
        ? tr(context, 'Picture', 'Ảnh')
        : sourceName(b.platform).isNotEmpty
        ? sourceName(b.platform)
        : b.sourceDomain.replaceFirst(RegExp(r'^www\.'), '');
    // Its page is being read for a title and picture: the same shade and
    // spinner a picture gets.
    final reading = controller.fetching.containsKey(b.id);
    Widget shade(Widget child) => reading ? ReadingShade(child: child) : child;
    return SizedBox(
      key: Key('card-strip-${b.id}'),
      height: strip,
      child: Stack(
        fit: StackFit.expand,
        children: [
          shade(
            ExcludeSemantics(
              child: ColoredBox(
                color: p.raised,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(kindIcon(b), size: 20, color: p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.muted,
                            fontSize: BookmarkType.meta,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ...overlay,
        ],
      ),
    );
  }
}
