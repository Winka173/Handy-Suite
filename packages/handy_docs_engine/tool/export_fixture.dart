import 'dart:io';
import 'dart:typed_data';
import 'package:handy_docs_engine/handy_docs_engine.dart';

/// Generates real output for an independent PDF parser, outside Flutter tests.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) throw ArgumentError('Supply output PDF path');
  ScanRaster fixture(int width, int height) {
    final rgba = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        rgba[offset] = (x * 255 / (width - 1)).round();
        rgba[offset + 1] = (y * 255 / (height - 1)).round();
        rgba[offset + 2] = 64;
        rgba[offset + 3] = 255;
      }
    }
    return ScanRaster(width: width, height: height, rgba: rgba);
  }

  final pages = <Uint8List>[];
  for (final size in [(8, 6), (5, 8)]) {
    pages.add(
      await scanPng(
        encodeScanPng(fixture(size.$1, size.$2)),
        fullScanCorners(),
      ),
    );
  }
  final output = File(arguments.single);
  await output.parent.create(recursive: true);
  await output.writeAsBytes(await scannerPdf(pages), flush: true);
  stdout.writeln('Wrote ${pages.length} scanner pages');
}
