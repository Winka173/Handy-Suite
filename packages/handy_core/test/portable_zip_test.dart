import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/portable_zip.dart';

void main() {
  Uint8List zip(String name, List<int> data, [int level = 0]) {
    return ZipEncoder().encodeBytes(
      Archive()..addFile(ArchiveFile.bytes(name, data)),
      level: level,
    );
  }

  Map<String, Uint8List> decode(Uint8List bytes) =>
      decodePortableZip(bytes, isAllowedPath: (name) => name == 'source.md');
  test(
    'stored and deflated portable ZIP roundtrip without following paths',
    () {
      for (final level in [0, 6]) {
        final data = utf8.encode('Tiếng Việt\r\n' * 100);
        expect(decode(zip('source.md', data, level))['source.md'], data);
      }
      expect(() => decode(zip('../source.md', [1])), throwsFormatException);
    },
  );
  test('forged expanded size cannot bypass bounded inflation', () {
    final bytes = zip('source.md', List.generate(20000, (i) => i % 251), 6);
    final header = ByteData.sublistView(bytes);
    final end = bytes.length - 22,
        central = header.getUint32(end + 16, Endian.little);
    header.setUint32(central + 24, 10, Endian.little);
    header.setUint32(22, 10, Endian.little);
    expect(() => decode(bytes), throwsFormatException);
    expect(
      () => decodePortableZip(
        zip('source.md', [1, 2]),
        isAllowedPath: (_) => true,
        maxEntryBytes: 1,
      ),
      throwsFormatException,
    );
  });
}
