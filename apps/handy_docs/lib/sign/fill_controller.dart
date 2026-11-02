import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_pdf/handy_pdf.dart';

/// The pages being signed: their shown sizes, pictures of them, and the
/// one operation that makes the new copy. Tests replace it.
abstract class FillSource {
  int get pageCount;

  /// Width and height of page [index] as shown, in points.
  (double, double) size(int index);
  Future<Uint8List> render(int index);
  Future<Uint8List> flatten(List<PdfStamp> stamps, CancellationToken token);

  /// The new copy, opened to look through before saving.
  Future<FillSource> reopen(Uint8List bytes);
  Future<void> close();
}

/// A PDF opened only for signing: its own PDFium document, closed on leave.
class PdfFillSource implements FillSource {
  final LocalPdf pdf;
  PdfFillSource(this.pdf);

  static Future<PdfFillSource> open(Uint8List bytes) async =>
      PdfFillSource(await LocalPdf.open(bytes));

  @override
  int get pageCount => pdf.pages.length;
  @override
  (double, double) size(int index) =>
      (pdf.pages[index].width, pdf.pages[index].height);
  @override
  Future<Uint8List> render(int index) => pdf.renderPng(index, maxEdge: 1600);
  @override
  Future<Uint8List> flatten(List<PdfStamp> stamps, CancellationToken token) =>
      pdf.flatten(stamps, cancellation: token);
  @override
  Future<FillSource> reopen(Uint8List bytes) => open(bytes);
  @override
  Future<void> close() => pdf.close();
}

enum MarkKind { signature, text, date }

/// One thing placed on a page. Its box is in fractions of the shown page;
/// [aspect] (width ÷ height in points) never changes while it is resized.
class Placed {
  final String id;
  final MarkKind kind;
  final int page;
  final PdfBox box;
  final String text;
  final Uint8List? png, rgba;
  final int pixelWidth, pixelHeight;
  const Placed({
    required this.id,
    required this.kind,
    required this.page,
    required this.box,
    this.text = '',
    this.png,
    this.rgba,
    this.pixelWidth = 0,
    this.pixelHeight = 0,
  });

  Placed at(PdfBox next) => Placed(
    id: id,
    kind: kind,
    page: page,
    box: next,
    text: text,
    png: png,
    rgba: rgba,
    pixelWidth: pixelWidth,
    pixelHeight: pixelHeight,
  );

  PdfStamp stamp() => kind == MarkKind.signature
      ? PdfImageStamp(
          page,
          box,
          rgba: rgba!,
          pixelWidth: pixelWidth,
          pixelHeight: pixelHeight,
        )
      // The line fills its box exactly, as on the preview.
      : PdfTextStamp(page, box, text, fit: true);
}

/// Signing and filling one PDF: what is placed where, and the new copy.
/// The original bytes are only read; the copy exists until it is saved.
class FillController extends ChangeNotifier {
  final FillSource source;
  final String name;
  FillController(this.source, this.name);

  int page = 0;
  final _pictures = <int, Uint8List>{};
  final items = <Placed>[];
  String? selected;
  var _next = 0;

  /// The new copy and its pages, once made.
  Uint8List? output;
  FillSource? preview;
  int previewPage = 0;
  final _previewPictures = <int, Uint8List>{};

  bool _closed = false;

  Uint8List? get picture => _pictures[page];
  Uint8List? get previewPicture => _previewPictures[previewPage];
  List<Placed> get onPage => [
    for (final p in items)
      if (p.page == page) p,
  ];
  Placed? get current => items.where((p) => p.id == selected).firstOrNull;
  bool get dirty => items.isNotEmpty;

  /// Width ÷ height of the shown page.
  double get pageAspect {
    final (w, h) = source.size(page);
    return w / h;
  }

  Future<void> open() => turn(0);

  Future<void> turn(int to) async {
    if (to < 0 || to >= source.pageCount) return;
    _pictures[to] ??= await source.render(to);
    page = to;
    selected = null;
    notifyListeners();
  }

  String _id() => 'mark-${_next++}';

  /// A picture placed lower right, 30% of the page wide.
  void addSignature(Uint8List png, Uint8List rgba, int width, int height) {
    final (pw, ph) = source.size(page);
    final w = .3;
    final h = (w * pw) * (height / width) / ph;
    final box = _fit(PdfBox(.6, .78 - h, w, h));
    _add(
      Placed(
        id: _id(),
        kind: MarkKind.signature,
        page: page,
        box: box,
        png: png,
        rgba: rgba,
        pixelWidth: width,
        pixelHeight: height,
      ),
    );
  }

  /// A line of text 12 points tall, [aspect] times as wide as its line,
  /// mid-page (headings sit at the top), each next one a line lower.
  void addText(String text, double aspect, {MarkKind kind = MarkKind.text}) {
    final (pw, ph) = source.size(page);
    final h = 12 * textLineHeight / ph;
    final w = math.min(.9, h * ph * aspect / pw);
    final row = onPage.where((p) => p.kind != MarkKind.signature).length;
    _add(
      Placed(
        id: _id(),
        kind: kind,
        page: page,
        box: _fit(PdfBox(.12, .46 + row * .05, w, w * pw / aspect / ph)),
        text: text,
      ),
    );
  }

  void _add(Placed p) {
    items.add(p);
    selected = p.id;
    _dropOutput();
    notifyListeners();
  }

  void select(String? id) {
    if (selected == id) return;
    selected = id;
    notifyListeners();
  }

  /// Keeps a box on its page: inside the edges, at least 2% across.
  static PdfBox _fit(PdfBox b) {
    var w = b.width.clamp(.02, 1.0), h = b.height.clamp(.005, 1.0);
    if (h > 1) {
      w = w / h;
      h = 1;
    }
    return PdfBox(b.left.clamp(0.0, 1 - w), b.top.clamp(0.0, 1 - h), w, h);
  }

  /// Moves [id] by fractions of the page.
  void move(String id, double dx, double dy) => _change(id, (b) {
    return PdfBox(b.left + dx, b.top + dy, b.width, b.height);
  });

  /// Makes [id] [dw] wider (fraction of the page), keeping its shape.
  void resize(String id, double dw) => _change(id, (b) {
    final w = (b.width + dw).clamp(.03, 1 - b.left);
    final h = b.height * w / b.width;
    if (b.top + h > 1) return b;
    return PdfBox(b.left, b.top, w, h);
  });

  void _change(String id, PdfBox Function(PdfBox) f) {
    final i = items.indexWhere((p) => p.id == id);
    if (i < 0) return;
    items[i] = items[i].at(_fit(f(items[i].box)));
    _dropOutput();
    notifyListeners();
  }

  void remove(String id) {
    items.removeWhere((p) => p.id == id);
    if (selected == id) selected = null;
    _dropOutput();
    notifyListeners();
  }

  /// Draws everything into a new copy and opens it to look through.
  Future<void> make(CancellationToken token) async {
    if (items.isEmpty) {
      throw const FormatException('Place a signature, text or date first');
    }
    final bytes = await source.flatten([
      for (final p in items) p.stamp(),
    ], token);
    token.check();
    final opened = await source.reopen(bytes);
    if (_closed) {
      await opened.close();
      return;
    }
    await preview?.close();
    _previewPictures.clear();
    output = bytes;
    preview = opened;
    previewPage = page;
    await turnPreview(page);
  }

  Future<void> turnPreview(int to) async {
    final p = preview;
    if (p == null || to < 0 || to >= p.pageCount) return;
    _previewPictures[to] ??= await p.render(to);
    previewPage = to;
    notifyListeners();
  }

  /// Back to placing; the copy is dropped, the marks stay.
  void edit() {
    _dropOutput();
    notifyListeners();
  }

  void _dropOutput() {
    if (output == null && preview == null) return;
    output = null;
    final p = preview;
    preview = null;
    _previewPictures.clear();
    if (p != null) p.close();
  }

  String get outputName {
    final base = name.toLowerCase().endsWith('.pdf')
        ? name.substring(0, name.length - 4)
        : name;
    return '$base-signed.pdf';
  }

  /// Saves the copy where the person chooses; null when canceled.
  Future<String?> save(HandyFiles files, CancellationToken token) =>
      files.exportBytes(
        outputName,
        output!,
        mimeType: 'application/pdf',
        cancellation: token,
      );

  @override
  void notifyListeners() {
    if (!_closed) super.notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    final p = preview;
    preview = null;
    if (p != null) p.close();
    source.close();
    super.dispose();
  }
}
