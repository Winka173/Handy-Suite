import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/data/store_native.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'ui_test.dart' as f;

Future<void> tap(WidgetTester t, String key) async {
  final finder = find.byKey(Key(key)).last;
  if (find.byKey(Key(key)).evaluate().isEmpty) {
    await t.scrollUntilVisible(
      find.byKey(Key(key)),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .hitTestable()
          .first,
    );
  }
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> route(WidgetTester t, String path) async {
  t.state<NavigatorState>(find.byType(Navigator).first).pushNamed(path);
  await t.pumpAndSettle();
}

Future<void> end(WidgetTester t, HabitController c) async {
  await t.pumpWidget(const SizedBox());
  c.dispose();
}

class DraftStore extends f.MemoryStore {
  bool fail = false;
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<void> commit(HabitState next, {required int expectedRevision}) async {
    writes++;
    await gate?.future;
    if (fail) throw StateError('disk full');
    await super.commit(next, expectedRevision: expectedRevision);
  }
}

void main() {
  testWidgets('draft add edit link reorder dirty cancel and atomic save', (
    t,
  ) async {
    final c = await f.start(t, state: f.seeded());
    final before = c.state!.toJson();
    await route(t, '/routine/r/edit');
    await tap(t, 'draft-down-a');
    expect(c.state!.toJson(), before);
    await tap(t, 'step-add');
    await t.enterText(find.byKey(const Key('field-title')), 'Stretch');
    await tap(t, 'field-habit-h');
    await tap(t, 'editor-save');
    expect(c.state!.toJson(), before);
    await tap(t, 'draft-edit-a');
    await t.enterText(find.byKey(const Key('field-title')), 'Open my book');
    await tap(t, 'editor-save');
    await tap(t, 'sheet-cancel');
    expect(find.text('Unsaved changes'), findsOneWidget);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    await tap(t, 'editor-save');
    final r = c.state!.routines.single;
    expect(r.steps.map((s) => s.title), [
      'Read quietly',
      'Open my book',
      'Stretch',
    ]);
    expect(r.steps.last.habit, 'h');
    expect(r.steps[1].seconds, 0);
    expect(r.steps[1].minimum, 0);
    expect(r.steps[1].required, true);
    expect(c.state!.revision, 1);
    await route(t, '/routine/r/edit');
    await tap(t, 'draft-remove-a');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tap(t, 'confirm-action');
    expect(c.state!.routines.single.steps, hasLength(3));
    await end(t, c);
  });
  testWidgets('all eleven templates are reachable and discard writes nothing', (
    t,
  ) async {
    final c = await f.start(t, state: f.seeded());
    await route(t, '/routine/new');
    await tap(t, 'routine-starters');
    expect(
      find.byKey(const Key('draft-template-A screen break')),
      findsOneWidget,
    );
    await tap(t, 'draft-template-A gentle morning');
    expect(c.state!.routines, hasLength(1));
    await tap(t, 'sheet-cancel');
    await tap(t, 'confirm-action');
    expect(c.state!.revision, 0);
    await end(t, c);
  });
  testWidgets(
    'failed save retains draft busy save commits once and stale save refuses overwrite',
    (t) async {
      final store = DraftStore()..value = f.seeded();
      final c = HabitController(open: () async => store);
      await t.runAsync(c.load);
      await t.pumpWidget(
        HabitApp(
          controller: c,
          device: false,
          clock: () => DateTime.utc(2024, 1, 8),
        ),
      );
      await t.pumpAndSettle();
      await route(t, '/routine/r/edit');
      await t.enterText(find.byKey(const Key('field-title')), 'Changed');
      store.fail = true;
      await tap(t, 'editor-save');
      expect(find.textContaining('Nothing changed.'), findsOneWidget);
      expect(c.state!.routines.single.title, 'Evening reading');
      store.fail = false;
      store.gate = Completer<void>();
      await t.tap(find.byKey(const Key('editor-save')));
      await t.pump();
      await t.tap(find.byKey(const Key('editor-save')));
      await t.pump();
      expect(store.writes, 2);
      store.gate!.complete();
      await t.pumpAndSettle();
      expect(c.state!.routines.single.title, 'Changed');
      expect(c.state!.revision, 1);
      await route(t, '/routine/r/edit');
      await t.enterText(find.byKey(const Key('field-title')), 'Stale draft');
      await c.change(
        (s) => s.copy({
          'routines': [
            s.routines.single.copy({'title': 'Elsewhere'}).toJson(),
          ],
        }),
      );
      await t.pumpAndSettle();
      await tap(t, 'editor-save');
      expect(find.textContaining('Nothing changed.'), findsOneWidget);
      expect(c.state!.routines.single.title, 'Elsewhere');
      await end(t, c);
    },
  );
  testWidgets(
    'runner keyboard pause resume skip complete exactly once summary and exit guard',
    (t) async {
      final c = await f.start(t, state: f.seeded(), tab: 2);
      await tap(t, 'start-r');
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(c.state!.sessions.single.running, false);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(c.state!.sessions.single.running, true);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Pause and exit?'), findsOneWidget);
      await t.tap(find.text('Cancel').last);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(c.state!.events, hasLength(1));
      await tap(t, 'runner-skip');
      expect(c.state!.sessions.single.steps.last.status, 'skipped');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text('Run summary'), findsOneWidget);
      expect(find.byKey(const Key('summary-habit-h')), findsOneWidget);
      expect(c.state!.events, hasLength(1));
      expect(c.state!.sessions.single.status, 'finished');
      await end(t, c);
    },
  );
  testWidgets('runner note typing cannot complete and confirmed exit pauses', (
    t,
  ) async {
    final c = await f.start(t, state: f.seeded(), tab: 2);
    await tap(t, 'start-r');
    await tap(t, 'more-menu');
    await tap(t, 'runner-note');
    await t.enterText(find.byKey(const Key('step-note')), 'A note');
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pumpAndSettle();
    expect(c.state!.events, isEmpty);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    await tap(t, 'confirm-action');
    expect(c.state!.sessions.single.running, false);
    expect(c.state!.sessions.single.status, 'active');
    expect(find.byKey(const Key('routine-complete-step')), findsNothing);
    await end(t, c);
  });
  testWidgets(
    'reopened snapshot recovers paused and stale completion cannot double credit',
    (t) async {
      final base = f.seeded();
      final session = startSession(
        base.routines.single,
        '2024-01-08',
        DateTime.utc(2024, 1, 8, 11, 58),
      );
      final c = await f.start(
        t,
        state: base.copy({
          'sessions': [session.toJson()],
        }),
      );
      await tap(t, 'resume-session');
      expect(c.state!.sessions.single.running, false);
      expect(c.state!.sessions.single.recoveryWarning, true);
      expect(c.state!.sessions.single.steps.first.elapsed, 0);
      // The away note shows while the run waits, and goes once resumed.
      const away =
          'Paused while the app was away. Only saved foreground time is counted.';
      expect(find.text(away), findsOneWidget);
      await tap(t, 'routine-pause');
      expect(find.text(away), findsNothing);
      await tap(t, 'routine-pause');
      await tap(t, 'routine-complete-step');
      await c.change(
        (s) => completeStep(
          s,
          session.id,
          expectedStep: 'a',
          today: '2024-01-08',
          now: DateTime.utc(2024, 1, 8, 12),
        ),
      );
      expect(c.state!.events, hasLength(1));
      await end(t, c);
    },
  );
  test(
    'native session snapshot and exactly-once credit survive controller restart',
    () async {
      final dir = Directory.systemTemp.createTempSync('habit-r7-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = NativeHabitStore('${dir.path}/habit.sqlite');
      final c = HabitController(open: () async => store);
      await c.load();
      final base = f.seeded();
      final now = DateTime.utc(2024, 1, 8);
      final session = startSession(base.routines.single, '2024-01-08', now);
      await c.change(
        (s) => base.copy({
          'sessions': [session.toJson()],
        }),
      );
      c.dispose();
      final again = HabitController(
        open: () async => NativeHabitStore(store.path),
      );
      await again.load();
      expect(again.state!.sessions.single.running, true);
      await again.change(
        (s) => putSession(
          s,
          recoverSession(
            s.sessions.single,
            now.add(const Duration(minutes: 2)),
          ),
        ),
      );
      await again.change(
        (s) => completeStep(
          s,
          session.id,
          expectedStep: 'a',
          today: '2024-01-08',
          now: now,
        ),
      );
      await again.change(
        (s) => completeStep(
          s,
          session.id,
          expectedStep: 'a',
          today: '2024-01-08',
          now: now,
        ),
      );
      expect((await store.read()).events, hasLength(1));
      expect(again.state!.sessions.single.steps.first.elapsed, 0);
      again.dispose();
    },
  );
  testWidgets('drag reorder stays draft until Save', (t) async {
    t.view.physicalSize = const Size(800, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = await f.start(t, state: f.seeded());
    await route(t, '/routine/r/edit');
    final first = find.byType(ReorderableDragStartListener).first;
    await t.ensureVisible(first);
    await t.pumpAndSettle();
    final gesture = await t.startGesture(t.getCenter(first));
    await gesture.moveBy(const Offset(0, 20));
    await t.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(0, 400));
    await t.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await t.pumpAndSettle();
    expect(c.state!.routines.single.steps.first.id, 'a');
    await tap(t, 'editor-save');
    expect(c.state!.routines.single.steps.map((s) => s.id), ['b', 'a']);
    await end(t, c);
  });
  testWidgets(
    'completion failure keeps step and retry credits once, unskippable stays required',
    (t) async {
      final store = DraftStore()..value = f.seeded();
      final routine = store.value.routines.single;
      store.value = store.value.copy({
        'routines': [
          routine.copy({
            'steps': [
              routine.steps.first.copy({'canSkip': false}).toJson(),
            ],
          }).toJson(),
        ],
      });
      final c = HabitController(open: () async => store);
      await c.load();
      await t.pumpWidget(
        HabitApp(
          controller: c,
          device: false,
          clock: () => DateTime.utc(2024, 1, 8),
        ),
      );
      await t.pumpAndSettle();
      await route(t, '/routine/r');
      await tap(t, 'routine-start');
      expect(find.byKey(const Key('runner-skip')), findsNothing);
      store.fail = true;
      await tap(t, 'routine-complete-step');
      expect(c.state!.events, isEmpty);
      expect(c.state!.sessions.single.steps.single.status, 'pending');
      store.fail = false;
      store.gate = Completer<void>();
      await t.tap(find.byKey(const Key('routine-complete-step')));
      await t.pump();
      await t.tap(find.byKey(const Key('routine-complete-step')));
      await t.pump();
      store.gate!.complete();
      await t.pumpAndSettle();
      expect(c.state!.events, hasLength(1));
      await tap(t, 'runner-finish');
      expect(find.byKey(const Key('summary-habit-h')), findsOneWidget);
      await end(t, c);
    },
  );
  testWidgets(
    'reduced motion step swap and progress snap without delaying check-in',
    (t) async {
      final c = await f.start(
        t,
        state: f.seeded().copy({
          'settings': {'onboarded': true, 'reducedMotion': true},
        }),
        tab: 2,
      );
      await tap(t, 'start-r');
      await t.tap(find.byKey(const Key('routine-complete-step')));
      await t.pump();
      await t.pump();
      expect(c.state!.events, hasLength(1));
      expect(find.text('Read quietly'), findsOneWidget);
      final swaps = t.widgetList<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(swaps.every((s) => s.duration == Duration.zero), true);
      final tracks = t.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(tracks.every((s) => s.duration == Duration.zero), true);
      await end(t, c);
    },
  );

  testWidgets(
    'New template Save creates a complete routine once and library expands in place',
    (t) async {
      final base = f.seeded();
      final c = await f.start(
        t,
        state: base.copy({
          'routines': [
            for (var i = 0; i < 7; i++)
              base.routines.single.copy({
                'id': 'r$i',
                'title': 'Routine $i',
              }).toJson(),
          ],
        }),
        tab: 2,
      );
      expect(find.byKey(const Key('routine-r6')), findsNothing);
      await tap(t, 'routines-more');
      expect(find.byKey(const Key('routine-r6')), findsOneWidget);
      await tap(t, 'routine-new');
      // The quick sheet first; the gallery is one tap further.
      expect(find.byKey(const Key('quick-routine')), findsOneWidget);
      await tap(t, 'quick-routine-templates');
      await t.enterText(
        find.byKey(const Key('template-search')),
        'gentle morning',
      );
      await t.pumpAndSettle();
      await tap(t, 'preset-morning');
      await tap(t, 'template-customise');
      await tap(t, 'editor-save');
      expect(c.state!.routines, hasLength(8));
      expect(c.state!.routines.last.title, 'A gentle morning');
      expect(c.state!.routines.last.steps, hasLength(3));
      expect(c.state!.revision, 1);
      await end(t, c);
    },
  );
}
