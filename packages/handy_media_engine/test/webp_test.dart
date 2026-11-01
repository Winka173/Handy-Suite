import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_core/handy_core.dart';

Uint8List fixture(String name) =>
    File('../../test-fixtures/webp/$name').readAsBytesSync();
void main() {
  test(
    'independent libwebp static images decode bounded dimensions and expected alpha/pixels',
    () {
      for (final kind in ['lossless', 'lossy']) {
        final bytes = fixture('$kind.webp'), expected = fixture('$kind.rgba');
        final raster = decodeBoundedImage(bytes, allowWebP: true);
        expect((raster.width, raster.height), (24, 16));
        expect(raster.rgba.length, expected.length);
        for (var i = 0; i < expected.length; i++) {
          expect(
            (raster.rgba[i] - expected[i]).abs(),
            lessThanOrEqualTo(kind == 'lossless' || i % 4 == 3 ? 0 : 3),
            reason: '$kind channel $i',
          );
        }
        expect(
          () => decodeBoundedImage(bytes),
          throwsFormatException,
        ); // Scanner default remains PNG/JPEG.
      }
    },
  );
  test(
    'static WebP input crops/resizes/watermarks/converts with exact PNG pixels and preserved source',
    () async {
      final source = fixture('lossless.webp'),
          copy = Uint8List.fromList(fixture('lossless.webp'));
      final png = await convertImage(source, format: 'png');
      expect(decodeBoundedImage(png).rgba, fixture('lossless.rgba'));
      final resized = await resizeImage(source, width: 12);
      expect(
        (decodeBoundedImage(resized).width, decodeBoundedImage(resized).height),
        (12, 8),
      );
      final cropped = await cropImage(
        source,
        const ImageRegion(x: 0, y: 0, width: .5, height: .5),
      );
      expect(
        (decodeBoundedImage(cropped).width, decodeBoundedImage(cropped).height),
        (12, 8),
      );
      expect(source, copy);
    },
  );
  test(
    'real WebP encode reopens and writes independent-decoder artifacts; size/quality/cancel are bounded',
    () async {
      final source = fixture('source.png');
      final folder = Directory('../../docs/qa/evidence/webp');
      folder.createSync(recursive: true);
      for (final quality in [20, 85, 100]) {
        final bytes = await convertImage(
          source,
          format: 'webp',
          quality: quality,
        );
        expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
        expect(ascii.decode(bytes.sublist(8, 12)), 'WEBP');
        final raster = decodeBoundedImage(bytes, allowWebP: true);
        expect((raster.width, raster.height), (24, 16));
        File('${folder.path}/quality-$quality.webp').writeAsBytesSync(bytes);
      }
      await expectLater(
        convertImage(source, format: 'webp', width: 2500),
        throwsFormatException,
      );
      final token = CancellationToken()..cancel();
      await expectLater(
        convertImage(source, format: 'webp', cancellation: token),
        throwsA(isA<Cancelled>()),
      );
    },
  );
  test(
    'RIFF corruption, animation, duplicate chunks, dimension bombs and truncation reject before decode',
    () {
      final original = fixture('lossless.webp');
      final wrongSize = Uint8List.fromList(original)..[4] = 0;
      final bomb = Uint8List.fromList(original);
      // VP8L width/height packed into its mandatory first 5 bytes.
      final at = ascii.decode(original, allowInvalid: true).indexOf('VP8L') + 8;
      ByteData.sublistView(bomb).setUint32(at + 1, 0x0fffffff, Endian.little);
      for (final bytes in [
        wrongSize,
        bomb,
        fixture('animated.webp'),
        original.sublist(0, original.length - 1),
      ]) {
        expect(
          () => decodeBoundedImage(bytes, allowWebP: true),
          throwsFormatException,
        );
      }
      final duplicate = Uint8List.fromList([...original, ...original.skip(12)]);
      ByteData.sublistView(
        duplicate,
      ).setUint32(4, duplicate.length - 8, Endian.little);
      expect(
        () => decodeBoundedImage(duplicate, allowWebP: true),
        throwsFormatException,
      );
    },
  );
}
