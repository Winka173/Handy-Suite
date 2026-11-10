import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/data/store.dart';
import 'package:handy_habit/runner.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

class MemoryStore implements HabitStore {
  HabitState value = HabitState(settings: {'onboarded': true});
  @override
  Future<HabitState> read() async => value;
  @override
  Future<void> commit(HabitState next, {required int expectedRevision}) async {
    if (expectedRevision != value.revision) throw StateError('stale');
    value = next;
  }

  @override
  Future<String> integrity() async => 'ok';
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty)
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .hitTestable()
          .first,
    );
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<HabitController> start(
  WidgetTester tester, {
  HabitState? state,
  int tab = 0,
  String locale = 'en',
}) async {
  final store = MemoryStore();
  if (state != null) store.value = state;
  final c = HabitController(open: () async => store);
  await c.load();
  store.value = store.value.copy({
    'settings': {...store.value.settings, 'locale': locale},
  });
  await c.load();
  await tester.pumpWidget(
    HabitApp(controller: c, clock: () => DateTime.utc(2024, 1, 8, 12)),
  );
  await tester.pumpAndSettle();
  if (tab != 0) await tapKey(tester, 'nav-$tab');
  return c;
}

HabitState seeded() => HabitState(
  habits: [
    Habit(
      id: 'h',
      title: 'Read a few pages',
      created: '2024-01-01',
      schedules: [Schedule(id: 'v', from: '2024-01-01')],
    ),
  ],
  routines: [
    Routine(
      id: 'r',
      title: 'Evening reading',
      steps: [
        RoutineStep(
          id: 'a',
          title: 'Open book',
          seconds: 0,
          minimum: 0,
          habit: 'h',
        ),
        RoutineStep(
          id: 'b',
          title: 'Read quietly',
          seconds: 60,
          minimum: 30,
          required: false,
        ),
      ],
    ),
  ],
  settings: {'onboarded': true},
);

void main() {
  testWidgets(
    'archived link is explicit and completing step records no habit event',
    (tester) async {
      final store = MemoryStore();
      final base = seeded();
      final session = startSession(
        base.routines.single,
        '2024-01-08',
        DateTime.utc(2024, 1, 8),
      );
      store.value = base.copy({
        'habits': [
          base.habits.single.copy({'archived': true}).toJson(),
        ],
        'sessions': [session.toJson()],
      });
      final c = HabitController(open: () async => store);
      await c.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHandyTheme(habitAccent, Brightness.light),
          home: RoutineRunner(
            controller: c,
            sessionId: session.id,
            clock: () => DateTime.utc(2024, 1, 8),
            fresh: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Linked habit is archived'), findsOneWidget);
      await tester.tap(find.byKey(const Key('routine-complete-step')));
      await tester.pumpAndSettle();
      expect(c.state!.events, isEmpty);
      expect(c.state!.sessions.single.steps.first.status, 'completed');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'recover a running session after mounting without notifying during build',
    (tester) async {
      final store = MemoryStore();
      final routine = seeded().routines.single;
      final session = startSession(
        routine,
        '2024-01-08',
        DateTime.utc(2024, 1, 8),
      );
      store.value = seeded().copy({
        'sessions': [session.toJson()],
      });
      final c = HabitController(open: () async => store);
      await c.load();
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: c,
          builder: (context, _) => MaterialApp(
            theme: buildHandyTheme(habitAccent, Brightness.light),
            home: RoutineRunner(
              controller: c,
              sessionId: session.id,
              clock: () => DateTime.utc(2024, 1, 8, 0, 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.state!.sessions.single.running, isFalse);
      expect(c.state!.sessions.single.recoveryWarning, isTrue);
      expect(c.state!.sessions.single.steps.first.elapsed, 60);
      expect(c.state!.events, isEmpty);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('background pauses a fresh timer and resume stays explicit', (
    tester,
  ) async {
    final store = MemoryStore();
    final routine = seeded().routines.single;
    final session = startSession(
      routine,
      '2024-01-08',
      DateTime.utc(2024, 1, 8),
    );
    store.value = seeded().copy({
      'sessions': [session.toJson()],
    });
    final c = HabitController(open: () async => store);
    await c.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHandyTheme(habitAccent, Brightness.light),
        home: RoutineRunner(
          controller: c,
          sessionId: session.id,
          clock: () => DateTime.utc(2024, 1, 8),
          fresh: true,
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(c.state!.sessions.single.running, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(c.state!.sessions.single.running, isFalse);
    expect(c.state!.events, isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    'new habit, one tap marks it once, a full bead opens the day and cancel keeps it',
    (tester) async {
      final c = await start(tester);
      await tapKey(tester, 'habit-add');
      await tapKey(tester, 'add-habit');
      await tapKey(tester, 'preset-blank');
      await tester.enterText(
        find.byKey(const Key('field-title')),
        'Read a few pages',
      );
      await tapKey(tester, 'editor-save');
      expect(c.state!.habits.length, 1);
      final id = c.state!.habits.single.id;
      await tapKey(tester, 'bead-$id');
      expect(c.state!.events.single.value, 1000);
      // Done already: the tap opens the day; cancel writes nothing.
      await tapKey(tester, 'bead-$id');
      expect(find.byKey(const Key('editor-save')), findsOneWidget);
      await tapKey(tester, 'sheet-cancel');
      expect(c.state!.events.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('a count adds one per tap and never passes the target', (
    tester,
  ) async {
    final c = await start(
      tester,
      state: HabitState(
        habits: [
          Habit(
            id: 'w',
            title: 'Glasses of water',
            created: '2024-01-01',
            type: 'count',
            schedules: [Schedule(id: 'v', from: '2024-01-01', target: 2000)],
          ),
        ],
        settings: {'onboarded': true},
      ),
    );
    await tapKey(tester, 'bead-w');
    await tapKey(tester, 'bead-w');
    expect(c.state!.events.fold(0, (v, e) => v + e.value), 2000);
    await tapKey(tester, 'bead-w');
    await tapKey(tester, 'sheet-cancel');
    expect(c.state!.events.length, 2);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('minutes ask how much; the rest of the target is one tap', (
    tester,
  ) async {
    final c = await start(
      tester,
      state: HabitState(
        habits: [
          Habit(
            id: 'm',
            title: 'Walk',
            created: '2024-01-01',
            type: 'duration',
            unit: 'min',
            schedules: [Schedule(id: 'v', from: '2024-01-01', target: 30000)],
          ),
        ],
        settings: {'onboarded': true},
      ),
    );
    await tapKey(tester, 'bead-m');
    await tester.enterText(find.byKey(const Key('amount-custom')), '12,5');
    await tapKey(tester, 'amount-add');
    expect(c.state!.events.single.value, 12500);
    await tapKey(tester, 'bead-m');
    await tapKey(tester, 'amount-rest');
    expect(c.state!.events.fold(0, (v, e) => v + e.value), 30000);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('a past day is filled in from the month grid', (tester) async {
    final c = await start(tester, state: seeded());
    await tapKey(tester, 'habit-h');
    expect(find.byKey(const Key('habit-current')), findsOneWidget);
    await tapKey(tester, 'day-2024-01-05');
    await tapKey(tester, 'field-state-done');
    await tapKey(tester, 'editor-save');
    expect(c.state!.events.single.day, '2024-01-05');
    // The month before the habit began cannot be opened.
    final prev = tester.widget<IconButton>(find.byKey(const Key('grid-prev')));
    expect(prev.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('trash retains records and links; permanent delete cleans them', (
    tester,
  ) async {
    final c = await start(
      tester,
      state: seeded().copy({
        'events': [
          HabitEvent(
            id: 'e',
            habit: 'h',
            day: '2024-01-07',
            value: 1000,
          ).toJson(),
        ],
      }),
    );
    await tapKey(tester, 'habit-h');
    await tapKey(tester, 'more-menu');
    await tapKey(tester, 'habit-delete');
    await tapKey(tester, 'confirm-action');
    expect(c.state!.liveHabits, isEmpty);
    expect(c.state!.events.single.id, 'e');
    expect(c.state!.routines.single.steps.first.habit, 'h');
    expect(c.state!.trash.single.entity, 'h');
    await c.change((s) => deleteTrash(s, s.trash.single.id), remember: false);
    expect(c.state!.habits, isEmpty);
    expect(c.state!.events, isEmpty);
    expect(c.state!.routines.single.steps.first.habit, isNull);
    expect(c.state!.tombstones.single['entity'], 'h');
    expect(c.state!.routines.single.steps, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    'running a routine leaves it as it is, and a linked step records once',
    (tester) async {
      final c = await start(tester, state: seeded(), tab: 2);
      await tapKey(tester, 'routine-r');
      expect(c.state!.routines.single.planned, 60);
      await tapKey(tester, 'routine-start');
      expect(find.byKey(const Key('routine-complete-step')), findsOneWidget);
      await tester.tap(find.byKey(const Key('routine-complete-step')));
      await tester.pumpAndSettle();
      expect(c.state!.events.length, 1);
      expect(c.state!.events.single.source, 'routine');
      expect(c.state!.sessions.single.steps.first.status, 'completed');
      expect(c.state!.routines.single.planned, 60);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'first open: skippable guide leaves a blank day, ads off during guide',
    (tester) async {
      final c = await start(tester, state: HabitState());
      expect(find.byKey(const Key('welcome-next')), findsOneWidget);
      expect(c.adsVisible.value, isFalse);
      await tapKey(tester, 'welcome-skip');
      expect(c.state!.settings['onboarded'], isTrue);
      expect(c.state!.habits, isEmpty);
      expect(c.state!.routines, isEmpty);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
    testWidgets(
      'three areas, habit management and long Vietnamese text fit $width wide',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = await start(tester, state: seeded(), locale: 'vi');
        await tapKey(tester, 'today-all-habits');
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        for (final label in ['Quy trình', 'Tiến bộ', 'Hôm nay']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
}
