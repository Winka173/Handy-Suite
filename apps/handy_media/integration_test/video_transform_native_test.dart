import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/helpers.dart' show kitTheme;
import 'package:integration_test/integration_test.dart';
import 'package:handy_capture/handy_capture.dart';
import 'package:handy_media/video_preview.dart';
import 'package:handy_ui/kit.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real H264/AAC transform resizes, rotates, mutes, cancels and preserves sources',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: Scaffold(body: Text('Local video transform verification')),
        ),
      );
      await tester.pumpAndSettle();
      const native = NativeCapture();
      final fixture = File(
        '/data/user/0/com.example.handysuite.media.flutterpilot/files/handy-video-qa-fixture.mp4',
      );
      if (await fixture.exists()) await fixture.delete();
      debugPrint('HANDY_VIDEO_TRANSFORM_FIXTURE');
      CaptureResult? muted;
      late CaptureResult resized;
      await tester.runAsync(() async {
        for (var i = 0; i < 90 && !await fixture.exists(); i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        expect(await fixture.exists(), isTrue);
        final bytes = await fixture.readAsBytes();
        expect(bytes.length, greaterThan(1000));
        final source = await native.importVideo(bytes),
            before = await native.read(source);
        expect((source.width, source.height), (320, 240));
        muted = await native.transform(
          source,
          rotation: 90,
          maxEdge: 240,
          mute: true,
        );
        expect((muted!.width, muted!.height), (180, 240));
        final mutedBytes = await native.read(muted!);
        resized = await native.transform(source, maxEdge: 240);
        expect((resized.width, resized.height), (240, 180));
        final resizedBytes = await native.read(resized);
        final pending = native.transform(source, rotation: 180, maxEdge: 240);
        final canceled = expectLater(
          pending,
          throwsA(isA<PlatformException>()),
        );
        await native.cancel();
        await canceled;
        expect(await native.read(source), before);
        await expectLater(
          native.transform(source, rotation: 45),
          throwsFormatException,
        );
        await expectLater(
          const MethodChannel('handy_capture').invokeMethod('transform', {
            'uri': 'file:///not-owned/private.mp4',
            'rotation': 0,
            'maxEdge': 240,
            'mute': true,
          }),
          throwsA(isA<PlatformException>()),
        );
        expect(await native.read(source), before);
        expect((await native.status()).pending, isFalse);
        binding.reportData ??= <String, dynamic>{};
        binding.reportData!['videoTransformArtifacts'] = {
          'source.mp4': base64Encode(before),
          'muted-rotated.mp4': base64Encode(mutedBytes),
          'resized-audio.mp4': base64Encode(resizedBytes),
        };
      });
      expect(muted, isNotNull);
      if (muted == null) return;
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureVideoPreview(capture: muted!),
        ),
      );
      for (
        var i = 0;
        i < 150 &&
            find.byKey(const Key('video-preview-player')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('video-preview-player')), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('media-video-rotated-muted');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
