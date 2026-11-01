import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:pdfrx/pdfrx.dart';

// A selectable-text PDF: stamps must preserve existing text and vector content.
Uint8List textPdf() {
  const stream = 'BT /F1 18 Tf 24 140 Td (SOURCE) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 240 180] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  var pdf = '%PDF-1.7\n';
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final xref = pdf.length;
  pdf += 'xref\n0 6\n0000000000 65535 f \n';
  for (final offset in offsets) {
    pdf += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  pdf += 'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
  return Uint8List.fromList(pdf.codeUnits);
}

Future<Uint8List> pixels(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  try {
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return Uint8List.fromList(
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void main() {
  const modulePath = String.fromEnvironment('HANDY_PDFIUM_MODULE_PATH');
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    // Native adapter test uses a real DLL and filesystem cache, no platform mock.
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
    if (modulePath.isNotEmpty) Pdfrx.pdfiumModulePath = modulePath;
  });
  testWidgets(
    'native stamp preserves selectable source, rotation and duplicates',
    (tester) async {
      await tester.runAsync(() async {
        final bytes = textPdf();
        final original = Uint8List.fromList(bytes);
        final source = await LocalPdf.open(bytes);
        try {
          final output = await source.transform(
            [0, 0],
            rotation: 90,
            watermark: 'CONFIDENTIAL',
          );
          final stamped = await LocalPdf.open(output);
          try {
            expect(stamped.pages.length, 2);
            for (var i = 0; i < 2; i++) {
              expect(stamped.pages[i].rotation, 90);
              final text = await stamped.pageText(i);
              expect(text, contains('SOURCE'));
              expect(text, contains('CONFIDENTIAL'));
            }
            final baseline = await LocalPdf.open(
              await source.transform([0], rotation: 90),
            );
            try {
              final before = await pixels(
                await baseline.renderPng(0, maxEdge: 600),
              );
              final after = await pixels(
                await stamped.renderPng(0, maxEdge: 600),
              );
              expect(after.length, before.length);
              var changed = 0;
              for (var p = 0; p < after.length; p += 4) {
                if (before[p] != after[p]) {
                  changed++;
                  // Half-opacity gray over a white page stays above 180.
                  expect(after[p], inInclusiveRange(180, 255));
                  expect(after[p + 1], after[p]);
                  expect(after[p + 2], after[p]);
                }
              }
              expect(changed, greaterThan(200));
            } finally {
              await baseline.close();
            }
          } finally {
            await stamped.close();
          }
          expect(await source.pageText(0), contains('SOURCE'));
          expect(await source.pageText(0), isNot(contains('CONFIDENTIAL')));
          expect(bytes, original);
          await expectLater(
            source.transform([0], watermark: 'Tiếng Việt'),
            throwsFormatException,
          );
          final canceled = CancellationToken()..cancel();
          await expectLater(
            source.transform(
              [0],
              watermark: 'CANCELED',
              cancellation: canceled,
            ),
            throwsA(isA<Cancelled>()),
          );
        } finally {
          await source.close();
        }
      });
    },
    // Host tests require an explicitly selected, already bundled native library.
    skip: modulePath.isEmpty,
  );
}
