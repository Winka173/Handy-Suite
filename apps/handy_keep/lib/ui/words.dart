import 'dart:typed_data';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/whereabouts.dart';

/// The words of a due date's kind.
String dueKind(BuildContext c, String kind) => switch (kind) {
  'loan' => tr(c, 'Return due', 'Hẹn trả'),
  'warranty' => tr(c, 'Warranty ends', 'Hết bảo hành'),
  'runout' => tr(c, 'Likely to run out', 'Có lẽ sắp hết'),
  _ => tr(c, 'Service due', 'Đến hạn bảo dưỡng'),
};

/// How far a dated thing is, in the words of its kind: an overdue loan is
/// "overdue by 5 days", an ended warranty "ended 5 days ago".
String dueWhen(BuildContext c, String kind, int days) {
  if (days >= 0) return relativeDays(c, days);
  final n = -days;
  return switch (kind) {
    'loan' => tr(
      c,
      n == 1 ? 'overdue by 1 day' : 'overdue by $n days',
      'quá hạn $n ngày',
    ),
    'runout' => tr(
      c,
      n == 1 ? 'probably out 1 day ago' : 'probably out $n days ago',
      'có lẽ đã hết $n ngày',
    ),
    'warranty' => tr(
      c,
      'ended ${relativeDays(c, days)}',
      'đã hết ${relativeDays(c, days)}',
    ),
    _ => tr(c, n == 1 ? 'late by 1 day' : 'late by $n days', 'trễ $n ngày'),
  };
}

/// A place as a heading: "With Lan", "Box 7", "Kitchen cupboard".
String placeTitle(BuildContext c, Place p) => switch (p.kind) {
  PlaceKind.borrower => tr(c, 'With ${p.name}', 'Ở chỗ ${p.name}'),
  PlaceKind.none => tr(c, 'No place yet', 'Chưa ghi chỗ'),
  _ => p.name,
};

/// The one-line answer to "where is it?" for a single item.
String whereNow(BuildContext c, InventoryAsset a, KeepState s) {
  final p = placeOf(a, {for (final b in s.boxes) b.id: b});
  return switch (p.kind) {
    PlaceKind.box when p.detail.isNotEmpty => '${p.name} · ${p.detail}',
    _ => placeTitle(c, p),
  };
}

String itemCount(BuildContext c, int n) =>
    tr(c, n == 1 ? '1 item' : '$n items', '$n món');

/// Currencies offered in the editor, the đồng first. Codes already in use
/// are added by the editor.
const keepCurrencies = [
  'VND',
  'USD',
  'EUR',
  'JPY',
  'KRW',
  'CNY',
  'SGD',
  'THB',
  'AUD',
  'GBP',
];

/// The currency a new price starts in: the one most items use, else the
/// đồng in Vietnamese and the dollar otherwise.
String startCurrency(BuildContext c, KeepState s) =>
    usualCurrency(s) ?? tr(c, 'USD', 'VND');

/// An amount for reading: "4,500,000 đ", "1.299,90 USD". The đồng is
/// written đ because the bundled faces lack ₫.
String money(BuildContext c, String currency, String amount) =>
    formatFigure(c, '$amount ${currency == 'VND' ? 'đ' : currency}');

/// One item's price, with its currency's own decimals.
String priceOf(BuildContext c, InventoryAsset a) => money(
  c,
  a.currency,
  formatMinor(valueOf([a]).totals[a.currency]!, a.currency),
);

/// Each currency's sum side by side, never added together: "4,750,000 đ ·
/// 130.05 USD". A dash when nothing has a price.
String moneyLine(BuildContext c, KeepValue v) =>
    v.hasPrices ? v.amounts.map((e) => money(c, e.$1, e.$2)).join(' · ') : '—';

/// "3 without a price", or empty when every item has one. It never breaks
/// across lines: it wraps whole after an amount.
String unpricedNote(BuildContext c, KeepValue v) => v.unpriced == 0
    ? ''
    : tr(
        c,
        v.unpriced == 1 ? '1 without a price' : '${v.unpriced} without a price',
        '${v.unpriced} món chưa có giá',
      ).replaceAll(' ', ' ');

/// The item's own photo at [size], or its initial on the pale tint of
/// where it is ([hue], a `HandyPalette` index), or of the app.
class ItemThumb extends StatelessWidget {
  final InventoryAsset item;
  final Map<String, Uint8List> blobs;
  final double size;
  final int? hue;

  /// Flies between the list row and the item page (phones only: on wide
  /// screens both are on one page, where a tag may appear once).
  final bool hero;
  const ItemThumb(
    this.item,
    this.blobs, {
    super.key,
    this.size = 40,
    this.hero = false,
    this.hue,
  });
  @override
  Widget build(BuildContext context) => hero
      ? Hero(tag: 'keep-thumb-${item.id}', child: _thumb(context))
      : _thumb(context);

  Widget _thumb(BuildContext context) {
    final bytes = blobs[item.photoUri];
    final c = HandyColors.of(context);
    final radius = BorderRadius.circular(HandyRadius.control);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 3).round(),
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _initial(context, c, radius),
        ),
      );
    }
    return _initial(context, c, radius);
  }

  Widget _initial(BuildContext context, HandyColors c, BorderRadius radius) {
    final tint = hue == null ? null : HandyPalette.of(context, hue!).tint;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint ?? c.select, borderRadius: radius),
      child: ExcludeSemantics(
        child: Text(
          item.name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: tint == null
                ? c.selectInk
                : Theme.of(context).colorScheme.onSurface,
            fontSize: size * .45,
          ),
        ),
      ),
    );
  }
}
