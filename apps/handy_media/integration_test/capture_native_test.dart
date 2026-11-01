import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/helpers.dart' show kitTheme;
import 'package:integration_test/integration_test.dart';
import 'package:handy_capture/handy_capture.dart';
import 'package:handy_media/native_capture_page.dart';
import 'package:handy_media/video_preview.dart';
import 'package:video_player/video_player.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const native = NativeCapture();
  testWidgets(
    'real system consent, PNG capture, H264 recording and local codec roundtrips',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: Scaffold(
            body: Center(
              child: Text('Handy Media native capture verification'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(nativeCaptureAvailable, isTrue);
      debugPrint('HANDY_CAPTURE_CONSENT_CANCEL');
      await tester.runAsync(() async {
        await expectLater(
          native.screenshot(delayMs: 0).timeout(const Duration(seconds: 60)),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'E_CANCELED',
            ),
          ),
        );
        expect((await native.status()).pending, isFalse);
      });
      debugPrint('HANDY_CAPTURE_CONSENT_IMAGE');
      late CaptureResult screenshot;
      await tester.runAsync(() async {
        screenshot = await native
            .screenshot(delayMs: 0)
            .timeout(const Duration(seconds: 60));
        expect(screenshot.mime, 'image/png');
        final bytes = await native.read(screenshot);
        final raster = decodeBoundedImage(bytes);
        expect(raster.width, screenshot.width);
        expect(raster.height, screenshot.height);
      });
      debugPrint('HANDY_CAPTURE_CONSENT_VIDEO');
      await tester.runAsync(() async {
        await native.startRecording().timeout(const Duration(seconds: 60));
        expect((await native.status()).recording, isTrue);
      });
      for (var i = 0; i < 25; i++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: kitTheme,
            home: Scaffold(
              backgroundColor: i.isEven ? Colors.orange : Colors.blue,
              body: Center(child: Text('Frame $i')),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
      }
      late CaptureResult video;
      await tester.runAsync(() async {
        video = await native.stopRecording();
        expect(video.mime, 'video/mp4');
        expect(video.durationMs, greaterThan(1000));
        final original = await native.read(video),
            snapshot = Uint8List.fromList(original);
        for (var i = 0; i < 20; i++) {
          expect(await native.read(video), snapshot);
        }
        final still = await native.frame(video, 0),
            png = await native.read(still);
        expect(decodeBoundedImage(png).width, still.width);
        final trimmed = await native.trim(video, 200, video.durationMs! - 100);
        expect(trimmed.actualStartMs, lessThanOrEqualTo(200));
        expect((await native.read(trimmed)).length, greaterThan(32));
        final combined = await native.combine([video, video]);
        expect(combined.durationMs, greaterThan(video.durationMs!));
        expect((await native.read(combined)).length, greaterThan(32));
        final imported = await native.importVideo(original);
        expect(imported.mime, 'video/mp4');
        expect((await native.read(imported)).length, greaterThan(32));
        expect(await native.read(video), snapshot);
        final bad = Uint8List(40)..setRange(4, 8, 'ftyp'.codeUnits);
        await expectLater(
          native.importVideo(bad),
          throwsA(isA<PlatformException>()),
        );
        expect(await native.read(video), snapshot);
        await expectLater(
          native.frame(video, video.durationMs!),
          throwsFormatException,
        );
        await expectLater(native.trim(video, 10, 1), throwsFormatException);
        expect((await native.status()).pending, isFalse);
        binding.reportData ??= <String, dynamic>{};
        binding.reportData!['captureArtifacts'] = {
          'recording.mp4': base64Encode(original),
          'trimmed.mp4': base64Encode(await native.read(trimmed)),
          'joined.mp4': base64Encode(await native.read(combined)),
          'frame.png': base64Encode(png),
          'screenshot.png': base64Encode(await native.read(screenshot)),
        };
      });
      final sourceBeforePreview = await native.read(video);
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureVideoPreview(capture: video),
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
      expect(find.byKey(const Key('video-preview-error')), findsNothing);
      expect(find.byKey(const Key('video-preview-player')), findsOneWidget);
      final player = tester
          .widget<VideoPlayer>(find.byKey(const Key('video-preview-player')))
          .controller;
      expect(player.value.isInitialized, isTrue);
      debugPrint('HANDY_VIDEO_PREVIEW_INITIALIZED');
      expect(player.value.isPlaying, isFalse);
      await tester.ensureVisible(find.byKey(const Key('video-preview-play')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-preview-play')));
      await tester.pump(const Duration(milliseconds: 700));
      expect(player.value.isPlaying, isTrue);
      await tester.tap(find.byKey(const Key('video-preview-play')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(player.value.isPlaying, isFalse);
      final seek = tester.widget<Slider>(
        find.byKey(const Key('video-preview-seek')),
      );
      seek.onChanged!(1000);
      await tester.pump(const Duration(milliseconds: 500));
      expect(player.value.position.inMilliseconds, greaterThanOrEqualTo(900));
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('media-local-video-preview');
      }
      expect(await native.read(video), sourceBeforePreview);
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: NativeCapturePage(
            files: const SystemHandyFiles(),
            annotate: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('native-result')), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await tester.pumpAndSettle();
        await binding.takeScreenshot('media-native-capture-video');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      // Do not clear cached captures here: the user can inspect the real output.
    },
  );
}
