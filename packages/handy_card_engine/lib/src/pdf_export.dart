part of '../handy_card_engine.dart';

/// Where a picture is drawn so the element's crop region fills its box by
/// its fit rule: the whole picture's box in element coordinates. Clipping
/// to the element (and its mask) hides the rest. Shared by every renderer.
Box imagePlacement(CardElement e, double imageW, double imageH) {
  final w = e.frame.width, h = e.frame.height;
  final cx = e.prop<double>('cropX', 0) * imageW,
      cy = e.prop<double>('cropY', 0) * imageH;
  final cw = e.prop<double>('cropW', 1) * imageW,
      ch = e.prop<double>('cropH', 1) * imageH;
  double sx, sy;
  switch (e.prop<String>('fit', 'cover')) {
    case 'fill':
      sx = w / cw;
      sy = h / ch;
    case 'contain':
      sx = sy = math.min(w / cw, h / ch);
    default:
      sx = sy = math.max(w / cw, h / ch);
  }
  final ox = (w - cw * sx) / 2 - cx * sx, oy = (h - ch * sy) / 2 - cy * sy;
  return Box(ox, oy, imageW * sx, imageH * sy);
}

/// The clip outline of a picture element (its mask), in element space.
List<PathOp> imageClip(CardElement e) =>
    switch (e.prop<String>('mask', 'none')) {
      'ellipse' => ellipsePath(e.frame.width, e.frame.height),
      'rounded' => roundedRectPath(
        e.frame.width,
        e.frame.height,
        e.prop<double>('radius', 8),
      ),
      _ => roundedRectPath(e.frame.width, e.frame.height, 0),
    };

/// Everything a PDF writer can use while drawing one element.
class PdfContext {
  final PdfDocument pdf;
  final PdfGraphics g;
  final CardDocument doc;
  final CardProfile? profile;
  final TextMeasurer measurer;
  final Map<String, Uint8List> assets;
  final Map<String, Uint8List> fonts;
  final List<String> warnings;
  final _fontCache = <String, PdfFont>{};
  final _imageCache = <String, PdfImage?>{};
  PdfContext(
    this.pdf,
    this.g,
    this.doc,
    this.profile,
    this.measurer,
    this.assets,
    this.fonts,
    this.warnings,
  );

  /// The embedded face for the element: `<family>-<400|700>` from [fonts],
  /// else the regular weight, else Helvetica (which lacks Vietnamese marks;
  /// a warning says so).
  PdfFont font(CardElement e) {
    final family = e.prop<String>('font', 'sans');
    final weight = e.prop<double>('weight', 400) >= 600 ? 700 : 400;
    for (final key in [
      '$family-$weight',
      '$family-400',
      'sans-$weight',
      'sans-400',
    ]) {
      final bytes = fonts[key];
      if (bytes != null) {
        return _fontCache.putIfAbsent(
          key,
          () => PdfTtfFont(pdf, ByteData.sublistView(bytes)),
        );
      }
    }
    if (!warnings.contains(_noFont)) warnings.add(_noFont);
    return _fontCache.putIfAbsent('helvetica', () => PdfFont.helvetica(pdf));
  }

  PdfImage? image(String id) => _imageCache.putIfAbsent(id, () {
    final bytes = assets[id];
    if (bytes == null) return null;
    final asset = doc.assets.where((a) => a.id == id).firstOrNull;
    if (asset?.mime == 'image/jpeg') return PdfImage.jpeg(pdf, image: bytes);
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final rgba = decoded.convert(numChannels: 4);
    return PdfImage(
      pdf,
      image: rgba.getBytes(order: img.ChannelOrder.rgba),
      width: rgba.width,
      height: rgba.height,
    );
  });
}

const _noFont =
    'No embedded face was given; text used Helvetica and may lose Vietnamese marks';

typedef PdfWriter = void Function(PdfContext ctx, CardElement e, double alpha);

/// Writers by element type. Register one for a new element type.
final pdfWriters = <String, PdfWriter>{
  'text': _pdfText,
  'contact': _pdfText,
  'rect': (c, e, a) => _pdfShape(
    c,
    e,
    a,
    roundedRectPath(e.frame.width, e.frame.height, e.prop<double>('radius', 0)),
  ),
  'ellipse': (c, e, a) =>
      _pdfShape(c, e, a, ellipsePath(e.frame.width, e.frame.height)),
  'polygon': (c, e, a) => _pdfShape(
    c,
    e,
    a,
    polygonPath(
      polygonPoints(
        e.frame.width,
        e.frame.height,
        e.prop<double>('sides', 6).round(),
        star: e.prop<bool>('star', false),
        inner: e.prop<double>('inner', 0.5),
      ),
    ),
  ),
  'line': _pdfLine,
  'image': _pdfImage,
  'icon': (c, e, a) {
    final ops = parseIconPath(
      cardIcons[e.prop<String>('glyph', 'phone')]!,
      e.frame.width,
      e.frame.height,
    );
    _fillOps(c, ops, e.prop<String>('color', '111111'), a, evenOdd: true);
  },
  'qr': _pdfQr,
};

PdfColor _pdfColor(String hex) => PdfColor.fromInt(colorValue(hex));
double _colorAlpha(String hex) =>
    hex.length == 8 ? int.parse(hex.substring(0, 2), radix: 16) / 255 : 1;

void _trace(PdfGraphics g, List<PathOp> ops) {
  for (final op in ops) {
    switch (op) {
      case MoveTo(:final p):
        g.moveTo(p.x, p.y);
      case LineTo(:final p):
        g.lineTo(p.x, p.y);
      case CubicTo(:final c1, :final c2, :final p):
        g.curveTo(c1.x, c1.y, c2.x, c2.y, p.x, p.y);
      case ClosePath():
        g.closePath();
    }
  }
}

void _opacity(PdfContext c, double a) {
  if (a < 1) c.g.setGraphicState(PdfGraphicState(opacity: a));
}

void _fillOps(
  PdfContext c,
  List<PathOp> ops,
  String color,
  double alpha, {
  bool evenOdd = false,
}) {
  c.g.saveContext();
  _opacity(c, alpha * _colorAlpha(color));
  c.g.setFillColor(_pdfColor(color));
  _trace(c.g, ops);
  c.g.fillPath(evenOdd: evenOdd);
  c.g.restoreContext();
}

Matrix4 _m4(Affine m) =>
    Matrix4(m.a, m.b, 0, 0, m.c, m.d, 0, 0, 0, 0, 1, 0, m.e, m.f, 0, 1);

/// Draws the element's content in its own (top-left, y-down) space; the
/// caller has already applied its matrix.
void _pdfElement(PdfContext c, CardElement e, double alpha) {
  if (!e.visible) return;
  c.g.saveContext();
  c.g.setTransform(_m4(e.frame.matrix));
  final a = alpha * e.opacity;
  if (e.isGroup) {
    for (final child in e.children) _pdfElement(c, child, a);
  } else {
    final writer = pdfWriters[e.type];
    if (writer == null) {
      c.warnings.add('An element of type "${e.type}" is not drawn in PDF');
    } else {
      writer(c, e, a);
    }
  }
  c.g.restoreContext();
}

void _pdfShape(PdfContext c, CardElement e, double alpha, List<PathOp> path) {
  final fill = e.prop<String?>('fill', null),
      fill2 = e.prop<String?>('fill2', null);
  final stroke = e.prop<String?>('stroke', null);
  if (fill != null && fill2 != null) {
    // A gradient as 64 thin bands clipped to the shape: vector, and the
    // same in every viewer, at the cost of visible steps when enlarged.
    c.g.saveContext();
    _trace(c.g, path);
    c.g.clipPath();
    final w = e.frame.width, h = e.frame.height;
    final len = math.sqrt(w * w + h * h);
    c.g.setTransform(
      _m4(
        Affine.translate(w / 2, h / 2) *
            Affine.rotate(e.prop<double>('angle', 90) * math.pi / 180),
      ),
    );
    const bands = 64;
    final from = colorValue(fill), to = colorValue(fill2);
    for (var i = 0; i < bands; i++) {
      final t = i / (bands - 1);
      int mix(int shift) =>
          (((from >> shift) & 255) * (1 - t) + ((to >> shift) & 255) * t)
              .round();
      c.g.setFillColor(
        PdfColor.fromInt(
          (255 << 24) | (mix(16) << 16) | (mix(8) << 8) | mix(0),
        ),
      );
      c.g.drawRect(
        -len / 2 + i * len / bands,
        -len / 2,
        len / bands + 0.5,
        len,
      );
      c.g.fillPath();
    }
    c.g.restoreContext();
  } else if (fill != null) {
    _fillOps(c, path, fill, alpha);
  }
  if (stroke != null) {
    c.g.saveContext();
    _opacity(c, alpha * _colorAlpha(stroke));
    c.g.setStrokeColor(_pdfColor(stroke));
    c.g.setLineWidth(e.prop<double>('strokeWidth', 1));
    _trace(c.g, path);
    c.g.strokePath();
    c.g.restoreContext();
  }
}

void _pdfLine(PdfContext c, CardElement e, double alpha) {
  final stroke = e.prop<String?>('stroke', '111111');
  if (stroke == null) return;
  c.g.saveContext();
  _opacity(c, alpha * _colorAlpha(stroke));
  c.g.setStrokeColor(_pdfColor(stroke));
  c.g.setLineWidth(e.prop<double>('strokeWidth', 1));
  final dash = e.prop<double>('dash', 0);
  if (dash > 0) c.g.setLineDashPattern([dash, dash]);
  final y = e.frame.height / 2;
  c.g.drawLine(0, y, e.frame.width, y);
  c.g.strokePath();
  c.g.restoreContext();
}

void _pdfText(PdfContext c, CardElement e, double alpha) {
  final text = displayText(e, c.profile);
  if (text.isEmpty) return;
  final layout = layoutText(e, text, c.measurer);
  final color = e.prop<String>('color', '111111');
  final font = c.font(e);
  c.g.saveContext();
  if (e.prop<String>('overflow', 'shrink') == 'clip') {
    c.g.drawRect(0, 0, e.frame.width, e.frame.height);
    c.g.clipPath();
  }
  _opacity(c, alpha * _colorAlpha(color));
  c.g.setFillColor(_pdfColor(color));
  for (final l in layout.lines) {
    // Glyphs are drawn upright: flip back the page's y-down space locally.
    c.g.saveContext();
    c.g.setTransform(
      _m4(Affine.translate(l.x, l.baseline) * Affine.scale(1, -1)),
    );
    // The built-in Helvetica only encodes Latin-1; other characters become
    // "?" rather than failing the whole export (the warning says so).
    final shown = font is PdfTtfFont
        ? l.text
        : l.text.replaceAll(RegExp(r'[^\u0000-\u00ff]'), '?');
    c.g.drawString(
      font,
      layout.size,
      shown,
      0,
      0,
      charSpace: e.prop<double>('letterSpacing', 0),
    );
    c.g.restoreContext();
  }
  c.g.restoreContext();
}

void _pdfImage(PdfContext c, CardElement e, double alpha) {
  final id = e.prop<String?>('asset', null);
  final image = id == null ? null : c.image(id);
  if (image == null) {
    _fillOps(
      c,
      roundedRectPath(e.frame.width, e.frame.height, 0),
      'E8EAEE',
      alpha,
    );
    if (id != null) c.warnings.add('A picture is missing and was left blank');
    return;
  }
  final at = imagePlacement(e, image.width.toDouble(), image.height.toDouble());
  c.g.saveContext();
  _trace(c.g, imageClip(e));
  c.g.clipPath();
  _opacity(c, alpha);
  c.g.setTransform(
    _m4(Affine.translate(at.x, at.bottom) * Affine.scale(1, -1)),
  );
  c.g.drawImage(image, 0, 0, at.width, at.height);
  c.g.restoreContext();
}

void _pdfQr(PdfContext c, CardElement e, double alpha) {
  final side = math.min(e.frame.width, e.frame.height);
  final bg = e.prop<String?>('background', 'FFFFFF');
  if (bg != null) _fillOps(c, roundedRectPath(side, side, 0), bg, alpha);
  try {
    final m = qrMatrix(
      qrPayload(e, c.profile),
      ecc: e.prop<String>('ecc', 'M'),
    );
    _fillOps(
      c,
      qrPath(m, side, e.prop<double>('quiet', 4).round()),
      e.prop<String>('color', '000000'),
      alpha,
    );
  } on FormatException catch (err) {
    c.warnings.add(err.message);
  }
}

/// Draws one side with its top-left at the current origin.
void _pdfSide(PdfContext c, CardPage page, double bleed) {
  if (page.background != null) {
    _fillOps(
      c,
      roundedRectPath(c.doc.width + 2 * bleed, c.doc.height + 2 * bleed, 0)
          .map(
            (op) => switch (op) {
              MoveTo(:final p) => MoveTo(p - Vec(bleed, bleed)),
              LineTo(:final p) => LineTo(p - Vec(bleed, bleed)),
              _ => op,
            },
          )
          .toList(),
      page.background!,
      1,
    );
  }
  for (final e in page.elements) _pdfElement(c, e, 1);
}

void _cropMarks(
  PdfGraphics g,
  double x,
  double y,
  double w,
  double h,
  double gap,
  double len,
) {
  g.saveContext();
  g.setStrokeColor(PdfColors.black);
  g.setLineWidth(0.25);
  for (final (px, dx) in [(x, -1.0), (x + w, 1.0)]) {
    for (final (py, dy) in [(y, -1.0), (y + h, 1.0)]) {
      g.drawLine(px + dx * gap, py, px + dx * (gap + len), py);
      g.drawLine(px, py + dy * gap, px, py + dy * (gap + len));
    }
  }
  g.strokePath();
  g.restoreContext();
}

/// The design as a vector PDF at its real size, one PDF page per side.
/// With [bleed] the art runs past the trim; [cropMarks] adds a margin with
/// hairline marks at the trim corners. [fonts] maps `<family>-<400|700>`
/// to TrueType bytes so text is embedded, selectable and keeps its marks.
Future<({Uint8List bytes, List<String> warnings})> exportPdf(
  CardDocument doc, {
  CardProfile? profile,
  TextMeasurer measurer = const ApproximateMeasurer(),
  Map<String, Uint8List> assets = const {},
  Map<String, Uint8List> fonts = const {},
  List<String>? pages,
  bool bleed = false,
  bool cropMarks = false,
}) async {
  final pdf = PdfDocument();
  final warnings = <String>[];
  final b = bleed ? doc.bleed : 0.0;
  final margin = cropMarks ? 18.0 : 0.0;
  for (final page in doc.pages.where(
    (p) => pages == null || pages.contains(p.id),
  )) {
    final w = doc.width + 2 * b + 2 * margin,
        h = doc.height + 2 * b + 2 * margin;
    final pdfPage = PdfPage(pdf, pageFormat: PdfPageFormat(w, h));
    final g = pdfPage.getGraphics();
    final c = PdfContext(
      pdf,
      g,
      doc,
      profile,
      measurer,
      assets,
      fonts,
      warnings,
    );
    g.saveContext();
    // Top-left origin, y down, so the scene draws as it does on screen.
    g.setTransform(
      _m4(Affine.translate(margin + b, h - margin - b) * Affine.scale(1, -1)),
    );
    g.saveContext();
    g.drawRect(-b, -b, doc.width + 2 * b, doc.height + 2 * b);
    g.clipPath();
    _pdfSide(c, page, b);
    g.restoreContext();
    if (cropMarks) _cropMarks(g, 0, 0, doc.width, doc.height, b + 3, 12);
    g.restoreContext();
  }
  return (
    bytes: Uint8List.fromList(await pdf.save()),
    warnings: warnings.toSet().toList(),
  );
}

/// Cards laid out on [sheet] (A4 or Letter) as many as fit with [gap]
/// points between them, each with crop marks: a page to print and cut.
Future<({Uint8List bytes, int perSheet, List<String> warnings})>
exportPrintSheet(
  CardDocument doc,
  String pageId, {
  PdfPageFormat sheet = PdfPageFormat.a4,
  int copies = 10,
  double gap = 18,
  CardProfile? profile,
  TextMeasurer measurer = const ApproximateMeasurer(),
  Map<String, Uint8List> assets = const {},
  Map<String, Uint8List> fonts = const {},
}) async {
  const margin = 28.0;
  final cols = ((sheet.width - 2 * margin + gap) / (doc.width + gap)).floor();
  final rows = ((sheet.height - 2 * margin + gap) / (doc.height + gap)).floor();
  final perSheet = cols * rows;
  if (perSheet < 1)
    throw const FormatException('The card is larger than the sheet');
  final pdf = PdfDocument();
  final warnings = <String>[];
  var left = copies.clamp(1, 500);
  while (left > 0) {
    final pdfPage = PdfPage(pdf, pageFormat: sheet);
    final g = pdfPage.getGraphics();
    final c = PdfContext(
      pdf,
      g,
      doc,
      profile,
      measurer,
      assets,
      fonts,
      warnings,
    );
    final usedW = cols * doc.width + (cols - 1) * gap,
        usedH = rows * doc.height + (rows - 1) * gap;
    final x0 = (sheet.width - usedW) / 2, y0 = (sheet.height - usedH) / 2;
    for (var i = 0; i < perSheet && left > 0; i++, left--) {
      final x = x0 + (i % cols) * (doc.width + gap),
          y = y0 + (i ~/ cols) * (doc.height + gap);
      g.saveContext();
      g.setTransform(
        _m4(Affine.translate(x, sheet.height - y) * Affine.scale(1, -1)),
      );
      g.saveContext();
      g.drawRect(0, 0, doc.width, doc.height);
      g.clipPath();
      _pdfSide(c, doc.page(pageId), 0);
      g.restoreContext();
      _cropMarks(
        g,
        0,
        0,
        doc.width,
        doc.height,
        3,
        math.min(9, gap / 2 - 3).toDouble(),
      );
      g.restoreContext();
    }
  }
  return (
    bytes: Uint8List.fromList(await pdf.save()),
    perSheet: perSheet,
    warnings: warnings.toSet().toList(),
  );
}
