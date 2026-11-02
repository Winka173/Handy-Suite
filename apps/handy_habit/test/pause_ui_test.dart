import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/run_notice.dart';
import 'package:handy_habit/runner.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart' show MemoryStore, seeded, start, tapKey;

/// The system notifications, as a test sees them.
class FakeNotices implements RunNoticePort {
  bool granted = true;
  final shown = <RunNotice>[];
  int cancels = 0;
  String? launch;
  void Function(String)? tap;
  @override
  bool get supported => true;
  @override
  Future<bool> allowed() async => granted;
  @override
  Future<void> show(RunNotice notice) async => shown.add(notice);
  @override
  Future<void> cancel() async => cancels++;
  @override
  Future<String?> listen(void Function(String) onOpen) async {
    tap = onOpen;
    return launch;
  }
}

Future<(HabitController, RoutineSession)> runner(
  WidgetTester tester,
  FakeNotices port, {
  Map<String, dynamic> settings = const {'notifications': true},
  DateTime? now,
}) async {
  final store = MemoryStore();
  final base = seeded();
  final session = startSession(
    base.routines.single,
    '2024-01-08',
    DateTime.utc(2024, 1, 8, 12),
  );
  store.value = base.copy({
    'sessions': [session.toJson()],
    'settings': {...base.settings, 'zone': 'UTC', ...settings},
  });
  final c = HabitController(open: () async => store);
  await c.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHandyTheme(habitAccent, Brightness.light),
      home: RoutineRunner(
        controller: c,
        sessionId: session.id,
        clock: () => now ?? DateTime.utc(2024, 1, 8, 12),
        fresh: true,
        notices: HabitRunNotices(port: port),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (c, session);
}

void main() {
  testWidgets('a pause for everything: Today rests, End early brings it back', (
    tester,
  ) async {
    final c = await start(tester, state: seeded());
    await tapKey(tester, 'habit-add');
    await tapKey(tester, 'add-pause');
    // The end is picked on the calendar, never typed.
    await tapKey(tester, 'field-until');
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-reason')), 'Đà Lạt');
    await tapKey(tester, 'editor-save');
    final p = c.state!.pauses.single;
    expect((p.from, p.until, p.everything), ('2024-01-08', '2024-01-10', true));
    expect(find.textContaining('Paused until Wednesday'), findsOneWidget);
    expect(find.textContaining('nothing to do'), findsOneWidget);
    expect(find.textContaining('Đà Lạt'), findsOneWidget);
    expect(
      habitStatus(
        c.state!.habits.single,
        '2024-01-08',
        '2024-01-08',
        HabitIndex.of(c.state!),
      ),
      'paused',
    );
    // Today's bead still marks the day; done anyway counts.
    expect(find.bySemanticsLabel(RegExp('paused today')), findsOneWidget);
    await tapKey(tester, 'pause-end-today');
    // It began today, so ending it early takes it away.
    expect(c.state!.pauses, isEmpty);
    expect(find.textContaining('Paused until'), findsNothing);
    await tapKey(tester, 'snack-undo');
    expect(c.state!.pauses.single.until, '2024-01-10');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('a pause for one habit, from its menu, shows on its row', (
    tester,
  ) async {
    final base = seeded();
    final c = await start(
      tester,
      state: base.copy({
        'habits': [
          ...base.habits.map((h) => h.toJson()),
          Habit(
            id: 'k',
            title: 'Stretch',
            created: '2024-01-01',
            schedules: [Schedule(id: 'vk', from: '2024-01-01')],
          ).toJson(),
        ],
      }),
    );
    await tapKey(tester, 'habit-h');
    await tapKey(tester, 'more-menu');
    await tapKey(tester, 'habit-pause');
    await tapKey(tester, 'editor-save');
    final p = c.state!.pauses.single;
    expect(p.habits, ['h']);
    expect(find.text('Pauses'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('Paused until'), findsOneWidget);
    // The other habit is still to do; the greeting is not resting.
    expect(find.textContaining('1 left to do'), findsOneWidget);
    // Deleting the habit leaves no pause naming it. (The page now has a
    // menu on its pause too; the habit's own is in the app bar.)
    await tapKey(tester, 'habit-h');
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const Key('more-menu')),
      ),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'habit-delete');
    await tapKey(tester, 'confirm-action');
    expect(c.state!.pauses, isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('pauses are listed in Settings and can be deleted', (
    tester,
  ) async {
    final c = await start(
      tester,
      state: seeded().copy({
        'pauses': [
          Pause(id: 'p', from: '2024-01-20', until: '2024-01-25').toJson(),
        ],
      }),
    );
    await tapKey(tester, 'open-settings');
    await tester.pumpAndSettle();
    await tapKey(tester, 'pause-p');
    expect(find.byKey(const Key('editor-save')), findsOneWidget);
    await tapKey(tester, 'sheet-cancel');
    final menu = find.descendant(
      of: find.byKey(const Key('pause-p')),
      matching: find.byKey(const Key('more-menu')),
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tapKey(tester, 'pause-delete-p');
    expect(c.state!.pauses, isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    'leaving a run shows it paused, with the time left, then clears',
    (tester) async {
      final port = FakeNotices();
      final (c, session) = await runner(tester, port);
      // Step one is untimed; finish it so the timed step is current.
      await tester.tap(find.byKey(const Key('routine-complete-step')));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(c.state!.sessions.single.running, isFalse);
      expect(port.shown, hasLength(1));
      final n = port.shown.single;
      expect(n.session, session.id);
      expect(n.title, 'Evening reading · Step 2 of 2');
      expect(n.body, 'Paused · 1:00 left. Tap to continue.');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(port.cancels, 1);
      // Still paused after coming back: the timer never ran in between.
      expect(c.state!.sessions.single.running, isFalse);
      expect(c.state!.sessions.single.steps[1].elapsed, 0);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('no notice when it is off, not allowed, or in quiet hours', (
    tester,
  ) async {
    for (final (settings, granted, now) in [
      (const {'notifications': false}, true, null),
      (const {'notifications': true, 'runNotice': false}, true, null),
      (const {'notifications': true}, false, null),
      (
        const {
          'notifications': true,
          'quietStart': '22:00',
          'quietEnd': '07:00',
        },
        true,
        DateTime.utc(2024, 1, 8, 23),
      ),
    ]) {
      final port = FakeNotices()..granted = granted;
      final (c, _) = await runner(tester, port, settings: settings, now: now);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(port.shown, isEmpty, reason: '$settings $granted');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(port.cancels, 0);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }
  });

  testWidgets('stopping the run clears its notice', (tester) async {
    final port = FakeNotices();
    final (c, _) = await runner(
      tester,
      port,
      settings: const {'runNotice': true},
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(port.shown.single.body, 'Paused. Tap to continue.');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tapKey(tester, 'more-menu');
    await tapKey(tester, 'runner-abort');
    await tapKey(tester, 'confirm-action');
    expect(c.state!.sessions.single.status, 'aborted');
    expect(port.cancels, greaterThanOrEqualTo(2));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('the notice that opened the app goes back to its run', (
    tester,
  ) async {
    final store = MemoryStore();
    final base = seeded();
    final session = startSession(
      base.routines.single,
      '2024-01-08',
      DateTime.utc(2024, 1, 8, 12),
    ).copy({'anchor': null});
    store.value = base.copy({
      'sessions': [session.toJson()],
    });
    final c = HabitController(open: () async => store);
    final port = FakeNotices()..launch = session.id;
    await tester.pumpWidget(
      HabitApp(
        controller: c,
        clock: () => DateTime.utc(2024, 1, 8, 12),
        notices: HabitRunNotices(port: port),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine-complete-step')), findsOneWidget);
    // A stale notice from a closed app is taken away at start.
    expect(port.cancels, 1);
    // A second tap while the run is on screen opens nothing new.
    port.tap!(session.id);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine-complete-step')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
