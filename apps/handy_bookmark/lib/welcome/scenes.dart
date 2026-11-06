import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';
import 'clipping.dart';

/// True where other apps can share into this one.
bool get canReceiveShares =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// A drawn illustration on a fixed 320 × 280 canvas, scaled to fit and kept
/// out of the reader's text size and of screen readers (it only repeats
/// what the step's words say).
class _Canvas extends StatelessWidget {
  final Widget child;
  const _Canvas({required this.child});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: FittedBox(child: SizedBox(width: 320, height: 280, child: child)),
    ),
  );
}

/// Plays once from the start; under reduced motion it is already at the end.
/// The pause before it is part of the controller, so nothing waits on a
/// timer and the scene is always either moving or at rest.
mixin _PlaysOnce<T extends StatefulWidget> on State<T>, TickerProvider {
  late final AnimationController _clock;

  /// 0 → 1 over [length], after [delay].
  late final Animation<double> run;
  Duration get length;
  Duration get delay => Duration.zero;
  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: delay + length);
    run = CurvedAnimation(
      parent: _clock,
      curve: Interval(
        delay.inMilliseconds / (delay + length).inMilliseconds,
        1,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clock.isAnimating || _clock.value > 0) return;
    if (HandyMotion.of(context) == Duration.zero) {
      _clock.value = 1;
    } else {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }
}

/// Step one: four saves from four apps lie scattered, then settle into one
/// column under the app's masthead and today's date.
class PileScene extends StatefulWidget {
  final DateTime today;
  const PileScene({super.key, required this.today});
  @override
  State<PileScene> createState() => _PileSceneState();
}

class _PileSceneState extends State<PileScene>
    with SingleTickerProviderStateMixin, _PlaysOnce {
  @override
  Duration get length => const Duration(milliseconds: 730);
  @override
  Duration get delay => const Duration(milliseconds: 200);

  // Where each clipping starts, against where it ends: (dx, dy, turn).
  static const _from = [
    (-26.0, 150.0, -.10),
    (34.0, 64.0, .08),
    (-12.0, -18.0, -.05),
    (22.0, -112.0, .12),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final samples = sampleClippings(context);
    final date = MaterialLocalizations.of(context).formatFullDate(widget.today);
    return _Canvas(
      child: Stack(
        children: [
          Positioned(
            left: 28,
            right: 28,
            top: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Handy Bookmark',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: handyFontFamily('Newsreader'),
                      ),
                    ),
                    const SizedBox(width: HandySpace.s),
                    Expanded(
                      child: Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HandySpace.xs),
                Container(height: 2, color: theme.colorScheme.onSurface),
              ],
            ),
          ),
          for (var i = 0; i < samples.length; i++)
            AnimatedBuilder(
              animation: run,
              builder: (context, child) {
                final start = i * 70 / 730;
                final t = Curves.easeOutCubic.transform(
                  ((run.value - start) / (520 / 730)).clamp(0, 1),
                );
                final (dx, dy, turn) = _from[i];
                return Positioned(
                  left: 28 + dx * (1 - t),
                  top: 48 + i * 56.0 + dy * (1 - t),
                  child: Transform.rotate(angle: turn * (1 - t), child: child),
                );
              },
              child: Clipping(
                title: samples[i].title,
                source: samples[i].source,
                screenshot: samples[i].screenshot,
              ),
            ),
        ],
      ),
    );
  }
}

/// Step two: a save travels from the app it was found in, through the
/// share row (or the paste keys on a computer), into Not sorted.
class ShareScene extends StatefulWidget {
  const ShareScene({super.key});
  @override
  State<ShareScene> createState() => _ShareSceneState();
}

class _ShareSceneState extends State<ShareScene>
    with SingleTickerProviderStateMixin, _PlaysOnce {
  @override
  Duration get length => const Duration(milliseconds: 760);
  @override
  Duration get delay => const Duration(milliseconds: 360);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final sample = sampleClippings(context).first;
    final clip = Clipping(title: sample.title, source: sample.source);
    return _Canvas(
      child: Stack(
        children: [
          Positioned(left: 28, top: 4, child: clip),
          Positioned(
            left: 16,
            right: 16,
            top: 70,
            height: 104,
            child: canReceiveShares ? _shareRow(context) : _pasteKeys(context),
          ),
          Positioned(
            left: 28,
            right: 28,
            top: 184,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 1, color: theme.colorScheme.onSurface),
                const SizedBox(height: HandySpace.xs),
                Text(
                  tr(context, 'Not sorted', 'Chưa xếp'),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: run,
            builder: (context, child) {
              final t = Curves.easeInOutCubic.transform(run.value);
              return Positioned(
                left: 28,
                top: 4 + (206 - 4) * t,
                child: Opacity(opacity: math.min(1, t * 4), child: child),
              );
            },
            child: clip,
          ),
          // The tray's border reads as the place the save lands.
          Positioned(
            left: 28,
            top: 206,
            child: IgnorePointer(
              child: SizedBox(
                width: 264,
                height: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(HandyRadius.card),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareRow(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    Widget target(IconData icon, String label, {bool ours = false}) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              border: Border.all(
                color: ours ? c.accent : c.control,
                width: ours ? 2.5 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: ours ? theme.colorScheme.onSurface : c.muted,
            ),
          ),
          const SizedBox(height: HandySpace.xs),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: ours ? FontWeight.w600 : null,
              color: ours ? null : c.muted,
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.raised,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              target(Icons.link, tr(context, 'Copy link', 'Sao chép link')),
              target(
                Icons.chat_bubble_outline,
                tr(context, 'Messages', 'Tin nhắn'),
              ),
              target(Icons.bookmark_outline, 'Handy Bookmark', ours: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pasteKeys(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    Widget key(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: theme.textTheme.titleMedium),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        key(mac ? '⌘' : 'Ctrl'),
        const SizedBox(width: HandySpace.s),
        Text('+', style: theme.textTheme.titleMedium),
        const SizedBox(width: HandySpace.s),
        key('V'),
      ],
    );
  }
}

/// The Not sorted tray: empty and waiting on step three, holding the
/// person's first save on step four. Real content, so it is not a canvas.
class Tray extends StatelessWidget {
  final String heading;
  final Widget? child;
  const Tray({super.key, required this.heading, this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: theme.colorScheme.onSurface),
        const SizedBox(height: HandySpace.xs),
        HandySwap(
          child: Text(
            heading,
            key: ValueKey(heading),
            style: theme.textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: HandySpace.s),
        HandySwap(
          duration: HandyMotion.long,
          child:
              child ??
              CustomPaint(
                key: const ValueKey('empty'),
                painter: _Dashed(c.control, HandyRadius.card),
                child: Padding(
                  padding: const EdgeInsets.all(HandySpace.l),
                  child: Text(
                    tr(
                      context,
                      'Your first save goes here.',
                      'Món đầu tiên bạn lưu sẽ nằm ở đây.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
                ),
              ),
        ),
      ],
    );
  }
}

class _Dashed extends CustomPainter {
  final Color color;
  final double radius;
  const _Dashed(this.color, this.radius);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => old.color != color;
}
