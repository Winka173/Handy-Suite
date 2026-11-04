import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';

/// A pale blue-grey board with one dark stroke across the middle row.
ScanRaster board() {
  const w = 10, h = 6;
  final bytes = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = (y * w + x) * 4;
      final stroke = y == 3;
      bytes[p] = stroke ? 30 : 205;
      bytes[p + 1] = stroke ? 40 : 212;
      bytes[p + 2] = stroke ? 120 : 222;
      bytes[p + 3] = 255;
    }
  }
  return ScanRaster(width: w, height: h, rgba: bytes);
}

List<int> pixel(ScanRaster r, int x, int y) {
  final p = (y * r.width + x) * 4;
  return r.rgba.sublist(p, p + 3);
}

void main() {
  test('four presets, each with a known tone and a contrast in range', () {
    expect(scanPresets.map((p) => p.id), [
      'original',
      'document',
      'receipt',
      'board',
    ]);
    for (final p in scanPresets) {
      expect(scanTones, contains(p.tone));
      expect(p.contrast, inInclusiveRange(1, 3));
    }
  });

  test('grey turns every pixel grey', () async {
    final out = await rectifyScan(board(), fullScanCorners(), tone: 'gray');
    for (var y = 0; y < out.height; y++) {
      final px = pixel(out, 4, y);
      expect(px[0], px[1]);
      expect(px[1], px[2]);
    }
  });

  test('whiten lifts the board to white and keeps the stroke', () async {
    final source = board();
    final out = await rectifyScan(source, fullScanCorners(), tone: 'whiten');
    final ground = pixel(out, 4, 0), stroke = pixel(out, 4, 3);
    expect(ground.every((c) => c >= 250), isTrue, reason: '$ground');
    expect(stroke, pixel(source, 4, 3));
  });

  test(
    'colour is unchanged at contrast 1; unknown tones are refused',
    () async {
      final source = board();
      final out = await rectifyScan(source, fullScanCorners());
      expect(pixel(out, 4, 0), pixel(source, 4, 0));
      expect(
        () => rectifyScan(source, fullScanCorners(), tone: 'sepia'),
        throwsFormatException,
      );
    },
  );
}
