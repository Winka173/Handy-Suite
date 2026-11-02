import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../trips/editor.dart';
import '../media/attachments.dart';

Future<void> editBooking(
  BuildContext context,
  TripScope scope, [
  Booking? old,
]) async {
  final trip = old == null
      ? await ensureTrip(context, scope)
      : scope.state.trip(old.trip);
  if (trip == null || !context.mounted) return;
  final files = AttachmentSelection(old?.list('assets') ?? []);
  await tripForm(
    context,
    tr(
      context,
      old == null ? 'Add booking' : 'Edit booking',
      old == null ? 'Thêm đặt chỗ' : 'Sửa đặt chỗ',
    ),
    [
      const TripField('title', 'Booking title', 'Tên đặt chỗ'),
      TripField(
        'type',
        'Type',
        'Loại',
        kind: 'choice',
        choices: {
          'flight': tr(context, 'Flight', 'Máy bay'),
          'train': tr(context, 'Train', 'Tàu hỏa'),
          'bus': tr(context, 'Bus', 'Xe khách'),
          'hotel': tr(context, 'Hotel', 'Khách sạn'),
          'car': tr(context, 'Car', 'Xe'),
          'activity': tr(context, 'Activity', 'Hoạt động'),
          'other': tr(context, 'Other', 'Khác'),
        },
      ),
      const TripField('startDay', 'Start date', 'Ngày bắt đầu', kind: 'date'),
      foldField(context, key: 'startFold'),
      const TripField('startTime', 'Start time', 'Giờ bắt đầu', kind: 'time'),
      const TripField('endDay', 'End date', 'Ngày kết thúc', kind: 'date'),
      foldField(context, key: 'endFold'),
      const TripField('endTime', 'End time', 'Giờ kết thúc', kind: 'time'),
      const TripField('zone', 'Booking timezone', 'Múi giờ đặt chỗ'),
      const TripField('provider', 'Provider', 'Nhà cung cấp', optional: true),
      const TripField(
        'code',
        'Private confirmation code',
        'Mã xác nhận riêng tư',
        optional: true,
      ),
      const TripField(
        'address',
        'Private address',
        'Địa chỉ riêng tư',
        optional: true,
      ),
      const TripField(
        'note',
        'Private notes',
        'Ghi chú riêng tư',
        kind: 'note',
        optional: true,
      ),
      TripField(
        'currency',
        'Currency',
        'Tiền tệ',
        kind: 'choice',
        choices: {for (final c in currencyScales.keys) c: c},
      ),
      const TripField(
        'cost',
        'Booking cost (informational, not charged twice)',
        'Giá đặt chỗ (tham khảo, không tự cộng chi tiêu)',
        kind: 'number',
      ),
      const TripField(
        'remind',
        'Remind one hour before start (enable OS permission separately)',
        'Nhắc trước 1 giờ (bật quyền OS riêng)',
        kind: 'toggle',
      ),
    ],
    {
      'title': old?.title ?? '',
      'type': old?.type ?? 'other',
      'startDay': old == null
          ? trip.start
          : localDay(DateTime.parse(old.start), old.zone),
      'endDay': old == null
          ? trip.start
          : localDay(DateTime.parse(old.end), old.zone),
      'startFold': lateFoldAt(old?.start, old?.zone ?? trip.zone)
          ? 'later'
          : 'earlier',
      'endFold': lateFoldAt(old?.end, old?.zone ?? trip.zone)
          ? 'later'
          : 'earlier',
      'startTime': old == null
          ? '09:00'
          : localClock(DateTime.parse(old.start), old.zone),
      'endTime': old == null
          ? '10:00'
          : localClock(DateTime.parse(old.end), old.zone),
      'zone': old?.zone ?? trip.zone,
      'provider': old?.text('provider') ?? '',
      'code': old?.code ?? '',
      'address': old?.text('address') ?? '',
      'note': old?.text('note') ?? '',
      'currency':
          old?.text('currency', fallback: trip.currency) ?? trip.currency,
      'cost': old == null
          ? '0'
          : amount(
              minorValue(old.data['cost'] ?? '0'),
              old.text('currency', fallback: trip.currency),
            ),
      'remind':
          old != null &&
          scope.state.alarms.any(
            (a) => a.type == 'booking' && a.target == old.key,
          ),
    },
    (v) async {
      final start = editedInstant(
            old?.start,
            old?.zone,
            v['startDay'],
            v['startTime'],
            v['zone'],
            lateFold: v['startFold'] == 'later',
          ),
          end = editedInstant(
            old?.end,
            old?.zone,
            v['endDay'],
            v['endTime'],
            v['zone'],
            lateFold: v['endFold'] == 'later',
          ),
          booking = Booking({
            ...?old?.toJson(),
            ...v,
            'id': old?.key ?? newId(),
            'trip': trip.key,
            'start': start.toIso8601String(),
            'end': end.toIso8601String(),
            'cost': money(v['cost'], v['currency']).toString(),
            'assets': files.ids,
          });
      await scope.controller.change((s) {
        var next = files.apply(s).put('bookings', booking);
        next = next.copy({
          'alarms': next.alarms
              .where((a) => !(a.type == 'booking' && a.target == booking.key))
              .map((a) => a.toJson())
              .toList(),
        });
        if (v['remind'] == true)
          next = next.put(
            'alarms',
            TripAlarm({
              'id': newId(),
              'trip': trip.key,
              'target': booking.key,
              'type': 'booking',
              'at': start.subtract(const Duration(hours: 1)).toIso8601String(),
              'zone': v['zone'],
              'enabled': true,
            }),
          );
        return next;
      });
    },
    footer: [AttachmentChooser(scope: scope, selection: files)],
  );
}
