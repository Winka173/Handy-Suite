import 'package:flutter_test/flutter_test.dart';
import '../test/helpers.dart' show kitTheme;
import 'package:integration_test/integration_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/image/image_page.dart';
import 'package:handy_ui/kit.dart';
import '../test/quick_tools_test.dart' show Files, png;
import '../test/guide_export_test.dart' show guidePress, guideSettle;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real system camera cancel and share-sheet dismiss preserve selected image',
    (tester) async {
      final files = Files()..next = ImportedBytes('Private-source.png', png());
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: ImagePage(files: files),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('media-import')));
      await tester.pumpAndSettle();
      debugPrint('HANDY_CAMERA_SYSTEM_CANCEL');
      await tester.tap(find.byKey(const Key('media-camera')));
      for (var i = 0; i < 180; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 50));
        final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('media-camera')),
        );
        if (button.onPressed != null) break;
      }
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('media-camera')))
            .onPressed,
        isNotNull,
      );
      expect(find.textContaining('1. Private-source.png'), findsOneWidget);
      expect(find.textContaining('Action failed'), findsNothing);
      // Let the external Camera app finish releasing its camera session before
      // opening its next capture intent (an emulator camera lifecycle boundary).
      await Future<void>.delayed(const Duration(seconds: 5));
      debugPrint('HANDY_CAMERA_SYSTEM_CAPTURE');
      await tester.tap(find.byKey(const Key('media-camera')));
      for (var i = 0; i < 240; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 50));
        final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('media-camera')),
        );
        if (button.onPressed != null) break;
      }
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('media-camera')))
            .onPressed,
        isNotNull,
      );
      expect(find.textContaining(RegExp(r'^2\. ')), findsOneWidget);
      expect(find.textContaining('Action failed'), findsNothing);
      // Scrolling through CropCanvas can edit its selection; move the outer
      // controller instead and await actual output before finding share.
      await guidePress(tester, find.byKey(const Key('media-apply')));
      await guideSettle(tester);
      expect(find.textContaining('Output ready'), findsOneWidget);
      debugPrint('HANDY_SHARE_SYSTEM_DISMISS');
      await guidePress(tester, find.text('Share file'));
      for (var i = 0; i < 180; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('Share canceled').evaluate().isNotEmpty) break;
      }
      expect(find.text('Share canceled'), findsOneWidget);
      expect(find.textContaining('Could not share'), findsNothing);
      expect(files.next!.bytes, png());
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('media-share-canceled');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
