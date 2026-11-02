import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip/data/store_native.dart';
import 'package:handy_trip/controller.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:sqlite3/sqlite3.dart';

Trip trip() => Trip({
  'id': 'trip',
  'title': 'Offline journey',
  'start': '2026-11-01',
  'end': '2026-11-03',
  'zone': 'Asia/Ho_Chi_Minh',
  'currency': 'VND',
  'created': '2026-11-01T00:00:00Z',
  'updated': '2026-11-01T00:00:00Z',
});

void main() {
  late Directory directory;
  late NativeTripStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('handy-trip-test-');
    store = NativeTripStore('${directory.path}/trip.sqlite');
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'SQLite survives a fresh store, rejects stale writers and unlinks plans atomically',
    () async {
      final empty = await store.read();
      var state = empty
          .put('trips', trip())
          .put('places', Place({'id': 'place', 'name': 'Saved place'}));
      state = state.put(
        'stops',
        Stop({
          'id': 'stop',
          'trip': 'trip',
          'place': 'place',
          'title': 'Planned',
          'day': '2026-11-02',
        }),
      );
      state = checkIn(
        state,
        Visit({
          'id': 'visit',
          'trip': 'trip',
          'stop': 'stop',
          'place': 'place',
          'zone': 'Asia/Ho_Chi_Minh',
          'at': '2026-11-02T01:00:00Z',
          'origin': 'manual',
          'confirmed': true,
          'created': '2026-11-02T01:00:00Z',
          'updated': '2026-11-02T01:00:00Z',
        }),
        now: DateTime.utc(2026, 11, 2, 2),
      );
      await store.commit(state.copy({'revision': 1}), expectedRevision: 0);
      final reopened = await NativeTripStore(store.path).read();
      expect(reopened.visits.single.key, 'visit');
      expect(reopened.stops.single.status, 'visited');
      await expectLater(
        store.commit(empty.copy({'revision': 1}), expectedRevision: 0),
        throwsStateError,
      );
      await store.commit(
        removeEntity(reopened, 'trips', 'trip').copy({'revision': 2}),
        expectedRevision: 1,
      );
      final after = await store.read();
      expect(after.trips, isEmpty);
      expect(after.visits.single.trip, isNull);
      expect(after.visits.single.stop, isNull);
      expect(after.places.single.key, 'place');
      expect(await store.integrity(), 'ok');
    },
  );

  test(
    'disk write failure rolls back every table, revision and Undo publication',
    () async {
      await store.read();
      final controller = TripController(open: () async => store);
      await controller.load();
      await controller.change((s) => s.put('trips', trip()));
      final db = openTripDatabase(store.path);
      db.execute(
        "CREATE TRIGGER fail_expense BEFORE INSERT ON expenses BEGIN SELECT RAISE(ABORT,'injected disk failure'); END",
      );
      db.close();
      final revision = controller.state!.revision;
      await expectLater(
        controller.change(
          (s) => s
              .put('trips', trip().copy({'title': 'Must roll back'}))
              .put(
                'expenses',
                Expense({
                  'id': 'expense',
                  'trip': 'trip',
                  'at': '2026-11-02T01:00:00Z',
                  'currency': 'VND',
                  'minor': '100000',
                }),
              ),
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(controller.state!.trip('trip').title, 'Offline journey');
      final reopened = await store.read();
      expect(reopened.revision, revision);
      expect(reopened.trip('trip').title, 'Offline journey');
      expect(reopened.expenses, isEmpty);
      await controller.undo();
      expect((await store.read()).trips, isEmpty);
      controller.dispose();
    },
  );

  test(
    'future database and corrupt file are preserved instead of reset',
    () async {
      final db = sqlite3.open(store.path);
      db.execute(
        'PRAGMA user_version=99; CREATE TABLE sentinel(value TEXT); INSERT INTO sentinel VALUES(\'keep\')',
      );
      db.close();
      await expectLater(store.read(), throwsFormatException);
      final kept = sqlite3.open(store.path);
      expect(kept.userVersion, 99);
      expect(kept.select('SELECT value FROM sentinel').single['value'], 'keep');
      kept.close();
      final corrupt = File('${directory.path}/broken.sqlite');
      final bytes = Uint8List.fromList(List.generate(128, (i) => i));
      await corrupt.writeAsBytes(bytes);
      await expectLater(
        NativeTripStore(corrupt.path).read(),
        throwsA(isA<SqliteException>()),
      );
      expect(await corrupt.readAsBytes(), bytes);
    },
  );
}
