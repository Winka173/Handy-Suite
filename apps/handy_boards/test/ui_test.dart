import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards/app.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/data/store.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

// Test-only repository; production uses native SQLite or IndexedDB.
class TestStore implements BoardsStore {
  BoardsState state;
  bool fail = false;
  TestStore(this.state);
  @override
  Future<BoardsState> read() async => state;
  @override
  Future<String> integrity() async => 'ok';
  @override
  Future<void> commit(BoardsState next, {required int expectedRevision}) async {
    if (fail) throw StateError('disk full');
    if (state.revision != expectedRevision) throw StateError('stale');
    state = next;
  }
}

BoardsState sample({String locale = 'en', String theme = 'light'}) {
  var s = createBoard(
    BoardsState(),
    'Semester 1',
    template: 'study',
    boardId: 'b',
  );
  s = saveTask(
    s,
    newTask(
      s,
      'b',
      'Practice equations',
      category: s.rows('categories').first.id,
    ).copy({
      'id': 'task',
      'due': {'kind': 'day', 'day': '2026-11-03'},
      'estimate': 30,
    }),
  );
  return s.copy(preferences: {'locale': locale, 'theme': theme});
}

Future<void> settleIO(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder target) async {
  await t.ensureVisible(target.first);
  await t.tap(target.first);
  await t.pumpAndSettle();
}

void main() {
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        ),
  );
  testWidgets(
    'four category identities, canonical task status change and view parity',
    (t) async {
      t.view.physicalSize = const Size(430, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = BoardsController(open: () async => TestStore(sample()));
      await c.load();
      await t.pumpWidget(
        BoardsApp(controller: c, clock: () => DateTime.utc(2026, 11, 2)),
      );
      await t.pumpAndSettle();
      for (final name in ['Mathematics', 'Java', 'English', 'Physics'])
        expect(find.text(name), findsOneWidget);
      expect(find.text('Practice equations'), findsNothing);
      await tap(t, find.widgetWithText(ChoiceChip, 'Kanban'));
      expect(find.text('Practice equations'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);

      await tap(t, find.byTooltip('Change status').first);
      await tap(t, find.text('Doing').last);
      await settleIO(t);
      // Fixture generates unique category IDs each time: compare the persisted name.
      final task = c.state!.get('tasks', 'task');
      expect(
        c.state!.get('categories', task.str('category')).str('title'),
        'Mathematics',
      );
      expect(
        c.state!.get('statuses', task.str('status')).str('title'),
        'Doing',
      );
      await tap(t, find.widgetWithText(ChoiceChip, 'Categories'));
      expect(find.text('Mathematics'), findsOneWidget);
      expect(c.state!.rows('tasks').length, 1);
      await tap(t, find.text('Today').last);
      await t.scrollUntilVisible(
        find.text('Practice equations'),
        160,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Practice equations'), findsOneWidget);
      await tap(t, find.text('Calendar').last);
      await tap(t, find.text('3').first);
      await t.scrollUntilVisible(
        find.text('Practice equations'),
        160,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Practice equations'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('failed quick capture retains title and commits no task', (
    t,
  ) async {
    final store = TestStore(sample())..fail = true,
        c = BoardsController(open: () async => store);
    await c.load();
    await t.pumpWidget(BoardsApp(controller: c));
    await t.pumpAndSettle();
    await tap(t, find.text('Add task').first);
    await t.enterText(find.byType(TextField).last, 'Do not lose this title');
    await tap(t, find.byKey(const Key('boards-form-save')));
    await settleIO(t);
    expect(find.text('Do not lose this title'), findsOneWidget);
    expect(find.textContaining('disk full'), findsOneWidget);
    expect(c.state!.rows('tasks').length, 1);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  for (final width in [320.0, 375.0, 430.0, 768.0, 1024.0, 1440.0])
    testWidgets('layout $width with VI and large text', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = width == 320 ? 2 : 1;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = BoardsController(
        open: () async => TestStore(sample(locale: 'vi')),
      );
      await c.load();
      await t.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(width == 320 ? 2 : 1),
          ),
          child: BoardsApp(controller: c),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
}
