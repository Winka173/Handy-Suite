import 'package:handy_ui/kit.dart';

/// The board's columns arriving from the side when the period changes:
/// from the right for a later week, from the left for an earlier one, so
/// the change reads as moving along the timeline. Still when the system
/// asks for less motion.
class PeriodSlide extends StatefulWidget {
  final DateTime? period;

  /// 1 later, -1 earlier, 0 none.
  final int direction;
  final Widget child;
  const PeriodSlide({
    super.key,
    required this.period,
    required this.direction,
    required this.child,
  });
  @override
  State<PeriodSlide> createState() => _PeriodSlideState();
}

class _PeriodSlideState extends State<PeriodSlide>
    with SingleTickerProviderStateMixin {
  late final _move = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(PeriodSlide old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period && widget.direction != 0) {
      final duration = HandyMotion.of(context);
      if (duration == Duration.zero) return;
      _move.duration = duration * 1.4;
      _move.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _move,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(_move.value);
      return Opacity(
        opacity: .2 + .8 * t,
        child: Transform.translate(
          offset: Offset(widget.direction * 56 * (1 - t), 0),
          child: child,
        ),
      );
    },
  );
}
