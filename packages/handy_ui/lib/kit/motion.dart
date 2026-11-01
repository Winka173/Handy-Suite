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
