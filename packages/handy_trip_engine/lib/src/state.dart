part of '../handy_trip_engine.dart';

const collections = [
  'trips',
  'places',
  'stops',
  'visits',
  'notes',
  'bookings',
  'packing',
  'expenses',
  'assets',
  'alarms',
];

class TripState {
  final int revision;
  final List<Trip> trips;
  final List<Place> places;
  final List<Stop> stops;
  final List<Visit> visits;
  final List<JournalNote> notes;
  final List<Booking> bookings;
  final List<PackItem> packing;
  final List<Expense> expenses;
  final List<MediaAsset> assets;
  final List<TripAlarm> alarms;
  final Map<String, Uint8List> files;
  final Json settings;
  TripState({
    this.revision = 0,
    List<Trip> trips = const [],
    List<Place> places = const [],
    List<Stop> stops = const [],
    List<Visit> visits = const [],
    List<JournalNote> notes = const [],
    List<Booking> bookings = const [],
    List<PackItem> packing = const [],
    List<Expense> expenses = const [],
    List<MediaAsset> assets = const [],
    List<TripAlarm> alarms = const [],
    Map<String, Uint8List> files = const {},
    Json settings = const {},
  }) : trips = List.unmodifiable(trips),
       places = List.unmodifiable(places),
       stops = List.unmodifiable(stops),
       visits = List.unmodifiable(visits),
       notes = List.unmodifiable(notes),
       bookings = List.unmodifiable(bookings),
       packing = List.unmodifiable(packing),
       expenses = List.unmodifiable(expenses),
       assets = List.unmodifiable(assets),
       alarms = List.unmodifiable(alarms),
       files = Map.unmodifiable(
         files.map(
           (k, v) => MapEntry(k, Uint8List.fromList(v).asUnmodifiableView()),
         ),
       ),
       settings = freeze(settings) as Json;
  List<Entity> entities(String kind) => switch (kind) {
    'trips' => trips,
    'places' => places,
    'stops' => stops,
    'visits' => visits,
    'notes' => notes,
    'bookings' => bookings,
    'packing' => packing,
    'expenses' => expenses,
    'assets' => assets,
    'alarms' => alarms,
    _ => throw ArgumentError('Unknown collection'),
  };
  Json toJson({bool includeData = true}) => {
    'app': 'handy-trip',
    'schema': 1,
    'revision': revision,
    'settings': settings,
    for (final kind in collections)
      kind: entities(kind).map((v) => v.toJson()).toList(),
    if (includeData) 'files': files.map((k, v) => MapEntry(k, base64Encode(v))),
  };
  factory TripState.fromJson(Json j, {Map<String, Uint8List>? files}) {
    if (j['app'] != 'handy-trip' || j['schema'] != 1)
      throw const FormatException('Unsupported Trip schema');
    List<T> rows<T>(String k, T Function(Json) parse) {
      final rows = j[k];
      if (rows is! List || rows.length > 100000)
        throw const FormatException('Invalid collection size');
      return rows.map((v) => parse(object(v))).toList();
    }

    final bytes =
        files ??
        object(
          j['files'] ?? {},
        ).map((k, v) => MapEntry(k, base64Decode(string(v, max: 17000000))));
    final s = TripState(
      revision: integer(j['revision']),
      trips: rows('trips', Trip.new),
      places: rows('places', Place.new),
      stops: rows('stops', Stop.new),
      visits: rows('visits', Visit.new),
      notes: rows('notes', JournalNote.new),
      bookings: rows('bookings', Booking.new),
      packing: rows('packing', PackItem.new),
      expenses: rows('expenses', Expense.new),
      assets: rows('assets', MediaAsset.new),
      alarms: rows('alarms', TripAlarm.new),
      files: bytes,
      settings: object(j['settings']),
    );
    s.validate();
    return s;
  }
  TripState copy(Json changes, {Map<String, Uint8List>? files}) =>
      TripState.fromJson({
        ...toJson(includeData: false),
        ...changes,
      }, files: files ?? this.files);
  TripState put(String kind, Entity item) => copy({
    kind: [
      for (final e in entities(kind))
        if (e.key != item.key) e.toJson(),
      item.toJson(),
    ],
  });
  late final _tripIndex = {for (final t in trips) t.key: t};
  late final _placeIndex = {for (final p in places) p.key: p};
  Trip trip(String key) =>
      _tripIndex[key] ?? (throw const FormatException('Missing trip'));
  Place place(String key) =>
      _placeIndex[key] ?? (throw const FormatException('Missing place'));
  void validate() {
    integer(revision);
    if (settings['zone'] != null) location(string(settings['zone']));
    for (final key in ['onboarded', 'notifications'])
      if (settings[key] != null && settings[key] is! bool)
        throw const FormatException('Invalid boolean preference');
    strings(settings['imports'] ?? []);
    if (!['system', 'en', 'vi'].contains(settings['locale'] ?? 'system') ||
        !['system', 'light', 'dark'].contains(settings['theme'] ?? 'system'))
      throw const FormatException('Invalid preferences');
    final ids = {
      for (final k in collections) k: entities(k).map((e) => e.key).toSet(),
    };
    for (final k in collections)
      if (ids[k]!.length != entities(k).length)
        throw const FormatException('Duplicate IDs');
    void link(String kind, String? key) {
      if (key != null && !ids[kind]!.contains(key))
        throw const FormatException('Missing reference');
    }

    for (final t in trips) link('assets', t.cover);
    for (final p in places) link('trips', p.ref('targetTrip'));
    for (final stop in stops) {
      link('trips', stop.trip);
      link('places', stop.place);
      final t = trip(stop.trip);
      if (stop.on.compareTo(t.start) < 0 || stop.on.compareTo(t.end) > 0)
        throw const FormatException('Stop outside trip dates');
      if (stop.time != null)
        localInstant(
          stop.on,
          stop.time!,
          t.zone,
          lateFold: stop.data['lateFold'] == true,
        );
      if (stop.endTime != null)
        localInstant(
          addDays(stop.on, stop.endOffset),
          stop.endTime!,
          t.zone,
          lateFold: stop.data['lateFold'] == true,
        );
    }
    for (final v in visits) {
      link('trips', v.trip);
      link('places', v.place);
      link('stops', v.stop);
      if (v.stop != null) {
        final stop = stops.firstWhere((s) => s.key == v.stop);
        if (stop.trip != v.trip || stop.place != v.place)
          throw const FormatException('Visit/stop mismatch');
      }
      for (final a in v.assets) link('assets', a);
    }
    for (final n in notes) {
      link('trips', n.trip);
      link('visits', n.ref('visit'));
      link('stops', n.ref('stop'));
      if (n.ref('stop') != null &&
          stops.firstWhere((s) => s.key == n.ref('stop')).trip != n.trip)
        throw const FormatException('Note/stop trip mismatch');
      for (final a in n.assets) link('assets', a);
      if (n.ref('visit') != null &&
          visits.firstWhere((v) => v.key == n.ref('visit')).trip != n.trip)
        throw const FormatException('Note/visit trip mismatch');
    }
    for (final b in bookings) {
      link('trips', b.trip);
      for (final a in b.list('assets')) link('assets', a);
    }
    for (final p in packing) link('trips', p.trip);
    final sources = <String>{};
    for (final e in expenses) {
      link('trips', e.trip);
      link('assets', e.ref('receipt'));
      if (e.data['source'] != null &&
          !sources.add('${e.trip}:${e.data['source']}'))
        throw const FormatException('Duplicate expense source');
    }
    if (alarms.length > 200)
      throw const FormatException('At most 200 reminder rules');
    for (final a in alarms) {
      link('trips', a.trip);
      final kind = switch (a.type) {
        'stop' => 'stops',
        'booking' => 'bookings',
        _ => 'packing',
      };
      link(kind, a.target);
      if (entities(kind).firstWhere((e) => e.key == a.target).text('trip') !=
          a.trip)
        throw const FormatException('Reminder trip mismatch');
    }
    final allowed = <String>{};
    var size = 0;
    for (final asset in assets) {
      allowed.add(asset.path);
      final b = files[asset.path];
      if (b == null ||
          b.length != asset.size ||
          sha256.convert(b).toString() != asset.checksum)
        throw const FormatException('Missing/corrupt asset');
      size += b.length;
      if (asset.data['preview'] != null) {
        final p = string(asset.data['preview']);
        if (p != 'previews/${asset.key}.jpg')
          throw const FormatException('Invalid preview path');
        allowed.add(p);
        final b = files[p];
        if (b == null ||
            sha256.convert(b).toString() != asset.data['previewSha'])
          throw const FormatException('Corrupt thumbnail');
        size += b.length;
      }
    }
    if (files.keys.any((p) => !allowed.contains(p)) || size > 300000000)
      throw const FormatException('Invalid managed files / over 300 MB');
  }
}
