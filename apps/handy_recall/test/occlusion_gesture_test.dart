import 'dart:convert';
import 'dart:ui' as ui;
import 'package:handy_ui/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_recall_app/occlusion_editor.dart';

Future<String> imageUri() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 160, 80),
    ui.Paint()..color = const ui.Color(0xff228844),
  );
  final picture = recorder.endRecording(),
      bitmap = await picture.toImage(160, 80),
      data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
  final uri =
      'data:image/png;base64,${base64Encode(data!.buffer.asUint8List())}';
  bitmap.dispose();
  picture.dispose();
  return uri;
}

/// The canvas lives in a scroll view in the app; here it gets room instead.
void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'actual image ratio and drag start/end create the selected region',
    (tester) async {
      tall(tester);
      final uri = (await tester.runAsync(imageUri))!;
      var current = RecallImage(
        dataUri: uri,
        masks: [const OcclusionMask(x: 0.05, y: 0.05, width: 0.1, height: 0.1)],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHandyTheme(const Color(0xFF4D7C0F), Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: StatefulBuilder(
                builder: (context, set) => OcclusionCanvas(
                  image: current,
                  hidden: true,
                  onChanged: (next) => set(() => current = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const Key('occlusion-surface')));
      expect(rect.width / rect.height, closeTo(2, 0.001));
      final gesture = await tester.startGesture(
        rect.topLeft + Offset(rect.width * .3, rect.height * .3),
      );
      await gesture.moveTo(
        rect.topLeft + Offset(rect.width * .7, rect.height * .7),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(current.masks.length, 2);
      expect(current.masks.last.width, closeTo(.4, .02));
      expect(current.masks.last.height, closeTo(.4, .02));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('tiny legacy mask resize never inverts clamp range', (
    tester,
  ) async {
    tall(tester);
    final uri = (await tester.runAsync(imageUri))!;
    var current = RecallImage(
      dataUri: uri,
      masks: [const OcclusionMask(x: .995, y: .995, width: .005, height: .005)],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHandyTheme(const Color(0xFF4D7C0F), Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: StatefulBuilder(
              builder: (context, set) => OcclusionCanvas(
                image: current,
                hidden: true,
                onChanged: (next) => set(() => current = next),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final handle = tester.widget<GestureDetector>(
      find.byKey(const Key('occlusion-resize-0')),
    );
    handle.onPanUpdate!(
      DragUpdateDetails(delta: const Offset(5, 5), globalPosition: Offset.zero),
    );
    await tester.pumpAndSettle();
    expect(
      current.masks.single.x + current.masks.single.width,
      lessThanOrEqualTo(1),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed image stream is handled and replacement recovers', (
    tester,
  ) async {
    tall(tester);
    final uri = (await tester.runAsync(imageUri))!;
    final bytes = base64Decode(uri.split(',').last);
    bytes[bytes.length ~/ 2] ^= 255;
    var current = RecallImage(
      dataUri: 'data:image/png;base64,${base64Encode(bytes)}',
      masks: [const OcclusionMask(x: .2, y: .2, width: .2, height: .2)],
    );
    StateSetter? update;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHandyTheme(const Color(0xFF4D7C0F), Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) {
              update = set;
              return SizedBox(
                width: 400,
                child: OcclusionCanvas(
                  image: current,
                  hidden: true,
                  onChanged: (_) {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    update!(() => current = RecallImage(dataUri: uri, masks: current.masks));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('occlusion-surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
