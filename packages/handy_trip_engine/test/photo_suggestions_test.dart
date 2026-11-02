import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:image/image.dart' as img;
import 'domain_test.dart' show fixture;

Uint8List photo({
  String date = '2026:03:08 10:30:12',
  String? offset = '+07:00',
  String ref = 'N',
}) {
  final image = img.Image(width: 24, height: 16);
  image.exif.exifIfd['DateTimeOriginal'] = date;
  if (offset != null) image.exif.exifIfd['OffsetTimeOriginal'] = offset;
  image.exif.gpsIfd.gpsLatitudeRef = ref;
  image.exif.gpsIfd.gpsLongitudeRef = 'E';
  image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational.list([
    img.IfdValueRational(10, 1).toRational(),
    img.IfdValueRational(46, 1).toRational(),
    img.IfdValueRational(48, 1).toRational(),
  ]);
  image.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational.list([
    img.IfdValueRational(106, 1).toRational(),
    img.IfdValueRational(42, 1).toRational(),
    img.IfdValueRational(0, 1).toRational(),
  ]);
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  test(
    'real EXIF rational DMS/offset is a proposal, never a visit or mutated original',
    () {
      final bytes = photo(),
          original = Uint8List.fromList(bytes),
          state = fixture(),
          before = jsonEncode(state.toJson());
      final proposal = readPhotoMetadata(bytes, 'Asia/Ho_Chi_Minh');
      expect(
        proposal['geo'],
        isNotNull,
        reason:
            '$proposal / ${img.decodeJpg(bytes)!.exif.gpsIfd.data.map((k, v) => MapEntry(k, "${v.type}/${v.length}/$v"))}',
      );
      expect(
        (proposal['geo']['lat'] as num).toDouble(),
        closeTo(10.78, 0.000001),
      );
      expect(proposal['geo']['lon'], 106.7);
      expect(
        DateTime.parse(proposal['at']),
        DateTime.utc(2026, 3, 8, 3, 30, 12),
      );
      expect(bytes, original);
      expect(jsonEncode(state.toJson()), before);
      expect(state.visits, isEmpty);
      final nearby = state.put(
        'places',
        Place({
          'id': 'near',
          'name': 'Manually entered place',
          'geo': {'lat': 10.7801, 'lon': 106.7},
        }),
      );
      expect(
        nearbyPhotoPlaces(
          nearby,
          Geo.fromJson(object(proposal['geo'])),
        ).single['placeId'],
        'near',
      );
      expect(proposal['warnings'].toString(), contains('not proof'));
    },
  );
  test(
    'ambiguous camera time and invalid GPS remain unknown instead of guessing',
    () {
      final result = readPhotoMetadata(
        photo(date: '2026:11:01 01:30:00', offset: null, ref: 'X'),
        'America/New_York',
      );
      expect(result['at'], isNull);
      expect(result['geo'], isNull);
      expect(result['warnings'].toString(), contains('ambiguous'));
      expect(
        readPhotoMetadata(photo(date: '2026:02:31 12:00:00'), 'UTC')['at'],
        isNull,
      );
      expect(
        () => readPhotoMetadata(Uint8List.fromList([1, 2, 3]), 'UTC'),
        throwsFormatException,
      );
    },
  );
  test(
    'static PNG is supported and missing metadata creates no fabricated suggestions',
    () {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 2, height: 2)),
      );
      expect(prepareAsset('alpha.png', bytes).asset.mime, 'image/png');
      final result = readPhotoMetadata(bytes, 'UTC');
      expect(result['geo'], isNull);
      expect(result['at'], isNull);
    },
  );
}
