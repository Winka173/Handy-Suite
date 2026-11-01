import 'package:handy_spend_engine/handy_spend_engine.dart';

/// Reads an amount the way people type it: `45.000` or `45,000` grouped,
/// `12,5` or `12.5` with decimals, `45k` for thousands and `1,5tr` (triệu)
/// for millions. [vi] decides which separator groups when only one is
/// used and it could be either. A sign is kept; the engine checks the scale.
BigInt parseAmount(String text, String currency, {required bool vi}) {
  var t = text
      .trim()
      .replaceAll(RegExp(r'[\s ₫đĐ$€£]'), '')
      .replaceAll(RegExp(currency, caseSensitive: false), '');
  if (t.isEmpty) throw const FormatException('Enter an amount / Nhập số tiền');
  var shift = 0;
  final lower = t.toLowerCase();
  if (lower.endsWith('tr')) {
    shift = 6;
    t = t.substring(0, t.length - 2);
  } else if (lower.endsWith('k')) {
    shift = 3;
    t = t.substring(0, t.length - 1);
  }
  var sign = '';
  if (t.startsWith('-') || t.startsWith('+')) {
    sign = t[0] == '-' ? '-' : '';
    t = t.substring(1);
  }
  t = _plain(t, vi: vi, wholeOnly: scale(currency) == 0 && shift == 0);
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t))
    throw const FormatException('Not an amount / Không phải số tiền');
  return minor('$sign${_shift(t, shift)}', currency);
}

/// One decimal point and no grouping. A separator used more than once, or
/// once before exactly three digits where it can only group, is grouping.
String _plain(String t, {required bool vi, required bool wholeOnly}) {
  final dec = vi ? ',' : '.', group = vi ? '.' : ',';
  if (t.contains(dec) && t.contains(group))
    return t.replaceAll(group, '').replaceAll(dec, '.');
  for (final sep in [group, dec]) {
    if (!t.contains(sep)) continue;
    final parts = t.split(sep);
    final grouping =
        parts.length > 2 ||
        parts.last.length == 3 && (wholeOnly || sep == group);
    if (!grouping) return parts.join('.');
    // Groups of exactly three after a lead of one to three digits.
    if (parts.first.isEmpty ||
        parts.first.length > 3 ||
        parts.skip(1).any((p) => p.length != 3))
      throw const FormatException('Not an amount / Không phải số tiền');
    return parts.join();
  }
  return t;
}

/// Moves the decimal point [places] to the right: `1.5` by 3 is `1500`.
String _shift(String t, int places) {
  if (places == 0) return t;
  final parts = t.split('.');
  final fraction = parts.length > 1 ? parts[1] : '';
  final moved = fraction.padRight(places, '0');
  final whole = '${parts[0]}${moved.substring(0, places)}'.replaceFirst(
    RegExp(r'^0+(?=\d)'),
    '',
  );
  final rest = moved.substring(places);
  return rest.isEmpty ? whole : '$whole.$rest';
}

/// An amount as it is typed back into a field: grouped in the reader's
/// way (`1.250.000,5` or `1,250,000.5`), which [parseAmount] reads again.
String editableAmount(BigInt value, String currency, {required bool vi}) {
  final m = RegExp(
    r'^(-?)(\d+)(?:\.(\d+))?$',
  ).firstMatch(decimalMoney(value, currency))!;
  final digits = m[2]!, out = StringBuffer(m[1]!);
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(vi ? '.' : ',');
    out.write(digits[i]);
  }
  if (m[3] != null) out.write('${vi ? ',' : '.'}${m[3]}');
  return out.toString();
}

/// A short figure for a chart's axis: `12tr`, `850k` (vi) or `12M`,
/// `850K`. Never used where the exact amount is the answer.
String compactAmount(BigInt minorUnits, String currency, {required bool vi}) {
  final major =
      minorUnits.toDouble() / BigInt.from(10).pow(scale(currency)).toDouble();
  final a = major.abs(), sign = major < 0 ? '−' : '';
  String trim(double v) {
    final s = v >= 10 ? v.round().toString() : v.toStringAsFixed(1);
    final out = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    return vi ? out.replaceAll('.', ',') : out;
  }

  if (a >= 1e9) return '$sign${trim(a / 1e9)}${vi ? ' tỷ' : 'B'}';
  if (a >= 1e6) return '$sign${trim(a / 1e6)}${vi ? 'tr' : 'M'}';
  if (a >= 1e3) return '$sign${trim(a / 1e3)}${vi ? 'k' : 'K'}';
  return '$sign${trim(a)}';
}

/// Payments a year for a schedule; a one-off has none.
int perYear(String frequency) => switch (frequency) {
  'weekly' => 52,
  'monthly' => 12,
  'yearly' => 1,
  _ => 0,
};

/// The unit shown after a figure: the currency's code, except the dong,
/// written đ as on price tags (the bundled faces have no ₫ sign).
String currencyUnit(String currency) => currency == 'VND' ? 'đ' : currency;
