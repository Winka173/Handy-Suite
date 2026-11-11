import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'pro_test.dart' as p;
import 'run14_test.dart' as f;
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;
import 'run15_fixtures.dart';
import 'ui_test.dart' show MemoryStore;

class FailedRuleStore extends MemoryStore {
  @override
  Future<void> commit(HabitState next, {required int expectedRevision}) async {
    throw StateError('Disk unavailable');
  }
}

void main() {
  testWidgets('foreground automatic save failure is visible and preserves data', (
    t,
  ) async {
    final base = convenienceSeed();
    final initial = base.copy({
      'settings': {
        ...base.settings,
        'convenienceRules': [
          ConvenienceRule(
            id: 'holiday-now',
            name: 'Holiday',
            kind: 'holiday',
            source: 'Movement',
            from: '2024-01-08',
            until: '2024-01-10',
          ).toJson(),
        ],
      },
    });
    final (c, _, _) = await p.bootPro(
      t,
      state: initial,
      memoryStore: FailedRuleStore(),
      open: false,
      fake: p.FakeHabitStore()
        ..value = p.FakeHabitStore.snapshot('ready', pro: true),
    );
    expect(c.state!.pauses, isEmpty);
    expect(
      find.text(
        'Automatic change not saved. Nothing changed. Review Local rules in Settings.',
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
  for (final action in ['archive', 'collection', 'pause', 'reminder']) {
    testWidgets('Pro $action batch previews exact selection and has one Undo', (
      t,
    ) async {
      var initial = convenienceSeed();
      initial = initial.copy({
        'settings': {
          ...initial.settings,
          'reminders': [
            ...objects(initial.settings['reminders']),
            Reminder(
              id: 'water-reminder',
              target: 'water',
              type: 'habit',
              time: '07:00',
              enabled: false,
            ).toJson(),
          ],
        },
      });
      final (c, _, _) = await f.bootRun14(t, state: initial);
      final before = c.state!;
      await host.go(t, '/habits/batch');
      await tap(t, 'batch-water');
      await tap(t, 'batch-walk');
      await tap(t, 'batch-preview');
      await tap(t, 'field-action-$action');
      if (action == 'collection')
        await t.enterText(find.byKey(const Key('field-collection')), 'Home');
      await tap(t, 'editor-save');
      expect(
        c.state!.habits.map((h) => h.toJson()),
        before.habits.map((h) => h.toJson()),
      );
      await tap(t, 'batch-apply');
      if (action == 'archive')
        expect(
          c.state!.habits.where((h) => h.archived).map((h) => h.id).toSet(),
          {'water', 'walk'},
        );
      if (action == 'collection')
        expect(
          c.state!.habits
              .where((h) => h.category == 'Home')
              .map((h) => h.id)
              .toSet(),
          {'water', 'walk'},
        );
      if (action == 'pause')
        expect(c.state!.pauses.last.habits.toSet(), {'water', 'walk'});
      if (action == 'reminder')
        expect(objects(c.state!.settings['reminders']).last['enabled'], false);
      await c.undo();
      await t.pumpAndSettle();
      expect(
        c.state!.habits.map((h) => h.toJson()),
        before.habits.map((h) => h.toJson()),
      );
      expect(
        c.state!.pauses.map((h) => h.toJson()),
        before.pauses.map((h) => h.toJson()),
      );
      expect(c.state!.settings['reminders'], before.settings['reminders']);
    });
  }
  testWidgets('saved views persist and applying one only changes the view', (
    t,
  ) async {
    final (c, _, _) = await f.bootRun14(t, state: convenienceSeed());
    await host.go(t, '/habits');
    await t.enterText(find.byKey(const Key('habit-search')), 'Water');
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    await tap(t, 'save-filter-habits');
    await t.enterText(find.byKey(const Key('field-name')), 'Water view');
    await tap(t, 'editor-save');
    await t.enterText(find.byKey(const Key('habit-search')), '');
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    final revision = c.state!.revision;
    await t.tap(find.text('Water view'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(find.byKey(const Key('habit-search')))
          .controller!
          .text,
      'Water',
    );
    expect(c.state!.revision, revision);
    await host.go(t, '/progress');
    await t.tap(find.text('January review'));
    await t.pumpAndSettle();
    expect(c.state!.revision, revision);
  });
  testWidgets('stale batch preview refuses every change', (t) async {
    final (c, _, _) = await f.bootRun14(t, state: convenienceSeed());
    await host.go(t, '/habits/batch');
    await tap(t, 'batch-water');
    await tap(t, 'batch-preview');
    await tap(t, 'editor-save');
    await c.change(
      (s) => s.copy({
        'settings': {...s.settings, 'density': 'compact'},
      }),
    );
    await t.pumpAndSettle();
    await tap(t, 'batch-apply');
    expect(c.state!.habits.every((h) => !h.archived), isTrue);
    expect(
      find.text('Nothing changed. Close and preview again.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'runner completion evaluates two rules; named Undo keeps the other effect and finished session',
    (t) async {
      final base = convenienceSeed();
      final routine = Routine(
        id: 'small',
        title: 'Morning',
        steps: [RoutineStep(id: 'breathe', title: 'Breathe')],
      );
      final session = startSession(routine, '2024-01-08', host.now);
      final initial = base.copy({
        'routines': [routine.toJson()],
        'sessions': [session.toJson()],
        'settings': {
          ...base.settings,
          'reminders': [],
          'convenienceRules': [
            ConvenienceRule(
              id: 'other-rule',
              name: 'Another water',
              kind: 'routine',
              source: 'small',
              target: 'water',
            ).toJson(),
            ConvenienceRule(
              id: 'new-rule',
              name: 'Morning water',
              kind: 'routine',
              source: 'small',
              target: 'water',
            ).toJson(),
          ],
        },
      });
      final (c, _, _) = await f.bootRun14(t, state: initial);
      await host.go(t, '/run/${session.id}');
      await tap(t, 'routine-complete-step');
      await tap(t, 'runner-finish');
      expect(c.state!.events.where((e) => e.habit == 'water').length, 3);
      final op = convenienceHistory(c.state!).last.$1;
      await host.go(t, '/settings/rules');
      await tap(t, 'rule-undo-${op.id}');
      expect(c.state!.events.where((e) => e.habit == 'water').length, 2);
      expect(c.state!.sessions.single.status, 'finished');
    },
  );
  testWidgets('saved Habits and Progress views are Pro gated', (t) async {
    await p.bootPro(t, open: false, state: f.run14Seed());
    await host.go(t, '/habits');
    await tap(t, 'habit-archived');
    await tap(t, 'save-filter-habits');
    expect(host.route(t), '/pro?feature=convenience');
  });
  testWidgets('check-in keeps the app wrapper and appearance notifier stable', (
    t,
  ) async {
    final (c, _, _) = await p.bootPro(t, open: false, state: f.run14Seed());
    final app = t.widget(find.byType(HandyApp));
    var appearances = 0;
    c.appearance.addListener(() => appearances++);
    await c.change(
      (s) => record(
        s,
        HabitEvent(id: 'run15', habit: 'walk', day: '2024-01-08', value: 1000),
        today: '2024-01-08',
      ),
    );
    await t.pumpAndSettle();
    expect(identical(t.widget(find.byType(HandyApp)), app), isTrue);
    expect(appearances, 0);
  });
  testWidgets('non-Pro batch cannot mutate; rules remain readable', (t) async {
    final (c, _, _) = await p.bootPro(t, open: false, state: f.run14Seed());
    await host.go(t, '/habits/batch');
    await tap(t, 'batch-walk');
    await tap(t, 'batch-preview');
    expect(host.route(t), '/pro?feature=convenience');
    expect(c.state!.habits.every((h) => !h.archived), isTrue);
    await host.go(t, '/settings/rules');
    expect(find.byKey(const Key('rule-add')), findsOneWidget);
  });
}
