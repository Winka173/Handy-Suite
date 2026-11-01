import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:image/image.dart' as img;

void main() {
  test(
    'crop presets round to real pixels without extra edge rows or columns',
    () async {
      for (final size in [(16, 9), (9, 16), (101, 67)]) {
        final source = img.encodePng(
          img.Image(width: size.$1, height: size.$2),
        );
        for (final aspect in [1.0, 4 / 3, 16 / 9, 9 / 16]) {
          final region = cropAspectPreset(size.$1, size.$2, aspect);
          region.validate();
          final result = decodeBoundedImage(await cropImage(source, region));
          expect(
            (result.width - result.height * aspect).abs(),
            lessThanOrEqualTo(aspect + 1),
          );
          if (aspect == 1) expect(result.width, result.height);
          expect(result.width, lessThanOrEqualTo(size.$1));
          expect(result.height, lessThanOrEqualTo(size.$2));
        }
      }
      for (final aspect in [0.0, double.nan, double.infinity, -1.0]) {
        expect(() => cropAspectPreset(100, 50, aspect), throwsFormatException);
      }
    },
  );
  test(
    'flip uses output coordinates, preserves alpha and roundtrips exact pixels',
    () async {
      final image = img.Image(width: 3, height: 2, numChannels: 4);
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 3; x++) {
          image.setPixelRgba(x, y, x * 90, y * 120, 25 + x + y, 100 + x * 40);
        }
      }
      final source = img.encodePng(image),
          snapshot = Uint8List.fromList(img.encodePng(image));
      for (final flags in [(true, false), (false, true), (true, true)]) {
        final output = await convertImage(
          source,
          format: 'png',
          flipHorizontal: flags.$1,
          flipVertical: flags.$2,
        );
        final decoded = img.decodePng(output)!;
        for (var y = 0; y < 2; y++) {
          for (var x = 0; x < 3; x++) {
            expect(
              decoded.getPixel(x, y).toList(),
              image
                  .getPixel(flags.$1 ? 2 - x : x, flags.$2 ? 1 - y : y)
                  .toList(),
            );
          }
        }
        final restored = await convertImage(
          output,
          format: 'png',
          flipHorizontal: flags.$1,
          flipVertical: flags.$2,
        );
        expect(
          decodeBoundedImage(restored).rgba,
          decodeBoundedImage(source).rgba,
        );
      }
      final rotated = img.copyRotate(image, angle: 90);
      final combined = img.decodePng(
        await convertImage(
          source,
          format: 'png',
          rotation: 90,
          flipHorizontal: true,
        ),
      )!;
      expect(
        combined.getPixel(0, 0).toList(),
        rotated.getPixel(rotated.width - 1, 0).toList(),
      );
      expect(source, snapshot);
      final token = CancellationToken()..cancel();
      await expectLater(
        convertImage(source, flipHorizontal: true, cancellation: token),
        throwsA(isA<Cancelled>()),
      );
      expect(source, snapshot);
    },
  );
  Uint8List input() {
    final image = img.Image(width: 8, height: 4, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
    image.setPixelRgba(0, 0, 255, 0, 0, 255);
    return img.encodePng(image);
  }

  test(
    'PNG conversion preserves exact pixels and clockwise right-angle geometry',
    () async {
      final bytes = input(), original = Uint8List.fromList(bytes);
      final png = await convertImage(bytes, format: 'png', rotation: 90);
      final raster = decodeBoundedImage(png);
      expect((raster.width, raster.height), (4, 8));
      expect(raster.rgba.sublist(12, 16), [255, 0, 0, 255]);
      expect(bytes, original);
      final restored = await convertImage(png, format: 'png', rotation: 270);
      expect(decodeBoundedImage(restored).rgba, decodeBoundedImage(bytes).rgba);
    },
  );
  test(
    'real JPEG header and decoded white transparency, resize and quality',
    () async {
      final bytes = input();
      for (final quality in [1, 85, 100]) {
        final jpg = await convertImage(
          bytes,
          format: 'jpeg',
          width: 80,
          rotation: 90,
          quality: quality,
        );
        expect(jpg.take(2).toList(), [255, 216]);
        final raster = decodeBoundedImage(jpg);
        expect((raster.width, raster.height), (40, 80));
        final end = raster.rgba.sublist(raster.rgba.length - 4);
        expect(end.take(3).every((v) => v >= 245), isTrue);
        expect(end.last, 255);
      }
    },
  );
  test(
    'bad format/size/quality/rotation/corruption/cancel never changes source',
    () async {
      final bytes = input(), original = Uint8List.fromList(input());
      for (final action in [
        () => convertImage(bytes, format: 'gif'),
        () => convertImage(bytes, width: 0),
        () => convertImage(bytes, width: 16384),
        () => convertImage(bytes, rotation: 45),
        () => convertImage(bytes, quality: 0),
        () => convertImage(Uint8List.fromList([1, 2, 3])),
      ]) {
        await expectLater(action(), throwsFormatException);
      }
      final token = CancellationToken();
      final result = convertImage(bytes, cancellation: token);
      token.cancel();
      await expectLater(result, throwsA(isA<Cancelled>()));
      expect(bytes, original);
    },
  );
}
