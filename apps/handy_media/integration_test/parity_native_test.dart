import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/quick_tools_test.dart' show verifyFlipUi;
import '../test/annotation_image_edit_test.dart' show verifyAnnotationImageEdit;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native flip form exports real unchanged-source corner pixels', (
    tester,
  ) async {
    await verifyFlipUi(tester);
    if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('media-flip-export');
    }
    await verifyAnnotationImageEdit(tester);
  });
}
