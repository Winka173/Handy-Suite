import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../media/attachments.dart';

Future<void> editTrip(
  BuildContext context,
  TripScope scope, [
  Trip? old,
]) async {
  final pictures = AttachmentSelection([if (old?.cover != null) old!.cover!]),
      now = scope.clock().toUtc().toIso8601String(),
      today = scope.today;
  await tripForm(
    context,
    tr(
      context,
      old == null ? 'New trip' : 'Edit trip',
      old == null ? 'Chuyến đi mới' : 'Sửa chuyến đi',
    ),
    [
      const TripField('title', 'Trip name', 'Tên chuyến đi'),
      const TripField(
        'destination',
        'Destination label (no lookup)',
        'Điểm đến (nhập tay, không tra cứu)',
        optional: true,
      ),
      const TripField(
        'description',
        'Private description',
        'Mô tả riêng tư',
        kind: 'note',
        optional: true,
      ),
      const TripField('start', 'First day', 'Ngày bắt đầu', kind: 'date'),
      const TripField(
        'end',
        'Last day (inclusive)',
        'Ngày kết thúc (tính cả ngày)',
        kind: 'date',
      ),
      const TripField(
        'zone',
        'IANA timezone, e.g. Asia/Ho_Chi_Minh',
        'Múi giờ IANA, ví dụ Asia/Ho_Chi_Minh',
      ),
      TripField(
        'status',
        'Trip state',
        'Trạng thái',
        kind: 'choice',
        choices: {
          'idea': tr(context, 'Idea', 'Ý tưởng'),
          'planned': tr(context, 'Planned', 'Đã lên lịch'),
          'ongoing': tr(context, 'Ongoing', 'Đang đi'),
          'completed': tr(context, 'Completed', 'Đã kết thúc'),
          'archived': tr(context, 'Archived', 'Đã lưu trữ'),
        },
      ),
      TripField(
        'currency',
        'Base currency (no auto exchange)',
        'Tiền tệ chính (không tự quy đổi)',
        kind: 'choice',
        choices: {for (final c in currencyScales.keys) c: c},
      ),
      const TripField(
        'budget',
        'Budget (decimal point, no thousands separator)',
        'Ngân sách (dấu chấm thập phân, không phân nhóm)',
        kind: 'number',
      ),
    ],
    {
      'title': old?.title ?? '',
      'destination': old?.destination ?? '',
      'description': old?.text('description') ?? '',
      'start': old?.start ?? today,
      'end': old?.end ?? today,
      'zone': old?.zone ?? scope.state.settings['zone'] ?? 'Asia/Ho_Chi_Minh',
      'status': old?.status ?? 'idea',
      'currency': old?.currency ?? 'VND',
      'budget': old == null ? '0' : amount(old.budget, old.currency),
    },
    (v) async {
      final trip = Trip({
        ...?old?.toJson(),
        ...v,
        'id': old?.key ?? newId(),
        'budget': money(v['budget'], v['currency']).toString(),
        'cover': pictures.ids.firstOrNull,
        'created': old?.data['created'] ?? now,
        'updated': scope.clock().toUtc().toIso8601String(),
      });
      await scope.controller.change((s) => saveTrip(pictures.apply(s), trip));
      scope.chooseTrip(trip.key);
    },
    footer: [
      AttachmentChooser(
        scope: scope,
        selection: pictures,
        imagesOnly: true,
        maxCount: 1,
      ),
    ],
  );
}

Future<Trip?> ensureTrip(BuildContext context, TripScope scope) async {
  if (scope.trip != null) return scope.trip;
  if (scope.state.trips.isEmpty) {
    await editTrip(context, scope);
    return scope.trip;
  }
  final key = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(tr(context, 'Choose a trip', 'Chọn chuyến đi')),
      children: [
        for (final t in scope.state.trips)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, t.key),
            child: Text(t.title),
          ),
      ],
    ),
  );
  if (key != null) scope.chooseTrip(key);
  return key == null ? null : scope.trip;
}
