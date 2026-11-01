import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';

ReaderDocument readerFixture({
  String id = 'document-1',
  String source = '\ufeff# Tiếng Việt\r\n\r\nNội dung 😀\r\n',
}) => ReaderDocument.parse(
  ReaderDocument(
    id: id,
    name: 'hướng dẫn.md',
    kind: 'markdown',
    source: source,
    createdAt: '2026-10-31T00:00:00.000Z',
    lastOpenedAt: '2026-10-31T00:00:00.000Z',
    folder: 'Work',
    favorite: true,
  ).toJson(),
);
Uint8List pack(Map<String, Uint8List> files) {
  final archive = Archive();
  for (final e in files.entries)
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive, level: 0));
}

void main() {
  test(
    'reader source/BOM/CRLF/Unicode metadata JSON and ZIP roundtrip preserve exact bytes',
    () {
      final document = readerFixture(),
          library = ReaderLibrary([
            readerFixture(),
            readerFixture(
              id: 'document-2',
              source: '<script>not executed</script>',
            ),
          ]);
      final json = library.serialize(),
          zip = readerZip(library),
          restored = readReaderZip(zip);
      expect(restored.serialize(), json);
      expect(ReaderLibrary.parse(json).serialize(), json);
      expect(
        ZipDecoder().decodeBytes(zip).findFile('documents/0.txt')!.content,
        utf8.encode(document.source),
      );
      expect(document.source.startsWith('\ufeff'), isTrue);
      final edited = document.copyWith(
        name: 'renamed.txt',
        folder: 'Private',
        favorite: false,
        opened: '2026-10-31T10:00:00.000Z',
      );
      final next = library.save(edited);
      expect(next.documents.first.source, document.source);
      expect(library.documents.first.name, 'hướng dẫn.md');
      expect(next.remove(edited.id).documents.length, 1);
    },
  );
  test(
    'corrupt/missing/extra/path/digest/duplicate IDs reject without touching source library',
    () {
      final library = ReaderLibrary([readerFixture()]),
          zip = readerZip(library),
          snapshot = library.serialize();
      final archive = ZipDecoder().decodeBytes(zip),
          files = {
            for (final f in archive.files)
              f.name: Uint8List.fromList(f.content),
          };
      final damaged = Uint8List.fromList(zip)..[50] ^= 1;
      for (final bytes in [
        damaged,
        pack({'manifest.json': files['manifest.json']!}),
        pack({...files, '../escape.txt': Uint8List(1)}),
        pack({...files, 'extra.txt': Uint8List(1)}),
        pack({
          ...files,
          'documents/0.txt': Uint8List.fromList(utf8.encode('different')),
        }),
      ]) {
        expect(() => readReaderZip(bytes), throwsFormatException);
      }
      expect(
        () => ReaderLibrary([readerFixture(), readerFixture()]),
        throwsFormatException,
      );
      expect(library.serialize(), snapshot);
    },
  );
  test(
    'source, document counts, library bytes and malformed metadata are bounded',
    () {
      expect(
        () => readerUtf8(Uint8List.fromList([0xc3, 0x28])),
        throwsFormatException,
      );
      expect(() => readerUtf8(Uint8List.fromList([0])), throwsFormatException);
      expect(() => readerFixture(source: '\ud800'), throwsFormatException);
      expect(() => readerUtf8(Uint8List(1000001)), throwsFormatException);
      expect(
        () =>
            ReaderLibrary(List.generate(51, (i) => readerFixture(id: 'd-$i'))),
        throwsFormatException,
      );
      expect(
        () => ReaderLibrary(
          List.generate(
            9,
            (i) => readerFixture(id: 'd-$i', source: 'a' * 999999),
          ),
        ),
        throwsFormatException,
      );
      for (final fields in [
        {'kind': 'pdf'},
        {'id': '../evil'},
        {'lastOpenedAt': 'bad'},
        {'favorite': 'yes'},
        {'folder': 'a\u0000b'},
      ]) {
        expect(
          () => ReaderDocument.parse({...readerFixture().toJson(), ...fields}),
          throwsFormatException,
        );
      }
      expect(readerKind('name.html'), 'html');
      expect(readerKind('name.dart'), 'code');
      expect(readerKind('name.md'), 'markdown');
    },
  );
  test(
    'HTML reading drops active/network markup but preserves readable headings, lists and code text',
    () {
      const source =
          '<html><head><script>steal()</script><style>secret-css</style></head><body><h1>Tiếng Việt</h1><p>Safe &amp; <b>bold</b></p><a href="javascript:evil()">link text</a><img src="https://remote/private"><iframe>remote body</iframe><form><input value="secret">Hidden form</form><pre>&lt;code&gt;</pre></body></html>';
      final text = readableHtml(source);
      expect(text, contains('Tiếng Việt'));
      expect(text, contains('Safe & bold'));
      expect(text, contains('link text'));
      expect(text, contains('<code>'));
      for (final blocked in [
        'steal',
        'secret-css',
        'https://remote',
        'javascript',
        'remote body',
        'Hidden form',
        'secret',
      ])
        expect(text, isNot(contains(blocked)));
      expect(() => readableHtml('x' * 100001), throwsFormatException);
      expect(() => readableHtml('<div>' * 10001), throwsFormatException);
    },
  );
}
