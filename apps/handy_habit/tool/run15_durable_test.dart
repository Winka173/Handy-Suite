import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/data/store_native.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

void main() {
  test(
    'host durable check-in at 100 habits and 10k logs',
    () async {
      final folder = Directory.systemTemp.createTempSync(
        'habit-durable-bench-',
      );
      addTearDown(() => folder.deleteSync(recursive: true));
      final store = NativeHabitStore('${folder.path}/habit.sqlite');
      await store.read();
      final seed = prepareHabitSync(
        HabitState(
          revision: 1,
          habits: [
            for (var i = 0; i < 100; i++)
              Habit(
                id: 'h$i',
                title: 'Habit $i',
                created: '2023-01-01',
                schedules: [Schedule(id: 'g$i', from: '2023-01-01')],
              ),
          ],
          events: [
            for (var i = 0; i < 10000; i++)
              HabitEvent(
                id: 'e$i',
                habit: 'h${i % 100}',
                day: addDays('2023-01-01', i ~/ 100),
                value: 1000,
              ),
          ],
        ),
      );
      await store.commit(seed, expectedRevision: 0);
      final c = HabitController(
        open: () async => store,
        clock: () => DateTime.utc(2024, 1, 1),
      );
      await c.load();
      final times = <double>[];
      for (var i = 0; i < 6; i++) {
        final watch = Stopwatch()..start();
        await c.change(
          (s) => record(
            s,
            HabitEvent(
              id: 'new$i',
              habit: 'h$i',
              day: '2024-01-01',
              value: 1000,
            ),
            today: '2024-01-01',
          ),
        );
        times.add(watch.elapsedMicroseconds / 1000);
      }
      final samples = times.skip(1).toList()..sort();
      final result = {
        'habits': 100,
        'logs': 10000,
        'operations': c.state!.operations.length,
        'warmup_ms': times.first,
        'samples_ms': samples,
        'p95_ms': samples.last,
        'sqlite_bytes': File(store.path).lengthSync(),
        'raw_backup_bytes': backup(c.state!, zip: false).length,
        'process_rss_bytes': ProcessInfo.currentRss,
      };
      File('build/run15/durable.json').writeAsStringSync(jsonEncode(result));
      expect(
        samples.last,
        lessThan(1000),
        reason: 'Host durable commit regression',
      );
      expect((await store.read()).events.length, 10006);
      expect(await store.integrity(), 'ok');
      c.dispose();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
