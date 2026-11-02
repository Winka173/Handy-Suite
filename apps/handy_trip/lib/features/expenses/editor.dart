import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../trips/editor.dart';
import '../media/attachments.dart';

Future<void> editExpense(
  BuildContext context,
  TripScope scope, [
  Expense? old,
]) async {
  final trip = old == null
      ? await ensureTrip(context, scope)
      : scope.state.trip(old.trip);
  if (trip == null || !context.mounted) return;
  final zone = old?.text('zone', fallback: trip.zone) ?? trip.zone;
  final receipt = AttachmentSelection([
    if (old?.ref('receipt') != null) old!.ref('receipt')!,
  ]);
  await tripForm(
    context,
    tr(
      context,
      old == null ? 'Record expense' : 'Edit expense',
      old == null ? 'Ghi chi tiêu' : 'Sửa chi tiêu',
    ),
    [
      const TripField(
        'description',
        'Expense description',
        'Mô tả chi tiêu',
        optional: true,
      ),
      const TripField('day', 'Expense date', 'Ngày chi tiêu', kind: 'date'),
      foldField(context),
      const TripField('time', 'Expense time', 'Giờ chi tiêu', kind: 'time'),
      TripField(
        'currency',
        'Currency — totals stay separate',
        'Tiền tệ — tổng được tính riêng',
        kind: 'choice',
        choices: {for (final c in currencyScales.keys) c: c},
      ),
      const TripField(
        'amount',
        'Amount (decimal point, no grouping)',
        'Số tiền (dấu chấm thập phân, không phân nhóm)',
        kind: 'number',
      ),
      TripField(
        'category',
        'Category',
        'Nhóm',
        kind: 'choice',
        choices: {
          'transport': tr(context, 'Transport', 'Di chuyển'),
          'lodging': tr(context, 'Lodging', 'Lưu trú'),
          'food': tr(context, 'Food', 'Ăn uống'),
          'activity': tr(context, 'Activity', 'Hoạt động'),
          'shopping': tr(context, 'Shopping', 'Mua sắm'),
          'other': tr(context, 'Other', 'Khác'),
        },
      ),
      const TripField(
        'payer',
        'Payer (optional, no automatic splitting)',
        'Người trả (tùy chọn, không tự chia tiền)',
        optional: true,
      ),
    ],
    {
      'description': old?.text('description') ?? '',
      'day': old == null
          ? scope.today
          : localDay(
              DateTime.parse(old.at),
              old.text('zone', fallback: trip.zone),
            ),
      'fold': lateFoldAt(old?.at, zone) ? 'later' : 'earlier',
      'time': localClock(
        old == null ? scope.clock() : DateTime.parse(old.at),
        zone,
      ),
      'currency': old?.currency ?? trip.currency,
      'amount': old == null ? '0' : amount(old.minor, old.currency),
      'category': old?.category ?? 'other',
      'payer': old?.text('payer') ?? '',
    },
    (v) async {
      final expense = Expense({
        ...?old?.toJson(),
        'id': old?.key ?? newId(),
        'trip': trip.key,
        'at': editedInstant(
          old?.at,
          old == null ? null : zone,
          v['day'],
          v['time'],
          zone,
          lateFold: v['fold'] == 'later',
        ).toIso8601String(),
        'zone': zone,
        'minor': money(v['amount'], v['currency']).toString(),
        'currency': v['currency'],
        'category': v['category'],
        'description': v['description'],
        'payer': v['payer'],
        'receipt': receipt.ids.firstOrNull,
      });
      await scope.controller.change(
        (s) => receipt.apply(s).put('expenses', expense),
      );
    },
    footer: [AttachmentChooser(scope: scope, selection: receipt, maxCount: 1)],
  );
}
