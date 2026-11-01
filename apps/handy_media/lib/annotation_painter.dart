import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';

/// Shared by editor display and full-resolution flattened PNG export.
void paintAnnotations(Canvas canvas, Size size, List<ProjectLayer> layers) {
  final stroke = math.max(2.0, size.shortestSide * 0.006),
      font = math.max(12.0, size.shortestSide * 0.045);
  // Match legacy Snap: opaque redaction masks render last.
  final ordered = [
    ...layers.where((l) => l.kind != 'redact'),
    ...layers.where((l) => l.kind == 'redact'),
  ];
  var badge = 0;
  for (final layer in ordered) {
    final g = layer.geometry,
        rect = Rect.fromLTWH(
          g.x * size.width,
          g.y * size.height,
          g.width * size.width,
          g.height * size.height,
        ),
        color = Color(int.parse('FF${layer.color.substring(1)}', radix: 16));
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (layer.kind) {
      case 'rect':
        canvas.drawRect(rect, paint);
      case 'ellipse':
        canvas.drawOval(rect, paint);
      case 'redact':
        canvas.drawRect(rect, Paint()..color = Colors.black);
      case 'highlight':
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.3));
      case 'spotlight':
        final path = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRect(rect);
        canvas.drawPath(
          path,
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
      case 'pen':
        final points = layer.points!;
        final path = Path()
          ..moveTo(points.first.x * size.width, points.first.y * size.height);
        for (final point in points.skip(1)) {
          path.lineTo(point.x * size.width, point.y * size.height);
        }
        canvas.drawPath(path, paint);
      case 'arrow':
        final points = layer.points,
            p = points?.first ?? ProjectPoint(g.x, g.y),
            q = points?.last ?? ProjectPoint(g.x + g.width, g.y + g.height),
            a = Offset(p.x * size.width, p.y * size.height),
            b = Offset(q.x * size.width, q.y * size.height);
        canvas.drawLine(a, b, paint);
        final angle = math.atan2(b.dy - a.dy, b.dx - a.dx),
            head = math.max(10.0, stroke * 4);
        final path = Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(
            b.dx - head * math.cos(angle - 0.5),
            b.dy - head * math.sin(angle - 0.5),
          )
          ..lineTo(
            b.dx - head * math.cos(angle + 0.5),
            b.dy - head * math.sin(angle + 0.5),
          )
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      case 'step':
        badge++;
        canvas.drawCircle(
          rect.center,
          math.max(font * 0.7, rect.shortestSide / 2),
          Paint()..color = color,
        );
        final label = TextPainter(
          text: TextSpan(
            text: layer.text.isEmpty ? '$badge' : layer.text,
            style: TextStyle(
              color: Colors.white,
              fontSize: font,
              fontWeight: FontWeight.w700,
              fontFamily: _face,
              fontFamilyFallback: handyFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(1, rect.width));
        label.paint(
          canvas,
          rect.center - Offset(label.width / 2, label.height / 2),
        );
      case 'text':
        final label = TextPainter(
          text: TextSpan(
            text: layer.text.split('\n').take(10).join('\n'),
            style: TextStyle(
              color: color,
              fontSize: font,
              height: 1.15,
              fontWeight: FontWeight.w500,
              fontFamily: _face,
              fontFamilyFallback: handyFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lines = label.computeLineMetrics(),
            baseline = lines.isEmpty ? font : lines.first.baseline;
        label.paint(
          canvas,
          Offset(rect.left, rect.top + font * 1.15 - baseline),
        );
    }
  }
}

/// The bundled text face, so a note looks the same on screen and in every
/// export, on every platform, with Vietnamese marks; other scripts fall
/// back to the system's fonts.
const _face = 'packages/handy_ui/Geist';

class AnnotationPainter extends CustomPainter {
  final List<ProjectLayer> layers;
  final Size referenceSize;
  AnnotationPainter(this.layers, this.referenceSize);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / referenceSize.width,
      size.height / referenceSize.height,
    );
    paintAnnotations(canvas, referenceSize, layers);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnnotationPainter old) =>
      old.layers != layers || old.referenceSize != referenceSize;
}

Future<Uint8List> flattenAnnotation(
  ProjectStep step,
  Uint8List source, {
  int? maxWidth,
  int? maxHeight,
  int maxPixels = 16000000,
}) async {
  if (maxWidth != null && maxWidth < 1 ||
      maxHeight != null && maxHeight < 1 ||
      maxPixels < 1 ||
      maxPixels > 16000000) {
    throw const FormatException('Invalid PNG export bounds');
  }
  final input = Uint8List.fromList(source);
  verifyProjectImage(input, step);
  final scale = [
    1.0,
    if (maxWidth != null) maxWidth / step.imageWidth,
    if (maxHeight != null) maxHeight / step.imageHeight,
    math.sqrt(maxPixels / (step.imageWidth * step.imageHeight)),
  ].reduce(math.min);
  final width = math.max(1, (step.imageWidth * scale).floor()),
      height = math.max(1, (step.imageHeight * scale).floor());
  final codec = await ui.instantiateImageCodec(
    input,
    targetWidth: width,
    targetHeight: height,
    allowUpscaling: false,
  );
  ui.FrameInfo? frame;
  try {
    frame = await codec.getNextFrame();
    final recorder = ui.PictureRecorder(),
        canvas = Canvas(recorder),
        size = Size(step.imageWidth.toDouble(), step.imageHeight.toDouble());
    canvas.scale(width / step.imageWidth, height / step.imageHeight);
    canvas.drawImageRect(
      frame.image,
      Rect.fromLTWH(
        0,
        0,
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      ),
      Offset.zero & size,
      Paint(),
    );
    paintAnnotations(canvas, size, step.annotations);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null || data.lengthInBytes > 20000000)
          throw const FormatException('PNG export exceeds limit');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    frame?.image.dispose();
    codec.dispose();
  }
}
