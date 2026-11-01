import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:handy_save/services/metadata_client.dart';

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
      final encoded = image.encodePng(image.Image(width: 2001, height: 1000));
      expect(encoded.length, lessThan(metadataMaxThumbnailBytes));
      expect(
        sanitizeThumbnail(encoded, contentType: 'image/png').available,
        isFalse,
      );
    },
  );
}
