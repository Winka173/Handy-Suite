import 'dart:math' as math;
import 'project.dart';

/// A box on the picture, in the picture's own pixels.
class OcrBox {
  final double left, top, width, height;
  const OcrBox(this.left, this.top, this.width, this.height);
  double get right => left + width;
  double get bottom => top + height;
}

/// One word (or other piece) of a recognised line, with its box.
class OcrWord {
  final String text;
  final OcrBox box;
  const OcrWord(this.text, this.box);
}

/// One line of recognised text. [words] may be empty when the recogniser
/// only gives line boxes; the place of a match is then estimated from its
/// share of the line's characters.
class OcrLine {
  final String text;
  final OcrBox box;
  final List<OcrWord> words;
  const OcrLine(this.text, this.box, {this.words = const []});
}

/// What a finding looks like.
enum SensitiveKind { email, phone, card, iban, account, otp, token, secret }

/// A span of [SensitiveKind] in a piece of text, `[start, end)`.
typedef SensitiveSpan = ({SensitiveKind kind, int start, int end});

/// A place on the picture that may need hiding. [hint] shows only the
/// first and last characters of what was found, so a review list never
/// repeats the secret in full.
class SensitiveFinding {
  final SensitiveKind kind;
  final LayerGeometry area;
  final String hint;

  /// Which recognised line it came from.
  final int line;
  const SensitiveFinding(this.kind, this.area, this.hint, this.line);
}

/// At most this many lines are read from one picture.
const sensitiveMaxLines = 2000;

/// At most this many findings are proposed for one picture.
const sensitiveMaxFindings = 100;

final _email = RegExp(
  r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}',
);
// IBAN: country, check digits, then 11-30 letters or digits, in groups
// of four or written together.
final _iban = RegExp(
  r'\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){2,7}(?:[ ]?[A-Z0-9]{1,4})?\b',
);
// Digit runs, allowing one space, dot or dash between groups.
final _digits = RegExp(r'(?<![\w+])\+?\d(?:[ .\-]?\(?\d\)?){3,22}(?![\w])');
final _token = RegExp(r'[A-Za-z0-9_\-+/=.~]{20,}');
final _secret = RegExp(
  '(?:password|passwd|pwd|token|api[_ -]?key|secret|bearer|authorization|'
  'mật\\s*khẩu|khóa\\s*api|mã\\s*bí\\s*mật)\\s*[:=]?\\s*["\']?([^\\s"\']{4,})',
  caseSensitive: false,
);
final _otpWord = RegExp(
  r'\b(?:otp|code|pin|passcode|verification|verify|xác\s*thực|xác\s*minh|mã)(?![A-Za-z])',
  caseSensitive: false,
  unicode: true,
);

bool luhn(String digits) {
  if (!RegExp(r'^\d{13,19}$').hasMatch(digits)) return false;
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var d = digits.codeUnitAt(digits.length - 1 - i) - 48;
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}

bool ibanValid(String input) {
  final s = input.replaceAll(' ', '');
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(s)) return false;
  final moved = s.substring(4) + s.substring(0, 4);
  var rest = 0;
  for (final c in moved.codeUnits) {
    final v = c >= 65 ? c - 55 : c - 48;
    rest = (v > 9 ? rest * 100 + v : rest * 10 + v) % 97;
  }
  return rest == 1;
}

/// Bits per character; long random keys score above about 3.5.
double entropy(String s) {
  final counts = <int, int>{};
  for (final c in s.codeUnits) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  return -counts.values.fold<double>(0, (sum, n) {
    final p = n / s.length;
    return sum + p * math.log(p) / math.ln2;
  });
}

bool _phone(String run) {
  final d = run.replaceAll(RegExp(r'\D'), '');
  // Vietnam: mobile 0 + [35789] + 8 digits, landline 02 + 9 digits, with
  // +84 or 0084 in place of the 0.
  const vn = r'(?:[35789]\d{8}|2\d{9})$';
  if (run.startsWith('+84')) return RegExp('^84$vn').hasMatch(d);
  if (run.startsWith('+')) return d.length >= 8 && d.length <= 15;
  if (d.startsWith('0084')) return RegExp('^0084$vn').hasMatch(d);
  return RegExp('^0$vn').hasMatch(d);
}

/// Every sensitive span in [text], longest kinds first, never overlapping.
List<SensitiveSpan> matchSensitive(String text) {
  final found = <SensitiveSpan>[];
  bool free(int s, int e) => found.every((f) => e <= f.start || s >= f.end);
  void add(SensitiveKind kind, int s, int e) {
    if (e > s && free(s, e)) found.add((kind: kind, start: s, end: e));
  }

  for (final m in _email.allMatches(text)) {
    add(SensitiveKind.email, m.start, m.end);
  }
  for (final m in _secret.allMatches(text)) {
    final value = m.group(1)!;
    final at = m.end - value.length;
    add(SensitiveKind.secret, at, m.end);
  }
  for (final m in _iban.allMatches(text)) {
    if (ibanValid(m[0]!)) add(SensitiveKind.iban, m.start, m.end);
  }
  final keyword = _otpWord.hasMatch(text);
  for (final m in _digits.allMatches(text)) {
    var run = m[0]!;
    var start = m.start;
    // A trailing separator belongs to the sentence, not the number.
    while (run.isNotEmpty && !RegExp(r'\d|\)').hasMatch(run[run.length - 1])) {
      run = run.substring(0, run.length - 1);
    }
    final digits = run.replaceAll(RegExp(r'\D'), '');
    final end = start + run.length;
    if (!free(start, end)) continue;
    // Amounts and dates written with dots ("1.250.000", "02.11.2026") are
    // not account numbers.
    final dotted = run.contains('.');
    if (!run.startsWith('+') && luhn(digits)) {
      add(SensitiveKind.card, start, end);
    } else if (_phone(run)) {
      add(SensitiveKind.phone, start, end);
    } else if (!dotted && digits.length >= 9 && digits.length <= 19) {
      add(SensitiveKind.account, start, end);
    } else if (!dotted &&
        digits.length >= 4 &&
        digits.length <= 8 &&
        (keyword || text.trim() == run)) {
      add(SensitiveKind.otp, start, end);
    }
  }
  for (final m in _token.allMatches(text)) {
    final t = m[0]!;
    if (!RegExp(r'\d').hasMatch(t) ||
        !RegExp(r'[A-Za-z]').hasMatch(t) ||
        entropy(t) < 3.5 ||
        t.startsWith('http') ||
        t.contains('//')) {
      continue;
    }
    add(SensitiveKind.token, m.start, m.end);
  }
  found.sort((a, b) => a.start.compareTo(b.start));
  return found;
}

/// "jo…om" for a found value: enough to recognise it, never all of it.
String sensitiveHint(String value) {
  final v = value.replaceAll(RegExp(r'\s'), '');
  if (v.length <= 4) return '•' * v.length;
  final keep = v.length >= 12 ? 2 : 1;
  return '${v.substring(0, keep)}…${v.substring(v.length - keep)}';
}

/// The places on a [imageWidth] × [imageHeight] picture to propose hiding,
/// from its recognised [lines]. A place already covered by one of the
/// [hidden] areas (the step's opaque masks) is not proposed again.
List<SensitiveFinding> findSensitiveAreas(
  List<OcrLine> lines, {
  required int imageWidth,
  required int imageHeight,
  Iterable<LayerGeometry> hidden = const [],
}) {
  if (imageWidth < 1 || imageHeight < 1) {
    throw const FormatException('The picture has no size');
  }
  if (lines.length > sensitiveMaxLines) {
    throw const FormatException('Too much text on one picture to check');
  }
  final out = <SensitiveFinding>[];
  for (final (index, line) in lines.indexed) {
    for (final span in matchSensitive(line.text)) {
      final box = _spanBox(line, span.start, span.end);
      if (box == null) continue;
      final pad = math.max(2.0, box.height * .15);
      final area = LayerGeometry(
        (box.left - pad) / imageWidth,
        (box.top - pad) / imageHeight,
        (box.width + pad * 2) / imageWidth,
        (box.height + pad * 2) / imageHeight,
      ).clamped();
      if (area.width <= 0 || area.height <= 0) continue;
      if (hidden.any((h) => _covers(h, area))) continue;
      out.add(
        SensitiveFinding(
          span.kind,
          area,
          sensitiveHint(line.text.substring(span.start, span.end)),
          index,
        ),
      );
      if (out.length >= sensitiveMaxFindings) return out;
    }
  }
  return out;
}

/// The opaque masks for [accepted] findings, ready to add to a step.
List<ProjectLayer> redactionLayers(
  Iterable<SensitiveFinding> accepted, {
  required String Function() newId,
}) => [
  for (final f in accepted)
    ProjectLayer.parse({
      'id': newId(),
      'kind': 'redact',
      ...f.area.toJson(),
      'color': '#000000',
      'text': '',
    }),
];

/// Where `[start, end)` of [line] sits: the union of the words it
/// touches, or its share of the line's width.
OcrBox? _spanBox(OcrLine line, int start, int end) {
  if (line.words.isNotEmpty) {
    var cursor = 0;
    OcrBox? box;
    for (final w in line.words) {
      final at = line.text.indexOf(w.text, cursor);
      if (at < 0 || w.text.isEmpty) continue;
      final wEnd = at + w.text.length;
      cursor = wEnd;
      if (wEnd <= start || at >= end) continue;
      // A word that holds more than the match ("e-mail:me@x.vn") is cut
      // to the match's share of it.
      final from = math.max(start, at), to = math.min(end, wEnd);
      final part = OcrBox(
        w.box.left + w.box.width * (from - at) / w.text.length,
        w.box.top,
        w.box.width * (to - from) / w.text.length,
        w.box.height,
      );
      box = box == null ? part : _union(box, part);
    }
    if (box != null) return box;
  }
  final n = line.text.length;
  if (n == 0) return null;
  return OcrBox(
    line.box.left + line.box.width * start / n,
    line.box.top,
    line.box.width * (end - start) / n,
    line.box.height,
  );
}

OcrBox _union(OcrBox a, OcrBox b) {
  final l = math.min(a.left, b.left), t = math.min(a.top, b.top);
  return OcrBox(
    l,
    t,
    math.max(a.right, b.right) - l,
    math.max(a.bottom, b.bottom) - t,
  );
}

/// Whether [mask] hides at least nine tenths of [area].
bool _covers(LayerGeometry mask, LayerGeometry area) {
  final w =
      math.min(mask.x + mask.width, area.x + area.width) -
      math.max(mask.x, area.x);
  final h =
      math.min(mask.y + mask.height, area.y + area.height) -
      math.max(mask.y, area.y);
  if (w <= 0 || h <= 0) return false;
  return w * h >= area.width * area.height * .9;
}
