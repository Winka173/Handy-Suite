// STORE_DIR=build/store flutter test --no-pub tool/store_shots_test.dart
// Host renders of real app screens with disposable sample data, not device QA.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/ui_test.dart' show MemoryStore, tapKey;

const today = '2026-11-02';
final now = DateTime.utc(2026, 11, 2, 8);
final root = GlobalKey();

Future<void> loadFonts() async {
  final nunito = FontLoader('Nunito');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    nunito.addFont(rootBundle.load('fonts/Nunito-$weight.ttf'));
  }
  await nunito.load();
  final icons = FontLoader('MaterialIcons');
  icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

HabitState sample(String locale) {
  final vi = locale == 'vi';
  const from = '2026-01-01';
  Habit positive(
    String id,
    String en,
    String vn,
    String type,
    int target,
    Color color,
    IconData icon,
    String unit,
  ) => Habit(
    id: id,
    title: vi ? vn : en,
    type: type,
    unit: unit,
    color: color.toARGB32(),
    icon: icon.codePoint,
    created: from,
    category: vi ? 'Mỗi ngày một chút' : 'A little every day',
    schedules: [Schedule(id: '$id-goal', from: from, target: target)],
  );
  final habits = [
    positive(
      'read',
      'Read ten pages',
      'Đọc mười trang',
      'quantity',
      10000,
      const Color(0xffa16207),
      Icons.menu_book_outlined,
      vi ? 'trang' : 'pages',
    ),
    positive(
      'water',
      'Drink water',
      'Uống nước',
      'count',
      8000,
      const Color(0xff2563eb),
      Icons.water_drop_outlined,
      '',
    ),
    positive(
      'walk',
      'Walk outside',
      'Đi bộ ngoài trời',
      'duration',
      20000,
      const Color(0xff4d7c0f),
      Icons.directions_walk,
      'min',
    ),
    Habit(
      id: 'reduce',
      title: vi ? 'Bớt nước ngọt' : 'Fewer sugary drinks',
      type: 'count',
      direction: 'reduce',
      created: from,
      schedules: [Schedule(id: 'reduce-schedule', from: from)],
      color: 0xff7c3f8c,
      icon: Icons.local_drink_outlined.codePoint,
      negativeGoals: [NegativeGoal(id: 'reduce-goal', from: from, limit: 1000)],
    ),
  ];
  final events = <HabitEvent>[];
  for (var i = 0; i <= date(today).difference(date(from)).inDays; i++) {
    final d = addDays(from, i);
    for (var h = 0; h < habits.length; h++) {
      if (h == 3) {
        if (i % 11 != 0)
          events.add(
            HabitEvent(
              id: 'reduce-$d',
              habit: 'reduce',
              day: d,
              value: i % 9 == 0 ? 2000 : 0,
            ),
          );
      } else if (d == today) {
        if (h < 2)
          events.add(
            HabitEvent(
              id: '${habits[h].id}-$d',
              habit: habits[h].id,
              day: d,
              value: h == 0 ? 10000 : 4000,
            ),
          );
      } else if ((i + h * 2) % 7 != 0 && (i + h) % 13 != 0) {
        events.add(
          HabitEvent(
            id: '${habits[h].id}-$d',
            habit: habits[h].id,
            day: d,
            value: habits[h].schedules.single.target,
          ),
        );
      }
    }
  }
  return HabitState(
    habits: habits,
    events: events,
    routines: [
      Routine(
        id: 'morning',
        title: vi ? 'Buổi sáng nhẹ nhàng' : 'An easy morning',
        steps: [
          RoutineStep(
            id: 'stretch',
            title: vi ? 'Giãn cơ nhẹ nhàng' : 'Stretch gently',
            seconds: 120,
          ),
          RoutineStep(
            id: 'drink',
            title: vi ? 'Uống một cốc nước' : 'Drink a glass of water',
            habit: 'water',
          ),
          RoutineStep(
            id: 'pages',
            title: vi ? 'Đọc vài trang sách' : 'Read a few pages',
            seconds: 600,
          ),
        ],
      ),
    ],
    settings: {
      'onboarded': true,
      'theme': 'light',
      'locale': locale,
      'zone': 'UTC',
      'showMoodToday': false,
      'routineAutoTimer': false,
    },
  );
}

Future<void> capture(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await t.pump(const Duration(milliseconds: 400));
  expect(t.takeException(), isNull);
  await t.runAsync(() async {
    final boundary =
        root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 3);
    expect(picture.width, 1080);
    expect(picture.height, 2160);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['STORE_DIR'] ?? 'build/store');
    dir.createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

void main() {
  setUpAll(loadFonts);
  for (final locale in ['en', 'vi']) {
    testWidgets('six store screenshots $locale', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        t.view.physicalSize = const Size(1080, 2160);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final disk = MemoryStore()..value = sample(locale);
        final c = HabitController(open: () async => disk, clock: () => now);
        await c.load();
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          c.dispose();
        });
        // The app is on screen, so the runner keeps running for its shot.
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpWidget(
          RepaintBoundary(
            key: root,
            child: HabitApp(controller: c, clock: () => now, device: false),
          ),
        );
        await t.pumpAndSettle();
        final nav = t.state<NavigatorState>(find.byType(Navigator).first);
        Future<void> open(String route) async {
          unawaited(nav.pushNamed(route));
          await t.pumpAndSettle();
        }

        Future<void> close() async {
          nav.pop();
          await t.pumpAndSettle();
        }

        // Let the mark image decode before the first shot.
        await t.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await t.pump();
        await capture(t, '$locale-01-today');
        await open('/habit/read');
        await capture(t, '$locale-02-history');
        await close();
        await open('/routine/morning');
        await tapKey(t, 'routine-start');
        // The sample's run waits paused: resume it.
        if (find
            .text(locale == 'vi' ? 'Tiếp tục' : 'Resume')
            .evaluate()
            .isNotEmpty)
          await tapKey(t, 'routine-pause');
        // A few real seconds so the step's clock shows it running.
        await t.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 7)),
        );
        await t.pump(const Duration(milliseconds: 300));
        await capture(t, '$locale-03-runner');
        // Leave via navigation so the runner retains its normal exit behavior.
        await open('/progress');
        await tapKey(t, 'range-year');
        await Scrollable.ensureVisible(
          t.element(
            find.text(
              locale == 'vi'
                  ? 'Một năm từng bước nhỏ'
                  : 'A year of small steps',
            ),
          ),
        );
        await capture(t, '$locale-04-year');
        await open('/templates');
        await capture(t, '$locale-05-templates');
        await open('/habit/reduce');
        await capture(t, '$locale-06-reduce');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
