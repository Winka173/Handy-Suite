// The guide's motion pieces, shared in spirit with Handy Bookmark and
// Sticky Wall (same beats, spotlight and coach), in Boards' colours.
import 'dart:math' as math;
import 'package:handy_ui/kit.dart';

/// Whether this person allows movement (the OS "reduce motion" setting).
bool moves(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) != true;

/// The guide's colours: the app's magenta used boldly, a pale tint of it
/// for highlights, and the stone ground of the app.
abstract final class GuideColors {
  static const teal = Color(0xFFA61C8E);
  static const tealDeep = Color(0xFF82136F);
  static const tint = Color(0xFFF6D9EE);
  static const paper = Color(0xFFF7F3F1);
  static const ink = Color(0xFF231A21);
  static const muted = Color(0xFF62575F);
  static const card = Color(0xFFFFFFFF);
  static const shadow = Color(0x1F3A0E30);
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
  final TextAlign textAlign;
  const Highlighted({
    super.key,
    required this.before,
    required this.words,
    this.after = '',
    required this.style,
    this.from = .3,
    this.to = .7,
    this.textAlign = TextAlign.start,
  });
  @override
  Widget build(BuildContext context) {
    final clock = Beat.of(context);
    return Semantics(
      header: true,
      label: '$before$words$after',
      excludeSemantics: true,
      child: Text.rich(
        textAlign: textAlign,
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
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
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

  /// No frame: the screen fills the space at its real size (on a phone
  /// the guide becomes the screen), scaled down only below [minHeight].
  final bool bare;
  final double minHeight;
  const PhoneFrame({
    super.key,
    required this.screen,
    this.interactive = false,
    this.bare = false,
    this.minHeight = 560,
  });
  @override
  Widget build(BuildContext context) {
    if (bare) {
      return ExcludeSemantics(
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: LayoutBuilder(
            builder: (context, box) => FittedBox(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: box.maxWidth,
                height: math.max(box.maxHeight, minHeight),
                child: screen,
              ),
            ),
          ),
        ),
      );
    }
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

/// Darkens everything except the one thing to tap next, which sits in a
/// lit window with a glowing edge and a word beside it. When the target
/// changes the window glides to it (following a sheet as it slides up);
/// with no target the dark lifts. Taps pass through to the screen.
class Spotlight extends StatefulWidget {
  final GlobalKey? target;
  final String? label;
  final double radius;

  /// Where the word goes; by default below a target in the top half of
  /// the screen and above one in the bottom half.
  final bool? labelBelow;
  final Widget child;
  const Spotlight({
    super.key,
    required this.target,
    this.label,
    this.radius = 14,
    this.labelBelow,
    required this.child,
  });
  @override
  State<Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends State<Spotlight> with TickerProviderStateMixin {
  late final AnimationController move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..addListener(_track);
  late final AnimationController glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  Rect? from, at;
  bool fadeIn = true, fadeOut = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (move.value == 0 && !move.isAnimating) _start();
    _syncGlow();
  }

  @override
  void didUpdateWidget(Spotlight old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      from = _shown;
      fadeIn = old.target == null;
      fadeOut = widget.target == null;
      _start();
    }
    _syncGlow();
  }

  void _start() {
    if (moves(context)) {
      move.forward(from: 0);
    } else {
      move.value = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _track());
  }

  /// The target the ring last breathed for: each new target gets a few
  /// breaths, then the ring rests (as in Sticky Wall), so nothing moves
  /// for long.
  GlobalKey? _breathedFor;

  void _syncGlow() {
    if (widget.target != null && moves(context)) {
      if (_breathedFor != widget.target) {
        _breathedFor = widget.target;
        glow.repeat(count: 4);
      }
    } else {
      glow.stop();
      _breathedFor = null;
    }
  }

  /// Where the target is now, in this widget's own coordinates.
  void _track() {
    if (!mounted || widget.target == null) return;
    final box = widget.target!.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (box is! RenderBox || me is! RenderBox) return;
    if (!box.attached || !box.hasSize || !me.hasSize) return;
    final r = box.localToGlobal(Offset.zero, ancestor: me) & box.size;
    if (r != at) setState(() => at = r);
  }

  double get _t => Curves.easeInOutCubic.transform(move.value);

  Rect? get _shown {
    if (fadeOut) return from;
    if (from == null || at == null) return at;
    return Rect.lerp(from, at, _t);
  }

  double get _dark => fadeOut ? 1 - _t : (fadeIn ? _t : 1);

  @override
  void dispose() {
    move.dispose();
    glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _track());
    return LayoutBuilder(
      builder: (context, box) => Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([move, glow]),
              builder: (context, _) => CustomPaint(
                painter: _SpotPainter(
                  hole: _shown,
                  radius: widget.radius,
                  dark: _dark,
                  glow: glow.value,
                  still: !moves(context),
                ),
              ),
            ),
          ),
          if (widget.label != null)
            AnimatedBuilder(
              animation: move,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  if (_shown != null && !fadeOut) _label(box.biggest, _shown!),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The word beside the window: below it in the top half of the screen,
  /// above it in the bottom half, kept on screen.
  Widget _label(Size size, Rect hole) {
    final below = widget.labelBelow ?? hole.center.dy < size.height / 2;
    final x = (hole.center.dx / size.width * 2 - 1).clamp(-1.0, 1.0);
    final pill = IgnorePointer(
      child: Opacity(
        opacity: Curves.easeOut.transform(
          ((move.value - .55) / .45).clamp(0.0, 1.0),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66F06BCB),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                below ? Icons.arrow_upward : Icons.arrow_downward,
                size: 18,
                color: GuideColors.teal,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label!,
                  style: const TextStyle(
                    color: GuideColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Positioned(
      left: 12,
      right: 12,
      top: below ? hole.bottom + 22 : null,
      bottom: below ? null : size.height - hole.top + 22,
      child: Align(alignment: Alignment(x, 0), child: pill),
    );
  }
}

class _SpotPainter extends CustomPainter {
  final Rect? hole;
  final double radius, dark, glow;
  final bool still;
  const _SpotPainter({
    required this.hole,
    required this.radius,
    required this.dark,
    required this.glow,
    required this.still,
  });

  static const _light = Color(0xFFF7A8E2);

  @override
  void paint(Canvas canvas, Size size) {
    if (dark <= 0) return;
    final scrim = Paint()
      ..color = Color.fromRGBO(4, 12, 16, .74 * dark.clamp(0, 1));
    final full = Offset.zero & size;
    if (hole == null) {
      canvas.drawRect(full, scrim);
      return;
    }
    final window = RRect.fromRectAndRadius(
      hole!.inflate(8),
      Radius.circular(radius + 8),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(full)
        ..addRRect(window),
      scrim,
    );
    final a = dark.clamp(0.0, 1.0);
    // The light: a soft glow spilling out of the window, then a crisp edge.
    canvas.drawRRect(
      window.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = _light.withValues(alpha: a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: a),
    );
    if (still) return;
    final g = Curves.easeOut.transform(glow);
    canvas.drawRRect(
      window.inflate(3 + 18 * g),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - g)
        ..color = _light.withValues(alpha: (1 - g) * .9 * a),
    );
  }

  @override
  bool shouldRepaint(_SpotPainter old) =>
      old.hole != hole ||
      old.dark != dark ||
      old.glow != glow ||
      old.radius != radius ||
      old.still != still;
}
