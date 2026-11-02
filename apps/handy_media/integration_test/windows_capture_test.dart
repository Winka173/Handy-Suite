// Windows only: real screenshots through the handy_capture plugin.
//
//   flutter test --no-pub integration_test/windows_capture_test.dart -d windows
//
// The region tests move the real mouse pointer (SetCursorPos and
// mouse_event) to drag on the frozen overlay, so leave the machine alone
// while they run.
import 'dart:ffi';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_capture/handy_capture.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_media/annotation_canvas.dart';
import 'package:handy_media/app.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:integration_test/integration_test.dart';
import '../test/helpers.dart' show Memory, Prefs, go, tapKey;

final _user32 = DynamicLibrary.open('user32.dll');
final _setCursorPos = _user32
    .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
      'SetCursorPos',
    );
final _mouseEvent = _user32
    .lookupFunction<
      Void Function(Uint32, Uint32, Uint32, Uint32, UintPtr),
      void Function(int, int, int, int, int)
    >('mouse_event');
final _metric = _user32
    .lookupFunction<Int32 Function(Int32), int Function(int)>(
      'GetSystemMetrics',
    );

const _move = 0x1, _leftDown = 0x2, _leftUp = 0x4, _rightDown = 0x8;
const _rightUp = 0x10;

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

/// Drags on the primary screen from [from] to [to], in physical pixels.
Future<void> _drag((int, int) from, (int, int) to) async {
  _setCursorPos(from.$1, from.$2);
  await _wait(80);
  _mouseEvent(_leftDown, 0, 0, 0, 0);
  await _wait(80);
  for (var i = 1; i <= 8; i++) {
    _setCursorPos(
      from.$1 + (to.$1 - from.$1) * i ~/ 8,
      from.$2 + (to.$2 - from.$2) * i ~/ 8,
    );
    _mouseEvent(_move, 0, 0, 0, 0);
    await _wait(30);
  }
  _mouseEvent(_leftUp, 0, 0, 0, 0);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const native = NativeCapture();

  testWidgets('the whole screen is captured at its real size', (t) async {
    expect(nativeCaptureAvailable, isTrue);
    expect(nativeVideoAvailable, isFalse);
    final shot = await native.screenshot(delayMs: 0);
    final png = await native.read(shot);
    final raster = decodeBoundedImage(png);
    expect((raster.width, raster.height), (shot.width, shot.height));
    // The primary screen, in physical pixels, when the pointer is on it.
    _setCursorPos(10, 10);
    final again = await native.screenshot(delayMs: 0);
    expect((again.width, again.height), (_metric(0), _metric(1)));
    final status = await native.status();
    expect(status.pending, isFalse);
    expect(status.lastResult!.uri, again.uri);
    await expectLater(native.startRecording(), throwsUnsupportedError);
  });

  testWidgets('an area dragged on the frozen screen is cut exactly', (t) async {
    final pending = native.screenshot(
      delayMs: 0,
      area: CaptureArea.region,
      hint: 'Integration test: dragging',
    );
    await _wait(1200);
    await _drag((200, 200), (520, 440));
    final shot = await pending;
    expect((shot.width, shot.height), (321, 241));
    final raster = decodeBoundedImage(await native.read(shot));
    expect((raster.width, raster.height), (321, 241));
  });

  testWidgets('a right click on the overlay cancels and keeps nothing new', (
    t,
  ) async {
    final before = (await native.status()).lastResult?.uri;
    final pending = native.screenshot(delayMs: 0, area: CaptureArea.region);
    await _wait(1200);
    _setCursorPos(300, 300);
    _mouseEvent(_rightDown, 0, 0, 0, 0);
    await _wait(50);
    _mouseEvent(_rightUp, 0, 0, 0, 0);
    await expectLater(
      pending,
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'E_CANCELED'),
      ),
    );
    expect((await native.status()).lastResult?.uri, before);
    await native.clear();
    expect((await native.status()).lastResult, isNull);
  });

  testWidgets('capture page: an area becomes the first step of a new guide', (
    t,
  ) async {
    await t.pumpWidget(
      MediaApp(
        documents: Memory(),
        preferences: Prefs()..value = HandyPreferences(locale: 'en'),
        drafts: (_) => Memory(),
      ),
    );
    await t.pumpAndSettle();
    await go(t, '/capture');
    expect(find.byKey(const Key('native-record')), findsNothing);
    await t.tap(find.byKey(const Key('native-screenshot')));
    await t.pump();
    await t.runAsync(() async {
      await _wait(1200);
      await _drag((240, 260), (639, 559));
      await _wait(800);
    });
    await t.pumpAndSettle();
    expect(find.text('Screenshot · 400 × 300'), findsOneWidget);
    expect(find.byKey(const Key('native-preview')), findsOneWidget);
    await tapKey(t, 'native-annotate');
    await t.pumpAndSettle();
    final step = t.widget<AnnotationCanvas>(find.byType(AnnotationCanvas)).step;
    expect((step.imageWidth, step.imageHeight), (400, 300));
  });
}
