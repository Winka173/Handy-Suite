import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_capture/handy_capture.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform transform validates options before platform calls',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        const channel = MethodChannel('handy_capture');
        final calls = <MethodCall>[];
        final raw = {
          'uri': 'file:///owned/video.mp4',
          'mime': 'video/mp4',
          'width': 320,
          'height': 240,
          'durationMs': 1500,
        };
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return raw;
            });
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });
        final source = CaptureResult.parse(raw);
        const native = NativeCapture();
        await native.transform(source, rotation: 90, maxEdge: 240, mute: true);
        expect(calls.single.method, 'transform');
        expect(calls.single.arguments, {
          'uri': source.uri,
          'rotation': 90,
          'maxEdge': 240,
          'mute': true,
        });
        for (final operation in [
          () => native.transform(source, rotation: 1),
          () => native.transform(source, maxEdge: 0),
          () => native.transform(source, format: 'webm'),
        ]) {
          await expectLater(operation(), throwsFormatException);
        }
        expect(calls.length, 1);
      },
    );
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iOS exposes app recording but rejects full-device screenshot',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(nativeCaptureAvailable, isTrue);
      await expectLater(
        const NativeCapture().screenshot(),
        throwsUnsupportedError,
      );
    },
  );

  test('iOS shares the bounded Flutter video operation contract', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const channel = MethodChannel('handy_capture');
    final calls = <MethodCall>[];
    final video = <String, Object>{
      'uri': 'file:///owned/clip.mp4',
      'mime': 'video/mp4',
      'width': 1280,
      'height': 720,
      'durationMs': 2000,
    };
    final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    final frame = {
      'uri': 'file:///owned/frame.png',
      'mime': 'image/png',
      'width': 1280,
      'height': 720,
    };
    final mp4 = Uint8List(40)..setRange(4, 8, 'ftyp'.codeUnits);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'status' => {'recording': false, 'pending': false},
            'startRecording' || 'cancel' || 'clear' => null,
            'frame' => frame,
            'read' => png,
            _ => video,
          };
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    const capture = NativeCapture();
    expect((await capture.status()).recording, isFalse);
    await capture.startRecording();
    final stopped = await capture.stopRecording();
    final imported = await capture.importVideo(mp4);
    await capture.trim(imported, 500, 1500);
    await capture.combine([stopped, imported]);
    expect(await capture.read(await capture.frame(imported, 500)), png);
    await capture.cancel();
    await capture.clear();
    expect(calls.map((c) => c.method), [
      'status',
      'startRecording',
      'stopRecording',
      'importVideo',
      'trim',
      'combine',
      'frame',
      'read',
      'cancel',
      'clear',
    ]);
    expect(calls.firstWhere((c) => c.method == 'trim').arguments, {
      'uri': imported.uri,
      'startMs': 500,
      'endMs': 1500,
    });
  });
  test(
    'native result validates local URI, dimensions, duration and actual trim start',
    () {
      final video = {
        'uri': 'file:///owned/capture.mp4',
        'mime': 'video/mp4',
        'width': 1280,
        'height': 720,
        'durationMs': 5000,
        'actualStartMs': 1000,
      };
      expect(CaptureResult.parse(video).actualStartMs, 1000);
      for (final bad in [
        null,
        {},
        {...video, 'uri': 'https://example.com/x'},
        {...video, 'uri': 'file:///owned/%2e%2e/private.mp4'},
        {...video, 'uri': 'file:///owned/x.mp4?secret'},
        {...video, 'width': 0},
        {...video, 'width': 32000},
        {...video, 'durationMs': -1},
        {...video, 'durationMs': 300001},
        {...video, 'actualStartMs': '1'},
        {...video, 'mime': 'application/pdf'},
      ]) {
        expect(
          () => CaptureResult.parse(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    },
  );
  test(
    'status does not fabricate missing fields or corrupt capture metadata',
    () {
      expect(
        CaptureStatus.parse({'recording': false, 'pending': false}).lastResult,
        isNull,
      );
      for (final raw in [
        {},
        {'recording': 'true', 'pending': false},
        {'recording': false, 'pending': true, 'lastResult': {}},
      ]) {
        expect(() => CaptureStatus.parse(raw), throwsFormatException);
      }
    },
  );
  test(
    'unsupported platforms reject native calls before opening a channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(nativeCaptureAvailable, isFalse);
      await expectLater(
        const NativeCapture().screenshot(),
        throwsUnsupportedError,
      );
      await expectLater(
        const NativeCapture().startRecording(),
        throwsUnsupportedError,
      );
    },
  );
}
