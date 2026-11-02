part of '../handy_trip_engine.dart';

Json readPhotoMetadata(Uint8List bytes, String assumedZone) {
  location(assumedZone);
  if (bytes.isEmpty || bytes.length > 12000000)
    throw const FormatException('Photo exceeds 12 MB');
  final decoder = img.findDecoderForData(bytes),
      info = decoder?.startDecode(bytes);
  if (info == null ||
      info.numFrames != 1 ||
      info.width * info.height > 16000000)
    throw const FormatException('Invalid/static image required or over 16 MP');
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Cannot decode photo');
  final warnings = <String>[],
      gps = image.exif.gpsIfd,
      exif = image.exif.exifIfd;
  Geo? point;
  String? at;
  try {
    double? coordinate(int tag, int refTag, List<String> refs) {
      final value = gps.data[tag],
          ref = gps.data[refTag]
              ?.toString()
              .replaceAll('\u0000', '')
              .trim()
              .toUpperCase();
      if (value == null || ref == null) return null;
      if (!refs.contains(ref))
        throw const FormatException('Invalid GPS hemisphere');
      if (value.length != 1 && value.length != 3)
        throw const FormatException('Invalid coordinate components');
      final degrees = value.toDouble(0),
          minutes = value.length == 3 ? value.toDouble(1) : 0.0,
          seconds = value.length == 3 ? value.toDouble(2) : 0.0;
      if (!degrees.isFinite ||
          !minutes.isFinite ||
          !seconds.isFinite ||
          degrees < 0 ||
          minutes < 0 ||
          minutes >= 60 ||
          seconds < 0 ||
          seconds >= 60)
        throw const FormatException('Invalid photo coordinate');
      return (degrees + minutes / 60 + seconds / 3600) *
          (ref == refs.last ? -1 : 1);
    }

    final lat = coordinate(2, 1, ['N', 'S']),
        lon = coordinate(4, 3, ['E', 'W']);
    if (lat != null && lon != null) point = Geo(lat, lon);
  } catch (_) {
    warnings.add('Invalid GPS metadata; coordinates ignored.');
  }
  final raw = (exif['DateTimeOriginal'] ?? image.exif.imageIfd['DateTime'])
          ?.toString()
          .replaceAll('\u0000', '')
          .trim(),
      offset = exif['OffsetTimeOriginal']
          ?.toString()
          .replaceAll('\u0000', '')
          .trim();
  if (raw != null) {
    try {
      final m = RegExp(
        r'^(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)$',
      ).firstMatch(raw);
      if (m == null) throw const FormatException('Invalid camera date');
      final day = '${m[1]}-${m[2]}-${m[3]}',
          time = '${m[4]}:${m[5]}',
          seconds = int.parse(m[6]!);
      if (seconds > 59) throw const FormatException('Invalid camera seconds');
      if (offset != null) {
        at = instant('${day}T$time:${m[6]}$offset');
      } else {
        at = localInstant(
          day,
          time,
          assumedZone,
        ).add(Duration(seconds: seconds)).toUtc().toIso8601String();
        warnings.add(
          'Camera has no timezone offset. Your selected timezone is an assumption to review.',
        );
      }
    } catch (_) {
      warnings.add(
        'Camera date is invalid, ambiguous or in a DST gap. Enter the actual time manually.',
      );
    }
  }
  if (point == null && at == null)
    warnings.add('No usable position or date metadata. No visit was created.');
  warnings.add(
    'Photo clocks/GPS can be wrong; metadata is a proposal, not proof of a visit. Accuracy is unknown.',
  );
  return {
    'geo': point?.toJson(),
    'at': at,
    'zone': assumedZone,
    'warnings': warnings,
    'hasOffset': offset != null,
  };
}

List<Json> nearbyPhotoPlaces(
  TripState s,
  Geo point, {
  double withinMeters = 250,
}) {
  if (!withinMeters.isFinite || withinMeters < 0 || withinMeters > 10000)
    throw const FormatException('Invalid search radius');
  final results = <Json>[];
  for (final p in s.places.where((p) => p.geo != null)) {
    final lat1 = point.lat * pi / 180,
        lat2 = p.geo!.lat * pi / 180,
        dLat = lat2 - lat1,
        dLon = (p.geo!.lon - point.lon) * pi / 180;
    final a =
            pow(sin(dLat / 2), 2) +
            cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2),
        distance =
            6371000 * 2 * atan2(sqrt(a.clamp(0, 1)), sqrt((1 - a).clamp(0, 1)));
    if (distance <= withinMeters)
      results.add({'placeId': p.key, 'distanceMeters': distance});
  }
  results.sort(
    (a, b) => (a['distanceMeters'] as double).compareTo(
      b['distanceMeters'] as double,
    ),
  );
  return results.take(5).toList();
}
