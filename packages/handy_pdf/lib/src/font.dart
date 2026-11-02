import 'dart:typed_data';

/// A TrueType font to embed in a PDF, with the characters it can draw.
///
/// Text written with it is checked against its own character map first, so a
/// letter the font lacks is refused instead of printed as an empty box.
class PdfFont {
  final Uint8List bytes;
  final Set<int> codepoints;
  PdfFont._(this.bytes, this.codepoints);

  /// Reads the font's character map (cmap formats 4 and 12). Throws a
  /// [FormatException] for anything that is not a TrueType-outline font.
  factory PdfFont(Uint8List bytes) {
    if (bytes.length < 12 || bytes.length > 4000000) {
      throw const FormatException('Font must be a TrueType file up to 4 MB');
    }
    final copy = Uint8List.fromList(bytes);
    return PdfFont._(copy, Set.unmodifiable(_codepoints(copy)));
  }

  bool covers(String text) => text.runes.every(codepoints.contains);
}

Set<int> _codepoints(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  int u16(int o) => data.getUint16(o);
  int u32(int o) => data.getUint32(o);
  void need(int end) {
    if (end > bytes.length) throw const FormatException('Damaged font file');
  }

  final version = u32(0);
  if (version != 0x00010000 && version != 0x74727565) {
    throw const FormatException('Only TrueType-outline fonts can be embedded');
  }
  final tables = u16(4);
  need(12 + tables * 16);
  int? cmap;
  var glyf = false;
  for (var i = 0; i < tables; i++) {
    final at = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(at, at + 4));
    if (tag == 'cmap') cmap = u32(at + 8);
    if (tag == 'glyf') glyf = true;
  }
  if (cmap == null || !glyf) {
    throw const FormatException('Only TrueType-outline fonts can be embedded');
  }
  need(cmap + 4);
  final subtables = u16(cmap + 2);
  need(cmap + 4 + subtables * 8);
  int? best, bestFormat;
  for (var i = 0; i < subtables; i++) {
    final at = cmap + 4 + i * 8;
    final platform = u16(at), encoding = u16(at + 2);
    final offset = cmap + u32(at + 4);
    need(offset + 2);
    final format = u16(offset);
    final unicode =
        platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
    if (!unicode || (format != 4 && format != 12)) continue;
    if (bestFormat != 12) {
      best = offset;
      bestFormat = format;
    }
  }
  if (best == null) throw const FormatException('Font has no Unicode map');
  final out = <int>{};
  if (bestFormat == 12) {
    need(best + 16);
    final groups = u32(best + 12);
    need(best + 16 + groups * 12);
    for (var g = 0; g < groups; g++) {
      final at = best + 16 + g * 12;
      final start = u32(at), end = u32(at + 4), glyph = u32(at + 8);
      if (end < start || end - start > 0x10ffff) continue;
      for (var c = start; c <= end; c++) {
        if (glyph + c - start != 0) out.add(c);
      }
    }
    return out;
  }
  need(best + 14);
  final segments = u16(best + 6) ~/ 2;
  final ends = best + 14, starts = ends + segments * 2 + 2;
  final deltas = starts + segments * 2, ranges = deltas + segments * 2;
  need(ranges + segments * 2);
  for (var s = 0; s < segments; s++) {
    final end = u16(ends + s * 2), start = u16(starts + s * 2);
    final delta = data.getInt16(deltas + s * 2);
    final range = u16(ranges + s * 2);
    if (start > end || start == 0xffff) continue;
    for (var c = start; c <= end; c++) {
      int glyph;
      if (range == 0) {
        glyph = (c + delta) & 0xffff;
      } else {
        final at = ranges + s * 2 + range + (c - start) * 2;
        need(at + 2);
        glyph = u16(at);
        if (glyph != 0) glyph = (glyph + delta) & 0xffff;
      }
      if (glyph != 0) out.add(c);
    }
  }
  return out;
}
