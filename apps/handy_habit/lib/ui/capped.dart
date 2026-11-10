import 'package:handy_ui/kit.dart';

/// The sibling apps' in-place disclosure; expansion never opens a new route.
class Capped extends StatefulWidget {
  final int count, max;
  final String name;
  final bool open;
  final Widget Function(BuildContext, int shown) builder;
  const Capped({
    super.key,
    required this.count,
    required this.max,
    required this.name,
    required this.builder,
    this.open = false,
  });
  @override
  State<Capped> createState() => _CappedState();
}

class _CappedState extends State<Capped> {
  bool all = false;
  @override
  Widget build(BuildContext context) {
    final long = widget.count > widget.max + 1 && !widget.open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyReveal(
          child: widget.builder(
            context,
            long && !all ? widget.max : widget.count,
          ),
        ),
        if (long)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: Key('${widget.name}-more'),
              onPressed: () => setState(() => all = !all),
              icon: AnimatedRotation(
                turns: all ? .5 : 0,
                duration: HandyMotion.of(context),
                child: const Icon(Icons.expand_more),
              ),
              label: Text(
                all
                    ? tr(context, 'Show fewer', 'Thu gọn')
                    : tr(
                        context,
                        'Show all ${widget.count}',
                        'Xem tất cả ${widget.count}',
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
