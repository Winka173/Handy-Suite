part of '../handy_trip_engine.dart';

Json exportItineraryRecipe(TripState s, String tripId) {
  final trip = s.trip(tripId);
  return {
    'app': 'handy-trip-itinerary',
    'schema': 1,
    'title': redactBookingCodes(s, trip.title),
    'zone': trip.zone,
    'privacy':
        'Public itinerary recipe only; no history, finance, notes, booking data, photo assets or GPS. Choose an existing target trip with matching dates when importing.',
    'stops': [
      for (final stop in s.stops.where((v) => v.trip == tripId))
        {
          'title': redactBookingCodes(s, stop.title),
          'day': stop.on,
          'time': stop.time ?? '',
          'endTime': stop.endTime,
          'endOffset': stop.endOffset,
          'duration': stop.duration,
          'type': stop.type,
          'lateFold': stop.data['lateFold'] == true,
          'order': stop.order,
          'placeName': stop.place == null
              ? ''
              : redactBookingCodes(s, s.place(stop.place!).name),
        },
    ],
  };
}

TripState importPlacesTable(
  TripState state,
  List<List<String>> rows, {
  required int nameColumn,
  int? urlColumn,
  int? latitudeColumn,
  int? longitudeColumn,
  int? cityColumn,
  int? countryColumn,
}) {
  if (rows.isEmpty || rows.length > 10001)
    throw const FormatException('At most 10000 place rows');
  final added = <Place>[];
  for (final row in rows.skip(1)) {
    String cell(int? n) => n == null
        ? ''
        : n < 0 || n >= row.length
        ? throw const FormatException('Place column missing')
        : row[n].trim();
    final lat = cell(latitudeColumn), lon = cell(longitudeColumn);
    final p = Place({
      'id': newId(),
      'name': cell(nameColumn),
      'url': cell(urlColumn),
      'city': cell(cityColumn),
      'country': cell(countryColumn),
      'wishlist': true,
      'geo': lat.isEmpty && lon.isEmpty
          ? null
          : Geo(num.parse(lat), num.parse(lon)).toJson(),
    });
    final candidates = TripState(places: [...state.places, ...added]);
    if (clearDuplicate(candidates, p) == null) added.add(p);
  }
  return state.copy({
    'places': [
      ...state.places.map((p) => p.toJson()),
      ...added.map((p) => p.toJson()),
    ],
  });
}

/// Documented JSON interchange, not a private relational backup or location proof.
TripState importItineraryJson(TripState state, String tripId, Json input) {
  if (input['app'] != 'handy-trip-itinerary' ||
      input['schema'] != 1 ||
      input['stops'] is! List)
    throw const FormatException('Unsupported itinerary JSON schema');
  final records = input['stops'] as List;
  if (records.length > 10000)
    throw const FormatException('At most 10000 stops');
  final trip = state.trip(tripId), added = <Json>[];
  if (input['zone'] != null && input['zone'] != trip.zone)
    throw const FormatException(
      'Recipe timezone differs from target; review/convert explicitly before import',
    );
  for (final record in records) {
    final row = object(record),
        placeName = string(row['placeName'] ?? '', max: 300);
    final matches = state.places
        .where(
          (p) =>
              placeName.isNotEmpty &&
              p.name.toLowerCase() == placeName.toLowerCase(),
        )
        .toList();
    final time = string(row['time'] ?? ''), end = string(row['endTime'] ?? '');
    added.add(
      Stop({
        'id': newId(),
        'trip': tripId,
        'title': string(row['title'], max: 300, required: true),
        'day': string(row['day']),
        'time': time.isEmpty ? null : time,
        'endTime': end.isEmpty ? null : end,
        'endOffset': row['endOffset'] ?? 0,
        'duration': row['duration'] ?? 0,
        'type': row['type'] ?? 'activity',
        'lateFold': row['lateFold'] == true,
        'order':
            row['order'] ??
            (state.stops
                    .where((s) => s.trip == tripId && s.on == row['day'])
                    .length +
                added.where((s) => s['day'] == row['day']).length),
        'place': matches.length == 1 ? matches.single.key : null,
        'status': 'planned',
        'note': placeName.isEmpty || matches.length == 1
            ? ''
            : 'Unmatched place label: $placeName',
      }).toJson(),
    );
  }
  return state.copy({
    'stops': [...state.stops.map((s) => s.toJson()), ...added],
  });
}

TripState importItineraryTable(
  TripState state,
  String tripId,
  List<List<String>> rows, {
  required int titleColumn,
  required int dayColumn,
  int? timeColumn,
  int? placeColumn,
}) {
  if (rows.length > 10001 || rows.isEmpty)
    throw const FormatException('At most 10000 CSV rows');
  final trip = state.trip(tripId), added = <Json>[];
  for (final row in rows.skip(1)) {
    String cell(int i) => i < 0 || i >= row.length
        ? throw const FormatException('CSV column missing')
        : row[i].trim();
    final on = cell(dayColumn),
        name = cell(titleColumn),
        time = timeColumn == null ? null : cell(timeColumn),
        placeName = placeColumn == null ? '' : cell(placeColumn);
    final matches = state.places
        .where(
          (p) =>
              placeName.isNotEmpty &&
              p.name.toLowerCase() == placeName.toLowerCase(),
        )
        .toList();
    final stop = Stop({
      'id': newId(),
      'trip': trip.key,
      'title': name,
      'day': on,
      'time': time == null || time.isEmpty ? null : time,
      'place': matches.length == 1 ? matches.single.key : null,
      'order':
          state.stops.where((s) => s.trip == tripId && s.on == on).length +
          added.where((s) => s['day'] == on).length,
      'status': 'planned',
      'note': placeName.isEmpty || matches.length == 1
          ? ''
          : 'Unmatched place label: $placeName',
    });
    added.add(stop.toJson());
  }
  return state.copy({
    'stops': [...state.stops.map((s) => s.toJson()), ...added],
  });
}

String _icsUnescape(String s) => s.replaceAllMapped(
  RegExp(r'\\([\\nN,;])'),
  (m) => m[1]!.toLowerCase() == 'n' ? '\n' : m[1]!,
);
TripState importIcs(TripState state, String tripId, String source) {
  if (utf8.encode(source).length > 3000000 || source.contains('\u0000'))
    throw const FormatException('ICS exceeds 3 MB / contains null');
  final trip = state.trip(tripId),
      lines = source
          .replaceAll(RegExp(r'\r?\n[ \t]'), '')
          .split(RegExp(r'\r?\n')),
      events = <Json>[];
  Json? current;
  for (final line in lines) {
    if (line == 'BEGIN:VEVENT') {
      if (current != null) throw const FormatException('Nested event');
      current = {};
    } else if (line == 'END:VEVENT') {
      if (current == null) throw const FormatException('Unexpected event end');
      events.add(current);
      if (events.length > 10000) throw const FormatException('Too many events');
      current = null;
    } else if (current != null) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      final key = line.substring(0, i);
      if (current.containsKey(key))
        throw const FormatException('Duplicate ICS property');
      current[key] = line.substring(i + 1);
    }
  }
  if (current != null ||
      !lines.contains('BEGIN:VCALENDAR') ||
      !lines.contains('END:VCALENDAR') ||
      events.isEmpty)
    throw const FormatException('Incomplete/empty calendar');
  final stops = {for (final s in state.stops) s.key: s};
  for (final e in events) {
    if (e.keys.any(
      (k) => k.startsWith('RRULE') || k.startsWith('RECURRENCE-ID'),
    ))
      throw const FormatException(
        'Recurring ICS events are unsupported; expand them first',
      );
    final startKey = e.keys
        .where((k) => k == 'DTSTART' || k.startsWith('DTSTART;'))
        .firstOrNull;
    if (startKey == null) throw const FormatException('ICS needs DTSTART');
    ({String date, String? time, DateTime? utc}) parse(String key, String raw) {
      if (key.contains('VALUE=DATE')) {
        if (!RegExp(r'^\d{8}$').hasMatch(raw))
          throw const FormatException('Invalid all-day date');
        final d =
            '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
        date(d);
        return (date: d, time: null, utc: null);
      }
      if (!RegExp(r'^\d{8}T\d{6}Z?$').hasMatch(raw))
        throw const FormatException(
          'Only minute/second ICS clock values supported',
        );
      final d =
              '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}',
          t = '${raw.substring(9, 11)}:${raw.substring(11, 13)}';
      if (raw.substring(13, 15) != '00')
        throw const FormatException(
          'ICS seconds cannot be represented without loss; use minute boundaries',
        );
      final zone = key.contains('TZID=')
          ? key.split('TZID=').last.split(';').first
          : trip.zone;
      final utc = raw.endsWith('Z')
          ? DateTime.parse(instant('${d}T$t:00Z'))
          : localInstant(d, t, zone);
      final local = tz.TZDateTime.from(utc, location(trip.zone));
      return (
        date: day(local),
        time:
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
        utc: utc,
      );
    }

    final start = parse(startKey, e[startKey]),
        endKey = e.keys
            .where((k) => k == 'DTEND' || k.startsWith('DTEND;'))
            .firstOrNull,
        end = endKey == null ? null : parse(endKey, e[endKey]);
    final uid = string(e['UID'] ?? newId(), max: 1000),
        key = uid.endsWith('@handy-trip')
            ? id(uid.split('@').first)
            : sha256.convert(utf8.encode(uid)).toString().substring(0, 32);
    final stop = Stop({
      'id': key,
      'trip': tripId,
      'title': _icsUnescape(
        string(e['SUMMARY'] ?? 'Imported event', max: 1000),
      ),
      'day': start.date,
      'time': start.time,
      'endTime': end?.time,
      'endOffset': end == null || start.time == null
          ? 0
          : date(end.date).difference(date(start.date)).inDays,
      'duration': 0,
      'type': 'activity',
      'status': 'planned',
      'order': stops.values
          .where((s) => s.on == start.date && s.trip == tripId)
          .length,
      'lateFold': start.time == null
          ? false
          : localInstant(start.date, start.time!, trip.zone, lateFold: false) !=
                start.utc,
    });
    final old = stops[key];
    if (old != null) {
      if (old.trip != tripId ||
          old.title != stop.title ||
          old.on != stop.on ||
          old.time != stop.time ||
          old.endTime != stop.endTime)
        throw const FormatException('Conflicting calendar UID');
      continue;
    }
    stops[key] = stop;
  }
  return state.copy({'stops': stops.values.map((s) => s.toJson()).toList()});
}
