import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/features/editors.dart';
import 'package:handy_boards/scope.dart';
import 'package:handy_boards/ui/labels.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart' as fixtures;

Future<BoardsController> openEditor(WidgetTester t, BoardsState s) async {
  t.view.physicalSize = const Size(800, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final c = BoardsController(open: () async => fixtures.TestStore(s));
  await c.load();
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => editTask(context, BoardsScope(c), 'task'),
            child: const Text('Edit'),
          ),
        ),
      ),
    ),
  );
  await fixtures.tap(t, find.text('Edit'));
  return c;
}

void main() {
  const label = 'Assignee label (local only)';

  testWidgets('a personal task has no assignee field, and saving keeps it '
      'empty', (t) async {
    final s = fixtures.sample();
    expect(boardsUseAssignee(s), isFalse);
    final c = await openEditor(t, s);
    expect(find.text(label, skipOffstage: false), findsNothing);
    await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
    await fixtures.settleIO(t);
    expect(c.state!.get('tasks', 'task').str('assignee'), '');
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('a task that already names someone keeps the field and value', (
    t,
  ) async {
    var s = fixtures.sample();
    s = s.put('tasks', s.get('tasks', 'task').copy({'assignee': 'Lan'}));
    expect(boardsUseAssignee(s), isTrue);
    final c = await openEditor(t, s);
    expect(find.text(label, skipOffstage: false), findsOneWidget);
    await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
    await fixtures.settleIO(t);
    expect(c.state!.get('tasks', 'task').str('assignee'), 'Lan');
    // Still in the backup, as before.
    expect(
      readBackup(exportBackup(c.state!)).get('tasks', 'task').str('assignee'),
      'Lan',
    );
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
