import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme;
import 'package:handy_capture/handy_capture.dart';
import 'package:handy_media/video_preview.dart';
import 'package:handy_ui/kit.dart';

void main() {
  testWidgets('ownership rejection shows an error before opening a player', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('handy_capture');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          throw PlatformException(code: 'E_INVALID_URI');
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final result = CaptureResult.parse({
      'uri': 'file:///not-owned/private.mp4',
      'mime': 'video/mp4',
      'width': 720,
      'height': 1280,
      'durationMs': 1000,
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: kitTheme,
        home: CaptureVideoPreview(capture: result),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, ['read']);
    expect(find.byKey(const Key('video-preview-error')), findsOneWidget);
    expect(find.byKey(const Key('video-preview-player')), findsNothing);
    expect(find.byKey(const Key('video-preview-play')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });
}
