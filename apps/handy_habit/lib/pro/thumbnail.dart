import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import 'entitlements.dart';

/// Tiny drawn UI, with the same bead/routine marks as Habit's live panels.
class ProThumbnail extends CustomPainter {
  final HabitProFeature feature;
  final HabitPalette palette;
  ProThumbnail(this.feature, this.palette);
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = palette.muted
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final ink = Paint()..color = palette.vermilion;
    void stroke(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), line);
    void dot(double x, double y, {bool filled = false}) =>
        canvas.drawCircle(Offset(x, y), 3, filled ? ink : line);
    if (feature == HabitProFeature.days || feature == HabitProFeature.heatmap) {
      for (var row = 0; row < 3; row++)
        for (var col = 0; col < 5; col++)
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(4 + col * 10, 6 + row * 13, 7, 9),
              const Radius.circular(2),
            ),
            (row + col) % 3 == 0 ? ink : line,
          );
    } else if (feature == HabitProFeature.timeLeft) {
      canvas.drawCircle(const Offset(28, 24), 18, line);
      stroke(28, 24, 28, 12);
      stroke(28, 24, 39, 29);
    } else if (feature == HabitProFeature.choices ||
        feature == HabitProFeature.dependencies) {
      stroke(9, 24, 25, 24);
      stroke(25, 24, 43, 10);
      stroke(25, 24, 43, 38);
      dot(9, 24, filled: true);
      dot(43, 10);
      dot(43, 38, filled: feature == HabitProFeature.dependencies);
    } else if (feature == HabitProFeature.stacking) {
      stroke(8, 24, 48, 24);
      for (var i = 0; i < 3; i++) dot(8 + i * 20, 24, filled: i == 1);
    } else if (feature == HabitProFeature.blocks ||
        feature == HabitProFeature.presets ||
        feature == HabitProFeature.reports) {
      for (var i = 0; i < (feature == HabitProFeature.blocks ? 2 : 1); i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              5 + i * 24,
              5,
              feature == HabitProFeature.blocks ? 20 : 46,
              38,
            ),
            const Radius.circular(3),
          ),
          line,
        );
        for (var j = 0; j < 3; j++)
          stroke(
            9 + i * 24,
            13 + j * 10,
            feature == HabitProFeature.blocks ? 20 + i * 24 : 44,
            13 + j * 10,
          );
      }
    } else if (feature == HabitProFeature.mood) {
      for (var i = 0; i < 4; i++) {
        dot(9 + i * 12, 12, filled: i < 3);
        dot(9 + i * 12, 35, filled: i < 2);
      }
    } else if (feature == HabitProFeature.goals) {
      stroke(7, 31, 47, 31);
      for (var i = 0; i < 5; i++) dot(7 + i * 10, 31, filled: i < 4);
      stroke(35, 19, 47, 19);
      stroke(42, 14, 47, 19);
      stroke(42, 24, 47, 19);
    } else if (feature == HabitProFeature.unfinished) {
      for (var i = 0; i < 3; i++) {
        final y = 10.0 + i * 14;
        canvas.drawCircle(Offset(8, y), 3, line);
        canvas.drawLine(Offset(16, y), Offset(i == 1 ? 38 : 48, y), line);
      }
      canvas.drawCircle(const Offset(8, 24), 3, ink);
    } else if (feature == HabitProFeature.studio) {
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(5, 10.0 + i * 14),
          Offset(51, 10.0 + i * 14),
          line,
        );
        for (var j = 0; j < 4; j++)
          canvas.drawCircle(
            Offset(9.0 + j * 12, 10.0 + i * 14),
            3,
            j == i ? ink : line,
          );
      }
    } else {
      for (var i = 0; i < 4; i++)
        canvas.drawRect(
          Rect.fromLTWH(5.0 + i * 12, 40.0 - (i + 1) * 7, 7, (i + 1) * 7.0),
          i == 3 ? ink : line,
        );
    }
  }

  @override
  bool shouldRepaint(ProThumbnail old) =>
      old.feature != feature || old.palette != palette;
}
