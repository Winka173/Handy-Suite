import 'dart:typed_data';
import 'dart:math' as math;
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import 'annotation_painter.dart';

class AnnotationCanvas extends StatelessWidget {
  final ProjectStep step;
  final Uint8List png;
  final String? selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<ProjectLayer> onChange;
  final VoidCallback onGestureStart, onGestureEnd;
  final bool drawing;
  final bool panEnabled;
  final TransformationController? transformation;
  final ValueChanged<List<ProjectPoint>>? onStroke;

  /// What a screen reader says for each note.
  final String Function(ProjectLayer layer)? describe;

  /// A shape tool in hand: dragging draws one, a tap places one.
  final String? tool;
  final void Function(
    String kind,
    LayerGeometry? area,
    List<ProjectPoint>? line,
  )?
  onCreate;
  const AnnotationCanvas({
    super.key,
    required this.step,
    required this.png,
    required this.selected,
    required this.onSelect,
    required this.onChange,
    required this.onGestureStart,
    required this.onGestureEnd,
    this.drawing = false,
    this.panEnabled = false,
    this.transformation,
    this.onStroke,
    this.tool,
    this.onCreate,
    this.describe,
  });
  @override
  Widget build(BuildContext context) {
    final frame = HandyPictureFrame(
      bytes: png,
      ratio: step.imageWidth / step.imageHeight,
      overlays: (size) => [
        Positioned(
          left: 22,
          top: 22,
          width: size.width,
          height: size.height,
          child: IgnorePointer(
            child: CustomPaint(
              painter: AnnotationPainter(
                step.annotations,
                Size(step.imageWidth.toDouble(), step.imageHeight.toDouble()),
              ),
            ),
          ),
        ),
        for (final layer in [
          ...step.annotations.where((l) => l.id != selected),
          ...step.annotations.where((l) => l.id == selected),
        ])
          _target(context, layer, size),
        if (step.annotations.any((l) => l.id == selected))
          _handle(
            context,
            step.annotations.firstWhere((l) => l.id == selected),
            size,
          ),
        if (tool != null && tool != 'pen' && onCreate != null)
          Positioned(
            left: 22,
            top: 22,
            width: size.width,
            height: size.height,
            child: _ShapeInput(kind: tool!, onCreate: onCreate!),
          ),
        if (drawing && onStroke != null)
          Positioned(
            left: 22,
            top: 22,
            width: size.width,
            height: size.height,
            child: _StrokeInput(
              reference: Size(
                step.imageWidth.toDouble(),
                step.imageHeight.toDouble(),
              ),
              onStroke: onStroke!,
            ),
          ),
      ],
    );
    if (panEnabled)
      return InteractiveViewer(
        key: const Key('annotation-viewport'),
        transformationController: transformation,
        minScale: 1,
        maxScale: 3,
        child: IgnorePointer(child: frame),
      );
    if (transformation == null) return frame;
    return ClipRect(
      child: AnimatedBuilder(
        animation: transformation!,
        child: frame,
        builder: (context, child) => Transform(
          transform: transformation!.value,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
    );
  }

  Widget _target(BuildContext context, ProjectLayer layer, Size size) {
    final g = layerBounds(layer);
    return Positioned(
      left: 22 + g.x * size.width,
      top: 22 + g.y * size.height,
      width: (g.width * size.width).clamp(math.min(20, size.width), size.width),
      height: (g.height * size.height).clamp(
        math.min(20, size.height),
        size.height,
      ),
      child: Semantics(
        button: true,
        selected: layer.id == selected,
        label:
            describe?.call(layer) ??
            [layer.kind, if (layer.text.isNotEmpty) layer.text].join(': '),
        child: GestureDetector(
          key: ValueKey('layer-${layer.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(layer.id),
          onPanStart: (_) {
            onSelect(layer.id);
            onGestureStart();
          },
          onPanEnd: (_) => onGestureEnd(),
          onPanCancel: onGestureEnd,
          onPanUpdate: (d) {
            final next = LayerGeometry(
              (g.x + d.delta.dx / size.width).clamp(0, 1 - g.width),
              (g.y + d.delta.dy / size.height).clamp(0, 1 - g.height),
              g.width,
              g.height,
            );
            onChange(
              ProjectLayer.parse({
                ...layer.toJson(),
                ...g.toJson(),
              }).copyWith(geometry: next),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: layer.id == selected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle(BuildContext context, ProjectLayer layer, Size size) {
    final g = layerBounds(layer);
    return Positioned(
      left: (g.x + g.width) * size.width,
      top: (g.y + g.height) * size.height,
      width: 44,
      height: 44,
      child: GestureDetector(
        key: const Key('layer-resize'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onGestureStart(),
        onPanEnd: (_) => onGestureEnd(),
        onPanCancel: onGestureEnd,
        onPanUpdate: (d) {
          final next = LayerGeometry(
            g.x,
            g.y,
            (g.width + d.delta.dx / size.width).clamp(
              (1 - g.x).clamp(0.0, 0.01),
              1 - g.x,
            ),
            (g.height + d.delta.dy / size.height).clamp(
              (1 - g.y).clamp(0.0, 0.01),
              1 - g.y,
            ),
          );
          onChange(
            ProjectLayer.parse({
              ...layer.toJson(),
              ...g.toJson(),
            }).copyWith(geometry: next),
          );
        },
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _StrokeInput extends StatefulWidget {
  final Size reference;
  final ValueChanged<List<ProjectPoint>> onStroke;
  const _StrokeInput({required this.reference, required this.onStroke});
  @override
  State<_StrokeInput> createState() => _StrokeInputState();
}

class _StrokeInputState extends State<_StrokeInput> {
  List<ProjectPoint> points = [];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      ProjectPoint point(Offset value) => ProjectPoint(
        (value.dx / box.maxWidth).clamp(0, 1),
        (value.dy / box.maxHeight).clamp(0, 1),
      );
      return GestureDetector(
        key: const Key('capture-pen-input'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => setState(() => points = [point(d.localPosition)]),
        onPanUpdate: (d) {
          if (points.length < 2000)
            setState(() => points = [...points, point(d.localPosition)]);
        },
        onPanCancel: () => setState(() => points = []),
        onPanEnd: (_) {
          if (points.length >= 2) widget.onStroke(List.unmodifiable(points));
          if (mounted) setState(() => points = []);
        },
        child: CustomPaint(
          painter: points.length >= 2
              ? AnnotationPainter([
                  ProjectLayer(
                    id: 'preview',
                    kind: 'pen',
                    geometry: const LayerGeometry(0, 0, 1, 1),
                    points: points,
                  ),
                ], widget.reference)
              : null,
        ),
      );
    },
  );
}

/// Draws a new layer of [kind]: a drag gives its box (or, for an arrow, its
/// line); a tap gives the default size centred where the finger landed.
class _ShapeInput extends StatefulWidget {
  final String kind;
  final void Function(String, LayerGeometry?, List<ProjectPoint>?) onCreate;
  const _ShapeInput({required this.kind, required this.onCreate});
  @override
  State<_ShapeInput> createState() => _ShapeInputState();
}

class _ShapeInputState extends State<_ShapeInput> {
  Offset? from, to;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      ProjectPoint norm(Offset o) => ProjectPoint(
        (o.dx / box.maxWidth).clamp(0, 1),
        (o.dy / box.maxHeight).clamp(0, 1),
      );
      void place(Offset at) {
        const w = 0.3, h = 0.14;
        final c = norm(at);
        widget.onCreate(
          widget.kind,
          LayerGeometry(
            (c.x - w / 2).clamp(0, 1 - w),
            (c.y - h / 2).clamp(0, 1 - h),
            w,
            h,
          ),
          null,
        );
      }

      void finish() {
        final a = from, b = to;
        setState(() => from = to = null);
        if (a == null || b == null) return;
        final p = norm(a), q = norm(b);
        if ((p.x - q.x).abs() < .02 && (p.y - q.y).abs() < .02) {
          return place(a);
        }
        if (widget.kind == 'arrow')
          return widget.onCreate('arrow', null, [p, q]);
        final x = math.min(p.x, q.x), y = math.min(p.y, q.y);
        widget.onCreate(
          widget.kind,
          LayerGeometry(
            x,
            y,
            math.max((p.x - q.x).abs(), .02).clamp(0, 1 - x).toDouble(),
            math.max((p.y - q.y).abs(), .02).clamp(0, 1 - y).toDouble(),
          ),
          null,
        );
      }

      final color = Theme.of(context).colorScheme.primary;
      return GestureDetector(
        key: const Key('capture-shape-input'),
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => place(d.localPosition),
        onPanStart: (d) => setState(() => from = to = d.localPosition),
        onPanUpdate: (d) => setState(() => to = d.localPosition),
        onPanEnd: (_) => finish(),
        onPanCancel: () => setState(() => from = to = null),
        child: MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: CustomPaint(
            painter: from == null || to == null
                ? null
                : _Rubber(from!, to!, widget.kind == 'arrow', color),
          ),
        ),
      );
    },
  );
}

class _Rubber extends CustomPainter {
  final Offset a, b;
  final bool line;
  final Color color;
  _Rubber(this.a, this.b, this.line, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    line
        ? canvas.drawLine(a, b, paint)
        : canvas.drawRect(Rect.fromPoints(a, b), paint);
  }

  @override
  bool shouldRepaint(_Rubber old) => old.a != a || old.b != b;
}
