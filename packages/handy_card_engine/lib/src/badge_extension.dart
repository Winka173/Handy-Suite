part of '../handy_card_engine.dart';

// The worked example of extending the editor (docs/HANDY_CARD_EXTENSION_GUIDE.md):
// a "badge" seal added only through the registries — a spec for the core,
// and a writer for each exporter. Selection, resizing, rotation, layers,
// undo and saving handle it with no change, and the app adds its screen
// painter and inspector the same way.

/// The badge's outline: a 16-point seal.
List<PathOp> badgeOutline(double w, double h) =>
    polygonPath(polygonPoints(w, h, 16, star: true, inner: 0.86));

/// The badge's label as a text element in the badge's own space, so every
/// renderer sets it with its ordinary text writer.
CardElement badgeLabel(CardElement badge) => CardElement(
  id: '${badge.id}-label',
  type: 'text',
  frame: Frame(
    badge.frame.width * 0.12,
    badge.frame.height * 0.3,
    badge.frame.width * 0.76,
    badge.frame.height * 0.4,
  ),
  props: {
    ..._textStyle({
      'size': badge.prop<double>('size', 7),
      'weight': 700,
      'color': badge.prop<String>('ink', 'FFFFFF'),
      'align': 'center',
    }),
    'text': badge.prop<String>('label', 'NEW'),
  },
);

void registerBadgeExtension(ElementRegistry registry) {
  registry.register(
    ElementSpec(
      type: 'badge',
      en: 'Badge',
      vi: 'Huy hiệu',
      width: 56,
      height: 56,
      keepsAspect: true,
      defaults: () => {
        'label': 'NEW',
        'fill': 'C2410C',
        'ink': 'FFFFFF',
        'size': 7,
      },
      normalize: (p) => {
        'label': _text(p['label'] ?? '', max: 24),
        'fill': _optColor(p, 'fill', 'C2410C'),
        'ink': _optColor(p, 'ink', 'FFFFFF'),
        'size': _clamp(p, 'size', 3, 60, 7),
      },
      scaleProps: (p, k) => {
        ...p,
        'size': ((p['size'] as num? ?? 7) * k).clamp(3, 60).toDouble(),
      },
    ),
  );
  svgWriters['badge'] = (o, e, ctx) {
    final fill = e.prop<String?>('fill', 'C2410C');
    if (fill != null)
      o.write(
        '<path d="${pathData(badgeOutline(e.frame.width, e.frame.height))}" fill="${_hex(fill)}"/>',
      );
    _svgElement(o, badgeLabel(e), ctx);
  };
  pdfWriters['badge'] = (c, e, a) {
    final fill = e.prop<String?>('fill', 'C2410C');
    if (fill != null)
      _fillOps(c, badgeOutline(e.frame.width, e.frame.height), fill, a);
    _pdfElement(c, badgeLabel(e), a);
  };
}
