import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';

/// Whether each item shown in the deck turned out to have a picture, so a
/// card that moves up the deck (a new card widget) does not flash the
/// other face for a frame while its picture is looked up again.
final _hasPicture = <String, bool>{};

/// One saved thing in the Focus deck. With a picture: the picture edge to
/// edge, then its title, where it is from and when it was saved, a little
/// of its description, and Open. Without one: a typographic poster on a
/// pale field of its source's colour (the same colour its [SourceFace]
/// uses everywhere else): where it is from at the top, the title large in
/// the library's serif, then the description, the meta line and Open. On
/// a small card or with large text the words scroll; they never overflow.
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

  Future<Uint8List?> _picture() => bookmark.media != null
      ? scope.c.mediaPreview(bookmark.media!.id)
      : scope.c.thumbnail(bookmark.id);

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final b = bookmark;
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
      child: FutureBuilder<Uint8List?>(
        future: _picture(),
        builder: (context, snap) {
          final known = snap.connectionState == ConnectionState.done
              ? snap.data != null
              : null;
          if (known != null) {
            if (_hasPicture.length > 200) _hasPicture.clear();
            _hasPicture[b.id] = known;
          }
          // Until the lookup answers: what it was last time, or a guess
          // from whether the item is a picture of its own.
          final pictured = known ?? _hasPicture[b.id] ?? b.media != null;
          return Material(
            color: pictured ? p.surface : _posterGround(context, b),
            borderRadius: BorderRadius.circular(BookmarkRadii.focus),
            clipBehavior: Clip.antiAlias,
            child: pictured
                ? _PictureCard(scope: scope, bookmark: b)
                : _PosterCard(scope: scope, bookmark: b),
          );
        },
      ),
    );
  }
}

/// The poster's field: [SourceFace]'s pale source colour, a step paler in
/// light so the large serif reads at full ink.
Color _posterGround(BuildContext context, Bookmark b) {
  final hue = HandyPalette.of(context, sourceHue(b));
  return Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(BookmarkPalette.dark.surface, hue.mark, .2)!
      : Color.lerp(Colors.white, hue.mark, .1)!;
}

/// The source's colour as ink on the poster (as [SourceFace] draws it).
Color _sourceInk(BuildContext context, Bookmark b) {
  final hue = HandyPalette.of(context, sourceHue(b));
  return Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(hue.mark, Colors.white, .45)!
      : Color.lerp(hue.mark, Colors.black, .15)!;
}

String _title(BuildContext context, Bookmark b) => b.title.isNotEmpty
    ? b.title
    : b.isImage
    ? tr(context, 'Picture', 'Ảnh')
    : b.sourceDomain;

/// Collection, source and when it was saved, on one line.
Widget _meta(BuildContext context, SaveScope scope, Bookmark b, {Color? on}) {
  final home = collectionOf(scope.library, b.collectionId);
  return Text.rich(
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
    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: on),
  );
}

/// Open the original (or view the picture).
Widget _open(BuildContext context, SaveScope scope, Bookmark b, {Color? bg}) {
  final p = BookmarkPalette.of(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  return FilledButton.icon(
    key: const Key('focus-open'),
    style: FilledButton.styleFrom(
      backgroundColor: bg ?? p.tint,
      foregroundColor: dark ? p.ink : p.pressed,
      minimumSize: const Size(48, 44),
      shape: const StadiumBorder(),
    ),
    onPressed: () => scope.open(context, b),
    icon: Icon(b.hasUrl ? Icons.open_in_new : Icons.fullscreen, size: 20),
    label: Text(
      b.hasUrl
          ? tr(context, 'Open original', 'Mở bản gốc')
          : tr(context, 'View picture', 'Xem ảnh'),
    ),
  );
}

class _PictureCard extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _PictureCard({required this.scope, required this.bookmark});
  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
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
                  _title(context, b),
                  maxLines: roomy ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 21,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _meta(context, scope, b),
              if (roomy && (b.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: HandySpace.s),
                Text(
                  b.description!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
              ],
              const SizedBox(height: 14),
              _open(context, scope, b),
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
    );
  }
}

/// A save with no picture, as a poster of its own words: where it is from
/// at the top; low on the card its title, set as large as the card allows
/// (the largest size at which it fits, never a word broken), and its
/// description or note; at the foot the meta line and Open.
class _PosterCard extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _PosterCard({required this.scope, required this.bookmark});

  /// The poster sizes, largest first.
  static const _sizes = [
    72.0,
    64.0,
    56.0,
    50.0,
    44.0,
    38.0,
    33.0,
    29.0,
    25.0,
    22.0,
  ];

  /// The largest size at which [text] fits [width] × [height] with no
  /// word wider than the line. Display type already reads large, so the
  /// reader's text scale applies up to 1.3×.
  static (double, TextScaler) _fit(
    BuildContext context,
    String text,
    TextStyle base,
    double width,
    double height,
  ) {
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final words = text.split(RegExp(r'\s+'));
    final longest = words.fold(
      '',
      (String a, String w) => w.length > a.length ? w : a,
    );
    for (final size in _sizes) {
      final style = base.copyWith(fontSize: size);
      final word = TextPainter(
        text: TextSpan(text: longest, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final all = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width);
      final fits = word.width <= width && all.height <= height;
      word.dispose();
      all.dispose();
      if (fits) return (size, scaler);
    }
    return (_sizes.last, scaler);
  }

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = _sourceInk(context, b);
    final title = _title(context, b);
    final source = b.isImage
        ? tr(context, 'Picture', 'Ảnh')
        : (sourceName(b.platform).isNotEmpty
              ? sourceName(b.platform)
              : b.sourceDomain.replaceFirst(RegExp(r'^www\.'), ''));
    final base = bookmarkSerif(
      context,
      36,
    ).copyWith(height: 1.1, letterSpacing: -.6, color: p.ink);
    final more = [
      (b.description ?? '').trim(),
      b.note.trim(),
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final mark = ExcludeSemantics(
      child: Row(
        children: [
          Icon(kindIcon(b), size: 22, color: ink),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    final foot = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _meta(context, scope, b, on: p.muted),
        const SizedBox(height: 14),
        _open(context, scope, b, bg: dark ? p.raised : p.surface),
      ],
    );
    final moreText = more.isEmpty
        ? null
        : Text(
            more,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: p.muted,
              height: 1.45,
            ),
          );
    return LayoutBuilder(
      builder: (context, box) {
        const pad = EdgeInsets.fromLTRB(24, 22, 24, 20);
        final width = box.maxWidth - pad.horizontal;
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        // Mark, foot and the description's room, roughly, at this scale.
        final reserved =
            pad.vertical +
            (40 + 18 + 120) * scale.clamp(1.0, 2.0) +
            (moreText == null ? 0 : 110 * scale.clamp(1.0, 2.0));
        final room = box.maxHeight - reserved;
        // A small card or very large text: everything in one scroll.
        if (room < 90) {
          final (size, scaler) = _fit(context, title, base, width, 160);
          return SingleChildScrollView(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mark,
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textScaler: scaler,
                    style: base.copyWith(fontSize: size),
                  ),
                ),
                if (moreText != null) ...[const SizedBox(height: 10), moreText],
                const SizedBox(height: 18),
                foot,
              ],
            ),
          );
        }
        final (size, scaler) = _fit(context, title, base, width, room);
        return Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              mark,
              const SizedBox(height: 18),
              // Sized to fit by [_fit] and set low, over the foot, as a
              // poster's headline; if a guess is off, the words are cut at
              // the top edge rather than pushing the foot out.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, area) => ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.bottomCenter,
                      maxHeight: double.infinity,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: area.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                textScaler: scaler,
                                style: base.copyWith(fontSize: size),
                              ),
                            ),
                            if (moreText != null) ...[
                              const SizedBox(height: 14),
                              moreText,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              foot,
            ],
          ),
        );
      },
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
