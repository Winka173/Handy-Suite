import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:image/image.dart' as img;

Uint8List fixture({int width = 24, int height = 16}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x * 7 % 256, y * 9 % 256, 30, 255);
    }
  }
  return img.encodePng(image);
}

Uint8List chunk(String type, List<int> payload) {
  final out = Uint8List(payload.length + 12), data = ByteData.sublistView(out);
  data.setUint32(0, payload.length);
  out.setRange(4, 8, ascii.encode(type));
  out.setRange(8, out.length - 4, payload);
  data.setUint32(out.length - 4, getCrc32(out.sublist(4, out.length - 4)));
  return out;
}

void main() {
  test(
    'Media generalized codec bounds remain separate from scanner limits',
    () {
      final png = fixture(width: 1, height: 3000);
      expect(decodeBoundedImage(png).height, 3000);
      expect(() => decodeScanImage(png), throwsFormatException);
      final bomb = Uint8List.fromList(png);
      final data = ByteData.sublistView(bomb);
      data.setUint32(16, 16000);
      data.setUint32(20, 16000);
      data.setUint32(29, getCrc32(bomb.sublist(12, 29)));
      expect(() => decodeBoundedImage(bomb), throwsFormatException);
    },
  );
  test('crop snapshots input before yielding to caller mutations', () async {
    final png = fixture();
    final pending = cropImage(
      png,
      const ImageRegion(x: 0, y: 0, width: 1, height: 1),
    );
    png.fillRange(0, png.length, 0);
    expect(decodeBoundedImage(await pending).width, 24);
  });
  test(
    'shared codec accepts 1px Media images while scanner retains 2px minimum',
    () {
      final png = fixture(width: 1, height: 1);
      expect(decodeBoundedImage(png).width, 1);
      expect(() => decodeScanImage(png), throwsFormatException);
      expect(
        () => decodeBoundedImage(png, maxPixels: 16000001),
        throwsFormatException,
      );
    },
  );
  test(
    'normalized crop preserves exact source pixels without modifying input',
    () async {
      final png = fixture(), original = Uint8List.fromList(png);
      final cropped = decodeBoundedImage(
        await cropImage(
          png,
          const ImageRegion(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
        ),
      );
      expect((cropped.width, cropped.height), (12, 8));
      expect(cropped.rgba.sublist(0, 4), [42, 36, 30, 255]);
      expect(png, original);
      for (final region in [
        const ImageRegion(x: -1, y: 0, width: 1, height: 1),
        const ImageRegion(x: 0, y: 0, width: 0, height: 1),
        const ImageRegion(x: 0.9, y: 0, width: 0.2, height: 1),
      ]) {
        await expectLater(cropImage(png, region), throwsFormatException);
      }
    },
  );
  test(
    'resize maintains ratio, permits 1px and rejects allocation bombs',
    () async {
      final png = fixture();
      final resized = decodeBoundedImage(await resizeImage(png, width: 12));
      expect((resized.width, resized.height), (12, 8));
      expect(
        decodeBoundedImage(await resizeImage(png, width: 1, height: 1)).width,
        1,
      );
      await expectLater(
        resizeImage(png, width: 16000, height: 16000),
        throwsFormatException,
      );
    },
  );
  test(
    'logo/text watermark modifies pixels; alpha zero preserves pixels',
    () async {
      final png = fixture(width: 120, height: 80),
          logo = img.Image(width: 4, height: 4, numChannels: 4);
      img.fill(logo, color: img.ColorRgba8(255, 0, 0, 255));
      final watermarked = decodeBoundedImage(
        await watermarkImage(
          png,
          WatermarkSpec.logo(
            img.encodePng(logo),
            opacity: 1,
            position: 'center',
            relativeWidth: 0.2,
          ),
        ),
      );
      final offset = (40 * 120 + 60) * 4;
      expect(watermarked.rgba.sublist(offset, offset + 4), [255, 0, 0, 255]);
      final text = decodeBoundedImage(
        await watermarkImage(
          png,
          WatermarkSpec.text('Handy', relativeWidth: 0.8, opacity: 1),
        ),
      );
      expect(text.rgba, isNot(decodeBoundedImage(png).rgba));
      await expectLater(
        watermarkImage(png, WatermarkSpec.text('Tiếng Việt')),
        throwsFormatException,
      );
      await expectLater(
        watermarkImage(png, WatermarkSpec.text('a', opacity: double.nan)),
        throwsFormatException,
      );
    },
  );
  test('batch isolates corrupt files, enforces limits and cancels', () async {
    final png = fixture(width: 120, height: 80), spec = WatermarkSpec.text('A');
    final result = await watermarkBatch([png, Uint8List(20), png], spec);
    expect(result.map((r) => r.bytes != null), [true, false, true]);
    expect(result[1].error, isNotEmpty);
    await expectLater(
      watermarkBatch(List.filled(51, png), spec),
      throwsFormatException,
    );
    final token = CancellationToken()..cancel();
    await expectLater(
      watermarkBatch([png], spec, cancellation: token),
      throwsA(isA<Cancelled>()),
    );
  });
  test(
    'PNG EXIF/text removal preserves exact RGBA and IDAT; malformed CRC rejected',
    () {
      final png = fixture(),
          metadata = chunk('tEXt', utf8.encode('GPS\x0010.0,20.0'));
      final withText = Uint8List.fromList([
        ...png.sublist(0, png.length - 12),
        ...metadata,
        ...png.sublist(png.length - 12),
      ]);
      expect(inspectImageMetadata(withText).sections, ['tEXt']);
      final stripped = stripImageMetadata(withText);
      expect(stripped, png);
      expect(decodeBoundedImage(stripped).rgba, decodeBoundedImage(png).rgba);
      withText[withText.length - 15] ^= 1;
      expect(() => stripImageMetadata(withText), throwsFormatException);
    },
  );
  test(
    'JPEG EXIF/XMP/comment stripping retains encoded scan bytes and pixels',
    () {
      final jpg = img.encodeJpg(mediaBitmap(fixture()), quality: 90);
      final comment = utf8.encode('private GPS metadata'),
          length = comment.length + 2;
      final tagged = Uint8List.fromList([
        255,
        216,
        255,
        254,
        length >> 8,
        length & 255,
        ...comment,
        ...jpg.sublist(2),
      ]);
      expect(inspectImageMetadata(tagged).sections, ['COM']);
      expect(stripImageMetadata(tagged), jpg);
      expect(
        decodeBoundedImage(stripImageMetadata(tagged)).rgba,
        decodeBoundedImage(jpg).rgba,
      );
      expect(
        () => stripImageMetadata(jpg.sublist(0, jpg.length - 2)),
        throwsFormatException,
      );
    },
  );
  test('SRT and VTT roundtrip preserve multiline cues and offset', () {
    const source =
        '1\n00:00:01,000 --> 00:00:02,500\nHello\nWorld\n\n2\n00:00:03,000 --> 00:00:04,000\nNext\n';
    final cues = parseSubtitles(source),
        vtt = renderSubtitles(cues, vtt: true, offsetMs: 250);
    final restored = parseSubtitles(vtt);
    expect(restored.first.startMs, 1250);
    expect(restored.first.text, 'Hello\nWorld');
    expect(
      renderSubtitles(parseSubtitles(renderSubtitles(cues))),
      renderSubtitles(cues),
    );
    expect(() => renderSubtitles(cues, offsetMs: -2000), throwsFormatException);
    expect(
      () => parseSubtitles('1\n00:99:00,000 --> 00:00:01,000\nx'),
      throwsFormatException,
    );
    expect(() => parseSubtitles('garbage'), throwsFormatException);
  });
}
