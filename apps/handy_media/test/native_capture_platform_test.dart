import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme;
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/native_capture_page.dart';
import 'package:handy_ui/kit.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform capture controls describe actual capture scope', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      const channel = MethodChannel('handy_capture');
      final calls = <String>[];
      var recording = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'startRecording') recording = true;
            return {
              'recording': recording,
              'pending': false,
              'lastResult': null,
              'error': null,
            };
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: NativeCapturePage(
            files: const SystemHandyFiles(),
            annotate: (_, _) async {},
          ),
        ),
      );
      await tester.pump();
      final ios = platform == TargetPlatform.iOS;
      expect(
        find.byKey(const Key('native-screenshot')),
        ios ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Wait before the screenshot'),
        ios ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(ios ? 'Record this app' : 'Record screen'),
        findsOneWidget,
      );
      if (ios) {
        expect(find.textContaining('Control Center'), findsOneWidget);
        expect(find.textContaining('60 seconds'), findsOneWidget);
        expect(find.textContaining('720p'), findsOneWidget);
      }
      await tester.ensureVisible(find.byKey(const Key('native-record')));
      await tester.tap(find.byKey(const Key('native-record')));
      await tester.pump();
      await tester.pump();
      expect(calls, contains('startRecording'));
      expect(
        find.text(
          ios
              ? 'Recording this app · app sound on, microphone off'
              : 'Recording · no sound',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('native-stop')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
