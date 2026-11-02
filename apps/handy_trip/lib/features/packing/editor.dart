import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../trips/editor.dart';

Future<void> editPacking(
  BuildContext context,
  TripScope scope, [
  PackItem? old,
]) async {
  final trip = await ensureTrip(context, scope);
  if (trip == null || !context.mounted) return;
  await tripForm(
    context,
    tr(
      context,
      old == null ? 'Packing item' : 'Edit packing item',
      old == null ? 'Đồ cần mang' : 'Sửa đồ cần mang',
    ),
    [
      const TripField('title', 'Item name', 'Tên đồ'),
      const TripField('list', 'Checklist name', 'Tên checklist'),
      const TripField('category', 'Category', 'Nhóm', optional: true),
      const TripField(
        'quantity',
        'Quantity (whole items)',
        'Số lượng (nguyên)',
        kind: 'number',
      ),
      const TripField(
        'weightGrams',
        'Weight per item, grams (0 = not set)',
        'Khối lượng mỗi món, gram (0 = chưa đặt)',
        kind: 'number',
      ),
      const TripField('packed', 'Packed', 'Đã xếp', kind: 'toggle'),
    ],
    {
      'title': old?.title ?? '',
      'list':
          old?.text('list', fallback: 'Packing') ??
          tr(context, 'Packing', 'Hành lý'),
      'category': old?.text('category') ?? '',
      'quantity': '${old?.quantity ?? 1}',
      'weightGrams': '${old?.data['weightGrams'] ?? 0}',
      'packed': old?.packed ?? false,
    },
    (v) async {
      final item = PackItem({
        ...?old?.toJson(),
        ...v,
        'id': old?.key ?? newId(),
        'trip': trip.key,
        'quantity': int.parse(v['quantity']),
        'weightGrams': int.parse(v['weightGrams']),
        'order':
            old?.order ??
            scope.state.packing.where((p) => p.trip == trip.key).length,
      });
      await scope.controller.change((s) => s.put('packing', item));
    },
  );
}
