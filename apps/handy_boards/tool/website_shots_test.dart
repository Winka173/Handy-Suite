// Website kit: every feature as a marketing still, in Vietnamese and
// English, light and dark, phone (390×844 @3x), tablet (834×1194 @2x) and
// desktop (1440×900 @2x), plus frame sequences for short clips. Real fonts
// and lived-in sample boards (no lorem ipsum). Nothing here touches lib/.
//
// KIT_DIR=<dir> [KIT_LANGS=vi,en] \
//   flutter test --no-pub --timeout 300s tool/website_shots_test.dart
import 'dart:async';
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

final _out = Platform.environment['KIT_DIR'] ?? 'build/website-kit';
final _langs = (Platform.environment['KIT_LANGS'] ?? 'vi,en').split(',');
final _only = Platform.environment['KIT_ONLY'];
final _root = GlobalKey();

/// A Wednesday morning, so the week has days behind and ahead.
final clock = DateTime(2026, 11, 11, 9);
const study = 'b0000000-0000-4000-8000-000000000001';
const trip = 'b0000000-0000-4000-8000-000000000002';
const home = 'b0000000-0000-4000-8000-000000000003';
const launch = 'b0000000-0000-4000-8000-000000000004';
const sprint = 'b0000000-0000-4000-8000-000000000005';

/// Where a simulated finger is, drawn into clip frames so a viewer sees
/// what was tapped. Never drawn in stills.
final _touch = ValueNotifier<Offset?>(null);

Widget _touchable(Widget child) => Stack(
  textDirection: TextDirection.ltr,
  fit: StackFit.expand,
  children: [
    child,
    IgnorePointer(
      child: ValueListenableBuilder<Offset?>(
        valueListenable: _touch,
        builder: (_, at, _) => at == null
            ? const SizedBox.shrink()
            : CustomPaint(painter: _Finger(at)),
      ),
    ),
  ],
);

class _Finger extends CustomPainter {
  final Offset at;
  const _Finger(this.at);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      at + const Offset(0, 2),
      24,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(at, 22, Paint()..color = const Color(0x8CFFFFFF));
    canvas.drawCircle(
      at,
      22,
      Paint()
        ..color = const Color(0x8C231A21)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Finger old) => old.at != at;
}

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

/// The forms a scene is drawn in.
enum KitForm {
  mobile(Size(390, 844), 3, 'light'),
  mobileDark(Size(390, 844), 3, 'dark'),
  tablet(Size(834, 1194), 2, 'light'),
  desktop(Size(1440, 900), 2, 'light'),
  desktopDark(Size(1440, 900), 2, 'dark');

  final Size size;
  final double ratio;
  final String theme;
  const KitForm(this.size, this.ratio, this.theme);
  String get label => switch (this) {
    mobile => 'mobile',
    mobileDark => 'mobile-dark',
    tablet => 'tablet',
    desktop => 'desktop',
    desktopDark => 'desktop-dark',
  };
}

/// One scene in one language and form.
class Kit {
  final String lang;
  final KitForm form;
  final String name;
  Kit(this.lang, this.form, this.name);
  bool get vi => lang == 'vi';
  String t(String en, String vi) => this.vi ? vi : en;

  /// A visible tap on [f]: the finger lands, holds for [hold] frames
  /// (filmed as `<clip>`), then lifts and the tap goes through.
  Future<void> press(
    WidgetTester t,
    Finder f,
    String clip, {
    int hold = 9,
  }) async {
    await t.ensureVisible(f.first);
    await t.pump();
    final at = t.getCenter(f.first);
    _touch.value = at;
    final g = await t.startGesture(at);
    await film(t, clip, hold);
    await g.up();
    _touch.value = null;
  }

  /// `<form>-<lang>-<name>[-<suffix>].png`
  Future<void> shot(WidgetTester t, [String suffix = '']) async {
    await settle(t);
    if (Platform.environment['KIT_LOOSE'] != null) return;
    final error = t.takeException();
    if (error is FlutterError) debugPrint(error.toStringDeep());
    expect(error, isNull, reason: '$name $suffix');
    final file = '${form.label}-$lang-$name${suffix.isEmpty ? '' : '-$suffix'}';
    await _write(t, '$_out/$file.png', form.ratio);
  }

  /// A frame sequence for a clip, at 2x: `films/<form>-<lang>-<clip>/000.png`.
  Future<void> film(
    WidgetTester t,
    String clip,
    int frames, {
    Duration step = const Duration(milliseconds: 33),
  }) async {
    final dir = '$_out/films/${form.label}-$lang-$clip';
    Directory(dir).createSync(recursive: true);
    for (var i = 0; i < frames; i++) {
      await _write(t, '$dir/${i.toString().padLeft(3, '0')}.png', 2);
      await t.pump(step);
    }
  }
}

Future<void> _write(WidgetTester t, String path, double ratio) async {
  File(path).parent.createSync(recursive: true);
  await t.runAsync(() async {
    final b =
        _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pumpAndSettle();
  }
}

/// Five boards someone really keeps: a semester planned by week, a trip
/// with costs and bookings, home chores with repeating cards, a website
/// launch and a sprint.
BoardsState kitSample(String lang, String theme) {
  final vi = lang == 'vi';
  String t(String en, String v) => vi ? v : en;
  BoardsState make(
    BoardsState s,
    String id,
    String title,
    String boardId, {
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
  var s = BoardsState(
    preferences: {'locale': lang, 'theme': theme, 'welcomed': true},
  );
  s = make(s, 'sprint', t('Sprint 24', 'Sprint 24'), sprint, daysAgo: 12);
  s = make(
    s,
    'launch',
    t('Website launch', 'Ra mắt website'),
    launch,
    daysAgo: 9,
    answers: {'end': '2026-12-01'},
  );
  s = make(
    s,
    'personal',
    t('Home in November', 'Việc nhà tháng 11'),
    home,
    daysAgo: 6,
  );
  s = make(s, 'trip', t('Da Nang, 4 days', 'Đà Nẵng 4 ngày'), trip, daysAgo: 3);
  s = make(
    s,
    'semester',
    t('Semester 1', 'Học kỳ 1'),
    study,
    daysAgo: 1,
    answers: {'end': '2027-01-15'},
  );

  // The semester: a few more cards, then planned by week.
  final cats = categoriesOf(s, study);
  final first = columnsOf(s, study).first.id;
  for (final (i, (en, v, cat, due)) in [
    ('Group report: chapter 2', 'Báo cáo nhóm: chương 2', 1, 4),
    ('Speaking practice, 15 minutes', 'Luyện nói 15 phút', 2, 1),
    ('Exercises 3.1 to 3.6', 'Bài tập 3.1 đến 3.6', 3, 2),
    ('Read chapter 5 before class', 'Đọc chương 5 trước giờ học', 0, 0),
  ].indexed) {
    final card = newTask(
      s,
      study,
      t(en, v),
      category: cats[cat % cats.length].id,
    ).copy({'status': first, 'order': 10 + i});
    s = saveTask(s, card, now: clock);
    s = setDueDay(s, card.id, clock.add(Duration(days: due)));
  }
  if (boardTimeline(s.get('boards', study)) == null) {
    s = setTimeline(s, study, 'week', now: clock);
  }
  // One card left from last week, one planned for next week.
  final open = topTasks(s, board: study);
  s = s.put(
    'tasks',
    open.first.copy({
      'scheduled': isoDay(clock.subtract(const Duration(days: 7))),
    }),
  );
  final next = newTask(
    s,
    study,
    t('Mock test, unit 4', 'Kiểm tra thử bài 4'),
    category: cats.first.id,
  ).copy({'status': first, 'order': 30});
  s = saveTask(s, next, now: clock);
  s = s.put(
    'tasks',
    s.get('tasks', next.id).copy({
      'scheduled': isoDay(clock.add(const Duration(days: 6))),
    }),
  );

  // The trip: costs and bookings filled in.
  final fields = fieldsOf(s, trip);
  final cost = fields.where((f) => f.str('type') == 'number').firstOrNull;
  final booked = fields.where((f) => f.str('type') == 'checkbox').firstOrNull;
  for (final (i, c) in topTasks(s, board: trip).take(5).indexed) {
    if (cost != null) {
      s = setFieldValue(
        s,
        c.id,
        cost.id,
        ['1450000', '2600000', '380000', '900000', '250000'][i],
        now: clock,
      );
    }
    if (booked != null && i < 3) {
      s = setFieldValue(s, c.id, booked.id, true, now: clock);
    }
  }

  // Home: rent comes back every month, the bins every week.
  final homeFirst = columnsOf(s, home).first.id;
  for (final (i, (en, v, every, due)) in [
    ('Pay the rent', 'Đóng tiền nhà', 'monthly', 4),
    ('Take the bins out', 'Đổ rác', 'weekly', 1),
  ].indexed) {
    final card = newTask(
      s,
      home,
      t(en, v),
    ).copy({'status': homeFirst, 'order': 20 + i, 'repeat': every});
    s = saveTask(s, card, now: clock);
    s = setDueDay(s, card.id, clock.add(Duration(days: due)));
  }
  return s;
}

/// Starts the app on the sample boards (or [state]).
Future<BoardsController> boot(
  WidgetTester t,
  Kit k, {
  BoardsState? state,
  Size? size,
}) async {
  t.view.physicalSize = size ?? k.form.size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = BoardsController(
    open: () async => TestStore(state ?? kitSample(k.lang, k.form.theme)),
  );
  await t.runAsync(c.load);
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: _touchable(BoardsApp(controller: c, clock: () => clock)),
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

Future<void> tapKey(WidgetTester t, String key) => tap(t, find.byKey(Key(key)));

/// Scrolls the first scrollable under [within] (or the page) to [f].
Future<void> reach(WidgetTester t, Finder f, {Finder? within}) async {
  if (f.evaluate().isNotEmpty) return;
  await t.scrollUntilVisible(
    f,
    150,
    scrollable: within == null
        ? find.byType(Scrollable).first
        : find.descendant(of: within, matching: find.byType(Scrollable)).first,
  );
  await t.pumpAndSettle();
}

Future<void> openBoard(WidgetTester t, [String id = study]) =>
    tapKey(t, 'board-$id');

/// Opens the board menu and taps [key] in it.
Future<void> menu(WidgetTester t, String key) async {
  await tapKey(t, 'board-more');
  await reach(t, find.byKey(Key(key)), within: find.byType(BottomSheet));
  await tapKey(t, key);
}

Future<void> push(WidgetTester t, String route, {Object? arguments}) async {
  final nav = t.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(nav.pushNamed(route, arguments: arguments));
  await settle(t);
}

/// The system back, as a phone's back gesture would.
Future<void> back(WidgetTester t) async {
  final nav = t.state<NavigatorState>(find.byType(Navigator).last);
  unawaited(nav.maybePop());
  await t.pump();
}

Future<void> openSettings(WidgetTester t) => tapKey(t, 'home-settings');

/// The string keys with [prefix] that are on screen now.
List<String> keysOnScreen(WidgetTester t, String prefix) => [
  for (final e in find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith(prefix);
  }).evaluate())
    (e.widget.key! as ValueKey<String>).value,
];

/// The category tiles in the strip, in order.
List<String> stripTiles(WidgetTester t) => [
  for (final k in keysOnScreen(t, 'strip-'))
    if (!{'strip-edit', 'strip-add-category', 'strip-none'}.contains(k)) k,
];

/// The card on screen with the most subtasks.
BoardRecord shownCard(WidgetTester t, BoardsController c) {
  final ids = {
    for (final k in keysOnScreen(t, 'card-'))
      if (c.state!.maybe('tasks', k.substring(5)) != null) k.substring(5),
  };
  final cards = [for (final id in ids) c.state!.get('tasks', id)]
    ..sort(
      (a, b) => subtaskProgress(
        c.state!,
        b.id,
      ).total.compareTo(subtaskProgress(c.state!, a.id).total),
    );
  return cards.first;
}

Future<void> openCard(WidgetTester t, BoardRecord card) async {
  final f = find.byKey(ValueKey('card-${card.id}'));
  await reach(t, f);
  await tap(t, f);
}

void pro(bool on) {
  // ignore: invalid_use_of_visible_for_testing_member
  debugProOverride = on ? true : null;
}

/// Defines one scene for every language and the given forms.
void scene(
  String name,
  List<KitForm> forms,
  Future<void> Function(WidgetTester t, Kit k) body, {
  bool isPro = false,
}) {
  final only = _only;
  if (only != null && !name.startsWith(only)) return;
  for (final lang in _langs) {
    for (final form in forms) {
      testWidgets('$name ${form.label} $lang', (t) async {
        if (isPro) {
          pro(true);
          addTearDown(() => pro(false));
        }
        await body(t, Kit(lang, form, name));
      });
    }
  }
}

const _phone = [KitForm.mobile];
const _phones = [KitForm.mobile, KitForm.mobileDark];
const _all = [
  KitForm.mobile,
  KitForm.mobileDark,
  KitForm.desktop,
  KitForm.desktopDark,
];

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
    const root = '../../packages/handy_ui/fonts';
    await _font('packages/handy_ui/Geist', [
      '$root/Geist-Regular.ttf',
      '$root/Geist-Medium.ttf',
      '$root/Geist-Bold.ttf',
    ]);
    await _font('PlusJakartaSans', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    final flutter =
        Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/Winka/flutter';
    await _font('MaterialIcons', [
      '$flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  // ── Home and the board ────────────────────────────────────────────────
  scene('01-home', [..._all, KitForm.tablet], (t, k) async {
    await boot(t, k);
    await k.shot(t);
  });

  scene('02-board', [..._all, KitForm.tablet], (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await k.shot(t);
  });

  scene('02-board-trip', _all, (t, k) async {
    await boot(t, k);
    await openBoard(t, trip);
    await k.shot(t);
  });

  scene('02-board-home', _phone, (t, k) async {
    await boot(t, k);
    await openBoard(t, home);
    await k.shot(t);
  });

  scene('03-categories', [..._phones, KitForm.desktop], (t, k) async {
    await boot(t, k);
    await openBoard(t);
    final tiles = stripTiles(t);
    await tapKey(t, tiles[0]);
    await tapKey(t, tiles[1]);
    await k.shot(t, 'two');
  });

  // ── The timeline ──────────────────────────────────────────────────────
  scene('04-week', _phones, (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await tapKey(t, 'week-next');
    await k.shot(t, 'next');
    await tapKey(t, 'week-current');
    await tapKey(t, 'week-prev');
    await k.shot(t, 'past');
  });

  scene('04-timeline-sheet', _phones, (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await tapKey(t, 'board-timeline');
    await k.shot(t);
  });

  scene('04-past-card', _phone, (t, k) async {
    final c = await boot(t, k);
    await openBoard(t);
    await tapKey(t, 'week-prev');
    final open = openIn(
      c.state!,
      study,
      timelineWindow('week', clock.subtract(const Duration(days: 7))),
    );
    await openCard(t, open.first);
    await k.shot(t);
  });

  // ── Cards ─────────────────────────────────────────────────────────────
  scene('05-card', [..._phones, KitForm.desktop], (t, k) async {
    final c = await boot(t, k);
    await openBoard(t);
    await openCard(t, shownCard(t, c));
    await k.shot(t);
  });

  scene('05-card-fields', _phones, (t, k) async {
    final c = await boot(t, k);
    await openBoard(t, trip);
    await openCard(t, shownCard(t, c));
    await reach(t, find.byKey(const Key('card-fields-add')));
    await k.shot(t);
  });

  scene('05-card-repeat', _phone, (t, k) async {
    final c = await boot(t, k);
    await openBoard(t, home);
    final rent = topTasks(
      c.state!,
      board: home,
    ).firstWhere((x) => x.data['repeat'] == 'monthly');
    await openCard(t, rent);
    await reach(t, find.byKey(const Key('card-repeat')));
    await tapKey(t, 'card-repeat');
    await k.shot(t);
  }, isPro: true);

  scene('06-cover-picker', _phone, (t, k) async {
    final c = await boot(t, k);
    await openBoard(t);
    await openCard(t, shownCard(t, c));
    final chip = find.byKey(const Key('card-cover'));
    await tap(
      t,
      chip.evaluate().isNotEmpty
          ? chip
          : find.byKey(const Key('card-cover-art')),
    );
    await k.shot(t);
  });

  // ── New boards and templates ──────────────────────────────────────────
  scene('07-new-board', _phone, (t, k) async {
    await boot(t, k);
    await tapKey(t, 'home-new');
    await k.shot(t);
  });

  scene('08-templates', [..._phones, KitForm.desktop], (t, k) async {
    await boot(t, k);
    await push(t, '/templates');
    await k.shot(t);
    await tapKey(t, 'group-study');
    await k.shot(t, 'study');
  });

  scene('09-template', _phones, (t, k) async {
    await boot(t, k);
    await push(t, '/templates');
    await tapKey(t, 'template-semester');
    await k.shot(t, 'preview');
    await tapKey(t, 'template-use');
    await k.shot(t, 'setup');
    await tapKey(t, 'setup-preview');
    await k.shot(t, 'plan');
  });

  scene('09-template-trip', _phone, (t, k) async {
    await boot(t, k);
    await push(t, '/templates');
    await t.enterText(
      find.byKey(const Key('gallery-search')),
      k.t('trip', 'chuyến đi'),
    );
    await settle(t);
    await tapKey(t, 'template-trip');
    await k.shot(t, 'preview');
    await tapKey(t, 'template-use');
    await reach(t, find.byKey(const Key('setup-card-fields')));
    await k.shot(t, 'fields');
  });

  scene('10-blank', _phone, (t, k) async {
    await boot(t, k);
    await tapKey(t, 'home-new');
    await tapKey(t, 'new-blank');
    await k.shot(t);
  });

  // ── Menus, search, trash ──────────────────────────────────────────────
  scene('11-board-menu', _phones, (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await tapKey(t, 'board-more');
    await k.shot(t);
  });

  scene('11-categories-edit', _phone, (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await tapKey(t, 'strip-edit');
    await k.shot(t);
  });

  scene('11-move-to', _phone, (t, k) async {
    final c = await boot(t, k);
    await openBoard(t);
    await tapKey(t, 'card-menu-${shownCard(t, c).id}');
    await reach(
      t,
      find.byKey(const Key('menu-move-card')),
      within: find.byType(BottomSheet).last,
    );
    await tapKey(t, 'menu-move-card');
    await k.shot(t);
  });

  scene('12-search', [..._phones, KitForm.desktop], (t, k) async {
    await boot(t, k);
    await tapKey(t, 'home-search');
    await t.enterText(find.byType(TextField).first, k.t('report', 'báo cáo'));
    await k.shot(t);
  });

  scene('13-trash', _phone, (t, k) async {
    var s = kitSample(k.lang, k.form.theme);
    final gone = topTasks(s, board: home).last;
    s = s.put('tasks', gone.copy({'trashed': true}));
    await boot(t, k, state: s);
    await push(t, '/trash');
    await k.shot(t);
  });

  scene('14-key-dates', _phone, (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await menu(t, 'menu-key-dates');
    await k.shot(t);
  });

  // ── Pro ───────────────────────────────────────────────────────────────
  scene('20-my-work', _all, (t, k) async {
    await boot(t, k);
    await push(t, '/my-work');
    await k.shot(t);
  }, isPro: true);

  scene('21-rules', _phones, (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await menu(t, 'menu-rules');
    await k.shot(t);
    await tapKey(t, 'rule-example-0');
    await k.shot(t, 'editor');
  }, isPro: true);

  scene('22-saved-filters', _phone, (t, k) async {
    final c = await boot(t, k);
    final cats = categoriesOf(c.state!, study);
    await t.runAsync(
      () => c.change(
        (s) => saveFilter(s, study, k.t('Maths, due soon', 'Toán, sắp hạn'), [
          {'category': cats.first.id},
        ]),
      ),
    );
    await openBoard(t);
    await tapKey(t, 'board-filters');
    await k.shot(t);
  }, isPro: true);

  scene('23-card-templates', _phone, (t, k) async {
    final c = await boot(t, k);
    await t.runAsync(
      () => c.change(
        (s) => saveCardTemplate(
          s,
          title: k.t('Lab report', 'Báo cáo thí nghiệm'),
          checklist: [
            k.t('Collect the data', 'Thu số liệu'),
            k.t('Write the method', 'Viết phương pháp'),
            k.t('Draw the charts', 'Vẽ biểu đồ'),
          ],
          planIn: 3,
        ),
      ),
    );
    await openSettings(t);
    await reach(t, find.byKey(const Key('settings-card-templates')));
    await tapKey(t, 'settings-card-templates');
    await k.shot(t);
  }, isPro: true);

  scene('24-fields', _phone, (t, k) async {
    await boot(t, k);
    await openBoard(t, trip);
    await menu(t, 'menu-fields');
    await k.shot(t);
  }, isPro: true);

  scene('25-looks', _phones, (t, k) async {
    await boot(t, k);
    await openBoard(t);
    if (k.form.size.width < 600) await tapKey(t, 'board-categories');
    await menu(t, 'menu-board-look');
    await reach(
      t,
      find.byKey(const Key('look-blueprint')),
      within: find.byKey(const Key('look-list')),
    );
    await tapKey(t, 'look-blueprint');
    await k.shot(t);
  }, isPro: true);

  scene('26-insights', _phone, (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await menu(t, 'menu-insights');
    await k.shot(t);
  }, isPro: true);

  scene('27-history', _phone, (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await menu(t, 'menu-board-history');
    await k.shot(t);
  }, isPro: true);

  scene('28-export', [KitForm.mobile, KitForm.desktop], (t, k) async {
    await boot(t, k);
    await openBoard(t);
    await menu(t, 'menu-export');
    await k.shot(t, 'plain');
    for (final style in ['poster', 'print', 'report']) {
      await tapKey(t, 'export-style-$style');
      await k.shot(t, style);
    }
  }, isPro: true);

  scene('29-pro', [..._phones, KitForm.desktop], (t, k) async {
    await boot(t, k);
    await push(t, '/pro');
    await k.shot(t);
  });

  // ── Settings ──────────────────────────────────────────────────────────
  scene('30-settings', _phones, (t, k) async {
    await boot(t, k);
    await openSettings(t);
    await k.shot(t);
    for (var i = 1; i <= 3; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -620));
      await settle(t);
      await k.shot(t, '$i');
    }
  });

  scene('31-notifications', _phone, (t, k) async {
    await boot(t, k);
    await openSettings(t);
    await tapKey(t, 'settings-reminders');
    await k.shot(t);
  });

  scene('32-widgets', _phone, (t, k) async {
    await boot(t, k);
    await openSettings(t);
    await reach(t, find.byKey(const Key('settings-home-widget')));
    await tapKey(t, 'settings-home-widget');
    await k.shot(t);
  });

  scene('33-how-to', _phone, (t, k) async {
    await boot(t, k);
    await push(t, '/how-to');
    await k.shot(t);
    for (final topic in ['cards', 'categories', 'time']) {
      await tapKey(t, 'howto-topic-$topic');
      await k.shot(t, topic);
      await tapKey(t, 'howto-done');
    }
  });

  scene('34-empty', [KitForm.mobile, KitForm.desktop], (t, k) async {
    await boot(
      t,
      k,
      state: BoardsState(
        preferences: {
          'locale': k.lang,
          'theme': k.form.theme,
          'welcomed': true,
        },
      ),
    );
    await k.shot(t);
  });

  // ── Welcome ───────────────────────────────────────────────────────────
  scene('50-welcome', [KitForm.mobile, KitForm.desktop], (t, k) async {
    await boot(
      t,
      k,
      state: BoardsState(
        preferences: {'locale': k.lang, 'theme': k.form.theme},
      ),
    );
    await k.shot(t, '1');
    await tapKey(t, 'welcome-primary'); // gather
    await tapKey(t, 'welcome-primary');
    await k.shot(t, '2');
    for (var i = 3; i <= 6; i++) {
      await tapKey(t, 'welcome-do-it');
      await k.shot(t, '$i');
    }
    await tapKey(t, 'welcome-primary');
    await k.shot(t, '7');
  });

  // ── Clips: frame sequences, phone, light ─────────────────────────────
  for (final lang in _langs) {
    final only = _only;
    if (only != null && !'film'.startsWith(only)) break;
    final k = Kit(lang, KitForm.mobile, 'film');

    testWidgets('film welcome $lang', (t) async {
      await boot(
        t,
        k,
        state: BoardsState(preferences: {'locale': lang, 'theme': 'light'}),
      );
      await k.film(t, 'welcome-0', 30);
      await k.press(t, find.byKey(const Key('welcome-primary')), 'welcome-1');
      await k.film(t, 'welcome-2', 15);
      await k.press(t, find.byKey(const Key('welcome-primary')), 'welcome-3');
      await k.film(t, 'welcome-4', 45);
      for (var i = 0; i < 4; i++) {
        await k.press(
          t,
          find.byKey(const Key('welcome-do-it')),
          'welcome-${5 + i * 2}',
        );
        await k.film(t, 'welcome-${6 + i * 2}', 60);
      }
    });

    testWidgets('film template $lang', (t) async {
      await boot(t, k);
      await k.film(t, 'template-0', 20);
      await k.press(t, find.byKey(const Key('home-new')), 'template-1');
      await k.film(t, 'template-2', 20);
      await k.press(t, find.byKey(const Key('new-template')), 'template-3');
      await k.film(t, 'template-4', 25);
      await k.press(
        t,
        find.byKey(const Key('template-semester')),
        'template-5',
      );
      await k.film(t, 'template-6', 30);
      await k.press(t, find.byKey(const Key('template-use')), 'template-7');
      await k.film(t, 'template-8', 30);
      await k.press(t, find.byKey(const Key('setup-preview')), 'template-9');
      await k.film(t, 'template-a', 30);
      await k.press(t, find.byKey(const Key('plan-create')), 'template-b');
      await k.film(t, 'template-c', 45);
    });

    testWidgets('film categories $lang', (t) async {
      await boot(t, k);
      await openBoard(t);
      final tiles = stripTiles(t);
      await k.film(t, 'categories-0', 20);
      await k.press(t, find.byKey(Key(tiles[0])), 'categories-1');
      await k.film(t, 'categories-2', 25);
      await k.press(t, find.byKey(Key(tiles[1])), 'categories-3');
      await k.film(t, 'categories-4', 25);
      await k.film(t, 'categories-5', 10);
    });

    testWidgets('film timeline $lang', (t) async {
      await boot(t, k);
      await openBoard(t);
      await k.film(t, 'timeline-0', 20);
      await k.press(t, find.byKey(const Key('week-next')), 'timeline-1');
      await k.film(t, 'timeline-2', 30);
      await k.press(t, find.byKey(const Key('week-current')), 'timeline-3');
      await k.film(t, 'timeline-4', 15);
      await k.press(t, find.byKey(const Key('week-prev')), 'timeline-5');
      await k.film(t, 'timeline-6', 35);
      await k.press(t, find.byKey(const Key('carry-all')), 'timeline-7');
      await k.film(t, 'timeline-8', 45);
    });

    testWidgets('film card $lang', (t) async {
      final c = await boot(t, k);
      await openBoard(t);
      final card = shownCard(t, c);
      await k.film(t, 'card-0', 15);
      await k.press(t, find.byKey(ValueKey('card-${card.id}')), 'card-1');
      await k.film(t, 'card-2', 25);
      final boxes = find.byType(Checkbox);
      for (var i = 0; i < 2 && i < boxes.evaluate().length; i++) {
        await k.press(t, boxes.at(i), 'card-${3 + i * 2}');
        await k.film(t, 'card-${4 + i * 2}', 20);
      }
      await back(t);
      await k.film(t, 'card-9', 30);
    });

    testWidgets('film dark mode $lang', (t) async {
      await boot(t, k);
      await openSettings(t);
      await k.film(t, 'theme-0', 15);
      await k.press(t, find.byKey(const Key('settings-theme')), 'theme-1');
      await k.film(t, 'theme-2', 15);
      final dark = find.text(k.t('Dark', 'Tối'));
      await k.press(t, dark.last, 'theme-3');
      await k.film(t, 'theme-4', 25);
      await back(t);
      await k.film(t, 'theme-5', 30);
    });

    testWidgets('film pro $lang', (t) async {
      await boot(t, k);
      await push(t, '/pro', arguments: ProFeature.myWork);
      // Each part tapped plays its demo on the stage from the start.
      for (final (i, f) in [
        ProFeature.repeat,
        ProFeature.automation,
        ProFeature.looks,
      ].indexed) {
        final part = find.byKey(Key('pro-part-${f.name}'));
        await reach(t, part, within: find.byKey(const Key('pro-page')));
        await k.press(t, part, 'pro-${i * 2}');
        await k.film(t, 'pro-${i * 2 + 1}', 130);
      }
    });
  }
}
