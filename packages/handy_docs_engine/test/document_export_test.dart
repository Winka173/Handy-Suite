import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';

void main() {
  late MarkdownPdfFonts fonts;
  setUpAll(() {
    final data = [
      for (final style in ['Regular', 'Bold', 'Italic', 'BoldItalic'])
        ByteData.sublistView(
          File(
            '../handy_ui/assets/fonts/NotoSans-$style.ttf',
          ).readAsBytesSync(),
        ),
    ];
    fonts = MarkdownPdfFonts(data[0], data[1], data[2], data[3]);
  });
  test('frozen legacy ZIP imports without invoking any TypeScript source', () {
    final bytes = File(
      '../../test-fixtures/document-pack/legacy.zip',
    ).readAsBytesSync();
    final pack = parseDocumentPack(bytes);
    expect(
      pack.source,
      File(
        '../../test-fixtures/document-pack/legacy-source.md',
      ).readAsStringSync(),
    );
    expect(pack.pdfBytes.take(5), '%PDF-'.codeUnits);
  });
  test(
    'real PDF and four-format ZIP reopen preserve exact Unicode source',
    () async {
      const source =
          '\ufeff# Tiếng Việt\r\n\r\n**Đậm** và *nghiêng*.\n\n- [x] Xong\n- [ ] Chưa\n\n| A | B |\n|---|---|\n| Một | Hai |\n\n```dart\nfinal x = 1;\n```\n';
      final pdf = await markdownPdf(source, fonts);
      expect(latin1.decode(pdf.take(8).toList()), startsWith('%PDF-'));
      expect(latin1.decode(pdf), contains('/ToUnicode'));
      final bytes = createDocumentPack(source, pdf),
          reopened = parseDocumentPack(bytes);
      expect(reopened.source, source);
      expect(reopened.html, parseMarkdownDocument(source).html);
      expect(reopened.text, parseMarkdownDocument(source).text);
      expect(reopened.pdfBytes, pdf);
      expect(
        parseDocumentPack(
          createDocumentPack(reopened.source, reopened.pdfBytes),
        ).source,
        source,
      );
      Directory(
        '../../docs/qa/evidence/document-export',
      ).createSync(recursive: true);
      File(
        '../../docs/qa/evidence/document-export/markdown-vietnamese.pdf',
      ).writeAsBytesSync(pdf);
      File(
        '../../docs/qa/evidence/document-export/document-pack.zip',
      ).writeAsBytesSync(bytes);
    },
  );
  test(
    'PDF cancellation, Unicode font coverage, size and release page guard fail explicitly',
    () async {
      await expectLater(
        markdownPdf('ok', fonts, cancellation: CancellationToken()..cancel()),
        throwsA(isA<Cancelled>()),
      );
      await expectLater(
        markdownPdf('Unsupported 😀', fonts),
        throwsFormatException,
      );
      await expectLater(
        markdownPdf('a' * 100001, fonts),
        throwsFormatException,
      );
      await expectLater(
        markdownPdf('Paragraph\n\n' * 5000, fonts),
        throwsFormatException,
      );
      expect((await markdownPdf('', fonts)).length, greaterThan(100));
    },
  );
  test(
    'ZIP corruption, unexpected/missing paths, invalid UTF-8 and oversized content reject',
    () async {
      final pdf = await markdownPdf('safe', fonts);
      Uint8List zip(Map<String, List<int>> files) {
        final archive = Archive();
        for (final e in files.entries) {
          archive.addFile(ArchiveFile.bytes(e.key, e.value));
        }
        return ZipEncoder().encodeBytes(archive, level: 0);
      }

      final files = {
        'source.md': utf8.encode('safe'),
        'document.html': utf8.encode('<p>safe</p>'),
        'document.txt': utf8.encode('safe'),
        'document.pdf': pdf,
      };
      expect(parseDocumentPack(zip(files)).source, 'safe');
      for (final bad in [
        Uint8List(0),
        Uint8List.fromList([80, 75]),
        zip({
          ...files,
          '../evil.md': [1],
        }),
        zip({...files}..remove('document.txt')),
        zip({
          ...files,
          'source.md': [0xff],
        }),
        zip({...files, 'source.md': List.filled(1000001, 65)}),
        zip({
          ...files,
          'document.pdf': [1, 2],
        }),
      ]) {
        expect(() => parseDocumentPack(bad), throwsFormatException);
      }
      final corrupt = zip(files);
      corrupt[40] ^= 1;
      expect(() => parseDocumentPack(corrupt), throwsFormatException);
    },
  );
}
