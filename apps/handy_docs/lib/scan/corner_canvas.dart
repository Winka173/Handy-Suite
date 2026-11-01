import 'dart:typed_data';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';

/// The photo with four numbered dots to drag onto the paper's corners.
class CornerCanvas extends StatelessWidget {
  final Uint8List png;
  final double ratio;
  final List<ScanPoint> corners;
  final ValueChanged<List<ScanPoint>> onChange;
  const CornerCanvas({
    super.key,
    required this.png,
    required this.ratio,
    required this.corners,
    required this.onChange,
  });
  @override
  Widget build(BuildContext context) => HandyPictureFrame(
    bytes: png,
    ratio: ratio,
    overlays: (canvas) => [
      Positioned(
        left: 22,
        top: 22,
        width: canvas.width,
        height: canvas.height,
        child: CustomPaint(
          painter: _CornersPainter(
            corners,
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      for (var i = 0; i < 4; i++)
        Positioned(
          left: corners[i].x * canvas.width,
          top: corners[i].y * canvas.height,
          width: 44,
          height: 44,
          child: Semantics(
            label: '${tr(context, 'Corner', 'Góc')} ${i + 1}',
            child: GestureDetector(
              key: ValueKey('scan-corner-$i'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                final next = List<ScanPoint>.of(corners);
                next[i] = ScanPoint(
                  (corners[i].x + d.delta.dx / canvas.width).clamp(0, 1),
                  (corners[i].y + d.delta.dy / canvas.height).clamp(0, 1),
                );
                onChange(next);
              },
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _CornersPainter extends CustomPainter {
  final List<ScanPoint> points;
  final Color color;
  _CornersPainter(this.points, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(points.first.x * size.width, points.first.y * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CornersPainter old) =>
      old.points != points || old.color != color;
}
