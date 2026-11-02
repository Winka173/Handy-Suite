import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:image/image.dart' as img;

void main() {
  test(
    'screenshots of one page join on their overlap, bars kept once',
    () async {
      // A long page of varied rows under a fixed 40px bar and a 30px nav bar.
      final random = Random(7);
      const width = 120, page = 900, view = 400, bar = 40, nav = 30;
      final content = img.Image(width: width, height: page);
      for (var y = 0; y < page; y++) {
        for (var x = 0; x < width; x++) {
          final v = (x * 7 + y * 13 + random.nextInt(4) * 40) % 256;
          content.setPixelRgb(x, y, v, 255 - v, (v * 3) % 256);
        }
      }
      img.Image shot(int scroll) {
        final s = img.Image(width: width, height: bar + view + nav);
        img.fill(s, color: img.ColorRgb8(20, 20, 20));
        img.compositeImage(
          s,
          img.copyCrop(content, x: 0, y: scroll, width: width, height: view),
          dstY: bar,
        );
        img.fillRect(
          s,
          x1: 0,
          y1: bar + view,
          x2: width,
          y2: bar + view + nav,
          color: img.ColorRgb8(240, 240, 240),
        );
        return s;
      }

      final shots = [0, 300, 500].map((s) => img.encodePng(shot(s))).toList();
      final r = await stitchScreenshots(shots);
      expect((r.header, r.footer), (bar, nav));
      expect(r.overlaps, [100, 200]);
      expect(r.height, bar + page + nav);
      final joined = img.decodePng(r.png)!;
      final (got, want) = (
        joined.getPixel(5, bar + 850),
        content.getPixel(5, 850),
      );
      expect([got.r, got.g, got.b], [want.r, want.g, want.b]);
    },
  );

  test('stitching needs at least two shots of one width', () async {
    final a = img.encodePng(img.Image(width: 10, height: 10));
    final b = img.encodePng(img.Image(width: 12, height: 10));
    expect(stitchScreenshots([a]), throwsFormatException);
    expect(stitchScreenshots([a, b]), throwsFormatException);
  });
}
