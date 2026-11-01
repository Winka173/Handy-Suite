import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Real 4000x8000 RGBA PNG; native streaming zlib avoids a 128 MB test allocation.
Uint8List largeProjectPng() {
  final compressed = BytesBuilder();
  final sink = io.ZLibEncoder(
    level: 9,
  ).startChunkedConversion(ByteConversionSink.withCallback(compressed.add));
  final row = Uint8List(4000 * 4 + 1)..fillRange(1, 4000 * 4 + 1, 255);
  for (var y = 0; y < 8000; y++) sink.add(row);
  sink.close();
  final header = Uint8List(13);
  ByteData.sublistView(header)
    ..setUint32(0, 4000)
    ..setUint32(4, 8000);
  header[8] = 8;
  header[9] = 6;
  Uint8List chunk(String type, Uint8List data) {
    final bytes = Uint8List(data.length + 12),
        view = ByteData.sublistView(bytes);
    view.setUint32(0, data.length);
    bytes.setRange(4, 8, ascii.encode(type));
    bytes.setRange(8, 8 + data.length, data);
    view.setUint32(
      bytes.length - 4,
      getCrc32(Uint8List.sublistView(bytes, 4, bytes.length - 4)),
    );
    return bytes;
  }

  return Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', header),
    ...chunk('IDAT', compressed.takeBytes()),
    ...chunk('IEND', Uint8List(0)),
  ]);
}
