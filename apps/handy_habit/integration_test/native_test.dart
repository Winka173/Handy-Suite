import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/data/store_native.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

Future<void> settleNative(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  expect(
    ready(),
    isTrue,
    reason: 'Native commit must finish before asserting UI',
  );
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native SQLite restart, exactly-once linked step, recovery and ZIP roundtrip',
    (tester) async {
      final directory = (await tester.runAsync(
        getApplicationSupportDirectory,
      ))!;
      final store = NativeHabitStore(
        '${directory.path}/habit-qa-${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      final now = DateTime.now(), today = localDay(now, 'Asia/Ho_Chi_Minh');
      var c = HabitController(open: () async => store);
      await tester.runAsync(c.load);
      expect(c.error, isNull);
      final habit = Habit(
        id: 'read',
        title: 'Read a few pages',
        created: today,
        type: 'count',
        schedules: [Schedule(id: 'daily', from: today, target: 2000)],
      );
      final routine = Routine(
        id: 'evening',
        title: 'Evening reading',
        steps: [
          RoutineStep(
            id: 'open',
            title: 'Open the book',
            seconds: 0,
            minimum: 0,
            habit: habit.id,
          ),
          RoutineStep(
            id: 'read',
            title: 'Read quietly',
            seconds: 600,
            minimum: 120,
          ),
          RoutineStep(
            id: 'notes',
            title: 'Write one thought',
            seconds: 300,
            minimum: 60,
            required: false,
          ),
        ],
      );
      await tester.runAsync(
        () => c.change(
          (s) => s.copy({
            'habits': [habit.toJson()],
            'routines': [routine.toJson()],
            'settings': {'onboarded': true, 'locale': 'en'},
          }),
        ),
      );
      await tester.pumpWidget(HabitApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('bead-${habit.id}')).first);
      await settleNative(tester, () => c.state!.events.length == 1);
      expect(HabitIndex(c.state!.events).value(habit.id, today), 1000);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      c = HabitController(open: () async => store);
      await tester.runAsync(c.load);
      expect(HabitIndex(c.state!.events).value(habit.id, today), 1000);
      await tester.pumpWidget(HabitApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('habit-native-today');
      // Phones use the bottom bar; wide screens the switch in the top bar.
      await tester.tap(
        find.byKey(
          Key(
            find.byKey(const Key('nav-2')).evaluate().isEmpty
                ? 'area-2'
                : 'nav-2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('routine-${routine.id}')).first);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('habit-native-builder');
      await tester.tap(find.byKey(const Key('routine-start')));
      await settleNative(tester, () => c.state!.sessions.isNotEmpty);
      await binding.takeScreenshot('habit-native-runner');
      final sessionId = c.state!.sessions.single.id;
      await tester.tap(find.byKey(const Key('routine-complete-step')));
      await settleNative(tester, () => c.state!.events.length == 2);
      expect(c.state!.events.where((e) => e.source == 'routine'), hasLength(1));
      expect(c.state!.routines.single.planned, 900);
      await tester.runAsync(
        () => c.change(
          (s) => completeStep(
            s,
            sessionId,
            expectedStep: 'open',
            today: today,
            now: now,
          ),
        ),
      );
      expect(c.state!.events, hasLength(2));
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      c = HabitController(open: () async => store);
      await tester.runAsync(c.load);
      expect(c.state!.events, hasLength(2));
      expect(c.state!.sessions.single.steps.first.status, 'completed');
      final encoded = backup(c.state!);
      expect(
        jsonEncode(restore(encoded).toJson()),
        jsonEncode(c.state!.toJson()),
      );
      final bad = encoded.sublist(0, 20);
      expect(() => restore(bad), throwsFormatException);
      expect(await tester.runAsync(store.integrity), 'ok');
      await tester.pumpWidget(HabitApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resume-session')));
      await tester.pumpAndSettle();
      expect(c.state!.sessions.single.running, isFalse);
      expect(c.state!.events, hasLength(2));
      await binding.takeScreenshot('habit-native-recovery');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
