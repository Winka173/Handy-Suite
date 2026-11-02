part of '../handy_card_engine.dart';

/// What the editor core needs to know about one kind of element. The
/// renderers (screen, SVG, PDF) keep their own registries keyed by [type],
/// so a new element is added by registering a spec and its painters, with
/// no change to selection, history, hit testing or serialization.
class ElementSpec {
  final String type, en, vi;

  /// Holds children (only groups in this build).
  final bool container;

  /// Resizing keeps the width:height ratio unless the person unlocks it.
  final bool keepsAspect;

  /// Size of a new element, in points.
  final double width, height;
  final Map<String, Object?> Function() defaults;

  /// Checks and clamps stored properties; throws on anything unsafe.
  final Map<String, Object?> Function(Map<String, Object?>) normalize;

  /// How the element answers a resize of its group: text grows with it.
  final Map<String, Object?> Function(Map<String, Object?> props, double scale)?
  scaleProps;
  const ElementSpec({
    required this.type,
    required this.en,
    required this.vi,
    this.container = false,
    this.keepsAspect = false,
    this.width = 120,
    this.height = 40,
    required this.defaults,
    required this.normalize,
    this.scaleProps,
  });
}

class ElementRegistry {
  final _specs = <String, ElementSpec>{};
  ElementRegistry();

  /// The built-in elements plus the badge extension.
  factory ElementRegistry.standard() {
    final r = ElementRegistry();
    for (final s in builtInElements) r.register(s);
    registerBadgeExtension(r);
    return r;
  }

  void register(ElementSpec spec) {
    if (_specs.containsKey(spec.type))
      throw StateError('Element type ${spec.type} is already registered');
    _specs[spec.type] = spec;
  }

  ElementSpec? lookup(String type) => _specs[type];
  ElementSpec spec(String type) =>
      _specs[type] ?? (throw StateError('Unknown element type $type'));
  bool knows(String type) => _specs.containsKey(type);
  Iterable<ElementSpec> get specs => _specs.values;

  /// A new element of [type] centred at [at].
  CardElement create(
    String type, {
    required Vec at,
    Map<String, Object?> props = const {},
    String? name,
    ElementBinding? binding,
  }) {
    final s = spec(type);
    return CardElement(
      id: newCardId(),
      type: type,
      name: name ?? '',
      frame: Frame(0, 0, s.width, s.height).centredAt(at),
      props: s.normalize({...s.defaults(), ...props}),
      binding: binding,
    );
  }
}

// Property checks shared by the built-in specs.
String? _optColor(Map<String, Object?> p, String key, String? fallback) =>
    p.containsKey(key) ? cardColor(p[key]) : fallback;
double _clamp(
  Map<String, Object?> p,
  String key,
  double min,
  double max,
  double fallback,
) {
  final v = p[key];
  if (v == null) return fallback;
  if (v is! num || !v.isFinite) throw FormatException('Invalid $key');
  return v.toDouble().clamp(min, max);
}

String _choice(
  Map<String, Object?> p,
  String key,
  Set<String> options,
  String fallback,
) {
  final v = p[key] ?? fallback;
  if (v is! String || !options.contains(v))
    throw FormatException('Invalid $key');
  return v;
}

/// Font families the renderers know. Each maps to a face bundled with the
/// app (open licences only); exporters say when one had to be substituted.
const cardFonts = {'sans', 'serif', 'display', 'mono'};

Map<String, Object?> _textStyle(Map<String, Object?> p) => {
  'font': _choice(p, 'font', cardFonts, 'sans'),
  'size': _clamp(p, 'size', 2, 400, 12),
  'weight': _clamp(p, 'weight', 100, 900, 400).roundToDouble(),
  'italic': p['italic'] == true,
  'color': _optColor(p, 'color', '111111'),
  'align': _choice(p, 'align', const {'left', 'center', 'right'}, 'left'),
  'lineHeight': _clamp(p, 'lineHeight', 0.8, 3, 1.25),
  'letterSpacing': _clamp(p, 'letterSpacing', -5, 50, 0),
  'upper': p['upper'] == true,
  'overflow': _choice(p, 'overflow', const {
    'clip',
    'shrink',
    'visible',
  }, 'shrink'),
};

Map<String, Object?> _scaleText(Map<String, Object?> p, double k) => {
  ...p,
  'size': ((p['size'] as num? ?? 12) * k).clamp(2, 400).toDouble(),
};

Map<String, Object?> _paint(
  Map<String, Object?> p, {
  String? fill = 'E8EAEE',
}) => {
  'fill': _optColor(p, 'fill', fill),
  'fill2': _optColor(p, 'fill2', null),
  'angle': _clamp(p, 'angle', -360, 360, 90),
  'stroke': _optColor(p, 'stroke', null),
  'strokeWidth': _clamp(p, 'strokeWidth', 0, 200, 1),
};

final builtInElements = <ElementSpec>[
  ElementSpec(
    type: 'text',
    en: 'Text',
    vi: 'Chữ',
    width: 160,
    height: 28,
    defaults: () => {'text': 'Text'},
    normalize: (p) => {'text': _text(p['text'] ?? ''), ..._textStyle(p)},
    scaleProps: _scaleText,
  ),
  ElementSpec(
    type: 'contact',
    en: 'Contact field',
    vi: 'Trường liên hệ',
    width: 160,
    height: 18,
    defaults: () => {'size': 9, 'prefix': ''},
    normalize: (p) => {
      'prefix': _text(p['prefix'] ?? '', max: 40),
      // What shows while the field has no value in the profile.
      'text': _text(p['text'] ?? '', max: 500),
      ..._textStyle(p),
    },
    scaleProps: _scaleText,
  ),
  ElementSpec(
    type: 'rect',
    en: 'Rectangle',
    vi: 'Hình chữ nhật',
    width: 80,
    height: 50,
    defaults: () => {},
    normalize: (p) => {..._paint(p), 'radius': _clamp(p, 'radius', 0, 1000, 0)},
  ),
  ElementSpec(
    type: 'ellipse',
    en: 'Ellipse',
    vi: 'Hình elip',
    width: 60,
    height: 60,
    defaults: () => {},
    normalize: (p) => _paint(p),
  ),
  ElementSpec(
    type: 'line',
    en: 'Line',
    vi: 'Đường kẻ',
    width: 100,
    height: 4,
    defaults: () => {'stroke': '111111', 'strokeWidth': 1},
    normalize: (p) => {
      'stroke': _optColor(p, 'stroke', '111111'),
      'strokeWidth': _clamp(p, 'strokeWidth', 0.1, 200, 1),
      'dash': _clamp(p, 'dash', 0, 100, 0),
    },
  ),
  ElementSpec(
    type: 'polygon',
    en: 'Polygon',
    vi: 'Đa giác',
    width: 60,
    height: 60,
    keepsAspect: true,
    defaults: () => {'sides': 6},
    normalize: (p) => {
      ..._paint(p),
      'sides': _clamp(p, 'sides', 3, 24, 6).roundToDouble(),
      'star': p['star'] == true,
      'inner': _clamp(p, 'inner', 0.1, 0.95, 0.5),
    },
  ),
  ElementSpec(
    type: 'image',
    en: 'Picture',
    vi: 'Ảnh',
    width: 80,
    height: 80,
    keepsAspect: true,
    defaults: () => {},
    normalize: (p) {
      final asset = p['asset'];
      if (asset != null &&
          (asset is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(asset)))
        throw const FormatException('Invalid picture reference');
      return {
        'asset': asset,
        'fit': _choice(p, 'fit', const {'cover', 'contain', 'fill'}, 'cover'),
        'mask': _choice(p, 'mask', const {
          'none',
          'ellipse',
          'rounded',
        }, 'none'),
        'radius': _clamp(p, 'radius', 0, 1000, 8),
        // The visible part of the picture, as fractions of its size.
        'cropX': _clamp(p, 'cropX', 0, 1, 0),
        'cropY': _clamp(p, 'cropY', 0, 1, 0),
        'cropW': _clamp(p, 'cropW', 0.01, 1, 1),
        'cropH': _clamp(p, 'cropH', 0.01, 1, 1),
      };
    },
  ),
  ElementSpec(
    type: 'icon',
    en: 'Icon',
    vi: 'Biểu tượng',
    width: 14,
    height: 14,
    keepsAspect: true,
    defaults: () => {'glyph': 'phone'},
    normalize: (p) => {
      'glyph': _choice(p, 'glyph', cardIcons.keys.toSet(), 'phone'),
      'color': _optColor(p, 'color', '111111'),
    },
  ),
  ElementSpec(
    type: 'qr',
    en: 'QR code',
    vi: 'Mã QR',
    width: 64,
    height: 64,
    keepsAspect: true,
    defaults: () => {'payload': 'https://example.com'},
    normalize: (p) => {
      'payload': _text(p['payload'] ?? '', max: 2900),
      'ecc': _choice(p, 'ecc', const {'L', 'M', 'Q', 'H'}, 'M'),
      'color': _optColor(p, 'color', '000000'),
      'background': _optColor(p, 'background', 'FFFFFF'),
      'quiet': _clamp(p, 'quiet', 0, 8, 4).roundToDouble(),
    },
  ),
  ElementSpec(
    type: 'group',
    en: 'Group',
    vi: 'Nhóm',
    container: true,
    defaults: () => {},
    normalize: (p) => const {},
  ),
];
