import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';

Future<List<Color>> marks(WidgetTester t, Color primary) async {
  late List<Color> out;
  await t.pumpWidget(
    MaterialApp(
      theme: buildHandyTheme(primary, Brightness.light),
      home: Builder(
        builder: (context) {
          out = [
            for (var i = 0; i < HandyPalette.count; i++)
              HandyPalette.of(context, i).mark,
          ];
          return const SizedBox();
        },
      ),
    ),
  );
  // MaterialApp animates between themes.
  await t.pumpAndSettle();
  return out;
}

double gap(Color a, Color b) {
  final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  testWidgets('things never take the colour nearest the app own', (t) async {
    // The seven app colours of the suite.
    for (final app in const [
      Color(0xFF0F8A5F),
      Color(0xFF1D5FBF),
      Color(0xFFB7791F),
      Color(0xFFC2255C),
      Color(0xFF4D7C0F),
      Color(0xFF0E7490),
      Color(0xFFE8590C),
    ]) {
      final list = await marks(t, app);
      final distinct = list.toSet().length;
      expect(distinct, inInclusiveRange(6, 7));
      // The cycle starts again after the usable colours.
      expect(list[distinct], list[0]);
      for (final c in list) {
        expect(gap(c, app), greaterThanOrEqualTo(25));
      }
    }
  });

  test('forKey is stable and in range', () {
    expect(HandyPalette.forKey('guide-1'), HandyPalette.forKey('guide-1'));
    for (final k in ['a', 'b', 'guide-42', 'Hướng dẫn']) {
      expect(
        HandyPalette.forKey(k),
        inInclusiveRange(0, HandyPalette.count - 1),
      );
    }
  });
}
