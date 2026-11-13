import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// The page's head on a deep band (strong contrast, 3a): the library's
/// name in white, its counts in the band's pale line, and the Save row
/// with the gold action. The band is the one dark field on the page, so
/// the eye lands on the name and the one way to save first.
class HeaderBand extends StatelessWidget {
  final String title;

  /// The counts line ("87 items · 4 not sorted"), figures bold.
  final List<InlineSpan> counts;

  /// Beside the title on a wide screen, under it on a phone.
  final Widget? action;

  /// Lay the action beside the title (a wide screen).
  final bool across;
  final double titleSize;

  /// Icon buttons at the title's right (the phone's Search and Settings),
  /// drawn in the band's ink.
  final List<Widget> trailing;
  const HeaderBand({
    super.key,
    required this.title,
    required this.counts,
    this.action,
    this.across = false,
    this.titleSize = BookmarkType.page,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: across ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: bookmarkSerif(
              context,
              titleSize,
            ).copyWith(color: p.bandInk, fontWeight: FontWeight.w700),
          ),
        ),
        if (counts.isNotEmpty) ...[
          const SizedBox(height: HandySpace.xs),
          Text.rich(
            TextSpan(children: counts),
            key: const Key('home-subtitle'),
            maxLines: across ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: p.bandSub),
          ),
        ],
      ],
    );
    final head = trailing.isEmpty
        ? name
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: name),
              // The band's own buttons: white marks, a white focus ring.
              IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: p.bandInk,
                    focusColor: p.bandInk.withValues(alpha: .24),
                    hoverColor: p.bandInk.withValues(alpha: .12),
                    highlightColor: p.bandInk.withValues(alpha: .18),
                    minimumSize: const Size(48, 48),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: trailing),
              ),
            ],
          );
    return Material(
      key: const Key('header-band'),
      color: p.band,
      borderRadius: BorderRadius.circular(BookmarkRadii.focus),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          across ? HandySpace.xl : HandySpace.l,
          trailing.isEmpty ? HandySpace.l : HandySpace.m,
          trailing.isEmpty ? HandySpace.l : HandySpace.s,
          HandySpace.l,
        ),
        child: across
            ? Row(
                children: [
                  Expanded(child: head),
                  if (action != null) ...[
                    const SizedBox(width: HandySpace.l),
                    action!,
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  head,
                  if (action != null) ...[
                    const SizedBox(height: HandySpace.m),
                    // The buttons above sit 8 from the edge; the row, 16.
                    Padding(
                      padding: EdgeInsets.only(
                        right: trailing.isEmpty ? 0 : HandySpace.s,
                      ),
                      child: action!,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// A figure in the band's counts line: white and bold.
InlineSpan bandFigure(BuildContext context, int v) => TextSpan(
  text: formatFigure(context, '$v'),
  style: TextStyle(
    color: BookmarkPalette.of(context).bandInk,
    fontWeight: FontWeight.w700,
  ),
);
