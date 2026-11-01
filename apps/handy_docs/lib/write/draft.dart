import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_files/share.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_ui/kit.dart';

/// The one Markdown draft. The text lives here, outside the page, so leaving
/// the editor keeps it; it reaches the disk only when the person saves.
class DraftController extends ChangeNotifier {
  final DocumentRepository documents;
  final ExportHistory history;
  DraftController(this.documents, {ExportHistory? history})
    : history = history ?? ExportHistory('docs') {
    source.addListener(_typed);
  }

  final source = TextEditingController();
  final undo = UndoHistoryController();
  String saved = '';
  bool loaded = false;
  Object? error;
  bool _dirty = false;
  bool get dirty => _dirty;

  /// The exported file's record could not be written (the file was).
  bool historyUnavailable = false;

  void _typed() {
    if (_dirty != (source.text != saved)) {
      _dirty = !_dirty;
      notifyListeners();
    }
  }

  /// A damaged draft is reported and never replaced by an empty one.
  Future<void> load() async {
    error = null;
    try {
      final raw = await documents.load();
      saved = raw == null ? '' : parseMarkdownDraft(raw);
      source.text = saved;
      loaded = true;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  Future<void> save() async {
    final text = source.text;
    await documents.save(serializeMarkdownDraft(text));
    saved = text;
    _dirty = source.text != saved;
    notifyListeners();
  }

  /// Puts [text] in the editor; the saved draft is untouched until [save].
  void replace(String text) {
    serializeMarkdownDraft(text);
    source.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void revert() => replace(saved);

  /// Words in the draft as the reader will see them.
  int get words => RegExp(r'\S+').allMatches(source.text).length;

  /// The first lines as plain text, for the sheet on the desk.
  String get opening {
    final text = source.text;
    final head = text.length > 600 ? text.substring(0, 600) : text;
    try {
      return parseMarkdownDocument(head).text.trim();
    } catch (_) {
      return head.trim();
    }
  }

  static const previewBytes = 100000;

  /// The rendered document, or a [FormatException] past the preview limit.
  MarkdownDocument render() {
    if (utf8.encode(source.text).length > previewBytes) {
      throw const FormatException(
        'Preview limit: 100 KB; larger documents can still be saved/exported',
      );
    }
    return parseMarkdownDocument(source.text);
  }

  ({int count, int? line, int? column}) find(String query) {
    final m = findMarkdownLiteral(source.text, query);
    return (count: m.count, line: m.first?.line, column: m.first?.column);
  }

  /// Literal text only: `$&` stays `$&`.
  void replaceAll(String query, String replacement) =>
      replace(replaceMarkdownLiteral(source.text, query, replacement));

  void template(String kind, String locale) =>
      replace(insertMarkdownTemplate(source.text, kind, locale: locale));

  /// Checks a document ZIP fully, PDF included, before handing back its text.
  Future<String> readPack(Uint8List bytes) async {
    final pack = parseDocumentPack(bytes);
    final pdf = await LocalPdf.open(pack.pdfBytes);
    await pdf.close();
    return pack.source;
  }

  /// The draft as one file: name, bytes and type, checked before it leaves.
  Future<(String, Uint8List, String)> output(
    String kind,
    CancellationToken token,
  ) async {
    final text = source.text;
    serializeMarkdownDraft(text);
    if (kind == 'pdf' || kind == 'zip') {
      parseMarkdownDocument(text);
      final fonts = await Future.wait([
        for (final style in ['Regular', 'Bold', 'Italic', 'BoldItalic'])
          rootBundle.load('packages/handy_ui/assets/fonts/NotoSans-$style.ttf'),
      ]);
      token.check();
      final pdfBytes = await markdownPdf(
        text,
        MarkdownPdfFonts(fonts[0], fonts[1], fonts[2], fonts[3]),
        cancellation: token,
      );
      final pdf = await LocalPdf.open(pdfBytes, cancellation: token);
      try {
        if (pdf.pages.isEmpty || pdf.pages.length > 100) {
          throw const FormatException('Invalid generated PDF page count');
        }
      } finally {
        await pdf.close();
      }
      token.check();
      return kind == 'pdf'
          ? ('document.pdf', pdfBytes, 'application/pdf')
          : (
              'document-pack.zip',
              createDocumentPack(text, pdfBytes),
              'application/zip',
            );
    }
    final out = switch (kind) {
      'md' => text,
      'html' => parseMarkdownDocument(text).html,
      _ => parseMarkdownDocument(text).text,
    };
    final bytes = Uint8List.fromList(utf8.encode(out));
    // Dart drops a leading BOM when decoding; a prefix checks the exact text.
    if (utf8.decode([32, ...bytes]).substring(1) != out) {
      throw const FormatException('UTF-8 output verification failed');
    }
    final mime = switch (kind) {
      'html' => 'text/html; charset=utf-8',
      'md' => 'text/markdown; charset=utf-8',
      _ => 'text/plain; charset=utf-8',
    };
    return ('document.$kind', bytes, mime);
  }

  /// Saves the file where the person chooses, or hands it to the share
  /// sheet. Null when canceled. Saved files are noted in the export history
  /// by checksum only, never by content.
  Future<String?> deliver(
    HandyFiles files,
    (String, Uint8List, String) file, {
    required CancellationToken token,
    Rect? shareFrom,
  }) async {
    final (name, bytes, mime) = file;
    historyUnavailable = false;
    if (shareFrom != null) {
      final result = await const LocalShare().bytes(
        name,
        bytes,
        mimeType: mime,
        origin: shareFrom,
        cancellation: token,
      );
      return switch (result) {
        LocalShareResult.dismissed => null,
        LocalShareResult.selected => 'share-selected',
        LocalShareResult.unknown => 'share-unknown',
      };
    }
    final uri = await files.exportBytes(
      name,
      bytes,
      mimeType: mime,
      cancellation: token,
    );
    if (uri == null) return null;
    try {
      await history.record(
        tool: switch (name.split('.').last) {
          'md' => 'md-source',
          'html' => 'md-html',
          'txt' => 'md-text',
          final ext => 'markdown-$ext',
        },
        uri: uri,
        mime: mime.split(';').first,
        data: bytes,
      );
    } catch (_) {
      historyUnavailable = true;
    }
    return uri;
  }

  @override
  void dispose() {
    source.removeListener(_typed);
    source.dispose();
    undo.dispose();
    super.dispose();
  }
}
