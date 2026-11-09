import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/services/metadata_thumbnail.dart';
import 'package:image/image.dart' as img;

void main() {
  test('an article picture is kept at most 1280 px, as a clean JPEG', () {
    final big = img.Image(width: 2000, height: 1000);
    img.fill(big, color: img.ColorRgb8(200, 80, 20));
    big.exif.imageIfd['Make'] = img.IfdValueAscii('PhoneMaker');
    final r = sanitizeArticlePicture((
      Uint8List.fromList(img.encodePng(big)),
      'image/png',
    ));
    expect(r.contentType, 'image/jpeg');
    final out = img.decodeJpg(r.bytes!)!;
    expect((out.width, out.height), (1280, 640));
    expect(out.exif.imageIfd.containsKey(0x010F), isFalse);
  });

  test('anything that is not a still picture is refused', () {
    final r = sanitizeArticlePicture((
      Uint8List.fromList('<svg/>'.codeUnits),
      'image/svg+xml',
    ));
    expect(r.available, isFalse);
  });
}
