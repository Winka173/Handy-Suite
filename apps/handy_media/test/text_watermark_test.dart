import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media/text_watermark.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'dart:typed_data';

void main() {
  testWidgets(
    'Vietnamese raster has transparent background and composites through batch engine',
    (tester) async {
      await tester.runAsync(() async {
        final mark = await renderTextWatermark('Ảnh của tôi');
        final decoded = decodeBoundedImage(mark);
        final alphas = [
          for (var i = 3; i < decoded.rgba.length; i += 4) decoded.rgba[i],
        ];
        expect(alphas.any((a) => a > 0), isTrue);
        expect(alphas.any((a) => a == 0), isTrue);
        final source = encodeScanPng(
          ScanRaster(width: 100, height: 100, rgba: Uint8List(40000)),
        );
        final result = await watermarkBatch([
          source,
          source,
        ], WatermarkSpec.logo(mark));
        expect(result.length, 2);
        for (final image in result) {
          expect(image.error, isNull);
          expect(image.bytes, isNot(source));
          expect(
            decodeBoundedImage(image.bytes!).rgba.any((v) => v > 0),
            isTrue,
          );
        }
      });
    },
  );
  testWidgets(
    'empty, control, oversized and canceled text do not produce a logo',
    (tester) async {
      await tester.runAsync(() async {
        for (final invalid in ['', ' ', 'x\ny', 'Ả' * 101]) {
          await expectLater(
            renderTextWatermark(invalid),
            throwsFormatException,
          );
        }
        final cancellation = CancellationToken()..cancel();
        await expectLater(
          renderTextWatermark('Tiếng Việt', cancellation: cancellation),
          throwsA(isA<Cancelled>()),
        );
      });
    },
  );
}
