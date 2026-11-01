import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../test/helpers.dart' show kitTheme;
import 'package:integration_test/integration_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_media/capture_editor.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ui/kit.dart';
import '../test/guide_export_test.dart'
    show GuideFiles, guideBundle, guidePress, guideSettle;
import '../test/quick_tools_test.dart' show png;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'HTML, PDF, Markdown, safe ZIP, long PNG and change-map UI export actual flattened outputs',
    (tester) async {
      final input = guideBundle(),
          files = GuideFiles(),
          source = Uint8List.fromList(png());
      var commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: input,
            files: files,
            onCommit: (_) async {
              commits++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final format in ['html', 'pdf', 'md', 'zip', 'long', 'diff']) {
        await guidePress(tester, find.byKey(const Key('guide-export-options')));
        await guidePress(tester, find.byKey(Key('guide-export-$format')));
        expect(find.text('Review before sharing'), findsOneWidget);
        await tester.tap(find.byKey(const Key('guide-review-confirm')));
        await guideSettle(tester);
      }
      final zip = parseGuideZip(files.outputs['handy-media-guide.zip']!);
      final pdf = await LocalPdf.open(files.outputs['handy-media-guide.pdf']!);
      try {
        expect(pdf.pages, isNotEmpty);
        final text = [
          for (var i = 0; i < pdf.pages.length; i++) await pdf.pageText(i),
        ].join('\n');
        expect(text, contains('1. Step'));
        expect(text, contains('2. Step'));
        expect(text, isNot(contains('file:///owned')));
        final raster = decodeBoundedImage(await pdf.renderPng(0));
        expect(raster.width, greaterThan(100));
        expect(raster.rgba.where((n) => n < 20).length, greaterThan(100));
      } finally {
        await pdf.close();
      }
      final first = decodeBoundedImage(zip['steps/001.png']!);
      expect(first.rgba.sublist((40 * 100 + 40) * 4, (40 * 100 + 40) * 4 + 4), [
        0,
        0,
        0,
        255,
      ]);
      expect(first.rgba.sublist(0, 4), [255, 255, 255, 255]);
      final html = utf8.decode(files.outputs['handy-media-guide.html']!);
      expect(html, contains('class="comparison"'));
      expect(html, isNot(contains('file:///owned')));
      expect(
        utf8.decode(files.outputs['handy-media-guide.md']!),
        contains('## 2. Step'),
      );
      final long = decodeBoundedImage(files.outputs['handy-media-long.png']!);
      expect((long.width, long.height), (1000, 2000));
      final map = decodeBoundedImage(
        files.outputs['handy-media-change-map.png']!,
      );
      expect(map.rgba.sublist((40 * 100 + 40) * 4, (40 * 100 + 40) * 4 + 4), [
        239,
        68,
        68,
        255,
      ]);
      expect(map.rgba.sublist(0, 4), [226, 232, 240, 255]);
      expect(commits, 0);
      expect(input.assets.values.first, source);
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['guideArtifacts'] = {
        for (final e in files.outputs.entries) e.key: base64Encode(e.value),
      };
      await tester.ensureVisible(find.byKey(const Key('guide-export-options')));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('media-guide-exports');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
