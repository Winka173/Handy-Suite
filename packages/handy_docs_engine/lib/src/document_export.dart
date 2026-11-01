import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_core/portable_zip.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'markdown.dart';

class MarkdownPdfFonts {
  final ByteData regular, bold, italic, boldItalic;
  const MarkdownPdfFonts(this.regular, this.bold, this.italic, this.boldItalic);
}

/// Selectable text PDF with embedded local fonts; no HTML/browser/network engine.
/// Images become alt text. Links remain text and never become PDF actions.
Future<Uint8List> markdownPdf(
  String source,
  MarkdownPdfFonts fonts, {
  CancellationToken? cancellation,
}) async {
  cancellation?.check();
  final parsed = parseMarkdownDocument(source);
  final normal = pw.Font.ttf(fonts.regular),
      bold = pw.Font.ttf(fonts.bold),
      italic = pw.Font.ttf(fonts.italic),
      boldItalic = pw.Font.ttf(fonts.boldItalic);
  final document = pw.Document(
    creator: 'Handy Docs',
    theme: pw.ThemeData.withFont(
      base: normal,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    ),
  );
  final context = pw.Context(document: document.document);
  final pdfFonts = [
    normal,
    bold,
    italic,
    boldItalic,
  ].map((f) => f.getFont(context)).toList();
  for (final rune in parsed.text.runes.toSet()) {
    if ({9, 10, 13, 0xfeff}.contains(rune)) continue;
    if (pdfFonts.any((f) => !f.isRuneSupported(rune))) {
      throw FormatException(
        'PDF font does not support U+${rune.toRadixString(16).toUpperCase()}; export MD/HTML to preserve this character',
      );
    }
  }
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parse(source.startsWith('\ufeff') ? source.substring(1) : source);
  pw.TextSpan inline(md.Node node) {
    if (node is md.Text)
      return pw.TextSpan(text: node.text.replaceAll('\ufeff', ''));
    if (node is! md.Element) return pw.TextSpan(text: node.textContent);
    if (node.tag == 'img')
      return pw.TextSpan(text: node.attributes['alt'] ?? '');
    if (node.tag == 'input')
      return pw.TextSpan(
        text: node.attributes.containsKey('checked') ? '[x] ' : '[ ] ',
      );
    if (node.tag == 'br') return const pw.TextSpan(text: '\n');
    return pw.TextSpan(
      style: pw.TextStyle(
        fontWeight: node.tag == 'strong' ? pw.FontWeight.bold : null,
        fontStyle: node.tag == 'em' ? pw.FontStyle.italic : null,
        decoration: node.tag == 'del' ? pw.TextDecoration.lineThrough : null,
      ),
      children: (node.children ?? []).map(inline).toList(),
    );
  }

  final blocks = <pw.Widget>[];
  void block(md.Node node, [int indent = 0, String prefix = '']) {
    cancellation?.check();
    if (node is md.Element) {
      if (node.tag == 'ul' || node.tag == 'ol') {
        var index = int.tryParse(node.attributes['start'] ?? '') ?? 1;
        for (final child in node.children ?? <md.Node>[]) {
          block(child, indent + 1, node.tag == 'ol' ? '${index++}. ' : '- ');
        }
        return;
      }
      if (node.tag == 'li' || node.tag == 'blockquote') {
        var first = true;
        final pending = <md.Node>[];
        void flush() {
          if (pending.isEmpty) return;
          block(md.Element('p', List.of(pending)), indent, first ? prefix : '');
          pending.clear();
          first = false;
        }

        for (final child in node.children ?? <md.Node>[]) {
          if (child is md.Element &&
              {
                'p',
                'ul',
                'ol',
                'blockquote',
                'pre',
                'table',
              }.contains(child.tag)) {
            flush();
            block(child, indent, first ? prefix : '');
            first = false;
          } else {
            pending.add(child);
          }
        }
        flush();
        return;
      }
      if (node.tag == 'table') {
        final rows = <List<String>>[];
        void row(md.Node n) {
          if (n is! md.Element) return;
          if (n.tag == 'tr') {
            rows.add((n.children ?? []).map((c) => c.textContent).toList());
          } else {
            for (final c in n.children ?? <md.Node>[]) {
              row(c);
            }
          }
        }

        row(node);
        if (rows.isNotEmpty)
          blocks.add(
            pw.TableHelper.fromTextArray(
              data: rows,
              headerCount: 1,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );
        blocks.add(pw.SizedBox(height: 8));
        return;
      }
      if (node.tag == 'hr') {
        blocks.add(pw.Divider());
        return;
      }
    }
    final tag = node is md.Element ? node.tag : '';
    final heading = RegExp(r'^h([1-6])$').firstMatch(tag);
    blocks.add(
      pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '${'  ' * indent}$prefix'),
            inline(node),
          ],
          style: pw.TextStyle(
            fontSize: heading == null
                ? (tag == 'pre' ? 10 : 11)
                : 25 - int.parse(heading[1]!) * 2,
            fontWeight: heading == null
                ? pw.FontWeight.normal
                : pw.FontWeight.bold,
            lineSpacing: 3,
          ),
        ),
      ),
    );
    blocks.add(pw.SizedBox(height: 7));
  }

  for (final node in nodes) {
    block(node);
  }
  if (blocks.isEmpty) blocks.add(pw.Text(''));
  try {
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        maxPages: 100,
        // MultiPage's own maxPages assertion is disabled in release builds.
        header: (c) {
          cancellation?.check();
          if (c.pageNumber > 100)
            throw const FormatException(
              'Markdown PDF limit: 100 pages; simplify oversized blocks',
            );
          return pw.SizedBox(height: 0);
        },
        build: (_) => blocks,
      ),
    );
    final bytes = await document.save(enableEventLoopBalancing: true);
    cancellation?.check();
    if (bytes.length > 10000000 ||
        document.document.pdfPageList.pages.length > 100) {
      throw const FormatException('Markdown PDF limit: 10 MB / 100 pages');
    }
    return bytes;
  } on Cancelled {
    rethrow;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'Could not lay out this document as PDF; export MD/HTML or simplify oversized blocks',
    );
  }
}

class DocumentPack {
  final String source, html, text;
  final Uint8List pdfBytes;
  const DocumentPack(this.source, this.html, this.text, this.pdfBytes);
}

const _packNames = {
  'source.md',
  'document.html',
  'document.txt',
  'document.pdf',
};
String _exactUtf8(Uint8List bytes) {
  // Dart strips an initial BOM. A prefix preserves every original code point.
  final prefixed = Uint8List(bytes.length + 1)..[0] = 32;
  prefixed.setRange(1, prefixed.length, bytes);
  return utf8.decode(prefixed, allowMalformed: false).substring(1);
}

/// Reopens legacy/current packs without loading HTML or writing archive paths.
DocumentPack parseDocumentPack(Uint8List bytes) {
  final files = decodePortableZip(
    bytes,
    isAllowedPath: _packNames.contains,
    maxEntries: 4,
    maxEntryBytes: 10000000,
    maxTotalBytes: 16000000,
  );
  if (files.length != 4)
    throw const FormatException('Document pack requires MD, HTML, TXT and PDF');
  final source = _exactUtf8(files['source.md']!);
  serializeMarkdownDraft(source);
  final html = _exactUtf8(files['document.html']!),
      text = _exactUtf8(files['document.txt']!),
      pdfBytes = files['document.pdf']!;
  if (files['document.html']!.length > 4000000 ||
      files['document.txt']!.length > 1000000 ||
      pdfBytes.length < 8 ||
      !ascii
          .decode(pdfBytes.take(5).toList(), allowInvalid: true)
          .startsWith('%PDF-')) {
    throw const FormatException('Invalid document pack content');
  }
  // The application must parse the actual PDF before accepting or exporting.
  return DocumentPack(source, html, text, pdfBytes);
}

Uint8List createDocumentPack(String source, Uint8List verifiedPdfBytes) {
  final document = parseMarkdownDocument(source), archive = Archive();
  for (final entry in {
    'source.md': utf8.encode(source),
    'document.html': utf8.encode(document.html),
    'document.txt': utf8.encode(document.text),
    'document.pdf': verifiedPdfBytes,
  }.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  final bytes = ZipEncoder().encodeBytes(archive, level: 0);
  final reopened = parseDocumentPack(bytes);
  if (reopened.source != source ||
      reopened.html != document.html ||
      reopened.text != document.text ||
      reopened.pdfBytes.length != verifiedPdfBytes.length ||
      getCrc32(reopened.pdfBytes) != getCrc32(verifiedPdfBytes)) {
    throw const FormatException('Document pack roundtrip verification failed');
  }
  return bytes;
}
