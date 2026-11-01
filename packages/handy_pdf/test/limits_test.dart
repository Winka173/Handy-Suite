import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_pdf/handy_pdf.dart';

void main() {
  test('watermark rejects unsupported glyphs, controls and oversized text', () {
    for (final text in [
      'Tiếng Việt',
      'first\nsecond',
      'a' * 101,
      '\t',
      '\u007f',
    ]) {
      expect(() => validatePdfWatermark(text), throwsFormatException);
    }
    validatePdfWatermark('');
    validatePdfWatermark('COPY 2026 - (internal)');
    validatePdfWatermark('a' * 100);
  });
  test('invalid envelopes and byte limits reject before native loading', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList('not a pdf'.codeUnits),
      Uint8List(30000001),
    ]) {
      expect(() => validatePdfBytes(bytes), throwsFormatException);
    }
    validatePdfBytes(Uint8List.fromList('%PDF-1.7\n'.codeUnits));
  });
  test(
    'cancellation and merge bounds reject before native initialization',
    () async {
      final bytes = Uint8List.fromList('%PDF-1.7\n'.codeUnits);
      final canceled = CancellationToken()..cancel();
      await expectLater(
        LocalPdf.open(bytes, cancellation: canceled),
        throwsA(isA<Cancelled>()),
      );
      await expectLater(
        LocalPdf.merge([], cancellation: canceled),
        throwsFormatException,
      );
      await expectLater(
        LocalPdf.merge(List.filled(21, bytes)),
        throwsFormatException,
      );
      await expectLater(
        LocalPdf.merge([bytes], cancellation: canceled),
        throwsA(isA<Cancelled>()),
      );
    },
  );
}
