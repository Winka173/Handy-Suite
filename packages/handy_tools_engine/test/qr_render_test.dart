import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:image/image.dart' as image;

void main() {
  final payloads = <String>[
    'https://example.com/a?b=1',
    'Tiếng Việt 😀',
    wifiQr('Office;WiFi', 'secret:password'),
    contactQr('Nguyễn A', '+84123456789', 'a@example.com'),
    eventQr('Review', '2026-10-31T08:00:00Z', '2026-10-31T09:00:00Z', 'Office'),
  ];
  for (var index = 0; index < payloads.length; index++) {
    test(
      'PNG fixture $index decodes and matches every encoded module plus quiet zone',
      () {
        final payload = payloads[index],
            matrix = qrMatrix(payload),
            bytes = qrPng(payload),
            decoded = image.decodePng(Uint8List.fromList(bytes));
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        expect(decoded, isNotNull);
        final bitmap = decoded!;
        expect(bitmap.width, (matrix.length + 8) * 8);
        expect(bitmap.height, bitmap.width);
        for (var row = 0; row < matrix.length + 8; row++)
          for (var column = 0; column < matrix.length + 8; column++) {
            final black =
                row >= 4 &&
                column >= 4 &&
                row < matrix.length + 4 &&
                column < matrix.length + 4 &&
                matrix[row - 4][column - 4];
            final p = bitmap.getPixel(column * 8 + 4, row * 8 + 4);
            expect(
              [p.r, p.g, p.b],
              [
                if (black) 0 else 255,
                if (black) 0 else 255,
                if (black) 0 else 255,
              ],
            );
          }
        // The finder at the top left has a seven-module black outer border.
        for (var n = 0; n < 7; n++) {
          expect(matrix[0][n], true);
          expect(matrix[n][0], true);
        }
      },
    );
    test(
      'SVG fixture $index is a safe vector encoding of the same modules',
      () {
        final matrix = qrMatrix(payloads[index]), svg = qrSvg(payloads[index]);
        expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg"'));
        expect(
          svg,
          contains('viewBox="0 0 ${matrix.length + 8} ${matrix.length + 8}"'),
        );
        expect(
          RegExp(r'M\d+ \d+h1v1h-1z').allMatches(svg).length,
          matrix.expand((r) => r).where((b) => b).length,
        );
        expect(svg, isNot(contains('<script')));
        expect(svg, isNot(contains('href=')));
        expect(svg, isNot(contains(payloads[index])));
      },
    );
    test('PDF fixture $index reopens as one valid vector page', () async {
      final bytes = await qrPdf(payloads[index]);
      expect(() => verifyQrPdf(Uint8List.fromList(bytes)), returnsNormally);
      final source = latin1.decode(bytes);
      expect(source, startsWith('%PDF-1.4'));
      expect(source, contains('/MediaBox'));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(source).length, 1);
      expect(source, isNot(contains(payloads[index])));
    });
  }
  test('renderers reject empty or oversized data before encoding', () async {
    for (final invalid in ['', 'a' * 1201, 'ệ' * 601]) {
      expect(() => qrMatrix(invalid), throwsFormatException);
      expect(() => qrPng(invalid), throwsFormatException);
      expect(() => qrSvg(invalid), throwsFormatException);
      await expectLater(qrPdf(invalid), throwsFormatException);
    }
  });
  test('matrix is immutable and independent across calls', () {
    final matrix = qrMatrix('hello');
    expect(() => matrix.clear(), throwsUnsupportedError);
    expect(() => matrix.first[0] = false, throwsUnsupportedError);
    expect(qrMatrix('hello'), matrix);
  });
  test(
    'SVG never inserts input as markup',
    () => expect(
      qrSvg('<script>alert("x")</script>'),
      isNot(contains('<script>')),
    ),
  );
  test(
    'PDF structural verification rejects truncated and damaged xref',
    () async {
      final bytes = await qrPdf('hello');
      expect(
        () => verifyQrPdf(
          Uint8List.fromList(bytes.take(bytes.length - 30).toList()),
        ),
        throwsFormatException,
      );
      final source = latin1.decode(bytes),
          broken = source.replaceFirst(
            RegExp(r'startxref\s+\d+'),
            'startxref\n1',
          );
      expect(
        () => verifyQrPdf(Uint8List.fromList(latin1.encode(broken))),
        throwsFormatException,
      );
      final changed = source.replaceFirst('/Count 1', '/Count 2');
      if (changed != source)
        expect(
          () => verifyQrPdf(Uint8List.fromList(latin1.encode(changed))),
          throwsFormatException,
        );
    },
  );
}
