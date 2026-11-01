import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:handy_core/handy_core.dart';
import 'package:pdfrx/pdfrx.dart';
import 'src/watermark_stub.dart'
    if (dart.library.io) 'src/watermark_native.dart'
    as stamp;

/// Content editing is available through PDFium's native document API.
const bool supportsPdfWatermark = stamp.supported;

/// Matches the legacy single-line Helvetica stamp without silent truncation.
void validatePdfWatermark(String text) {
  if (text.length > 100 || text.codeUnits.any((c) => c < 32 || c > 126)) {
    throw const FormatException(
      'Watermark requires up to 100 printable ASCII characters',
    );
  }
}

Future<void>? _initializing;
Future<void> _initialize() =>
    _initializing ??= pdfrxFlutterInitialize().catchError((Object e) {
      _initializing = null;
      throw e;
    });

void validatePdfBytes(Uint8List bytes) {
  if (bytes.length < 8 ||
      bytes.length > 30000000 ||
      String.fromCharCodes(bytes.take(5)) != '%PDF-')
    throw const FormatException(
      'PDF requires a valid header and must be at most 30 MB',
    );
}

class PdfPageInfo {
  final double width, height;
  final int rotation;
  const PdfPageInfo(this.width, this.height, this.rotation);
}

/// PDFium processes actual PDFs locally. This adapter never opens URLs, follows
/// document actions/links, writes originals or launches an external application.
class LocalPdf {
  final PdfDocument _document;
  bool _closed = false;
  LocalPdf._(this._document);
  static Future<LocalPdf> open(
    Uint8List bytes, {
    CancellationToken? cancellation,
  }) async {
    validatePdfBytes(bytes);
    cancellation?.check();
    final source = Uint8List.fromList(bytes);
    await _initialize();
    cancellation?.check();
    final document = await PdfDocument.openData(
      source,
      sourceName: 'memory:handy-pdf',
      passwordProvider: () => null,
    );
    try {
      cancellation?.check();
      if (document.isEncrypted)
        throw const FormatException(
          'Encrypted PDFs are not supported; the original file was preserved',
        );
      if (document.pages.isEmpty || document.pages.length > 500)
        throw const FormatException('PDF page limit: 1–500');
      for (final p in document.pages) {
        if (!p.width.isFinite ||
            !p.height.isFinite ||
            p.width <= 0 ||
            p.height <= 0 ||
            p.width > 100000 ||
            p.height > 100000)
          throw const FormatException(
            'Invalid or oversized PDF page dimensions',
          );
      }
      return LocalPdf._(document);
    } catch (_) {
      await document.dispose();
      rethrow;
    }
  }

  void _check() {
    if (_closed) throw StateError('PDF is closed');
  }

  List<PdfPageInfo> get pages {
    _check();
    return List.unmodifiable(
      _document.pages.map(
        (p) => PdfPageInfo(p.width, p.height, p.rotation.index * 90),
      ),
    );
  }

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      await _document.dispose();
    }
  }

  /// Extracts existing selectable text only; this does not perform OCR.
  Future<String> pageText(int index, {CancellationToken? cancellation}) async {
    _check();
    cancellation?.check();
    if (index < 0 || index >= pages.length)
      throw const FormatException('Invalid PDF page');
    final page = await _document.pages[index].loadText();
    if (page == null)
      throw const FormatException('Could not read PDF page text');
    final text = page.fullText;
    cancellation?.check();
    if (text.length > 1000000)
      throw const FormatException('PDF page text limit exceeded');
    return text;
  }

  Future<Uint8List> renderPng(
    int index, {
    int maxEdge = 1400,
    CancellationToken? cancellation,
  }) async {
    _check();
    cancellation?.check();
    if (index < 0 || index >= pages.length || maxEdge < 32 || maxEdge > 2000)
      throw const FormatException('Invalid PDF page or render size');
    final page = _document.pages[index];
    final scale = maxEdge / math.max(page.width, page.height);
    final width = math.max(1, (page.width * scale).round()),
        height = math.max(1, (page.height * scale).round());
    final raster = await page.render(
      width: width,
      height: height,
      fullWidth: width.toDouble(),
      fullHeight: height.toDouble(),
    );
    if (raster == null)
      throw const FormatException('PDF page could not be rendered');
    ui.Image? image;
    try {
      cancellation?.check();
      image = await raster.createImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      cancellation?.check();
      if (data == null || data.lengthInBytes > 20000000)
        throw const FormatException('PDF page image exceeds output limit');
      return Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image?.dispose();
      raster.dispose();
    }
  }

  Future<Uint8List> transform(
    List<int> indices, {
    int rotation = 0,
    String watermark = '',
    CancellationToken? cancellation,
  }) async {
    _check();
    cancellation?.check();
    validatePdfWatermark(watermark);
    if (watermark.isNotEmpty && !supportsPdfWatermark) {
      throw const FormatException(
        'PDF watermark is available in the Android, iOS and Windows apps',
      );
    }
    if (indices.isEmpty ||
        indices.length > 500 ||
        indices.any((i) => i < 0 || i >= pages.length) ||
        !{0, 90, 180, 270}.contains(rotation))
      throw const FormatException('Invalid PDF page selection or rotation');
    final selected = List<int>.from(indices);
    final destination = await PdfDocument.createNew(
      sourceName: 'memory:handy-pdf-output',
    );
    try {
      destination.pages = [
        for (final i in selected)
          _document.pages[i].rotatedBy(PdfPageRotation.values[rotation ~/ 90]),
      ];
      cancellation?.check();
      if (watermark.isNotEmpty) {
        await destination.assemble();
        cancellation?.check();
        await stamp.applyWatermark(destination, watermark, cancellation);
      }
      return await _encode(destination, selected.length, cancellation);
    } finally {
      await destination.dispose();
    }
  }

  static Future<Uint8List> merge(
    List<Uint8List> inputs, {
    CancellationToken? cancellation,
  }) async {
    if (inputs.isEmpty ||
        inputs.length > 20 ||
        inputs.fold<int>(0, (n, b) => n + b.length) > 30000000)
      throw const FormatException('PDF merge limit: 20 files / 30 MB');
    for (final bytes in inputs) {
      validatePdfBytes(bytes);
    }
    cancellation?.check();
    final snapshots = [for (final b in inputs) Uint8List.fromList(b)];
    final opened = <LocalPdf>[];
    PdfDocument? destination;
    try {
      var count = 0;
      for (final bytes in snapshots) {
        cancellation?.check();
        final document = await open(bytes, cancellation: cancellation);
        opened.add(document);
        count += document.pages.length;
        if (count > 500)
          throw const FormatException('PDF merge page limit: 500');
      }
      destination = await PdfDocument.createNew(
        sourceName: 'memory:handy-pdf-merge',
      );
      destination.pages = [
        for (final input in opened) ...input._document.pages,
      ];
      return await _encode(destination, count, cancellation);
    } finally {
      await destination?.dispose();
      for (final input in opened) {
        await input.close();
      }
    }
  }

  static Future<Uint8List> _encode(
    PdfDocument document,
    int count,
    CancellationToken? cancellation,
  ) async {
    cancellation?.check();
    final result = await document.encodePdf();
    cancellation?.check();
    validatePdfBytes(result);
    final reopened = await open(result, cancellation: cancellation);
    try {
      if (reopened.pages.length != count)
        throw const FormatException(
          'PDF output page count verification failed',
        );
    } finally {
      await reopened.close();
    }
    return Uint8List.fromList(result);
  }
}
