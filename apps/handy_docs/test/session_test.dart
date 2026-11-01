import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs/session.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';

Uint8List samplePng() => encodeScanPng(
  ScanRaster(
    width: 16,
    height: 16,
    rgba: Uint8List.fromList(List.filled(16 * 16 * 4, 255)),
  ),
);
void main() {
  test(
    'scanner backup roundtrip preserves page IDs, order, names and pixels',
    () {
      final png = samplePng();
      final session = ScanSession([
        ScanPage('one', 'Hóa đơn', png),
        ScanPage('two', 'Receipt', png),
      ]);
      final restored = ScanSession.parse(session.serialize());
      expect(restored.pages.map((p) => p.id), ['one', 'two']);
      expect(restored.pages.first.name, 'Hóa đơn');
      expect(restored.pages.first.png, png);
      expect(restored.serialize(), session.serialize());
    },
  );
  test('scanner owns immutable buffers and page lists', () {
    final png = samplePng(), original = Uint8List.fromList(png);
    final page = ScanPage('one', 'Page', png);
    png[0] = 0;
    final session = ScanSession([page]);
    page.png[0] = 0;
    expect(session.pages.single.png, original);
    expect(() => session.pages.clear(), throwsUnsupportedError);
  });
  test(
    'malformed, incompatible, duplicate and corrupt session input is rejected',
    () {
      final png = samplePng();
      expect(() => ScanSession.parse('{'), throwsFormatException);
      expect(
        () => ScanSession.parse(
          '{"format":"handy-docs-scan","version":2,"pages":[]}',
        ),
        throwsFormatException,
      );
      expect(
        () => ScanSession([
          ScanPage('same', 'One', png),
          ScanPage('same', 'Two', png),
        ]),
        throwsFormatException,
      );
      expect(
        () => ScanSession([ScanPage('bad', 'Broken', Uint8List(20))]),
        throwsFormatException,
      );
      expect(
        () => ScanSession.parse(
          jsonEncode({
            'format': 'handy-docs-scan',
            'version': 1,
            'pages': [
              {'id': 'x', 'name': 'Page', 'png': '%%%%'},
            ],
          }),
        ),
        throwsFormatException,
      );
      expect(
        () =>
            ScanSession(List.generate(21, (i) => ScanPage('p$i', 'Page', png))),
        throwsFormatException,
      );
    },
  );
}
