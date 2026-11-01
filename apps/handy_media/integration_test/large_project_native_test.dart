import 'package:flutter_test/flutter_test.dart';
import '../test/helpers.dart' show kitTheme;
import 'package:integration_test/integration_test.dart';
import 'package:handy_media/annotation_canvas.dart';
import 'package:handy_media/annotation_painter.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../../packages/handy_media_engine/test/large_project_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native 32M legacy PNG previews and renders bounded masks while preserving original ZIP asset',
    (tester) async {
      final png = largeProjectPng();
      final step = ProjectStep(
        id: 'large-step',
        title: 'Legacy 4000 x 8000',
        body: '',
        imageUri: 'file:///legacy/large.png',
        imageWidth: 4000,
        imageHeight: 8000,
        annotations: [
          ProjectLayer(
            id: 'mask',
            kind: 'redact',
            geometry: const LayerGeometry(.25, .25, .5, .25),
          ),
        ],
      );
      final project = CaptureProject.create(
        'large-legacy',
      ).copyWith(steps: [step]);
      final zip = buildPortableProject(project, {step.imageUri: png}),
          imported = parsePortableProject(zip);
      final output = await flattenAnnotation(
        imported.project.steps.single,
        imported.assets.values.single,
        maxWidth: 400,
        maxHeight: 800,
        maxPixels: 320000,
      );
      final raster = decodeBoundedImage(output);
      expect((raster.width, raster.height), (400, 800));
      expect(
        raster.rgba.sublist((300 * 400 + 200) * 4, (300 * 400 + 200) * 4 + 4),
        [0, 0, 0, 255],
      );
      expect(raster.rgba.sublist(0, 4), [255, 255, 255, 255]);
      expect(
        parsePortableProject(
          buildPortableProject(imported.project, imported.assets),
        ).assets.values.single,
        png,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: Scaffold(
            appBar: AppBar(title: const Text('Legacy project · 4000 x 8000')),
            body: AnnotationCanvas(
              step: step,
              png: png,
              selected: null,
              onSelect: (_) {},
              onChange: (_) {},
              onGestureStart: () {},
              onGestureEnd: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('media-legacy-large-project');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
