import 'dart:async';
// Review shots of the Kanban rebuild, rendered with the real fonts:
//   SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/app.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/kanban_app_test.dart' show TestStore;

final boundary = GlobalKey();
final clock = DateTime(2026, 11, 7, 9);
const board = 'b0000000-0000-4000-8000-000000000001';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pumpAndSettle();
  }
}

Future<void> shot(WidgetTester t, String name, {bool still = true}) async {
  if (still) await settle(t);
  final error = t.takeException();
  if (error is FlutterError) debugPrint(error.toStringDeep());
  expect(error, isNull, reason: name);
  await t.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final im = await render.toImage(pixelRatio: 1.5);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/shots')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    im.dispose();
  });
}

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths)
    loader.addFont(
      Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
    );
  await loader.load();
}

BoardsState sample({String locale = 'vi', String theme = 'light'}) {
  final vi = locale == 'vi';
  BoardsState make(
    BoardsState s,
    String id,
    String title, {
    String? boardId,
    int daysAgo = 0,
    Map<String, Object?> answers = const {},
  }) => createFromTemplate(
    s,
    templateById(id)!,
    vi: vi,
    examples: true,
    answers: {'title': title, ...answers},
    now: clock.subtract(Duration(days: daysAgo)),
    boardId: boardId,
  );
  var s = make(
    BoardsState(
      preferences: {'locale': locale, 'theme': theme, 'welcomed': true},
    ),
    'semester',
    vi ? 'Học kỳ 1' : 'Semester 1',
    boardId: board,
    answers: {'end': '2027-01-15'},
  );
  // A few more real-looking cards on the study board.
  final b = board;
  final cats = categoriesOf(s, b);
  final first = columnsOf(s, b).first.id;
  for (final (i, (en, viTitle, cat, due)) in [
    ('Group report: chapter 2', 'Báo cáo nhóm: chương 2', 1, 4),
    ('Speaking practice', 'Luyện nói 15 phút', 2, 1),
    ('Exercises 3.1 to 3.6', 'Bài tập 3.1 đến 3.6', 3, 2),
  ].indexed) {
    final card = newTask(
      s,
      b,
      vi ? viTitle : en,
      category: cats[cat].id,
    ).copy({'status': first, 'order': 10 + i});
    s = saveTask(s, card, now: clock);
    s = setDueDay(s, card.id, clock.add(Duration(days: due)));
  }
  s = make(
    s,
    'personal',
    vi ? 'Việc nhà tháng 11' : 'Home in November',
    daysAgo: 1,
  );
  s = make(s, 'project', vi ? 'Ra mắt website' : 'Website launch', daysAgo: 3);
  return s;
}

Future<BoardsController> boot(
  WidgetTester t,
  BoardsState s, {
  Size size = const Size(390, 844),
  double text = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final c = BoardsController(open: () async => TestStore(s));
  await t.runAsync(c.load);
  await t.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: BoardsApp(controller: c, clock: () => clock),
    ),
  );
  await settle(t);
  return c;
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await settle(t);
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
    const root = '../../packages/handy_ui/fonts';
    await loadFont('packages/handy_ui/Geist', [
      '$root/Geist-Regular.ttf',
      '$root/Geist-Medium.ttf',
      '$root/Geist-Bold.ttf',
    ]);
    await loadFont('PlusJakartaSans', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    final flutter =
        Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/Winka/flutter';
    await loadFont('MaterialIcons', [
      '$flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  testWidgets('welcome, study branch', (t) async {
    await boot(t, BoardsState(preferences: {'locale': 'vi'}));
    await shot(t, '01-welcome-purpose');
    await tap(t, find.byKey(const Key('welcome-purpose-study')));
    await shot(t, '01a-welcome-purpose-picked');
    await tap(t, find.byKey(const Key('welcome-primary')));
    await shot(t, '02-welcome-practice-add');
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await shot(t, '02a-welcome-practice-drag');
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await shot(t, '02b-welcome-practice-focus');
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await shot(t, '02c-welcome-practice-tick');
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await shot(t, '02d-welcome-done');
    await tap(t, find.byKey(const Key('welcome-primary')));
    await shot(t, '03-welcome-start-study');
  });

  testWidgets('welcome, work branch', (t) async {
    await boot(t, BoardsState(preferences: {'locale': 'vi'}));
    await tap(t, find.byKey(const Key('welcome-purpose-work')));
    await tap(t, find.byKey(const Key('welcome-primary')));
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await shot(t, '03a-welcome-work-focused');
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await tap(t, find.byKey(const Key('welcome-primary')));
    await shot(t, '03b-welcome-start-work');
  });

  testWidgets('welcome wide', (t) async {
    await boot(
      t,
      BoardsState(preferences: {'locale': 'vi'}),
      size: const Size(1280, 800),
    );
    await tap(t, find.byKey(const Key('welcome-purpose-study')));
    await tap(t, find.byKey(const Key('welcome-primary')));
    await shot(t, '03e-welcome-practice-wide');
  });

  testWidgets('phone journey', (t) async {
    final c = await boot(t, sample());
    await shot(t, '04-home');
    await tap(t, find.byKey(const Key('board-$board')));
    await shot(t, '05-board');

    final card = topTasks(
      c.state!,
      board: board,
    ).firstWhere((x) => subtaskProgress(c.state!, x.id).total > 2);
    await tap(t, find.byKey(ValueKey('card-${card.id}')));
    await shot(t, '07-card');
    final chip = find.byKey(const Key('card-cover'));
    await tap(
      t,
      chip.evaluate().isNotEmpty
          ? chip
          : find.byKey(const Key('card-cover-art')),
    );
    await shot(t, '08-cover-picker');
  });

  testWidgets('templates', (t) async {
    await boot(t, sample(), size: const Size(390, 1800));
    await tap(t, find.byKey(const Key('home-new')));
    await shot(t, '09-new-board');
    await tap(t, find.byKey(const Key('new-template')));
    await shot(t, '10-template-gallery');
    await tap(t, find.byKey(const Key('group-study')));
    await shot(t, '10a-gallery-study');
  });

  testWidgets('template preview, setup and the board it makes', (t) async {
    await boot(t, sample());
    await tap(t, find.byKey(const Key('home-new')));
    await tap(t, find.byKey(const Key('new-template')));
    await tap(t, find.byKey(const Key('template-semester')));
    await shot(t, '11-template-preview');
    await tap(t, find.byKey(const Key('template-use')));
    await shot(t, '11a-setup-semester');
    await tap(t, find.byKey(const Key('setup-preview')));
    await shot(t, '11b-plan-preview');
  });

  testWidgets('a Pro template, previewed free', (t) async {
    await boot(t, sample(), size: const Size(390, 1000));
    await tap(t, find.byKey(const Key('home-new')));
    await tap(t, find.byKey(const Key('new-template')));
    await t.enterText(find.byKey(const Key('gallery-search')), 'chuyển nhà');
    await settle(t);
    await shot(t, '11c-gallery-search');
    await t.enterText(find.byKey(const Key('gallery-search')), 'sự kiện');
    await settle(t);
    await tap(t, find.byKey(const Key('template-event')));
    await shot(t, '11d-preview-pro');
    await tap(t, find.byKey(const Key('template-use')));
    await shot(t, '11e-setup-event');
  });

  testWidgets('blank board', (t) async {
    await boot(t, sample());
    await tap(t, find.byKey(const Key('home-new')));
    await tap(t, find.byKey(const Key('new-blank')));
    await tap(t, find.byKey(const Key('blank-columns')));
    await shot(t, '11f-blank');
  });

  testWidgets('category focus and the explicit filter', (t) async {
    final c = await boot(t, sample());
    await tap(t, find.byKey(const Key('board-$board')));
    final cat = categoriesOf(c.state!, board)[1];
    await tap(t, find.byKey(Key('strip-${cat.id}')));
    await shot(t, '06-board-focus');
    await tap(t, find.byKey(const Key('focus-only')));
    await shot(t, '06a-board-only');
  });

  testWidgets('settings and pro', (t) async {
    await boot(t, sample());
    await tap(t, find.byKey(const Key('home-settings')));
    await shot(t, '12-settings');
    await tap(t, find.byKey(const Key('settings-pro')));
    await shot(t, '13-pro');
    await t.scrollUntilVisible(
      find.byKey(const Key('pro-part-automation')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('pro-page')),
        matching: find.byType(Scrollable),
      ),
    );
    await tap(t, find.byKey(const Key('pro-part-automation')));
    await shot(t, '13c-pro-automation-end');
  });

  testWidgets('pro, opened from a part', (t) async {
    await boot(t, sample());
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.pushNamed('/pro', arguments: ProFeature.automation));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 1500));
    await shot(t, '13b-pro-gate-moving', still: false);
    await shot(t, '13d-pro-gate-end');
  });

  testWidgets('pro, whole page and widths', (t) async {
    await boot(t, sample(), size: const Size(390, 3400));
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.pushNamed('/pro'));
    await shot(t, '13a-pro-whole');
  });

  testWidgets('pro, small and dark', (t) async {
    await boot(t, sample(theme: 'dark'), size: const Size(320, 640));
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.pushNamed('/pro', arguments: ProFeature.looks));
    await shot(t, '13e-pro-small-dark');
  });

  testWidgets('pro, desktop', (t) async {
    await boot(t, sample(locale: 'en'), size: const Size(1280, 800));
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.pushNamed('/pro', arguments: ProFeature.export));
    await shot(t, '13f-pro-desktop');
  });

  testWidgets('settings, whole', (t) async {
    await boot(t, sample(), size: const Size(390, 2600));
    await tap(t, find.byKey(const Key('home-settings')));
    await shot(t, '12a-settings-whole');
  });

  testWidgets('how to use', (t) async {
    await boot(t, sample(), size: const Size(390, 1500));
    await tap(t, find.byKey(const Key('home-settings')));
    await t.scrollUntilVisible(
      find.byKey(const Key('settings-howto')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(t, find.byKey(const Key('settings-howto')));
    await shot(t, '26-howto');
    for (final topic in ['cards', 'categories', 'details', 'time', 'look']) {
      await tap(t, find.byKey(Key('howto-topic-$topic')));
      await shot(t, '27-howto-$topic');
      await tap(t, find.byKey(const Key('howto-done')));
    }
  });

  testWidgets('how to use, dark, 320 px, text x2', (t) async {
    await boot(t, sample(theme: 'dark'), size: const Size(320, 1400), text: 2);
    await tap(t, find.byKey(const Key('home-settings')));
    await t.scrollUntilVisible(
      find.byKey(const Key('settings-howto')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(t, find.byKey(const Key('settings-howto')));
    await tap(t, find.byKey(const Key('howto-topic-cards')));
    await shot(t, '28-howto-small-dark');
  });

  testWidgets('desktop light and dark', (t) async {
    await boot(t, sample(locale: 'en'), size: const Size(1280, 800));
    await shot(t, '14-desktop-home');
    await tap(t, find.byKey(const Key('board-$board')));
    await shot(t, '15-desktop-board');
  });

  testWidgets('desktop dark', (t) async {
    await boot(
      t,
      sample(locale: 'en', theme: 'dark'),
      size: const Size(1280, 800),
    );
    await tap(t, find.byKey(const Key('board-$board')));
    await shot(t, '16-desktop-board-dark');
  });

  testWidgets('320 px, Vietnamese, text x2', (t) async {
    await boot(t, sample(), size: const Size(320, 700), text: 2);
    await shot(t, '17-small-home');
    await tap(t, find.byKey(const Key('board-$board')));
    await shot(t, '18-small-board');
  });

  testWidgets('looks and exports', (t) async {
    await boot(t, sample());
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await t.scrollUntilVisible(
      find.byKey(const Key('menu-board-look')),
      120,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tap(t, find.byKey(const Key('menu-board-look')));
    await t.scrollUntilVisible(
      find.byKey(const Key('look-blueprint')),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('look-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tap(t, find.byKey(const Key('look-blueprint')));
    await shot(t, '19-look-picker');
  });

  testWidgets('export styles', (t) async {
    await boot(t, sample(locale: 'en'), size: const Size(1280, 900));
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await t.scrollUntilVisible(
      find.byKey(const Key('menu-export')),
      120,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tap(t, find.byKey(const Key('menu-export')));
    await shot(t, '20-export-plain');
    await tap(t, find.byKey(const Key('export-style-poster')));
    await shot(t, '21-export-poster');
    await tap(t, find.byKey(const Key('export-style-print')));
    await shot(t, '22-export-print');
  });

  testWidgets('time view', (t) async {
    await boot(t, sample());
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.text('Thời gian'));
    await shot(t, '23-time-phone');
  });

  testWidgets('time view wide', (t) async {
    await boot(t, sample(locale: 'en'), size: const Size(1280, 800));
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.text('Time'));
    await shot(t, '24-time-wide');
    await tap(t, find.byKey(const Key('time-span')));
    await tap(t, find.byKey(const Key('span-month-1')));
    await shot(t, '25-time-month');
  });

  testWidgets('menus, categories, search, trash, insights', (t) async {
    var s = sample();
    final gone = topTasks(s, board: board).last;
    s = s.put('tasks', gone.copy({'trashed': true}));
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await shot(t, '29-board-menu');
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    await tap(t, find.byKey(const Key('strip-edit')));
    await shot(t, '30-categories-edit');
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    final card = topTasks(c.state!, board: board).first;
    await tap(t, find.byKey(ValueKey('card-${card.id}')));
    await tap(t, find.byKey(const Key('card-more')));
    await shot(t, '31-card-menu');
    await tap(t, find.byKey(const Key('menu-move-card')));
    await shot(t, '32-move-to');
  });

  testWidgets('search every board', (t) async {
    await boot(t, sample());
    await tap(t, find.byKey(const Key('home-search')));
    await t.enterText(find.byType(TextField).first, 'Ôn');
    await shot(t, '33-search');
  });

  testWidgets('trash', (t) async {
    var s = sample();
    final gone = topTasks(s, board: board).last;
    s = s.put('tasks', gone.copy({'trashed': true}));
    await boot(t, s, size: const Size(390, 2600));
    await tap(t, find.byKey(const Key('home-settings')));
    await tap(t, find.byKey(const Key('settings-trash')));
    await shot(t, '34-trash');
  });

  testWidgets('insights (Pro)', (t) async {
    // ignore: invalid_use_of_visible_for_testing_member
    debugProOverride = true;
    // ignore: invalid_use_of_visible_for_testing_member
    addTearDown(() => debugProOverride = null);
    await boot(t, sample());
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await tap(t, find.text('Thống kê bảng'));
    await shot(t, '35-insights');
  });
}
