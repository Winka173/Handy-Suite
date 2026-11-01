import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../test/quick_tools_test.dart' show Files, png, verifyConversionUi;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native JPEG/PNG conversion UI roundtrips two-file ZIP with source preservation',
    (tester) async {
      await verifyConversionUi(
        tester,
        Files()..next = ImportedBytes('Photo.png', png()),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('media-convert-format')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('media-convert-rotate');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
