import 'dart:typed_data';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';

class CropCanvas extends StatelessWidget {
  final Uint8List png;
  final double ratio;
  final ImageRegion region;
  final ValueChanged<ImageRegion> onChange;
  const CropCanvas({
    super.key,
    required this.png,
    required this.ratio,
    required this.region,
    required this.onChange,
  });
  @override
  Widget build(BuildContext context) => HandyPictureFrame(
    bytes: png,
    ratio: ratio,
    overlays: (canvas) {
      double clamp(double value, double low, double high) =>
          value.clamp(low, high).toDouble();
      final r = region;
      return [
        Positioned(
          left: 22 + r.x * canvas.width,
          top: 22 + r.y * canvas.height,
          width: r.width * canvas.width,
          height: r.height * canvas.height,
          child: GestureDetector(
            key: const Key('crop-move'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => onChange(
              ImageRegion(
                x: clamp(r.x + d.delta.dx / canvas.width, 0, 1 - r.width),
                y: clamp(r.y + d.delta.dy / canvas.height, 0, 1 - r.height),
                width: r.width,
                height: r.height,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < 4; i++)
          Positioned(
            left: (i == 1 || i == 2 ? r.x + r.width : r.x) * canvas.width,
            top: (i >= 2 ? r.y + r.height : r.y) * canvas.height,
            width: 44,
            height: 44,
            child: GestureDetector(
              key: ValueKey('crop-corner-$i'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                var left = r.x,
                    top = r.y,
                    right = r.x + r.width,
                    bottom = r.y + r.height;
                if (i == 0 || i == 3) {
                  left = clamp(
                    left + d.delta.dx / canvas.width,
                    0,
                    right - 0.02,
                  );
                } else {
                  right = clamp(
                    right + d.delta.dx / canvas.width,
                    left + 0.02,
                    1,
                  );
                }
                if (i < 2) {
                  top = clamp(
                    top + d.delta.dy / canvas.height,
                    0,
                    bottom - 0.02,
                  );
                } else {
                  bottom = clamp(
                    bottom + d.delta.dy / canvas.height,
                    top + 0.02,
                    1,
                  );
                }
                onChange(
                  ImageRegion(
                    x: left,
                    y: top,
                    width: right - left,
                    height: bottom - top,
                  ),
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
          ),
      ];
    },
  );
}
