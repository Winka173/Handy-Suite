import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme;
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/image/image_page.dart';
import 'package:handy_ui/kit.dart';
import 'quick_tools_test.dart' show Files, png;

class CameraPort implements ScanCamera {
  ImportedBytes? next, lost;
  bool denied = false;
  @override
  bool get supported => true;
  @override
  Future<ImportedBytes?> recover() async => lost;
  @override
  Future<ImportedBytes?> capture() async {
    if (denied) throw PlatformException(code: 'camera_access_denied');
    return next;
  }
}

void main() {
  testWidgets('long camera filename fits a narrow source selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final camera = CameraPort()
      ..next = ImportedBytes('${'camera-' * 20}.jpg', png());
    await tester.pumpWidget(
      MaterialApp(
        theme: kitTheme,
        home: Scaffold(
          body: ImagePage(files: Files(), camera: camera),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-camera')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets(
    'camera cancel/deny/corruption keep selection; recovered and captured photos use same engine',
    (tester) async {
      final photo = ImportedBytes('Camera.jpg', png()),
          camera = CameraPort()..lost = ImportedBytes('Recovered.png', png());
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: Scaffold(
            body: ImagePage(files: Files(), camera: camera),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('media-camera-recovered')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1. Recovered.png'), findsOneWidget);
      for (final mode in ['cancel', 'denied', 'corrupt', 'success']) {
        camera.denied = mode == 'denied';
        camera.next = mode == 'success'
            ? photo
            : mode == 'corrupt'
            ? ImportedBytes('broken.jpg', Uint8List.fromList([1, 2]))
            : null;
        await tester.tap(find.byKey(const Key('media-camera')));
        await tester.pumpAndSettle();
        expect(find.textContaining('1. Recovered.png'), findsOneWidget);
        expect(
          find.textContaining('2. Camera.jpg'),
          mode == 'success' ? findsOneWidget : findsNothing,
        );
      }
      expect(photo.bytes, png());
    },
  );
}
