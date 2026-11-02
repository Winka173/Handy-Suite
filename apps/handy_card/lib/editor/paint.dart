import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart' show handyFontFamily;

/// The bundled faces behind the four design families. All are under the
/// SIL Open Font License, so designs may embed them in exported PDFs.
String cardFamily(String key) => switch (key) {
  'serif' => 'CardSerif',
  'display' => handyFontFamily('Bricolage'),
  'mono' => handyFontFamily('GeistMono'),
  _ => 'HankenGrotesk',
};

/// TrueType bytes for the PDF exporter, as `<family>-<400|700>`.
Future<Map<String, Uint8List>> cardPdfFonts() async {
  Future<Uint8List> load(String path) async =>
      (await rootBundle.load(path)).buffer.asUint8List();
  const ui = 'packages/handy_ui/fonts';
  return {
    'sans-400': await load('fonts/HankenGrotesk-Regular.ttf'),
    'sans-700': await load('fonts/HankenGrotesk-Bold.ttf'),
    'serif-400': await load('fonts/Literata-Regular.ttf'),
    'serif-700': await load('fonts/Literata-Bold.ttf'),
    'display-400': await load('$ui/BricolageGrotesque-Medium.ttf'),
    'display-700': await load('$ui/BricolageGrotesque-Display.ttf'),
    'mono-400': await load('$ui/GeistMono-Regular.ttf'),
  };
}

/// The family stacks written into SVG files.
const cardSvgFamilies = {
  'sans': "'Hanken Grotesk', 'Segoe UI', Arial, sans-serif",
  'serif': "'Literata', Georgia, serif",
  'display': "'Bricolage Grotesque', 'Hanken Grotesk', sans-serif",
  'mono': "'Geist Mono', Consolas, monospace",
};

TextStyle cardTextStyle(CardElement e, double size, {Color? color}) =>
    TextStyle(
      fontFamily: cardFamily(e.prop<String>('font', 'sans')),
      fontSize: size,
      fontWeight:
          FontWeight.values[((e.prop<double>('weight', 400) / 100).round() - 1)
              .clamp(0, 8)],
      fontStyle: e.prop<bool>('italic', false)
          ? FontStyle.italic
          : FontStyle.normal,
      letterSpacing: e.prop<double>('letterSpacing', 0),
      color: color ?? Color(colorValue(e.prop<String>('color', '111111'))),
      height: 1,
    );

/// Measures with the real faces; every renderer places lines from it.
class FlutterMeasurer implements TextMeasurer {
  final _widths = <String, double>{};
  final _ascents = <String, double>{};
  String _key(CardElement e, double size) =>
      '${e.prop<String>('font', 'sans')}|${e.prop<double>('weight', 400)}|${e.prop<bool>('italic', false)}|${e.prop<double>('letterSpacing', 0)}|$size';

  @override
  double width(String text, CardElement style, double size) {
    final key = '${_key(style, size)}|$text';
    final hit = _widths[key];
    if (hit != null) return hit;
    final tp = TextPainter(
      text: TextSpan(text: text, style: cardTextStyle(style, size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    if (_widths.length > 20000) _widths.clear();
    return _widths[key] = w;
  }

  @override
  double ascent(CardElement style, double size) {
    final key = _key(style, size);
    final hit = _ascents[key];
    if (hit != null) return hit;
    final tp = TextPainter(
      text: TextSpan(text: 'Hg', style: cardTextStyle(style, size)),
      textDirection: TextDirection.ltr,
    )..layout();
    final a = tp.computeLineMetrics().first.ascent;
    tp.dispose();
    return _ascents[key] = a;
  }
}

/// What every screen painter can use.
class PaintContext {
  final CardProfile? profile;
  final TextMeasurer measurer;
  final ui.Image? Function(String id) image;
  const PaintContext({
    required this.profile,
    required this.measurer,
    required this.image,
  });
}

typedef CanvasPainter =
    void Function(Canvas c, CardElement e, PaintContext ctx);

Path toPath(List<PathOp> ops, {bool evenOdd = false}) {
  final p = Path()
    ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
  for (final op in ops) {
    switch (op) {
      case MoveTo(p: final v):
        p.moveTo(v.x, v.y);
      case LineTo(p: final v):
        p.lineTo(v.x, v.y);
      case CubicTo(:final c1, :final c2, p: final v):
        p.cubicTo(c1.x, c1.y, c2.x, c2.y, v.x, v.y);
      case ClosePath():
        p.close();
    }
  }
  return p;
}

Color hexColor(String hex) => Color(colorValue(hex));

/// Screen painters by element type. Register one for a new element type.
final canvasPainters = <String, CanvasPainter>{
  'text': _paintText,
  'contact': _paintText,
  'rect': (c, e, ctx) => _paintShape(
    c,
    e,
    roundedRectPath(e.frame.width, e.frame.height, e.prop<double>('radius', 0)),
  ),
  'ellipse': (c, e, ctx) =>
      _paintShape(c, e, ellipsePath(e.frame.width, e.frame.height)),
  'polygon': (c, e, ctx) => _paintShape(
    c,
    e,
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
  'line': _paintLine,
  'image': _paintImage,
  'icon': (c, e, ctx) => c.drawPath(
    toPath(
      parseIconPath(
        cardIcons[e.prop<String>('glyph', 'phone')]!,
        e.frame.width,
        e.frame.height,
      ),
      evenOdd: true,
    ),
    Paint()..color = hexColor(e.prop<String>('color', '111111')),
  ),
  'qr': _paintQr,
  'badge': (c, e, ctx) {
    final fill = e.prop<String?>('fill', 'C2410C');
    if (fill != null)
      c.drawPath(
        toPath(badgeOutline(e.frame.width, e.frame.height)),
        Paint()..color = hexColor(fill),
      );
    paintElement(c, badgeLabel(e), ctx);
  },
};

/// One element and its children, in the parent's coordinates.
void paintElement(Canvas c, CardElement e, PaintContext ctx) {
  if (!e.visible) return;
  final m = e.frame.matrix;
  c.save();
  c.transform(
    Float64List.fromList([
      m.a,
      m.b,
      0,
      0,
      m.c,
      m.d,
      0,
      0,
      0,
      0,
      1,
      0,
      m.e,
      m.f,
      0,
      1,
    ]),
  );
  final layered = e.opacity < 1;
  if (layered) {
    c.saveLayer(
      Rect.fromLTWH(
        -e.frame.width,
        -e.frame.height,
        e.frame.width * 3,
        e.frame.height * 3,
      ),
      Paint()..color = Color.fromRGBO(0, 0, 0, e.opacity),
    );
  }
  if (e.isGroup) {
    for (final child in e.children) {
      paintElement(c, child, ctx);
    }
  } else {
    final painter = canvasPainters[e.type];
    if (painter == null) {
      _paintUnknown(c, e);
    } else {
      painter(c, e, ctx);
    }
  }
  if (layered) c.restore();
  c.restore();
}

/// A whole side: background (into the bleed when [bleed] > 0) and layers.
void paintPage(
  Canvas c,
  CardDocument doc,
  CardPage page,
  PaintContext ctx, {
  double bleed = 0,
}) {
  if (page.background != null) {
    c.drawRect(
      Rect.fromLTWH(
        -bleed,
        -bleed,
        doc.width + 2 * bleed,
        doc.height + 2 * bleed,
      ),
      Paint()..color = hexColor(page.background!),
    );
  }
  for (final e in page.elements) {
    paintElement(c, e, ctx);
  }
}

void _paintShape(Canvas c, CardElement e, List<PathOp> ops) {
  final path = toPath(ops);
  final fill = e.prop<String?>('fill', null),
      fill2 = e.prop<String?>('fill2', null);
  if (fill != null) {
    final paint = Paint()..color = hexColor(fill);
    if (fill2 != null) {
      final a = e.prop<double>('angle', 90) * math.pi / 180;
      final w = e.frame.width, h = e.frame.height;
      final dx = math.cos(a) * w / 2, dy = math.sin(a) * h / 2;
      paint.shader = ui.Gradient.linear(
        Offset(w / 2 - dx, h / 2 - dy),
        Offset(w / 2 + dx, h / 2 + dy),
        [hexColor(fill), hexColor(fill2)],
      );
    }
    c.drawPath(path, paint);
  }
  final stroke = e.prop<String?>('stroke', null);
  if (stroke != null) {
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.prop<double>('strokeWidth', 1)
        ..color = hexColor(stroke),
    );
  }
}

void _paintLine(Canvas c, CardElement e, PaintContext ctx) {
  final stroke = e.prop<String?>('stroke', '111111');
  if (stroke == null) return;
  final paint = Paint()
    ..color = hexColor(stroke)
    ..strokeWidth = e.prop<double>('strokeWidth', 1);
  final y = e.frame.height / 2, dash = e.prop<double>('dash', 0);
  if (dash <= 0) {
    c.drawLine(Offset(0, y), Offset(e.frame.width, y), paint);
    return;
  }
  for (var x = 0.0; x < e.frame.width; x += dash * 2) {
    c.drawLine(
      Offset(x, y),
      Offset(math.min(x + dash, e.frame.width), y),
      paint,
    );
  }
}

void _paintText(Canvas c, CardElement e, PaintContext ctx) {
  final text = displayText(e, ctx.profile);
  if (text.isEmpty) return;
  final layout = layoutText(e, text, ctx.measurer);
  final clip = e.prop<String>('overflow', 'shrink') == 'clip';
  if (clip) {
    c.save();
    c.clipRect(Rect.fromLTWH(0, 0, e.frame.width, e.frame.height));
  }
  final ascent = ctx.measurer.ascent(e, layout.size);
  for (final l in layout.lines) {
    final tp = TextPainter(
      text: TextSpan(text: l.text, style: cardTextStyle(e, layout.size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(c, Offset(l.x, l.baseline - ascent));
    tp.dispose();
  }
  if (clip) c.restore();
}

void _paintImage(Canvas c, CardElement e, PaintContext ctx) {
  final id = e.prop<String?>('asset', null);
  final image = id == null ? null : ctx.image(id);
  final w = e.frame.width, h = e.frame.height;
  c.save();
  c.clipPath(toPath(imageClip(e)));
  if (image == null) {
    // No picture yet (or still loading): a plain well with a cross.
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFE6E8EC),
    );
    final line = Paint()
      ..color = const Color(0xFFB8BEC6)
      ..strokeWidth = math.max(0.5, math.min(w, h) / 60);
    c.drawLine(Offset.zero, Offset(w, h), line);
    c.drawLine(Offset(w, 0), Offset(0, h), line);
  } else {
    final at = imagePlacement(
      e,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    c.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(at.x, at.y, at.width, at.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
  c.restore();
}

void _paintQr(Canvas c, CardElement e, PaintContext ctx) {
  final side = math.min(e.frame.width, e.frame.height);
  final bg = e.prop<String?>('background', 'FFFFFF');
  if (bg != null)
    c.drawRect(Rect.fromLTWH(0, 0, side, side), Paint()..color = hexColor(bg));
  try {
    final m = qrMatrix(
      qrPayload(e, ctx.profile),
      ecc: e.prop<String>('ecc', 'M'),
    );
    c.drawPath(
      toPath(qrPath(m, side, e.prop<double>('quiet', 4).round())),
      Paint()
        ..color = hexColor(e.prop<String>('color', '000000'))
        ..isAntiAlias = false,
    );
  } on FormatException {
    _paintUnknown(c, e);
  }
}

/// An element this build cannot draw: a hatched box, so it is visible and
/// can be selected, moved or deleted; its data is kept as it came.
void _paintUnknown(Canvas c, CardElement e) {
  final r = Rect.fromLTWH(0, 0, e.frame.width, e.frame.height);
  c.drawRect(r, Paint()..color = const Color(0x22C4242A));
  c.drawRect(
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFC4242A)
      ..strokeWidth = 0.75,
  );
}

/// Renders one side to an image at [dpi] (points are 1/72 inch).
Future<ui.Image> renderSide(
  CardDocument doc,
  CardPage page,
  PaintContext ctx, {
  double dpi = 300,
  bool bleed = false,
  bool transparent = false,
}) async {
  final b = bleed ? doc.bleed : 0.0;
  final scale = dpi / 72;
  final w = ((doc.width + 2 * b) * scale).round(),
      h = ((doc.height + 2 * b) * scale).round();
  if (w * h > 64000000) {
    throw const FormatException(
      'Too large to render; choose a lower DPI / Quá lớn, hãy giảm DPI',
    );
  }
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  c.scale(scale);
  c.translate(b, b);
  c.clipRect(Rect.fromLTWH(-b, -b, doc.width + 2 * b, doc.height + 2 * b));
  // A transparent PNG leaves the side's background out; JPEG has no alpha
  // and always gets a white ground under it.
  final side = transparent ? page.copyWith(clearBackground: true) : page;
  if (!transparent && page.background == null) {
    c.drawRect(
      Rect.fromLTWH(-b, -b, doc.width + 2 * b, doc.height + 2 * b),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
  paintPage(c, doc, side, ctx, bleed: b);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  return image;
}
