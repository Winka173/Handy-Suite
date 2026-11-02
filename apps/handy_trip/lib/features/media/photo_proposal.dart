import 'package:flutter/foundation.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../checkins/editor.dart';

Json _read((Uint8List, String) input) => readPhotoMetadata(input.$1, input.$2);
String _warning(BuildContext context, String warning) {
  const translations = {
    'Invalid GPS metadata; coordinates ignored.':
        'Metadata GPS không hợp lệ; bỏ qua tọa độ.',
    'Camera has no timezone offset. Your selected timezone is an assumption to review.':
        'Máy ảnh không ghi offset múi giờ. Cần kiểm tra lại múi giờ bạn đã chọn.',
    'Camera date is invalid, ambiguous or in a DST gap. Enter the actual time manually.':
        'Giờ máy ảnh không hợp lệ, bị trùng hoặc rơi vào khoảng chuyển giờ mùa hè. Hãy nhập giờ thực tế.',
    'No usable position or date metadata. No visit was created.':
        'Không có metadata vị trí hoặc thời gian dùng được. Chưa tạo lượt ghé.',
    'Photo clocks/GPS can be wrong; metadata is a proposal, not proof of a visit. Accuracy is unknown.':
        'Giờ và GPS của ảnh có thể sai; metadata chỉ là gợi ý, không chứng minh lượt ghé. Không biết độ chính xác.',
  };
  return tr(context, warning, translations[warning] ?? warning);
}

Future<void> showPhotoProposal(
  BuildContext context,
  TripScope scope,
  String assetId,
) async {
  final asset = scope.state.assets.firstWhere((a) => a.key == assetId);
  Json? result;
  await tripForm(
    context,
    tr(context, 'Photo metadata proposal', 'Gợi ý từ metadata ảnh'),
    [
      const TripField(
        'zone',
        'Timezone you confirm if the camera recorded no offset',
        'Múi giờ bạn xác nhận khi máy ảnh không ghi offset',
      ),
    ],
    {'zone': scope.trip?.zone ?? 'Asia/Ho_Chi_Minh'},
    (v) async {
      result = await compute(_read, (
        scope.state.files[asset.path]!,
        v['zone'] as String,
      ));
    },
    saveLabel: tr(context, 'Read local metadata', 'Đọc metadata cục bộ'),
    footer: [
      Text(
        tr(
          context,
          'Reading creates no visit. Camera clocks and location tags can be wrong; there is no geocoding or network request.',
          'Đọc ảnh không tạo lượt ghé. Giờ máy ảnh và thẻ vị trí có thể sai; không geocode hay yêu cầu mạng.',
        ),
      ),
    ],
  );
  if (result == null || !context.mounted) return;
  final proposal = result!,
      geo = proposal['geo'] == null
          ? null
          : Geo.fromJson(object(proposal['geo'])),
      matches = geo == null ? <Json>[] : nearbyPhotoPlaces(scope.state, geo);
  final usable = geo != null || proposal['at'] != null;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        tr(context, 'Review photo suggestions', 'Kiểm tra gợi ý từ ảnh'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tr(context, 'Recorded time (displayed in your selected zone)', 'Giờ metadata (hiển thị theo múi giờ đã chọn)')}: ${proposal['at'] == null ? '—' : '${localDay(DateTime.parse(proposal['at']), proposal['zone'])} ${localClock(DateTime.parse(proposal['at']), proposal['zone'])} / ${proposal['zone']}'}',
            ),
            if (geo != null)
              Text(
                '${tr(context, 'Photo coordinates, accuracy unknown', 'Tọa độ ảnh, không biết độ chính xác')}: ${geo.lat.toStringAsFixed(5)}, ${geo.lon.toStringAsFixed(5)}',
              ),
            for (final warning in proposal['warnings'] as List)
              Text(_warning(context, warning as String)),
            for (final match in matches)
              Text(
                '${tr(context, 'Nearby saved label (not proof)', 'Nhãn đã lưu ở gần (không phải bằng chứng)')}: ${scope.state.place(match['placeId']).name} · ${(match['distanceMeters'] as double).round()} m',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        if (usable)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Review a check-in', 'Kiểm tra lượt ghé')),
          ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  await editCheckIn(
    context,
    scope,
    photoProposal: proposal,
    photoAsset: assetId,
    place: matches.length == 1
        ? scope.state.place(matches.single['placeId'])
        : null,
  );
}
