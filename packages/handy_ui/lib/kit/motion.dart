import 'package:flutter/material.dart';

/// The suite's motion. Movement is feedback and continuity (a panel that
/// grows, a value that changes, a page that follows from the row tapped),
/// never a performance. Everything snaps when the OS asks for less motion.
abstract final class HandyMotion {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 240);
  static const long = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;

  /// [d], or zero when animations are turned off for this person.
  static Duration of(BuildContext context, [Duration d = medium]) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;
}

/// Cross-fades to a new child with a short rise. Give each state's child its
/// own key (`ValueKey(id)`) so a change of state is a change of child.
class HandySwap extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;
  const HandySwap({
    super.key,
    required this.child,
    this.duration = HandyMotion.medium,
    this.alignment = AlignmentDirectional.topStart,
  });
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: HandyMotion.of(context, duration),
    switchInCurve: HandyMotion.curve,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) =>
        Stack(alignment: alignment, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .02),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: child,
  );
}

/// Grows and shrinks with its content instead of jumping.
class HandyReveal extends StatelessWidget {
  final Widget child;
  const HandyReveal({super.key, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: HandyMotion.of(context),
    curve: HandyMotion.curve,
    alignment: AlignmentDirectional.topStart,
    child: child,
  );
}

/// A short demonstration that plays itself: [builder] gets `t` from 0 to 1
/// over [period], holds the last frame for [hold], and plays [times] times
/// before resting on its last frame (a replay button brings it back). With
/// [play] off, or when the OS asks for less motion, it only ever shows the
/// last frame, so the still image must explain the feature on its own.
class HandyDemoLoop extends StatefulWidget {
  final Duration period, hold;
  final int times;
  final bool play;

  /// Read aloud instead of the drawing, which is excluded from semantics.
  final String label;

  /// The replay button's tooltip, in the app's language.
  final String replayLabel;
  final Widget Function(BuildContext context, double t) builder;
  const HandyDemoLoop({
    super.key,
    required this.label,
    this.replayLabel = 'Play again',
    required this.builder,
    this.period = const Duration(milliseconds: 3200),
    this.hold = const Duration(milliseconds: 1000),
    this.times = 2,
    this.play = true,
  });

  /// Pure: the t of the drawing at [elapsed] into one play with a hold.
  static double at(Duration elapsed, Duration period, Duration hold) {
    final whole = period + hold;
    final e = elapsed.inMicroseconds % whole.inMicroseconds;
    return (e / period.inMicroseconds).clamp(0.0, 1.0);
  }

  @override
  State<HandyDemoLoop> createState() => _HandyDemoLoopState();
}

class _HandyDemoLoopState extends State<HandyDemoLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _done = false;

  bool get _still =>
      !widget.play || MediaQuery.maybeDisableAnimationsOf(context) == true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _c.stop();
    } else if (!_c.isAnimating && !_done) {
      _start();
    }
  }

  @override
  void didUpdateWidget(HandyDemoLoop old) {
    super.didUpdateWidget(old);
    if (old.label != widget.label || old.play != widget.play) {
      _done = false;
      if (_still) {
        _c.stop();
      } else {
        _start();
      }
    }
  }

  void _start() {
    final whole = widget.period + widget.hold;
    _c.duration = whole * widget.times;
    _done = false;
    _c.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted && _c.value == 1) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    final drawing = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = still || _done || _c.duration == null
            ? 1.0
            : HandyDemoLoop.at(
                _c.duration! * _c.value,
                widget.period,
                widget.hold,
              );
        return widget.builder(context, t);
      },
    );
    return Semantics(
      image: true,
      label: widget.label,
      child: Stack(
        children: [
          Positioned.fill(child: ExcludeSemantics(child: drawing)),
          if (_done && !still)
            PositionedDirectional(
              end: 4,
              bottom: 4,
              child: IconButton.filledTonal(
                key: const Key('demo-replay'),
                visualDensity: VisualDensity.compact,
                tooltip: widget.replayLabel,
                icon: const Icon(Icons.replay, size: 18),
                onPressed: _start,
              ),
            ),
        ],
      ),
    );
  }
}
