part of '../handy_trip_engine.dart';

const portableLimit = 30000000;
Uint8List fullBackup(TripState s, {bool zip = true}) {
  s.validate();
  if (!zip) {
    final b = Uint8List.fromList(utf8.encode(jsonEncode(s.toJson())));
    if (b.length > portableLimit)
      throw const FormatException(
        'JSON backup exceeds 30 MB; export selected modules/trips',
      );
    return b;
  }
  final body = Uint8List.fromList(
        utf8.encode(jsonEncode(s.toJson(includeData: false))),
      ),
      entries = {'data.json': body, ...s.files};
  if (entries.length > 998 ||
      entries.values.fold<int>(0, (a, b) => a + b.length) >
          portableLimit - 100000)
    throw const FormatException(
      'Portable bundle exceeds 30 MB / 998 entries; originals preserved',
    );
  final manifest = utf8.encode(
    jsonEncode({
      'app': 'handy-trip',
      'formatVersion': 1,
      'appVersion': '0.1.0',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'timezone': s.settings['zone'] ?? 'UTC',
      'counts': {for (final k in collections) k: s.entities(k).length},
      'files': entries.map(
        (k, v) => MapEntry(k, {
          'size': v.length,
          'sha256': sha256.convert(v).toString(),
        }),
      ),
    }),
  );
  final archive = Archive()
    ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  for (final e in entries.entries)
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
  if (bytes.length > portableLimit)
    throw const FormatException('Compressed bundle too large');
  return bytes;
}

TripState readBackup(Uint8List bytes, {bool zip = true}) {
  if (bytes.length > portableLimit)
    throw const FormatException('Import exceeds 30 MB');
  if (!zip)
    return _validateRestoredAssets(
      TripState.fromJson(object(jsonDecode(utf8.decode(bytes)))),
    );
  final entries = decodePortableZip(
    bytes,
    isAllowedPath: (p) =>
        p == 'manifest.json' ||
        p == 'data.json' ||
        RegExp(
          r'^(assets|previews)/[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp|pdf)$',
        ).hasMatch(p),
    maxEntries: 1000,
    maxEntryBytes: portableLimit,
    maxTotalBytes: portableLimit,
  );
  if (!entries.containsKey('data.json') ||
      !entries.containsKey('manifest.json'))
    throw const FormatException('Incomplete bundle');
  final manifest = object(
    jsonDecode(utf8.decode(entries.remove('manifest.json')!)),
  );
  if (manifest['app'] != 'handy-trip' || manifest['formatVersion'] != 1)
    throw const FormatException('Unsupported manifest');
  final hashes = object(manifest['files']);
  if (hashes.length != entries.length)
    throw const FormatException('Manifest count mismatch');
  for (final e in entries.entries) {
    final expected = object(hashes[e.key]);
    if (expected['size'] != e.value.length ||
        expected['sha256'] != sha256.convert(e.value).toString())
      throw const FormatException('Checksum mismatch');
  }
  final data = object(jsonDecode(utf8.decode(entries.remove('data.json')!))),
      s = TripState.fromJson(data, files: entries),
      counts = object(manifest['counts']);
  for (final k in collections)
    if (counts[k] != s.entities(k).length)
      throw const FormatException('Record counts mismatch');
  return _validateRestoredAssets(s);
}

TripState _validateRestoredAssets(TripState state) {
  for (final a in state.assets) {
    final checked = prepareAsset(a.text('name'), state.files[a.path]!);
    if (checked.asset.mime != a.mime)
      throw const FormatException(
        'Asset signature does not match declared media type',
      );
    if (a.data['preview'] != null) {
      final preview = prepareAsset(
        'preview.jpg',
        state.files[a.data['preview']]!,
      );
      if (preview.asset.mime != 'image/jpeg')
        throw const FormatException('Invalid preview signature');
    }
  }
  return state;
}

TripState mergeBackup(
  TripState current,
  TripState incoming, {
  required String digest,
}) {
  final imports = strings(current.settings['imports'] ?? []);
  if (imports.contains(digest))
    throw const FormatException('Backup already merged');
  final maps = {
        for (final k in collections)
          k: {for (final e in incoming.entities(k)) e.key: newId()},
      },
      merged = <String, dynamic>{};
  String? mapped(String kind, dynamic value) =>
      value == null ? null : maps[kind]![value];
  final files = {...current.files};
  for (final kind in collections) {
    final rows = <Json>[];
    for (final e in incoming.entities(kind)) {
      final j = e.toJson();
      j['id'] = maps[kind]![e.key];
      for (final field in [
        'trip',
        'targetTrip',
        'place',
        'stop',
        'visit',
        'receipt',
        'cover',
      ])
        if (j[field] != null)
          j[field] = mapped(
            {
              'trip': 'trips',
              'targetTrip': 'trips',
              'place': 'places',
              'stop': 'stops',
              'visit': 'visits',
              'receipt': 'assets',
              'cover': 'assets',
            }[field]!,
            j[field],
          );
      if (kind != 'assets' && j['assets'] != null)
        j['assets'] = (j['assets'] as List)
            .map((v) => mapped('assets', v))
            .toList();
      if (kind == 'alarms') {
        j['target'] = mapped(
          {
            'stop': 'stops',
            'booking': 'bookings',
            'packing': 'packing',
          }[j['type']]!,
          j['target'],
        );
        j['enabled'] = false;
      }
      if (kind == 'expenses') j['source'] = null;
      if (kind == 'assets') {
        final a = e as MediaAsset,
            newKey = j['id'] as String,
            ext = a.path.split('.').last,
            path = 'assets/$newKey.$ext';
        j['path'] = path;
        files[path] = incoming.files[a.path]!;
        if (a.data['preview'] != null) {
          final preview = 'previews/$newKey.jpg';
          j['preview'] = preview;
          files[preview] = incoming.files[a.data['preview']]!;
        }
      }
      rows.add(j);
    }
    merged[kind] = [...current.entities(kind).map((e) => e.toJson()), ...rows];
  }
  return current.copy({
    ...merged,
    'settings': {
      ...current.settings,
      'imports': [...imports, digest],
    },
  }, files: files);
}

TripState selectTrip(TripState s, String tripId, {String? on}) {
  final stops = s.stops
          .where((v) => v.trip == tripId && (on == null || v.on == on))
          .toList(),
      ids = stops.map((v) => v.key).toSet(),
      visits = s.visits
          .where(
            (v) =>
                v.trip == tripId &&
                (on == null || localDay(DateTime.parse(v.at), v.zone) == on),
          )
          .toList(),
      visitIds = visits.map((v) => v.key).toSet();
  final notes = s.notes
      .where(
        (v) =>
            v.trip == tripId &&
            (on == null || localDay(DateTime.parse(v.at), v.zone) == on),
      )
      .toList();
  final placeIds = {
    ...stops.map((s) => s.place).whereType<String>(),
    ...visits.map((v) => v.place),
  };
  final raw = TripState(
    trips: [s.trip(tripId)],
    places: s.places
        .where((p) => placeIds.contains(p.key))
        .map((p) => p.copy({'targetTrip': null}))
        .toList(),
    stops: stops,
    visits: visits
        .map((v) => v.copy({'stop': ids.contains(v.stop) ? v.stop : null}))
        .toList(),
    notes: notes
        .map(
          (n) => n.copy({
            'stop': ids.contains(n.ref('stop')) ? n.ref('stop') : null,
            'visit': visitIds.contains(n.ref('visit')) ? n.ref('visit') : null,
          }),
        )
        .toList(),
    bookings: s.bookings
        .where(
          (v) =>
              v.trip == tripId &&
              (on == null || localDay(DateTime.parse(v.start), v.zone) == on),
        )
        .toList(),
    packing: s.packing.where((v) => v.trip == tripId).toList(),
    expenses: s.expenses
        .where(
          (v) =>
              v.trip == tripId &&
              (on == null ||
                  localDay(DateTime.parse(v.at), s.trip(tripId).zone) == on),
        )
        .toList(),
    assets: s.assets,
    files: s.files,
  );
  return pruneManagedCopies(raw);
}

String csvField(String s) {
  if (RegExp(r'^\s*[=+@\-\t\r]').hasMatch(s)) s = "'$s";
  return '"${s.replaceAll('"', '""')}"';
}

String exportCsv(TripState s, String kind) {
  if (![
    'stops',
    'places',
    'expenses',
    'packing',
    'visits',
    'notes',
  ].contains(kind))
    throw ArgumentError('CSV kind');
  return '\ufeffkind,id,title,day,currency,minor,record_b64\r\n${s.entities(kind).map((e) => [
    kind,
    e.key,
    e.data['title'] ?? e.data['name'] ?? e.data['description'] ?? '',
    e.data['day'] ?? e.data['at'] ?? '',
    e.data['currency'] ?? '',
    e.data['minor'] ?? '',
    base64Encode(utf8.encode(jsonEncode({'schema': 1, 'record': e.toJson()}))),
  ].map((v) => csvField(v.toString())).join(',')).join('\r\n')}';
}

TripState importOwnCsv(TripState s, String text, String kind) {
  final rows = csvParse(text);
  if (rows.isEmpty ||
      rows.first.join(',') != 'kind,id,title,day,currency,minor,record_b64')
    throw const FormatException('Use documented CSV schema');
  final current = {for (final e in s.entities(kind)) e.key: e.toJson()};
  for (final row in rows.skip(1)) {
    if (row.length != 7 || row[0] != kind)
      throw const FormatException('Wrong CSV row');
    final j = object(jsonDecode(utf8.decode(base64Decode(row[6]))));
    if (j['schema'] != 1) throw const FormatException('Unknown CSV schema');
    final record = object(j['record']);
    if (record['id'] != row[1]) throw const FormatException('CSV ID mismatch');
    final expected =
        [
          kind,
          record['id'],
          record['title'] ?? record['name'] ?? record['description'] ?? '',
          record['day'] ?? record['at'] ?? '',
          record['currency'] ?? '',
          record['minor'] ?? '',
        ].map((v) {
          final text = v.toString();
          return RegExp(r'^\s*[=+@\-\t\r]').hasMatch(text) ? "'$text" : text;
        }).toList();
    for (var i = 0; i < 6; i++) {
      if (row[i] != expected[i])
        throw const FormatException(
          'CSV display columns changed; use mapped import for edits',
        );
    }
    final previous = current[row[1]];
    if (previous != null && jsonEncode(previous) != jsonEncode(record))
      throw const FormatException('Conflicting CSV ID');
    current[row[1]] = record;
  }
  return s.copy({kind: current.values.toList()});
}

Json publicDocument(TripState s) {
  final codes = s.bookings
      .map((b) => b.code)
      .where((c) => c.isNotEmpty)
      .toList();
  String clean(String value) {
    for (final c in codes)
      value = value.replaceAll(
        RegExp(RegExp.escape(c), caseSensitive: false),
        '[private]',
      );
    return value;
  }

  return {
    'app': 'handy-trip-public',
    'schema': 1,
    'privacy':
        'Public titles only; review user-entered titles before sharing. No booking identifiers, notes, addresses, assets or precise GPS.',
    'trips': [
      for (final t in s.trips)
        {
          'id': t.key,
          'title': clean(t.title),
          'start': t.start,
          'end': t.end,
          'zone': t.zone,
          'destination': clean(t.destination),
        },
    ],
    'stops': [
      for (final v in s.stops)
        {
          'id': v.key,
          'trip': v.trip,
          'day': v.on,
          'title': clean(v.title),
          'time': v.time,
          'endTime': v.endTime,
          'endOffset': v.endOffset,
          'type': v.type,
          'status': v.status,
        },
    ],
    'visits': [
      for (final v in s.visits.where((v) => v.confirmed))
        {
          'id': v.key,
          'trip': v.trip,
          'place': clean(s.place(v.place).name),
          'day': localDay(DateTime.parse(v.at), v.zone),
          'origin': v.origin,
          'confirmedByUser': true,
        },
    ],
    'bookings': [
      for (final b in s.bookings)
        {'type': b.type, 'start': b.start, 'end': b.end, 'zone': b.zone},
    ],
  };
}

String markdownItinerary(TripState s, {bool vietnamese = false}) {
  final doc = publicDocument(s);
  String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('|', r'\|')
      .replaceAll('\n', ' ');
  return '# Handy Trip\n\n${(doc['trips'] as List).map((t) => '## ${escape(t['title'])}\n\n${t['start']} - ${t['end']} (${t['zone']})\n\n${(doc['stops'] as List).where((v) => v['trip'] == t['id']).map((v) => '- ${v['day']} ${v['time'] ?? ''} ${escape(v['title'])}').join('\n')}').join('\n\n')}\n\n${vietnamese ? 'Lịch dự kiến không phải bằng chứng đã ghé thăm. Đã bỏ thông tin đặt chỗ riêng tư và tọa độ.' : 'Planned stops do not prove visits. Private booking details and coordinates omitted.'}\n';
}

String _icsEscape(String s) => s
    .replaceAll('\\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r', '')
    .replaceAll('\n', r'\n');
String _icsInstant(DateTime t) =>
    t
        .toUtc()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(RegExp('[-:]'), '') +
    'Z';
String exportIcs(TripState s) {
  final public = publicDocument(s),
      rows = <String>[
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//Handy Suite//Handy Trip//EN',
        'CALSCALE:GREGORIAN',
      ];
  for (final stop in s.stops) {
    final trip = s.trip(stop.trip),
        title =
            (public['stops'] as List).firstWhere(
                  (v) => v['id'] == stop.key,
                )['title']
                as String;
    rows.addAll([
      'BEGIN:VEVENT',
      'UID:${stop.key}@handy-trip',
      'DTSTAMP:${_icsInstant(DateTime.now())}',
      'SUMMARY:${_icsEscape(title)}',
    ]);
    if (stop.time == null) {
      rows.add('DTSTART;VALUE=DATE:${stop.on.replaceAll('-', '')}');
      rows.add('DTEND;VALUE=DATE:${addDays(stop.on, 1).replaceAll('-', '')}');
    } else {
      final start = localInstant(
        stop.on,
        stop.time!,
        trip.zone,
        lateFold: stop.data['lateFold'] as bool?,
      );
      rows.add('DTSTART:${_icsInstant(start)}');
      final end = stop.endTime != null
          ? localInstant(
              addDays(stop.on, stop.endOffset),
              stop.endTime!,
              trip.zone,
              lateFold: stop.data['lateFold'] as bool?,
            )
          : start.add(Duration(minutes: stop.duration));
      if (end.isAfter(start)) rows.add('DTEND:${_icsInstant(end)}');
    }
    rows.addAll(['X-HANDY-TIMEZONE:${trip.zone}', 'END:VEVENT']);
  }
  rows.add('END:VCALENDAR');
  return rows
          .map((line) {
            final out = StringBuffer();
            var width = 0;
            for (final rune in line.runes) {
              final char = String.fromCharCode(rune),
                  size = utf8.encode(char).length;
              if (width + size > 73) {
                out.write('\r\n ');
                width = 1;
              }
              out.write(char);
              width += size;
            }
            return out.toString();
          })
          .join('\r\n') +
      '\r\n';
}
