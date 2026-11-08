// Every screen of Handy Boards at every shape it meets: small and large
// phones both ways up, BlueStacks' landscape window, tablets, desktop and
// very large text. A layout that overflows, throws, or leaves the board
// too short to use fails here with the screen and size named.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/app.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart' hide clock;
import 'kanban_app_test.dart' show TestStore, studyState, board, clock, settle;

typedef Shape = ({String name, Size size, double text});

const shapes = <Shape>[
  (name: 'phone 320', size: Size(320, 568), text: 1),
  (name: 'phone 360', size: Size(360, 640), text: 1),
  (name: 'phone 412', size: Size(412, 915), text: 1),
  (name: 'phone 360 text x2', size: Size(360, 740), text: 2),
  (name: 'phone landscape', size: Size(640, 360), text: 1),
  (name: 'large phone landscape', size: Size(915, 412), text: 1),
  (name: 'BlueStacks 1000x562', size: Size(1000, 562), text: 1),
  (name: 'BlueStacks 1280x720', size: Size(1280, 720), text: 1),
  (name: 'tablet portrait', size: Size(768, 1024), text: 1),
  (name: 'tablet landscape', size: Size(1024, 768), text: 1),
  (name: 'desktop', size: Size(1440, 900), text: 1),
];

void main() {
  setUp(() {
    debugProOverride = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
  });
  tearDown(() => debugProOverride = null);

  for (final shape in shapes) {
    testWidgets('every screen fits: ${shape.name}', (t) async {
      final problems = <String>[];
      var where = 'start';
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final first = d.exceptionAsString().split('\n').first;
        // Where in lib/ the failing widget was made.
        final made = RegExp(
          r'handy_boards/lib/[^ )]+\.dart:\d+',
        ).firstMatch(d.toString())?.group(0);
        problems.add('$where: $first${made == null ? '' : ' ($made)'}');
        if (const bool.fromEnvironment('SWEEP_DETAIL')) {
          debugPrint('---- $where\n$d');
        }
      };
      try {
        await _sweep(t, shape, (w) => where = w, problems);
      } finally {
        FlutterError.onError = previous;
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}

Future<void> _sweep(
  WidgetTester t,
  Shape shape,
  void Function(String) at,
  List<String> problems,
) async {
  t.view.physicalSize = shape.size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = shape.text;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

  // First run: the welcome, both branches' first steps.
  at('welcome');
  final fresh = BoardsController(
    open: () async => TestStore(BoardsState(preferences: {'locale': 'vi'})),
  );
  await t.runAsync(fresh.load);
  await t.pumpWidget(BoardsApp(controller: fresh, clock: () => clock));
  await settle(t);
  for (final key in ['welcome-primary', 'welcome-purpose-work']) {
    await _tapIf(t, key);
  }
  await _tapIf(t, 'welcome-primary');
  at('welcome practice');
  await settle(t);
  await t.pumpWidget(const SizedBox());

  // The study board, in Vietnamese (the longer words).
  final s = studyState();
  final c = BoardsController(
    open: () async => TestStore(
      s.copy(preferences: {...s.preferences, 'locale': 'vi'}),
    ),
  );
  await t.runAsync(c.load);
  await t.pumpWidget(BoardsApp(controller: c, clock: () => clock));
  await settle(t);
  at('home');
  await _tapIf(t, 'home-new');
  at('new board sheet');
  await _tapIf(t, 'new-blank');
  at('blank board sheet');
  await _back(t);
  await _back(t);

  NavigatorState nav() =>
      Navigator.of(t.element(find.byType(Scaffold).first));

  for (final route in [
    '/templates',
    '/settings',
    '/how-to',
    '/pro',
    '/search',
    '/trash',
    '/insights',
    '/export',
  ]) {
    at(route);
    nav().pushNamed(
      route,
      arguments: route == '/insights' || route == '/export' ? board : null,
    );
    await settle(t);
    await _scrollThrough(t);
    nav().pop();
    await settle(t);
  }

  at('template preview');
  nav().pushNamed('/templates');
  await settle(t);
  await _tapIf(t, 'template-semester');
  _boardRoom(t, shape, problems, 'template preview');
  await _previewScroll(t, problems, 'template preview');
  await _tapIf(t, 'template-use');
  at('template setup');
  await _scrollThrough(t);
  await _tapIf(t, 'setup-preview');
  at('plan preview');
  await settle(t);
  _boardRoom(t, shape, problems, 'plan preview');
  await _previewScroll(t, problems, 'plan preview');
  nav().popUntil((r) => r.isFirst);
  await settle(t);

  at('board');
  nav().pushNamed('/board/$board');
  await settle(t);
  _boardRoom(t, shape, problems, 'board');
  // The header scrolls away on a short screen and the board stays usable.
  final scroller = find.byKey(const Key('board-scroll'));
  if (scroller.evaluate().isNotEmpty) {
    await t.drag(scroller, const Offset(0, -600));
    await settle(t);
    _boardRoom(t, shape, problems, 'board scrolled');
    // A swipe down inside a column at its top brings the header back.
    final pageScroll = t.state<ScrollableState>(
      find
          .descendant(of: scroller, matching: find.byType(Scrollable))
          .first,
    );
    if (pageScroll.position.pixels == 0) {
      problems.add('board: the header does not scroll away');
    }
    final column = find.byWidgetPredicate(
      (w) =>
          w.key is PageStorageKey &&
          '${(w.key as PageStorageKey).value}'.startsWith('column-'),
    );
    await t.drag(column.first, const Offset(0, 900), warnIfMissed: false);
    await settle(t);
    if (pageScroll.position.pixels > 0) {
      problems.add('board: a column swipe does not bring the header back');
    }
  }
  at('board search');
  await _tapIf(t, 'board-search');
  await _tapIf(t, 'board-search');
  at('board categories hidden');
  await _tapIf(t, 'board-categories');
  await _tapIf(t, 'board-categories');
  at('board menu');
  await _tapIf(t, 'board-more');
  await _scrollThrough(t, sheet: true);
  await _back(t);
  at('card');
  final card = topTasks(c.state!, board: board).first;
  final title = find.text(card.str('title'));
  if (title.evaluate().isNotEmpty) {
    await t.ensureVisible(title.first);
    await settle(t);
    await t.tap(title.first);
    await settle(t);
    await _scrollThrough(t, sheet: true);
    await _back(t);
  }
  at('add card field');
  final add = find.byWidgetPredicate(
    (w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith(
      'add-card-open-',
    ),
  );
  if (add.evaluate().isNotEmpty) {
    await t.ensureVisible(add.first);
    await settle(t);
    await t.tap(add.first);
    await settle(t);
    await t.tapAt(Offset.zero);
    await settle(t);
  }
  at('time view');
  var toggle = find.byKey(const Key('board-view-toggle'));
  if (toggle.evaluate().isEmpty) toggle = find.text('Thời gian');
  await t.ensureVisible(toggle.first);
  await settle(t);
  await t.tap(toggle.first);
  await settle(t);
  _boardRoom(t, shape, problems, 'time view');
  await t.pumpWidget(const SizedBox());
}

/// On a short screen the preview scrolls its header away and a swipe in
/// a column brings it back.
Future<void> _previewScroll(
  WidgetTester t,
  List<String> problems,
  String where,
) async {
  final scroller = find.byKey(const Key('preview-scroll'));
  if (scroller.evaluate().isEmpty) return;
  final pos = t.state<ScrollableState>(
    find.descendant(of: scroller, matching: find.byType(Scrollable)).first,
  ).position;
  await t.drag(scroller, const Offset(0, -600), warnIfMissed: false);
  await settle(t);
  if (pos.maxScrollExtent > 0 && pos.pixels == 0) {
    problems.add('$where: the header does not scroll away');
  }
  final column = find.byWidgetPredicate(
    (w) =>
        w.key is PageStorageKey &&
        '${(w.key as PageStorageKey).value}'.startsWith('column-'),
  );
  if (column.evaluate().isNotEmpty) {
    await t.drag(column.first, const Offset(0, 900), warnIfMissed: false);
    await settle(t);
    if (pos.pixels > 0) {
      problems.add('$where: a column swipe does not bring the header back');
    }
  }
}

/// The board under the header must have room for cards: at least 300 pt,
/// or the whole screen less its bars.
void _boardRoom(
  WidgetTester t,
  Shape shape,
  List<String> problems,
  String where,
) {
  for (final key in ['kanban-pages', 'kanban-wide']) {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) continue;
    final h = t.getSize(f).height;
    final need = (shape.size.height - 120).clamp(0, 300);
    if (h < need) problems.add('$where: board is only ${h.round()} pt tall');
  }
}

Future<void> _tapIf(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) return;
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first, warnIfMissed: false);
  await settle(t);
}

/// Closes the sheet or dialog on top, never the page under it.
Future<void> _back(WidgetTester t) async {
  final open =
      find.byType(BottomSheet).evaluate().isNotEmpty ||
      find.byType(Dialog).evaluate().isNotEmpty;
  if (!open) return;
  await t.binding.handlePopRoute();
  await settle(t);
}

/// Scrolls the page (or the open sheet) to its end and back, so every
/// part of it is laid out at least once.
Future<void> _scrollThrough(WidgetTester t, {bool sheet = false}) async {
  final scope = sheet ? find.byType(BottomSheet) : find.byType(Scaffold).last;
  final s = find.descendant(
    of: scope,
    matching: find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    ),
  );
  if (s.evaluate().isEmpty) return;
  for (var i = 0; i < 6; i++) {
    await t.drag(s.first, const Offset(0, -500), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}
