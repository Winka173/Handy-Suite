import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Most text a Word file is written from (a few hundred pages).
const docxTextLimit = 2000000;

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // Characters XML 1.0 cannot carry are dropped, never written.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F￾￿]'), '');

/// [text] as a Word document (.docx): a blank line starts a new paragraph,
/// a single line break stays a line break, and a form feed (`\f`) starts a
/// new page. Plain Office Open XML with no styles of its own, so Word,
/// LibreOffice and Google Docs open it with their defaults. [title] goes
/// into the document properties.
Uint8List docxFromText(String text, {String title = ''}) {
  if (text.length > docxTextLimit) {
    throw const FormatException('Text is too long for one document');
  }
  final body = StringBuffer();
  final pages = text.replaceAll('\r\n', '\n').split('\f');
  for (final (p, page) in pages.indexed) {
    final paragraphs = page.split(RegExp(r'\n[ \t]*\n'));
    for (final (i, para) in paragraphs.indexed) {
      final breakBefore = p > 0 && i == 0;
      body.write('<w:p>');
      if (breakBefore) body.write('<w:r><w:br w:type="page"/></w:r>');
      final lines = para.split('\n');
      for (final (j, line) in lines.indexed) {
        body.write('<w:r>');
        if (j > 0) body.write('<w:br/>');
        body.write('<w:t xml:space="preserve">${_xml(line)}</w:t></w:r>');
      }
      body.write('</w:p>');
    }
  }
  const w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  final files = <String, String>{
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '</Types>',
    '_rels/.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
        '</Relationships>',
    'word/document.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="$w"><w:body>$body'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="567" w:footer="567" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>',
    'docProps/core.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:title>${_xml(title)}</dc:title><dc:creator>Handy Docs</dc:creator>'
        '</cp:coreProperties>',
  };
  final archive = Archive();
  for (final e in files.entries) {
    final bytes = utf8.encode(e.value);
    archive.addFile(ArchiveFile.bytes(e.key, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
