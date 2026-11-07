import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:handy_bookmark/services/metadata_client.dart';

void main() {
  test('manual thumbnail import infers type without network', () {
    final original = image.encodePng(image.Image(width: 2, height: 3));
    final result = sanitizeThumbnail(original);
    expect(result.available, isTrue);
    expect(result.contentType, 'image/jpeg');
    expect(image.decodeJpg(result.bytes!)!.height, 3);
  });
  test(
    'thumbnail requires real decoded image and strips original encoding',
    () {
      final original = image.encodePng(image.Image(width: 600, height: 400));
      final result = sanitizeThumbnail(original, contentType: 'image/png');
      expect(result.available, isTrue);
      expect(result.contentType, 'image/jpeg');
      final decoded = image.decodeJpg(result.bytes!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 512);
      expect(decoded.height, lessThanOrEqualTo(400));
    },
  );
  test(
    'rejects MIME forgery, active content, corrupt pixels and oversized bytes',
    () {
      final png = image.encodePng(image.Image(width: 1, height: 1));
      expect(
        sanitizeThumbnail(png, contentType: 'image/jpeg').available,
        isFalse,
      );
      expect(
        sanitizeThumbnail(
          Uint8List.fromList('<svg onload="alert(1)"/>'.codeUnits),
          contentType: 'image/svg+xml',
        ).available,
        isFalse,
      );
      expect(
        sanitizeThumbnail(
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
          contentType: 'image/png',
        ).available,
        isFalse,
      );
      expect(
        sanitizeThumbnail(
          Uint8List(metadataMaxThumbnailBytes + 1),
          contentType: 'image/png',
        ).errorCode,
        'responseTooLarge',
      );
    },
  );
  test(
    'rejects compressed image exceeding pixel budget before decoding frame',
    () {
      final encoded = image.encodePng(image.Image(width: 2001, height: 2000));
      expect(encoded.length, lessThan(metadataMaxThumbnailBytes));
      expect(
        sanitizeThumbnail(encoded, contentType: 'image/png').available,
        isFalse,
      );
    },
  );

  test('a still lossy WebP (Vimeo covers) is a picture, not an animation', () {
    // 16 x 16, one colour, VP8 (lossy): it reports no frames at all.
    final webp = Uint8List.fromList([
      82, 73, 70, 70, 58, 0, 0, 0, 87, 69, 66, 80, 86, 80, 56, 32, 46, 0, 0, //
      0, 208, 1, 0, 157, 1, 42, 16, 0, 16, 0, 1, 64, 38, 37, 160, 2, 116, //
      186, 1, 248, 0, 3, 176, 0, 254, 240, 108, 175, 255, 16, 207, 71, 169, //
      120, 127, 253, 52, 143, 26, 71, 141, 35, 229, 52, 0, 0,
    ]);
    final result = sanitizeThumbnail(webp, contentType: 'image/webp');
    expect(result.errorCode, isNull);
    expect(image.decodeJpg(result.bytes!)!.width, 16);
  });
}
