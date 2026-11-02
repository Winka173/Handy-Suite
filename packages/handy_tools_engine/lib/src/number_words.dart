part of '../handy_tools_engine.dart';

/// How a Vietnamese number is spoken. The defaults are the northern
/// written form used on invoices.
class VietnameseWordStyle {
  /// "linh" (north) or "lẻ" (south) for a zero tens digit: một trăm linh năm.
  final String zeroTens;

  /// "nghìn" (north) or "ngàn" (south).
  final String thousand;

  /// "lăm" or "nhăm" for a 5 after a tens word above ten: hai mươi lăm.
  final String five;

  /// "tư" or "bốn" for a 4 after a tens word above ten: hai mươi tư.
  final String four;
  const VietnameseWordStyle({
    this.zeroTens = 'linh',
    this.thousand = 'nghìn',
    this.five = 'lăm',
    this.four = 'tư',
  });
  static const north = VietnameseWordStyle();
  static const south = VietnameseWordStyle(zeroTens: 'lẻ', thousand: 'ngàn');
}

const _viDigits = [
  'không',
  'một',
  'hai',
  'ba',
  'bốn',
  'năm',
  'sáu',
  'bảy',
  'tám',
  'chín',
];

/// A number split into sign, integer digits and fraction digits. Accepts
/// `-1234567.89`; the bench normalises grouping before it gets here.
({bool negative, String whole, String fraction}) _wordsNumber(String source) {
  final s = _bounded(source.trim(), 100).replaceAll(RegExp(r'[\s_]'), '');
  final m = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(s);
  if (m == null) {
    throw const FormatException('Use digits, an optional sign and decimals');
  }
  final whole = m[2]!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final fraction = (m[3] ?? '').replaceFirst(RegExp(r'0+$'), '');
  if (whole.length > 27) {
    throw const FormatException('Up to 27 digits before the decimal point');
  }
  if (fraction.length > 12) {
    throw const FormatException('Up to 12 decimal places');
  }
  final zero = whole == '0' && fraction.isEmpty;
  return (negative: m[1] == '-' && !zero, whole: whole, fraction: fraction);
}

/// Three digits. [full] reads "không trăm" and "linh" when this group
/// follows a larger one (một nghìn không trăm linh năm).
String _viGroup(int n, bool full, VietnameseWordStyle style) {
  final h = n ~/ 100, t = n ~/ 10 % 10, u = n % 10;
  final words = <String>[];
  if (h > 0 || full) words.addAll([_viDigits[h], 'trăm']);
  if (t == 0) {
    if (u > 0) {
      if (h > 0 || full) words.add(style.zeroTens);
      words.add(_viDigits[u]);
    }
  } else if (t == 1) {
    words.add('mười');
    if (u == 5) {
      words.add('lăm');
    } else if (u > 0) {
      words.add(_viDigits[u]);
    }
  } else {
    words.addAll([_viDigits[t], 'mươi']);
    if (u == 1) {
      words.add('mốt');
    } else if (u == 4) {
      words.add(style.four);
    } else if (u == 5) {
      words.add(style.five);
    } else if (u > 0) {
      words.add(_viDigits[u]);
    }
  }
  return words.join(' ');
}

/// Below one tỷ (10⁹): groups of triệu, nghìn and units.
String _viBelowBillion(int n, bool full, VietnameseWordStyle style) {
  final groups = [n ~/ 1000000, n ~/ 1000 % 1000, n % 1000];
  const names = ['triệu', '', ''];
  final out = <String>[];
  var started = full;
  for (var i = 0; i < 3; i++) {
    final g = groups[i];
    if (g == 0) continue;
    final name = i == 1 ? style.thousand : names[i];
    out.add([_viGroup(g, started, style), if (name.isNotEmpty) name].join(' '));
    started = true;
  }
  return out.join(' ');
}

/// Whole numbers: tỷ repeats above 10⁹ (một nghìn tỷ, một tỷ tỷ).
String _viWhole(BigInt n, bool full, VietnameseWordStyle style) {
  final billion = BigInt.from(1000000000);
  if (n < billion) return _viBelowBillion(n.toInt(), full, style);
  final high = n ~/ billion, low = (n % billion).toInt();
  final head = '${_viWhole(high, full, style)} tỷ';
  return low == 0 ? head : '$head ${_viBelowBillion(low, true, style)}';
}

/// [source] in Vietnamese words, lower case: `1200000` → "một triệu hai
/// trăm nghìn". Decimals are read digit by digit after "phẩy".
String vietnameseNumberWords(
  String source, {
  VietnameseWordStyle style = VietnameseWordStyle.north,
}) {
  final n = _wordsNumber(source);
  final whole = BigInt.parse(n.whole);
  final words = [
    if (n.negative) 'âm',
    whole == BigInt.zero ? 'không' : _viWhole(whole, false, style),
    if (n.fraction.isNotEmpty) ...[
      'phẩy',
      for (final d in n.fraction.split('')) _viDigits[int.parse(d)],
    ],
  ];
  return words.join(' ');
}

/// The invoice line: capitalised, "đồng", and "chẵn" for a whole amount.
/// Đồng has no smaller unit, so decimals are refused.
String vietnameseAmountWords(
  String source, {
  VietnameseWordStyle style = VietnameseWordStyle.north,
}) {
  final n = _wordsNumber(source);
  if (n.fraction.isNotEmpty) {
    throw const FormatException('Đồng amounts have no decimals');
  }
  final words = '${vietnameseNumberWords(source, style: style)} đồng chẵn';
  return words[0].toUpperCase() + words.substring(1);
}

const _enOnes = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
];
const _enTens = [
  '',
  '',
  'twenty',
  'thirty',
  'forty',
  'fifty',
  'sixty',
  'seventy',
  'eighty',
  'ninety',
];
const _enScales = [
  '',
  'thousand',
  'million',
  'billion',
  'trillion',
  'quadrillion',
  'quintillion',
  'sextillion',
  'septillion',
];

String _enGroup(int n) {
  final h = n ~/ 100, rest = n % 100;
  final words = <String>[];
  if (h > 0) words.addAll([_enOnes[h], 'hundred']);
  if (rest >= 20) {
    words.add(
      rest % 10 == 0
          ? _enTens[rest ~/ 10]
          : '${_enTens[rest ~/ 10]}-${_enOnes[rest % 10]}',
    );
  } else if (rest > 0) {
    words.add(_enOnes[rest]);
  }
  return words.join(' ');
}

/// [source] in English words (short scale, no "and"): `1200000` → "one
/// million two hundred thousand".
String englishNumberWords(String source) {
  final n = _wordsNumber(source);
  final digits = n.whole;
  final groups = <int>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.insert(0, int.parse(digits.substring(math.max(0, end - 3), end)));
  }
  final parts = <String>[];
  for (var i = 0; i < groups.length; i++) {
    final g = groups[i], scale = groups.length - 1 - i;
    if (g == 0) continue;
    parts.add([_enGroup(g), if (scale > 0) _enScales[scale]].join(' '));
  }
  return [
    if (n.negative) 'minus',
    parts.isEmpty ? 'zero' : parts.join(' '),
    if (n.fraction.isNotEmpty) ...[
      'point',
      for (final d in n.fraction.split('')) _enOnes[int.parse(d)],
    ],
  ].join(' ');
}

/// The registry runner. [options] is `unit=dong|none;style=north|south`.
String runNumberWords(String input, String options) {
  final o = <String, String>{};
  for (final part in options.split(';')) {
    if (part.trim().isEmpty) continue;
    final kv = part.split('=');
    if (kv.length != 2) throw const FormatException('Options: key=value');
    o[kv[0].trim()] = kv[1].trim();
  }
  final unit = o['unit'] ?? 'dong', dialect = o['style'] ?? 'north';
  if (!['dong', 'none'].contains(unit) ||
      !['north', 'south'].contains(dialect)) {
    throw const FormatException('Unit dong/none, style north/south');
  }
  final style = dialect == 'south'
      ? VietnameseWordStyle.south
      : VietnameseWordStyle.north;
  final n = _wordsNumber(input);
  final number =
      '${n.negative ? '-' : ''}${n.whole}${n.fraction.isEmpty ? '' : '.${n.fraction}'}';
  final vi = unit == 'dong'
      ? vietnameseAmountWords(number, style: style)
      : vietnameseNumberWords(number, style: style);
  var en = englishNumberWords(number);
  if (unit == 'dong') en = '$en dong';
  en = en[0].toUpperCase() + en.substring(1);
  return _json({'number': number, 'vi': vi, 'en': en});
}
