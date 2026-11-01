import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme, press;
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/image/image_page.dart';
import 'package:handy_media/crop_canvas.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';

class Files implements HandyFiles {
  ImportedBytes? next;
  Uint8List? exported;
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => next;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    exported = bytes;
    return 'test-export';
  }

  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async => null;
}

Uint8List png() => encodeScanPng(
  ScanRaster(
    width: 100,
    height: 100,
    rgba: Uint8List.fromList(List.filled(40000, 255)),
  ),
);
Future<void> showImages(WidgetTester tester, Files files) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: kitTheme,
      home: ImagePage(files: files),
    ),
  );
  await tester.pumpAndSettle();
}

Finder media(String key) => find.byKey(Key(key));

Future<void> verifyConversionUi(WidgetTester tester, Files files) async {
  final source = png();
  await showImages(tester, files);
  for (var i = 0; i < 2; i++) {
    await press(tester, media('media-import'));
  }
  await press(tester, find.text('Format'));
  await tester.enterText(media('media-output-width'), '50');
  for (final format in ['jpeg', 'png', 'webp']) {
    if (format != 'jpeg') {
      await press(
        tester,
        find.descendant(
          of: media('media-convert-format'),
          matching: find.text(format.toUpperCase()),
        ),
      );
    }
    await press(tester, media('media-apply'));
    expect(find.text('2 of 2 pictures ready'), findsOneWidget);
    await press(tester, media('media-export'));
    final zip = ZipDecoder().decodeBytes(files.exported!, verify: true);
    expect(zip.files.length, 2);
    for (final file in zip.files) {
      expect(
        file.name.endsWith(format == 'jpeg' ? '.jpg' : '.$format'),
        isTrue,
      );
      final raster = decodeBoundedImage(file.content, allowWebP: true);
      expect((raster.width, raster.height), (50, 50));
      if (format == 'jpeg') expect(file.content.take(2).toList(), [255, 216]);
    }
  }
  expect(files.next!.bytes, source);
}

Future<void> verifyFlipUi(WidgetTester tester) async {
  final rgba = Uint8List(24)..setRange(0, 4, [255, 0, 0, 255]);
  final source = encodeScanPng(ScanRaster(width: 3, height: 2, rgba: rgba));
  final files = Files()..next = ImportedBytes('Corners.png', source);
  await showImages(tester, files);
  await press(tester, media('media-import'));
  await press(tester, find.text('Format'));
  await tester.enterText(media('media-output-width'), '');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await press(
    tester,
    find.descendant(
      of: media('media-convert-format'),
      matching: find.text('PNG'),
    ),
  );
  await press(tester, media('media-convert-flip-horizontal'));
  await press(tester, media('media-convert-flip-vertical'));
  await press(tester, media('media-apply'));
  await press(tester, media('media-export'));
  final result = decodeBoundedImage(files.exported!);
  expect((result.width, result.height), (3, 2));
  expect(result.rgba.sublist(20, 24), [255, 0, 0, 255]);
  expect(result.rgba.sublist(0, 4), [0, 0, 0, 0]);
  expect(decodeBoundedImage(source).rgba, rgba);
}

void main() {
  testWidgets(
    'flip controls process both axes through actual image export',
    verifyFlipUi,
  );
  testWidgets(
    'conversion form batches real JPEG and PNG outputs without changing sources',
    (tester) async {
      await verifyConversionUi(
        tester,
        Files()..next = ImportedBytes('Photo.png', png()),
      );
    },
  );
  testWidgets('batch watermark ZIP reopens every actual image output', (
    tester,
  ) async {
    final files = Files()..next = ImportedBytes('Photo.png', png());
    await showImages(tester, files);
    for (var i = 0; i < 2; i++) {
      await press(tester, media('media-import'));
    }
    await press(tester, find.text('Stamp'));
    await press(tester, media('media-apply'));
    await press(tester, media('media-export'));
    final archive = ZipDecoder().decodeBytes(files.exported!, verify: true);
    expect(archive.files.map((f) => f.name), [
      'watermark-1.png',
      'watermark-2.png',
    ]);
    for (final file in archive.files) {
      final decoded = decodeBoundedImage(file.readBytes()!);
      expect((decoded.width, decoded.height), (100, 100));
    }
  });
  testWidgets(
    'image import, interactive crop, real processing and binary export',
    (tester) async {
      final files = Files()..next = ImportedBytes('Photo.png', png());
      await showImages(tester, files);
      await press(tester, media('media-import'));
      await press(tester, media('media-apply'));
      await press(tester, media('media-export'));
      expect(files.exported, isNotNull);
      expect(decodeBoundedImage(files.exported!).width, 80);
    },
  );
  testWidgets('corrupt file and cancelled picker do not create a selection', (
    tester,
  ) async {
    final files = Files();
    await showImages(tester, files);
    await tester.tap(find.byKey(const Key('media-import')));
    await tester.pumpAndSettle();
    expect(find.byType(CropCanvas), findsNothing);
    files.next = ImportedBytes('Bad.png', Uint8List(20));
    await tester.tap(find.byKey(const Key('media-import')));
    await tester.pumpAndSettle();
    expect(find.byType(CropCanvas), findsNothing);
  });
  testWidgets('crop selection moves, resizes and stays in image bounds', (
    tester,
  ) async {
    var region = const ImageRegion(x: 0.1, y: 0.1, width: 0.8, height: 0.8);
    await tester.pumpWidget(
      MaterialApp(
        theme: kitTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: StatefulBuilder(
                builder: (context, setState) => CropCanvas(
                  png: png(),
                  ratio: 1,
                  region: region,
                  onChange: (v) => setState(() => region = v),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const Key('crop-move')),
      const Offset(1000, 1000),
    );
    await tester.pump();
    expect(region.x, closeTo(0.2, 0.0001));
    expect(region.y, closeTo(0.2, 0.0001));
    final original = region.width;
    await tester.drag(
      find.byKey(const ValueKey('crop-corner-2')),
      const Offset(-60, -60),
    );
    await tester.pump();
    expect(region.width, lessThan(original));
    region.validate();
  });
}
