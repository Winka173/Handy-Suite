import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'reader_test.dart' show readerFixture;

void main() {
  ReaderLibrary many(int n) => ReaderLibrary([
    for (var i = 0; i < n; i++)
      readerFixture(id: 'doc-$i', source: 'Ghi chú số $i\n'),
  ]);

  test('up to 50 documents stay version 1, readable by older apps', () {
    final small = many(50);
    expect(jsonDecode(small.serialize())['version'], 1);
    expect(ReaderLibrary.parse(small.serialize()).documents, hasLength(50));
  });

  test('more than 50 are kept as version 2 and round-trip, also by ZIP', () {
    final big = many(180);
    final text = big.serialize();
    expect(jsonDecode(text)['version'], 2);
    final back = ReaderLibrary.parse(text);
    expect(back.serialize(), text);
    final zip = readerZip(big);
    expect(readReaderZip(zip).serialize(), text);
  });

  test('the cap is 500 and the 8 MB budget still holds', () {
    expect(() => many(readerDocumentLimit + 1), throwsFormatException);
    expect(
      () => ReaderLibrary([
        for (var i = 0; i < 9; i++)
          readerFixture(id: 'big-$i', source: 'x' * 999000),
      ]),
      throwsFormatException,
    );
  });
}
