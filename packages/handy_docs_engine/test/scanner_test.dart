import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:image/image.dart' as image;

ScanRaster raster([int width = 8, int height = 6]) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++)
    for (var x = 0; x < width; x++) {
      final p = (y * width + x) * 4;
      bytes[p] = (x / (width - 1) * 255).round();
      bytes[p + 1] = (y / (height - 1) * 255).round();
      bytes[p + 2] = 64;
      bytes[p + 3] = 255;
    }
  return ScanRaster(width: width, height: height, rgba: bytes);
}

Uint8List concat(List<List<int>> parts) =>
    Uint8List.fromList(parts.expand((p) => p).toList());
Uint8List chunk(String name, List<int> data) {
  final out = Uint8List(data.length + 12), v = ByteData.sublistView(out);
  v.setUint32(0, data.length);
  out.setRange(4, 8, ascii.encode(name));
  out.setRange(8, 8 + data.length, data);
  v.setUint32(out.length - 4, getCrc32(out.sublist(4, out.length - 4)));
  return out;
}

Uint8List png(
  int width,
  int height,
  List<int> raw, {
  int type = 6,
  int depth = 8,
  int interlace = 0,
  List<List<int>> extras = const [],
}) {
  final header = Uint8List(13), v = ByteData.sublistView(header);
  v.setUint32(0, width);
  v.setUint32(4, height);
  header[8] = depth;
  header[9] = type;
  header[12] = interlace;
  return concat([
    [137, 80, 78, 71, 13, 10, 26, 10],
    chunk('IHDR', header),
    ...extras,
    chunk('IDAT', const ZLibEncoder().encode(raw)),
    chunk('IEND', []),
  ]);
}

void main() {
  test('PNG encode/decode byte-exact RGBA independent immutable snapshots', () {
    final source = raster(),
        encoded = encodeScanPng(source),
        reopened = decodeScanPng(encoded);
    expect(reopened.width, 8);
    expect(reopened.height, 6);
    expect(reopened.rgba, source.rgba);
    final actual = image.decodePng(encoded)!;
    expect(actual.getBytes(order: image.ChannelOrder.rgba), source.rgba);
    expect(() => source.rgba[0] = 1, throwsUnsupportedError);
    final caller = Uint8List(16);
    final owned = ScanRaster(width: 2, height: 2, rgba: caller);
    caller[0] = 255;
    expect(owned.rgba[0], 0);
  });
  test('full page identity uses every original pixel', () async {
    final source = raster(), out = await rectifyScan(source, fullScanCorners());
    expect(out.width, source.width);
    expect(out.height, source.height);
    expect(out.rgba, source.rgba);
  });
  test('homography maps every square corner to selected quadrilateral', () {
    const corners = [
      ScanPoint(.1, .2),
      ScanPoint(.8, .1),
      ScanPoint(.9, .9),
      ScanPoint(.2, .8),
    ];
    final h = scanHomography(corners);
    for (var i = 0; i < 4; i++) {
      final u = [0, 1, 1, 0][i],
          v = [0, 0, 1, 1][i],
          d = h[6] * u + h[7] * v + 1;
      expect((h[0] * u + h[1] * v + h[2]) / d, closeTo(corners[i].x, 1e-9));
      expect((h[3] * u + h[4] * v + h[5]) / d, closeTo(corners[i].y, 1e-9));
    }
  });
  test(
    'perspective crop preserves all document corner sample colors',
    () async {
      const corners = [
        ScanPoint(.1, .2),
        ScanPoint(.8, .1),
        ScanPoint(.9, .9),
        ScanPoint(.2, .8),
      ];
      final out = await rectifyScan(raster(21, 21), corners);
      final indices = [
        0,
        out.width - 1,
        out.width * out.height - 1,
        (out.height - 1) * out.width,
      ];
      for (var i = 0; i < 4; i++) {
        expect(
          out.rgba[indices[i] * 4],
          closeTo((corners[i].x * 255).round(), 1),
        );
        expect(
          out.rgba[indices[i] * 4 + 1],
          closeTo((corners[i].y * 255).round(), 1),
        );
      }
      expect(out.width, lessThan(21));
      expect(out.height, lessThan(21));
    },
  );
  test('contrast separates gray channels; alpha composited on white', () async {
    final source = raster(3, 3),
        normal = await rectifyScan(source, fullScanCorners()),
        enhanced = await rectifyScan(source, fullScanCorners(), contrast: 1.8);
    expect(enhanced.rgba[2], lessThan(normal.rgba[2]));
    expect(enhanced.rgba[4], 128);
    expect(enhanced.rgba[8], 255);
    final white = await rectifyScan(
      ScanRaster(width: 2, height: 2, rgba: Uint8List(16)),
      fullScanCorners(),
    );
    expect(white.rgba, List.filled(16, 255));
  });
  final invalid = [
    [
      const ScanPoint(0, 0),
      const ScanPoint(1, 1),
      const ScanPoint(1, 0),
      const ScanPoint(0, 1),
    ],
    [
      const ScanPoint(0, 0),
      const ScanPoint(0, 0),
      const ScanPoint(1, 1),
      const ScanPoint(0, 1),
    ],
    [
      const ScanPoint(0, 0),
      const ScanPoint(0, 1),
      const ScanPoint(1, 1),
      const ScanPoint(1, 0),
    ],
    [
      const ScanPoint(0, 0),
      const ScanPoint(1, 0),
      const ScanPoint(.2, .1),
      const ScanPoint(0, 1),
    ],
    [
      const ScanPoint(0, 0),
      const ScanPoint(.01, 0),
      const ScanPoint(.01, .01),
      const ScanPoint(0, .01),
    ],
    [
      const ScanPoint(-.1, 0),
      const ScanPoint(1, 0),
      const ScanPoint(1, 1),
      const ScanPoint(0, 1),
    ],
    [
      const ScanPoint(double.nan, 0),
      const ScanPoint(1, 0),
      const ScanPoint(1, 1),
      const ScanPoint(0, 1),
    ],
    [const ScanPoint(0, 0)],
  ];
  for (var i = 0; i < invalid.length; i++) {
    test(
      'reject invalid geometry $i',
      () =>
          expect(() => validateScanCorners(invalid[i]), throwsFormatException),
    );
  }
  test(
    'output size bounds diagonal selection without oversized allocation',
    () {
      final size = scanOutputSize(2048, 2048, const [
        ScanPoint(.5, 0),
        ScanPoint(1, .5),
        ScanPoint(.5, 1),
        ScanPoint(0, .5),
      ]);
      expect(size.width, lessThanOrEqualTo(2048));
      expect(size.height, lessThanOrEqualTo(2048));
      expect(
        () => ScanRaster(width: 999999, height: 999999, rgba: Uint8List(0)),
        throwsFormatException,
      );
      expect(
        () => ScanRaster(width: 2, height: 2, rgba: Uint8List(1)),
        throwsFormatException,
      );
      expect(
        () => ScanRaster(width: 1, height: 1, rgba: Uint8List(4)),
        throwsFormatException,
      );
    },
  );
  for (final contrast in [0.0, .9, 3.1, double.nan, double.infinity]) {
    test(
      'invalid contrast $contrast rejects',
      () async => expectLater(
        rectifyScan(raster(), fullScanCorners(), contrast: contrast),
        throwsFormatException,
      ),
    );
  }
  test('PNG→crop→PNG→multipage PDF real object/page/image reopen', () async {
    final a = await scanPng(
          encodeScanPng(raster()),
          fullScanCorners(),
          contrast: 1.4,
        ),
        b = await scanPng(encodeScanPng(raster(5, 8)), fullScanCorners());
    final pdf = await scannerPdf([a, b]);
    expect(inspectScannerPdf(pdf).pages, 2);
    expect(inspectScannerPdf(pdf).images, greaterThanOrEqualTo(2));
    final text = latin1.decode(pdf);
    expect(RegExp(r'/MediaBox\s*\[0 0 8 6\]').hasMatch(text), true);
    expect(RegExp(r'/MediaBox\s*\[0 0 5 8\]').hasMatch(text), true);
    expect(text, contains('/Width 8'));
    expect(text, contains('/Height 8'));
  });
  test(
    'PDF duplicate pages valid even when image resource deduplicated',
    () async {
      final page = encodeScanPng(raster());
      expect(inspectScannerPdf(await scannerPdf([page, page])).pages, 2);
    },
  );
  test('PDF malformed/truncated/xref/page tree damage rejected', () async {
    final bytes = await scannerPdf([encodeScanPng(raster())]);
    expect(
      () => inspectScannerPdf(
        Uint8List.fromList(bytes.sublist(0, bytes.length - 10)),
      ),
      throwsFormatException,
    );
    final text = latin1.decode(bytes);
    expect(
      () => inspectScannerPdf(
        Uint8List.fromList(
          latin1.encode(
            text.replaceFirst(RegExp(r'startxref\s+\d+'), 'startxref\n1'),
          ),
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => inspectScannerPdf(
        Uint8List.fromList(
          latin1.encode(text.replaceFirst('/Count 1', '/Count 2')),
        ),
      ),
      throwsFormatException,
    );
  });
  test(
    'reject empty/too many/over-byte-limit PDF inputs and invalid page PNG',
    () async {
      final p = encodeScanPng(raster());
      await expectLater(scannerPdf([]), throwsFormatException);
      await expectLater(scannerPdf(List.filled(21, p)), throwsFormatException);
      await expectLater(
        scannerPdf([Uint8List(30000001)]),
        throwsFormatException,
      );
      await expectLater(scannerPdf([Uint8List(4)]), throwsFormatException);
    },
  );
  test(
    'PNG truncated missing-end CRC mismatch trailing data invalid depth/interlace reject',
    () {
      final good = encodeScanPng(raster());
      expect(
        () =>
            decodeScanPng(Uint8List.fromList(good.sublist(0, good.length - 4))),
        throwsFormatException,
      );
      final corrupt = Uint8List.fromList(good);
      corrupt[40] ^= 1;
      expect(() => decodeScanPng(corrupt), throwsFormatException);
      expect(
        () => decodeScanPng(
          concat([
            good,
            [0],
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => decodeScanPng(png(2, 2, List.filled(34, 0), depth: 16)),
        throwsFormatException,
      );
      expect(
        () => decodeScanPng(png(2, 2, List.filled(18, 0), interlace: 1)),
        throwsFormatException,
      );
      expect(() => decodeScanPng(png(90000, 2, [])), throwsFormatException);
    },
  );
  test(
    'bounded inflate rejects bomb, short scanline, unknown filter and APNG',
    () {
      expect(
        () => decodeScanPng(png(2, 2, List.filled(1000000, 0))),
        throwsFormatException,
      );
      expect(
        () => decodeScanPng(png(2, 2, List.filled(17, 0))),
        throwsFormatException,
      );
      expect(
        () => decodeScanPng(png(2, 2, [5, ...List.filled(17, 0)])),
        throwsFormatException,
      );
      expect(
        () => decodeScanPng(
          png(
            2,
            2,
            List.filled(18, 0),
            extras: [chunk('acTL', List.filled(8, 0))],
          ),
        ),
        throwsFormatException,
      );
    },
  );
  test('all five PNG unfilter modes reproduce actual RGBA', () {
    const width = 3, height = 3, channels = 4;
    final original = raster(width, height).rgba;
    for (var filter = 0; filter <= 4; filter++) {
      final raw = <int>[];
      int paeth(int a, int b, int c) {
        final p = a + b - c,
            pa = (p - a).abs(),
            pb = (p - b).abs(),
            pc = (p - c).abs();
        return pa <= pb && pa <= pc
            ? a
            : pb <= pc
            ? b
            : c;
      }

      for (var y = 0; y < height; y++) {
        raw.add(filter);
        for (var x = 0; x < width * channels; x++) {
          final idx = y * width * channels + x,
              a = x >= channels ? original[idx - channels] : 0,
              b = y > 0 ? original[idx - width * channels] : 0,
              c = y > 0 && x >= channels
                  ? original[idx - width * channels - channels]
                  : 0;
          final delta = switch (filter) {
            0 => 0,
            1 => a,
            2 => b,
            3 => (a + b) ~/ 2,
            _ => paeth(a, b, c),
          };
          raw.add((original[idx] - delta) & 255);
        }
      }
      expect(
        decodeScanPng(png(width, height, raw)).rgba,
        original,
        reason: 'filter $filter',
      );
    }
  });
  test('palette and grayscale transparency map to RGBA correctly', () {
    final palette = decodeScanPng(
      png(
        2,
        2,
        [0, 0, 1, 0, 1, 0],
        type: 3,
        extras: [
          chunk('PLTE', [255, 0, 0, 0, 255, 0]),
          chunk('tRNS', [0, 128]),
        ],
      ),
    );
    expect(palette.rgba.take(8), [255, 0, 0, 0, 0, 255, 0, 128]);
    final gray = decodeScanPng(
      png(
        2,
        2,
        [0, 7, 9, 0, 9, 7],
        type: 0,
        extras: [
          chunk('tRNS', [0, 7]),
        ],
      ),
    );
    expect(gray.rgba.take(8), [7, 7, 7, 0, 9, 9, 9, 255]);
    expect(
      () => decodeScanPng(
        png(
          2,
          2,
          [0, 2, 0, 0, 0, 0],
          type: 3,
          extras: [
            chunk('PLTE', [0, 0, 0]),
          ],
        ),
      ),
      throwsFormatException,
    );
  });
  test('complete JPEG decode accepted; missing EOI rejected', () {
    final bitmap = image.Image(width: 8, height: 6);
    image.fill(bitmap, color: image.ColorRgb8(31, 80, 150));
    final bytes = image.encodeJpg(bitmap, quality: 95),
        r = decodeScanImage(bytes);
    expect(r.width, 8);
    expect(r.height, 6);
    expect(r.rgba[0], closeTo(31, 4));
    expect(
      () => decodeScanImage(
        Uint8List.fromList(bytes.sublist(0, bytes.length - 2)),
      ),
      throwsFormatException,
    );
    expect(
      () => decodeScanImage(Uint8List.fromList([255, 216, 255, 217])),
      throwsFormatException,
    );
    expect(() => decodeScanImage(Uint8List(12000001)), throwsFormatException);
  });
  test(
    'cancellation before decode prevents parsing and returns no output',
    () async {
      final token = CancellationToken()..cancel();
      await expectLater(
        scanPng(Uint8List(1), fullScanCorners(), cancellation: token),
        throwsA(isA<Cancelled>()),
      );
      await expectLater(
        scannerPdf([], cancellation: token),
        throwsA(isA<Cancelled>()),
      );
    },
  );
  test(
    'event-loop cancellation interrupts rows without requiring progress callback',
    () async {
      final token = CancellationToken(),
          pending = rectifyScan(
            raster(128, 128),
            fullScanCorners(),
            cancellation: token,
          );
      Timer.run(token.cancel);
      await expectLater(pending, throwsA(isA<Cancelled>()));
    },
  );
  test(
    'progress cancellation is observed before pixel result emitted',
    () async {
      final token = CancellationToken();
      final progress = <double>[];
      await expectLater(
        rectifyScan(
          raster(100, 100),
          fullScanCorners(),
          cancellation: token,
          onProgress: (v) {
            progress.add(v);
            if (v > 0) token.cancel();
          },
        ),
        throwsA(isA<Cancelled>()),
      );
      expect(progress.last, lessThan(1));
    },
  );
  test('PDF cancellation mid-export returns no completed bytes', () async {
    final token = CancellationToken(), page = encodeScanPng(raster());
    await expectLater(
      scannerPdf(
        [page, page],
        cancellation: token,
        onProgress: (v) {
          if (v > 0) token.cancel();
        },
      ),
      throwsA(isA<Cancelled>()),
    );
  });
  test('successful progress monotonic and completes at one', () async {
    final values = <double>[];
    await rectifyScan(
      raster(100, 100),
      fullScanCorners(),
      onProgress: values.add,
    );
    expect(values.last, 1);
    for (var i = 1; i < values.length; i++) {
      expect(values[i], greaterThanOrEqualTo(values[i - 1]));
    }
  });
}
