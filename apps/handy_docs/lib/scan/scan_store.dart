import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ocr/handy_ocr.dart';
import 'package:handy_storage/documents.dart';
import '../session.dart';

/// The scanner's pages on this device. Every change is written first and
/// only then shown; a failed write leaves the pages as they were.
class ScanStore extends ChangeNotifier {
  final DocumentRepository documents;
  final ScanCamera camera;
  ScanStore(this.documents, this.camera);

  ScanSession? session;
  Object? error;

  /// A photo the camera took while Android had closed the app.
  ImportedBytes? recovered;
  List<ScanPage> get pages => session?.pages ?? const [];
  bool get full => pages.length >= 20;

  Future<void> load() async {
    error = null;
    try {
      final raw = await documents.load();
      session = raw == null ? ScanSession([]) : ScanSession.parse(raw);
    } catch (e) {
      error = e;
    }
    notifyListeners();
    // Android can recreate the activity while the system camera is open.
    try {
      recovered = await camera.recover();
    } catch (_) {
      recovered = null;
    }
    notifyListeners();
  }

  Future<void> commit(List<ScanPage> next) async {
    final s = ScanSession(next);
    await documents.save(s.serialize());
    session = s;
    notifyListeners();
  }

  /// Puts a corrected page in place of [replace], or at the end.
  Future<void> put(Uint8List png, String name, {ScanPage? replace}) {
    final page = ScanPage(
      replace?.id ??
          '${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
      replace?.name ?? name.substring(0, min(name.length, 200)),
      png,
    );
    return commit(
      replace == null
          ? [...pages, page]
          : [for (final p in pages) p.id == replace.id ? page : p],
    );
  }

  Future<void> move(int from, int to) {
    final list = [...pages];
    list.insert(to.clamp(0, list.length - 1), list.removeAt(from));
    return commit(list);
  }

  Future<void> remove(String id) => commit([
    for (final p in pages)
      if (p.id != id) p,
  ]);

  void dismissRecovered() {
    recovered = null;
    notifyListeners();
  }

  /// All pages as one PDF, saved where the person chooses. Null if canceled.
  Future<String?> exportPdf(
    HandyFiles files,
    CancellationToken token,
    ValueChanged<double> progress,
  ) async {
    final bytes = await scannerPdf(
      [for (final p in pages) p.png],
      cancellation: token,
      onProgress: progress,
    );
    return files.exportBytes(
      'handy-docs-scan.pdf',
      bytes,
      mimeType: 'application/pdf',
      cancellation: token,
    );
  }

  /// All pages as one PDF with the words read on this device laid under
  /// each picture, invisible: the PDF can be searched and copied from.
  /// [language] is tried first; without it the engine's own is used.
  Future<String?> exportSearchablePdf(
    HandyFiles files,
    CancellationToken token,
    ValueChanged<double> progress,
    String language,
  ) async {
    final pngs = [for (final p in pages) p.png];
    final support = await ocrSupport();
    final tag = support.listsLanguages ? support.match(language) : null;
    final hidden = <PdfStamp>[];
    for (var i = 0; i < pngs.length; i++) {
      token.check();
      final read = await recognizeText(
        pngs[i],
        language: tag,
        cancellation: token,
      );
      hidden.addAll(searchableLayer(i, read));
      progress((i + 1) / (pngs.length + 1));
    }
    final base = await scannerPdf(pngs, cancellation: token);
    var bytes = base;
    if (hidden.isNotEmpty) {
      final pdf = await LocalPdf.open(base, cancellation: token);
      try {
        bytes = await pdf.flatten(hidden, cancellation: token);
      } finally {
        await pdf.close();
      }
    }
    progress(1);
    return files.exportBytes(
      'handy-docs-scan-searchable.pdf',
      bytes,
      mimeType: 'application/pdf',
      cancellation: token,
    );
  }

  Future<String?> backup(HandyFiles files) => files.exportBytes(
    'handy-docs-session.json',
    Uint8List.fromList(utf8.encode(session!.serialize())),
    mimeType: 'application/json',
  );

  /// Reads and checks a session file; nothing changes until [commit].
  static ScanSession parseBackup(Uint8List bytes) =>
      ScanSession.parse(utf8.decode(bytes));
}

/// The words of one page as invisible text over the lines they came from,
/// each stretched to its line so a search highlights the right place.
List<PdfStamp> searchableLayer(int page, OcrResult read) => [
  for (final line in read.lines)
    if (read.width > 0 && read.height > 0 && line.box.width > 0)
      PdfTextStamp(
        page,
        PdfBox(
          (line.box.left / read.width).clamp(0.0, .99),
          (line.box.top / read.height).clamp(0.0, .99),
          (line.box.width / read.width).clamp(
            .005,
            1 - (line.box.left / read.width).clamp(0.0, .99),
          ),
          (line.box.height / read.height).clamp(
            .005,
            1 - (line.box.top / read.height).clamp(0.0, .99),
          ),
        ),
        line.text.length > maxStampTextLength
            ? line.text.substring(0, maxStampTextLength)
            : line.text,
        invisible: true,
        fit: true,
      ),
];

const maxStampTextLength = 300;
