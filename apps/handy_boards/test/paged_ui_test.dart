import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards/app.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/data/store_native.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'ui_test.dart' as fixtures;

void main() {
  testWidgets(
    'List pages native canonical records and refreshes after an edit',
    (t) async {
      late Directory dir;
      late BoardsController c;
      await t.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('boards-paged-ui-');
        final store = NativeBoardsStore('${dir.path}/boards.sqlite');
        await store.read();
        var s = createBoard(BoardsState(), 'Tasks', boardId: 'b');
        final edit = BoardsEdit(s);
        for (var i = 0; i < 121; i++)
          edit.put(
            'tasks',
            newTask(s, 'b', 'Task $i').copy({'id': 'task-$i', 'order': i}),
          );
        await store.commit(
          edit.finish().copy(revision: 1),
          expectedRevision: 0,
        );
        c = BoardsController(open: () async => store);
        await c.load();
      });
      await t.pumpWidget(BoardsApp(controller: c));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ChoiceChip, 'List'));
      await t.pump();
      await fixtures.settleIO(t);
      expect(find.text('1–100 / 121'), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.pump();
      await fixtures.settleIO(t);
      expect(find.text('101–121 / 121'), findsOneWidget);
      expect(find.text('Task 100'), findsOneWidget);
      await t.runAsync(
        () => c.change(
          (s) => s.put(
            'tasks',
            s.get('tasks', 'task-0').copy({'title': 'Edited task'}),
          ),
        ),
      );
      await t.pump();
      await fixtures.settleIO(t);
      expect(find.text('1–100 / 121'), findsOneWidget);
      expect(find.text('Edited task'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      await t.runAsync(() => dir.delete(recursive: true));
    },
  );
}
