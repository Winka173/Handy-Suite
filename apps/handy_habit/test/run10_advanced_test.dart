import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:handy_habit/data/store_native.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_store/handy_store.dart';
import 'ui_test.dart' as f;
import 'run4_routines_test.dart' as actions;

HabitState advancedSeed() => f.seeded().copy({
  'routines': [
    Routine(
      id: 'r',
      title: 'A little movement',
      steps: [
        RoutineStep(
          id: 'weekday',
          title: 'Walk to the park',
          seconds: 600,
          minimum: 0,
          logic: StepLogic(weekdays: [1, 2, 3, 4, 5]),
        ),
        RoutineStep(
          id: 'a',
          title: 'Stretch gently',
          seconds: 300,
          minimum: 0,
          logic: StepLogic(branch: 'Movement', option: 'A'),
        ),
        RoutineStep(
          id: 'b',
          title: 'Read a few pages',
          seconds: 300,
          minimum: 0,
          logic: StepLogic(branch: 'Movement', option: 'B'),
        ),
      ],
    ).toJson(),
  ],
  'settings': {'onboarded': true, 'locale': 'en', 'routineAutoTimer': false},
});
Future<(HabitController, LifetimeController)> bootAdvanced(
  WidgetTester t, {
  bool pro = false,
  HabitState? state,
  Key? boundary,
}) async {
  final memory = f.MemoryStore()..value = state ?? f.seeded();
  final c = HabitController(
    open: () async => memory,
    clock: () => DateTime.utc(2026, 11, 14, 1),
  );
  await c.load();
  await t.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: HabitApp(
        controller: c,
        device: false,
        clock: () => DateTime.utc(2026, 11, 14, 1),
      ),
    ),
  );
  await t.pumpAndSettle();
  final entitlement = t
      .widget<LifetimeScope>(find.byType(LifetimeScope).last)
      .notifier!;
  entitlement.accept(
    StoreSnapshot(
      status: 'owned',
      productId: entitlement.config.productId,
      owned: pro,
      verified: pro,
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  return (c, entitlement);
}

Future<void> textTap(WidgetTester t, String text) async {
  final found = find.text(text).first;
  await t.ensureVisible(found);
  await t.pumpAndSettle();
  await t.tap(found);
  await t.pumpAndSettle();
}

void main() {
  test(
    'schema8 branch snapshot and trace survive a SQLite controller restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('habit-run10-');
      addTearDown(() => dir.delete(recursive: true));
      final store = NativeHabitStore('${dir.path}/habit.sqlite');
      final empty = await store.read();
      final initial = advancedSeed();
      final run = startSession(
        initial.routines.single,
        '2026-11-14',
        DateTime.utc(2026, 11, 14),
        state: initial,
      );
      var state = putSession(initial, run);
      state = chooseRoutineBranch(state, run.id, 'B');
      await store.commit(
        state.copy({'revision': empty.revision + 1}),
        expectedRevision: empty.revision,
      );
      final c = HabitController(open: () async => NativeHabitStore(store.path));
      await c.load();
      expect(c.error, isNull);
      expect(c.state!.sessions.single.toJson(), state.sessions.single.toJson());
      expect(
        c.state!.routines.single.toJson(),
        initial.routines.single.toJson(),
      );
      expect(c.state!.sessions.single.running, false);
      c.dispose();
    },
  );
  testWidgets(
    'stacking prompt appears after the linked habit step, with one credit',
    (t) async {
      final r = Routine(
        id: 'r',
        title: 'Read after water',
        steps: [
          RoutineStep(
            id: 'water',
            title: 'Drink water',
            seconds: 0,
            minimum: 0,
            habit: 'h',
          ),
          RoutineStep(
            id: 'read',
            title: 'Read quietly',
            seconds: 0,
            minimum: 0,
            logic: StepLogic(stackAfter: 'water'),
          ),
        ],
      );
      final state = f.seeded().copy({
        'routines': [r.toJson()],
        'settings': {
          'onboarded': true,
          'locale': 'en',
          'routineAutoTimer': false,
        },
      });
      final (c, _) = await bootAdvanced(t, state: state);
      await actions.route(t, '/routine/r');
      await actions.tap(t, 'routine-start');
      expect(find.text('After Drink water, do Read quietly.'), findsNothing);
      await actions.tap(t, 'routine-complete-step');
      expect(find.text('After Drink water, do Read quietly.'), findsOneWidget);
      expect(c.state!.events, hasLength(1));
      await actions.tap(t, 'routine-complete-step');
      await actions.tap(t, 'runner-finish');
      expect(c.state!.events, hasLength(1));
    },
  );
  testWidgets(
    'Basic is default; Advanced reveals title badges and a non-saving demo',
    (t) async {
      final (c, _) = await bootAdvanced(t);
      await actions.route(t, '/routine/r/edit');
      expect(
        t
            .widget<SwitchListTile>(find.byKey(const Key('routine-advanced')))
            .value,
        false,
      );
      expect(find.text('Reusable step blocks'), findsNothing);
      await actions.tap(t, 'routine-advanced');
      expect(find.text('Pro'), findsNWidgets(2));
      await textTap(t, 'Reusable step blocks');
      expect(find.text("Skipped: it's Saturday"), findsOneWidget);
      await textTap(t, 'Monday');
      expect(find.text('Ready: walk for 10 minutes'), findsOneWidget);
      expect(c.state!.revision, 0);
    },
  );
  testWidgets(
    'step Advanced is optional; non-Pro sees a demo, existing rules survive basic save',
    (t) async {
      final (c, _) = await bootAdvanced(t, state: advancedSeed());
      await actions.route(t, '/routine/r/edit');
      await actions.tap(t, 'draft-edit-weekday');
      expect(find.text('Days to run'), findsNothing);
      await actions.tap(t, 'step-advanced');
      expect(find.text('Pro'), findsNWidgets(7));
      await textTap(t, 'Days to run');
      expect(find.byKey(const Key('logic-weekday-1')), findsNothing);
      await actions.tap(t, 'editor-save');
      await actions.tap(t, 'editor-save');
      expect(c.state!.routines.single.steps.first.logic.weekdays, [
        1,
        2,
        3,
        4,
        5,
      ]);
    },
  );
  testWidgets(
    'Pro can save weekday rules and the final save rechecks entitlement',
    (t) async {
      final (c, entitlement) = await bootAdvanced(t, pro: true);
      await actions.route(t, '/routine/r/edit');
      await actions.tap(t, 'draft-edit-a');
      await actions.tap(t, 'step-advanced');
      await textTap(t, 'Days to run');
      expect(find.text('Pro'), findsNothing);
      await actions.tap(t, 'logic-weekday-1');
      await actions.tap(t, 'editor-save');
      await actions.tap(t, 'editor-save');
      expect(c.state!.routines.single.steps.first.logic.weekdays, [1]);
      await actions.route(t, '/routine/r/edit');
      await actions.tap(t, 'draft-edit-a');
      await actions.tap(t, 'step-advanced');
      await textTap(t, 'Days to run');
      await actions.tap(t, 'logic-weekday-2');
      await actions.tap(t, 'editor-save');
      entitlement.accept(
        StoreSnapshot(status: 'ready', productId: entitlement.config.productId),
      );
      await t.pumpAndSettle();
      await actions.tap(t, 'editor-save');
      expect(find.byKey(const Key('sheet-error')), findsOneWidget);
      expect(c.state!.routines.single.steps.first.logic.weekdays, [1]);
    },
  );
  testWidgets('non-Pro cannot remove advanced nodes to bypass the edit gate', (
    t,
  ) async {
    final (c, _) = await bootAdvanced(t, state: advancedSeed());
    await actions.route(t, '/routine/r/edit');
    await actions.tap(t, 'draft-remove-weekday');
    await actions.tap(t, 'editor-save');
    expect(find.byKey(const Key('sheet-error')), findsOneWidget);
    expect(c.state!.routines.single.steps, hasLength(3));
  });
  testWidgets(
    'existing advanced routine runs without Pro, explains skips and branch in summary',
    (t) async {
      final (c, _) = await bootAdvanced(t, state: advancedSeed());
      await actions.route(t, '/routine/r');
      await actions.tap(t, 'routine-start');
      expect(find.textContaining("Skipped: it's Saturday"), findsOneWidget);
      expect(find.text('The timer waits for your choice.'), findsOneWidget);
      expect(find.byKey(const Key('routine-complete-step')), findsNothing);
      expect(find.byKey(const Key('runner-clock')), findsNothing);
      await actions.tap(t, 'branch-B');
      expect(c.state!.sessions.single.choices, {'Movement': 'B'});
      expect(find.textContaining('Skipped: chose path B'), findsOneWidget);
      await actions.tap(t, 'routine-complete-step');
      await actions.tap(t, 'runner-finish');
      expect(c.state!.sessions.single.status, 'finished');
      expect(find.text('Run summary'), findsOneWidget);
      expect(find.text("Skipped: it's Saturday"), findsOneWidget);
      expect(
        c.state!.sessions.single.trace.where((v) => v['kind'] == 'choice'),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'Pro blocks and presets stay in draft and insert independent copies',
    (t) async {
      final (c, _) = await bootAdvanced(t, pro: true);
      await actions.route(t, '/routine/r/edit');
      await actions.tap(t, 'routine-advanced');
      await textTap(t, 'Reusable step blocks');
      await actions.tap(t, 'save-blocks');
      await t.enterText(find.byKey(const Key('field-name')), 'Read together');
      await actions.tap(t, 'editor-save');
      expect(c.state!.routines.single.blocks, isEmpty);
      await textTap(t, 'Read together');
      await textTap(t, 'Saved presets');
      await actions.tap(t, 'save-presets');
      await t.enterText(find.byKey(const Key('field-name')), 'Slow morning');
      await actions.tap(t, 'editor-save');
      await actions.tap(t, 'editor-save');
      final r = c.state!.routines.single;
      expect(r.blocks.single.title, 'Read together');
      expect(r.presets.single.title, 'Slow morning');
      expect(r.steps, hasLength(4));
      expect(r.steps.map((s) => s.id).toSet(), hasLength(4));
    },
  );
}
