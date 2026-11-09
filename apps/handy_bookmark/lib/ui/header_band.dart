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
  const HeaderBand({
    super.key,
    required this.title,
    required this.counts,
    this.action,
    this.across = false,
    this.titleSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: bookmarkSerif(
              context,
              titleSize,
            ).copyWith(color: p.bandInk, fontWeight: FontWeight.w700),
          ),
        ),
        if (counts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: counts),
            key: const Key('home-subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(color: p.bandSub),
          ),
        ],
      ],
    );
    return Material(
      key: const Key('header-band'),
      color: p.band,
      borderRadius: BorderRadius.circular(BookmarkRadii.focus),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          across ? 24 : 18,
          across ? 18 : 16,
          across ? 18 : 16,
          across ? 18 : 16,
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
                  if (action != null) ...[const SizedBox(height: 14), action!],
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
