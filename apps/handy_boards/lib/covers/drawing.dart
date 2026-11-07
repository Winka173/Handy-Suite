part of 'cover_art.dart';

/// Small drawing vocabulary; compositions live in separate family files.
/// Paint is reused within a scene. No random values, shaders, or animation.
class _Art {
  final Canvas c;
  final _Style style;
  final Rect bounds;
  final Paint _paint = Paint()..isAntiAlias = true;
  _Art(this.c, this.style, this.bounds);

  /// Only visit visible tiles, including one overscan tile for shifted rows.
  void tiles(
    double pitch,
    void Function(double x, double y, int row, int col) draw,
  ) {
    for (
      var row = (bounds.top / pitch).floor() - 1;
      row <= (bounds.bottom / pitch).ceil();
      row++
    ) {
      for (
        var col = (bounds.left / pitch).floor() - 1;
        col <= (bounds.right / pitch).ceil();
        col++
      ) {
        draw(col * pitch, row * pitch, row, col);
      }
    }
  }

  Color get g => style.ground;
  Color get i => style.ink;
  Color get b => style.accent;
  Color get s => style.soft;

  Paint pen(Color color, [double width = 0]) => _paint
    ..color = color
    ..style = width == 0 ? PaintingStyle.fill : PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  void rect(
    double x,
    double y,
    double w,
    double h,
    Color color, [
    double radius = 0,
    double stroke = 0,
  ]) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      pen(color, stroke),
    );
  }

  void oval(
    double x,
    double y,
    double w,
    double h,
    Color color, [
    double stroke = 0,
  ]) => c.drawOval(
    Rect.fromCenter(center: Offset(x, y), width: w, height: h),
    pen(color, stroke),
  );
  void line(
    double x,
    double y,
    double x2,
    double y2,
    Color color, [
    double width = 2,
  ]) => c.drawLine(Offset(x, y), Offset(x2, y2), pen(color, width));
  void poly(List<double> points, Color color, [double stroke = 0]) {
    final p = Path()..moveTo(points[0], points[1]);
    for (var n = 2; n < points.length; n += 2) {
      p.lineTo(points[n], points[n + 1]);
    }
    p.close();
    c.drawPath(p, pen(color, stroke));
  }

  void curve(List<double> p, Color color, [double width = 2]) => c.drawPath(
    Path()
      ..moveTo(p[0], p[1])
      ..cubicTo(p[2], p[3], p[4], p[5], p[6], p[7]),
    pen(color, width),
  );
  void arc(
    double x,
    double y,
    double w,
    double h,
    double start,
    double sweep,
    Color color, [
    double width = 3,
  ]) => c.drawArc(
    Rect.fromCenter(center: Offset(x, y), width: w, height: h),
    start,
    sweep,
    false,
    pen(color, width),
  );
  void turn(double x, double y, double angle, void Function() draw) {
    c.save();
    c.translate(x, y);
    c.rotate(angle);
    draw();
    c.restore();
  }

  void leaf(double x, double y, double length, double angle, Color color) {
    turn(x, y, angle, () {
      final p = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          -length * .55,
          -length * .2,
          -length * .38,
          -length * .86,
          0,
          -length,
        )
        ..cubicTo(
          length * .38,
          -length * .86,
          length * .55,
          -length * .2,
          0,
          0,
        );
      c.drawPath(p, pen(color));
    });
  }

  void sprig(double x, double y, double height, Color color) {
    line(x, y, x, y - height, color, 3);
    for (var n = 0; n < 3; n++) {
      final dy = y - height * .24 - n * height * .25;
      leaf(x, dy, height * .34, -.85, color);
      leaf(x, dy - 8, height * .29, .85, color);
    }
  }

  void book(double x, double y, double w, double h, Color color) {
    rect(x, y, w, h, color, 3);
    rect(x + 5, y + 4, w - 10, h - 9, s, 2);
    line(x + 8, y + h - 6, x + w - 7, y + h - 6, g, 2);
  }

  void pencil(double x, double y, double length, double angle, Color color) {
    turn(x, y, angle, () {
      rect(-5, -length, 10, length, color, 1);
      poly([-5, 0, 5, 0, 0, 15], s);
      poly([-2, 9, 2, 9, 0, 15], i);
      rect(-5, -length - 10, 10, 10, b, 2);
      line(-1, -length + 4, -1, -4, s, 1);
    });
  }

  void mug(double x, double y, Color color) {
    oval(x + 32, y + 3, 30, 33, color, 5);
    rect(x - 28, y - 21, 56, 49, color, 8);
    oval(x, y - 19, 54, 13, s);
    oval(x, y - 19, 42, 8, i);
  }

  void star(double x, double y, double r, Color color) {
    final pts = <double>[];
    for (var n = 0; n < 10; n++) {
      final angle = -math.pi / 2 + n * math.pi / 5;
      final radius = n.isEven ? r : r * .43;
      pts.addAll([x + math.cos(angle) * radius, y + math.sin(angle) * radius]);
    }
    poly(pts, color);
  }
}
