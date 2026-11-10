import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/reminders.dart';
import 'package:handy_habit/settings/help_topics.dart';
import 'package:handy_habit/welcome/welcome_page.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_habit/run_notice.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'pause_ui_test.dart' show FakeNotices;
import 'ui_test.dart' as f;
import 'run4_routines_test.dart' show route, DraftStore;

Future<void> tap(WidgetTester t, String key) async {
  final target = find.byKey(Key(key));
  if (target.evaluate().isEmpty) {
    final scroll = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last;
    t.state<ScrollableState>(scroll).position.jumpTo(0);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(target, 250, scrollable: scroll, maxScrolls: 80);
  }
  await t.ensureVisible(target.last);
  await t.pumpAndSettle();
  await t.tap(target.last);
  await t.pumpAndSettle();
}

class LearningReminders extends HabitReminders {
  int requests = 0, tests = 0;
  bool allowed = false;
  bool fails = false;
  @override
  bool get supported => true;
  @override
  Future<bool> request() async {
    requests++;
    return allowed;
  }

  @override
  Future<bool> permission() async => allowed;
  @override
  Future<void> sync(HabitState state) async {}
  @override
  Future<void> test(HabitState state) async {
    if (fails) throw StateError('test failed');
    tests++;
  }
}

Future<(HabitController, DraftStore, LearningReminders)> learningBoot(
  WidgetTester t, {
  HabitState? state,
  LifetimeController? tier,
}) async {
  final store = DraftStore()
    ..value = state ?? HabitState(settings: {'locale': 'en'});
  final c = HabitController(
    open: () async => store,
    clock: () => DateTime.utc(2024, 1, 8, 12),
  );
  await c.load();
  final reminders = LearningReminders();
  await t.pumpWidget(
    LifetimeScope(
      notifier: tier,
      child: HabitApp(
        controller: c,
        reminders: reminders,
        device: false,
        clock: () => DateTime.utc(2024, 1, 8, 12),
      ),
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  return (c, store, reminders);
}

class TestTier extends ChangeNotifier implements LifetimeController {
  @override
  final bool pro;
  TestTier(this.pro);
  @override
  MonetizationConfig get config => const MonetizationConfig();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> backupContents(HabitState s) => Map<String, dynamic>.from(
  jsonDecode(utf8.decode(backup(s, zip: false))) as Map,
)..remove('backupCreatedAt');

Future<void> practiceStart(WidgetTester t) async {
  await tap(t, 'welcome-next');
  await tap(t, 'welcome-next');
}

void main() {
  test('help folds Vietnamese precomposed and combining accents', () {
    expect(foldHabitHelp('THÓI QUEN Đều đặn'), 'thoi quen deu dan');
    expect(foldHabitHelp('tho\u0301i quen'), 'thoi quen');
  });

  testWidgets(
    'two story beats no questions; Enter, Back, Esc, system back undo beats and steps',
    (t) async {
      final (c, store, reminders) = await learningBoot(t);
      expect(find.textContaining('?'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('welcome-back')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text('Small actions. Visible days.'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Good intentions drift away.'), findsOneWidget);
      await practiceStart(t);
      await tap(t, 'practice-bead');
      expect(find.text('1 / 3 times'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('0 / 3 times'), findsOneWidget);
      await tap(t, 'welcome-back');
      expect(find.text('Small actions. Visible days.'), findsOneWidget);
      await tap(t, 'welcome-back');
      expect(find.text('Good intentions drift away.'), findsOneWidget);
      expect(store.writes, 0);
      expect(reminders.requests, 0);
      expect(c.state!.habits, isEmpty);
    },
  );

  testWidgets(
    'every real practice step, goal edit, ring, one Start; practice writes no state or backup',
    (t) async {
      final (c, store, reminders) = await learningBoot(t);
      final before = backupContents(c.state!);
      await practiceStart(t);
      for (final key in ['practice-bead', 'practice-undo']) await tap(t, key);
      await tap(t, 'practice-goal');
      await t.enterText(find.byKey(const Key('practice-goal-value')), '8');
      await tap(t, 'practice-goal-save');
      expect(find.text('0 / 8 times'), findsOneWidget);
      await tap(t, 'practice-start');
      await tap(t, 'practice-complete');
      expect(find.text('1 of 2 kept today'), findsOneWidget);
      await tap(t, 'welcome-do-it');
      expect(find.byKey(const Key('practice-instruction-6')), findsOneWidget);
      expect(backupContents(c.state!), before);
      expect(store.writes, 0);
      await tap(t, 'welcome-next');
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await tap(t, 'welcome-next');
      expect(c.state!.settings['onboarded'], true);
      expect(store.writes, 1);
      expect(reminders.requests, 0);
      expect(c.state!.habits, isEmpty);
      expect(c.state!.events, isEmpty);
      expect(c.state!.sessions, isEmpty);
      expect(find.byKey(const Key('goal-water')), findsOneWidget);
    },
  );

  testWidgets(
    'Do it for me advances every practice microstep and Back reverses them',
    (t) async {
      final (_, store, _) = await learningBoot(t);
      await practiceStart(t);
      for (var i = 1; i <= 6; i++) {
        await tap(t, 'welcome-do-it');
        expect(find.byKey(Key('practice-instruction-$i')), findsOneWidget);
        await tap(t, 'welcome-back');
        expect(
          find.byKey(Key('practice-instruction-${i - 1}')),
          findsOneWidget,
        );
        await tap(t, 'welcome-do-it');
      }
      await tap(t, 'welcome-next');
      await tap(t, 'welcome-back');
      expect(find.byKey(const Key('practice-instruction-6')), findsOneWidget);
      expect(store.writes, 0);
    },
  );

  for (final stage in [0, 1, 2])
    testWidgets('Skip at stage $stage saves only completion flag', (t) async {
      final (c, store, r) = await learningBoot(t);
      if (stage > 0) await practiceStart(t);
      if (stage == 2) {
        for (var i = 0; i < 6; i++) await tap(t, 'welcome-do-it');
        await tap(t, 'welcome-next');
      }
      await tap(t, 'welcome-skip');
      expect(c.state!.settings['onboarded'], true);
      expect(c.state!.habits, isEmpty);
      expect(store.writes, 1);
      expect(r.requests, 0);
      await c.load();
      await t.pumpAndSettle();
      t.state<ScrollableState>(find.byType(Scrollable).last).position.jumpTo(0);
      await t.pumpAndSettle();
      expect(find.byType(HabitWelcomePage), findsNothing);
    });

  testWidgets(
    'completion failure stays in guide with retry and unchanged data',
    (t) async {
      final (c, store, _) = await learningBoot(t);
      store.fail = true;
      await tap(t, 'welcome-skip');
      expect(find.text('Could not save. Try again.'), findsOneWidget);
      expect(c.state!.settings['onboarded'], isNull);
      store.fail = false;
      await tap(t, 'welcome-skip');
      expect(c.state!.settings['onboarded'], true);
    },
  );

  testWidgets(
    'existing library without guide flag is never forced; replay from Settings and help writes nothing',
    (t) async {
      final (c, store, r) = await learningBoot(
        t,
        state: f.seeded().copy({
          'settings': {'locale': 'en'},
        }),
      );
      expect(find.byType(HabitWelcomePage), findsNothing);
      final before = backupContents(c.state!);
      await route(t, '/settings');
      await tap(t, 'settings-replay');
      await practiceStart(t);
      for (var i = 0; i < 6; i++) await tap(t, 'welcome-do-it');
      await tap(t, 'welcome-next');
      await tap(t, 'welcome-next');
      expect(find.byType(HabitWelcomePage), findsNothing);
      await route(t, '/help');
      await tap(t, 'help-replay');
      await tap(t, 'welcome-skip');
      expect(backupContents(c.state!), before);
      expect(store.writes, 0);
      expect(r.requests, 0);
    },
  );

  testWidgets(
    'optional empty Today goal opens editable preset without saving',
    (t) async {
      final (c, store, _) = await learningBoot(
        t,
        state: HabitState(settings: {'onboarded': true, 'locale': 'en'}),
      );
      await tap(t, 'goal-water');
      expect(find.text('Drink water'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(c.state!.habits, isEmpty);
      expect(store.writes, 0);
    },
  );

  testWidgets(
    'help searches with and without accents; no match clears; contextual routes open exact topic',
    (t) async {
      await learningBoot(t, state: f.seeded());
      await route(t, '/help');
      for (final query in ['thoi quen', 'thói quen']) {
        await t.enterText(find.byKey(const Key('help-search')), query);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('help-topic-start')), findsOneWidget);
      }
      await t.enterText(find.byKey(const Key('help-search')), 'zzzz');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('help-no-match')), findsOneWidget);
      await tap(t, 'help-clear');
      expect(find.byKey(const Key('help-no-match')), findsNothing);
      for (final id in ['streaks', 'pause', 'reminders', 'backup']) {
        await route(t, '/help/$id');
        expect(find.byKey(Key('help-article-$id')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'streak pause reminder backup entry points open contextual help',
    (t) async {
      await learningBoot(t, state: f.seeded());
      await route(t, '/habit/h');
      await tap(t, 'streak-help');
      expect(find.byKey(const Key('help-article-streaks')), findsOneWidget);
      await route(t, '/settings');
      for (final (entry, topic) in [
        ('pause-help', 'pause'),
        ('reminder-help', 'reminders'),
        ('backup-help', 'backup'),
      ]) {
        await tap(t, entry);
        expect(find.byKey(Key('help-article-$topic')), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
      }
      await tap(t, 'pause-add');
      await tap(t, 'context-help-pause');
      expect(find.byKey(const Key('help-article-pause')), findsOneWidget);
    },
  );

  testWidgets(
    'Settings choices and switches persist, show values; editor uses new defaults; reset keeps data',
    (t) async {
      final (c, store, _) = await learningBoot(t, state: f.seeded());
      final habits = c.state!.habits.map((h) => h.toJson()).toList();
      await route(t, '/settings');
      for (final (id, value) in [
        ('settings-density', 'compact'),
        ('settings-default-schedule', 'weekdays'),
        ('settings-default-goal', '8000'),
        ('settings-theme', 'dark'),
      ]) {
        await tap(t, id);
        await tap(t, '$id-$value');
      }
      for (final id in [
        'set-reduced-motion',
        'settings-routine-timer',
        'settings-routine-haptics',
        'settings-routine-confirm',
      ])
        await tap(t, id);
      await c.load();
      await t.pumpAndSettle();
      expect(c.state!.settings, containsPair('density', 'compact'));
      expect(c.state!.settings, containsPair('defaultGoal', 8000));
      t.state<ScrollableState>(find.byType(Scrollable).last).position.jumpTo(0);
      await t.pumpAndSettle();
      expect(find.text('Compact'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Pro Lifetime'), findsNothing);
      expect(find.text('Pro'), findsNothing);
      await route(t, '/habit/new');
      await t.enterText(
        find.byKey(const Key('field-title')),
        'Default counted habit',
      );
      await tap(t, 'field-type-count');
      await tap(t, 'editor-save');
      final newHabit = c.state!.habits.last;
      expect(newHabit.schedules.single.target, 8000);
      expect(newHabit.schedules.single.kind, 'weekdays');
      await route(t, '/settings');
      await tap(t, 'settings-reset');
      await t.tap(find.widgetWithText(FilledButton, 'Reset preferences'));
      await t.pumpAndSettle();
      expect(
        c.state!.habits.take(habits.length).map((h) => h.toJson()).toList(),
        habits,
      );
      expect(c.state!.routines, hasLength(1));
      expect(c.state!.settings['defaultGoal'], isNull);
      expect(c.state!.settings['onboarded'], true);
      expect(store.writes, greaterThan(5));
    },
  );

  testWidgets(
    'Settings failed persistence keeps value and library; retry succeeds',
    (t) async {
      final (c, store, _) = await learningBoot(t, state: f.seeded());
      await route(t, '/settings');
      store.fail = true;
      await tap(t, 'settings-density');
      await tap(t, 'settings-density-compact');
      expect(c.state!.settings['density'], isNull);
      expect(find.textContaining('Not saved:'), findsOneWidget);
      store.fail = false;
      await tap(t, 'settings-density');
      await tap(t, 'settings-density-compact');
      expect(c.state!.settings['density'], 'compact');
    },
  );

  testWidgets(
    'no permission on launch help replay; explanation precedes explicit opt-in; denial and test errors handled',
    (t) async {
      final (c, _, r) = await learningBoot(t, state: f.seeded());
      expect(r.requests, 0);
      await route(t, '/settings');
      expect(r.requests, 0);
      await tap(t, 'set-notifications');
      expect(r.requests, 0);
      expect(find.text('Allow reminders?'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Continue'));
      await t.pumpAndSettle();
      expect(r.requests, 1);
      expect(c.state!.settings['notifications'], false);
      r.allowed = true;
      await tap(t, 'set-notifications');
      await t.tap(find.widgetWithText(FilledButton, 'Continue'));
      await t.pumpAndSettle();
      expect(c.state!.settings['notifications'], true);
      await tap(t, 'notification-test');
      expect(r.tests, 1);
      r.fails = true;
      await tap(t, 'notification-test');
      expect(find.textContaining('Not done:'), findsOneWidget);
      await tap(t, 'settings-private-notifications');
      expect(c.state!.settings['privateNotifications'], false);
    },
  );

  testWidgets('English history uses time for a goal of one', (t) async {
    final s = f.seeded();
    final h = s.habits.first.copy({'type': 'count'});
    final (c, _, _) = await learningBoot(
      t,
      state: s.copy({
        'habits': [h.toJson()],
      }),
    );
    await route(t, '/habit/h');
    expect(find.textContaining('1 time'), findsWidgets);
    expect(find.textContaining('1 times'), findsNothing);
    expect(c.state!.habits.single.type, 'count');
  });

  for (final value in [1000, 2000])
    testWidgets('runner linked count $value uses correct singular/plural', (
      t,
    ) async {
      final s = f.seeded();
      final h = s.habits.single.copy({'type': 'count'});
      final routine = Routine(
        id: 'count-r',
        title: 'Water break',
        steps: [
          RoutineStep(
            id: 'step',
            title: 'Water',
            seconds: 0,
            minimum: 0,
            habit: h.id,
            linkedValue: value,
          ),
        ],
      );
      final run = startSession(
        routine,
        '2024-01-08',
        DateTime.utc(2024, 1, 8, 12),
      );
      await learningBoot(
        t,
        state: s.copy({
          'habits': [h.toJson()],
          'routines': [routine.toJson()],
          'sessions': [run.toJson()],
        }),
      );
      await route(t, '/run/${run.id}');
      expect(
        find.textContaining(value == 1000 ? '+1 time.' : '+2 times.'),
        findsOneWidget,
      );
      expect(find.textContaining('+1 times'), findsNothing);
    });

  testWidgets(
    'routine preferences control actual timer haptic and exit behavior',
    (t) async {
      final calls = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate')
            calls.add('${call.arguments}');
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final s = f.seeded();
      final (c, _, _) = await learningBoot(
        t,
        state: s.copy({
          'settings': {
            ...s.settings,
            'routineAutoTimer': false,
            'routineHaptics': true,
            'confirmRoutineExit': false,
          },
        }),
      );
      await route(t, '/routines');
      await tap(t, 'start-r');
      expect(c.state!.sessions.single.running, false);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(c.state!.sessions.single.running, false);
      expect(calls, contains('HapticFeedbackType.lightImpact'));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Pause and exit?'), findsNothing);
      expect(c.state!.sessions.single.status, 'active');
    },
  );

  test(
    'private reminder and paused-run notifications hide habit and routine names',
    () async {
      final base = f.seeded();
      final state = base.copy({
        'settings': {
          ...base.settings,
          'notifications': true,
          'runNotice': true,
          'zone': 'UTC',
          'reminders': [
            Reminder(
              id: 'reminder',
              type: 'habit',
              target: 'h',
              time: '13:00',
            ).toJson(),
          ],
        },
      });
      final due = dueReminders(state, DateTime.utc(2024, 1, 8, 12)).first;
      expect(reminderBody(state, due), 'Your practice is due');
      expect(
        reminderBody(
          state.copy({
            'settings': {...state.settings, 'privateNotifications': false},
          }),
          due,
        ),
        base.habits.single.title,
      );
      final port = FakeNotices();
      final notices = HabitRunNotices(port: port);
      await notices.show(
        state,
        const RunNotice(
          'session',
          'Private routine title',
          'Paused. Tap to continue.',
        ),
        DateTime.utc(2024, 1, 8, 12),
      );
      expect(port.shown.single.title, 'Handy Habit');
    },
  );

  for (final owned in [false, true])
    testWidgets(
      'free Settings has no Pro badge or purchase row for tier $owned; reset preserves records and ownership',
      (t) async {
        final tier = TestTier(owned);
        addTearDown(tier.dispose);
        final base = f.seeded();
        final event = HabitEvent(
          id: 'event',
          habit: 'h',
          day: '2024-01-07',
          value: 1000,
          updated: '2024-01-07T12:00:00.000Z',
        );
        final state = base.copy({
          'events': [event.toJson()],
          'settings': {
            ...base.settings,
            'theme': 'dark',
            'reminders': [
              Reminder(
                id: 'reminder',
                type: 'habit',
                target: 'h',
                time: '13:00',
              ).toJson(),
            ],
          },
        });
        final (c, _, _) = await learningBoot(t, state: state, tier: tier);
        await route(t, '/settings');
        expect(find.text('Pro'), findsNothing);
        expect(find.text('Pro Lifetime'), findsNothing);
        await tap(t, 'settings-reset');
        await tap(t, 'confirm-action');
        expect(c.state!.events.single.toJson(), event.toJson());
        expect(c.state!.settings['reminders'], state.settings['reminders']);
        expect(tier.pro, owned);
      },
    );

  testWidgets(
    'Enter advances every practice step and Back on first beat exits like Skip',
    (t) async {
      final (c, _, _) = await learningBoot(t);
      await practiceStart(t);
      for (var i = 1; i <= 6; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(find.byKey(Key('practice-instruction-$i')), findsOneWidget);
      }
      for (var i = 0; i < 8; i++) await tap(t, 'welcome-back');
      expect(find.text('Good intentions drift away.'), findsOneWidget);
      await tap(t, 'welcome-back');
      expect(c.state!.settings['onboarded'], true);
    },
  );
}
