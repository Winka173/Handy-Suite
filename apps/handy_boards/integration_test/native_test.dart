import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards/app.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/data/store_native.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

Future<void> complete(WidgetTester t, bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pump();
  }
  expect(condition(), true);
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder.first);
  await t.tap(finder.first);
  await t.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native category-first journey, canonical views, SQLite restart and ZIP restore',
    (t) async {
      const phase = String.fromEnvironment(
        'BOARDS_QA_PHASE',
        defaultValue: 'write',
      );
      final dir = await getApplicationSupportDirectory(),
          store = NativeBoardsStore('${dir.path}/boards-qa.sqlite'),
          c = BoardsController(open: () async => store),
          snapshot = File('${dir.path}/boards-qa-expected.json');
      await t.runAsync(c.load);
      expect(c.error, isNull);
      if (phase == 'write')
        await t.runAsync(() => c.change((s) => BoardsState()));
      if (phase == 'read')
        expect(c.state!.toJson(), jsonDecode(await snapshot.readAsString()));
      await t.pumpWidget(
        BoardsApp(controller: c, clock: () => DateTime.utc(2026, 11, 2)),
      );
      await t.pumpAndSettle();
      if (phase == 'write') {
        await tap(t, find.text('Create a board'));
        await t.enterText(find.byType(TextField).first, 'Semester 1');
        await tap(t, find.text('Blank board'));
        await tap(t, find.text('Study / Semester').last);
        await tap(t, find.byKey(const Key('boards-form-save')));
        await complete(t, () => c.state!.rows('boards').length == 1);
        for (final name in ['Mathematics', 'Java', 'English', 'Physics'])
          expect(find.text(name), findsOneWidget);
        await tap(t, find.text('Add task').first);
        await t.enterText(find.byType(TextField).last, 'Solve equations');
        await tap(t, find.byKey(const Key('boards-form-save')));
        await complete(t, () => c.state!.rows('tasks').length == 1);
        final task = c.state!.rows('tasks').single,
            category = task.str('category');
        expect(
          c.state!.get('categories', category).str('title'),
          'Mathematics',
        );
        await tap(t, find.widgetWithText(ChoiceChip, 'Kanban'));

        await tap(t, find.byTooltip('Change status'));
        await tap(t, find.text('Doing').last);
        await complete(
          t,
          () =>
              c.state!
                  .get('statuses', c.state!.get('tasks', task.id).str('status'))
                  .str('title') ==
              'Doing',
        );
        expect(c.state!.get('tasks', task.id).str('category'), category);
        await tap(t, find.widgetWithText(ChoiceChip, 'Categories'));
        await t.runAsync(
          () => c.change(
            (s) => saveTask(
              s,
              s.get('tasks', task.id).copy({
                'due': {'kind': 'day', 'day': '2026-11-03'},
              }),
            ),
          ),
        );
        await t.pumpAndSettle();
        final child = newTask(
          c.state!,
          task.str('board'),
          'Read notes',
          category: category,
          parent: task.id,
        );
        await t.runAsync(
          () => c.change(
            (s) => saveTask(s, child).put(
              'checklist',
              BoardRecord({
                'id': newId(),
                'task': task.id,
                'title': 'Check answer',
                'done': true,
              }),
            ),
          ),
        );
        expect(
          summary(
            c.state!,
            c.state!.rows('tasks'),
            now: DateTime.utc(2026, 11, 2),
          )['total'],
          1,
        );
        final back = readBackup(exportBackup(c.state!));
        expect(back.toJson(), c.state!.toJson());
        final restored = restoreBackup(
          BoardsState(),
          back,
          replace: true,
          confirmed: true,
        );
        expect(
          restored.rows('tasks').map((t) => t.id).toSet(),
          c.state!.rows('tasks').map((t) => t.id).toSet(),
        );
        await snapshot.writeAsString(jsonEncode(c.state!.toJson()));
      }
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await t.pumpAndSettle();
      await binding.takeScreenshot('boards-native-$phase-categories');
      await tap(t, find.text('Today').last);
      await binding.takeScreenshot('boards-native-$phase-today');
      await tap(t, find.text('Calendar').last);
      await binding.takeScreenshot('boards-native-$phase-calendar');
      final reopened = await store.read();
      expect(reopened.toJson(), c.state!.toJson());
      binding.reportData = {
        ...?binding.reportData,
        'phase': phase,
        'pid': pid,
        'physicalDevice': false,
        'canonicalTasks': c.state!.rows('tasks').length,
        'topLevelTasks': topTasks(c.state!).length,
        'integrity': await store.integrity(),
        'database': 'QA-only boards-qa.sqlite',
      };
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
