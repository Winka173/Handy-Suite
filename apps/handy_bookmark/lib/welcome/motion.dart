import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';

/// True where other apps can share into this one.
bool get canReceiveShares =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Whether this person allows movement (the OS "reduce motion" setting).
bool moves(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) != true;

/// The guide's colours: the app's teal used boldly, a pale tint of it for
/// highlights, and a warm paper ground.
abstract final class GuideColors {
  static const teal = Color(0xFF0E7490);
  static const tealDeep = Color(0xFF0B5A70);
  static const tint = Color(0xFFD7EEF3);
  static const paper = Color(0xFFFAF8F3);
  static const ink = Color(0xFF141414);
  static const muted = Color(0xFF5B5E63);
  static const card = Color(0xFFFFFFFF);
  static const shadow = Color(0x1F0B2A33);
}

/// One step's timeline: 0 → 1 over [length] from the moment it is built.
/// Everything inside reads it through [Beat.of] and plays its own slice,
/// so a step's parts arrive in order (words, picture, then the button).
class BeatStage extends StatefulWidget {
  final Duration length;
  final Widget child;
  const BeatStage({
    super.key,
    this.length = const Duration(milliseconds: 1400),
    required this.child,
  });
  @override
  State<BeatStage> createState() => _BeatStageState();
}

class _BeatStageState extends State<BeatStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock;
  @override
  void initState() {
    super.initState();
    clock = AnimationController(vsync: this, duration: widget.length);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (clock.value > 0 || clock.isAnimating) return;
    if (moves(context)) {
      clock.forward();
    } else {
      clock.value = 1;
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Beat(clock: clock, child: widget.child);
}

class Beat extends InheritedNotifier<Animation<double>> {
  const Beat({
    super.key,
    required Animation<double> clock,
    required super.child,
  }) : super(notifier: clock);
  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Beat>()?.notifier ??
      const AlwaysStoppedAnimation(1);
}

/// Arrives during [from]–[to] of the step's beat: fades in and rises
/// [rise] px (and grows from [scale]) with a soft overshoot.
class Reveal extends StatelessWidget {
  final double from, to, rise, scale;
  final Widget child;
  const Reveal({
    super.key,
    this.from = 0,
    this.to = .45,
    this.rise = 18,
    this.scale = 1,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final clock = Beat.of(context);
    return AnimatedBuilder(
      animation: clock,
      builder: (context, child) {
        final raw = ((clock.value - from) / (to - from)).clamp(0.0, 1.0);
        final t = Curves.easeOutBack.transform(raw);
        final o = Curves.easeOut.transform(raw);
        return Opacity(
          opacity: o,
          child: Transform.translate(
            offset: Offset(0, rise * (1 - t)),
            child: Transform.scale(
              scale: scale + (1 - scale) * t,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// The step's key words with a band of the tint drawn in under them,
/// left to right, during [from]–[to] of the beat.
class Highlighted extends StatelessWidget {
  final String before, words, after;
  final TextStyle style;
  final double from, to;
  const Highlighted({
    super.key,
    required this.before,
    required this.words,
    this.after = '',
    required this.style,
    this.from = .3,
    this.to = .7,
  });
  @override
  Widget build(BuildContext context) {
    final clock = Beat.of(context);
    return Semantics(
      header: true,
      label: '$before$words$after',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: before),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: AnimatedBuilder(
                animation: clock,
                builder: (context, child) {
                  final t = Curves.easeInOutCubic.transform(
                    ((clock.value - from) / (to - from)).clamp(0.0, 1.0),
                  );
                  return CustomPaint(painter: _Band(t), child: child);
                },
                child: Text('$words$after', style: style),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Band extends CustomPainter {
  final double t;
  const _Band(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final h = size.height * .34;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -2,
          size.height - h - size.height * .08,
          (size.width + 4) * t,
          h,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = GuideColors.tint,
    );
  }

  @override
  bool shouldRepaint(_Band old) => old.t != t;
}

/// A ring that keeps breathing around [child] to say "tap here", with a
/// still ring when motion is reduced.
class Pulse extends StatefulWidget {
  final Widget child;
  final bool on;
  final double radius;
  const Pulse({
    super.key,
    required this.child,
    this.on = true,
    this.radius = 999,
  });
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.on && moves(context)) {
      if (!loop.isAnimating) loop.repeat();
    } else {
      loop.stop();
      loop.value = 0;
    }
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.child;
    return AnimatedBuilder(
      animation: loop,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _Ring(
          loop.value,
          widget.radius,
          still: !moves(context),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _Ring extends CustomPainter {
  final double t, radius;
  final bool still;
  const _Ring(this.t, this.radius, {required this.still});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    RRect ring(double grow) => RRect.fromRectAndRadius(
      rect.inflate(grow),
      Radius.circular(math.min(radius, size.shortestSide / 2) + grow),
    );
    canvas.drawRRect(
      ring(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = GuideColors.teal,
    );
    if (still) return;
    canvas.drawRRect(
      ring(4 + 14 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - t)
        ..color = GuideColors.teal.withValues(alpha: (1 - t) * .7),
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.t != t || old.still != still;
}

/// A small label pointing at what to do next ("Tap Share").
class Coach extends StatelessWidget {
  final String text;
  final IconData? icon;
  const Coach(this.text, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: GuideColors.teal,
      borderRadius: BorderRadius.circular(999),
      boxShadow: const [
        BoxShadow(
          color: GuideColors.shadow,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Draws a phone-shaped frame around a 360 × 720 screen and scales the
/// whole to fit. Text inside keeps its design size (the frame is a
/// picture of a phone); the reader's text size applies outside it.
class PhoneFrame extends StatelessWidget {
  final Widget screen;
  final bool interactive;
  const PhoneFrame({super.key, required this.screen, this.interactive = false});
  @override
  Widget build(BuildContext context) {
    final framed = Container(
      width: 384,
      height: 744,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16181A),
        borderRadius: BorderRadius.circular(48),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: SizedBox(width: 360, height: 720, child: screen),
      ),
    );
    final body = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: FittedBox(child: framed),
    );
    return interactive ? body : ExcludeSemantics(child: body);
  }
}
