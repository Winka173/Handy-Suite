import 'package:flutter/scheduler.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// The keyboard's place on the screen: a ring around whatever holds the
/// focus, drawn over the whole app (pages, sheets and dialogs alike), so
/// no control needs a ring of its own and none is left without one.
///
/// Shown only while the keyboard is in use (Tab, arrows), never for a
/// touch or a click. The ring is two lines, the teal inside and the
/// surface colour around it, so it parts from any ground by at least 3:1:
/// on the pale page the teal reads, on the deep band the pale line does.
/// A text field keeps its own thicker border instead.
class FocusRing extends StatefulWidget {
  final Widget child;
  const FocusRing({super.key, required this.child});
  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  final _tick = ValueNotifier(0);

  /// Frames still to repaint after a change, so the ring follows a page
  /// or a sheet sliding in; it ends, so nothing runs while idle.
  int _follow = 0;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_changed);
    FocusManager.instance.addHighlightModeListener(_mode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_changed);
    FocusManager.instance.removeHighlightModeListener(_mode);
    _tick.dispose();
    super.dispose();
  }

  void _mode(FocusHighlightMode _) => _changed();

  void _changed() {
    if (!mounted) return;
    final start = _follow == 0;
    _follow = 24;
    if (start) _next();
  }

  /// Repaints at the start of each of the next frames (before the frame
  /// is built and painted, so nothing is left dirty after it).
  void _next() {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!mounted) return;
      _tick.value++;
      if (--_follow > 0) _next();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        // The focused row moves with its list.
        _tick.value++;
        return false;
      },
      child: CustomPaint(
        foregroundPainter: _RingPainter(
          repaint: _tick,
          host: context,
          line: p.primary,
          halo: p.surface,
        ),
        child: widget.child,
      ),
    );
  }
}

/// The rectangle the ring goes around, in global coordinates, or null
/// when nothing should be ringed.
Rect? focusRingRect(Size screen) {
  if (FocusManager.instance.highlightMode != FocusHighlightMode.traditional) {
    return null;
  }
  final node = FocusManager.instance.primaryFocus;
  final context = node?.context;
  if (node == null || context == null || node is FocusScopeNode) return null;
  if (!context.mounted) return null;
  // A text field draws its own focused border.
  if (context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null) {
    return null;
  }
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  final rect = node.rect;
  if (rect.isEmpty) return null;
  // A page's own focus (shortcuts) spans the screen: not a control.
  if (rect.width >= screen.width * .9 && rect.height >= screen.height * .6) {
    return null;
  }
  return rect;
}

class _RingPainter extends CustomPainter {
  final BuildContext host;
  final Color line, halo;
  _RingPainter({
    required Listenable repaint,
    required this.host,
    required this.line,
    required this.halo,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final global = focusRingRect(size);
    final self = host.findRenderObject();
    if (global == null || self is! RenderBox || !self.attached) return;
    final rect = (self.globalToLocal(global.topLeft) & global.size)
        .inflate(2)
        .intersect(Offset.zero & size);
    if (rect.isEmpty) return;
    // Round things (icon buttons, chips) get a round ring; the rest, the
    // controls' own corner.
    final r = rect.shortestSide <= 56
        ? rect.shortestSide / 2
        : BookmarkRadii.item + 2;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(r));
    canvas.drawRRect(
      shape.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = halo,
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = line,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.line != line || old.halo != halo || old.host != host;
}
