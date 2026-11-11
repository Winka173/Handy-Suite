import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_habit/today/beads.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/ui/row_menu.dart';
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;
import 'ui_test.dart' as f;

HabitState mixed() {
  final base = f.seeded();
  final n = Habit(
    id: 'negative',
    title: 'Sugary drinks',
    type: 'count',
    direction: 'reduce',
    created: '2024-01-01',
    schedules: [Schedule(id: 's', from: '2024-01-01')],
    negativeGoals: [NegativeGoal(id: 'limit', from: '2024-01-01', limit: 3000)],
  );
  return base.copy({
    'habits': [...base.habits.map((h) => h.toJson()), n.toJson()],
  });
}

void main() {
  testWidgets(
    'duplicate reduction starts today with a new goal and no observations',
    (t) async {
      final c = await host.boot(
        t,
        state: setManualTotal(
          mixed(),
          'negative',
          '2024-01-07',
          1000,
          today: '2024-01-08',
        ),
      );
      await host.go(t, '/habit/negative');
      await t.tap(find.byType(HabitMenuButton).last);
      await t.pumpAndSettle();
      await tap(t, 'habit-duplicate');
      final copied = c.state!.habits.last;
      expect(copied.id, isNot('negative'));
      expect(copied.created, '2024-01-08');
      expect(copied.negativeGoals.single.from, copied.created);
      expect(copied.negativeGoals.single.id, isNot('limit'));
      expect(HabitIndex.of(c.state!).known(copied.id, copied.created), isFalse);
    },
  );
  testWidgets(
    'Progress activity includes explicit None but never implies success for silence',
    (t) async {
      final state = setManualTotal(
        mixed(),
        'negative',
        '2024-01-08',
        0,
        today: '2024-01-08',
      );
      await host.boot(t, state: state);
      await host.go(t, '/progress');
      expect(find.byKey(const Key('progress-calendar')), findsOneWidget);
      await tap(t, 'progress-method');
      expect(
        find.textContaining('Pauses, skips, unknown days, conflicts'),
        findsOneWidget,
      );
      await tap(t, 'progress-method-done');
      expect(
        find.textContaining('No finished days to count yet'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Basic intention first, creates a weekly negative ceiling without advanced',
    (t) async {
      final c = await host.boot(t);
      await host.go(t, '/habit/new');
      expect(find.text('Build a habit'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Build a habit')).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('field-title'))).dy),
      );
      await tap(t, 'field-direction-reduce');
      await t.enterText(
        find.byKey(const Key('field-title')),
        'Less social media',
      );
      await tap(t, 'field-ceilingMode-limit');
      await t.enterText(find.byKey(const Key('field-ceiling')), '3');
      await tap(t, 'field-window-week');
      expect(find.byKey(const Key('field-type-binary')), findsNothing);
      await tap(t, 'editor-save');
      final h = c.state!.habits.last;
      expect(h.isNegative, isTrue);
      expect(h.negativeGoals.single.limit, 3000);
      expect(h.negativeGoals.single.window, 'week');
    },
  );
  testWidgets('one tap records incidents past limit with causal Undo', (
    t,
  ) async {
    final c = await host.boot(t, state: mixed());
    for (var i = 0; i < 4; i++) await tap(t, 'bead-negative');
    expect(HabitIndex.of(c.state!).value('negative', '2024-01-08'), 4000);
    expect(
      find.textContaining("Today: 4 of 3 — tomorrow is a fresh start"),
      findsOneWidget,
    );
    await tap(t, 'snack-undo');
    expect(HabitIndex.of(c.state!).value('negative', '2024-01-08'), 3000);
    expect(c.state!.events.where((e) => e.habit == 'h'), isEmpty);
  });
  testWidgets(
    'unknown is hollow, explicit None today is known and Undo returns unknown',
    (t) async {
      final c = await host.boot(t, state: mixed());
      expect(find.textContaining('Nothing recorded yet'), findsOneWidget);
      final negative = c.state!.habits.last;
      expect(
        habitStatus(
          negative,
          '2024-01-08',
          '2024-01-08',
          HabitIndex.of(c.state!),
        ),
        'unknown',
      );
      expect(
        find.byWidgetPredicate((w) => w is Bead && w.status == 'unknown'),
        findsWidgets,
      );
      await tap(t, 'none-negative');
      expect(HabitIndex.of(c.state!).known('negative', '2024-01-08'), isTrue);
      expect(HabitIndex.of(c.state!).value('negative', '2024-01-08'), 0);
      expect(find.textContaining('0 of 3 allowed today'), findsOneWidget);
      expect(
        metrics(negative, '2024-01-08', 1, HabitIndex.of(c.state!)).completed,
        0,
      );
      expect(find.byKey(const Key('none-negative')), findsNothing);
      await tap(t, 'snack-undo');
      expect(HabitIndex.of(c.state!).known('negative', '2024-01-08'), isFalse);
    },
  );
  testWidgets('no negative routine link and help teaches explicit zero', (
    t,
  ) async {
    await host.boot(t, state: mixed());
    await host.go(t, '/routine/r/edit');
    await tap(t, 'step-add');
    await tap(t, 'field-habit-h');
    expect(find.byKey(const Key('field-habit-h')), findsOneWidget);
    expect(find.byKey(const Key('field-habit-negative')), findsNothing);
    await host.go(t, '/help/negative');
    await t.scrollUntilVisible(
      find.textContaining('no record means unknown, never success'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.textContaining('no record means unknown, never success'),
      findsOneWidget,
    );
  });
  testWidgets('history edits total note, None and unknown', (t) async {
    final c = await host.boot(t, state: mixed());
    await host.go(t, '/habit/negative');
    await tap(t, 'day-2024-01-07');
    await tap(t, 'field-state-done');
    await t.enterText(find.byKey(const Key('field-total')), '2');
    await t.enterText(find.byKey(const Key('field-note')), 'At lunch');
    await tap(t, 'editor-save');
    expect(c.state!.events.single.note, 'At lunch');
    expect(HabitIndex.of(c.state!).value('negative', '2024-01-07'), 2000);
    await tap(t, 'day-2024-01-07');
    await tap(t, 'field-state-none');
    await tap(t, 'editor-save');
    expect(HabitIndex.of(c.state!).known('negative', '2024-01-07'), isTrue);
    expect(HabitIndex.of(c.state!).value('negative', '2024-01-07'), 0);
    await tap(t, 'day-2024-01-07');
    await tap(t, 'field-state-unknown');
    await tap(t, 'editor-save');
    expect(HabitIndex.of(c.state!).known('negative', '2024-01-07'), isFalse);
  });
  testWidgets('None at all creates an explicit zero limit', (t) async {
    final c = await host.boot(t);
    await host.go(t, '/habit/new');
    await tap(t, 'field-direction-reduce');
    await t.enterText(find.byKey(const Key('field-title')), 'No smoking');
    await tap(t, 'editor-save');
    expect(c.state!.habits.last.negativeGoals.single.limit, 0);
    expect(c.state!.habits.last.type, 'count');
  });
  testWidgets('weekly review excludes unknown from daily denominator', (
    t,
  ) async {
    var state = mixed();
    for (var i = 0; i < 6; i++)
      state = setManualTotal(
        state,
        'negative',
        addDays('2024-01-01', i),
        0,
        today: '2024-01-08',
      );
    await host.boot(t, state: state);
    await host.go(t, '/progress/week?from=2024-01-01');
    expect(
      find.textContaining('Kept 6 of 6 days · 1 day left unknown.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('week-review-smaller-negative')), findsNothing);
  });
}
