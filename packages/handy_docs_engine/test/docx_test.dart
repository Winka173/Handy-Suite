import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:test/test.dart';

String part(List<int> docx, String name) =>
    utf8.decode(ZipDecoder().decodeBytes(docx).findFile(name)!.content);

void main() {
  test('paragraphs, line breaks and pages follow the text', () {
    final docx = docxFromText(
      'Hợp đồng thuê nhà\nSố 12/2026\n\nBên A: <Ông An> & bà Bình\fTrang hai',
      title: 'Hợp đồng',
    );
    final doc = part(docx, 'word/document.xml');
    expect('<w:p>'.allMatches(doc).length, 3);
    expect(doc, contains('<w:br/>'));
    expect(doc, contains('<w:br w:type="page"/>'));
    expect(doc, contains('Hợp đồng thuê nhà'));
    expect(doc, contains('&lt;Ông An&gt; &amp; bà Bình'));
    expect(
      part(docx, 'docProps/core.xml'),
      contains('<dc:title>Hợp đồng</dc:title>'),
    );
    expect(part(docx, '[Content_Types].xml'), contains('/word/document.xml'));
    expect(part(docx, '_rels/.rels'), contains('word/document.xml'));
  });

  test('characters XML cannot hold are dropped; huge text refused', () {
    final doc = part(docxFromText('a\u0001b\u000bc'), 'word/document.xml');
    expect(doc, contains('>abc<'));
    expect(
      () => docxFromText('x' * (docxTextLimit + 1)),
      throwsFormatException,
    );
  });
}
