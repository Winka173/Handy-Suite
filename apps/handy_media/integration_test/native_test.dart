import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_media/capture_library.dart';
import 'package:handy_media/annotation_canvas.dart';
import 'package:handy_media/capture_editor.dart';
import 'package:handy_storage/documents.dart';
import 'legacy_fixture.dart';
import '../../../packages/handy_media_engine/test/exif_test.dart'
    show pngWithExif, tiff;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media/app.dart';
import 'package:handy_media/crop_canvas.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../test/helpers.dart' show go, press;

class FixtureImport implements HandyFiles {
  final HandyFiles actual = const SystemHandyFiles();
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async {
    final rgba = Uint8List(160 * 120 * 4);
    for (var y = 0; y < 120; y++) {
      for (var x = 0; x < 160; x++) {
        final i = (y * 160 + x) * 4;
        rgba[i] = (x / 160 * 255).round();
        rgba[i + 1] = (y / 120 * 255).round();
        rgba[i + 2] = 90;
        rgba[i + 3] = 255;
      }
    }
    return ImportedBytes(
      'Gradient fixture.png',
      encodeScanPng(ScanRaster(width: 160, height: 120, rgba: rgba)),
    );
  }

  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) => actual.importText(maxBytes: maxBytes, cancellation: cancellation);
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) => actual.exportBytes(
    name,
    bytes,
    mimeType: mimeType,
    cancellation: cancellation,
  );
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) => actual.exportText(name, text, cancellation: cancellation);
}

class ExifImport extends FixtureImport {
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => ImportedBytes('GPS fixture.png', pngWithExif(tiff()));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> snap(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('HANDY_SCREENSHOTS')) return;
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<PreferencesRepository> english(String name) async {
    final prefs = DevicePreferencesRepository(name);
    await prefs.save(HandyPreferences(locale: 'en', theme: 'light'));
    return prefs;
  }

  Uint8List firstOutput(WidgetTester tester) {
    final image = tester
        .widget<Image>(find.byKey(const Key('media-output-preview')))
        .image;
    return ((image is ResizeImage ? image.imageProvider : image) as MemoryImage)
        .bytes;
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'native crop gestures process fixture through the real image engine',
    (tester) async {
      await tester.pumpWidget(
        MediaApp(
          preferences: await english('handy-media-integration'),
          files: FixtureImport(),
          documents: localDocuments(
            'handy-media-integration',
            maxBytes: 30000000,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await go(tester, '/image');
      await press(tester, find.byKey(const Key('media-import')));
      expect(find.byType(CropCanvas), findsOneWidget);
      await snap(tester, 'media-interactive-crop');
      await press(tester, find.byKey(const Key('media-apply')));
      await waitFor(tester, find.text('Ready to save'));
      expect(find.text('Ready to save'), findsOneWidget);
    },
  );
  testWidgets(
    'native legacy Snap ZIP editor persists layer gestures and survives reopen',
    (tester) async {
      final store = localDocuments(
            'handy-media-capture-integration',
            maxBytes: 30000000,
          ),
          original = parsePortableProject(base64Decode(legacyProjectZipBase64));
      await store.save(CaptureLibrary([original]).serialize());
      final prefs = await english('handy-media-capture-integration');
      await tester.pumpWidget(MediaApp(preferences: prefs, documents: store));
      await tester.pumpAndSettle();
      await snap(tester, 'media-capture-projects');
      await tester.tap(find.text(original.project.title));
      await tester.pumpAndSettle();
      if (find.byKey(const Key('draft-discard')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('draft-discard')));
        await tester.pumpAndSettle();
      }
      expect(find.byType(CaptureEditor), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('capture-title')),
        'Migrated Snap project',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final layer = find.byKey(const ValueKey('layer-legacy-layer-8'));
      await tester.ensureVisible(layer);
      await tester.pumpAndSettle();
      await tester.tap(layer);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('layer-resize')),
        const Offset(70, 40),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnnotationCanvas>(find.byType(AnnotationCanvas))
            .step
            .annotations
            .last
            .geometry
            .width,
        greaterThan(
          original.project.steps.single.annotations.last.geometry.width,
        ),
      );
      await snap(tester, 'media-annotation-editor');
      await tester.tap(find.byKey(const Key('capture-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('media-studio')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final restored = CaptureLibrary.parse(
        (await localDocuments(
          'handy-media-capture-integration',
          maxBytes: 30000000,
        ).load())!,
      ).projects.single;
      expect(restored.project.id, original.project.id);
      expect(restored.project.title, 'Migrated Snap project');
      expect(restored.project.steps.single.annotations.length, 9);
      expect(
        restored.project.steps.single.annotations.last.geometry.width,
        greaterThan(
          original.project.steps.single.annotations.last.geometry.width,
        ),
      );
      expect(
        restored.project.steps.single.annotations.first.toJson(),
        original.project.steps.single.annotations.first.toJson(),
      );
      final portable = parsePortableProject(
        buildPortableProject(restored.project, restored.assets),
      );
      expect(portable.assets.values.single, original.assets.values.single);
      await prefs.save(HandyPreferences(locale: 'vi', theme: 'dark'));
      await tester.pumpWidget(MediaApp(preferences: prefs, documents: store));
      await tester.pumpAndSettle();
      expect(find.text('Migrated Snap project'), findsOneWidget);
      await snap(tester, 'media-capture-dark-vi');
      await store.save(CaptureLibrary([]).serialize());
    },
  );
  testWidgets('native Vietnamese text watermark processes a real image batch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaApp(
        preferences: await english('handy-media-watermark-integration'),
        files: FixtureImport(),
        documents: localDocuments(
          'handy-media-watermark-integration',
          maxBytes: 30000000,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await go(tester, '/image');
    for (var i = 0; i < 2; i++) {
      await press(tester, find.byKey(const Key('media-import')));
    }
    await press(tester, find.text('Stamp'));
    await tester.enterText(
      find.byKey(const Key('watermark-text')),
      'Ảnh của tôi',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await press(tester, find.byKey(const Key('media-apply')));
    await waitFor(tester, find.text('2 of 2 pictures ready'));
    expect(find.text('2 of 2 pictures ready'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('media-output-preview')));
    await tester.pumpAndSettle();
    expect(decodeBoundedImage(firstOutput(tester)).width, 160);
    await snap(tester, 'media-vietnamese-watermark');
  });
  testWidgets('native metadata view reads GPS and produces a clean PNG', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaApp(
        preferences: await english('handy-media-exif-integration'),
        documents: localDocuments(
          'handy-media-exif-integration',
          maxBytes: 30000000,
        ),
        files: ExifImport(),
      ),
    );
    await tester.pumpAndSettle();
    await go(tester, '/image');
    await press(tester, find.byKey(const Key('media-import')));
    await press(tester, find.text('Location'));
    expect(find.textContaining('-10.50000, 106.67500'), findsOneWidget);
    await snap(tester, 'media-exif-gps');
    await press(tester, find.byKey(const Key('media-apply')));
    await waitFor(tester, find.byKey(const Key('media-output-preview')));
    final output = firstOutput(tester);
    expect(inspectImageMetadata(output).hasExif, isFalse);
    expect(inspectImageMetadata(output).latitude, isNull);
  });
}
