part of '../handy_card_engine.dart';

/// What every SVG writer can use while writing one element.
class SvgContext {
  final CardDocument doc;
  final CardProfile? profile;
  final TextMeasurer measurer;
  final Map<String, Uint8List> assets;
  final Map<String, String> families;
  final StringBuffer defs = StringBuffer();
  final List<String> warnings = [];
  int _ids = 0;
  SvgContext(this.doc, this.profile, this.measurer, this.assets, this.families);
  String nextId(String prefix) => '$prefix${++_ids}';
}

typedef SvgWriter =
    void Function(StringBuffer out, CardElement e, SvgContext ctx);

/// Writers by element type. Register one for a new element type.
final svgWriters = <String, SvgWriter>{
  'text': _svgText,
  'contact': _svgText,
  'rect': (o, e, c) => _svgShape(
    o,
    e,
    c,
    roundedRectPath(e.frame.width, e.frame.height, e.prop<double>('radius', 0)),
  ),
  'ellipse': (o, e, c) =>
      _svgShape(o, e, c, ellipsePath(e.frame.width, e.frame.height)),
  'polygon': (o, e, c) => _svgShape(
    o,
    e,
    c,
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
  'line': _svgLine,
  'image': _svgImage,
  'icon': (o, e, c) {
    final glyph = cardIcons[e.prop<String>('glyph', 'phone')]!;
    o.write(
      '<path d="${pathData(parseIconPath(glyph, e.frame.width, e.frame.height))}" fill="${_hex(e.prop<String>('color', '111111'))}" fill-rule="evenodd"${_alpha(e.prop<String>('color', '111111'))}/>',
    );
  },
  'qr': _svgQr,
};

/// The default family stacks: the bundled faces first, then common ones.
const defaultSvgFamilies = {
  'sans': "'Be Vietnam Pro', 'Segoe UI', Arial, sans-serif",
  'serif': "'Literata', Georgia, serif",
  'display': "'Bricolage Grotesque', 'Be Vietnam Pro', sans-serif",
  'mono': "'Geist Mono', Consolas, monospace",
};

/// One side as a standalone SVG document, sized in millimetres so it
/// prints at the card's real size. With [bleed] the art extends past the
/// trim by the design's bleed. Text is real text set line by line from the
/// shared layout; viewers without the named faces substitute others (the
/// warning list says so), which PNG and PDF do not.
({String svg, List<String> warnings}) exportSvg(
  CardDocument doc,
  String pageId, {
  CardProfile? profile,
  TextMeasurer measurer = const ApproximateMeasurer(),
  Map<String, Uint8List> assets = const {},
  bool bleed = false,
  Map<String, String> families = defaultSvgFamilies,
}) {
  final page = doc.page(pageId);
  final b = bleed ? doc.bleed : 0.0;
  final ctx = SvgContext(doc, profile, measurer, assets, families);
  final body = StringBuffer();
  if (page.background != null) {
    body.write(
      '<rect x="${_n(-b)}" y="${_n(-b)}" width="${_n(doc.width + 2 * b)}" height="${_n(doc.height + 2 * b)}" fill="${_hex(page.background!)}"${_alpha(page.background!)}/>',
    );
  }
  for (final e in page.elements) _svgElement(body, e, ctx);
  final w = doc.width + 2 * b, h = doc.height + 2 * b;
  final svg = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
    ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
    ..write(
      'width="${_n(w / pointsPerMm)}mm" height="${_n(h / pointsPerMm)}mm" ',
    )
    ..write('viewBox="${_n(-b)} ${_n(-b)} ${_n(w)} ${_n(h)}">')
    ..write('<title>${_xml(doc.name)}</title>');
  if (ctx.defs.isNotEmpty) svg.write('<defs>${ctx.defs}</defs>');
  svg
    ..write(body)
    ..write('</svg>\n');
  return (svg: svg.toString(), warnings: ctx.warnings);
}

void _svgElement(StringBuffer o, CardElement e, SvgContext ctx) {
  if (!e.visible) return;
  final m = e.frame.matrix.values.map(_n).join(' ');
  o.write(
    '<g transform="matrix($m)"${e.opacity < 1 ? ' opacity="${_n(e.opacity)}"' : ''}>',
  );
  if (e.isGroup) {
    for (final c in e.children) _svgElement(o, c, ctx);
  } else {
    final writer = svgWriters[e.type];
    if (writer == null) {
      ctx.warnings.add('An element of type "${e.type}" is not drawn in SVG');
    } else {
      writer(o, e, ctx);
    }
  }
  o.write('</g>');
}

String _n(double v) {
  final s = v.toStringAsFixed(3);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

String _hex(String c) => '#${c.length == 8 ? c.substring(2) : c}';
String _alpha(String c, [String attr = 'fill-opacity']) {
  if (c.length != 8) return '';
  final a = int.parse(c.substring(0, 2), radix: 16) / 255;
  return a >= 1 ? '' : ' $attr="${_n(a)}"';
}

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
    // Characters XML 1.0 cannot carry at all.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String pathData(List<PathOp> ops) => ops
    .map(
      (op) => switch (op) {
        MoveTo(:final p) => 'M${_n(p.x)} ${_n(p.y)}',
        LineTo(:final p) => 'L${_n(p.x)} ${_n(p.y)}',
        CubicTo(:final c1, :final c2, :final p) =>
          'C${_n(c1.x)} ${_n(c1.y)} ${_n(c2.x)} ${_n(c2.y)} ${_n(p.x)} ${_n(p.y)}',
        ClosePath() => 'Z',
      },
    )
    .join();

void _svgShape(
  StringBuffer o,
  CardElement e,
  SvgContext ctx,
  List<PathOp> path,
) {
  final fill = e.prop<String?>('fill', null),
      fill2 = e.prop<String?>('fill2', null);
  final stroke = e.prop<String?>('stroke', null);
  var fillAttr = fill == null ? 'none' : _hex(fill);
  if (fill != null && fill2 != null) {
    final id = ctx.nextId('g');
    final a = e.prop<double>('angle', 90) * math.pi / 180;
    final dx = math.cos(a) / 2, dy = math.sin(a) / 2;
    ctx.defs.write(
      '<linearGradient id="$id" x1="${_n(0.5 - dx)}" y1="${_n(0.5 - dy)}" x2="${_n(0.5 + dx)}" y2="${_n(0.5 + dy)}">'
      '<stop offset="0" stop-color="${_hex(fill)}"${_alpha(fill, 'stop-opacity')}/>'
      '<stop offset="1" stop-color="${_hex(fill2)}"${_alpha(fill2, 'stop-opacity')}/></linearGradient>',
    );
    fillAttr = 'url(#$id)';
  }
  o.write('<path d="${pathData(path)}" fill="$fillAttr"');
  if (fill != null && fill2 == null) o.write(_alpha(fill));
  if (stroke != null) {
    o.write(
      ' stroke="${_hex(stroke)}" stroke-width="${_n(e.prop<double>('strokeWidth', 1))}"${_alpha(stroke, 'stroke-opacity')}',
    );
  }
  o.write('/>');
}

void _svgLine(StringBuffer o, CardElement e, SvgContext ctx) {
  final stroke = e.prop<String?>('stroke', '111111');
  if (stroke == null) return;
  final y = e.frame.height / 2, dash = e.prop<double>('dash', 0);
  o.write(
    '<line x1="0" y1="${_n(y)}" x2="${_n(e.frame.width)}" y2="${_n(y)}" stroke="${_hex(stroke)}" '
    'stroke-width="${_n(e.prop<double>('strokeWidth', 1))}"${_alpha(stroke, 'stroke-opacity')}'
    '${dash > 0 ? ' stroke-dasharray="${_n(dash)} ${_n(dash)}"' : ''}/>',
  );
}

void _svgText(StringBuffer o, CardElement e, SvgContext ctx) {
  final text = displayText(e, ctx.profile);
  if (text.isEmpty) return;
  final layout = layoutText(e, text, ctx.measurer);
  if (layout.overflow)
    ctx.warnings.add(
      'Text "${text.length > 24 ? '${text.substring(0, 24)}…' : text}" does not fit its box',
    );
  final color = e.prop<String>('color', '111111');
  final family =
      ctx.families[e.prop<String>('font', 'sans')] ??
      defaultSvgFamilies['sans']!;
  final clip = e.prop<String>('overflow', 'shrink') == 'clip';
  String? clipId;
  if (clip) {
    clipId = ctx.nextId('c');
    ctx.defs.write(
      '<clipPath id="$clipId"><rect width="${_n(e.frame.width)}" height="${_n(e.frame.height)}"/></clipPath>',
    );
  }
  o.write(
    '<text font-family="${_xml(family)}" font-size="${_n(layout.size)}" font-weight="${e.prop<double>('weight', 400).round()}"'
    '${e.prop<bool>('italic', false) ? ' font-style="italic"' : ''}'
    '${e.prop<double>('letterSpacing', 0) != 0 ? ' letter-spacing="${_n(e.prop<double>('letterSpacing', 0))}"' : ''}'
    ' fill="${_hex(color)}"${_alpha(color)} xml:space="preserve"${clipId == null ? '' : ' clip-path="url(#$clipId)"'}>',
  );
  for (final l in layout.lines) {
    o.write(
      '<tspan x="${_n(l.x)}" y="${_n(l.baseline)}">${_xml(l.text)}</tspan>',
    );
  }
  o.write('</text>');
}

void _svgImage(StringBuffer o, CardElement e, SvgContext ctx) {
  final id = e.prop<String?>('asset', null);
  final bytes = id == null ? null : ctx.assets[id];
  final asset = ctx.doc.assets.where((a) => a.id == id).firstOrNull;
  final w = e.frame.width, h = e.frame.height;
  if (bytes == null || asset == null) {
    o.write('<rect width="${_n(w)}" height="${_n(h)}" fill="#E8EAEE"/>');
    if (id != null) ctx.warnings.add('A picture is missing and was left blank');
    return;
  }
  final iw = asset.width > 0 ? asset.width.toDouble() : w,
      ih = asset.height > 0 ? asset.height.toDouble() : h;
  final cx = e.prop<double>('cropX', 0) * iw,
      cy = e.prop<double>('cropY', 0) * ih;
  final cw = e.prop<double>('cropW', 1) * iw,
      ch = e.prop<double>('cropH', 1) * ih;
  final fit = switch (e.prop<String>('fit', 'cover')) {
    'contain' => 'xMidYMid meet',
    'fill' => 'none',
    _ => 'xMidYMid slice',
  };
  final mask = e.prop<String>('mask', 'none');
  String? clipId;
  if (mask != 'none') {
    clipId = ctx.nextId('m');
    final shape = mask == 'ellipse'
        ? ellipsePath(w, h)
        : roundedRectPath(w, h, e.prop<double>('radius', 8));
    ctx.defs.write(
      '<clipPath id="$clipId"><path d="${pathData(shape)}"/></clipPath>',
    );
  }
  o.write(
    '<svg width="${_n(w)}" height="${_n(h)}" viewBox="${_n(cx)} ${_n(cy)} ${_n(cw)} ${_n(ch)}" '
    'preserveAspectRatio="$fit"${clipId == null ? '' : ' clip-path="url(#$clipId)"'} overflow="hidden">'
    '<image width="${_n(iw)}" height="${_n(ih)}" href="data:${asset.mime};base64,${base64Encode(bytes)}"/></svg>',
  );
}

void _svgQr(StringBuffer o, CardElement e, SvgContext ctx) {
  final payload = qrPayload(e, ctx.profile);
  final side = math.min(e.frame.width, e.frame.height);
  final bg = e.prop<String?>('background', 'FFFFFF');
  if (bg != null)
    o.write(
      '<rect width="${_n(side)}" height="${_n(side)}" fill="${_hex(bg)}"${_alpha(bg)}/>',
    );
  try {
    final m = qrMatrix(payload, ecc: e.prop<String>('ecc', 'M'));
    final color = e.prop<String>('color', '000000');
    o.write(
      '<path d="${pathData(qrPath(m, side, e.prop<double>('quiet', 4).round()))}" fill="${_hex(color)}" shape-rendering="crispEdges"/>',
    );
  } on FormatException catch (err) {
    ctx.warnings.add(err.message);
  }
}
