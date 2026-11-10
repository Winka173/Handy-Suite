import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/settings/how_to_mocks.dart';
import 'package:handy_habit/settings/help_topics.dart';
import 'package:handy_habit/ui/row_menu.dart';
import 'package:handy_habit/shell/habit_shell.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'drive_sync_test.dart' as sync;
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;
import 'ui_test.dart' as f;

void main() {
  testWidgets('Sync has explicit Back and returns to Settings', (t) async {
    final c = await sync.device(sync.seeded());
    final d = sync.drive(c, MemoryHabitSyncProvider());
    await d.initialize();
    await t.pumpWidget(HabitApp(controller: c, device: false, driveSync: d));
    await t.pumpAndSettle();
    await host.go(t, '/settings');
    await tap(t, 'habit-sync');
    expect(find.byKey(const Key('sync-back')), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(host.route(t), '/settings');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('every pushed page has Back and returns one level', (t) async {
    final c = await host.boot(t);
    final habit = c.state!.habits.first.id;
    for (final path in [
      '/habits',
      '/habit/$habit',
      '/habit/new',
      '/habit/$habit/edit',
      '/routine/new',
      '/routine/r',
      '/routine/r/edit',
      '/templates',
      '/templates/read',
      '/settings',
      '/settings/trash',
      '/help',
      '/help/backup',
      '/progress/week',
      '/mood/2024-01-08',
      '/missing',
    ]) {
      await host.go(t, path);
      expect(find.byType(BackButton), findsOneWidget, reason: path);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(host.nav(t).canPop(), isFalse, reason: path);
    }
  });

  testWidgets('help index pictures and Back/Esc stay in help one level', (
    t,
  ) async {
    await host.boot(t);
    await host.go(t, '/help');
    expect(find.byType(HabitHelpMock), findsWidgets);
    await tap(t, 'help-topic-start');
    expect(find.byKey(const Key('help-article-start')), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('help-topic-start')), findsOneWidget);
    await tap(t, 'help-topic-start');
    await tap(t, 'help-next');
    expect(find.byKey(const Key('help-article-check-in')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('help-topic-start')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(host.nav(t).canPop(), isFalse);
  });

  testWidgets('habit More, long press and right click share confirmed delete', (
    t,
  ) async {
    final c = await host.boot(t);
    final id = c.state!.habits.first.id;
    expect(find.byKey(Key('habit-more-$id')), findsOneWidget);
    await t.longPress(find.byKey(Key('habit-$id')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('habit-delete')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('habit-$id')), buttons: kSecondaryMouseButton);
    await t.pumpAndSettle();
    await tap(t, 'habit-delete');
    expect(c.state!.trash, isEmpty);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(c.state!.trash, isEmpty);
  });

  testWidgets('list delete stays on its page and Undo restores the row', (
    t,
  ) async {
    final c = await host.boot(t);
    await host.go(t, '/habits');
    await t.tap(find.byType(HabitMenuButton).first);
    await t.pumpAndSettle();
    await tap(t, 'habit-delete');
    await tap(t, 'confirm-action');
    expect(host.route(t), '/habits');
    expect(c.state!.liveHabits, isEmpty);
    await tap(t, 'snack-undo');
    expect(c.state!.liveHabits.single.id, 'h');
    expect(find.byKey(const Key('habit-h')), findsOneWidget);
  });

  for (final kind in ['habit', 'routine']) {
    testWidgets('$kind detail delete returns to its list', (t) async {
      await host.boot(t);
      final list = kind == 'habit' ? '/habits' : '/routines';
      await host.go(t, list);
      await host.go(t, kind == 'habit' ? '/habit/h' : '/routine/r');
      await t.tap(find.byType(HabitMenuButton).first);
      await t.pumpAndSettle();
      await tap(t, '$kind-delete');
      await tap(t, 'confirm-action');
      expect(host.route(t), list);
    });
  }

  testWidgets(
    'routine context actions confirm deletion and keep its list open',
    (t) async {
      final c = await host.boot(t);
      await host.go(t, '/routines');
      await t.longPress(find.byKey(const Key('routine-r')));
      await t.pumpAndSettle();
      await tap(t, 'routine-delete');
      expect(c.state!.trash, isEmpty);
      await tap(t, 'confirm-cancel');
      await t.tap(
        find.byKey(const Key('routine-r')),
        buttons: kSecondaryMouseButton,
      );
      await t.pumpAndSettle();
      await tap(t, 'routine-delete');
      await tap(t, 'confirm-action');
      expect(host.route(t), '/routines');
      expect(c.state!.liveRoutines, isEmpty);
      await tap(t, 'snack-undo');
      expect(c.state!.liveRoutines.single.id, 'r');
    },
  );

  testWidgets('one-day Trash wording and permanent delete never offer Undo', (
    t,
  ) async {
    final base = f.seeded();
    await host.boot(
      t,
      state: trashEntity(
        base,
        'habit',
        'h',
        host.now.subtract(const Duration(days: 29)),
      ),
    );
    await host.go(t, '/settings/trash');
    expect(find.textContaining('1 day left'), findsOneWidget);
    await t.tap(find.text('Delete for good'));
    await t.pumpAndSettle();
    await tap(t, 'confirm-action');
    expect(find.byKey(const Key('snack-undo')), findsNothing);
  });

  testWidgets('latest Undo message replaces queued messages', (t) async {
    await host.boot(t);
    final context = t.element(find.byKey(const Key('bead-h')));
    final scope = t.widget<HabitShell>(find.byType(HabitShell)).scope;
    scope.announce(context, 'First');
    await t.pumpAndSettle();
    scope.announce(context, 'Second');
    scope.announce(context, 'Latest');
    await t.pumpAndSettle();
    expect(find.text('Second'), findsNothing);
    expect(find.text('Latest'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final theme in ['light', 'dark']) {
    testWidgets(
      'new controls have labels, contrast and 48px targets in $theme',
      (t) async {
        final semantics = t.ensureSemantics();
        final base = f.seeded();
        await host.boot(
          t,
          state: base.copy({
            'settings': {...base.settings, 'theme': theme},
          }),
        );
        for (final path in ['/mood/2024-01-08', '/help']) {
          await host.go(t, path);
          for (final guideline in [
            labeledTapTargetGuideline,
            androidTapTargetGuideline,
            iOSTapTargetGuideline,
            textContrastGuideline,
          ]) {
            await expectLater(t, meetsGuideline(guideline), reason: path);
          }
          host.nav(t).pop();
          await t.pumpAndSettle();
        }
        await t.tap(find.byType(HabitMenuButton).first);
        await t.pumpAndSettle();
        for (final entry in t.widgetList<PopupMenuItem<int>>(
          find.byType(PopupMenuItem<int>),
        )) {
          expect(entry.height, greaterThanOrEqualTo(48));
        }
        semantics.dispose();
      },
    );
  }

  testWidgets('face scale saves with Enter, without a note or colour cue', (
    t,
  ) async {
    final c = await host.boot(t);
    await host.go(t, '/mood/2024-01-08');
    final face = find.byKey(const Key('mood-choice-4'));
    expect(t.getSize(face).width, greaterThanOrEqualTo(48));
    expect(t.getSize(face).height, greaterThanOrEqualTo(48));
    Focus.of(
      t.element(find.descendant(of: face, matching: find.byType(Text)).first),
    ).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(c.state!.moods.single.mood, 4);
    expect(c.state!.moods.single.note, isEmpty);
  });

  testWidgets('month and year day targets stay 48px on a narrow screen', (
    t,
  ) async {
    final base = f.seeded();
    await host.boot(
      t,
      width: 320,
      scale: 2,
      state: base.copy({
        'settings': {...base.settings, 'reducedMotion': true},
      }),
    );
    await host.go(t, '/progress');
    final day = find.byKey(const Key('calendar-2024-01-08'));
    expect(t.getSize(day).width, greaterThanOrEqualTo(48));
    expect(t.getSize(day).height, greaterThanOrEqualTo(48));
    await tap(t, 'range-year');
    final cell = find.byKey(const Key('heatmap-2024-01-01'));
    expect(t.getSize(cell), const Size(48, 48));
    await t.ensureVisible(cell);
    await t.pumpAndSettle();
    await t.tap(cell);
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      ModalRoute.of(t.element(find.byType(BottomSheet)))!.transitionDuration,
      Duration.zero,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('mood delete confirms and cancellation preserves the entry', (
    t,
  ) async {
    final c = await host.boot(
      t,
      state: saveMood(
        f.seeded(),
        '2024-01-08',
        4,
        now: host.now,
        expectedRevision: 0,
      ),
    );
    await host.go(t, '/mood/2024-01-08');
    await tap(t, 'mood-delete');
    expect(find.text('Delete this mood entry?'), findsOneWidget);
    expect(c.state!.moods.single.deleted, isFalse);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(c.state!.moods.single.deleted, isFalse);
    await tap(t, 'mood-delete');
    await t.tap(find.text('Delete').last);
    await t.pumpAndSettle();
    expect(c.state!.moods.single.deleted, isTrue);
  });

  testWidgets('Undo expires and uses zero motion when reduced', (t) async {
    final state = f.seeded();
    await host.boot(
      t,
      state: state.copy({
        'settings': {...state.settings, 'reducedMotion': true},
      }),
    );
    await t.tap(find.byKey(Key('bead-${state.habits.first.id}')));
    await t.pump();
    await t.pump();
    final snack = t.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.persist, isFalse);
    expect(snack.animation!.value, 1);
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('snack-undo')), findsNothing);
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('help, mood and settings fit at text $scale', (t) async {
      await host.boot(t, width: 320, scale: scale);
      for (final path in [
        '/help',
        for (final topic in habitHelpTopics) '/help/${topic.id}',
        '/mood/2024-01-08',
        '/settings',
        '/habits',
        '/habit/h',
        '/habit/new',
        '/routine/r',
        '/routine/new',
        '/routines',
        '/progress',
        '/progress/week',
        '/templates',
      ]) {
        await host.go(t, path);
        final error = t.takeException();
        if (error is FlutterError) debugPrint(error.toStringDeep());
        expect(error, isNull, reason: path);
        host.nav(t).pop();
        await t.pumpAndSettle();
      }
    });
  }
}
