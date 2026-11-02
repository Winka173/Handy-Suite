part of '../handy_inventory.dart';

/// Currencies people write without minor units. Every other code allows two.
const _wholeCurrencies = {'VND', 'JPY', 'KRW'};

/// How many decimals [currency] allows: 0 for the đồng, the yen and the won,
/// 2 for the rest.
int currencyDigits(Object? currency) =>
    _wholeCurrencies.contains(currency) ? 0 : 2;

String _price(Object? value) {
  final result = _text(value, 20);
  if (result.isNotEmpty &&
      !RegExp(r'^(0|[1-9]\d{0,11})(\.\d{1,2})?$').hasMatch(result))
    throw const FormatException('Invalid price');
  return result;
}

String _currency(Object? value) {
  final result = _text(value, 3);
  if (result.isNotEmpty && !RegExp(r'^[A-Z]{3}$').hasMatch(result))
    throw const FormatException('Invalid currency code');
  return result;
}

int _decimals(String price) {
  final dot = price.indexOf('.');
  return dot < 0 ? 0 : price.length - dot - 1;
}

/// Reads a price as people type it: "4.500.000", "4 500 000", "1,299.90",
/// "1.299,90". Grouping marks are dropped; a last "." or "," followed by one
/// or two digits is the decimal mark, but only for currencies that have
/// minor units. Empty input means no price. Throws in words otherwise.
String parsePrice(String input, String currency) {
  final raw = input.trim().replaceAll(RegExp(r'[\s  ]'), '');
  if (raw.isEmpty) return '';
  if (!RegExp(r'^[0-9.,]+$').hasMatch(raw) || !RegExp(r'[0-9]').hasMatch(raw)) {
    throw const FormatException(
      'Write the price as a number / Ghi giá bằng số',
    );
  }
  var whole = raw, fraction = '';
  final decimal = RegExp(r'[.,](\d{1,2})$').firstMatch(raw);
  if (decimal != null && currencyDigits(_currency(currency)) > 0) {
    whole = raw.substring(0, decimal.start);
    fraction = decimal[1]!;
  }
  whole = whole.replaceAll(RegExp('[.,]'), '');
  whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (whole.isEmpty) whole = '0';
  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  final result = fraction.isEmpty ? whole : '$whole.$fraction';
  try {
    return _price(result);
  } on FormatException {
    throw const FormatException('Price is too large / Giá quá lớn');
  }
}

BigInt _minor(String price, String currency) {
  final digits = currencyDigits(currency);
  final parts = price.split('.');
  final fraction = (parts.length > 1 ? parts[1] : '').padRight(digits, '0');
  return BigInt.parse('${parts[0]}$fraction');
}

/// [minor] units of [currency] as a plain decimal with the currency's own
/// decimals ("4500000", "1299.90"), ready for `formatFigure`.
String formatMinor(BigInt minor, String currency) {
  final digits = currencyDigits(currency);
  if (digits == 0) return '$minor';
  final text = minor.toString().padLeft(digits + 1, '0');
  final cut = text.length - digits;
  return '${text.substring(0, cut)}.${text.substring(cut)}';
}

/// What a set of things cost, kept per currency: amounts in different
/// currencies are listed side by side and never added together.
class KeepValue {
  /// Sum per currency, in minor units. The currency most of the items are
  /// priced in comes first; ties go by code.
  final Map<String, BigInt> totals;

  /// How many things were counted, and how many of those have no price.
  final int items, unpriced;
  KeepValue(
    Map<String, BigInt> totals,
    this.items,
    this.unpriced, [
    Map<String, int> counts = const {},
  ]) : totals = Map.unmodifiable(
         Map.fromEntries(
           totals.entries.toList()..sort((a, b) {
             final n = (counts[b.key] ?? 0).compareTo(counts[a.key] ?? 0);
             return n != 0 ? n : a.key.compareTo(b.key);
           }),
         ),
       );

  bool get hasPrices => totals.isNotEmpty;

  /// Each currency's sum as a plain decimal, for display or export.
  List<(String currency, String amount)> get amounts => [
    for (final e in totals.entries) (e.key, formatMinor(e.value, e.key)),
  ];
}

/// The value of [items], counted once each.
KeepValue valueOf(Iterable<InventoryAsset> items) {
  final totals = <String, BigInt>{}, counts = <String, int>{};
  var count = 0, unpriced = 0;
  for (final a in items) {
    count++;
    if (a.price.isEmpty) {
      unpriced++;
      continue;
    }
    totals[a.currency] =
        (totals[a.currency] ?? BigInt.zero) + _minor(a.price, a.currency);
    counts[a.currency] = (counts[a.currency] ?? 0) + 1;
  }
  return KeepValue(totals, count, unpriced, counts);
}

/// The currency most items are priced in, or null when none has a price.
/// Ties go to the code that sorts first, so the answer is stable.
String? usualCurrency(KeepState state) {
  final counts = <String, int>{};
  for (final a in state.assets) {
    if (a.currency.isNotEmpty)
      counts[a.currency] = (counts[a.currency] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final n = b.value.compareTo(a.value);
      return n != 0 ? n : a.key.compareTo(b.key);
    });
  return ranked.first.key;
}
