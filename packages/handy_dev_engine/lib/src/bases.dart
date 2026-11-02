/// Integers between bases 2–36 with BigInt, and two's complement at a bit
/// width.
library;

class BaseConversion {
  final BigInt value;

  /// Extra base asked for (2–36), if any.
  final int? base;

  /// Bit width for two's complement, if any.
  final int? bits;
  const BaseConversion(this.value, {this.base, this.bits});

  static String _signed(BigInt v, int radix, String prefix) =>
      '${v.isNegative ? '-' : ''}$prefix${v.abs().toRadixString(radix)}';

  String get decimal => value.toString();
  String get hex => _signed(value, 16, '0x');
  String get octal => _signed(value, 8, '0o');
  String get binary => _signed(value, 2, '0b');
  String? get inBase => base == null ? null : _signed(value, base!, '');

  /// The bit pattern at [bits]: as unsigned and signed numbers, and as hex
  /// and binary padded to the width.
  ({String unsigned, String signed, String hex, String binary})? get twos {
    final b = bits;
    if (b == null) return null;
    final size = BigInt.one << b;
    final pattern = value.isNegative ? size + value : value;
    final signed = pattern >= (size >> 1) ? pattern - size : pattern;
    return (
      unsigned: pattern.toString(),
      signed: signed.toString(),
      hex: '0x${pattern.toRadixString(16).padLeft((b + 3) ~/ 4, '0')}',
      binary: '0b${pattern.toRadixString(2).padLeft(b, '0')}',
    );
  }

  Map<String, dynamic> toJson() => {
    'decimal': decimal,
    'hex': hex,
    'octal': octal,
    'binary': binary,
    if (base != null) 'base$base': inBase,
    if (twos case final t?) ...{
      'bits': bits,
      'unsigned': t.unsigned,
      'signed': t.signed,
      'twosComplementHex': t.hex,
      'twosComplementBinary': t.binary,
    },
  };
}

const maxBaseDigits = 4096, maxBits = 4096;

/// Reads `255`, `-42`, `0xff`, `0b1010`, `0o755` (separators `_` and spaces
/// allowed). Text without a prefix is decimal when it is all digits, and in
/// [base] otherwise.
BaseConversion convertBase(String input, {int? base, int? bits}) {
  if (base != null && (base < 2 || base > 36)) {
    throw const FormatException(
      'Base must be 2–36 / Hệ cơ số phải từ 2 đến 36',
    );
  }
  if (bits != null && (bits < 1 || bits > maxBits)) {
    throw const FormatException(
      'Bit width must be 1–$maxBits / Số bit phải từ 1 đến $maxBits',
    );
  }
  var s = input.trim().replaceAll(RegExp(r'[_\s]'), '');
  if (s.isEmpty || s.length > maxBaseDigits) {
    throw const FormatException(
      'Enter an integer of up to $maxBaseDigits digits / '
      'Nhập số nguyên tối đa $maxBaseDigits chữ số',
    );
  }
  var negative = false;
  if (s.startsWith('-') || s.startsWith('+')) {
    negative = s.startsWith('-');
    s = s.substring(1);
  }
  final lower = s.toLowerCase();
  final (int radix, String digits) = lower.startsWith('0x')
      ? (16, s.substring(2))
      : lower.startsWith('0b')
      ? (2, s.substring(2))
      : lower.startsWith('0o')
      ? (8, s.substring(2))
      : RegExp(r'^\d+$').hasMatch(s)
      ? (10, s)
      : base != null
      ? (base, s)
      : throw const FormatException(
          'Not a decimal number: add 0x, 0b or 0o, or choose the base / '
          'Không phải số thập phân: thêm 0x, 0b, 0o hoặc chọn hệ cơ số',
        );
  final valid = RegExp(
    '^[${'0123456789abcdefghijklmnopqrstuvwxyz'.substring(0, radix)}]+\$',
    caseSensitive: false,
  );
  if (digits.isEmpty || !valid.hasMatch(digits)) {
    throw FormatException(
      'Not a valid base-$radix number / Không phải số hệ $radix hợp lệ',
    );
  }
  var value = BigInt.parse(digits, radix: radix);
  if (negative) value = -value;
  if (bits != null) {
    final size = BigInt.one << bits;
    if (value < -(size >> 1) || value >= size) {
      throw FormatException('Does not fit in $bits bits / Không vừa $bits bit');
    }
  }
  return BaseConversion(value, base: base, bits: bits);
}

/// The `base-convert` tool's options: `base=36 bits=32`, either optional.
({int? base, int? bits}) baseOptions(String options) {
  int? base, bits;
  for (final t in options.trim().split(RegExp(r'\s+'))) {
    if (t.isEmpty) continue;
    final m = RegExp(r'^(base|bits)=(\d{1,4})$').firstMatch(t.toLowerCase());
    if (m == null) {
      throw const FormatException(
        'Options are base=N and bits=N / Tùy chọn là base=N và bits=N',
      );
    }
    if (m[1] == 'base') {
      base = int.parse(m[2]!);
    } else {
      bits = int.parse(m[2]!);
    }
  }
  return (base: base, bits: bits);
}
