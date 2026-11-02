import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../media/attachments.dart';

Future<void> editNote(
  BuildContext context,
  TripScope scope, {
  JournalNote? old,
  String? visit,
  String? stop,
}) async {
  final linkedStop = old?.ref('stop') ?? stop,
      linkedVisit = old?.ref('visit') ?? visit;
  final linked = linkedStop != null || linkedVisit != null;
  final linkedTrip = linkedStop != null
      ? scope.state.stops.firstWhere((s) => s.key == linkedStop).trip
      : linkedVisit != null
      ? scope.state.visits.firstWhere((v) => v.key == linkedVisit).trip
      : null;
  final photos = AttachmentSelection(old?.assets ?? []),
      zone = old?.zone ?? scope.trip?.zone ?? 'Asia/Ho_Chi_Minh',
      today = localDay(
        scope.clock(),
        old?.zone ?? scope.trip?.zone ?? 'Asia/Ho_Chi_Minh',
      );
  await tripForm(
    context,
    tr(
      context,
      old == null ? 'Add a memory' : 'Edit memory',
      old == null ? 'Thêm kỷ niệm' : 'Sửa kỷ niệm',
    ),
    [
      if (!linked)
        TripField(
          'trip',
          'Trip (optional)',
          'Chuyến đi (tùy chọn)',
          kind: 'choice',
          optional: true,
          choices: {
            '': tr(
              context,
              'No trip · spontaneous memory',
              'Không có chuyến · kỷ niệm tự do',
            ),
            for (final t in scope.state.trips) t.key: t.title,
          },
        ),
      const TripField('title', 'Memory title', 'Tên kỷ niệm', optional: true),
      const TripField(
        'body',
        'Private memory text',
        'Nội dung kỷ niệm riêng tư',
        kind: 'note',
        optional: true,
      ),
      const TripField('day', 'Memory date', 'Ngày kỷ niệm', kind: 'date'),
      foldField(context),
      const TripField('time', 'Memory time', 'Giờ kỷ niệm', kind: 'time'),
      const TripField('zone', 'IANA timezone', 'Múi giờ IANA'),
    ],
    {
      'trip': linked
          ? (linkedTrip ?? '')
          : old != null
          ? (old.trip ?? '')
          : (scope.trip?.key ?? ''),
      'title': old?.title ?? '',
      'body': old?.body ?? '',
      'day': old == null ? today : localDay(DateTime.parse(old.at), old.zone),
      'fold': lateFoldAt(old?.at, zone) ? 'later' : 'earlier',
      'time': localClock(
        old == null ? scope.clock() : DateTime.parse(old.at),
        zone,
      ),
      'zone': zone,
    },
    (v) async {
      final note = JournalNote({
        ...?old?.toJson(),
        'id': old?.key ?? newId(),
        'trip': linked ? linkedTrip : (v['trip'] == '' ? null : v['trip']),
        'visit': old?.ref('visit') ?? visit,
        'stop': old?.ref('stop') ?? stop,
        'title': v['title'],
        'body': v['body'],
        'at': editedInstant(
          old?.at,
          old == null ? null : zone,
          v['day'],
          v['time'],
          v['zone'],
          lateFold: v['fold'] == 'later',
        ).toIso8601String(),
        'zone': v['zone'],
        'assets': photos.ids,
      });
      await scope.controller.change((s) => photos.apply(s).put('notes', note));
    },
    footer: [
      AttachmentChooser(scope: scope, selection: photos, imagesOnly: true),
    ],
  );
}
