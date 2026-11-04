import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'stamp_styles.dart';

/// Shapes a stamp can be cut in.
const stampShapes = ['circle', 'oval', 'postage', 'label'];

/// Ink colours: the Trip hue first, then inks a rubber stamp comes in.
const stampInks = [0xff0284c7, 0xff1f2937, 0xffb42318, 0xff0f766e, 0xff92400e];

/// Everything a stamp is drawn from. The photo window shows [photo]
/// scaled by [zoom] and moved by [offset] (a fraction of the window).
class StampDesign {
  final String shape, place, day, trip;

  /// The style it came from, and the style's edge, ornament and weight.
  final String style, edge, decor;
  final bool thin;
  final int ink, seed;
  final double rotation, wear, zoom;
  final Offset offset;
  final ui.Image? photo;
  const StampDesign({
    this.shape = 'circle',
    this.style = 'travel-ring',
    this.edge = 'single',
    this.decor = 'none',
    this.thin = false,
    required this.place,
    required this.day,
    this.trip = '',
    this.ink = 0xff0284c7,
    this.seed = 1,
    this.rotation = -4,
    this.wear = .25,
    this.zoom = 1,
    this.offset = Offset.zero,
    this.photo,
  });

  /// [style]'s cut, ornament, weight and suggested ink.
  StampDesign withStyle(StampStyle style) => StampDesign(
    shape: style.shape,
    style: style.id,
    edge: style.edge,
    decor: style.decor,
    thin: style.thin,
    place: place,
    day: day,
    trip: trip,
    ink: style.ink,
    seed: seed,
    rotation: rotation,
    wear: wear,
    zoom: zoom,
    offset: offset,
    photo: photo,
  );

  StampDesign copyWith({
    String? shape,
    String? place,
    String? trip,
    int? ink,
    double? rotation,
    double? wear,
    double? zoom,
    Offset? offset,
    ui.Image? photo,
    bool noPhoto = false,
  }) => StampDesign(
    shape: shape ?? this.shape,
    style: style,
    edge: edge,
    decor: decor,
    thin: thin,
    place: place ?? this.place,
    day: day,
    trip: trip ?? this.trip,
    ink: ink ?? this.ink,
    seed: seed,
    rotation: rotation ?? this.rotation,
    wear: wear ?? this.wear,
    zoom: zoom ?? this.zoom,
    offset: offset ?? this.offset,
    photo: noPhoto ? null : photo ?? this.photo,
  );
}

/// The stamp on a transparent ground: its cut, the photo in the ink's
/// tones, rings, the place and the day, turned and worn like a real one.
class StampPainter extends CustomPainter {
  final StampDesign d;
  const StampPainter(this.d);

  @override
  bool shouldRepaint(StampPainter old) => old.d != d;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide, c = size.center(Offset.zero);
    final ink = Color(d.ink),
        paper = Color.lerp(ink, const Color(0xffffffff), .9)!;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(d.rotation * math.pi / 180);
    canvas.translate(-c.dx, -c.dy);
    canvas.saveLayer(Offset.zero & size, Paint());
    final outer = _outer(c, s), window = _window(c, s);
    canvas.drawPath(outer, Paint()..color = paper);
    if (d.photo != null) {
      canvas.save();
      canvas.clipPath(window);
      _photo(canvas, window.getBounds(), ink, paper);
      canvas.restore();
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink;
    final main = d.thin ? s * .01 : s * .022;
    if (d.edge == 'scallop') {
      canvas.drawPath(outer, line..strokeWidth = s * .008);
    }
    switch (d.edge) {
      case 'double':
        canvas.drawPath(_inset(c, s, .035), line..strokeWidth = main);
        canvas.drawPath(_inset(c, s, .065), line..strokeWidth = s * .007);
      case 'dotted':
        _dots(canvas, _inset(c, s, .045), s, ink);
      default:
        canvas.drawPath(_inset(c, s, .035), line..strokeWidth = main);
    }
    canvas.drawPath(window, line..strokeWidth = s * .008);
    _decor(canvas, c, s, ink, paper);
    _words(canvas, c, s, ink, paper);
    _wear(canvas, size, s);
    canvas.restore();
    canvas.restore();
  }

  Rect _box(Offset c, double s, double inset) {
    final (w, h) = switch (d.shape) {
      'oval' => (s * .96, s * .7),
      'postage' => (s * .78, s * .96),
      'label' => (s * .96, s * .62),
      _ => (s * .96, s * .96),
    };
    return Rect.fromCenter(
      center: c,
      width: w - s * inset * 2,
      height: h - s * inset * 2,
    );
  }

  Path _shape(Rect r) => switch (d.shape) {
    'circle' || 'oval' => Path()..addOval(r),
    'label' =>
      Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height * .12))),
    _ => Path()..addRect(r),
  };

  /// The cut edge; a postage stamp has its perforations bitten out.
  Path _outer(Offset c, double s) {
    final r = _box(c, s, 0), path = _shape(r);
    if (d.edge == 'scallop' && (d.shape == 'circle' || d.shape == 'oval')) {
      return _scallop(c, s);
    }
    if (d.shape != 'postage') return path;
    final bites = Path(), radius = s * .018, step = radius * 3.2;
    for (
      var x = r.left;
      x <= r.right + .1;
      x += r.width / (r.width / step).round()
    ) {
      bites
        ..addOval(Rect.fromCircle(center: Offset(x, r.top), radius: radius))
        ..addOval(Rect.fromCircle(center: Offset(x, r.bottom), radius: radius));
    }
    for (
      var y = r.top;
      y <= r.bottom + .1;
      y += r.height / (r.height / step).round()
    ) {
      bites
        ..addOval(Rect.fromCircle(center: Offset(r.left, y), radius: radius))
        ..addOval(Rect.fromCircle(center: Offset(r.right, y), radius: radius));
    }
    return Path.combine(PathOperation.difference, path, bites);
  }

  Path _inset(Offset c, double s, double inset) => _shape(_box(c, s, inset));

  /// A scalloped cut for round shapes: one continuous wavy outline, so it
  /// can be filled and inked like any other edge.
  Path _scallop(Offset c, double s) {
    final r = _box(c, s, 0), rx = r.width / 2, ry = r.height / 2;
    final bumps = (math.pi * (rx + ry) / (s * .055)).round(), a = s * .022;
    final path = Path();
    for (var i = 0; i <= 720; i++) {
      final t = i * 2 * math.pi / 720;
      final k = 1 - a / ry * (1 - math.cos(bumps * t).abs());
      final q = c + Offset(math.cos(t) * rx * k, math.sin(t) * ry * k);
      i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    return path..close();
  }

  /// Where the photo shows: inside the rings on a round stamp, above the
  /// words on the others.
  Path _window(Offset c, double s) {
    if (d.shape == 'circle' || d.shape == 'oval') return _inset(c, s, .14);
    final r = _box(c, s, .07);
    return _shape(
      Rect.fromLTRB(r.left, r.top, r.right, r.bottom - r.height * .3),
    );
  }

  void _photo(Canvas canvas, Rect window, Color ink, Color paper) {
    final p = d.photo!;
    final cover =
        math.max(window.width / p.width, window.height / p.height) * d.zoom;
    final w = p.width * cover, h = p.height * cover;
    final dst = Rect.fromCenter(
      center: window.center.translate(
        d.offset.dx * window.width,
        d.offset.dy * window.height,
      ),
      width: w,
      height: h,
    );
    // Duotone: dark parts of the photo take the ink, light parts the paper.
    List<double> row(double inkC, double paperC) {
      final k = inkC - paperC;
      return [-k * .299 / 255, -k * .587 / 255, -k * .114 / 255, 0, inkC];
    }

    canvas.drawImageRect(
      p,
      Offset.zero & Size(p.width.toDouble(), p.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.matrix([
          ...row(ink.r * 255, paper.r * 255),
          ...row(ink.g * 255, paper.g * 255),
          ...row(ink.b * 255, paper.b * 255),
          0,
          0,
          0,
          1,
          0,
        ]),
    );
  }

  TextPainter _text(
    String text,
    double size,
    Color ink, {
    FontWeight w = FontWeight.w600,
    double? width,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Archivo',
        fontSize: size,
        fontWeight: w,
        color: ink,
        letterSpacing: size * .08,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: width ?? double.infinity);

  void _words(Canvas canvas, Offset c, double s, Color ink, Color paper) {
    final place = d.place.toUpperCase();
    if (d.decor == 'banner') return _bannerWords(canvas, c, s, ink, paper);
    if (d.shape == 'circle') {
      final radius = s * .395;
      _arc(canvas, place, c, radius, s * .055, ink, top: true);
      // Without a photo the day takes the middle; the ring keeps the trip.
      final under = d.photo == null
          ? d.trip
          : [d.day, if (d.trip.isNotEmpty) d.trip].join(' · ');
      if (under.isNotEmpty)
        _arc(canvas, under, c, radius, s * .042, ink, top: false);
      if (d.photo == null) _centre(canvas, c, s, d.day, ink);
      return;
    }
    final box = _box(c, s, .07);
    final band = d.shape == 'oval'
        ? Rect.fromLTRB(
            box.left,
            c.dy + box.height * .18,
            box.right,
            box.bottom,
          )
        : Rect.fromLTRB(
            box.left,
            box.bottom - box.height * .3,
            box.right,
            box.bottom,
          );
    if (d.photo == null && d.shape == 'oval') {
      _centre(canvas, c, s, place, ink);
      return;
    }
    final title = _text(place, s * .06, ink, width: band.width * .9);
    final sub = _text(
      [d.day, if (d.trip.isNotEmpty) d.trip].join(' · '),
      s * .036,
      ink,
      w: FontWeight.w500,
      width: band.width * .9,
    );
    final top = d.photo == null && d.shape != 'oval'
        ? c.dy - (title.height + sub.height) / 2
        : band.center.dy - (title.height + sub.height + s * .01) / 2;
    title.paint(canvas, Offset(c.dx - title.width / 2, top));
    sub.paint(
      canvas,
      Offset(c.dx - sub.width / 2, top + title.height + s * .01),
    );
    title.dispose();
    sub.dispose();
  }

  /// The ribbon across the stamp: on round cuts it crosses the middle, on
  /// the others it is the word band. The place reads in paper on the ink.
  Rect _banner(Offset c, double s) {
    final box = _box(c, s, 0);
    if (d.shape == 'circle' || d.shape == 'oval') {
      return Rect.fromCenter(
        center: c,
        width: box.width * 1.02,
        height: s * .16,
      );
    }
    final inner = _box(c, s, .07);
    return Rect.fromLTRB(
      inner.left,
      inner.bottom - inner.height * .3,
      inner.right,
      inner.bottom,
    );
  }

  void _bannerWords(Canvas canvas, Offset c, double s, Color ink, Color paper) {
    final band = _banner(c, s);
    final place = d.place.toUpperCase();
    final sub = [d.day, if (d.trip.isNotEmpty) d.trip].join(' · ');
    final round = d.shape == 'circle' || d.shape == 'oval';
    final title = _text(place, s * .058, paper, width: band.width * .8);
    final under = round
        ? null
        : _text(
            sub,
            s * .034,
            paper,
            w: FontWeight.w500,
            width: band.width * .9,
          );
    final h = title.height + (under?.height ?? 0);
    title.paint(canvas, Offset(c.dx - title.width / 2, band.center.dy - h / 2));
    under?.paint(
      canvas,
      Offset(c.dx - under.width / 2, band.center.dy - h / 2 + title.height),
    );
    title.dispose();
    under?.dispose();
    if (!round) return;
    if (d.shape == 'circle') {
      final radius = s * .395;
      _arc(canvas, d.day, c, radius, s * .05, ink, top: true);
      if (d.trip.isNotEmpty)
        _arc(canvas, d.trip, c, radius, s * .042, ink, top: false);
    } else {
      final t = _text(sub, s * .036, ink, w: FontWeight.w500, width: s * .6);
      t.paint(canvas, Offset(c.dx - t.width / 2, band.bottom + s * .03));
      t.dispose();
    }
  }

  /// Dots along [path] instead of a solid ring.
  void _dots(Canvas canvas, Path path, double s, Color ink) {
    final dot = Paint()..color = ink;
    final r = d.thin ? s * .006 : s * .01;
    for (final m in path.computeMetrics()) {
      final n = (m.length / (s * .028)).round();
      for (var i = 0; i < n; i++) {
        canvas.drawCircle(
          m.getTangentForOffset(m.length * i / n)!.position,
          r,
          dot,
        );
      }
    }
  }

  Path _star(Offset at, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5, rr = i.isEven ? r : r * .45;
      final q = at + Offset(rr * math.cos(a), rr * math.sin(a));
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  /// Where side marks (stars, dots) sit: the ends of the ring's middle on a
  /// round cut, the ends of the word band on the others.
  List<Offset> _sides(Offset c, double s) {
    if (d.shape == 'circle') {
      return [c + Offset(-s * .395, 0), c + Offset(s * .395, 0)];
    }
    if (d.shape == 'oval') {
      final w = _box(c, s, 0).width / 2 * .8;
      return [c + Offset(-w, 0), c + Offset(w, 0)];
    }
    final b = _banner(c, s);
    return [
      Offset(b.left + s * .05, b.center.dy),
      Offset(b.right - s * .05, b.center.dy),
    ];
  }

  void _decor(Canvas canvas, Offset c, double s, Color ink, Color paper) {
    final fill = Paint()..color = ink;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink
      ..strokeCap = StrokeCap.round;
    switch (d.decor) {
      case 'stars':
        for (final p in _sides(c, s)) {
          canvas.drawPath(_star(p, s * .028), fill);
        }
      case 'dots':
        for (final p in _sides(c, s)) {
          canvas.drawCircle(p, s * .014, fill);
        }
      case 'rays':
        // A sunburst between the cut and the main ring.
        final box = _box(c, s, 0);
        final rx = box.width / 2, ry = box.height / 2;
        stroke.strokeWidth = s * (d.thin ? .006 : .009);
        for (var i = 0; i < 48; i++) {
          final a = i * 2 * math.pi / 48;
          final ux = math.cos(a), uy = math.sin(a);
          canvas.drawLine(
            c + Offset(ux * (rx - s * .006), uy * (ry - s * .006)),
            c + Offset(ux * (rx - s * .03), uy * (ry - s * .03)),
            stroke,
          );
        }
      case 'postmark':
        // Cancellation waves running off the right of the stamp.
        // They start right of the words, so the place and day stay legible;
        // on a label they cross its upper half, above the word band.
        stroke.strokeWidth = s * (d.thin ? .008 : .012);
        final round = d.shape == 'circle' || d.shape == 'oval';
        final mid = round ? c.dy : c.dy - s * .16;
        final from = c.dx + s * (round ? .29 : .18);
        for (var k = -2; k <= 2; k++) {
          final y = mid + k * s * .05;
          final path = Path()..moveTo(from, y);
          for (var x = from; x <= c.dx + s * .5; x += s * .02) {
            path.lineTo(x, y + math.sin((x - c.dx) / (s * .04)) * s * .012);
          }
          canvas.drawPath(path, stroke);
        }
      case 'banner':
        canvas.drawRect(_banner(c, s), fill);
      case 'ticks':
        final r = _box(c, s, .06), l = s * .06;
        stroke.strokeWidth = s * (d.thin ? .008 : .014);
        for (final (corner, dx, dy) in [
          (r.topLeft, 1.0, 1.0),
          (r.topRight, -1.0, 1.0),
          (r.bottomLeft, 1.0, -1.0),
          (r.bottomRight, -1.0, -1.0),
        ]) {
          canvas.drawPath(
            Path()
              ..moveTo(corner.dx + dx * l, corner.dy)
              ..lineTo(corner.dx, corner.dy)
              ..lineTo(corner.dx, corner.dy + dy * l),
            stroke,
          );
        }
    }
  }

  void _centre(Canvas canvas, Offset c, double s, String text, Color ink) {
    final t = _text(text, s * .075, ink, width: s * .5);
    t.paint(canvas, c - Offset(t.width / 2, t.height / 2));
    t.dispose();
  }

  /// [text] set along the ring: over the top, or under the bottom reading
  /// left to right.
  void _arc(
    Canvas canvas,
    String text,
    Offset c,
    double radius,
    double size,
    Color ink, {
    required bool top,
  }) {
    final glyphs = [
      for (final ch in text.runes.map(String.fromCharCode))
        _text(ch, size, ink, w: top ? FontWeight.w700 : FontWeight.w500),
    ];
    final total = glyphs.fold<double>(0, (a, g) => a + g.width) / radius;
    final span = math.min(total, math.pi * .9);
    final squeeze = total == 0 ? 1.0 : span / total;
    var angle = top ? -math.pi / 2 - span / 2 : math.pi / 2 + span / 2;
    for (final g in glyphs) {
      final a = g.width * squeeze / radius;
      final mid = top ? angle + a / 2 : angle - a / 2;
      canvas.save();
      canvas.translate(
        c.dx + radius * math.cos(mid),
        c.dy + radius * math.sin(mid),
      );
      canvas.rotate(top ? mid + math.pi / 2 : mid - math.pi / 2);
      canvas.scale(squeeze, 1);
      g.paint(
        canvas,
        Offset(-g.width / 2, top ? -g.height / 2 : -g.height / 2),
      );
      canvas.restore();
      angle = top ? angle + a : angle - a;
      g.dispose();
    }
  }

  /// Specks where the ink did not take, the same each time for one visit.
  void _wear(Canvas canvas, Size size, double s) {
    if (d.wear <= 0) return;
    final random = math.Random(d.seed);
    final erase = Paint()..blendMode = BlendMode.dstOut;
    for (var i = 0; i < (d.wear * 420).round(); i++) {
      erase.color = Color.fromRGBO(0, 0, 0, .35 + random.nextDouble() * .65);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        s * (.002 + random.nextDouble() * .01),
        erase,
      );
    }
  }
}

/// The stamp as a transparent PNG, [side] pixels square.
Future<Uint8List> renderStampPng(StampDesign d, {int side = 1200}) async {
  final recorder = ui.PictureRecorder();
  StampPainter(d).paint(Canvas(recorder), Size.square(side.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

/// A printable A4 sheet of the stamp, twelve to a page, to cut out.
Future<Uint8List> stampSheetPdf(Uint8List png, String label) async {
  final font = pw.Font.ttf(
    await rootBundle.load(
      'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
    ),
  );
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font));
  final image = pw.MemoryImage(png);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
      build: (_) => pw.Column(
        children: [
          for (var row = 0; row < 4; row++)
            pw.Expanded(
              child: pw.Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(3 * PdfPageFormat.mm),
                        child: pw.Image(image, fit: pw.BoxFit.contain),
                      ),
                    ),
                ],
              ),
            ),
          pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
    ),
  );
  return doc.save();
}
