import 'dart:typed_data';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/whereabouts.dart';

/// The words of a due date's kind.
String dueKind(BuildContext c, String kind) => switch (kind) {
  'loan' => tr(c, 'Return due', 'Hẹn trả'),
  'warranty' => tr(c, 'Warranty ends', 'Hết bảo hành'),
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

/// The item's own photo at [size], or its initial on the app's pale tint.
class ItemThumb extends StatelessWidget {
  final InventoryAsset item;
  final Map<String, Uint8List> blobs;
  final double size;

  /// Flies between the list row and the item page (phones only: on wide
  /// screens both are on one page, where a tag may appear once).
  final bool hero;
  const ItemThumb(
    this.item,
    this.blobs, {
    super.key,
    this.size = 40,
    this.hero = false,
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

  Widget _initial(BuildContext context, HandyColors c, BorderRadius radius) =>
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.select, borderRadius: radius),
        child: ExcludeSemantics(
          child: Text(
            item.name.characters.first.toUpperCase(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: c.selectInk,
              fontSize: size * .45,
            ),
          ),
        ),
      );
}
