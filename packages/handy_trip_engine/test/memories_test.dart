import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:image/image.dart' as img;
import 'domain_test.dart' show fixture, visit;

TripState memories() {
  var s = fixture().put(
    'bookings',
    Booking({
      'id': 'book',
      'trip': 't',
      'title': 'Private booking',
      'start': '2026-03-07T00:00:00Z',
      'end': '2026-03-09T00:00:00Z',
      'zone': 'UTC',
      'code': 'PRIVATE-CODE',
    }),
  );
  final original = img.Image(width: 30, height: 20)
    ..exif.imageIfd['Artist'] = 'PRIVATE-ARTIST';
  final asset = prepareAsset(
    'PRIVATE-FILE.jpg',
    Uint8List.fromList(img.encodeJpg(original)),
    caption: 'PRIVATE-CAPTION',
  );
  s = addPreparedAsset(s, asset);
  s = s.put(
    'trips',
    s.trip('t').copy({'title': 'Coast PRIVATE-CODE', 'cover': asset.asset.key}),
  );
  s = s.put(
    'places',
    s.place('p').copy({'name': '<script>alert(1)</script> PRIVATE-CODE'}),
  );
  s = checkIn(
    s,
    visit('first').copy({
      'assets': [asset.asset.key],
      'note': 'PRIVATE-NOTE',
      'rating': 5,
    }),
  );
  s = checkIn(
    s,
    visit(
      'second',
      at: '2026-03-11T01:00:00Z',
    ).copy({'stop': null, 'rating': 3}),
  );
  s = s.put(
    'notes',
    JournalNote({
      'id': 'n',
      'trip': 't',
      'at': '2026-03-10T01:00:00Z',
      'zone': 'UTC',
      'title': 'PRIVATE-TITLE',
      'body': 'PRIVATE-BODY',
      'assets': [asset.asset.key],
    }),
  );
  s = s.put(
    'expenses',
    Expense({
      'id': 'e',
      'trip': 't',
      'at': '2026-03-08T00:00:00Z',
      'currency': 'USD',
      'minor': '1250',
    }),
  );
  return s;
}

void main() {
  test(
    'safe template whitelist drops unknown secrets/completion flags and bounds long names',
    () {
      var s = fixture();
      s = s.put(
        'trips',
        s.trip('t').copy({
          'title': List.filled(200, 'x').join(),
          'unexpectedSecret': 'PRIVATE-UNKNOWN',
        }),
      );
      s = s.put(
        'stops',
        s.stops.single.copy({
          'place': null,
          'status': 'visited',
          'manualComplete': true,
          'unexpectedSecret': 'PRIVATE-UNKNOWN',
          'note': 'PRIVATE-NOTE',
        }),
      );
      final copied = duplicateTrip(s, 't', '2026-05-01'),
          newTrip = copied.trips.last;
      final newStop = copied.stops.last;
      expect(newTrip.title.length, lessThanOrEqualTo(200));
      expect(newTrip.data.containsKey('unexpectedSecret'), isFalse);
      expect(newStop.status, 'planned');
      expect(newStop.data.containsKey('manualComplete'), isFalse);
      expect(newStop.data.containsKey('unexpectedSecret'), isFalse);
      expect(newStop.text('note'), '');
      expect(projectVisits(copied).stops.last.status, 'planned');
    },
  );
  test(
    'memory book keeps off-plan days, default redaction and optional private content',
    () {
      final s = memories(), book = memoryBookData(s, 't');
      expect(book['visits'], 2);
      expect(book['uniquePlaces'], 1);
      expect(
        (book['days'] as List).map((d) => d['day']),
        contains('2026-03-10'),
      );
      expect(jsonEncode(book), isNot(contains('PRIVATE-CODE')));
      expect(jsonEncode(book), isNot(contains('PRIVATE-NOTE')));
      expect(book.containsKey('expenses'), isFalse);
      final private = memoryBookData(
        s,
        't',
        privateText: true,
        includeMoney: true,
      );
      expect(jsonEncode(private), contains('PRIVATE-NOTE'));
      expect(private['expenses']['USD'], '1250');
    },
  );
  test(
    'HTML/photo ZIP contains escaped text, no original metadata and deterministic backup round-trip',
    () {
      final s = memories();
      {
        final bytes = memoryBookZip(s, 't'),
            archive = ZipDecoder().decodeBytes(bytes);
        final html = utf8.decode(archive.findFile('index.html')!.content);
        expect(html, isNot(contains('<script>')));
        expect(html, contains('&lt;script&gt;'));
        for (final secret in [
          'PRIVATE-CODE',
          'PRIVATE-NOTE',
          'PRIVATE-CAPTION',
          'PRIVATE-ARTIST',
          'PRIVATE-FILE',
        ])
          expect(html, isNot(contains(secret)));
        for (final file in archive.files.where(
          (f) => f.name.endsWith('.jpg'),
        )) {
          expect(
            img
                .decodeJpg(Uint8List.fromList(file.content))!
                .exif
                .imageIfd
                .containsKey(0x013b),
            isFalse,
          );
        }
        final restored = ZipDecoder().decodeBytes(
          memoryBookZip(readBackup(fullBackup(s)), 't'),
        );
        expect(
          restored.findFile('index.html')!.content,
          archive.findFile('index.html')!.content,
        );
        expect(s.assets.first.text('name'), 'PRIVATE-FILE.jpg');
      }
    },
  );
  test(
    'stamp is unofficial, redacted, requires confirmation and contains no precise position',
    () {
      final s = memories(), stamp = stampData(s, 'first');
      expect(jsonEncode(stamp), isNot(contains('PRIVATE-CODE')));
      expect(stamp.containsKey('geo'), isFalse);
      expect(stamp['label'], contains('not an official'));
      expect(
        () => stampData(
          editVisit(s, s.visits.first.copy({'confirmed': false})),
          'first',
        ),
        throwsFormatException,
      );
    },
  );
}
