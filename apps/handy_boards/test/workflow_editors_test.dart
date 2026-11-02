import 'package:flutter/services.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_store/handy_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/scope.dart';
import 'package:handy_boards/features/task_table.dart';
import 'package:handy_boards/features/rule_editor.dart';
import 'package:handy_boards/features/planner.dart';
import 'package:handy_boards/features/task_tools.dart';
import 'package:handy_boards/features/saved_view_editor.dart';
import 'package:handy_boards/features/exam_editor.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'ui_test.dart' as fixtures;

Future<void> close(WidgetTester t, BoardsController c) async {
  await t.pumpWidget(const SizedBox());
  c.dispose();
}

void main() {
  testWidgets('exam detail edit preserves canonical task and typed metadata', (
    t,
  ) async {
    var s = fixtures.sample();
    s = s.put(
      'tasks',
      s.get('tasks', 'task').copy({
        'kind': 'exam',
        'exam': {
          'location': 'Room 1',
          'durationMinutes': 60,
          'materials': 'Calculator',
        },
      }),
    );
    final c = BoardsController(open: () async => fixtures.TestStore(s));
    await c.load();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => editExam(
                context,
                BoardsScope(c),
                'b',
                s.get('tasks', 'task').str('category'),
                task: c.state!.get('tasks', 'task'),
              ),
              child: const Text('Edit exam'),
            ),
          ),
        ),
      ),
    );
    await fixtures.tap(t, find.text('Edit exam'));
    final location = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == 'Room 1',
    );
    await t.ensureVisible(location);
    await t.enterText(location, 'Room 2');
    await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
    await fixtures.settleIO(t);
    expect(c.state!.rows('tasks').single.id, 'task');
    expect(
      object(c.state!.get('tasks', 'task').data['exam'])['location'],
      'Room 2',
    );
    expect(
      object(c.state!.get('tasks', 'task').data['exam'])['durationMinutes'],
      60,
    );
    expect(
      c.state!.get('tasks', 'task').str('category'),
      s.get('tasks', 'task').str('category'),
    );
    expect(readBackup(exportBackup(c.state!)).toJson(), c.state!.toJson());
    await close(t, c);
  });
  testWidgets(
    'saved view builder preserves repeated-property OR conditions and layout',
    (t) async {
      final c = BoardsController(
        open: () async => fixtures.TestStore(fixtures.sample()),
      );
      await c.load();
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editSavedView(context, BoardsScope(c), 'b'),
                child: const Text('Edit view'),
              ),
            ),
          ),
        ),
      );
      await fixtures.tap(t, find.text('Edit view'));
      await t.enterText(find.byType(TextField).first, 'My focus');
      await fixtures.tap(t, find.byType(DropdownButtonFormField<String>).first);
      await fixtures.tap(t, find.text('OR').last);
      for (final label in ['Normal', 'High']) {
        await fixtures.tap(t, find.text('Add condition'));
        await fixtures.tap(
          t,
          find.byType(DropdownButtonFormField<String>).last,
        );
        await fixtures.tap(t, find.text('Priority').last);
        await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
        await fixtures.tap(
          t,
          find.byType(DropdownButtonFormField<String>).last,
        );
        await fixtures.tap(t, find.text(label).last);
        await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
      }
      await fixtures.tap(t, find.widgetWithText(FilledButton, 'Save'));
      await fixtures.settleIO(t);
      final view = c.state!.rows('views').single;
      expect(view.str('mode'), 'or');
      expect(view.data['conditions'], [
        {'priority': 1},
        {'priority': 2},
      ]);
      expect(smartViewTasks(c.state!, view).single.id, 'task');
      final restored = readBackup(exportBackup(c.state!));
      expect(restored.get('views', view.id).data, view.data);
      await close(t, c);
    },
  );
  testWidgets(
    'optional Study sessions appear in Calendar without duplicate tasks',
    (t) async {
      var s = fixtures.sample();
      s = s.put(
        'classes',
        BoardRecord({
          'id': 'class',
          'board': 'b',
          'category': s.rows('categories').first.id,
          'title': 'Weekly tutorial',
          'weekday': 2,
          'startMinute': 540,
          'endMinute': 600,
          'zone': 'Asia/Ho_Chi_Minh',
        }),
      );
      final c = BoardsController(open: () async => fixtures.TestStore(s));
      await c.load();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardsCalendar(
              scope: BoardsScope(c, clock: () => DateTime.utc(2026, 11, 3)),
              board: 'b',
            ),
          ),
        ),
      );
      await fixtures.tap(t, find.widgetWithText(ChoiceChip, 'Day'));
      expect(find.text('Weekly tutorial'), findsOneWidget);
      expect(find.textContaining('09:00–10:00'), findsOneWidget);
      expect(c.state!.rows('tasks').length, 1);
      await fixtures.tap(t, find.text('Show optional class schedule'));
      expect(find.text('Weekly tutorial'), findsNothing);
      expect(find.text('Practice equations'), findsOneWidget);
      await close(t, c);
    },
  );
  testWidgets('table cell edit persists canonical task and can be undone', (
    t,
  ) async {
    final c = BoardsController(
      open: () async => fixtures.TestStore(fixtures.sample()),
    );
    await c.load();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: c,
            builder: (context, _) => TaskTable(
              scope: BoardsScope(c),
              board: 'b',
              tasks: topTasks(c.state!, board: 'b').toList(),
              selected: {},
              select: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await fixtures.tap(t, find.text('30'));
    await t.enterText(find.byType(TextField).last, '45');
    await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
    await fixtures.settleIO(t);
    expect(c.state!.get('tasks', 'task').number('estimate'), 45);
    expect(c.state!.rows('tasks').single.id, 'task');
    await t.runAsync(() => c.undo());
    await t.pumpAndSettle();
    expect(c.state!.get('tasks', 'task').number('estimate'), 30);
    await close(t, c);
  });
  testWidgets('rule preview cancellation retains draft without writing data', (
    t,
  ) async {
    final c = BoardsController(
      open: () async => fixtures.TestStore(fixtures.sample()),
    );
    await c.load();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => editAutomationRule(context, BoardsScope(c), 'b'),
              child: const Text('Edit rule'),
            ),
          ),
        ),
      ),
    );
    await fixtures.tap(t, find.text('Edit rule'));
    await t.enterText(find.byType(TextField).first, 'Review creation');
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await fixtures.tap(t, dropdowns.at(1));
    await fixtures.tap(t, find.text('High').last);
    await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
    await t.pumpAndSettle();
    expect(find.text('Save these actions?'), findsOneWidget);
    await fixtures.tap(t, find.text('Cancel').last);
    expect(c.state!.rows('rules'), isEmpty);
    expect(find.text('Review creation'), findsOneWidget);
    await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
    await t.pumpAndSettle();
    await fixtures.tap(t, find.text('Confirm').last);
    await fixtures.settleIO(t);
    expect(c.state!.rows('rules').single.str('title'), 'Review creation');
    expect(c.state!.rows('executions'), isEmpty);
    await close(t, c);
  });
  testWidgets('custom multi-select values save as typed list', (t) async {
    const channel = MethodChannel('boards_editor_test_store');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => {
            'status': 'owned',
            'productId': 'boards_test_pro',
            'owned': true,
            'verified': true,
          },
        );
    final lifetime = LifetimeController(
      const MonetizationConfig(productId: 'boards_test_pro'),
      NativeLifetimeStore(productId: 'boards_test_pro', channel: channel),
    );
    await t.runAsync(() async {
      lifetime.accept(await lifetime.store.read());
    });
    addTearDown(lifetime.dispose);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    var s = fixtures.sample().put(
      'fields',
      BoardRecord({
        'id': 'field',
        'board': 'b',
        'title': 'Channels',
        'type': 'multi',
        'options': ['Mobile', 'Web'],
      }),
    );
    final c = BoardsController(open: () async => fixtures.TestStore(s));
    await c.load();
    await t.pumpWidget(
      LifetimeScope(
        notifier: lifetime,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    taskCustomFields(context, BoardsScope(c), 'task'),
                child: const Text('Edit fields'),
              ),
            ),
          ),
        ),
      ),
    );
    await fixtures.tap(t, find.text('Edit fields'));
    await fixtures.tap(t, find.text('Mobile'));
    await fixtures.tap(t, find.text('Web'));
    await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
    await fixtures.settleIO(t);
    expect(object(c.state!.get('tasks', 'task').data['custom'])['field'], [
      'Mobile',
      'Web',
    ]);
    await close(t, c);
  });
  testWidgets('calendar week and day retain canonical due task', (t) async {
    final c = BoardsController(
      open: () async => fixtures.TestStore(fixtures.sample()),
    );
    await c.load();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardsCalendar(
            scope: BoardsScope(c, clock: () => DateTime.utc(2026, 11, 3)),
            board: 'b',
          ),
        ),
      ),
    );
    await fixtures.tap(t, find.widgetWithText(ChoiceChip, 'Week'));
    expect(find.text('Practice equations'), findsOneWidget);
    expect(find.byTooltip('Previous month'), findsNothing);
    await fixtures.tap(t, find.widgetWithText(ChoiceChip, 'Day'));
    expect(find.text('Practice equations'), findsOneWidget);
    expect(c.state!.rows('tasks').single.id, 'task');
    await close(t, c);
  });
}
