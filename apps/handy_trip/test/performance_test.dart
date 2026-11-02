import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip/data/store_native.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'ui_test.dart' show sample;

void main() {
  test(
    'SQLite performance fixture 10/100/1000 trips and 10000 visits, exact restore',
    () async {
      final dir = await Directory.systemTemp.createTemp('trip-scale-');
      final results = <Object>[];
      try {
        for (final count in [10, 100, 1000]) {
          final base = sample(), template = base.trip('t').toJson();
          final state = base.copy({
            'trips': [
              for (var i = 0; i < count; i++)
                {...template, 'id': i == 0 ? 't' : 'trip$i'},
            ],
            'visits': List.generate(
              count == 1000 ? 10000 : count * 10,
              (i) => {
                'id': 'visit$i',
                'trip': 't',
                'place': 'p',
                'at': '2026-11-01T01:00:00Z',
                'zone': 'Asia/Ho_Chi_Minh',
                'origin': 'manual',
                'confirmed': true,
                'created': '2026-11-01T01:00:00Z',
                'updated': '2026-11-01T01:00:00Z',
              },
            ),
            'revision': 1,
          });
          final store = NativeTripStore('${dir.path}/scale-$count.sqlite');
          await store.read();
          final write = Stopwatch()..start();
          await store.commit(state, expectedRevision: 0);
          write.stop();
          final read = Stopwatch()..start();
          final restored = await NativeTripStore(store.path).read();
          read.stop();
          expect(restored.trips.length, count);
          expect(restored.visits.length, state.visits.length);
          final search = Stopwatch()..start();
          expect(
            restored.visits
                .where(
                  (v) => restored
                      .place(v.place)
                      .name
                      .toLowerCase()
                      .contains('museum'),
                )
                .length,
            state.visits.length,
          );
          search.stop();
          final portability = Stopwatch()..start();
          final back = readBackup(fullBackup(restored));
          portability.stop();
          expect(back.toJson(), restored.toJson());
          results.add({
            'trips': count,
            'visits': restored.visits.length,
            'sqliteWriteMs': write.elapsedMilliseconds,
            'sqliteColdReadMs': read.elapsedMilliseconds,
            'filterMs': search.elapsedMilliseconds,
            'zipRoundTripMs': portability.elapsedMilliseconds,
            'processRssBytes': ProcessInfo.currentRss,
            'databaseBytes': await File(store.path).length(),
          });
        }
        File('../../docs/qa/evidence/trip-performance.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'environment':
                'Windows Flutter host test; no image-heavy/device scroll claim',
            'measurements': results,
          }),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
