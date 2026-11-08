import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart' hide clock;
import 'package:handy_ui/kit.dart';
import 'kanban_app_test.dart' show boot, tap, menuTap, studyState, board, clock;
import 'settings_test.dart' show tall, openSettings;

void main() {
  setUp(() {
    debugProOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
  });

  testWidgets('rules: an example opens with a preview, saving asks for Pro, '
      'then it runs inside the person\'s change and is logged', (t) async {
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-rules');
    // Free: the Pro page opens at once, not the rules first.
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    expect(find.byKey(const Key('rules-page')), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    debugProOverride = true;
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-rules');
    expect(find.byKey(const Key('rules-page')), findsOneWidget);
    await tap(t, find.byKey(const Key('rule-example-0')));
    await t.scrollUntilVisible(
      find.byKey(const Key('rule-preview')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('add subtask'), findsWidgets);
    expect(c.state!.rows('rules'), isEmpty);
    // A second step: High priority.
    await tap(t, find.byKey(const Key('rule-add-action')));
    await tap(t, find.byKey(const Key('rule-pick-priority')));
    await tap(t, find.byKey(const Key('rule-pick-3')));
    await tap(t, find.byKey(const Key('rule-save')));
    final rule = c.state!.rows('rules').single;
    expect(rule.flag('enabled'), isTrue);
    expect(find.byKey(Key('rule-${rule.id}')), findsOneWidget);
    expect(find.byKey(const Key('rule-log-empty')), findsOneWidget);

    // The person adds a card: the rule acts in the same change.
    await t.runAsync(
      () => c.change(
        (s) => saveTask(s, newTask(s, board, 'Lab report'), now: clock),
      ),
    );
    await t.pumpAndSettle();
    final card = topTasks(
      c.state!,
      board: board,
    ).firstWhere((x) => x.str('title') == 'Lab report');
    expect(card.data['priority'], 3);
    expect(subtasksOf(c.state!, card.id), hasLength(1));
    expect(find.byKey(const Key('rule-log-empty')), findsNothing);
    expect(find.text('Lab report'), findsOneWidget);
    // One Undo takes back the card and what the rule did.
    await t.runAsync(c.undo);
    await t.pumpAndSettle();
    expect(c.state!.maybe('tasks', card.id), isNull);

    // Off: nothing runs.
    await tap(t, find.byKey(Key('rule-on-${rule.id}')));
    expect(c.state!.get('rules', rule.id).flag('enabled'), isFalse);
    await t.runAsync(
      () => c.change(
        (s) => saveTask(s, newTask(s, board, 'Quiet card'), now: clock),
      ),
    );
    await t.pumpAndSettle();
    final quiet = topTasks(
      c.state!,
      board: board,
    ).firstWhere((x) => x.str('title') == 'Quiet card');
    expect(subtasksOf(c.state!, quiet.id), isEmpty);

    // Editing, then deleting.
    await tap(t, find.byKey(Key('rule-${rule.id}')));
    await tap(t, find.byKey(const Key('rule-delete')));
    expect(c.state!.rows('rules'), isEmpty);
  });

  testWidgets('rules: a due-soon rule offers "Notify me" and previews the '
      'cards it covers today', (t) async {
    debugProOverride = true;
    var s = studyState();
    final today = DateTime(clock.year, clock.month, clock.day);
    s = saveTask(
      s,
      newTask(s, board, 'Essay').copy({
        'due': {'kind': 'day', 'day': isoDay(addDays(today, 1))},
      }),
      now: clock,
    );
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-rules');
    await tap(t, find.byKey(const Key('rule-new')));
    await tap(t, find.byKey(const Key('rule-trigger-due soon')));
    await t.scrollUntilVisible(
      find.byKey(const Key('rule-preview')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Today it would act on'), findsOneWidget);
    expect(find.text('· Essay'), findsOneWidget);
    await tap(t, find.byKey(const Key('rule-add-action')));
    await tap(t, find.byKey(const Key('rule-pick-notify')));
    await tap(t, find.byKey(const Key('rule-save')));
    final rule = c.state!.rows('rules').single;
    expect(rule.str('trigger'), 'due soon');
    expect(rule.data['days'], 1);
    expect((rule.data['actions'] as List).single, {
      'type': 'notify',
      'value': true,
    });
  });

  testWidgets('widget styles: free ones apply at once, a Pro one previews '
      'and asks only at Apply', (t) async {
    final c = await boot(t, studyState(), size: tall);
    await openSettings(t);
    await tap(t, find.byKey(const Key('settings-home-widget')));
    await tap(t, find.byKey(const Key('widget-style-dark')));
    expect(c.state!.preferences['widgetStyle'], 'dark');
    await tap(t, find.byKey(const Key('widget-style-harbor')));
    // Previewed only: the stored style is unchanged.
    expect(c.state!.preferences['widgetStyle'], 'dark');
    final box = t.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('widget-today')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, const Color(0xFF0F2A2E));
    await tap(t, find.byKey(const Key('widget-style-apply')));
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(c.state!.preferences['widgetStyle'], 'dark');
    debugProOverride = true;
    // A tap rebuilds the page under Pro, then the Pro style applies.
    await tap(t, find.byKey(const Key('widget-style-light')));
    await tap(t, find.byKey(const Key('widget-style-harbor')));
    expect(c.state!.preferences['widgetStyle'], 'harbor');
    await tap(t, find.byKey(const Key('widget-style-system')));
    expect(c.state!.preferences['widgetStyle'], isNull);
  });

  testWidgets('export: the report lists open cards by deadline; custom '
      'fields are a Pro option on any style', (t) async {
    var s = studyState();
    s = addField(s, board, 'Teacher', 'text');
    final field = fieldsOf(
      s,
      board,
    ).firstWhere((f) => f.str('title') == 'Teacher').id;
    final card = topTasks(s, board: board).first;
    s = setFieldValue(s, card.id, field, 'Ms Lan', now: clock);
    await boot(t, s, size: const Size(1000, 900));
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await tap(t, find.byKey(const Key('menu-export')));
    // Plain with fields: shown, saving asks for Pro.
    await tap(t, find.byKey(const Key('export-fields')));
    expect(find.text('Teacher: Ms Lan'), findsOneWidget);
    expect(find.textContaining('Saves with Pro.'), findsOneWidget);
    await tap(t, find.byKey(const Key('export-png')));
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await tap(t, find.byKey(const Key('export-style-report')));
    expect(find.byKey(const Key('board-report')), findsOneWidget);
    expect(find.text('Finished per week'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Ms Lan'), findsOneWidget);
    await tap(t, find.byKey(const Key('export-fields')));
    expect(find.text('Teacher'), findsNothing);
  });

  testWidgets('digest: Pro picks daily or weekly, the day and the boards', (
    t,
  ) async {
    // A desktop without notifications: no permission prompt in a test.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final c = await boot(t, studyState(), size: tall);
    await openSettings(t);
    await tap(t, find.byKey(const Key('settings-reminders')));
    await tap(t, find.text('Daily'));
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect((c.state!.preferences['notify'] as Map?)?['digest'], isNull);
    debugProOverride = true;
    await t.pumpAndSettle();
    await tap(t, find.text('Weekly'));
    expect((c.state!.preferences['notify'] as Map)['digest'], 'weekly');
    expect(c.state!.preferences['notifications'], isTrue);
    await tap(t, find.byKey(const Key('notify-digest-day')));
    await tap(t, find.byKey(const Key('digest-day-5')));
    expect((c.state!.preferences['notify'] as Map)['digestDay'], 5);
    await tap(t, find.byKey(const Key('notify-digest-boards')));
    expect(find.byKey(Key('digest-board-$board')), findsOneWidget);
    await tap(t, find.byKey(const Key('digest-boards-save')));
    // All boards picked: stored as "every board".
    expect((c.state!.preferences['notify'] as Map)['digestBoards'], isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
