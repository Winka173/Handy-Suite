part of '../handy_card_engine.dart';

/// A ready size: its name, the unit it is usually given in, and its size
/// in that unit (landscape where it has an orientation).
class CardSize {
  final String id, en, vi, unit;
  final double width, height;

  /// Suggested bleed and safe margin, in millimetres (0 for screen sizes).
  final double bleedMm, safeMm;
  final bool print;
  const CardSize(
    this.id,
    this.en,
    this.vi,
    this.unit,
    this.width,
    this.height, {
    this.bleedMm = 3,
    this.safeMm = 3,
    this.print = true,
  });
  double get widthPt => toPoints(width, unit, dpi: 72);
  double get heightPt => toPoints(height, unit, dpi: 72);
}

const cardSizes = [
  CardSize(
    'vn',
    'Business card 90 × 54 mm (Vietnam)',
    'Danh thiếp 90 × 54 mm (Việt Nam)',
    'mm',
    90,
    54,
  ),
  CardSize(
    'iso',
    'Business card 85 × 55 mm (Europe)',
    'Danh thiếp 85 × 55 mm (châu Âu)',
    'mm',
    85,
    55,
  ),
  CardSize(
    'us',
    'Business card 3.5 × 2 in (US)',
    'Danh thiếp 3.5 × 2 in (Mỹ)',
    'in',
    3.5,
    2,
  ),
  CardSize(
    'jp',
    'Business card 91 × 55 mm (Japan)',
    'Danh thiếp 91 × 55 mm (Nhật)',
    'mm',
    91,
    55,
  ),
  CardSize(
    'cr80',
    'ID card 85.6 × 54 mm (CR80)',
    'Thẻ 85,6 × 54 mm (CR80)',
    'mm',
    85.6,
    53.98,
    bleedMm: 2,
    safeMm: 3,
  ),
  CardSize(
    'badge',
    'Event badge 102 × 76 mm',
    'Thẻ sự kiện 102 × 76 mm',
    'mm',
    102,
    76,
  ),
  CardSize(
    'square',
    'Square post 1080 × 1080 px',
    'Bài vuông 1080 × 1080 px',
    'px',
    1080,
    1080,
    bleedMm: 0,
    safeMm: 0,
    print: false,
  ),
  CardSize(
    'portrait',
    'Portrait post 1080 × 1350 px',
    'Bài dọc 1080 × 1350 px',
    'px',
    1080,
    1350,
    bleedMm: 0,
    safeMm: 0,
    print: false,
  ),
];

/// A new blank design of [size]: [sides] sides named Front and Back.
/// Pixel sizes are kept in points at 72 dpi (1 px = 1 pt), so a 1080 px
/// post is 1080 points wide and exports at its own pixel size at 72 dpi.
CardDocument blankDocument({
  required CardSize size,
  bool portrait = false,
  int sides = 2,
  String kind = 'business',
  String name = '',
  required DateTime at,
}) {
  var w = size.widthPt, h = size.heightPt;
  if (portrait && w > h || !portrait && h > w && size.print) {
    final t = w;
    w = h;
    h = t;
  }
  final stamp = at.toUtc().toIso8601String();
  return CardDocument(
    id: newCardId(),
    name: name,
    kind: kind,
    unit: size.unit,
    width: snapValue(w),
    height: snapValue(h),
    bleed: snapValue(size.bleedMm * pointsPerMm),
    safe: snapValue(size.safeMm * pointsPerMm),
    pages: [
      CardPage(id: newCardId(), name: 'Front'),
      if (sides > 1) CardPage(id: newCardId(), name: 'Back'),
    ],
    createdAt: stamp,
    updatedAt: stamp,
  );
}
