import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import 'paint.dart';
import 'studio_controller.dart';

enum _Mode { move, resize, rotate, marquee, pan, pinch }

/// A handle on the selection: where it is on screen and which sides it moves.
class _Handle {
  final Offset at;
  final Vec sides;
  final bool rotate;
  const _Handle(this.at, this.sides, {this.rotate = false});
}

/// The canvas: the card on its mat, the selection with its handles, and
/// every pointer, touch and wheel gesture that edits or moves the view.
class CardCanvas extends StatefulWidget {
  final StudioController c;
  const CardCanvas({super.key, required this.c});
  @override
  State<CardCanvas> createState() => _CardCanvasState();
}

class _CardCanvasState extends State<CardCanvas> {
  StudioController get c => widget.c;
  EditorSession get s => c.session;
  bool touch = false;
  _Mode? mode;
  Offset start = Offset.zero;
  Box? startBox;
  Frame? startFrame;
  Affine startParent = Affine.identity;
  Vec handleSides = Vec.zero;
  Set<String> moving = {};
  double lastScale = 1;
  final text = TextEditingController();
  final textFocus = FocusNode();

  bool get shift => HardwareKeyboard.instance.isShiftPressed;
  bool get alt => HardwareKeyboard.instance.isAltPressed;
  bool get multiKey =>
      shift ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;
  double get handleRadius => touch ? 22 : 8;

  @override
  void dispose() {
    text.dispose();
    textFocus.dispose();
    super.dispose();
  }

  /// The selection's outline on screen, and its handles.
  (List<Offset>, List<_Handle>)? selectionShape() {
    final ids = s.selected;
    if (ids.isEmpty) return null;
    List<Offset> corners;
    Vec up;
    if (ids.length == 1) {
      final e = findElement(s.elements, ids.first)!;
      final m = worldMatrix(s.elements, e.id);
      corners = [
        for (final p in [
          Vec.zero,
          Vec(e.frame.width, 0),
          Vec(e.frame.width, e.frame.height),
          Vec(0, e.frame.height),
        ])
          c.toScreen(m.apply(p)),
      ];
      up = m.applyVector(const Vec(0, -1));
    } else {
      final b = boundsOf(s.elements, ids)!;
      corners = [
        for (final p in [
          Vec(b.x, b.y),
          Vec(b.right, b.y),
          Vec(b.right, b.bottom),
          Vec(b.x, b.bottom),
        ])
          c.toScreen(p),
      ];
      up = const Vec(0, -1);
    }
    Offset mid(int a, int b) => (corners[a] + corners[b]) / 2;
    final locked = ids.any((id) => findElement(s.elements, id)?.locked == true);
    if (locked) return (corners, const <_Handle>[]);
    final u = up.length == 0
        ? const Offset(0, -1)
        : Offset(up.x, up.y) / up.length;
    return (
      corners,
      [
        _Handle(corners[0], const Vec(-1, -1)),
        _Handle(corners[1], const Vec(1, -1)),
        _Handle(corners[2], const Vec(1, 1)),
        _Handle(corners[3], const Vec(-1, 1)),
        _Handle(mid(0, 1), const Vec(0, -1)),
        _Handle(mid(1, 2), const Vec(1, 0)),
        _Handle(mid(2, 3), const Vec(0, 1)),
        _Handle(mid(3, 0), const Vec(-1, 0)),
        _Handle(mid(0, 1) + u * (touch ? 36 : 24), Vec.zero, rotate: true),
      ],
    );
  }

  _Handle? handleAt(Offset p) {
    final shape = selectionShape();
    if (shape == null) return null;
    _Handle? best;
    var distance = handleRadius;
    for (final h in shape.$2) {
      final d = (h.at - p).distance;
      if (d <= distance) {
        distance = d;
        best = h;
      }
    }
    return best;
  }

  String? hit(Offset p) => hitTest(
    s.elements,
    c.toDoc(p),
    enter: s.entered,
    tolerance: (touch ? 8 : 3) / c.zoom,
  );

  void finishTextEdit() {
    if (c.editingText == null) return;
    c.editingText = null;
    textFocus.unfocus();
    setState(() {});
  }

  DateTime? lastTap;
  Offset lastTapAt = Offset.zero;

  /// Taps select at once; a second tap within 350 ms and 20 px is a double
  /// tap (no recognizer delays every single tap to wait for one).
  void onTap(TapUpDetails d) {
    final now = DateTime.now();
    final double =
        lastTap != null &&
        now.difference(lastTap!) < const Duration(milliseconds: 350) &&
        (d.localPosition - lastTapAt).distance < 20;
    lastTap = double ? null : now;
    lastTapAt = d.localPosition;
    if (double) return onDoubleTap(d.localPosition);
    finishTextEdit();
    final id = hit(d.localPosition);
    if (id == null) {
      if (s.entered != null) {
        final g = findElement(s.elements, s.entered!);
        final inside =
            g != null &&
            worldBounds(s.elements, g.id).contains(c.toDoc(d.localPosition));
        if (!inside) s.enter(null);
      }
      if (!multiKey) s.clearSelection();
      return;
    }
    if (multiKey) {
      s.toggle(id);
    } else {
      s.select({id});
    }
  }

  void onDoubleTap(Offset at) {
    final id = hit(at);
    if (id == null) return;
    final e = findElement(s.elements, id)!;
    if (e.isGroup) {
      s.enter(e.id);
      s.clearSelection();
      s.enter(e.id);
      return;
    }
    if (e.type == 'text') {
      s.select({id});
      text.text = e.prop<String>('text', '');
      c.editingText = id;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => textFocus.requestFocus(),
      );
    }
  }

  void onLongPress(LongPressStartDetails d) {
    // Touch has no Shift: a long press adds to or removes from the selection.
    final id = hit(d.localPosition);
    if (id != null) {
      HapticFeedback.selectionClick();
      s.toggle(id);
    }
  }

  void onScaleStart(ScaleStartDetails d) {
    finishTextEdit();
    start = d.localFocalPoint;
    lastScale = 1;
    if (d.pointerCount > 1) {
      if (s.inTransaction) s.cancel();
      mode = _Mode.pinch;
      return;
    }
    if (c.panMode || d.kind == PointerDeviceKind.trackpad) {
      mode = _Mode.pan;
      return;
    }
    final h = handleAt(start);
    if (h != null) {
      moving = s.selected;
      startBox = boundsOf(s.elements, moving);
      if (h.rotate) {
        mode = _Mode.rotate;
        s.begin('Rotate');
      } else {
        mode = _Mode.resize;
        handleSides = h.sides;
        if (moving.length == 1) {
          final e = findElement(s.elements, moving.first)!;
          startFrame = e.frame;
          startParent = parentMatrix(s.elements, e.id);
        }
        s.begin('Resize');
      }
      return;
    }
    final id = hit(start);
    if (id == null) {
      mode = _Mode.marquee;
      return;
    }
    if (!s.selected.contains(id)) s.select({id}, add: multiKey);
    moving = s.selected;
    if (moving.any((m) => findElement(s.elements, m)?.locked == true)) {
      mode = null;
      return;
    }
    startBox = boundsOf(s.elements, moving);
    mode = _Mode.move;
    s.begin('Move');
  }

  void onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount > 1 && mode != _Mode.pinch) {
      if (s.inTransaction) s.cancel();
      mode = _Mode.pinch;
      lastScale = d.scale;
    }
    final delta = d.localFocalPoint - start;
    final docDelta = Vec(delta.dx / c.zoom, delta.dy / c.zoom);
    switch (mode) {
      case _Mode.pinch:
        c.zoomBy(d.scale / lastScale, d.localFocalPoint);
        lastScale = d.scale;
        c.panBy(d.focalPointDelta);
      case _Mode.pan:
        c.panBy(d.focalPointDelta);
      case _Mode.move:
        var by = docDelta;
        if (shift) by = by.x.abs() >= by.y.abs() ? Vec(by.x, 0) : Vec(0, by.y);
        final top = s.entered == null
            ? s.elements
            : (findElement(s.elements, s.entered!)?.children ?? s.elements);
        final snapped = alt
            ? (delta: by, guides: const <SnapGuide>[])
            : snapMove(
                c.doc,
                top,
                moving,
                startBox!,
                by,
                threshold: 6 / c.zoom,
                options: c.snap,
              );
        c.guides = snapped.guides;
        s.preview(
          (base) => withPageElements(
            base,
            s.page,
            moveBy(base.page(s.page).elements, moving, snapped.delta),
          ),
        );
      case _Mode.resize:
        if (moving.length == 1 && startFrame != null) {
          final e = findElement(s.elements, moving.first)!;
          final keep =
              (c.registry.lookup(e.type)?.keepsAspect ?? false) != shift;
          final next = resizeFrame(
            startFrame!,
            startParent,
            handleSides,
            docDelta,
            keepAspect: keep,
            fromCenter: alt,
          );
          s.preview(
            (base) => withPageElements(
              base,
              s.page,
              setFrame(
                base.page(s.page).elements,
                moving.first,
                next,
                c.registry,
              ),
            ),
          );
        } else if (startBox != null) {
          final b = startBox!;
          final r = resizeFrame(
            Frame(b.x, b.y, b.width, b.height),
            Affine.identity,
            handleSides,
            docDelta,
            keepAspect: shift,
            fromCenter: alt,
          );
          s.preview(
            (base) => withPageElements(
              base,
              s.page,
              scaleSelection(
                base.page(s.page).elements,
                moving,
                b,
                Box(r.x, r.y, r.width, r.height),
                c.registry,
              ),
            ),
          );
        }
      case _Mode.rotate:
        final centre = c.toScreen(startBox!.center);
        double angle(Offset p) =>
            math.atan2(p.dy - centre.dy, p.dx - centre.dx) * 180 / math.pi;
        var by = angle(d.localFocalPoint) - angle(start);
        by = shift ? (by / 15).roundToDouble() * 15 : snapAngle(by, within: 2);
        s.preview(
          (base) => withPageElements(
            base,
            s.page,
            rotateBy(
              base.page(s.page).elements,
              moving,
              by,
              pivot: startBox!.center,
            ),
          ),
        );
      case _Mode.marquee:
        c.marquee = Rect.fromPoints(start, d.localFocalPoint);
        c.refresh();
      case null:
        break;
    }
  }

  void onScaleEnd(ScaleEndDetails d) {
    switch (mode) {
      case _Mode.move || _Mode.resize || _Mode.rotate:
        if (s.inTransaction) s.commit();
      case _Mode.marquee:
        final r = c.marquee;
        if (r != null && r.width > 3 && r.height > 3) {
          final a = c.toDoc(r.topLeft), b = c.toDoc(r.bottomRight);
          final ids = elementsInside(
            s.elements,
            Box(a.x, a.y, b.x - a.x, b.y - a.y),
            within: s.entered,
          );
          s.select(ids, add: multiKey);
        }
        c.marquee = null;
      default:
        break;
    }
    mode = null;
    c.guides = const [];
    startFrame = null;
    c.refresh();
  }

  void onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final zoomKey =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (zoomKey) {
      c.zoomBy(math.pow(1.0015, -e.scrollDelta.dy).toDouble(), e.localPosition);
    } else {
      c.panBy(shift ? Offset(-e.scrollDelta.dy, 0) : -e.scrollDelta);
    }
  }

  MouseCursor cursorAt(Offset p) {
    if (c.panMode)
      return mode == _Mode.pan
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.grab;
    final h = handleAt(p);
    if (h != null) {
      if (h.rotate) return SystemMouseCursors.alias;
      if (h.sides.x != 0 && h.sides.y != 0) {
        return h.sides.x == h.sides.y
            ? SystemMouseCursors.resizeUpLeftDownRight
            : SystemMouseCursors.resizeUpRightDownLeft;
      }
      return h.sides.x != 0
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown;
    }
    return hit(p) == null ? SystemMouseCursors.basic : SystemMouseCursors.move;
  }

  Offset hover = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final colors = HandyColors.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        if (c.viewport != size) {
          c.viewport = size;
          if (!c.fitted)
            WidgetsBinding.instance.addPostFrameCallback((_) => c.fit(size));
        }
        return Listener(
          onPointerSignal: onSignal,
          onPointerDown: (e) => touch =
              e.kind == PointerDeviceKind.touch ||
              e.kind == PointerDeviceKind.stylus,
          onPointerHover: (e) => setState(() => hover = e.localPosition),
          child: MouseRegion(
            cursor: cursorAt(hover),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onTap,
              onLongPressStart: onLongPress,
              onScaleStart: onScaleStart,
              onScaleUpdate: onScaleUpdate,
              onScaleEnd: onScaleEnd,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CanvasPainter(
                          c,
                          colors,
                          selectionShape(),
                          touch,
                        ),
                      ),
                    ),
                  ),
                  if (c.editingText != null) _textEditor(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The text being edited, typed in place over the element, in its face,
  /// size and turn.
  Widget _textEditor() {
    final id = c.editingText!;
    final e = findElement(s.elements, id);
    if (e == null) return const SizedBox.shrink();
    final m = worldMatrix(s.elements, id);
    final screen =
        Affine.translate(c.origin.dx, c.origin.dy) * Affine.scale(c.zoom) * m;
    final align = switch (e.prop<String>('align', 'left')) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
    return Positioned(
      left: 0,
      top: 0,
      child: Transform(
        transform: Matrix4(
          screen.a,
          screen.b,
          0,
          0,
          screen.c,
          screen.d,
          0,
          0,
          0,
          0,
          1,
          0,
          screen.e,
          screen.f,
          0,
          1,
        ),
        child: SizedBox(
          width: math.max(20, e.frame.width),
          height: e.frame.height,
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              key: const Key('canvas-text-editor'),
              controller: text,
              focusNode: textFocus,
              maxLines: null,
              expands: true,
              textAlign: align,
              style: cardTextStyle(
                e,
                e.prop<double>('size', 12),
              ).copyWith(height: e.prop<double>('lineHeight', 1.25)),
              decoration: const InputDecoration.collapsed(hintText: ''),
              onChanged: (v) => c.setProps(
                {id},
                {'text': v},
                label: 'Edit text',
                coalesce: 'text:$id',
              ),
              onTapOutside: (_) => finishTextEdit(),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final StudioController c;
  final HandyColors colors;
  final (List<Offset>, List<_Handle>)? selection;
  final bool touch;
  _CanvasPainter(this.c, this.colors, this.selection, this.touch);

  @override
  bool shouldRepaint(_CanvasPainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final doc = c.doc, page = c.session.current, b = doc.bleed;
    canvas.save();
    canvas.translate(c.origin.dx, c.origin.dy);
    canvas.scale(c.zoom);
    // The card and its bleed; art past the bleed is not shown.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(-b, -b, doc.width + 2 * b, doc.height + 2 * b),
    );
    if (page.background == null) {
      _checker(
        canvas,
        Rect.fromLTWH(-b, -b, doc.width + 2 * b, doc.height + 2 * b),
      );
    }
    paintPage(canvas, doc, page, c.paintContext, bleed: b);
    canvas.restore();
    final hair = 1 / c.zoom;
    if (b > 0) {
      // What is cut away is veiled, so the trim reads at a glance.
      final veil = Paint()..color = colors.ground.withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTWH(-b, -b, doc.width + 2 * b, b), veil);
      canvas.drawRect(
        Rect.fromLTWH(-b, doc.height, doc.width + 2 * b, b),
        veil,
      );
      canvas.drawRect(Rect.fromLTWH(-b, 0, b, doc.height), veil);
      canvas.drawRect(Rect.fromLTWH(doc.width, 0, b, doc.height), veil);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, doc.width, doc.height),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hair
        ..color = colors.control,
    );
    if (c.showGuides) {
      final guide = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hair
        ..color = const Color(0xFF8A929C);
      if (b > 0)
        _dashed(
          canvas,
          Rect.fromLTWH(-b, -b, doc.width + 2 * b, doc.height + 2 * b),
          guide,
          4 / c.zoom,
        );
      if (doc.safe > 0)
        _dashed(
          canvas,
          Rect.fromLTWH(
            doc.safe,
            doc.safe,
            doc.width - 2 * doc.safe,
            doc.height - 2 * doc.safe,
          ),
          guide,
          1.5 / c.zoom,
        );
    }
    final hue = Paint()
      ..color = colors.accent
      ..strokeWidth = hair;
    for (final g in c.guides) {
      canvas.drawLine(
        g.vertical ? Offset(g.at, g.from) : Offset(g.from, g.at),
        g.vertical ? Offset(g.at, g.to) : Offset(g.to, g.at),
        hue,
      );
    }
    final entered = c.session.entered;
    if (entered != null && findElement(c.session.elements, entered) != null) {
      final m = worldMatrix(c.session.elements, entered);
      final g = findElement(c.session.elements, entered)!;
      final pts = [
        Vec.zero,
        Vec(g.frame.width, 0),
        Vec(g.frame.width, g.frame.height),
        Vec(0, g.frame.height),
      ].map(m.apply).toList();
      final path = Path()
        ..addPolygon([for (final p in pts) Offset(p.x, p.y)], true);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hair
          ..color = colors.accent.withValues(alpha: 0.5),
      );
    }
    canvas.restore();

    final sel = selection;
    if (sel != null) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = colors.accent;
      canvas.drawPath(Path()..addPolygon(sel.$1, true), outline);
      final r = touch ? 7.0 : 4.0;
      for (final h in sel.$2) {
        if (h.rotate) {
          canvas.drawLine((sel.$1[0] + sel.$1[1]) / 2, h.at, outline);
          canvas.drawCircle(h.at, r + 1, Paint()..color = Colors.white);
          canvas.drawCircle(h.at, r + 1, outline);
        } else {
          final rect = Rect.fromCenter(
            center: h.at,
            width: r * 2,
            height: r * 2,
          );
          canvas.drawRect(rect, Paint()..color = Colors.white);
          canvas.drawRect(rect, outline);
        }
      }
    }
    final m = c.marquee;
    if (m != null) {
      canvas.drawRect(
        m,
        Paint()..color = colors.accent.withValues(alpha: 0.08),
      );
      canvas.drawRect(
        m,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.accent,
      );
    }
  }

  void _checker(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = const Color(0xFFFFFFFF));
    final grey = Paint()..color = const Color(0xFFE9ECEF);
    final step = 8 / c.zoom;
    for (var y = r.top, row = 0; y < r.bottom; y += step, row++) {
      for (
        var x = r.left + (row.isOdd ? step : 0);
        x < r.right;
        x += step * 2
      ) {
        canvas.drawRect(Rect.fromLTWH(x, y, step, step), grey);
      }
    }
  }

  void _dashed(Canvas canvas, Rect r, Paint p, double dash) {
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var t = 0.0; t < len; t += dash * 2) {
        canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, len), p);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }
}
