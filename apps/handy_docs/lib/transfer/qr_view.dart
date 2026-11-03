import 'package:handy_ui/kit.dart';

/// One QR code drawn on white with its quiet zone, in both themes: a
/// camera reads dark modules on a light ground.
class QrView extends StatelessWidget {
  final List<List<bool>> modules;
  final double size;
  final String label;
  const QrView({
    super.key,
    required this.modules,
    required this.size,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: HandyColors.of(context).border),
      ),
      child: CustomPaint(painter: _QrPainter(modules)),
    ),
  );
}

class _QrPainter extends CustomPainter {
  final List<List<bool>> modules;
  _QrPainter(this.modules);

  @override
  void paint(Canvas canvas, Size size) {
    final n = modules.length;
    if (n == 0) return;
    // Four modules of quiet zone on every side, as the standard asks.
    final cell = size.width / (n + 8);
    final ink = Paint()..color = const Color(0xFF111111);
    final path = Path();
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (!modules[y][x]) continue;
        path.addRect(
          Rect.fromLTWH((x + 4) * cell, (y + 4) * cell, cell + .3, cell + .3),
        );
      }
    }
    canvas.drawPath(path, ink);
  }

  @override
  bool shouldRepaint(_QrPainter old) => !identical(old.modules, modules);
}
