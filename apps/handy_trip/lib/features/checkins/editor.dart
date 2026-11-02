import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../media/attachments.dart';
import '../places/editor.dart';

Future<void> editCheckIn(
  BuildContext context,
  TripScope scope, {
  Stop? stop,
  Place? place,
  Visit? old,
  bool gps = false,
  Json? photoProposal,
  String? photoAsset,
}) async {
  var chosen = place?.key ?? stop?.place ?? old?.place;
  if (chosen == null && scope.state.places.isEmpty) {
    final created = await editPlace(
      context,
      scope,
      suggestedGeo: photoProposal?['geo'] == null
          ? null
          : Geo.fromJson(object(photoProposal!['geo'])),
    );
    if (created == null || !context.mounted) return;
    chosen = created.key;
  }
  CapturedLocation? fix;
  if (gps) {
    try {
      fix = await scope.locationPort.capture();
    } catch (_) {
      if (!context.mounted) return;
      final manual = await tripConfirm(
        context,
        tr(
          context,
          'Location unavailable or denied. Continue with a manual check-in?',
          'Vị trí không khả dụng hoặc bị từ chối. Tiếp tục ghi nhận thủ công?',
        ),
      );
      if (!manual) return;
    }
  }
  if (!context.mounted) return;
  final zone =
          old?.zone ??
          photoProposal?['zone'] as String? ??
          scope.trip?.zone ??
          'Asia/Ho_Chi_Minh',
      now = scope.clock().toUtc(),
      local = DateTime.parse(
        old?.at ?? photoProposal?['at'] as String? ?? now.toIso8601String(),
      ),
      visitId = old?.key ?? newId(),
      photos = AttachmentSelection(
        old?.assets ?? [if (photoAsset != null) photoAsset],
      );

  await tripForm(
    context,
    tr(
      context,
      old == null ? 'Confirm a visit' : 'Edit visit',
      old == null ? 'Xác nhận đã ghé thăm' : 'Sửa lượt ghé thăm',
    ),
    [
      if (stop == null && old?.stop == null)
        TripField(
          'trip',
          'Trip (optional; choose no trip for spontaneous visits)',
          'Chuyến đi (tùy chọn; chọn không có chuyến cho lượt ghé tự do)',
          kind: 'choice',
          optional: true,
          choices: {
            '': tr(
              context,
              'No trip · spontaneous',
              'Không có chuyến · ghé tự do',
            ),
            for (final t in scope.state.trips) t.key: t.title,
          },
        ),
      TripField(
        'place',
        'Place — no automatic location inference',
        'Địa điểm — không tự suy đoán vị trí',
        kind: 'choice',
        choices: {
          if (photoProposal != null)
            '': tr(
              context,
              'Choose the place you actually visited',
              'Chọn địa điểm bạn thực tế đã ghé',
            ),
          for (final p in scope.state.places)
            if (stop?.place == null || p.key == stop!.place) p.key: p.name,
        },
      ),
      const TripField(
        'day',
        'Actual visit date',
        'Ngày thực tế đã ghé',
        kind: 'date',
      ),
      const TripField(
        'time',
        'Actual visit time',
        'Giờ thực tế đã ghé',
        kind: 'time',
      ),
      const TripField(
        'zone',
        'Visit timezone (history keeps this zone)',
        'Múi giờ lượt ghé (lịch sử giữ múi giờ này)',
      ),
      TripField(
        'fold',
        'Repeated DST time',
        'Giờ trùng DST',
        kind: 'choice',
        choices: {
          'earlier': tr(context, 'First occurrence', 'Lần đầu'),
          'later': tr(context, 'Second occurrence', 'Lần sau'),
        },
      ),
      TripField(
        'rating',
        'Personal rating (optional)',
        'Đánh giá cá nhân (tùy chọn)',
        kind: 'choice',
        optional: true,
        choices: {
          '': tr(context, 'No rating', 'Không đánh giá'),
          for (var i = 1; i <= 5; i++) '$i': '$i / 5',
        },
      ),
      const TripField(
        'note',
        'Private visit note',
        'Ghi chú lượt ghé riêng tư',
        kind: 'note',
        optional: true,
      ),
      const TripField(
        'tags',
        'Personal tags, comma-separated',
        'Nhãn cá nhân, cách nhau bằng dấu phẩy',
        optional: true,
      ),
      const TripField(
        'confirmed',
        'I confirm that I visited this place',
        'Tôi xác nhận đã ghé địa điểm này',
        kind: 'toggle',
      ),
      if (fix != null)
        const TripField(
          'caution',
          'I reviewed this reading, including coarse accuracy / age',
          'Tôi đã kiểm tra độ chính xác / thời điểm của vị trí',
          kind: 'toggle',
        ),
      if (photoProposal?['geo'] != null)
        const TripField(
          'photoGeo',
          'Include reviewed photo coordinates in this private visit (accuracy unknown)',
          'Lưu tọa độ ảnh đã kiểm tra vào lượt ghé riêng tư (không biết độ chính xác)',
          kind: 'toggle',
        ),
    ],
    {
      'trip': old != null ? (old.trip ?? '') : (scope.trip?.key ?? ''),
      'place':
          chosen ?? (photoProposal != null ? '' : scope.state.places.first.key),
      'day': localDay(local, zone),
      'time': localClock(local, zone),
      'zone': zone,
      'fold': lateFoldAt(old?.at, zone) ? 'later' : 'earlier',
      'rating': old?.data['rating']?.toString() ?? '',
      'note': old?.note ?? '',
      'tags': old?.list('tags').join(', ') ?? '',
      'confirmed': old?.confirmed ?? false,
      'caution': false,
      'photoGeo': false,
    },
    (v) async {
      final at = editedInstant(
        old?.at ?? photoProposal?['at'] as String?,
        old?.zone ?? photoProposal?['zone'] as String?,
        v['day'],
        v['time'],
        v['zone'],
        lateFold: v['fold'] == 'later',
      ).toUtc().toIso8601String();
      final visit = Visit({
        ...?old?.toJson(),
        'id': visitId,
        'trip': old?.stop != null
            ? old!.trip
            : stop?.trip ?? (v['trip'] == '' ? null : v['trip']),
        'stop': old?.stop ?? stop?.key,
        'place': v['place'],
        'at': at,
        'zone': v['zone'],
        'origin': fix == null
            ? (old != null && DateTime.parse(at) == DateTime.parse(old.at)
                  ? old.origin
                  : 'manual')
            : 'gps',
        if (old == null && fix == null && photoProposal != null)
          'origin': 'photo-suggestion',
        'confirmed': v['confirmed'] == true,
        'rating': v['rating'] == '' ? null : int.parse(v['rating']),
        'note': v['note'],
        'tags': (v['tags'] as String)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'assets': photos.ids,
        'created': old?.data['created'] ?? now.toIso8601String(),
        'updated': scope.clock().toUtc().toIso8601String(),
        if (fix != null) 'geo': fix.geo.toJson(),
        if (fix != null) 'accuracy': fix.accuracy,
        if (fix != null) 'capturedAt': fix.at.toUtc().toIso8601String(),
        if (photoProposal?['geo'] != null && v['photoGeo'] == true)
          'geo': photoProposal!['geo'],
      });
      await scope.controller.change((s) {
        var next = photos.apply(s);
        if (stop != null && stop.place == null)
          next = next.put('stops', stop.copy({'place': v['place']}));
        return old == null
            ? checkIn(
                next,
                visit,
                fix: fix,
                acceptCaution: v['caution'] == true,
                now: scope.clock(),
              )
            : editVisit(next, visit, now: scope.clock());
      });
    },
    footer: [
      if (photoProposal != null)
        Text(
          tr(
            context,
            'Photo metadata is only a suggestion. Verify place/date/time; nothing counts as visited without your confirmation.',
            'Metadata ảnh chỉ là gợi ý. Kiểm tra nơi/ngày/giờ; chưa tính đã ghé nếu bạn chưa xác nhận.',
          ),
        ),
      if (fix != null)
        Text(
          '${tr(context, 'Captured GPS (not proof of visit)', 'GPS đã lấy (không phải bằng chứng đã ghé)')}: ${fix.geo.lat.toStringAsFixed(5)}, ${fix.geo.lon.toStringAsFixed(5)}\n±${fix.accuracy.round()}m · ${fix.at.toUtc().toIso8601String()}',
        ),
      AttachmentChooser(scope: scope, selection: photos, imagesOnly: true),
    ],
  );
}
