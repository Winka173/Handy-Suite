import 'package:test/test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import '../tool/scale.dart' show scaleFixture;

void main() {
  test(
    'validated snapshots reuse immutable data but changed rows and hashes validate again',
    () {
      final s = scaleFixture(1);
      s.validate();
      expect(
        () => s.copy({
          'events': [s.events.first.toJson()..['value'] = 500],
        }),
        throwsFormatException,
      );
      expect(() => s.copy({'revision': -1}), throwsFormatException);
      final next = recordChange(
        s,
        record(
          s,
          HabitEvent(id: 'new', habit: 'h0', day: '2024-01-01', value: 1000),
          today: '2024-01-01',
        ),
        actor: 'a',
      );
      next.validate();
      final rows = next.operations.map((o) => o.toJson()).toList();
      rows.first['afterHash'] = '0' * 64;
      expect(() => next.copy({'operations': rows}), throwsFormatException);
      expect(
        () => next.withLedger([
          ...next.operations,
          HabitOperation.fromJson(rows.first),
        ], next.undoBatch),
        throwsFormatException,
      );
    },
  );
  for (final count in [1, 10, 100, 500]) {
    test(
      '$count habits / 3 years / 200 routines / 2000 moods: index and check-in budget',
      () {
        final s = scaleFixture(count);
        final watch = Stopwatch()..start();
        final index = HabitIndex.of(s);
        expect(index.totals.length, count * 1095);
        expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
        watch.reset();
        final changed = record(
          s,
          HabitEvent(id: 'new', habit: 'h0', day: '2024-01-01', value: 1000),
          today: '2024-01-01',
        );
        expect(changed.events.length, s.events.length + 1);
        expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
        expect(s.events.length, count * 1095);
        watch.reset();
        expect(
          progressDays(
            s.habits,
            '2023-01-01',
            '2023-12-31',
            '2024-01-01',
            index,
          ).length,
          365,
        );
        expect(
          insightCount(
            s.habits,
            '2023-10-01',
            '2023-12-31',
            '2024-01-01',
            index,
          ).kept,
          count * 92,
        );
        expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
        if (count == 500) {
          expect(() => prepareHabitSync(s), throwsA(isA<HabitSyncCapacity>()));
          expect(() => backup(s), throwsFormatException);
        } else {
          watch.reset();
          expect(restore(backup(s)).events.length, s.events.length);
          expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
          watch.reset();
          expect(
            mergeHabitStates(s, HabitState()).events.length,
            s.events.length,
          );
          expect(watch.elapsed, lessThan(const Duration(seconds: 60)));
          if (count == 100) {
            // The causal generation is larger than the source snapshot.
            expect(() => encodeHabitSync(s), throwsA(isA<HabitSyncCapacity>()));
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
