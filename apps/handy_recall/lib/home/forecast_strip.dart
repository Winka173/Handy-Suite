import 'package:handy_ui/kit.dart';

/// The next 14 days of reviews, one column per day. Today, which also holds
/// everything overdue, is the one column in the app's hue; each column
/// carries its own count, so the strip needs no axis.
class ForecastStrip extends StatelessWidget {
  final List<int> days;
  final DateTime today;
  const ForecastStrip({super.key, required this.days, required this.today});

  static const _en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _vi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final most = days.fold(1, (a, b) => b > a ? b : a);
    final total = days.fold(0, (a, b) => a + b);
    const plot = 96.0;
    return Semantics(
      label: tr(
        context,
        'Reviews in the next 14 days: $total. Today ${days.first}.',
        'Số thẻ cần ôn trong 14 ngày tới: $total. Hôm nay ${days.first}.',
      ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: plot + 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, n) in days.indexed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Narrow columns shrink a count rather than cut it.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              n == 0 ? '' : '$n',
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: i == 0 ? c.selectInk : c.muted,
                                fontFeatures: tabular,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Columns grow to their count when the data changes.
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              end: n == 0 ? 2 : 4 + (plot - 4) * n / most,
                            ),
                            duration: HandyMotion.of(context, HandyMotion.long),
                            curve: HandyMotion.curve,
                            builder: (context, h, _) => Container(
                              height: h,
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? theme.colorScheme.primary
                                    : c.control,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: HandySpace.xs),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  // A label wider than its column (Today) runs into the
                  // unlabelled neighbour instead of being cut.
                  child: Text(
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    i == 0
                        ? tr(context, 'Today', 'Nay')
                        : i % 2 == 0
                        ? trList(
                            context,
                            _en,
                            _vi,
                          )[today.add(Duration(days: i)).weekday - 1]
                        : '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: i == 0 ? c.selectInk : c.muted,
                      fontWeight: i == 0 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [tr] for lists, so day names come in the reader's language.
List<String> trList(BuildContext c, List<String> en, List<String> vi) =>
    Localizations.localeOf(c).languageCode == 'vi' ? vi : en;
