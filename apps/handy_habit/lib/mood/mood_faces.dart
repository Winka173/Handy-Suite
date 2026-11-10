import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import 'mood_sheet.dart' show moodLabel;

/// Expressions, labels and selection all carry meaning without colour.
class MoodFaces extends StatelessWidget {
  final int? selected;
  final ValueChanged<int>? onSelected;
  const MoodFaces({super.key, this.selected, this.onSelected});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = scale > 1.3 || box.maxWidth < 330 ? 3 : 5;
      final width = (box.maxWidth - (columns - 1) * 8) / columns;
      final p = HabitPalette.of(context);
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var n = 1; n <= 5; n++)
            SizedBox(
              width: width,
              child: Semantics(
                selected: selected == n,
                child: OutlinedButton(
                  key: Key('mood-choice-$n'),
                  onPressed: onSelected == null ? null : () => onSelected!(n),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.topCenter,
                    minimumSize: const Size(48, 112),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    backgroundColor: selected == n ? p.ochreField : p.surface,
                    side: BorderSide(
                      color: selected == n ? p.anchor : p.control,
                      width: selected == n ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoodFace(value: n),
                      const SizedBox(height: 8),
                      Text(
                        moodLabel(context, n),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      if (selected == n) const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class MoodFace extends StatelessWidget {
  final int value;
  final double size;
  const MoodFace({super.key, required this.value, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _Face(value, p.anchor, p.ochreField),
      ),
    );
  }
}

class _Face extends CustomPainter {
  final int value;
  final Color ink, fill;
  const _Face(this.value, this.ink, this.fill);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    canvas.drawCircle(const Offset(20, 20), 18, Paint()..color = fill);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(20, 20), 18, line);
    for (final x in [13.0, 27.0]) {
      if (value == 5) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 3, 16)
            ..quadraticBezierTo(x, 11, x + 3, 16),
          line,
        );
      } else {
        canvas.drawCircle(Offset(x, 16), 1.5, Paint()..color = ink);
      }
    }
    final mouth = Path()..moveTo(12, value <= 2 ? 29 : 25);
    if (value == 3) {
      mouth.lineTo(28, 25);
    } else {
      mouth.quadraticBezierTo(
        20,
        switch (value) {
          1 => 16,
          2 => 21,
          4 => 33,
          _ => 37,
        },
        28,
        value <= 2 ? 29 : 25,
      );
    }
    canvas.drawPath(mouth, line);
    if (value == 1) {
      canvas.drawLine(const Offset(10, 11), const Offset(16, 9), line);
      canvas.drawLine(const Offset(24, 9), const Offset(30, 11), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Face old) =>
      old.value != value || old.ink != ink || old.fill != fill;
}
