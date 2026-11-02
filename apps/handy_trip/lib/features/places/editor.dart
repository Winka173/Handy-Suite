import 'package:flutter/services.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';

Future<Place?> editPlace(
  BuildContext context,
  TripScope scope, {
  Place? old,
  String? url,
  String? name,
  String? note,
  String? shareId,
  Geo? suggestedGeo,
}) async {
  Place? result;
  await tripForm(
    context,
    tr(
      context,
      old == null ? 'Save a place' : 'Edit place',
      old == null ? 'Lưu địa điểm' : 'Sửa địa điểm',
    ),
    [
      const TripField(
        'name',
        'Place name (confirm manually)',
        'Tên địa điểm (xác nhận thủ công)',
      ),
      const TripField(
        'url',
        'Source HTTP(S) link — no location is inferred',
        'Link HTTP(S) nguồn — không tự suy đoán địa chỉ',
        optional: true,
      ),
      const TripField(
        'address',
        'Explicit address (optional)',
        'Địa chỉ nhập tay (tùy chọn)',
        optional: true,
      ),
      const TripField(
        'lat',
        'Latitude, -90 to 90 (optional)',
        'Vĩ độ, -90 đến 90 (tùy chọn)',
        kind: 'number',
        optional: true,
      ),
      const TripField(
        'lon',
        'Longitude, -180 to 180 (optional)',
        'Kinh độ, -180 đến 180 (tùy chọn)',
        kind: 'number',
        optional: true,
      ),
      for (final (key, en, vi) in [
        ('country', 'Confirmed country label', 'Tên quốc gia đã xác nhận'),
        ('region', 'Confirmed region label', 'Tên vùng đã xác nhận'),
        ('city', 'Confirmed city label', 'Tên thành phố đã xác nhận'),
      ])
        TripField(key, en, vi, optional: true),
      TripField(
        'category',
        'Category',
        'Nhóm',
        kind: 'choice',
        choices: {
          'food': tr(context, 'Food', 'Ăn uống'),
          'attraction': tr(context, 'Attraction', 'Tham quan'),
          'shopping': tr(context, 'Shopping', 'Mua sắm'),
          'lodging': tr(context, 'Lodging', 'Lưu trú'),
          'activity': tr(context, 'Activity', 'Hoạt động'),
          'other': tr(context, 'Other', 'Khác'),
        },
      ),
      const TripField(
        'note',
        'Private note',
        'Ghi chú riêng',
        kind: 'note',
        optional: true,
      ),
      const TripField(
        'tags',
        'Tags, comma-separated',
        'Nhãn, cách nhau bằng dấu phẩy',
        optional: true,
      ),
      const TripField(
        'priority',
        'Wishlist priority 0–9',
        'Ưu tiên wishlist 0–9',
        kind: 'number',
      ),
      const TripField(
        'wishlist',
        'Keep in wishlist',
        'Giữ trong wishlist',
        kind: 'toggle',
      ),
      const TripField('favorite', 'Favorite', 'Yêu thích', kind: 'toggle'),
      TripField(
        'targetTrip',
        'Wishlist target trip (optional)',
        'Chuyến dự định (tùy chọn)',
        kind: 'choice',
        optional: true,
        choices: {
          '': tr(context, 'Not assigned', 'Chưa gắn chuyến'),
          for (final t in scope.state.trips) t.key: t.title,
        },
      ),
    ],
    {
      'name': old?.name ?? name ?? '',
      'url': old?.url ?? url ?? '',
      'address': old?.address ?? '',
      'lat': old?.geo?.lat.toString() ?? suggestedGeo?.lat.toString() ?? '',
      'lon': old?.geo?.lon.toString() ?? suggestedGeo?.lon.toString() ?? '',
      'country': old?.text('country') ?? '',
      'region': old?.text('region') ?? '',
      'city': old?.text('city') ?? '',
      'category': old?.category ?? 'other',
      'note': old?.text('note') ?? note ?? '',
      'targetTrip': old?.ref('targetTrip') ?? '',
      'tags': old?.list('tags').join(', ') ?? '',
      'priority': '${old?.data['priority'] ?? 0}',
      'wishlist': old?.wishlist ?? true,
      'favorite': old?.favorite ?? false,
    },
    (v) async {
      final geo = (v['lat'] == '' && v['lon'] == '')
          ? null
          : Geo(num.parse(v['lat']), num.parse(v['lon']));
      final place = Place({
        ...?old?.toJson(),
        ...v,
        'id': old?.key ?? newId(),
        'geo': geo?.toJson(),
        'priority': int.parse(v['priority']),
        'targetTrip': v['targetTrip'] == '' ? null : v['targetTrip'],
        if (shareId != null) 'shareId': shareId,
        'tags': (v['tags'] as String)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      });
      await scope.controller.change((s) => savePlace(s, place));
      result = place;
    },
  );
  return result;
}

Future<void> pastePlace(BuildContext context, TripScope scope) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  if (!context.mounted) return;
  final text = data?.text?.trim() ?? '';
  final uri = Uri.tryParse(text);
  await editPlace(
    context,
    scope,
    url: uri != null && ['https', 'http'].contains(uri.scheme)
        ? safeUrl(text)
        : null,
    name: uri != null && ['https', 'http'].contains(uri.scheme)
        ? null
        : (text.length <= 300 ? text : null),
    note: text.length <= 10000 ? text : null,
  );
}
