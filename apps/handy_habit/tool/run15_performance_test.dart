import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/data/store.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../../packages/handy_habit_engine/tool/scale.dart' show scaleFixture;
import 'run10_screens_test.dart' show fonts;

class Memory implements HabitStore {
  HabitState value;
  int commits = 0;
  Memory(this.value);
  @override
  Future<HabitState> read() async => value;
  @override
  Future<void> commit(HabitState next, {required int expectedRevision}) async {
    if (value.revision != expectedRevision) throw StateError('stale');
    value = next;
    commits++;
  }

  @override
  Future<String> integrity() async => 'ok';
}

void main() {
  setUpAll(fonts);
  for (final count in [1, 10, 100, 500])
    testWidgets(
      'host $count Today build and check-in',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final memory = Memory(scaleFixture(count)),
            now = DateTime.utc(2024, 1, 1, 12);
        final c = HabitController(open: () async => memory, clock: () => now);
        await c.load();
        final watch = Stopwatch()..start();
        await t.pumpWidget(
          HabitApp(controller: c, clock: () => now, device: false),
        );
        await t.pumpAndSettle();
        final build = watch.elapsedMicroseconds / 1000;
        double? check;
        // BASELINE_SKIP: repeated binary validation already exceeded the baseline
        // timeout at 100/500; do not hang the host render to recapture that failure.
        if (!const bool.fromEnvironment('BASELINE_SKIP') || count < 100) {
          watch.reset();
          await c.change(
            (s) => record(
              s,
              HabitEvent(
                id: 'check',
                habit: 'h0',
                day: '2024-01-01',
                value: 1000,
              ),
              today: '2024-01-01',
            ),
          );
          await t.pumpAndSettle();
          check = watch.elapsedMicroseconds / 1000;
          expect(memory.commits, 1);
        }
        final result = {
          'habits': count,
          'today_build_ms': build,
          'check_in_to_frame_ms': check,
          'commits': memory.commits,
        };
        debugPrint('HOST_PERFORMANCE ${jsonEncode(result)}');
        expect(build, lessThan(10000), reason: 'Host Today build regression');
        if (check != null) {
          expect(check, lessThan(10000), reason: 'Host check-in regression');
        }
        final out = Platform.environment['HABIT_PERF_OUT'];
        if (out != null)
          File(
            out,
          ).writeAsStringSync('${jsonEncode(result)}\n', mode: FileMode.append);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        c.dispose();
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
}
