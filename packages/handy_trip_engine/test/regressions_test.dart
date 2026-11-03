import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'domain_test.dart' show fixture, visit;

void main() {
  test(
    'editing a free visit moves linked notes atomically and refuses future confirmation',
    () {
      var s = checkIn(fixture(), visit('v').copy({'stop': null}));
      s = s.put('trips', s.trip('t').copy({'id': 'other', 'title': 'Other'}));
      s = s.put(
        'notes',
        JournalNote({
          'id': 'n',
          'trip': 't',
          'visit': 'v',
          'stop': 's',
          'at': '2026-03-08T01:00:00Z',
          'zone': 'UTC',
          'body': 'Preserve this note',
        }),
      );
      final moved = editVisit(s, s.visits.single.copy({'trip': 'other'}));
      expect(moved.notes.single.trip, 'other');
      expect(moved.notes.single.ref('stop'), isNull);
      expect(moved.notes.single.body, 'Preserve this note');
      expect(
        () => editVisit(
          s,
          s.visits.single.copy({'at': '2027-01-01T00:00:00Z'}),
          now: DateTime.utc(2026),
        ),
        throwsFormatException,
      );
      expect(s.visits.single.trip, 't');
    },
  );
  test(
    'state import rejects a missing DST end clock, preserving the original schedule',
    () {
      final s = fixture();
      expect(
        () => s.put(
          'stops',
          s.stops.single.copy({
            'time': '01:30',
            'endTime': '02:30',
            'endOffset': 0,
          }),
        ),
        throwsFormatException,
      );
      expect(s.stops.single.time, '23:30');
    },
  );
  test(
    'changing base currency preserves old stop estimates in their original currency',
    () {
      final s = fixture().put(
        'stops',
        fixture().stops.single.copy({'estimate': '1250'}),
      );
      expect(estimateTotals(s, 't'), {'USD': BigInt.from(1250)});
      final changed = saveTrip(s, s.trip('t').copy({'currency': 'VND'}));
      expect(changed.stops.single.text('currency'), 'USD');
      expect(estimateTotals(changed, 't'), {'USD': BigInt.from(1250)});
      expect(estimateTotals(readBackup(fullBackup(changed)), 't'), {
        'USD': BigInt.from(1250),
      });
    },
  );
  test(
    'editing another field preserves original seconds and the second DST fold',
    () {
      const at = '2026-11-01T06:30:17.123Z';
      expect(lateFoldAt(at, 'America/New_York'), isTrue);
      expect(
        editedInstant(
          at,
          'America/New_York',
          '2026-11-01',
          '01:30',
          'America/New_York',
          lateFold: true,
        ),
        DateTime.parse(at),
      );
      expect(
        editedInstant(
          at,
          'America/New_York',
          '2026-11-01',
          '01:30',
          'America/New_York',
          lateFold: false,
        ),
        DateTime.utc(2026, 11, 1, 5, 30),
      );
    },
  );
  test(
    'place CSV and itinerary JSON map supported fields without inventing visits',
    () {
      final state = fixture();
      final places = importPlacesTable(
        state,
        [
          ['name', 'lat', 'lon', 'url'],
          ['Antimeridian point', '10', '-179.99', 'https://example.com/p'],
        ],
        nameColumn: 0,
        latitudeColumn: 1,
        longitudeColumn: 2,
        urlColumn: 3,
      );
      expect(places.places.last.geo!.lon, -179.99);
      expect(places.visits, isEmpty);
      expect(
        () => importPlacesTable(
          state,
          [
            ['name', 'lat', 'lon'],
            ['Bad', '91', '0'],
          ],
          nameColumn: 0,
          latitudeColumn: 1,
          longitudeColumn: 2,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'a visit projection preserves an unrelated manually completed activity',
    () {
      final s = fixture().put(
        'stops',
        Stop({
          'id': 'activity',
          'trip': 't',
          'title': 'Rest',
          'day': '2026-03-08',
          'status': 'visited',
          'manualComplete': true,
        }),
      );
      final checked = checkIn(s, visit('v'));
      expect(
        checked.stops.firstWhere((s) => s.key == 'activity').status,
        'visited',
      );
      final removed = removeEntity(checked, 'visits', 'v');
      expect(removed.stops.firstWhere((s) => s.key == 's').status, 'planned');
      expect(
        removed.stops.firstWhere((s) => s.key == 'activity').status,
        'visited',
      );
      expect(uniquePlaces(removed), isEmpty);
    },
  );
  test(
    'year counters use the recorded zone across international year boundaries',
    () {
      final v = visit('v', at: '2026-01-01T00:30:00Z');
      final s = checkIn(fixture(), v);
      expect(uniquePlaces(s, year: 2025), {'p'});
      expect(uniquePlaces(s, year: 2026), isEmpty);
      expect(localClock(DateTime.parse(v.at), v.zone), '19:30');
    },
  );
  test('future visits cannot quietly turn a plan into visited history', () {
    expect(
      () => checkIn(
        fixture(),
        visit('v', at: '2027-01-01T00:00:00Z'),
        now: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
    expect(fixture().stops.single.status, 'planned');
  });
  test('mapped CSV has no silent date normalization or partial insertion', () {
    final original = fixture();
    final good = importItineraryTable(
      original,
      't',
      [
        ['title', 'date', 'time', 'place'],
        ['Offline tour', '2026-03-09', '09:30', 'User confirmed museum'],
      ],
      titleColumn: 0,
      dayColumn: 1,
      timeColumn: 2,
      placeColumn: 3,
    );
    expect(good.stops.last.place, 'p');
    expect(good.visits, isEmpty);
    expect(
      () => importItineraryTable(
        original,
        't',
        [
          ['title', 'date'],
          ['Valid', '2026-03-09'],
          ['Bad', '2026-02-30'],
        ],
        titleColumn: 0,
        dayColumn: 1,
      ),
      throwsFormatException,
    );
    expect(original.stops.length, 1);
    final own = exportCsv(original, 'stops');
    expect(
      () => importOwnCsv(
        original,
        own.replaceFirst('"Museum"', '"Changed"'),
        'stops',
      ),
      throwsFormatException,
    );
  });
  test(
    'limited ICS round-trip is idempotent and rejects recurrent, invalid and conflicting data',
    () {
      final s = fixture(), ics = exportIcs(s);
      final clean = s.copy({'stops': []});
      final imported = importIcs(clean, 't', ics);
      expect(imported.stops.single.title, s.stops.single.title);
      expect(imported.stops.single.time, '23:30');
      expect(importIcs(imported, 't', ics).stops.length, 1);
      expect(
        () => importIcs(
          clean,
          't',
          ics.replaceFirst('END:VEVENT', 'RRULE:FREQ=DAILY\r\nEND:VEVENT'),
        ),
        throwsFormatException,
      );
      expect(
        () =>
            importIcs(imported, 't', ics.replaceFirst('Museum', 'Conflicting')),
        throwsFormatException,
      );
    },
  );
  test(
    'ten thousand visits are distinct from a single unique place and survive JSON',
    () {
      final sample = visit('v').toJson();
      final large = fixture().copy({
        'visits': List.generate(10000, (i) => {...sample, 'id': 'v$i'}),
      });
      expect(large.visits.length, 10000);
      expect(uniquePlaces(large), {'p'});
      final restored = readBackup(fullBackup(large));
      expect(restored.visits.length, 10000);
      expect(jsonEncode(restored.toJson()), jsonEncode(large.toJson()));
    },
  );
}
