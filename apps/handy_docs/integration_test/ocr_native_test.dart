// Real on-device engines: Windows.Media.Ocr on Windows, ML Kit on Android.
// flutter test integration_test/ocr_native_test.dart -d windows
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ocr/handy_ocr.dart';
import 'package:integration_test/integration_test.dart';

/// A white page with dark lines of text, as a PNG.
Future<Uint8List> page(List<String> lines) async {
  const w = 1200.0, h = 900.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  var y = 80.0;
  for (final line in lines) {
    final painter = TextPainter(
      text: TextSpan(
        text: line,
        style: const TextStyle(
          fontFamily: 'Geist',
          package: 'handy_ui',
          fontSize: 44,
          color: Color(0xFF111111),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 160);
    painter.paint(canvas, Offset(80, y));
    y += painter.height + 40;
  }
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the device engine reads printed lines with their boxes', (
    tester,
  ) async {
    final support = await ocrSupport();
    debugPrint('OCR engine ${support.engine}: ${support.languages}');
    expect(support.available, isTrue);
    final png = await page([
      'Invoice number 0412',
      'Total due 512340',
      'Payment by 15 November 2026',
    ]);
    final result = await recognizeText(
      png,
      language: support.listsLanguages ? support.languages.first : null,
    );
    debugPrint('OCR read: ${result.text}');
    final text = result.text.toLowerCase();
    expect(text, contains('invoice'));
    expect(text, contains('0412'));
    expect(text, contains('november'));
    expect(result.lines.length, greaterThanOrEqualTo(3));
    final first = result.lines.first;
    // Boxes are in pixels of the page: the first line starts near x 80.
    expect(first.box.left, inInclusiveRange(40, 140));
    expect(first.box.top, inInclusiveRange(40, 160));
    expect(first.box.right, lessThanOrEqualTo(1200));

    if (support.engine == 'windows-ocr' && support.match('vi') == null) {
      // Vietnamese is not installed here: say so, never guess.
      await expectLater(
        recognizeText(png, language: 'vi'),
        throwsA(
          isA<OcrUnavailable>().having(
            (e) => e.problem,
            'problem',
            OcrProblem.languageMissing,
          ),
        ),
      );
    }
    if (support.match('vi') != null ||
        defaultTargetPlatform == TargetPlatform.android) {
      final vi = await recognizeText(
        await page(['Hóa đơn tiền điện', 'Thành tiền: 512.340 đồng']),
        language: 'vi',
      );
      debugPrint('OCR read Vietnamese: ${vi.text}');
      expect(vi.text.toLowerCase(), contains('512'));
    }
  });

  testWidgets('a scan page becomes a searchable PDF with a hidden layer', (
    tester,
  ) async {
    final png = await page(['Searchable receipt 0412']);
    final result = await recognizeText(png);
    expect(result.lines, isNotEmpty);
    // A one-page PDF of the picture, then the hidden text over it.
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final rgba = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final w = frame.image.width, h = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    final blank = await LocalPdf.open(_blankPdf(w * .6, h * .6));
    final base = await LocalPdf.open(
      await blank.flatten([
        PdfImageStamp(
          0,
          const PdfBox(0, 0, 1, 1),
          rgba: rgba!.buffer.asUint8List(),
          pixelWidth: w,
          pixelHeight: h,
        ),
      ]),
    );
    final searchable = await LocalPdf.open(
      await base.flatten([
        for (final line in result.lines)
          PdfTextStamp(
            0,
            PdfBox(
              line.box.left / w,
              line.box.top / h,
              line.box.width / w,
              line.box.height / h,
            ),
            line.text,
            invisible: true,
            fit: true,
          ),
      ]),
    );
    expect((await searchable.pageText(0)).toLowerCase(), contains('receipt'));
    await blank.close();
    await base.close();
    await searchable.close();
  });
}

Uint8List _blankPdf(double w, double h) {
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] >>',
  ];
  var pdf = '%PDF-1.7\n';
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final xref = pdf.length;
  pdf += 'xref\n0 4\n0000000000 65535 f \n';
  for (final offset in offsets) {
    pdf += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  pdf += 'trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
  return Uint8List.fromList(pdf.codeUnits);
}
