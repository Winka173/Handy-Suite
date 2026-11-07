// Review shots of the Kanban rebuild, rendered with the real fonts:
//   SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/app.dart';
import 'package:handy_boards/controller.dart';
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

Future<void> shot(WidgetTester t, String name) async {
  await settle(t);
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
  var s = createKanbanBoard(
    BoardsState(
      preferences: {'locale': locale, 'theme': theme, 'welcomed': true},
    ),
    title: vi ? 'Học kỳ 1' : 'Semester 1',
    preset: presetById('study'),
    vi: vi,
    now: clock,
    boardId: board,
  );
  s = createKanbanBoard(
    s,
    title: vi ? 'Việc nhà tháng 11' : 'Home in November',
    preset: presetById('personal'),
    vi: vi,
    now: clock.subtract(const Duration(days: 1)),
  );
  s = createKanbanBoard(
    s,
    title: vi ? 'Ra mắt website' : 'Website launch',
    preset: presetById('project'),
    vi: vi,
    now: clock.subtract(const Duration(days: 3)),
  );
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

  testWidgets('welcome', (t) async {
    await boot(t, BoardsState(preferences: {'locale': 'vi'}));
    await shot(t, '01-welcome-scattered');
    await tap(t, find.byKey(const Key('welcome-primary')));
    await shot(t, '02-welcome-board');
    await tap(t, find.byKey(const Key('welcome-primary')));
    await shot(t, '03-welcome-practice-add');
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await shot(t, '03a-welcome-practice-drag');
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await shot(t, '03b-welcome-tick');
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await tap(t, find.byKey(const Key('welcome-do-it')));
    await shot(t, '03c-welcome-done');
    await tap(t, find.byKey(const Key('welcome-primary')));
    await shot(t, '03d-welcome-start');
  });

  testWidgets('welcome wide', (t) async {
    await boot(
      t,
      BoardsState(preferences: {'locale': 'vi'}),
      size: const Size(1280, 800),
    );
    await tap(t, find.byKey(const Key('welcome-primary')));
    await tap(t, find.byKey(const Key('welcome-primary')));
    await shot(t, '03e-welcome-practice-wide');
  });

  testWidgets('phone journey', (t) async {
    final c = await boot(t, sample());
    await shot(t, '04-home');
    await tap(t, find.byKey(const Key('board-$board')));
    await shot(t, '05-board');
    final maths = categoriesOf(c.state!, board).first;
    await tap(t, find.byKey(Key('strip-${maths.id}')));
    await shot(t, '06-board-filtered');
    await tap(t, find.byKey(Key('strip-${maths.id}')));
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
    await boot(t, sample());
    await tap(t, find.byKey(const Key('home-new')));
    await shot(t, '09-new-board');
    await tap(t, find.byKey(const Key('new-template')));
    await shot(t, '10-template-gallery');
    await tap(t, find.byKey(const Key('shelf-work')));
    await tap(t, find.byKey(const Key('template-content')));
    await shot(t, '11-template-preview-pro');
  });

  testWidgets('settings and pro', (t) async {
    await boot(t, sample());
    await tap(t, find.byKey(const Key('home-settings')));
    await shot(t, '12-settings');
    await tap(t, find.byKey(const Key('settings-pro')));
    await shot(t, '13-pro');
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
    await tap(t, find.byKey(const Key('menu-board-look')));
    await tap(t, find.byKey(const Key('look-blueprint')));
    await shot(t, '19-look-picker');
  });

  testWidgets('export styles', (t) async {
    await boot(t, sample(locale: 'en'), size: const Size(1280, 900));
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await tap(t, find.byKey(const Key('menu-export')));
    await shot(t, '20-export-plain');
    await tap(t, find.byKey(const Key('export-style-poster')));
    await shot(t, '21-export-poster');
    await tap(t, find.byKey(const Key('export-style-print')));
    await shot(t, '22-export-print');
  });
}
