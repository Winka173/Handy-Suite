import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/app.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/data/store.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';

// Test-only repository; the app uses SQLite or IndexedDB.
class TestStore implements BoardsStore {
  BoardsState state;
  TestStore(this.state);
  @override
  Future<BoardsState> read() async => state;
  @override
  Future<String> integrity() async => 'ok';
  @override
  Future<void> commit(BoardsState next, {required int expectedRevision}) async {
    if (state.revision != expectedRevision) throw StateError('stale');
    state = next;
  }
}

final clock = DateTime(2026, 11, 7, 9);
const board = 'b0000000-0000-4000-8000-000000000001';

BoardsState studyState({bool welcomed = true}) {
  final s = createFromTemplate(
    BoardsState(
      preferences: {'locale': 'en', 'theme': 'light', 'welcomed': welcomed},
    ),
    templateById('semester')!,
    answers: {'title': 'Semester 1'},
    examples: true,
    now: clock,
    boardId: board,
  );
  // One example due today, so this week's time view has something on it.
  final first = topTasks(
    s,
    board: board,
  ).firstWhere((x) => x.data['due'] != null);
  return setDueDay(s, first.id, DateTime(clock.year, clock.month, clock.day));
}

/// Taps a look in the look picker, scrolling its list to it first.
Future<void> lookTap(WidgetTester t, String key) async {
  await t.scrollUntilVisible(
    find.byKey(Key(key)),
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('look-list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tap(t, find.byKey(Key(key)));
}

/// Taps a row of an open menu sheet, scrolling the sheet to it first.
Future<void> menuTap(WidgetTester t, String key) async {
  await t.scrollUntilVisible(
    find.byKey(Key(key)),
    120,
    scrollable: find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tap(t, find.byKey(Key(key)));
}

Future<BoardsController> boot(
  WidgetTester t,
  BoardsState s, {
  Size size = const Size(400, 860),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = BoardsController(open: () async => TestStore(s));
  await t.runAsync(c.load);
  await t.pumpWidget(BoardsApp(controller: c, clock: () => clock));
  await settle(t);
  return c;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pumpAndSettle();
  }
}

/// Shows every card on the board (it opens on this week when cards have
/// dates): the "All" chip, or on a phone the span menu's "All cards".
/// Every card in one board: a board on a timeline is turned off (nothing
/// moves, so the test sees every card).
Future<void> showAll(WidgetTester t) async {
  if (find.byKey(const Key('week-bar')).evaluate().isEmpty) return;
  await tapTime(t);
  await tap(t, find.byKey(const Key('timeline-off')));
  await tap(t, find.byKey(const Key('timeline-off-confirm')));
  // The Undo message would sit over the columns' Add card buttons.
  ScaffoldMessenger.of(
    t.element(find.byType(Scaffold).last),
  ).hideCurrentSnackBar();
  await t.pumpAndSettle();
}

/// The board's time choice: in the Filter and view sheet, or beside the
/// filters while the categories are hidden.
Future<void> tapTime(WidgetTester t) async {
  if (find.byKey(const Key('board-timeline')).evaluate().isEmpty) {
    await tap(t, find.byKey(const Key('board-filter-sheet')));
  }
  await tap(t, find.byKey(const Key('board-timeline')));
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await settle(t);
}

void main() {
  setUp(() {
    debugProOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
  });

  testWidgets('the study branch: purpose, a practice that never saves, '
      'three study suggestions; a suggestion opens its setup', (t) async {
    final c = await boot(t, BoardsState(preferences: {'locale': 'en'}));
    expect(find.byKey(const Key('welcome-skip')), findsOneWidget);
    // Next waits for a choice.
    await tap(t, find.byKey(const Key('welcome-primary')));
    expect(find.byKey(const Key('welcome-purpose-study')), findsOneWidget);
    await tap(t, find.byKey(const Key('welcome-purpose-study')));
    await tap(t, find.byKey(const Key('welcome-primary')));
    expect(find.text('Tap Add card'), findsOneWidget);
    await tap(t, find.byKey(const Key('welcome-do-it')));
    expect(find.text('Revise chapter 3'), findsWidgets);
    await tap(t, find.byKey(const Key('welcome-do-it')));
    expect(find.text('Tap Maths'), findsOneWidget);
    await tap(t, find.byKey(const Key('welcome-do-it')));
    // Focus lights Maths up; the other subjects' cards stay on the board.
    expect(find.text('Outline the essay'), findsOneWidget);
    expect(find.text('Learn 20 new words'), findsOneWidget);
    expect(find.text('Tick a subtask'), findsOneWidget);
    await tap(t, find.byKey(const Key('welcome-do-it')));
    expect(c.state!.rows('boards'), isEmpty);
    await tap(t, find.byKey(const Key('welcome-primary'))); // next
    for (final id in ['semester', 'group-assignment', 'exam-revision'])
      expect(find.byKey(Key('welcome-start-template:$id')), findsOneWidget);
    await tap(t, find.byKey(const Key('welcome-start-template:semester')));
    // Its setup opens; still nothing is made.
    expect(find.byKey(const Key('setup-preview')), findsOneWidget);
    expect(c.state!.rows('boards'), isEmpty);
    expect(c.state!.preferences['welcomed'], isTrue);
    expect(c.state!.preferences['purpose'], 'study');
  });

  testWidgets('the work branch uses work areas and suggests work templates', (
    t,
  ) async {
    await boot(t, BoardsState(preferences: {'locale': 'en'}));
    await tap(t, find.byKey(const Key('welcome-purpose-work')));
    await tap(t, find.byKey(const Key('welcome-primary')));
    await tap(t, find.byKey(const Key('welcome-do-it')));
    expect(find.text('Home screen'), findsWidgets);
    await tap(t, find.byKey(const Key('welcome-do-it')));
    expect(find.text('Tap Interface'), findsOneWidget);
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await tap(t, find.byKey(const Key('welcome-primary')));
    for (final id in ['project', 'weekly', 'ideas'])
      expect(find.byKey(Key('welcome-start-template:$id')), findsOneWidget);
  });

  testWidgets('skipping the tour leaves an empty home with both ways in', (
    t,
  ) async {
    final c = await boot(t, BoardsState(preferences: {'locale': 'en'}));
    await tap(t, find.byKey(const Key('welcome-skip')));
    expect(c.state!.rows('boards'), isEmpty);
    expect(find.text('Make your first board'), findsOneWidget);
    expect(find.byKey(const Key('first-templates')), findsOneWidget);
    expect(find.byKey(const Key('first-blank')), findsOneWidget);
  });

  testWidgets('home shows each board with its real figures', (t) async {
    final s = studyState();
    await boot(t, s);
    final sum = boardSummary(s, board, now: clock);
    expect(find.text('Your boards'), findsOneWidget);
    expect(
      find.textContaining(
        '4 categories · ${sum.cards} cards · ${sum.done} done',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'filtering by a category, adding a card in a column and moving it '
    'by menu keeps its category',
    (t) async {
      final c = await boot(t, studyState());
      await tap(t, find.byKey(const Key('board-$board')));
      final maths = categoriesOf(c.state!, board).first;
      await showAll(t);
      final others = topTasks(c.state!, board: board).where(
        (x) =>
            x.str('category') != maths.id &&
            x.str('status') == columnsOf(c.state!, board).first.id,
      );
      for (final o in others)
        expect(find.byKey(ValueKey('card-${o.id}')), findsOneWidget);
      // Picking a category shows only its cards, at once.
      await tap(t, find.byKey(Key('strip-${maths.id}')));
      // The picked tile says so with its tick.
      expect(
        find.descendant(
          of: find.byKey(Key('strip-${maths.id}')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
      for (final o in others)
        expect(find.byKey(ValueKey('card-${o.id}')), findsNothing);
      // A card added now joins the category in focus.
      final todo = columnsOf(c.state!, board).first;
      await tap(t, find.byKey(Key('add-card-open-${todo.id}')));
      await t.enterText(
        find.byKey(Key('add-card-${todo.id}')),
        'Past paper 2024',
      );
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      final card = topTasks(
        c.state!,
        board: board,
      ).firstWhere((x) => x.str('title') == 'Past paper 2024');
      expect(card.str('category'), maths.id);
      expect(card.str('status'), todo.id);
      // Move it to Done without dragging.
      final done = columnsOf(c.state!, board).last;
      final menu = find.descendant(
        of: find.byKey(ValueKey('card-${card.id}')),
        matching: find.byTooltip('Card options'),
      );
      // The card is in the first column, on screen: tapped where it is
      // (scrolling it to the edge would let the row stop on the next one).
      await t.tap(menu.first);
      await t.pumpAndSettle();
      await tap(t, find.byKey(const Key('menu-move-card')));
      await tap(t, find.byKey(Key('move-to-end-${done.id}')));
      final moved = c.state!.get('tasks', card.id);
      expect(moved.str('status'), done.id);
      expect(moved.str('category'), maths.id);
      expect(find.text('Moved to Completed'), findsOneWidget);
      // Undo puts it back.
      await tap(t, find.text('Undo'));
      expect(c.state!.get('tasks', card.id).str('status'), todo.id);
    },
  );

  testWidgets('a card opens with its subtasks; ticking them never moves it', (
    t,
  ) async {
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('board-$board')));
    final card = topTasks(
      c.state!,
      board: board,
    ).firstWhere((x) => subtaskProgress(c.state!, x.id).total > 0);
    await tap(t, find.byKey(ValueKey('card-${card.id}')));
    expect(find.text('Subtasks'), findsOneWidget);
    final first = subtasksOf(
      c.state!,
      card.id,
    ).firstWhere((x) => !x.flag('done'));
    // Larger type pushes the subtasks lower in the sheet: bring it up.
    await t.ensureVisible(find.text(first.str('title')).last);
    await t.pumpAndSettle();
    await tap(t, find.text(first.str('title')).hitTestable());
    // Tapping the words edits; the box ticks.
    await t.tap(find.text('Cancel'));
    await settle(t);
    await tap(
      t,
      find.byType(Checkbox).at(subtasksOf(c.state!, card.id).indexOf(first)),
    );
    expect(c.state!.get('checklist', first.id).flag('done'), isTrue);
    expect(c.state!.get('tasks', card.id).str('status'), card.str('status'));
  });

  testWidgets('a Pro template asks for Pro as soon as it is tapped, and '
      'nothing is made without it', (t) async {
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('home-new')));
    await tap(t, find.byKey(const Key('new-template')));
    await t.enterText(find.byKey(const Key('gallery-search')), 'sprint');
    await t.pumpAndSettle();
    await tap(t, find.byKey(const Key('template-sprint')));
    // The Pro page comes first: no preview or questions behind it.
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    expect(find.byKey(const Key('template-use')), findsNothing);
    expect(find.byKey(const Key('setup-preview')), findsNothing);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byKey(const Key('setup-preview')), findsNothing);
    expect(c.state!.rows('boards'), hasLength(1));
  });

  testWidgets('with Pro, a Pro template goes straight to its questions', (
    t,
  ) async {
    debugProOverride = true;
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('home-new')));
    await tap(t, find.byKey(const Key('new-template')));
    await t.enterText(find.byKey(const Key('gallery-search')), 'sprint');
    await t.pumpAndSettle();
    await tap(t, find.byKey(const Key('template-sprint')));
    expect(find.text('Use this template'), findsOneWidget);
    await tap(t, find.byKey(const Key('template-use')));
    await tap(t, find.byKey(const Key('setup-preview')));
    expect(find.text('Create board'), findsOneWidget);
    await tap(t, find.byKey(const Key('plan-create')));
    expect(c.state!.rows('boards'), hasLength(2));
  });

  testWidgets('a free template: answers change the board, Back keeps them, '
      'Create makes one board with fresh ids and opens it', (t) async {
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('home-new')));
    await tap(t, find.byKey(const Key('new-template')));
    await tap(t, find.byKey(const Key('template-project')));
    await tap(t, find.byKey(const Key('template-use')));
    await t.enterText(find.byKey(const Key('setup-title')), 'Shop app');
    await tap(t, find.byKey(const Key('setup-review')));
    await tap(t, find.byKey(const Key('setup-preview')));
    await tap(t, find.byKey(const Key('plan-edit')));
    // Back keeps the answers.
    expect(find.text('Shop app'), findsOneWidget);
    await tap(t, find.byKey(const Key('setup-preview')));
    await tap(t, find.byKey(const Key('plan-create')));
    expect(c.state!.rows('boards'), hasLength(2));
    final made = c.state!.rows('boards').firstWhere((b) => b.id != board);
    expect(made.str('title'), 'Shop app');
    expect(columnsOf(c.state!, made.id).map((x) => x.str('title')), [
      'Backlog',
      'In progress',
      'Done',
    ]);
    expect(topTasks(c.state!, board: made.id), isEmpty);
    expect(find.text('Shop app'), findsWidgets);
  });

  testWidgets('a blank board is two taps and a name', (t) async {
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('home-new')));
    await tap(t, find.byKey(const Key('new-blank')));
    await t.enterText(find.byKey(const Key('blank-title')), 'Errands');
    await tap(t, find.byKey(const Key('blank-create')));
    final made = c.state!.rows('boards').firstWhere((b) => b.id != board);
    expect(made.str('title'), 'Errands');
    expect(columnsOf(c.state!, made.id), hasLength(3));
  });

  testWidgets('choosing a cover and cancelling leaves the card as it was', (
    t,
  ) async {
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('board-$board')));
    await showAll(t);
    final card = topTasks(
      c.state!,
      board: board,
    ).firstWhere((x) => x.data['cover'] == null);
    await tap(t, find.byKey(ValueKey('card-${card.id}')));
    await tap(t, find.byKey(const Key('card-cover')));
    final free = coverCatalog.firstWhere((x) => !x.pro);
    await tap(t, find.byKey(const Key('cover-tab-all')));
    await tap(t, find.byKey(Key('cover-${free.id}')));
    await tap(t, find.byKey(const Key('cover-cancel')));
    expect(c.state!.get('tasks', card.id).data['cover'], isNull);
    await tap(t, find.byKey(const Key('card-cover')));
    await tap(t, find.byKey(const Key('cover-tab-all')));
    await tap(t, find.byKey(Key('cover-${free.id}')));
    await tap(t, find.byKey(const Key('cover-apply')));
    expect(c.state!.get('tasks', card.id).str('cover'), 'art:${free.id}');
  });

  testWidgets('removing a category keeps its cards on the board', (t) async {
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('board-$board')));
    final maths = categoriesOf(c.state!, board).first;
    final cards = topTasks(
      c.state!,
      board: board,
    ).where((x) => x.str('category') == maths.id).length;
    final before = topTasks(c.state!, board: board).length;
    await tap(t, find.byKey(const Key('board-filter-sheet')));
    await tap(t, find.byKey(const Key('strip-edit')));
    await tap(
      t,
      find.descendant(
        of: find.byKey(Key('category-row-${maths.id}')),
        matching: find.byTooltip('Remove category'),
      ),
    );
    expect(
      find.textContaining('Its $cards cards stay on the board'),
      findsOneWidget,
    );
    await tap(t, find.byKey(const Key('category-remove-confirm')));
    expect(c.state!.maybe('categories', maths.id), isNull);
    expect(topTasks(c.state!, board: board), hasLength(before));
  });

  testWidgets('phone, Vietnamese, large text and dark: the board still reads', (
    t,
  ) async {
    final s = studyState().copy(
      preferences: {'locale': 'vi', 'theme': 'dark', 'welcomed': true},
    );
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await boot(t, s, size: const Size(320, 640));
    expect(find.text('Bảng của bạn'), findsOneWidget);
    await tap(t, find.byKey(const Key('board-$board')));
    expect(t.takeException(), isNull);
    expect(find.text('Web Development'), findsWidgets);
    expect(find.byKey(const Key('board-filter-sheet')), findsOneWidget);
  });

  testWidgets('a board look is tried on the board itself; Cancel keeps the '
      'old one and a Pro look asks for Pro', (t) async {
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-board-look');
    await lookTap(t, 'look-linen');
    expect(find.text('Apply with Pro'), findsOneWidget);
    expect(c.state!.get('boards', board).data['appearance'], isNull);
    await tap(t, find.byKey(const Key('look-cancel')));
    expect(find.byKey(const Key('look-list')), findsNothing);
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-board-look');
    await lookTap(t, 'look-linen');
    await tap(t, find.byKey(const Key('look-apply')));
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    expect(c.state!.get('boards', board).data['appearance'], isNull);
    // Bought on the Pro page: back on the board, the look is kept.
    debugProOverride = true;
    await t.pageBack();
    await settle(t);
    expect(c.state!.get('boards', board).str('appearance'), 'linen');
    expect(find.byKey(const Key('look-list')), findsNothing);
  });

  testWidgets('export shows the picture first; Pro styles can be seen but '
      'saving them asks for Pro', (t) async {
    await boot(t, studyState(), size: const Size(1000, 800));
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await tap(t, find.byKey(const Key('menu-export')));
    expect(find.text('Semester 1'), findsWidgets);
    await tap(t, find.byKey(const Key('export-style-poster')));
    expect(find.textContaining('Saves with Pro.'), findsOneWidget);
    await tap(t, find.byKey(const Key('export-png')));
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
  });

  testWidgets('setting a card to repeat asks for Pro; with Pro it repeats', (
    t,
  ) async {
    final c = await boot(t, studyState());
    await tap(t, find.byKey(const Key('board-$board')));
    final card = topTasks(c.state!, board: board).first;
    await tap(t, find.byKey(ValueKey('card-${card.id}')));
    await tap(t, find.byKey(const Key('card-repeat')));
    await tap(t, find.byKey(const Key('card-repeat-weekly')));
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    expect(c.state!.get('tasks', card.id).data['repeat'], isNull);
    // Bought on the Pro page: the repeat is set on the way back.
    debugProOverride = true;
    await t.pageBack();
    await settle(t);
    expect(c.state!.get('tasks', card.id).str('repeat'), 'weekly');
  });
}
