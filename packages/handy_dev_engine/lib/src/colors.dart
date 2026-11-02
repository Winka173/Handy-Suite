import 'dart:math' as math;

/// Colour checks moved from Handy Tools on 2026-11-03: they serve people
/// building interfaces, who work in Dev.
List<int> _rgb(String hex) {
  if (!RegExp(r'^#[a-f\d]{6}$', caseSensitive: false).hasMatch(hex))
    throw const FormatException('Use #RRGGBB');
  return [
    1,
    3,
    5,
  ].map((at) => int.parse(hex.substring(at, at + 2), radix: 16)).toList();
}

double contrast(String a, String b) {
  double luminance(String hex) {
    final rgb = _rgb(hex)
        .map((n) => n / 255)
        .map(
          (n) => n <= 0.04045
              ? n / 12.92
              : math.pow((n + 0.055) / 1.055, 2.4).toDouble(),
        )
        .toList();
    return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722;
  }

  final left = luminance(a), right = luminance(b);
  return (math.max(left, right) + 0.05) / (math.min(left, right) + 0.05);
}

double _two(double n) => double.parse(n.toStringAsFixed(2));
Map<String, Object> colors(String hex) {
  final rgb = _rgb(hex),
      r = rgb[0] / 255,
      g = rgb[1] / 255,
      b = rgb[2] / 255,
      max = math.max(r, math.max(g, b)),
      min = math.min(r, math.min(g, b)),
      delta = max - min,
      light = (max + min) / 2;
  var hue = delta == 0
      ? 0.0
      : max == r
      ? ((g - b) / delta) % 6
      : max == g
      ? (b - r) / delta + 2
      : (r - g) / delta + 4;
  hue = (hue * 60 + 360) % 360;
  return {
    'hex': hex.toUpperCase(),
    'rgb': {'r': rgb[0], 'g': rgb[1], 'b': rgb[2]},
    'hsl': {
      'h': _two(hue),
      's': _two(delta == 0 ? 0 : delta / (1 - (2 * light - 1).abs()) * 100),
      'l': _two(light * 100),
    },
  };
}

/// WCAG 2.x verdicts for a text colour on a background.
Map<String, Object> contrastReport(String foreground, String background) {
  final ratio = contrast(foreground, background);
  return {
    'ratio': double.parse(ratio.toStringAsFixed(2)),
    'normalTextAA': ratio >= 4.5,
    'largeTextAA': ratio >= 3,
    'normalTextAAA': ratio >= 7,
  };
}
