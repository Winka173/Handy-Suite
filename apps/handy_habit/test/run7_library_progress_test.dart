import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;

void main() {
  testWidgets(
    'gallery searches EN VI without accents, categories and no match reset',
    (t) async {
      final c = await host.boot(t);
      await host.go(t, '/templates');
      final before = jsonEncode(c.state!.toJson());
      await t.enterText(find.byKey(const Key('template-search')), 'nuoc ngot');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('preset-sugary-drinks')), findsOneWidget);
      expect(find.byKey(const Key('preset-read')), findsNothing);
      await t.enterText(find.byKey(const Key('template-search')), 'zzzzzz');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('templates-reset')), findsOneWidget);
      await tap(t, 'templates-reset');
      await t.ensureVisible(find.byKey(const Key('collection-reading')));
      await tap(t, 'collection-reading');
      expect(find.byKey(const Key('preset-read')), findsOneWidget);
      expect(find.byKey(const Key('preset-walk')), findsNothing);
      expect(jsonEncode(c.state!.toJson()), before);
    },
  );
  testWidgets(
    'preview and cancel write nothing; customise reduction and rapid save once',
    (t) async {
      final c = await host.boot(t);
      final count = c.state!.habits.length;
      await host.go(t, '/templates?collection=reduce');
      await tap(t, 'preset-sugary-drinks');
      expect(find.byKey(const Key('template-preview-title')), findsOneWidget);
      expect(c.state!.habits.length, count);
      await tap(t, 'template-customise');
      expect(
        t
            .widget<TextField>(find.byKey(const Key('field-title')))
            .controller!
            .text,
        'Fewer sugary drinks',
      );
      host.nav(t).pop();
      await t.pumpAndSettle();
      expect(c.state!.habits.length, count);
      await tap(t, 'template-customise');
      await t.enterText(find.byKey(const Key('field-title')), 'Weekend drinks');
      await t.ensureVisible(find.byKey(const Key('editor-save')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('editor-save')));
      await t.tap(find.byKey(const Key('editor-save')));
      await t.pumpAndSettle();
      expect(c.state!.habits.length, count + 1);
      final h = c.state!.habits.last;
      expect(h.title, 'Weekend drinks');
      expect(h.direction, 'reduce');
      expect(h.negativeGoals.single.window, 'week');
      expect(h.negativeGoals.single.limit, 3000);
      expect(c.state!.settings['reminders'] ?? [], isEmpty);
      expect(find.byKey(const Key('template-search')), findsNothing);
    },
  );
  testWidgets(
    'routine gallery previews steps then creates an editable independent draft',
    (t) async {
      final c = await host.boot(t);
      final before = c.state!.routines.length;
      await host.go(t, '/templates?kind=routine&collection=mindfulness');
      await tap(t, 'preset-recovery');
      expect(find.text('Rest quietly'), findsOneWidget);
      expect(c.state!.routines.length, before);
      await tap(t, 'template-customise');
      await t.enterText(find.byKey(const Key('field-title')), 'My recovery');
      await tap(t, 'editor-save');
      expect(c.state!.routines.length, before + 1);
      expect(c.state!.routines.last.title, 'My recovery');
      expect(c.state!.routines.last.steps.length, 3);
    },
  );
  testWidgets(
    'Progress ranges, month calendar, yearly per-habit heatmap and Show all',
    (t) async {
      const start = '2024-01-01';
      final habits = [
        for (var i = 0; i < 9; i++)
          Habit(
            id: 'h$i',
            title: 'Habit $i',
            created: start,
            schedules: [Schedule(id: 's$i', from: start)],
          ),
      ];
      await host.boot(
        t,
        state: HabitState(habits: habits, settings: {'onboarded': true}),
      );
      await host.go(t, '/progress');
      expect(find.byKey(const Key('progress-calendar')), findsOneWidget);
      expect(find.byKey(const Key('insight-h5')), findsNothing);
      await tap(t, 'progress-habits-more');
      expect(find.byKey(const Key('insight-h8')), findsOneWidget);
      await tap(t, 'range-week');
      expect(find.byKey(const Key('calendar-2024-01-08')), findsOneWidget);
      expect(find.byKey(const Key('calendar-2024-01-15')), findsNothing);
      await tap(t, 'range-year');
      expect(find.byKey(const Key('year-heatmap')), findsOneWidget);
      await tap(t, 'progress-habit-filter');
      await t.tap(find.text('Habit 2').last);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await tap(t, 'progress-prev');
      expect(find.textContaining('2023'), findsWidgets);
    },
  );
  testWidgets('Progress empty is honest and offers creation without Pro', (
    t,
  ) async {
    await host.boot(t, state: HabitState(settings: {'onboarded': true}));
    await host.go(t, '/progress');
    expect(find.text('Nothing to count yet in this range'), findsOneWidget);
    expect(find.byKey(const Key('progress-create')), findsOneWidget);
    await tap(t, 'range-year');
    expect(find.byKey(const Key('year-heatmap')), findsOneWidget);
    expect(find.textContaining('0 days with a kept goal'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'routine completion counts unfinished runs and expands seven routines',
    (t) async {
      final routines = [
        for (var i = 0; i < 7; i++)
          Routine(
            id: 'r$i',
            title: 'Routine $i',
            steps: [RoutineStep(id: 'step$i', title: 'Read', seconds: 60)],
          ),
      ];
      final sessions = [
        for (var i = 0; i < 7; i++)
          RoutineSession(
            id: 'session$i',
            routine: 'r$i',
            title: 'Routine $i',
            started: '2024-01-07T12:00:00Z',
            day: '2024-01-07',
            steps: [
              StepRun(
                plan: routines[i].steps.single,
                status: i == 0 ? 'completed' : 'pending',
              ),
            ],
            status: i == 0 ? 'finished' : 'aborted',
            ended: '2024-01-07T12:01:00Z',
          ),
      ];
      await host.boot(
        t,
        state: HabitState(
          routines: routines,
          sessions: sessions,
          settings: {'onboarded': true},
        ),
      );
      await host.go(t, '/progress');
      await tap(t, 'progress-routines-more');
      expect(find.text('Routine 6'), findsOneWidget);
      expect(find.text('1 finished of 7 started.'), findsOneWidget);
    },
  );
  testWidgets('calendar date opens evidence and the existing backfill editor', (
    t,
  ) async {
    final c = await host.boot(t);
    await host.go(t, '/progress');
    await tap(t, 'calendar-2024-01-07');
    await t.tap(find.text('Read a few pages').last);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('editor-save')), findsOneWidget);
    expect(c.state!.events, isEmpty);
  });
}
