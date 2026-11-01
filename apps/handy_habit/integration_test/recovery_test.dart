import 'dart:io' show pid;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/data/store_native.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'process restart preserves linked entry and pauses unfinished plan',
    (tester) async {
      const reopen = bool.fromEnvironment('HABIT_REOPEN');
      final dir = (await tester.runAsync(getApplicationSupportDirectory))!;
      final c = HabitController(
        open: () async =>
            NativeHabitStore('${dir.path}/habit-process-qa.sqlite'),
      );
      await tester.runAsync(c.load);
      expect(c.error, isNull);
      final now = DateTime.now(), today = localDay(now, 'Asia/Ho_Chi_Minh');
      if (!reopen) {
        final h = Habit(
          id: 'process-h',
          title: 'Process recovery habit',
          type: 'count',
          created: today,
          schedules: [Schedule(id: 'v', from: today, target: 2000)],
        );
        final routine = Routine(
          id: 'process-r',
          title: 'Process recovery routine',
          steps: [
            RoutineStep(id: 'one', title: 'First action', habit: h.id),
            RoutineStep(id: 'two', title: 'Second action'),
          ],
        );
        var state = HabitState(
          habits: [h],
          routines: [routine],
          settings: {'onboarded': true, 'locale': 'en'},
        );
        final session = startSession(
          routine,
          today,
          now,
        ).copy({'id': 'process-session'});
        state = completeStep(
          putSession(state, session),
          session.id,
          expectedStep: 'one',
          today: today,
          now: now,
        );
        state = putSession(
          state,
          state.sessions.single.copy({'anchor': now.toUtc().toIso8601String()}),
        );
        final seeded = state;
        await tester.runAsync(() => c.change((_) => seeded));
      }
      expect(c.state!.events, hasLength(1));
      expect(c.state!.events.single.source, 'routine');
      expect(c.state!.sessions.single.steps.first.status, 'completed');
      expect(c.state!.sessions.single.cursor, 1);
      if (reopen) {
        await tester.pumpWidget(HabitApp(controller: c));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('resume-session')));
        for (var i = 0; i < 100 && c.state!.sessions.single.running; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(c.state!.sessions.single.running, isFalse);
        expect(c.state!.sessions.single.recoveryWarning, isTrue);
        expect(c.state!.events, hasLength(1));
      } else {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Text('Handy Habit restart fixture saved')),
          ),
        );
        await tester.pumpAndSettle();
      }
      // Collected by the host runner; two different PIDs prove a new process.
      debugPrint('HABIT_QA_PROCESS=$pid REOPEN=$reopen');
      binding.reportData = {
        'process': pid,
        'reopen': reopen,
        'linkedEvents': c.state!.events.length,
      };
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
