part of '../handy_trip_engine.dart';

TripState saveTrip(TripState s, Trip value) {
  final previous = s.trips.where((t) => t.key == value.key).firstOrNull;
  final outside = s.stops.where(
    (v) =>
        v.trip == value.key &&
        (v.on.compareTo(value.start) < 0 || v.on.compareTo(value.end) > 0),
  );
  if (outside.isNotEmpty)
    throw const FormatException(
      'Move out-of-range stops before changing dates; none were removed',
    );
  if (previous != null && previous.currency != value.currency) {
    s = s.copy({
      'stops': s.stops
          .map(
            (stop) => stop.trip == value.key && stop.data['currency'] == null
                ? stop.copy({'currency': previous.currency}).toJson()
                : stop.toJson(),
          )
          .toList(),
    });
  }
  return s.put('trips', value);
}

Map<String, BigInt> estimateTotals(TripState s, String tripId) {
  final values = <String, BigInt>{}, base = s.trip(tripId).currency;
  for (final stop in s.stops.where((v) => v.trip == tripId)) {
    final currency = stop.text('currency', fallback: base);
    values[currency] =
        (values[currency] ?? BigInt.zero) +
        minorValue(stop.data['estimate'] ?? '0');
  }
  return values;
}

List<Stop> itinerary(TripState s, String tripId, String on) =>
    s.stops.where((v) => v.trip == tripId && v.on == on).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
TripState reorderStops(
  TripState s,
  String tripId,
  String on,
  List<String> keys,
) {
  final existing = itinerary(s, tripId, on).map((v) => v.key).toSet();
  if (keys.length != existing.length ||
      keys.toSet().length != keys.length ||
      !keys.toSet().containsAll(existing))
    throw const FormatException('Reorder must be a permutation');
  return s.copy({
    'stops': s.stops
        .map(
          (v) => v.trip == tripId && v.on == on
              ? v.copy({'order': keys.indexOf(v.key)}).toJson()
              : v.toJson(),
        )
        .toList(),
  });
}

List<(String, String)> overlaps(TripState s, String tripId) {
  final intervals = <({Stop stop, DateTime start, DateTime end})>[];
  final t = s.trip(tripId);
  for (final stop in s.stops.where((v) => v.trip == tripId && v.time != null)) {
    final a = date(stop.on).add(Duration(minutes: minute(stop.time!))),
        b = stop.endTime != null
            ? date(
                addDays(stop.on, stop.endOffset),
              ).add(Duration(minutes: minute(stop.endTime!)))
            : a.add(Duration(minutes: stop.duration));
    if (b.isAfter(a)) intervals.add((stop: stop, start: a, end: b));
  }
  // Wall-calendar intervals intentionally warn without forbidding; zone belongs to trip.
  location(t.zone);
  intervals.sort((a, b) => a.start.compareTo(b.start));
  final result = <(String, String)>[];
  for (var i = 0; i < intervals.length; i++) {
    for (
      var j = i + 1;
      j < intervals.length && intervals[j].start.isBefore(intervals[i].end);
      j++
    ) {
      result.add((intervals[i].stop.key, intervals[j].stop.key));
    }
  }
  return result;
}

Place? clearDuplicate(TripState s, Place value) => s.places
    .where(
      (p) =>
          p.key != value.key &&
          (value.data['externalId'] != null &&
                  value.data['externalId'] == p.data['externalId'] ||
              p.name.trim().toLowerCase() == value.name.trim().toLowerCase() &&
                  p.geo != null &&
                  value.geo != null &&
                  (p.geo!.lat - value.geo!.lat).abs() < 0.000001 &&
                  (p.geo!.lon - value.geo!.lon).abs() < 0.000001),
    )
    .firstOrNull;
TripState savePlace(TripState s, Place value) {
  if (clearDuplicate(s, value) != null)
    throw const FormatException('Clear duplicate: use the existing place');
  return s.put('places', value);
}

TripState projectVisits(TripState s) => s.copy({
  'stops': s.stops
      .map(
        (stop) => stop.copy({
          'status':
              (stop.data['manualComplete'] == true && stop.place == null) ||
                  s.visits.any((v) => v.stop == stop.key && v.confirmed)
              ? 'visited'
              : stop.status == 'visited'
              ? 'planned'
              : stop.status,
        }).toJson(),
      )
      .toList(),
});
TripState checkIn(
  TripState s,
  Visit value, {
  CapturedLocation? fix,
  bool acceptCaution = false,
  DateTime? now,
}) {
  if (!value.confirmed)
    throw const FormatException('Confirm the visit before saving');
  if (DateTime.parse(
    instant(value.at),
  ).isAfter((now ?? DateTime.now()).toUtc().add(const Duration(minutes: 5))))
    throw const FormatException('A visit cannot be in the future');
  final old = s.visits.where((v) => v.key == value.key).firstOrNull;
  if (old != null) {
    if (jsonEncode(old.toJson()) == jsonEncode(value.toJson())) return s;
    throw const FormatException('Duplicate visit ID; edit explicitly');
  }
  if (value.origin == 'gps') {
    if (fix == null ||
        fix.requiresCaution(now ?? DateTime.now()) && !acceptCaution)
      throw const FormatException(
        'Review stale/coarse location before confirmation',
      );
    if (value.data['accuracy'] != fix.accuracy ||
        value.data['geo'] == null ||
        Geo.fromJson(object(value.data['geo'])).lat != fix.geo.lat ||
        Geo.fromJson(object(value.data['geo'])).lon != fix.geo.lon ||
        instant(value.data['capturedAt']) !=
            instant(fix.at.toUtc().toIso8601String()))
      throw const FormatException('GPS preview changed');
  }
  return projectVisits(s.put('visits', value));
}

TripState editVisit(TripState s, Visit value, {DateTime? now}) {
  if (!s.visits.any((v) => v.key == value.key))
    throw const FormatException('Visit was removed; reload before editing');
  if (value.confirmed &&
      DateTime.parse(value.at).isAfter(
        (now ?? DateTime.now()).toUtc().add(const Duration(minutes: 5)),
      ))
    throw const FormatException('A confirmed visit cannot be in the future');
  return projectVisits(
    s.copy({
      'visits': [
        for (final v in s.visits)
          v.key == value.key ? value.toJson() : v.toJson(),
      ],
      'notes': [
        for (final n in s.notes)
          n.ref('visit') == value.key
              ? n.copy({
                  'trip': value.trip,
                  'stop': n.trip == value.trip ? n.ref('stop') : null,
                }).toJson()
              : n.toJson(),
      ],
    }),
  );
}

TripState removeEntity(TripState s, String kind, String key) {
  if (kind == 'trips') {
    final visitIds = s.visits
            .where((v) => v.trip == key)
            .map((v) => v.key)
            .toSet(),
        stopIds = s.stops.where((v) => v.trip == key).map((v) => v.key).toSet();
    return s.copy({
      'trips': s.trips
          .where((v) => v.key != key)
          .map((v) => v.toJson())
          .toList(),
      'places': s.places
          .map(
            (v) => v.ref('targetTrip') == key
                ? v.copy({'targetTrip': null}).toJson()
                : v.toJson(),
          )
          .toList(),
      for (final k in ['stops', 'bookings', 'packing', 'expenses', 'alarms'])
        k: s
            .entities(k)
            .where((v) => v.text('trip') != key)
            .map((v) => v.toJson())
            .toList(),
      'visits': s.visits
          .map(
            (v) => v.trip == key
                ? v.copy({'trip': null, 'stop': null}).toJson()
                : v.toJson(),
          )
          .toList(),
      'notes': s.notes
          .map(
            (v) =>
                v.trip == key ||
                    visitIds.contains(v.ref('visit')) ||
                    stopIds.contains(v.ref('stop'))
                ? v.copy({'trip': null, 'stop': null}).toJson()
                : v.toJson(),
          )
          .toList(),
    });
  }
  if (kind == 'places' &&
      (s.visits.any((v) => v.place == key) ||
          s.stops.any((v) => v.place == key)))
    throw const FormatException('Place is referenced; keep it or unlink first');
  final changes = <String, dynamic>{
    kind: s
        .entities(kind)
        .where((v) => v.key != key)
        .map((v) => v.toJson())
        .toList(),
  };
  if (kind == 'visits')
    changes['notes'] = s.notes
        .map(
          (v) => v.ref('visit') == key
              ? v.copy({'visit': null}).toJson()
              : v.toJson(),
        )
        .toList();
  if (kind == 'stops') {
    changes['visits'] = s.visits
        .map(
          (v) => v.stop == key ? v.copy({'stop': null}).toJson() : v.toJson(),
        )
        .toList();
    changes['notes'] = s.notes
        .map(
          (v) => v.ref('stop') == key
              ? v.copy({'stop': null}).toJson()
              : v.toJson(),
        )
        .toList();
  }
  if (['stops', 'bookings', 'packing'].contains(kind))
    changes['alarms'] = s.alarms
        .where(
          (a) =>
              !(a.target == key &&
                  a.type ==
                      {
                        'stops': 'stop',
                        'bookings': 'booking',
                        'packing': 'packing',
                      }[kind]),
        )
        .map((a) => a.toJson())
        .toList();
  return projectVisits(s.copy(changes));
}

TripState duplicateTrip(TripState s, String sourceId, String firstDay) {
  final old = s.trip(sourceId),
      delta = date(firstDay).difference(date(old.start)).inDays,
      key = newId();
  var title = '';
  for (final rune in redactBookingCodes(s, old.title).runes) {
    final next = String.fromCharCode(rune);
    if (title.length + next.length > 193) break;
    title += next;
  }
  final now = DateTime.now().toUtc().toIso8601String();
  final trip = Trip({
    'id': key,
    'title': '$title (copy)',
    'destination': boundedLabel(redactBookingCodes(s, old.destination), 500),
    'start': firstDay,
    'end': addDays(old.end, delta),
    'zone': old.zone,
    'currency': old.currency,
    'budget': old.budget.toString(),
    'status': 'idea',
    'description': '',
    'cover': null,
    'created': now,
    'updated': now,
  });
  var next = s.put('trips', trip);
  for (final stop in s.stops.where((v) => v.trip == sourceId)) {
    next = next.put(
      'stops',
      Stop({
        'id': newId(),
        'trip': key,
        'place': stop.place,
        'title': boundedLabel(redactBookingCodes(s, stop.title), 300),
        'day': addDays(stop.on, delta),
        'status': 'planned',
        'note': '',
        'tags': [],
        'type': stop.type,
        'order': stop.order,
        'time': stop.time,
        'endTime': stop.endTime,
        'endOffset': stop.endOffset,
        'duration': stop.duration,
        'lateFold': stop.data['lateFold'] == true,
        'estimate': (stop.data['estimate'] ?? '0'),
        'currency': stop.text('currency', fallback: old.currency),
      }),
    );
  }
  for (final item in s.packing.where((v) => v.trip == sourceId)) {
    next = next.put(
      'packing',
      PackItem({
        'id': newId(),
        'trip': key,
        'title': boundedLabel(redactBookingCodes(s, item.title), 300),
        'list': boundedLabel(redactBookingCodes(s, item.text('list')), 200),
        'category': boundedLabel(
          redactBookingCodes(s, item.text('category')),
          200,
        ),
        'quantity': item.quantity,
        'weightGrams': item.data['weightGrams'] ?? 0,
        'order': item.order,
        'packed': false,
      }),
    );
  }
  return next;
}

Set<String> uniquePlaces(TripState s, {String? trip, int? year}) => s.visits
    .where(
      (v) =>
          v.confirmed &&
          (trip == null || v.trip == trip) &&
          (year == null ||
              localTime(DateTime.parse(v.at), v.zone).year == year),
    )
    .map((v) => v.place)
    .toSet();
Map<String, int> geography(TripState s, String field, {int? year}) {
  if (!['country', 'region', 'city'].contains(field))
    throw ArgumentError('Unknown geography');
  final counts = <String, int>{};
  for (final key in uniquePlaces(s, year: year)) {
    final p = s.place(key), label = p.text(field).trim();
    if (label.isNotEmpty) counts[label] = (counts[label] ?? 0) + 1;
  }
  return counts;
}

Map<String, BigInt> expenseTotals(TripState s, String tripId) {
  final result = <String, BigInt>{};
  for (final e in s.expenses.where((v) => v.trip == tripId))
    result[e.currency] = (result[e.currency] ?? BigInt.zero) + e.minor;
  return result;
}

TripState addPreparedAsset(TripState s, PreparedAsset p) {
  final meta = p.asset.copy({
    if (p.preview.isNotEmpty) 'preview': 'previews/${p.asset.key}.jpg',
    if (p.preview.isNotEmpty)
      'previewSha': sha256.convert(p.preview).toString(),
  });
  return s.copy(
    {
      'assets': [...s.assets.map((a) => a.toJson()), meta.toJson()],
    },
    files: {
      ...s.files,
      meta.path: p.original,
      if (p.preview.isNotEmpty) 'previews/${p.asset.key}.jpg': p.preview,
    },
  );
}

Set<String> referencedAssets(TripState s) => {
  for (final t in s.trips)
    if (t.cover != null) t.cover!,
  for (final v in s.visits) ...v.assets,
  for (final n in s.notes) ...n.assets,
  for (final b in s.bookings) ...b.list('assets'),
  for (final e in s.expenses)
    if (e.ref('receipt') != null) e.ref('receipt')!,
};
TripState pruneManagedCopies(TripState s) {
  final used = referencedAssets(s),
      kept = s.assets.where((a) => used.contains(a.key)).toList(),
      paths = {
        for (final a in kept) a.path,
        for (final a in kept)
          if (a.data['preview'] != null) a.data['preview'] as String,
      };
  return s.copy(
    {'assets': kept.map((v) => v.toJson()).toList()},
    files: {for (final p in paths) p: s.files[p]!},
  );
}

List<PackItem> packingTemplate(
  String tripId,
  String name, {
  bool vietnamese = false,
}) {
  const labels = {
    'Sun protection': 'Kem chống nắng',
    'Swimwear': 'Đồ bơi',
    'Water bottle': 'Bình nước',
    'Documents': 'Giấy tờ',
    'Charger': 'Bộ sạc',
    'Work clothes': 'Trang phục công tác',
    'Water': 'Nước uống',
    'Suitable shoes': 'Giày phù hợp',
    'First aid': 'Bộ sơ cứu',
    'Clothes': 'Quần áo',
    'Toiletries': 'Đồ vệ sinh cá nhân',
  };
  const lists = {
    'beach': 'Đi biển',
    'business': 'Công tác',
    'hiking': 'Đi bộ đường dài',
    'weekend': 'Cuối tuần',
  };
  final names = switch (name) {
    'beach' => ['Sun protection', 'Swimwear', 'Water bottle'],
    'business' => ['Documents', 'Charger', 'Work clothes'],
    'hiking' => ['Water', 'Suitable shoes', 'First aid'],
    _ => ['Clothes', 'Toiletries', 'Charger'],
  };
  return [
    for (var i = 0; i < names.length; i++)
      PackItem({
        'id': newId(),
        'trip': tripId,
        'title': vietnamese ? labels[names[i]] ?? names[i] : names[i],
        'list': vietnamese ? lists[name] ?? name : name,
        'category': vietnamese ? 'Đồ thiết yếu' : 'Essentials',
        'quantity': 1,
        'packed': false,
        'order': i,
      }),
  ];
}
