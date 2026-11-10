import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/habits/habit_view.dart';
import 'package:handy_habit/shell/habit_shell.dart';
import 'package:handy_habit/today/day_parts.dart';
import 'package:handy_habit/ui/form.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart' as f;

final now = DateTime.utc(2024, 1, 8, 12);
Future<HabitController> boot(
  WidgetTester t, {
  HabitState? state,
  double width = 390,
  double scale = 1,
  f.MemoryStore? store,
  DateTime Function()? clock,
}) async {
  t.view.physicalSize = Size(width, 844);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final memory = store ?? (f.MemoryStore()..value = state ?? f.seeded());
  final c = HabitController(
    open: () async => memory,
    clock: clock ?? () => now,
  );
  await c.load();
  await t.pumpWidget(
    HabitApp(controller: c, clock: clock ?? () => now, device: false),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  return c;
}

NavigatorState nav(WidgetTester t) =>
    t.state<NavigatorState>(find.byType(Navigator).first);
Future<void> go(WidgetTester t, String path) async {
  unawaited(nav(t).pushNamed(path));
  await t.pumpAndSettle();
}

String? route(WidgetTester t) =>
    ModalRoute.of(t.element(find.byType(Scaffold).last))?.settings.name;
Future<void> shortcut(
  WidgetTester t,
  LogicalKeyboardKey key, {
  bool meta = false,
}) async {
  final modifier = meta
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await t.sendKeyDownEvent(modifier);
  await t.sendKeyEvent(key);
  await t.sendKeyUpEvent(modifier);
  await t.pumpAndSettle();
}

class GatedStore extends f.MemoryStore {
  bool fail = false;
  Completer<void>? gate;
  int attempts = 0;
  @override
  Future<void> commit(HabitState next, {required int expectedRevision}) async {
    attempts++;
    await gate?.future;
    if (fail) throw StateError('disk full');
    await super.commit(next, expectedRevision: expectedRevision);
  }
}

void main() {
  testWidgets(
    'failed save keeps draft; retry blocks back and double save while busy',
    (t) async {
      final store = GatedStore()
        ..value = f.seeded()
        ..fail = true;
      final c = await boot(t, store: store);
      await go(t, '/habit/new');
      await t.enterText(find.byKey(const Key('field-title')), 'Walk daily');
      await f.tapKey(t, 'editor-save');
      expect(find.text('Walk daily'), findsOneWidget);
      expect(find.textContaining('Nothing changed.'), findsOneWidget);
      expect(c.state!.habits, hasLength(1));
      store.fail = false;
      store.gate = Completer<void>();
      await t.tap(find.byKey(const Key('editor-save')));
      await t.pump();
      expect(
        t.widget<FilledButton>(find.byKey(const Key('editor-save'))).onPressed,
        isNull,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(route(t), '/habit/new');
      expect(find.text('Unsaved changes'), findsNothing);
      store.gate!.complete();
      await t.pumpAndSettle();
      expect(c.state!.habits, hasLength(2));
      expect(store.attempts, 2);
    },
  );

  testWidgets(
    'effective target edit preserves old day value, goal and appearance',
    (t) async {
      final old = f.seeded().habits.single.copy({
        'type': 'count',
        'color': 0xff147d72,
        'schedules': [
          Schedule(id: 'v', from: '2024-01-01', target: 2000).toJson(),
        ],
      });
      final c = await boot(
        t,
        state: f.seeded().copy({
          'habits': [old.toJson()],
          'events': [
            HabitEvent(
              id: 'e',
              habit: 'h',
              day: '2024-01-07',
              value: 2000,
            ).toJson(),
          ],
        }),
      );
      await go(t, '/habit/h/edit');
      await t.enterText(find.byKey(const Key('field-target')), '4');
      await f.tapKey(t, 'editor-save');
      final h = c.state!.habits.single;
      expect(scheduleOn(h, '2024-01-07')!.target, 2000);
      expect(scheduleOn(h, '2024-01-08')!.target, 4000);
      expect(c.state!.events.single.value, 2000);
      expect(h.color, old.color);
      expect(h.icon, old.icon);
      await go(t, '/habit/h');
      expect(find.textContaining('Goal 2'), findsWidgets);
    },
  );

  testWidgets(
    'an open Today advances at the configured boundary without shifting history',
    (t) async {
      var instant = DateTime.utc(2024, 1, 8, 3, 59);
      final c = await boot(
        t,
        clock: () => instant,
        state: f.seeded().copy({
          'settings': {
            'onboarded': true,
            'zone': 'UTC',
            'dayBoundaryMinutes': 240,
          },
          'clockPolicies': [
            {
              'id': 'p',
              'zone': 'UTC',
              'dayBoundaryMinutes': 240,
              'effectiveFrom': '1900-01-01T00:00:00.000Z',
            },
          ],
        }),
      );
      await f.tapKey(t, 'bead-h');
      expect(c.state!.events.single.day, '2024-01-07');
      await go(t, '/habit/new');
      instant = instant.add(const Duration(minutes: 1));
      await t.pump(const Duration(minutes: 1));
      await t.pumpAndSettle();
      await f.tapKey(t, 'sheet-cancel');
      expect(find.text('Unsaved changes'), findsNothing);
      await f.tapKey(t, 'bead-h');
      expect(c.state!.events.map((e) => e.day).toSet(), {
        '2024-01-07',
        '2024-01-08',
      });
    },
  );
  setUpAll(() async {
    // Geometry assertions use the shipped face, rather than Ahem's square glyphs.
    final font = FontLoader('Nunito');
    for (final file in Directory('fonts').listSync().whereType<File>()) {
      if (file.path.endsWith('.ttf'))
        font.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
    }
    await font.load();
  });
  testWidgets(
    'named editor saves a new habit and an effective target without changing appearance',
    (t) async {
      final c = await boot(t);
      await go(t, '/habit/new');
      await t.enterText(find.byKey(const Key('field-title')), 'Walk daily');
      await f.tapKey(t, 'editor-save');
      expect(
        c.state!.habits,
        hasLength(2),
        reason: t
            .widgetList<Text>(find.byKey(const Key('sheet-error')))
            .map((w) => w.data)
            .join(),
      );
      expect(find.byType(HabitForm), findsNothing);
      final old = c.state!.habits.first;
      await go(t, '/habit/${old.id}/edit');
      await t.enterText(find.byKey(const Key('field-title')), 'Read every day');
      await f.tapKey(t, 'editor-save');
      final changed = c.state!.habits.firstWhere((h) => h.id == old.id);
      expect(changed.title, 'Read every day');
      expect(changed.icon, old.icon);
      expect(changed.color, old.color);
      expect(changed.schedules.first.toJson(), old.schedules.first.toJson());
    },
  );
  testWidgets(
    'three destinations have named routes, and back returns one level',
    (t) async {
      await boot(t);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      await f.tapKey(t, 'nav-2');
      expect(route(t), '/routines');
      await f.tapKey(t, 'nav-3');
      expect(route(t), '/progress');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
      await f.tapKey(t, 'today-all-habits');
      expect(route(t), '/habits');
      await go(t, '/habit/h');
      expect(find.byType(HabitPage), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(route(t), '/habits');
    },
  );

  testWidgets(
    'new/edit, weekly URL query, legacy URLs and missing paths resolve',
    (t) async {
      await boot(t);
      for (final path in [
        '/today',
        '/routines',
        '/progress',
        '/insights',
        '/progress/week?from=2024-01-01',
        '/review',
        '/habit/new',
        '/habit/h/edit',
        '/routine/new',
        '/routine/r/edit',
        '/routine/r',
        '/help',
        '/help/history',
        '/templates?kind=habit',
        '/templates/read',
        '/settings',
        '/settings/calendar',
        '/habit/missing/edit',
        '/not-a-page',
      ]) {
        await go(t, path);
        expect(route(t), path);
        expect(t.takeException(), isNull, reason: path);
        if (path.endsWith('/edit') || path.endsWith('/new')) {
          expect(find.text('Unsaved changes'), findsNothing);
        }
        nav(t).pop();
        await t.pumpAndSettle();
      }
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'bead starts above top60% with active run and scale1.5 at $width',
      (t) async {
        final base = f.seeded();
        final session = startSession(base.routines.single, '2024-01-08', now);
        await boot(
          t,
          width: width,
          scale: 1.5,
          state: base.copy({
            'sessions': [session.toJson()],
          }),
        );
        expect(
          t.getTopLeft(find.byKey(const Key('bead-h'))).dy,
          lessThan(844 * .6),
        );
        expect(find.byKey(const Key('resume-session')), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'one tap commits once, keeps row position, and durable Undo restores',
    (t) async {
      final c = await boot(t);
      final before = t.getTopLeft(find.byKey(const Key('bead-h')));
      await f.tapKey(t, 'bead-h');
      expect(c.state!.events, hasLength(1));
      expect(HabitIndex.of(c.state!).value('h', '2024-01-08'), 1000);
      expect(t.getTopLeft(find.byKey(const Key('bead-h'))), before);
      await c.load();
      await t.pumpAndSettle();
      expect(c.canUndo, isTrue);
      await f.tapKey(t, 'snack-undo');
      expect(c.state!.events, isEmpty);
    },
  );

  testWidgets(
    'sidebar folds at top, remembers after reload and reopens at rail top',
    (t) async {
      final c = await boot(t, width: 1440);
      expect(
        t.getTopLeft(find.byKey(const Key('side-collapse'))).dy,
        lessThan(80),
      );
      await f.tapKey(t, 'side-collapse');
      expect(c.state!.settings['sidebarCollapsed'], true);
      await c.load();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('side-collapse')), findsNothing);
      expect(t.getTopLeft(find.byKey(const Key('side-open'))).dy, lessThan(80));
      await go(t, '/routines');
      expect(find.byKey(const Key('side-open')), findsOneWidget);
      await f.tapKey(t, 'side-open');
      expect(c.state!.settings['sidebarCollapsed'], false);
      expect(find.byKey(const Key('side-collapse')), findsOneWidget);
    },
  );

  testWidgets('Show all expands habits in place and folds without navigation', (
    t,
  ) async {
    final base = f.seeded();
    final habits = [
      for (var i = 0; i < 10; i++)
        base.habits.single.copy({'id': 'h$i', 'title': 'Read $i'}).toJson(),
    ];
    await boot(t, state: base.copy({'habits': habits, 'routines': []}));
    expect(find.byKey(const Key('habit-h8')), findsNothing);
    await f.tapKey(t, 'today-habits-more');
    await t.scrollUntilVisible(find.byKey(const Key('habit-h8')), 300);
    expect(find.byKey(const Key('habit-h8')), findsOneWidget);
    expect(route(t), '/');
    await f.tapKey(t, 'today-habits-more');
    expect(find.byKey(const Key('habit-h8')), findsNothing);
  });

  testWidgets(
    'history Show all reveals old entries with targets effective that day',
    (t) async {
      final h = f.seeded().habits.single.copy({
        'type': 'count',
        'created': '2023-11-01',
        'schedules': [
          Schedule(id: 'v1', from: '2023-11-01', target: 2000).toJson(),
          Schedule(id: 'v2', from: '2024-01-01', target: 4000).toJson(),
        ],
      });
      final events = [
        for (var i = 0; i < 45; i++)
          HabitEvent(
            id: 'e$i',
            habit: 'h',
            day: addDays('2024-01-08', -i),
            value: 2000,
            note: 'Record $i',
          ).toJson(),
      ];
      await boot(
        t,
        state: f.seeded().copy({
          'habits': [h.toJson()],
          'events': events,
        }),
      );
      await go(t, '/habit/h');
      await f.tapKey(t, 'history-more');
      await t.ensureVisible(find.textContaining('Record 44'));
      await t.pumpAndSettle();
      expect(find.textContaining('Record 44'), findsOneWidget);
      expect(find.textContaining('Goal 2'), findsWidgets);
      expect(route(t), '/habit/h');
      await f.tapKey(t, 'history-more');
      expect(find.textContaining('Record 44'), findsNothing);
    },
  );

  testWidgets('dirty editor Cancel keeps draft until explicit discard', (
    t,
  ) async {
    final c = await boot(t);
    await go(t, '/habit/new');
    await t.enterText(find.byKey(const Key('field-title')), 'Read daily');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await shortcut(t, LogicalKeyboardKey.digit3);
    expect(route(t), '/progress');
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Read daily'), findsOneWidget);
    await f.tapKey(t, 'sheet-cancel');
    expect(find.text('Unsaved changes'), findsOneWidget);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    expect(find.text('Read daily'), findsOneWidget);
    expect(c.state!.habits, hasLength(1));
    await f.tapKey(t, 'sheet-cancel');
    await t.tap(find.text('Discard'));
    await t.pumpAndSettle();
    expect(find.byType(HabitForm), findsNothing);
    expect(c.state!.habits, hasLength(1));
  });

  testWidgets(
    'untouched editor exits silently; back and Escape guard dirty choice',
    (t) async {
      await boot(t);
      await go(t, '/habit/new');
      await f.tapKey(t, 'sheet-cancel');
      expect(find.text('Unsaved changes'), findsNothing);
      await go(t, '/habit/new');
      await f.tapKey(t, 'field-type-count');
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await t.tap(find.text('Cancel').last);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(find.byType(HabitForm), findsNothing);
    },
  );

  testWidgets('keyboard shortcuts support Cmd/Ctrl and leave typing alone', (
    t,
  ) async {
    await boot(t);
    await shortcut(t, LogicalKeyboardKey.digit2);
    expect(route(t), '/routines');
    await shortcut(t, LogicalKeyboardKey.keyN, meta: true);
    expect(route(t), '/routine/new');
    await f.tapKey(t, 'sheet-cancel');
    await shortcut(t, LogicalKeyboardKey.keyF);
    expect(route(t), '/habits?search=true');
    await t.enterText(find.byKey(const Key('habit-search')), 'Read');
    await shortcut(t, LogicalKeyboardKey.digit3);
    await shortcut(t, LogicalKeyboardKey.keyN);
    await shortcut(t, LogicalKeyboardKey.comma);
    expect(route(t), '/habits?search=true');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await shortcut(t, LogicalKeyboardKey.comma, meta: true);
    expect(route(t), '/settings');
  });

  for (final appSetting in [false, true]) {
    testWidgets(
      'motion snaps for ${appSetting ? 'app preference' : 'OS preference'}',
      (t) async {
        if (!appSetting) {
          t.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        await boot(
          t,
          width: 1440,
          state: f.seeded().copy({
            'settings': {'onboarded': true, 'reducedMotion': appSetting},
          }),
        );
        final context = t.element(find.byType(HabitShell).last);
        expect(HandyMotion.of(context), Duration.zero);
        await f.tapKey(t, 'side-collapse');
        for (final w in t.widgetList<AnimatedSwitcher>(
          find.byType(AnimatedSwitcher),
        )) {
          expect(w.duration, Duration.zero);
        }
        expect(find.byKey(const Key('side-open')), findsOneWidget);
      },
    );
  }

  test(
    'day grouping infers reminder/routine times and explicit override wins',
    () {
      final s = f.seeded();
      final h = s.habits.single;
      expect(habitDayPart(s, h), 'morning'); // linked routine defaults07:00
      final reminders = s.copy({
        'settings': {
          ...s.settings,
          'reminders': [
            Reminder(
              id: 'n',
              target: h.id,
              type: 'habit',
              time: '19:30',
            ).toJson(),
          ],
        },
        'routines': [],
      });
      expect(habitDayPart(reminders, h), 'evening');
      expect(
        habitDayPart(
          reminders.copy({
            'settings': {
              ...reminders.settings,
              'habitDayParts': {h.id: 'afternoon'},
            },
          }),
          h,
        ),
        'afternoon',
      );
    },
  );
}
