import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:image/image.dart' as img;

TripState fixture() {
  final trip = Trip({
    'id': 't',
    'title': 'Three days',
    'start': '2026-03-07',
    'end': '2026-03-09',
    'zone': 'America/New_York',
    'currency': 'USD',
    'budget': '10000',
    'created': '2026-01-01T00:00:00Z',
    'updated': '2026-01-01T00:00:00Z',
    'status': 'planned',
  });
  final place = Place({
    'id': 'p',
    'name': 'User confirmed museum',
    'category': 'attraction',
    'geo': {'lat': 10.5, 'lon': 179.99},
    'country': 'Known country',
    'wishlist': true,
    'url': 'https://example.com/place',
  });
  return TripState(
    trips: [trip],
    places: [place],
    stops: [
      Stop({
        'id': 's',
        'trip': 't',
        'place': 'p',
        'title': 'Museum',
        'day': '2026-03-08',
        'time': '23:30',
        'endTime': '00:30',
        'endOffset': 1,
      }),
    ],
  );
}

Visit visit(String key, {String at = '2026-03-08T14:00:00Z'}) => Visit({
  'id': key,
  'trip': 't',
  'stop': 's',
  'place': 'p',
  'at': at,
  'zone': 'America/New_York',
  'origin': 'manual',
  'confirmed': true,
  'created': at,
  'updated': at,
});

void main() {
  test(
    'inclusive days across DST; strict dates and missing/folded local times',
    () {
      expect(fixture().trips.single.days, [
        '2026-03-07',
        '2026-03-08',
        '2026-03-09',
      ]);
      expect(() => date('2026-02-30'), throwsFormatException);
      expect(
        () => localInstant('2026-03-08', '02:30', 'America/New_York'),
        throwsFormatException,
      );
      expect(
        () => localInstant('2026-11-01', '01:30', 'America/New_York'),
        throwsFormatException,
      );
      expect(
        localInstant(
          '2026-11-01',
          '01:30',
          'America/New_York',
          lateFold: true,
        ).difference(
          localInstant(
            '2026-11-01',
            '01:30',
            'America/New_York',
            lateFold: false,
          ),
        ),
        const Duration(hours: 1),
      );
    },
  );
  test(
    'overnight overlap warns, reorder validates permutation, date shrink preserves stops',
    () {
      final s = fixture().put(
        'stops',
        Stop({
          'id': 'next',
          'trip': 't',
          'title': 'Transit',
          'day': '2026-03-09',
          'time': '00:00',
          'duration': 60,
        }),
      );
      expect(overlaps(s, 't'), [('s', 'next')]);
      expect(
        () => reorderStops(s, 't', '2026-03-08', ['s', 's']),
        throwsFormatException,
      );
      expect(
        () => saveTrip(s, s.trips.single.copy({'end': '2026-03-07'})),
        throwsFormatException,
      );
      expect(s.stops.length, 2);
    },
  );
  test(
    'manual visit without permission, retries, repeat visits and unique geography',
    () {
      var s = checkIn(fixture(), visit('v'));
      expect(s.stops.single.status, 'visited');
      expect(s.visits.length, 1);
      s = checkIn(s, visit('v'));
      expect(s.visits.length, 1);
      s = checkIn(s, visit('again', at: '2026-03-09T12:00:00Z'));
      expect(s.visits.length, 2);
      expect(uniquePlaces(s), {'p'});
      expect(geography(s, 'country'), {'Known country': 1});
      s = removeEntity(s, 'visits', 'v');
      expect(s.stops.single.status, 'visited');
      s = removeEntity(s, 'visits', 'again');
      expect(s.stops.single.status, 'planned');
      expect(
        () => checkIn(s, visit('notconfirmed').copy({'confirmed': false})),
        throwsFormatException,
      );
    },
  );
  test(
    'GPS coarse/stale requires explicit caution acceptance, coordinates bounded',
    () {
      final at = DateTime.utc(2026, 3, 8, 14),
          fix = CapturedLocation(Geo(0, 0), 400, DateTime.utc(2026, 3, 8, 13));
      final v = visit('gps').copy({
        'origin': 'gps',
        'geo': fix.geo.toJson(),
        'accuracy': fix.accuracy,
        'capturedAt': fix.at.toIso8601String(),
      });
      expect(
        () => checkIn(fixture(), v, fix: fix, now: at),
        throwsFormatException,
      );
      expect(
        checkIn(
          fixture(),
          v,
          fix: fix,
          now: at,
          acceptCaution: true,
        ).visits.length,
        1,
      );
      expect(() => Geo(double.nan, 0), throwsFormatException);
      expect(() => Geo(0, 181), throwsFormatException);
    },
  );
  test('exact money, mixed currencies never implicitly converted', () {
    expect(money('0.10', 'USD') + money('0.20', 'USD'), BigInt.from(30));
    expect(() => money('0.1', 'VND'), throwsFormatException);
    expect(money('1.001', 'KWD'), BigInt.from(1001));
    var s = fixture();
    for (final (id, currency, minor) in [
      ('a', 'USD', '10'),
      ('b', 'VND', '50000'),
    ])
      s = s.put(
        'expenses',
        Expense({
          'id': id,
          'trip': 't',
          'at': '2026-03-08T14:00:00Z',
          'currency': currency,
          'minor': minor,
        }),
      );
    expect(expenseTotals(s, 't'), {
      'USD': BigInt.from(10),
      'VND': BigInt.from(50000),
    });
  });
  test(
    'trip template strips secrets/history/expenses, packing completion isolated',
    () {
      var s = fixture().put(
        'bookings',
        Booking({
          'id': 'b',
          'trip': 't',
          'title': 'Flight',
          'start': '2026-03-08T00:00:00Z',
          'end': '2026-03-08T02:00:00Z',
          'zone': 'UTC',
          'code': 'PRIVATE42',
        }),
      );
      s = checkIn(s, visit('v'));
      for (final p in packingTemplate('t', 'beach'))
        s = s.put('packing', p.copy({'packed': true}));
      final copy = duplicateTrip(s, 't', '2026-04-01'),
          id = copy.trips.last.key;
      expect(copy.visits.length, 1);
      expect(copy.bookings.where((b) => b.trip == id), isEmpty);
      expect(
        copy.packing.where((p) => p.trip == id).every((p) => !p.packed),
        isTrue,
      );
    },
  );
  for (final zip in [false, true])
    test(
      'full ${zip ? 'ZIP' : 'JSON'} roundtrip, merge refs/reminders, future schema/corrupt refuse',
      () {
        final s = checkIn(fixture(), visit('v')),
            bytes = fullBackup(s, zip: zip),
            restored = readBackup(bytes, zip: zip);
        expect(jsonEncode(restored.toJson()), jsonEncode(s.toJson()));
        final merged = mergeBackup(s, restored, digest: 'same');
        expect(merged.trips.length, 2);
        expect(merged.visits.map((v) => v.place).toSet().length, 2);
        expect(
          () => mergeBackup(merged, restored, digest: 'same'),
          throwsFormatException,
        );
        expect(
          () => readBackup(Uint8List.fromList([1, 2, 3]), zip: zip),
          throwsA(anything),
        );
        expect(
          () => TripState.fromJson({...s.toJson(), 'schema': 2}),
          throwsFormatException,
        );
      },
    );
  test(
    'managed original preserved, public preview has no EXIF, private/public exports differ',
    () {
      final photo = img.Image(width: 24, height: 24),
          bytes = Uint8List.fromList(img.encodeJpg(photo));
      final prepared = prepareAsset('photo.jpg', bytes),
          s = addPreparedAsset(fixture(), prepared);
      expect(s.files[prepared.asset.path], bytes);
      expect(img.decodeJpg(prepared.preview), isNotNull);
      final linked = s.put(
        'notes',
        JournalNote({
          'id': 'n',
          'trip': 't',
          'at': '2026-03-08T12:00:00Z',
          'zone': 'UTC',
          'body': 'Private note',
          'assets': [prepared.asset.key],
        }),
      );
      expect(readBackup(fullBackup(linked)).files[prepared.asset.path], bytes);
      expect(pruneManagedCopies(s).assets, isEmpty);
      expect(bytes, prepared.original);
      final booked = linked.put(
        'bookings',
        Booking({
          'id': 'b',
          'trip': 't',
          'title': 'PRIVATE42',
          'start': '2026-03-08T00:00:00Z',
          'end': '2026-03-08T01:00:00Z',
          'zone': 'UTC',
          'code': 'PRIVATE42',
        }),
      );
      final public = jsonEncode(publicDocument(booked));
      expect(public, isNot(contains('PRIVATE42')));
      expect(public, isNot(contains('Private note')));
      expect(public, isNot(contains('179.99')));
    },
  );
  test('own CSV roundtrip and conflicting import refuse', () {
    final s = fixture(), csv = exportCsv(s, 'stops');
    expect(
      importOwnCsv(s.copy({'stops': []}), csv, 'stops').stops.single.title,
      'Museum',
    );
    expect(
      () => importOwnCsv(
        s.put('stops', s.stops.single.copy({'title': 'Changed'})),
        csv,
        'stops',
      ),
      throwsFormatException,
    );
  });
  test('ICS UTC/all-day escape and public redaction', () {
    final s = fixture().put(
      'stops',
      fixture().stops.single.copy({'title': 'Line,semi;slash\\\nnext'}),
    );
    final ics = exportIcs(s);
    expect(ics, contains('DTSTART:20260309T033000Z'));
    expect(ics, contains(r'Line\,semi\;slash\\\nnext'));
  });
}
