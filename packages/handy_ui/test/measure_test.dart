import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;

void main() {
  test('a length is its share of the reference edge', () {
    expect(
      handyMeasureMm(
        Offset.zero,
        const Offset(856, 0),
        85.6,
        const Offset(10, 10),
        const Offset(10, 430),
      ),
      closeTo(42, 1e-9),
    );
    expect(
      handyMeasureMm(
        Offset.zero,
        Offset.zero,
        85.6,
        Offset.zero,
        const Offset(1, 1),
      ),
      isNull,
    );
    expect(handyMeasureLabel(42.4), '≈ 42 mm');
    expect(handyMeasureLabel(185), '≈ 18.5 cm');
    expect(handyMeasureLabel(300), '≈ 30 cm');
  });

  testWidgets('tapping the edge, then a length, reads it in millimetres', (
    t,
  ) async {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 400, height: 300)),
    );
    final seen = <List<double>>[];
    await t.pumpWidget(
      MaterialApp(
        theme: buildHandyTheme(
          const Color(0xff1450f5),
          Brightness.light,
          HandyBrand.handyCard,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: HandyMeasureBoard(
              image: png,
              referenceMm: 85.6,
              onChanged: seen.add,
            ),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
    final board = find.byKey(const Key('measure-board'));
    final origin = t.getTopLeft(board);
    final scale = t.getSize(board).width / 400;
    Future<void> tap(double x, double y) async {
      await t.tapAt(origin + Offset(x, y) * scale);
      await t.pump();
    }

    await tap(50, 50);
    await tap(250, 50); // a 200 px reference edge = 85.6 mm
    await tap(50, 200);
    await tap(50, 300 - 1);
    expect(seen.last.single, closeTo(85.6 * 99 / 200, 0.5));
    final state = t.state<HandyMeasureBoardState>(
      find.byType(HandyMeasureBoard),
    );
    state.undo();
    await t.pump();
    expect(seen.last, isEmpty);
    state.undo();
    expect(state.points, isEmpty);
  });
}
