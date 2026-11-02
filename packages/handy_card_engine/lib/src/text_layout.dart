part of '../handy_card_engine.dart';

/// Measures text in a face. The app measures with the real fonts; the
/// screen, SVG and PDF renderers all place lines from the same layout, so
/// line breaks agree across formats.
abstract interface class TextMeasurer {
  /// Advance width of [text] at [size] points in the element's face.
  double width(String text, CardElement style, double size);

  /// Distance from the line top to the baseline, at [size].
  double ascent(CardElement style, double size);
}

/// A rough measurer (half an em per character) for tests and fallbacks.
class ApproximateMeasurer implements TextMeasurer {
  const ApproximateMeasurer();
  @override
  double width(String text, CardElement style, double size) =>
      text.runes.length * size * 0.5 +
      math.max(0, text.runes.length - 1) *
          style.prop<double>('letterSpacing', 0);
  @override
  double ascent(CardElement style, double size) => size * 0.8;
}

class TextLine {
  final String text;

  /// Offset of the line start from the box's left, and of the baseline
  /// from the box's top.
  final double x, baseline, width;
  const TextLine(this.text, this.x, this.baseline, this.width);
}

class TextLayout {
  final List<TextLine> lines;

  /// The size used, after shrinking to fit when the element asks for it.
  final double size;

  /// Text did not fit the box even at the smallest size (or was clipped).
  final bool overflow;
  const TextLayout(this.lines, this.size, this.overflow);
}

/// [text] wrapped into the element's box: words break at spaces, a word
/// longer than the line breaks between characters, `\n` starts a line.
/// With overflow `shrink` the size steps down until it fits.
TextLayout layoutText(CardElement e, String text, TextMeasurer m) {
  final w = e.frame.width, h = e.frame.height;
  final base = e.prop<double>('size', 12);
  final mode = e.prop<String>('overflow', 'shrink');
  final lh = e.prop<double>('lineHeight', 1.25);
  var size = base;
  while (true) {
    final lines = _wrap(text, w, size, e, m);
    final height = lines.length * size * lh;
    final tooWide = lines.any((l) => m.width(l, e, size) > w + 0.01);
    final fits = height <= h + 0.01 && !tooWide;
    if (fits || mode != 'shrink' || size <= 4) {
      final align = e.prop<String>('align', 'left');
      final out = <TextLine>[];
      for (var i = 0; i < lines.length; i++) {
        final lw = m.width(lines[i], e, size);
        final x = switch (align) {
          'center' => (w - lw) / 2,
          'right' => w - lw,
          _ => 0.0,
        };
        // Lines sit centred in their line box, as the screen draws them.
        final top = i * size * lh + (size * lh - size) / 2;
        out.add(TextLine(lines[i], x, top + m.ascent(e, size), lw));
      }
      final visible = mode == 'clip'
          ? out.where((l) => l.baseline <= h + size * 0.25).toList()
          : out;
      return TextLayout(visible, size, !fits);
    }
    size = math.max(4, size * 0.94);
  }
}

List<String> _wrap(
  String text,
  double width,
  double size,
  CardElement e,
  TextMeasurer m,
) {
  final out = <String>[];
  for (final paragraph in text.split('\n')) {
    var line = '';
    for (final word in paragraph.split(' ')) {
      final candidate = line.isEmpty ? word : '$line $word';
      if (m.width(candidate, e, size) <= width ||
          line.isEmpty && m.width(word, e, size) <= width) {
        line = candidate;
        continue;
      }
      if (line.isNotEmpty) out.add(line);
      // A word wider than the line breaks between characters.
      if (m.width(word, e, size) > width) {
        var part = '';
        for (final ch in word.runes.map(String.fromCharCode)) {
          if (part.isNotEmpty && m.width(part + ch, e, size) > width) {
            out.add(part);
            part = ch;
          } else {
            part += ch;
          }
        }
        line = part;
      } else {
        line = word;
      }
    }
    out.add(line);
  }
  return out;
}
