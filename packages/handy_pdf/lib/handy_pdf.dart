import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:handy_core/handy_core.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'src/edit_stub.dart' if (dart.library.io) 'src/edit_native.dart' as edit;
import 'src/font.dart';
import 'src/stamps.dart';

export 'src/font.dart' show PdfFont;
export 'src/stamps.dart'
    show
        PdfBox,
        PdfStamp,
        PdfImageStamp,
        PdfTextStamp,
        textLineHeight,
        textBaseline,
        validateStamps,
        shownToPdf,
        shownSize;

/// Content editing (stamps, signatures, smaller pictures) is available
/// through PDFium's native document API: Android, iOS and Windows.
const bool supportsPdfWatermark = edit.supported;
const bool supportsPdfEditing = edit.supported;

/// One line, up to 100 characters, that [font] can draw. Without a font only
/// printable ASCII is accepted.
void validatePdfWatermark(String text, {PdfFont? font}) {
  if (text.length > 100 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(text)) {
    throw const FormatException('Stamp text is one line of up to 100 letters');
  }
  if (font == null
      ? text.codeUnits.any((c) => c < 32 || c > 126)
      : !font.covers(text)) {
    throw const FormatException(
      'Stamp text can use Latin letters, Vietnamese and common punctuation',
    );
  }
}

/// The text face embedded in stamps and filled-in text: Geist, which covers
/// Vietnamese. Loaded once from the bundled handy_ui fonts.
Future<PdfFont> loadPdfFont() => _font ??= rootBundle
    .load('packages/handy_ui/fonts/Geist-Regular.ttf')
    .then(
      (data) => PdfFont(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    )
    .catchError((Object e) {
      _font = null;
      throw e;
    });
Future<PdfFont>? _font;

/// A smaller copy and what changed to make it.
class PdfCompressed {
  final Uint8List bytes;

  /// Pictures re-encoded, and pictures left exactly as they were.
  final int changed, kept;

  /// True when every page became a picture ("strong" compression).
  final bool rasterized;
  const PdfCompressed(this.bytes, this.changed, this.kept, this.rasterized);
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
    PdfFont? font,
    CancellationToken? cancellation,
  }) async {
    _check();
    cancellation?.check();
    if (watermark.isNotEmpty && supportsPdfWatermark) {
      font ??= await loadPdfFont();
    }
    validatePdfWatermark(watermark, font: font);
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
        await edit.applyMarks(
          destination,
          [
            for (var i = 0; i < selected.length; i++)
              edit.watermarkMark(i, watermark),
          ],
          font!.bytes,
          cancellation,
        );
      }
      return await _encode(destination, selected.length, cancellation);
    } finally {
      await destination.dispose();
    }
  }

  /// A new copy of every page with [stamps] drawn on: signatures, text,
  /// dates or a hidden text layer. The open document is never changed.
  Future<Uint8List> flatten(
    List<PdfStamp> stamps, {
    PdfFont? font,
    CancellationToken? cancellation,
  }) async {
    _check();
    cancellation?.check();
    if (!supportsPdfEditing) {
      throw const FormatException(
        'Signing and filling PDFs is available in the Android, iOS and Windows apps',
      );
    }
    validateStamps(stamps, pages.length);
    if (stamps.any((s) => s is PdfTextStamp)) {
      font ??= await loadPdfFont();
      for (final s in stamps.whereType<PdfTextStamp>()) {
        if (!font.covers(s.text)) {
          throw const FormatException(
            'Text on a page can use Latin letters, Vietnamese and common punctuation',
          );
        }
      }
    }
    final count = pages.length;
    final destination = await PdfDocument.createNew(
      sourceName: 'memory:handy-pdf-filled',
    );
    try {
      destination.pages = [..._document.pages];
      await destination.assemble();
      cancellation?.check();
      await edit.applyMarks(
        destination,
        [for (final s in stamps) edit.markOf(s)],
        font?.bytes,
        cancellation,
      );
      return await _encode(destination, count, cancellation);
    } finally {
      await destination.dispose();
    }
  }

  /// A smaller copy: pictures re-encoded as JPEG at [quality] (1–95) and at
  /// most [dpi] at their size on the page. Text, vectors and links stay as
  /// they are. Throws a [FormatException] when nothing could be made smaller.
  Future<PdfCompressed> compress({
    int quality = 60,
    int dpi = 150,
    CancellationToken? cancellation,
  }) async {
    _check();
    cancellation?.check();
    if (!supportsPdfEditing) {
      throw const FormatException(
        'Making PDFs smaller is available in the Android, iOS and Windows apps',
      );
    }
    if (quality < 1 || quality > 95 || dpi < 50 || dpi > 600) {
      throw const FormatException('Invalid compression settings');
    }
    final count = pages.length;
    final destination = await PdfDocument.createNew(
      sourceName: 'memory:handy-pdf-smaller',
    );
    try {
      destination.pages = [..._document.pages];
      await destination.assemble();
      final report = await edit.recompressImages(
        destination,
        quality,
        dpi,
        cancellation,
      );
      if (report.changed == 0) {
        throw const FormatException(
          'No picture in this PDF could be made smaller',
        );
      }
      // Replaced pictures stay in the document until its pages are copied
      // into a fresh one, which keeps only what the pages use.
      final fresh = await PdfDocument.createNew(
        sourceName: 'memory:handy-pdf-smaller-copy',
      );
      try {
        fresh.pages = [...destination.pages];
        final bytes = await _encode(fresh, count, cancellation);
        return PdfCompressed(bytes, report.changed, report.kept, false);
      } finally {
        await fresh.dispose();
      }
    } finally {
      await destination.dispose();
    }
  }

  /// "Strong" compression: every page becomes one JPEG picture at [dpi].
  /// Text can no longer be selected or searched, and links stop working.
  Future<PdfCompressed> rasterize({
    int dpi = 100,
    int quality = 55,
    CancellationToken? cancellation,
    void Function(double)? onProgress,
  }) async {
    _check();
    cancellation?.check();
    if (quality < 1 || quality > 95 || dpi < 50 || dpi > 300) {
      throw const FormatException('Invalid compression settings');
    }
    final made = <PdfDocument>[];
    PdfDocument? destination;
    try {
      for (var i = 0; i < pages.length; i++) {
        cancellation?.check();
        final page = _document.pages[i];
        var scale = dpi / 72;
        scale = math.min(scale, 2000 / math.max(page.width, page.height));
        final width = math.max(1, (page.width * scale).round()),
            height = math.max(1, (page.height * scale).round());
        final raster = await page.render(
          width: width,
          height: height,
          fullWidth: width.toDouble(),
          fullHeight: height.toDouble(),
          backgroundColor: 0xffffffff,
        );
        if (raster == null) {
          throw const FormatException('PDF page could not be rendered');
        }
        final Uint8List jpeg;
        try {
          final pixels = Uint8List.fromList(raster.pixels);
          jpeg = await Isolate.run(
            () => img.encodeJpg(
              img.Image.fromBytes(
                width: width,
                height: height,
                bytes: pixels.buffer,
                numChannels: 4,
                order: img.ChannelOrder.bgra,
              ).convert(numChannels: 3),
              quality: quality,
            ),
          );
        } finally {
          raster.dispose();
        }
        made.add(
          await PdfDocument.createFromJpegData(
            jpeg,
            width: page.width,
            height: page.height,
            sourceName: 'memory:handy-pdf-page-$i',
          ),
        );
        onProgress?.call((i + 1) / pages.length);
      }
      cancellation?.check();
      destination = await PdfDocument.createNew(
        sourceName: 'memory:handy-pdf-pictures',
      );
      destination.pages = [for (final d in made) d.pages.first];
      final bytes = await _encode(destination, made.length, cancellation);
      return PdfCompressed(bytes, made.length, 0, true);
    } finally {
      await destination?.dispose();
      for (final d in made) {
        await d.dispose();
      }
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
