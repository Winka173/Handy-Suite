import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/home_widget.dart';
import 'package:handy_habit/reminders.dart';
import 'package:timezone/timezone.dart' as tz;
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;
import 'ui_test.dart' as f;

void main() {
  test(
    'mood and private notes never enter reminder or home-widget payloads',
    () {
      final base = f.seeded();
      final withMood = saveMood(
        base,
        '2024-01-08',
        1,
        now: host.now,
        expectedRevision: 0,
        note: 'PRIVATE-MOOD-NOTE',
        tags: ['PRIVATE-TAG'],
      );
      final reminder = DueReminder(
        'h',
        tz.TZDateTime.from(host.now, location(base.zone)),
      );
      for (final vi in [false, true]) {
        final a = habitWidgetView(base, '2024-01-08', vi: vi),
            b = habitWidgetView(withMood, '2024-01-08', vi: vi);
        expect(
          [b.title, b.value, b.detail, b.uri, b.rows],
          [a.title, a.value, a.detail, a.uri, a.rows],
        );
      }
      for (final showNames in [false, true]) {
        HabitState preference(HabitState s) => s.copy({
          'settings': {...s.settings, 'privateNotifications': !showNames},
        });
        expect(
          reminderBody(preference(withMood), reminder),
          reminderBody(preference(base), reminder),
        );
      }
    },
  );
  testWidgets(
    'relogging after deletion starts with empty optional details; restore is explicit',
    (t) async {
      var state = saveMood(
        f.seeded(),
        '2024-01-08',
        2,
        now: host.now,
        expectedRevision: 0,
        note: 'Old note',
        tags: ['old'],
      );
      state = deleteMood(
        state,
        '2024-01-08',
        now: host.now,
        expectedRevision: 1,
      );
      final c = await host.boot(t, state: state);
      await tap(t, 'today-mood');
      await tap(t, 'mood-choice-5');
      expect(c.state!.moods.single.note, isEmpty);
      expect(c.state!.moods.single.tags, isEmpty);
      await tap(t, 'snack-undo');
      expect(c.state!.moods.single.deleted, true);
      expect(c.state!.moods.single.note, 'Old note');
    },
  );
  testWidgets(
    'history caps at five, follows range and keeps mood independent of habit filter',
    (t) async {
      var state = f.seeded();
      for (var n = 1; n <= 7; n++) {
        state = saveMood(
          state,
          '2024-01-0$n',
          3,
          now: host.now,
          expectedRevision: 0,
        );
      }
      await host.boot(t, state: state);
      await host.go(t, '/progress');
      expect(find.byKey(const Key('mood-row-2024-01-01')), findsNothing);
      await tap(t, 'mood-history-more');
      expect(find.byKey(const Key('mood-row-2024-01-01')), findsOneWidget);
      await tap(t, 'progress-prev');
      expect(find.byKey(const Key('mood-row-2024-01-01')), findsNothing);
      expect(find.textContaining('0 days recorded.'), findsOneWidget);
      await host.go(t, '/mood/2024-01-09');
      expect(find.byKey(const Key('mood-choice-1')), findsNothing);
    },
  );
  testWidgets(
    'two taps log with no note or keyboard and keep core habit data',
    (t) async {
      final c = await host.boot(t);
      final habits = jsonEncode(
        c.state!.habits.map((h) => h.toJson()).toList(),
      );
      await tap(t, 'today-mood');
      expect(find.byType(TextField), findsNothing);
      expect(t.testTextInput.isVisible, false);
      await tap(t, 'mood-choice-4');
      expect(c.state!.moods.single.mood, 4);
      expect(c.state!.moods.single.note, isEmpty);
      expect(c.state!.moods.single.energy, isNull);
      expect(c.state!.events, isEmpty);
      expect(
        jsonEncode(c.state!.habits.map((h) => h.toJson()).toList()),
        habits,
      );
      await tap(t, 'snack-undo');
      expect(c.state!.moods, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Skip and Escape write nothing; detailed cancel protects unsaved note',
    (t) async {
      final c = await host.boot(t);
      final before = jsonEncode(c.state!.toJson());
      await tap(t, 'today-mood');
      await tap(t, 'mood-skip');
      expect(jsonEncode(c.state!.toJson()), before);
      await tap(t, 'today-mood');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(jsonEncode(c.state!.toJson()), before);
      await tap(t, 'today-mood');
      await tap(t, 'mood-details');
      await t.enterText(find.byKey(const Key('field-note')), 'Private draft');
      await tap(t, 'sheet-cancel');
      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(jsonEncode(c.state!.toJson()), before);
    },
  );
  testWidgets(
    'details edit, delete Undo and history restore preserve optional fields',
    (t) async {
      final c = await host.boot(t);
      await tap(t, 'today-mood');
      await tap(t, 'mood-details');
      await tap(t, 'field-mood-2');
      await tap(t, 'field-energy-4');
      await t.enterText(find.byKey(const Key('field-note')), 'A quiet evening');
      await t.enterText(find.byKey(const Key('field-tags')), 'home, evening');
      await tap(t, 'editor-save');
      expect(c.state!.moods.single.tags, ['home', 'evening']);
      expect(c.state!.moods.single.energy, 4);
      await tap(t, 'today-mood');
      await tap(t, 'mood-choice-3');
      expect(c.state!.moods.single.note, 'A quiet evening');
      expect(c.state!.moods.single.revision, 2);
      await tap(t, 'today-mood');
      await tap(t, 'mood-delete');
      expect(c.state!.moods.single.deleted, isFalse);
      await tap(t, 'confirm-action');
      expect(c.state!.moods.single.deleted, true);
      await tap(t, 'snack-undo');
      expect(c.state!.moods.single.deleted, false);
      await tap(t, 'today-mood');
      await tap(t, 'mood-delete');
      expect(c.state!.moods.single.deleted, isFalse);
      await tap(t, 'confirm-action');
      await host.go(t, '/progress');
      await tap(t, 'mood-show-deleted');
      await tap(t, 'mood-restore-2024-01-08');
      expect(c.state!.moods.single.deleted, false);
      expect(c.state!.moods.single.note, 'A quiet evening');
      expect(c.state!.moods.single.tags, ['home', 'evening']);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'setting off hides prompt, keeps history and lets habit check-in work',
    (t) async {
      final state = saveMood(
        f.seeded(),
        '2024-01-08',
        5,
        now: host.now,
        expectedRevision: 0,
      );
      final c = await host.boot(t, state: state);
      await host.go(t, '/settings');
      await tap(t, 'settings-show-mood');
      expect(c.state!.settings['showMoodToday'], false);
      host.nav(t).pop();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('today-mood')), findsNothing);
      expect(c.state!.moods, hasLength(1));
      await tap(t, 'bead-h');
      expect(c.state!.events, hasLength(1));
      await host.go(t, '/progress');
      await t.ensureVisible(find.byKey(const Key('mood-row-2024-01-08')));
      expect(find.byKey(const Key('mood-row-2024-01-08')), findsOneWidget);
      await host.go(t, '/help/mood');
      await t.scrollUntilVisible(
        find.textContaining('no health claims'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('no health claims'), findsOneWidget);
    },
  );
  testWidgets(
    'failed mood save keeps choices, retry and busy prevent duplicate saves',
    (t) async {
      final store = host.GatedStore()
        ..value = f.seeded()
        ..fail = true;
      final c = await host.boot(t, store: store);
      await tap(t, 'today-mood');
      await tap(t, 'mood-choice-1');
      expect(c.state!.moods, isEmpty);
      expect(find.textContaining('Not saved.'), findsOneWidget);
      store.fail = false;
      store.gate = Completer<void>();
      await t.tap(find.byKey(const Key('mood-choice-1')));
      await t.pump();
      await t.tap(find.byKey(const Key('mood-choice-1')));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.byKey(const Key('mood-choice-1')), findsOneWidget);
      expect(store.attempts, 2);
      store.gate!.complete();
      await t.pumpAndSettle();
      expect(c.state!.moods, hasLength(1));
      expect(c.state!.moods.single.mood, 1);
    },
  );
}
