part of '../handy_card_engine.dart';

/// A point or a direction in document units (points, 1/72 inch).
class Vec {
  final double x, y;
  const Vec(this.x, this.y);
  static const zero = Vec(0, 0);
  Vec operator +(Vec o) => Vec(x + o.x, y + o.y);
  Vec operator -(Vec o) => Vec(x - o.x, y - o.y);
  Vec operator *(double k) => Vec(x * k, y * k);
  double get length => math.sqrt(x * x + y * y);
  @override
  bool operator ==(Object o) => o is Vec && o.x == x && o.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => 'Vec($x, $y)';
}

/// x' = a·x + c·y + e, y' = b·x + d·y + f — the same layout as SVG's
/// `matrix(a b c d e f)`, so the exporters write it as it is.
class Affine {
  final double a, b, c, d, e, f;
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);
  static const identity = Affine(1, 0, 0, 1, 0, 0);
  factory Affine.translate(double x, double y) => Affine(1, 0, 0, 1, x, y);
  factory Affine.rotate(double radians) {
    final cs = math.cos(radians), sn = math.sin(radians);
    return Affine(cs, sn, -sn, cs, 0, 0);
  }
  factory Affine.scale(double sx, [double? sy]) =>
      Affine(sx, 0, 0, sy ?? sx, 0, 0);

  /// This after [o]: `(this * o).apply(p) == this.apply(o.apply(p))`.
  Affine operator *(Affine o) => Affine(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.e + c * o.f + e,
    b * o.e + d * o.f + f,
  );
  Vec apply(Vec p) => Vec(a * p.x + c * p.y + e, b * p.x + d * p.y + f);

  /// Applies only the linear part (for directions and drag deltas).
  Vec applyVector(Vec v) => Vec(a * v.x + c * v.y, b * v.x + d * v.y);
  double get determinant => a * d - b * c;
  Affine inverse() {
    final det = determinant;
    if (det.abs() < 1e-12) throw StateError('Singular transform');
    return Affine(
      d / det,
      -b / det,
      -c / det,
      a / det,
      (c * f - d * e) / det,
      (b * e - a * f) / det,
    );
  }

  List<double> get values => [a, b, c, d, e, f];
}

/// An axis-aligned box.
class Box {
  final double x, y, width, height;
  const Box(this.x, this.y, this.width, this.height);
  factory Box.fromPoints(Iterable<Vec> points) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in points) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    return Box(minX, minY, maxX - minX, maxY - minY);
  }
  double get right => x + width;
  double get bottom => y + height;
  Vec get center => Vec(x + width / 2, y + height / 2);
  bool contains(Vec p) => p.x >= x && p.x <= right && p.y >= y && p.y <= bottom;
  bool overlaps(Box o) =>
      x <= o.right && o.x <= right && y <= o.bottom && o.y <= bottom;
  Box union(Box o) => Box.fromPoints([
    Vec(x, y),
    Vec(right, bottom),
    Vec(o.x, o.y),
    Vec(o.right, o.bottom),
  ]);
  Box inflate(double by) =>
      Box(x - by, y - by, width + 2 * by, height + 2 * by);
  @override
  String toString() => 'Box($x, $y, $width, $height)';
}

/// Rounds to a thousandth of a point, so repeated edits cannot drift.
double snapValue(double v) => (v * 1000).roundToDouble() / 1000;

/// Where an element sits in its parent: its unrotated box, turned
/// [rotation] degrees clockwise about the box centre.
class Frame {
  final double x, y, width, height, rotation;
  const Frame(this.x, this.y, this.width, this.height, [this.rotation = 0]);

  factory Frame.fromJson(Object? raw) {
    final j = _map(raw, 'frame');
    final f = Frame(
      _num(j['x']),
      _num(j['y']),
      _num(j['w']),
      _num(j['h']),
      _num(j['r'] ?? 0),
    );
    if (f.width < 0 || f.height < 0 || f.width > 100000 || f.height > 100000)
      throw const FormatException('Invalid element size');
    return f;
  }
  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'w': width,
    'h': height,
    if (rotation != 0) 'r': rotation,
  };

  Vec get center => Vec(x + width / 2, y + height / 2);

  /// Local (0..width, 0..height) to parent coordinates.
  Affine get matrix =>
      Affine.translate(x + width / 2, y + height / 2) *
      Affine.rotate(rotation * math.pi / 180) *
      Affine.translate(-width / 2, -height / 2);

  List<Vec> corners([Affine parent = Affine.identity]) {
    final m = parent * matrix;
    return [
      m.apply(Vec.zero),
      m.apply(Vec(width, 0)),
      m.apply(Vec(width, height)),
      m.apply(Vec(0, height)),
    ];
  }

  Box bounds([Affine parent = Affine.identity]) =>
      Box.fromPoints(corners(parent));

  Frame copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
  }) => Frame(
    snapValue(x ?? this.x),
    snapValue(y ?? this.y),
    snapValue(math.max(0, width ?? this.width)),
    snapValue(math.max(0, height ?? this.height)),
    normalizeAngle(rotation ?? this.rotation),
  );

  Frame moved(Vec by) => copyWith(x: x + by.x, y: y + by.y);

  /// The same box placed so its centre is [c].
  Frame centredAt(Vec c) => copyWith(x: c.x - width / 2, y: c.y - height / 2);

  @override
  bool operator ==(Object o) =>
      o is Frame &&
      o.x == x &&
      o.y == y &&
      o.width == width &&
      o.height == height &&
      o.rotation == rotation;
  @override
  int get hashCode => Object.hash(x, y, width, height, rotation);
  @override
  String toString() => 'Frame($x, $y, $width, $height, $rotation°)';
}

/// An angle in degrees folded into (-180, 180], rounded to a thousandth.
double normalizeAngle(double degrees) {
  var a = degrees % 360;
  if (a > 180) a -= 360;
  if (a <= -180) a += 360;
  return snapValue(a);
}

const pointsPerMm = 72 / 25.4;
const pointsPerInch = 72.0;

/// A length in [unit] (mm, in, pt, or px at [dpi]) as points.
double toPoints(double value, String unit, {double dpi = 72}) => switch (unit) {
  'mm' => value * pointsPerMm,
  'in' => value * pointsPerInch,
  'px' => value * 72 / dpi,
  _ => value,
};

/// Points as a length in [unit].
double fromPoints(double points, String unit, {double dpi = 72}) =>
    switch (unit) {
      'mm' => points / pointsPerMm,
      'in' => points / pointsPerInch,
      'px' => points * dpi / 72,
      _ => points,
    };

Map<String, Object?> _map(Object? raw, String what) {
  if (raw is! Map) throw FormatException('Invalid $what');
  return {for (final e in raw.entries) '${e.key}': e.value};
}

double _num(Object? v, {double min = -1e6, double max = 1e6}) {
  if (v is! num || !v.isFinite || v < min || v > max)
    throw const FormatException('Invalid number');
  return v.toDouble();
}
