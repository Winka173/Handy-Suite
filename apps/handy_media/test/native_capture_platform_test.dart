import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme;
import 'quick_tools_test.dart' show png;
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

  testWidgets('Windows takes an area or a screen into a guide step, no '
      'recording', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const channel = MethodChannel('handy_capture');
    final calls = <MethodCall>[];
    final picture = png();
    const shot = {
      'uri': 'file:///handy-capture/windows/shot-9-1.png',
      'mime': 'image/png',
      'width': 100,
      'height': 100,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'screenshot' => shot,
            'read' => picture,
            _ => {
              'recording': false,
              'pending': false,
              'lastResult': null,
              'error': null,
            },
          };
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    Uint8List? marked;
    await tester.pumpWidget(
      MaterialApp(
        theme: kitTheme,
        home: NativeCapturePage(
          files: const SystemHandyFiles(),
          annotate: (_, bytes) async => marked = bytes,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('native-record')), findsNothing);
    expect(find.byKey(const Key('native-area')), findsOneWidget);
    expect(find.textContaining('not available on Windows'), findsOneWidget);
    await tester.tap(find.byKey(const Key('native-screenshot')));
    await tester.pump();
    await tester.pump();
    final call = calls.firstWhere((c) => c.method == 'screenshot');
    expect(call.arguments['area'], 'region');
    expect(call.arguments['delayMs'], 0);
    expect(call.arguments['hint'], contains('Esc'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Screenshot · 100 × 100'), findsOneWidget);
    expect(find.byKey(const Key('native-preview')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('native-annotate')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('native-annotate')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(marked, picture);
    // The whole screen, after a wait.
    await tester.ensureVisible(find.text('Whole screen'));
    await tester.pump();
    await tester.tap(find.text('Whole screen'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('native-delay-3000')));
    await tester.tap(find.byKey(const Key('native-delay-3000')));
    await tester.pump();
    expect(calls.where((c) => c.method == 'screenshot'), hasLength(1));
    await tester.ensureVisible(find.byKey(const Key('native-screenshot')));
    await tester.tap(find.byKey(const Key('native-screenshot')));
    await tester.pump();
    await tester.pump();
    final last = calls.lastWhere((c) => c.method == 'screenshot');
    expect(last.arguments['area'], 'screen');
    expect(last.arguments['delayMs'], 3000);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
