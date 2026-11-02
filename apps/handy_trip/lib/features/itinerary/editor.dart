import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../trips/editor.dart';

Future<void> editStop(
  BuildContext context,
  TripScope scope, {
  Stop? old,
  Place? place,
}) async {
  final trip = old == null
      ? await ensureTrip(context, scope)
      : scope.state.trip(old.trip);
  if (trip == null || !context.mounted) return;
  final currency =
      old?.text('currency', fallback: trip.currency) ?? trip.currency;
  await tripForm(
    context,
    tr(
      context,
      old == null ? 'Add stop / activity' : 'Edit activity',
      old == null ? 'Thêm điểm dừng / hoạt động' : 'Sửa hoạt động',
    ),
    [
      const TripField(
        'title',
        'Activity / stop name',
        'Tên hoạt động / điểm dừng',
      ),
      const TripField('day', 'Trip day', 'Ngày trong chuyến đi', kind: 'date'),
      TripField(
        'place',
        'Saved place (optional)',
        'Địa điểm đã lưu (tùy chọn)',
        kind: 'choice',
        optional: true,
        choices: {
          '': tr(context, 'No place: activity only', 'Không gắn địa điểm'),
          for (final p in scope.state.places) p.key: p.name,
        },
      ),
      TripField(
        'type',
        'Type',
        'Loại',
        kind: 'choice',
        choices: {
          'sightseeing': tr(context, 'Sightseeing', 'Tham quan'),
          'food': tr(context, 'Food', 'Ăn uống'),
          'transit': tr(context, 'Transit', 'Di chuyển'),
          'lodging': tr(context, 'Lodging', 'Lưu trú'),
          'activity': tr(context, 'Activity', 'Hoạt động'),
          'other': tr(context, 'Other', 'Khác'),
        },
      ),
      const TripField(
        'time',
        'Start time (optional)',
        'Giờ bắt đầu (tùy chọn)',
        kind: 'time',
        optional: true,
      ),
      const TripField(
        'endTime',
        'End time (optional)',
        'Giờ kết thúc (tùy chọn)',
        kind: 'time',
        optional: true,
      ),
      const TripField(
        'endOffset',
        'End day offset, 0–7 (1 = next day)',
        'Kết thúc sau 0–7 ngày (1 = hôm sau)',
        kind: 'number',
      ),
      const TripField(
        'duration',
        'Expected minutes if no end time',
        'Số phút dự kiến nếu chưa có giờ kết thúc',
        kind: 'number',
      ),
      TripField(
        'currency',
        'Estimated currency',
        'Ti\u1ec1n t\u1ec7 d\u1ef1 ki\u1ebfn',
        kind: 'choice',
        choices: {for (final c in currencyScales.keys) c: c},
      ),
      const TripField(
        'estimate',
        'Estimated cost (not an actual expense)',
        'Chi phí dự kiến (không phải khoản đã chi)',
        kind: 'number',
      ),
      const TripField(
        'note',
        'Private notes / transit instructions',
        'Ghi chú riêng / hướng dẫn di chuyển',
        kind: 'note',
        optional: true,
      ),
      const TripField(
        'tags',
        'Tags, comma-separated',
        'Nhãn, cách nhau bằng dấu phẩy',
        optional: true,
      ),
      TripField(
        'fold',
        'Repeated DST clock time',
        'Giờ trùng khi đổi DST',
        kind: 'choice',
        choices: {
          'earlier': tr(context, 'First occurrence', 'Lần đầu'),
          'later': tr(context, 'Second occurrence', 'Lần sau'),
        },
      ),
    ],
    {
      'currency': currency,
      'title': old?.title ?? place?.name ?? '',
      'day': old?.on ?? scope.selectedDay ?? trip.start,
      'place': old?.place ?? place?.key ?? '',
      'type': old?.type ?? 'activity',
      'time': old?.time ?? '',
      'endTime': old?.endTime ?? '',
      'endOffset': '${old?.endOffset ?? 0}',
      'duration': '${old?.duration ?? 60}',
      'estimate': old == null
          ? '0'
          : amount(minorValue(old.data['estimate'] ?? '0'), currency),
      'note': old?.text('note') ?? '',
      'tags': old?.list('tags').join(', ') ?? '',
      'fold': old?.data['lateFold'] == true ? 'later' : 'earlier',
    },
    (v) async {
      final time = v['time'] == '' ? null : v['time'],
          end = v['endTime'] == '' ? null : v['endTime'];
      if (time != null)
        localInstant(v['day'], time, trip.zone, lateFold: v['fold'] == 'later');
      final row = Stop({
        ...?old?.toJson(),
        ...v,
        'id': old?.key ?? newId(),
        'trip': trip.key,
        'place': v['place'] == '' ? null : v['place'],
        'time': time,
        'endTime': end,
        'endOffset': int.parse(v['endOffset']),
        'duration': int.parse(v['duration']),
        'estimate': money(v['estimate'], v['currency']).toString(),
        'order':
            old?.order ??
            scope.state.stops
                .where((s) => s.trip == trip.key && s.on == v['day'])
                .length,
        'status': old?.status ?? 'planned',
        'tags': (v['tags'] as String)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'lateFold': v['fold'] == 'later',
      });
      await scope.controller.change((s) {
        var next = s.put('stops', row);
        if (place != null && place.wishlist)
          next = next.put('places', place.copy({'wishlist': false}));
        return next;
      });
      scope.selectedDay = row.on;
    },
  );
}
