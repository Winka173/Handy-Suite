import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'watermark_native_test.dart' show textPdf, pixels;

// Run with a bundled PDFium, e.g.
// flutter test --no-pub test/edit_native_test.dart
//   --dart-define=HANDY_PDFIUM_MODULE_PATH=<app>/build/native_assets/windows/pdfium.dll
const modulePath = String.fromEnvironment('HANDY_PDFIUM_MODULE_PATH');

PdfFont geist() =>
    PdfFont(File('../handy_ui/fonts/Geist-Regular.ttf').readAsBytesSync());

/// A one-page PDF holding a sharp 1600 px photograph-like JPEG on a page
/// 200 points wide: far more pixels than the page shows.
Future<Uint8List> photoPdf() async {
  final picture = img.Image(width: 1600, height: 1200);
  final random = math.Random(7);
  for (final p in picture) {
    final v = (p.x * 255 ~/ 1600 + random.nextInt(40)).clamp(0, 255);
    p.setRgb(v, (p.y * 255 ~/ 1200), 255 - v);
  }
  final document = await PdfDocument.createFromJpegData(
    img.encodeJpg(picture, quality: 95),
    width: 200,
    height: 150,
    sourceName: 'memory:test-photo',
  );
  try {
    return await document.encodePdf();
  } finally {
    await document.dispose();
  }
}

/// Mean brightness of the shown page inside [box] (fractions).
Future<double> ink(LocalPdf pdf, int page, PdfBox box) async {
  final png = await pdf.renderPng(page, maxEdge: 400);
  final rgba = await pixels(png);
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final w = frame.image.width, h = frame.image.height;
  frame.image.dispose();
  codec.dispose();
  var sum = 0, n = 0;
  for (var y = (box.top * h).floor(); y < ((box.top + box.height) * h); y++) {
    for (
      var x = (box.left * w).floor();
      x < ((box.left + box.width) * w);
      x++
    ) {
      sum += rgba[(y * w + x) * 4];
      n++;
    }
  }
  return sum / n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
    if (modulePath.isNotEmpty) Pdfrx.pdfiumModulePath = modulePath;
  });

  test(
    'the embedded font knows Vietnamese and refuses what it cannot draw',
    () {
      final font = geist();
      const stamp = 'Bản sao – không có giá trị pháp lý';
      validatePdfWatermark(stamp, font: font);
      validatePdfWatermark('Đơn ưu tiên: Ạ ạ Ỹ ỹ', font: font);
      for (final bad in ['漢字', 'emoji 🙂', 'two\nlines', 'x' * 101]) {
        expect(
          () => validatePdfWatermark(bad, font: font),
          throwsFormatException,
        );
      }
      // Without a font only ASCII stays allowed.
      expect(() => validatePdfWatermark(stamp), throwsFormatException);
    },
  );

  testWidgets(
    'a Vietnamese stamp is embedded and reads back exactly',
    (tester) async {
      await tester.runAsync(() async {
        final bytes = textPdf();
        final original = Uint8List.fromList(bytes);
        final source = await LocalPdf.open(bytes);
        try {
          const stamp = 'Bản sao – không có giá trị pháp lý';
          final output = await source.transform(
            [0, 0],
            rotation: 90,
            watermark: stamp,
            font: geist(),
          );
          final stamped = await LocalPdf.open(output);
          try {
            for (var i = 0; i < 2; i++) {
              final text = await stamped.pageText(i);
              expect(text, contains('SOURCE'));
              expect(text, contains(stamp));
            }
            // The font is embedded once, not once per page.
            final fonts = RegExp(
              '/FontFile2',
            ).allMatches(String.fromCharCodes(output));
            expect(fonts.length, 1);
          } finally {
            await stamped.close();
          }
          expect(bytes, original);
        } finally {
          await source.close();
        }
      });
    },
    skip: modulePath.isEmpty,
  );

  testWidgets(
    'signatures and text land where they were placed, upright on turned pages',
    (tester) async {
      await tester.runAsync(() async {
        final base = await LocalPdf.open(textPdf());
        final turned = await LocalPdf.open(
          await base.transform([0, 0], rotation: 90),
        );
        await base.close();
        try {
          // A solid black 40×20 picture, half transparent on its right half.
          final rgba = Uint8List(40 * 20 * 4);
          for (var i = 0; i < 40 * 20; i++) {
            rgba[i * 4 + 3] = (i % 40) < 20 ? 255 : 0;
          }
          const box = PdfBox(.05, .05, .4, .3);
          final output = await turned.flatten([
            PdfImageStamp(0, box, rgba: rgba, pixelWidth: 40, pixelHeight: 20),
            const PdfTextStamp(1, PdfBox(.1, .8, .5, .08), 'Ngày 2/11/2026'),
            const PdfTextStamp(
              1,
              PdfBox(.1, .5, .8, .05),
              'lớp chữ ẩn',
              invisible: true,
              fit: true,
            ),
          ], font: geist());
          final filled = await LocalPdf.open(output);
          try {
            expect(filled.pages.map((p) => p.rotation), [90, 90]);
            // Left half of the picture is dark, right half shows the page.
            expect(
              await ink(filled, 0, const PdfBox(.07, .07, .15, .25)),
              lessThan(40),
            );
            expect(
              await ink(filled, 0, const PdfBox(.3, .07, .12, .25)),
              greaterThan(200),
            );
            expect(
              await ink(filled, 0, const PdfBox(.6, .6, .3, .3)),
              greaterThan(200),
            );
            final text = await filled.pageText(1);
            expect(text, contains('Ngày 2/11/2026'));
            expect(text, contains('lớp chữ ẩn'));
            // The hidden layer is found but never drawn.
            expect(
              await ink(filled, 1, const PdfBox(.12, .5, .7, .05)),
              greaterThan(250),
            );
          } finally {
            await filled.close();
          }
          await expectLater(
            turned.flatten([
              const PdfTextStamp(0, PdfBox(.1, .1, .2, .1), '漢字'),
            ], font: geist()),
            throwsFormatException,
          );
          await expectLater(
            turned.flatten([
              const PdfTextStamp(5, PdfBox(.1, .1, .2, .1), 'x'),
            ], font: geist()),
            throwsFormatException,
          );
        } finally {
          await turned.close();
        }
      });
    },
    skip: modulePath.isEmpty,
  );

  testWidgets(
    'pictures are re-encoded smaller; shared and transparent ones are kept',
    (tester) async {
      await tester.runAsync(() async {
        final bytes = await photoPdf();
        final original = Uint8List.fromList(bytes);
        final source = await LocalPdf.open(bytes);
        try {
          final smaller = await source.compress(quality: 60, dpi: 150);
          expect(smaller.changed, 1);
          expect(smaller.rasterized, isFalse);
          expect(smaller.bytes.length, lessThan(bytes.length ~/ 4));
          final reopened = await LocalPdf.open(smaller.bytes);
          try {
            expect(reopened.pages.single.width, closeTo(200, .01));
            // The picture still fills the page.
            expect(
              await ink(reopened, 0, const PdfBox(.4, .4, .2, .2)),
              closeTo(await ink(source, 0, const PdfBox(.4, .4, .2, .2)), 20),
            );
          } finally {
            await reopened.close();
          }
          expect(bytes, original);

          // One picture drawn on two pages stays shared and untouched.
          final twice = await LocalPdf.open(await source.transform([0, 0]));
          try {
            await expectLater(twice.compress(), throwsFormatException);
          } finally {
            await twice.close();
          }

          final strong = await source.rasterize(dpi: 72, quality: 50);
          expect(strong.rasterized, isTrue);
          final flat = await LocalPdf.open(strong.bytes);
          try {
            expect(flat.pages.length, 1);
            expect(flat.pages.single.width, closeTo(200, .5));
          } finally {
            await flat.close();
          }
          final canceled = CancellationToken()..cancel();
          await expectLater(
            source.compress(cancellation: canceled),
            throwsA(isA<Cancelled>()),
          );
        } finally {
          await source.close();
        }

        // A transparent signature is never flattened into a JPEG.
        final page = await LocalPdf.open(textPdf());
        try {
          final rgba = Uint8List(300 * 200 * 4);
          for (var i = 0; i < 300 * 200; i++) {
            rgba[i * 4 + 3] = i.isEven ? 255 : 0;
          }
          final signed = await LocalPdf.open(
            await page.flatten([
              PdfImageStamp(
                0,
                const PdfBox(.1, .1, .5, .5),
                rgba: rgba,
                pixelWidth: 300,
                pixelHeight: 200,
              ),
            ]),
          );
          try {
            await expectLater(signed.compress(), throwsFormatException);
          } finally {
            await signed.close();
          }
        } finally {
          await page.close();
        }
      });
    },
    skip: modulePath.isEmpty,
  );
}
