part of '../handy_card_engine.dart';

/// One step of a vector outline. All renderers draw from this list, so a
/// shape has one definition on screen, in SVG and in PDF.
sealed class PathOp {
  const PathOp();
}

class MoveTo extends PathOp {
  final Vec p;
  const MoveTo(this.p);
}

class LineTo extends PathOp {
  final Vec p;
  const LineTo(this.p);
}

class CubicTo extends PathOp {
  final Vec c1, c2, p;
  const CubicTo(this.c1, this.c2, this.p);
}

class ClosePath extends PathOp {
  const ClosePath();
}

/// The points of a regular polygon or star filling [w]×[h].
List<Vec> polygonPoints(
  double w,
  double h,
  int sides, {
  bool star = false,
  double inner = 0.5,
}) {
  final n = star ? sides * 2 : sides;
  return [
    for (var i = 0; i < n; i++)
      () {
        final a = -math.pi / 2 + i * 2 * math.pi / n;
        final r = star && i.isOdd ? inner : 1.0;
        return Vec(
          w / 2 + math.cos(a) * r * w / 2,
          h / 2 + math.sin(a) * r * h / 2,
        );
      }(),
  ];
}

List<PathOp> polygonPath(List<Vec> points) => [
  MoveTo(points.first),
  for (final p in points.skip(1)) LineTo(p),
  const ClosePath(),
];

/// An ellipse as four cubic curves (the usual 0.5523 handle length).
List<PathOp> ellipsePath(double w, double h) {
  const k = 0.5522847498;
  final rx = w / 2, ry = h / 2, cx = rx, cy = ry;
  return [
    MoveTo(Vec(cx + rx, cy)),
    CubicTo(
      Vec(cx + rx, cy + ry * k),
      Vec(cx + rx * k, cy + ry),
      Vec(cx, cy + ry),
    ),
    CubicTo(
      Vec(cx - rx * k, cy + ry),
      Vec(cx - rx, cy + ry * k),
      Vec(cx - rx, cy),
    ),
    CubicTo(
      Vec(cx - rx, cy - ry * k),
      Vec(cx - rx * k, cy - ry),
      Vec(cx, cy - ry),
    ),
    CubicTo(
      Vec(cx + rx * k, cy - ry),
      Vec(cx + rx, cy - ry * k),
      Vec(cx + rx, cy),
    ),
    const ClosePath(),
  ];
}

/// A rectangle with corners of radius [r] (clamped to half the short side).
List<PathOp> roundedRectPath(double w, double h, double r) {
  r = math.min(r, math.min(w, h) / 2);
  if (r <= 0) {
    return [
      const MoveTo(Vec.zero),
      LineTo(Vec(w, 0)),
      LineTo(Vec(w, h)),
      LineTo(Vec(0, h)),
      const ClosePath(),
    ];
  }
  const k = 0.5522847498;
  final c = r * (1 - k);
  return [
    MoveTo(Vec(r, 0)),
    LineTo(Vec(w - r, 0)),
    CubicTo(Vec(w - c, 0), Vec(w, c), Vec(w, r)),
    LineTo(Vec(w, h - r)),
    CubicTo(Vec(w, h - c), Vec(w - c, h), Vec(w - r, h)),
    LineTo(Vec(r, h)),
    CubicTo(Vec(c, h), Vec(0, h - c), Vec(0, h - r)),
    LineTo(Vec(0, r)),
    CubicTo(Vec(0, c), Vec(c, 0), Vec(r, 0)),
    const ClosePath(),
  ];
}

/// Path data in a 24×24 box, absolute M/L/C/Z only, scaled to [w]×[h].
List<PathOp> parseIconPath(String data, double w, double h) {
  final tokens = RegExp(
    r'[MLCZ]|-?\d*\.?\d+',
  ).allMatches(data).map((m) => m[0]!).toList();
  final sx = w / 24, sy = h / 24;
  final ops = <PathOp>[];
  var i = 0;
  Vec next() {
    final p = Vec(
      double.parse(tokens[i]) * sx,
      double.parse(tokens[i + 1]) * sy,
    );
    i += 2;
    return p;
  }

  String cmd = 'M';
  while (i < tokens.length) {
    if (RegExp(r'^[MLCZ]$').hasMatch(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        ops.add(MoveTo(next()));
        cmd = 'L';
      case 'L':
        ops.add(LineTo(next()));
      case 'C':
        ops.add(CubicTo(next(), next(), next()));
      case 'Z':
        ops.add(const ClosePath());
      default:
        throw const FormatException('Unsupported icon path');
    }
  }
  return ops;
}

/// Small contact icons drawn for Handy Card (original geometry, free to
/// ship), in a 24×24 box.
const cardIcons = {
  'phone':
      'M6 2 L10 2 L11 7 L8.5 8.5 C9.8 11.3 12.7 14.2 15.5 15.5 L17 13 L22 14 L22 18 C22 20 20 22 18 22 C9.2 22 2 14.8 2 6 C2 4 4 2 6 2 Z',
  'mail':
      'M2 5 L22 5 L22 19 L2 19 Z M3.5 6.5 L12 13 L20.5 6.5 L20.5 7.8 L12 14.6 L3.5 7.8 Z',
  'web':
      'M12 2 C17.5 2 22 6.5 22 12 C22 17.5 17.5 22 12 22 C6.5 22 2 17.5 2 12 C2 6.5 6.5 2 12 2 Z M4 11 L20 11 L20 13 L4 13 Z M11 4 C8.5 7 8.5 17 11 20 L13 20 C15.5 17 15.5 7 13 4 Z',
  'pin':
      'M12 2 C16 2 19 5 19 9 C19 14 12 22 12 22 C12 22 5 14 5 9 C5 5 8 2 12 2 Z M12 6 C10.3 6 9 7.3 9 9 C9 10.7 10.3 12 12 12 C13.7 12 15 10.7 15 9 C15 7.3 13.7 6 12 6 Z',
  'person':
      'M12 2 C14.8 2 17 4.2 17 7 C17 9.8 14.8 12 12 12 C9.2 12 7 9.8 7 7 C7 4.2 9.2 2 12 2 Z M3 22 C3 17 7 14 12 14 C17 14 21 17 21 22 Z',
  'star':
      'M12 2 L15 9 L22 9.3 L16.5 14 L18.5 21 L12 17 L5.5 21 L7.5 14 L2 9.3 L9 9 Z',
  'calendar':
      'M3 5 L21 5 L21 21 L3 21 Z M5 10 L19 10 L19 19 L5 19 Z M7 2 L9 2 L9 7 L7 7 Z M15 2 L17 2 L17 7 L15 7 Z',
  'link':
      'M9 15 L15 9 L16.5 10.5 L10.5 16.5 Z M6 13 L9 10 L10.5 11.5 L7.5 14.5 C6.5 15.5 6.5 17 7.5 18 C8.5 19 10 19 11 18 L14 15 L15.5 16.5 L12.5 19.5 C10.6 21.4 7.5 21.4 5.6 19.5 C3.7 17.6 3.7 14.5 6 13 Z M18 11 L15 14 L13.5 12.5 L16.5 9.5 C17.5 8.5 17.5 7 16.5 6 C15.5 5 14 5 13 6 L10 9 L8.5 7.5 L11.5 4.5 C13.4 2.6 16.5 2.6 18.4 4.5 C20.3 6.4 20.3 9.5 18 11 Z',
};
