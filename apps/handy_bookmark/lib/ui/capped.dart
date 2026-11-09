import 'package:handy_ui/kit.dart';

/// A long list shows its first [max] and a "Show all N" under them that
/// opens the rest in place (and folds them back), so what comes after the
/// list (tags, Advanced, a New button) never sits far down. A list only one
/// longer than [max] is shown whole; [open] keeps it whole (the picked
/// thing is further down).
class Capped extends StatefulWidget {
  final int count, max;
  final bool open;
  final Widget Function(BuildContext context, int shown) builder;

  /// Names the toggle for tests ('<name>-more').
  final String name;
  const Capped({
    super.key,
    required this.count,
    required this.max,
    required this.builder,
    required this.name,
    this.open = false,
  });

  @override
  State<Capped> createState() => _CappedState();
}

class _CappedState extends State<Capped> {
  bool all = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final long = w.count > w.max + 1 && !w.open;
    final shown = long && !all ? w.max : w.count;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyReveal(child: w.builder(context, shown)),
        if (long)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: Key('${w.name}-more'),
              onPressed: () => setState(() => all = !all),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                minimumSize: const Size(48, 44),
              ),
              icon: AnimatedRotation(
                turns: all ? .5 : 0,
                duration: HandyMotion.of(context),
                child: const Icon(Icons.expand_more, size: 20),
              ),
              label: Text(
                all
                    ? tr(context, 'Show fewer', 'Thu gọn')
                    : tr(
                        context,
                        'Show all ${w.count}',
                        'Xem tất cả ${w.count}',
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
