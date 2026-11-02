import 'dart:math' as math;

/// A rectangle in pixels of the image that was read, origin top-left.
class OcrBox {
  final double left, top, width, height;
  const OcrBox(this.left, this.top, this.width, this.height);

  double get right => left + width;
  double get bottom => top + height;
  double get centerY => top + height / 2;

  /// The smallest box holding all of [boxes].
  factory OcrBox.around(Iterable<OcrBox> boxes) {
    var l = double.infinity, t = double.infinity;
    var r = double.negativeInfinity, b = double.negativeInfinity;
    for (final x in boxes) {
      l = math.min(l, x.left);
      t = math.min(t, x.top);
      r = math.max(r, x.right);
      b = math.max(b, x.bottom);
    }
    if (l == double.infinity) return const OcrBox(0, 0, 0, 0);
    return OcrBox(l, t, r - l, b - t);
  }

  OcrBox scaled(double by) =>
      OcrBox(left * by, top * by, width * by, height * by);

  /// This box as fractions of an image [w] by [h] pixels.
  OcrBox fractionOf(int w, int h) =>
      OcrBox(left / w, top / h, width / w, height / h);

  static OcrBox? parse(Object? raw) {
    if (raw is! Map) return null;
    double? n(String k) {
      final v = raw[k];
      return v is num && v.isFinite ? v.toDouble() : null;
    }

    final x = n('x'), y = n('y'), w = n('w'), h = n('h');
    if (x == null || y == null || w == null || h == null || w < 0 || h < 0) {
      return null;
    }
    return OcrBox(x, y, w, h);
  }

  @override
  bool operator ==(Object other) =>
      other is OcrBox &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;
  @override
  int get hashCode => Object.hash(left, top, width, height);
  @override
  String toString() => 'OcrBox($left, $top, $width, $height)';
}

/// One recognised word and where it is.
class OcrWord {
  final String text;
  final OcrBox box;
  const OcrWord(this.text, this.box);
}

/// One recognised line: its words in reading order, and the box around them.
class OcrLine {
  final String text;
  final OcrBox box;
  final List<OcrWord> words;
  OcrLine(this.text, this.box, [List<OcrWord> words = const []])
    : words = List.unmodifiable(words);
}

/// What was read from one image. Boxes are in pixels of the image passed to
/// `recognizeText`, whatever size the engine itself worked at.
class OcrResult {
  final int width, height;
  final List<OcrLine> lines;

  /// 'mlkit-latin' (Android, iOS) or 'windows-ocr' (Windows).
  final String engine;

  /// The language the engine used, as a BCP-47 tag, when it says.
  final String? language;
  OcrResult({
    required this.width,
    required this.height,
    required List<OcrLine> lines,
    required this.engine,
    this.language,
  }) : lines = List.unmodifiable(readingOrder(lines));

  bool get isEmpty => lines.isEmpty;

  /// The lines as plain text: one line each, a blank line between blocks.
  String get text => layoutText(lines);

  /// Lines whose text contains [pattern], for finding things to hide.
  Iterable<OcrLine> where(Pattern pattern) =>
      lines.where((l) => l.text.contains(pattern));

  /// Reads the map a platform engine returns. Lines without text or a box
  /// are dropped; everything is scaled by [scale] back to the caller's image.
  factory OcrResult.fromMap(
    Map<Object?, Object?> raw, {
    required int width,
    required int height,
    required String engine,
    double scale = 1,
  }) {
    final lines = <OcrLine>[];
    final list = raw['lines'];
    if (list is List) {
      for (final l in list.take(5000)) {
        if (l is! Map) continue;
        final words = <OcrWord>[];
        final rawWords = l['words'];
        if (rawWords is List) {
          for (final w in rawWords.take(1000)) {
            if (w is! Map) continue;
            final text = _clean(w['text']);
            final box = OcrBox.parse(w['box']);
            if (text.isEmpty || box == null) continue;
            words.add(OcrWord(text, box.scaled(scale)));
          }
        }
        final text = _clean(l['text']);
        final box =
            OcrBox.parse(l['box'])?.scaled(scale) ??
            (words.isEmpty ? null : OcrBox.around(words.map((w) => w.box)));
        if (text.isEmpty || box == null) continue;
        lines.add(OcrLine(text, box, words));
      }
    }
    final language = raw['language'];
    return OcrResult(
      width: width,
      height: height,
      lines: lines,
      engine: engine,
      language: language is String && language.isNotEmpty ? language : null,
    );
  }
}

/// Engines return text, not control characters: anything else is dropped.
String _clean(Object? value) => value is String
    ? value
          .replaceAll(RegExp(r'[\x00-\x08\x0b-\x1f\x7f]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
    : '';

/// Lines top to bottom; lines sharing a row (their middles within half a
/// line height) left to right, so two columns of a form read across.
List<OcrLine> readingOrder(List<OcrLine> lines) {
  final sorted = [...lines]..sort((a, b) => a.box.top.compareTo(b.box.top));
  final rows = <List<OcrLine>>[];
  for (final line in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null) {
      final h = row.map((l) => l.box.height).reduce(math.max);
      final mid = row.first.box.centerY;
      if ((line.box.centerY - mid).abs() < math.max(h, line.box.height) / 2) {
        row.add(line);
        continue;
      }
    }
    rows.add([line]);
  }
  return [
    for (final row in rows)
      ...(row..sort((a, b) => a.box.left.compareTo(b.box.left))),
  ];
}

/// The text of lines already in reading order: a blank line where the gap
/// to the next row is wider than the line height, as between paragraphs.
String layoutText(List<OcrLine> lines) {
  if (lines.isEmpty) return '';
  final heights = lines.map((l) => l.box.height).toList()..sort();
  final typical = heights[heights.length ~/ 2];
  final out = StringBuffer(lines.first.text);
  for (var i = 1; i < lines.length; i++) {
    final previous = lines[i - 1], line = lines[i];
    final sameRow =
        (line.box.centerY - previous.box.centerY).abs() <
        math.max(line.box.height, previous.box.height) / 2;
    if (sameRow) {
      out.write('    ');
    } else {
      final gap = line.box.top - previous.box.bottom;
      out.write(gap > typical * 1.2 ? '\n\n' : '\n');
    }
    out.write(line.text);
  }
  return out.toString();
}
