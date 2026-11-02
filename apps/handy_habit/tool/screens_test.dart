// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/ui_test.dart' as fixtures;

final _root = GlobalKey();

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

Future<void> shot(WidgetTester t, String name, {bool settle = true}) async {
  final dir = Platform.environment['SHOTS_DIR'] ?? 'build/shots';
  Directory(dir).createSync(recursive: true);
  if (settle) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pump();
  }
  await t.runAsync(() async {
    final b =
        _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// Frames of a transition, for the review GIFs.
Future<void> film(
  WidgetTester t,
  String name,
  Future<void> Function() action, {
  int frames = 16,
  Duration step = const Duration(milliseconds: 25),
}) async {
  await action();
  for (var i = 0; i < frames; i++) {
    await shot(t, '$name-film-${i.toString().padLeft(3, '0')}', settle: false);
    await t.pump(step);
  }
  await t.pumpAndSettle();
}

/// Monday 2 November 2026, 07:30 in Hồ Chí Minh City.
final now = DateTime.utc(2026, 11, 2, 0, 30);
const today = '2026-11-02';

/// One person three weeks into a few habits and two routines.
HabitState practice() {
  final start = addDays(today, -24);
  Schedule sched(
    String kind, {
    int target = 1000,
    List<int>? days,
    int quota = 3,
  }) => Schedule(
    id: uid(),
    from: start,
    kind: kind,
    target: target,
    weekdays: days ?? const [1, 2, 3, 4, 5],
    weeklyTarget: quota,
  );
  final habits = [
    Habit(
      id: 'read',
      title: 'Đọc sách',
      created: start,
      type: 'quantity',
      unit: 'trang',
      category: 'Học tập',
      priority: 3,
      schedules: [sched('daily', target: 10000)],
    ),
    Habit(
      id: 'water',
      title: 'Uống nước',
      created: start,
      type: 'count',
      category: 'Sức khỏe',
      priority: 2,
      schedules: [sched('daily', target: 8000)],
    ),
    Habit(
      id: 'walk',
      title: 'Đi bộ sau bữa trưa',
      created: start,
      type: 'duration',
      unit: 'min',
      category: 'Sức khỏe',
      schedules: [sched('daily', target: 30000)],
    ),
    Habit(
      id: 'meditate',
      title: 'Thiền 10 phút',
      created: start,
      category: 'Sức khỏe',
      priority: 4,
      schedules: [sched('weekdays')],
    ),
    Habit(
      id: 'gym',
      title: 'Tập gym',
      created: start,
      category: 'Sức khỏe',
      schedules: [sched('weekly', quota: 3)],
    ),
    Habit(
      id: 'english',
      title: 'Học từ vựng tiếng Anh',
      created: start,
      type: 'count',
      unit: '',
      category: 'Học tập',
      schedules: [
        sched('weekdays', target: 20000, days: const [1, 3, 5]),
      ],
    ),
  ];
  final events = <HabitEvent>[];
  var n = 0;
  void log(
    String habit,
    String d,
    int value, {
    bool skipped = false,
    String note = '',
  }) => events.add(
    HabitEvent(
      id: 'e${n++}',
      habit: habit,
      day: d,
      value: value,
      skipped: skipped,
      note: note,
    ),
  );
  for (var i = 24; i >= 1; i--) {
    final d = addDays(today, -i), wd = date(d).weekday;
    if (i % 5 != 0) log('read', d, i % 4 == 0 ? 6000 : 12000);
    log('water', d, (i % 3 == 0 ? 5 : 8) * 1000);
    if (wd <= 5 && i % 6 != 0) log('walk', d, i % 4 == 0 ? 15000 : 30000);
    if (wd <= 5)
      i == 9
          ? log('meditate', d, 0, skipped: true, note: 'Ốm')
          : (i % 7 != 3 ? log('meditate', d, 1000) : null);
    if (wd == 1 || wd == 3 || wd == 6) log('gym', d, 1000);
    if ({1, 3, 5}.contains(wd) && i % 2 == 1) log('english', d, 20000);
  }
  log('water', today, 3000);
  log('meditate', today, 1000);
  RoutineStep step(
    String title,
    int minutes, {
    int? shortest,
    bool required = true,
    String? habit,
    int value = 1000,
    int priority = 1,
  }) => RoutineStep(
    id: uid(),
    title: title,
    seconds: minutes * 60,
    minimum: (shortest ?? minutes) * 60,
    required: required,
    habit: habit,
    linkedValue: value,
    priority: priority,
  );
  final morning = Routine(
    id: 'morning',
    title: 'Buổi sáng',
    time: '06:30',
    weekdays: const [1, 2, 3, 4, 5],
    steps: [
      step('Uống một ly nước', 1, habit: 'water', value: 1000, priority: 5),
      step('Giãn cơ', 8, shortest: 3, priority: 2),
      step('Thiền', 10, shortest: 5, habit: 'meditate', priority: 4),
      step('Viết ba việc chính hôm nay', 5, shortest: 2, priority: 3),
      step(
        'Đọc vài trang',
        15,
        required: false,
        habit: 'read',
        value: 5000,
        priority: 0,
      ),
    ],
  );
  final night = Routine(
    id: 'night',
    title: 'Trước khi ngủ',
    time: '22:15',
    steps: [
      step('Dọn bàn làm việc', 5, shortest: 2),
      step('Chuẩn bị đồ ngày mai', 5, shortest: 3),
      step(
        'Tắt điện thoại, đọc sách',
        20,
        shortest: 10,
        habit: 'read',
        value: 10000,
        required: false,
      ),
    ],
  );
  final sessions = <RoutineSession>[
    for (final i in [1, 2, 3, 5, 6])
      RoutineSession(
        id: 's$i',
        routine: 'night',
        title: night.title,
        started: '${addDays(today, -i)}T15:20:00Z',
        day: addDays(today, -i),
        steps: [
          for (final st in night.steps)
            StepRun(
              plan: st,
              status: 'completed',
              elapsed: st.seconds + (i * 37) % 120,
            ),
        ],
        cursor: night.steps.length - 1,
        status: 'finished',
        ended: '${addDays(today, -i)}T15:52:00Z',
      ),
  ];
  return HabitState(
    habits: habits,
    events: events,
    routines: [morning, night],
    sessions: sessions,
    settings: {
      'onboarded': true,
      'locale': 'vi',
      'reminders': [
        Reminder(
          id: 'r1',
          target: 'morning',
          type: 'routine',
          time: '06:30',
          weekdays: const [1, 2, 3, 4, 5],
        ).toJson(),
        Reminder(
          id: 'r2',
          target: 'read',
          type: 'habit',
          time: '21:30',
        ).toJson(),
      ],
    },
  );
}

/// The same person with days off: knee pain for the gym three weeks ago,
/// a trip now ([everything]) or only reading paused, and English later.
HabitState resting({bool everything = true}) {
  final s = practice();
  return s.copy({
    'pauses': [
      Pause(
        id: 'knee',
        from: addDays(today, -14),
        until: addDays(today, -10),
        reason: 'Đau gối',
        habits: const ['gym'],
      ).toJson(),
      if (everything)
        Pause(
          id: 'trip',
          from: addDays(today, -1),
          until: addDays(today, 3),
          reason: 'Đi Đà Lạt',
        ).toJson()
      else
        Pause(
          id: 'eyes',
          from: addDays(today, -1),
          until: addDays(today, 2),
          reason: 'Khám mắt',
          habits: const ['read'],
        ).toJson(),
      Pause(
        id: 'exam',
        from: addDays(today, 18),
        until: addDays(today, 20),
        habits: const ['english'],
      ).toJson(),
    ],
  });
}

Future<HabitController> boot(
  WidgetTester t,
  Size size, {
  String theme = 'light',
  HabitState? state,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final s = state ?? practice();
  final store = fixtures.MemoryStore()
    ..value = s.copy({
      'settings': {...s.settings, 'theme': theme},
    });
  final c = HabitController(open: () async => store);
  await c.load();
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: HabitApp(controller: c, clock: () => now),
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  return c;
}

Future<void> area(WidgetTester t, int i) async {
  final wide = t.view.physicalSize.width >= HandySpace.wide;
  await fixtures.tapKey(t, wide ? 'area-$i' : 'nav-$i');
}

void main() {
  setUpAll(() async {
    const fonts = '../../packages/handy_ui/fonts';
    await _font('packages/handy_ui/Geist', [
      '$fonts/Geist-Regular.ttf',
      '$fonts/Geist-Medium.ttf',
      '$fonts/Geist-Bold.ttf',
    ]);
    await _font('packages/handy_ui/GeistMono', [
      '$fonts/GeistMono-Regular.ttf',
    ]);
    await _font('packages/handy_ui/Bricolage', [
      '$fonts/BricolageGrotesque-Medium.ttf',
      '$fonts/BricolageGrotesque-Display.ttf',
    ]);
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    await _font('Nunito', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    await _font('MaterialIcons', [
      '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(768, 1024)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label today', (t) async {
      await boot(t, size);
      await shot(t, '$label-1-today');
    });
    testWidgets('$label habits', (t) async {
      await boot(t, size);
      await area(t, 1);
      await shot(t, '$label-2-habits');
    });
    testWidgets('$label routines', (t) async {
      await boot(t, size);
      await area(t, 2);
      await shot(t, '$label-3-routines');
    });
    testWidgets('$label insights', (t) async {
      await boot(t, size);
      await area(t, 3);
      await shot(t, '$label-4-insights');
    });
  }
  testWidgets('phone habit', (t) async {
    await boot(t, const Size(390, 844));
    await fixtures.tapKey(t, 'habit-read');
    await shot(t, 'phone-5-habit');
  });
  testWidgets('phone amount', (t) async {
    await boot(t, const Size(390, 844));
    await fixtures.tapKey(t, 'bead-walk');
    await shot(t, 'phone-6-amount');
  });
  testWidgets('phone editor', (t) async {
    await boot(t, const Size(390, 844));
    await fixtures.tapKey(t, 'habit-add');
    await fixtures.tapKey(t, 'add-habit');
    await t.enterText(find.byKey(const Key('field-title')), 'Viết nhật ký');
    await fixtures.tapKey(t, 'field-schedule-weekdays');
    await shot(t, 'phone-7-editor');
  });
  testWidgets('phone routine', (t) async {
    await boot(t, const Size(390, 844));
    await area(t, 2);
    await fixtures.tapKey(t, 'routine-morning');
    await shot(t, 'phone-8-routine');
    await fixtures.tapKey(t, 'routine-lite');
    await shot(t, 'phone-9-lite');
  });
  testWidgets('phone runner', (t) async {
    await boot(t, const Size(390, 844));
    await fixtures.tapKey(t, 'start-morning');
    await t.tap(find.byKey(const Key('routine-complete-step')));
    await t.pumpAndSettle();
    await shot(t, 'phone-10-runner');
    await t.tap(find.byKey(const Key('routine-pause')));
    await t.pumpAndSettle();
    await shot(t, 'phone-11-runner-paused');
  });
  testWidgets('phone settings', (t) async {
    await boot(t, const Size(390, 844));
    await fixtures.tapKey(t, 'open-settings');
    await shot(t, 'phone-12-settings');
  });
  testWidgets('phone first open', (t) async {
    await boot(
      t,
      const Size(390, 844),
      state: HabitState(settings: {'locale': 'vi'}),
    );
    await shot(t, 'phone-13-first-open');
  });
  testWidgets('phone dark', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await shot(t, 'phone-14-dark');
    await fixtures.tapKey(t, 'habit-read');
    await shot(t, 'phone-15-dark-habit');
  });
  testWidgets('desktop runner', (t) async {
    await boot(t, const Size(1440, 900));
    await fixtures.tapKey(t, 'start-morning');
    await shot(t, 'desktop-5-runner');
  });
  testWidgets('desktop settings', (t) async {
    await boot(t, const Size(1440, 900));
    await fixtures.tapKey(t, 'open-settings');
    await shot(t, 'desktop-6-settings');
  });
  testWidgets('phone resting', (t) async {
    await boot(t, const Size(390, 844), state: resting());
    await shot(t, 'phone-16-resting');
  });
  testWidgets('phone pause editor', (t) async {
    await boot(t, const Size(390, 844));
    await fixtures.tapKey(t, 'habit-add');
    await fixtures.tapKey(t, 'add-pause');
    await fixtures.tapKey(t, 'field-scope-some');
    await fixtures.tapKey(t, 'field-habits-gym');
    await t.enterText(find.byKey(const Key('field-reason')), 'Đau gối');
    await t.pumpAndSettle();
    await shot(t, 'phone-17-pause-editor');
  });
  testWidgets('phone habit paused', (t) async {
    await boot(t, const Size(390, 844), state: resting());
    await fixtures.tapKey(t, 'habit-gym');
    await shot(t, 'phone-18-habit-paused');
  });
  testWidgets('phone one habit paused', (t) async {
    await boot(t, const Size(390, 844), state: resting(everything: false));
    await shot(t, 'phone-19-one-paused');
  });
  testWidgets('phone settings pauses', (t) async {
    await boot(t, const Size(390, 844), state: resting());
    await fixtures.tapKey(t, 'open-settings');
    await t.scrollUntilVisible(
      find.byKey(const Key('pause-add')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-20-settings-pauses');
  });
  testWidgets('narrow resting', (t) async {
    await boot(t, const Size(320, 640), state: resting());
    await shot(t, 'narrow-1-resting');
  });
  testWidgets('phone dark resting', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark', state: resting());
    await shot(t, 'phone-21-dark-resting');
  });
  testWidgets('desktop resting', (t) async {
    await boot(t, const Size(1440, 900), state: resting());
    await shot(t, 'desktop-7-resting');
  });
  testWidgets('desktop pause editor', (t) async {
    await boot(t, const Size(1440, 900), state: resting());
    await fixtures.tapKey(t, 'habit-add');
    await fixtures.tapKey(t, 'add-pause');
    await shot(t, 'desktop-8-pause-editor');
  });
  testWidgets('films', (t) async {
    await boot(t, const Size(390, 844));
    await film(t, 'phone-tap-bead', () async {
      await t.tap(find.byKey(const Key('bead-meditate')).first);
      await t.pump();
    });
  });

  testWidgets('phone week review', (t) async {
    await boot(t, const Size(390, 844));
    await fixtures.tapKey(t, 'week-review-open');
    await shot(t, 'phone-22-week-review');
  });
}
