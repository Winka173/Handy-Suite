import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/home_widget.dart';
import 'package:handy_habit/reminders.dart';
import 'package:handy_habit/insights/insight_dates.dart';
import 'package:handy_habit/insights/insight_filters.dart';
import 'package:handy_habit/insights/smart_review.dart';
import 'package:handy_habit/settings/system_settings.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_notifications/native.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pro_test.dart' as p;
import 'ui_test.dart' as f;
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;
import 'run13_smart_studio_test.dart' show smartSeed;

HabitState run14Seed({String locale = 'en'}) {
  final vi = locale == 'vi', base = smartSeed();
  final walk = Habit(
    id: 'walk',
    title: vi ? 'Đi bộ ngoài trời' : 'Walk outside',
    created: '2023-10-01',
    category: vi ? 'Vận động' : 'Movement',
    schedules: [Schedule(id: 'ws', from: '2023-10-01')],
  );
  return base.copy({
    'habits': [
      base.habits.single.copy({
        'title': vi ? 'Đọc sách' : 'Read',
        'unit': vi ? 'trang' : 'pages',
        'category': vi ? 'Học tập' : 'Learning',
      }).toJson(),
      walk.toJson(),
    ],
    'routines': [
      f.seeded().routines.single.copy({
        'title': vi ? 'Buổi sáng nhẹ nhàng' : 'An easy morning',
        'steps': [
          for (final step in f.seeded().routines.single.steps)
            step.copy({'habit': step.habit == null ? null : 'walk'}).toJson(),
        ],
      }).toJson(),
    ],
    'events': [
      ...base.events.map((e) => e.toJson()),
      for (var i = 0; i < 99; i++)
        if (i % 7 < 4)
          HabitEvent(
            id: 'we$i',
            habit: 'walk',
            day: addDays(walk.created, i),
            value: 1000,
          ).toJson(),
    ],
    'settings': {
      ...base.settings,
      'onboarded': true,
      'locale': locale,
      'notifications': true,
      'habitDayParts': {'read': 'morning', 'walk': 'evening'},
      'reminders': [
        Reminder(
          id: 'read-reminder',
          type: 'habit',
          target: 'read',
          time: '08:00',
        ).toJson(),
        Reminder(
          id: 'routine-reminder',
          target: 'r',
          type: 'routine',
          time: '09:00',
        ).toJson(),
      ],
    },
  });
}

class Run14Reminders extends HabitReminders {
  ReminderDiagnostics value;
  bool available = true, fail = false;
  int tests = 0, requests = 0;
  Completer<ReminderDiagnostics>? gate;
  Run14Reminders({
    this.value = const ReminderDiagnostics(
      permission: HabitPermission.allowed,
      exactAllowed: false,
      batteryExempt: false,
    ),
  });
  @override
  bool get supported => available;
  @override
  Future<ReminderDiagnostics> diagnostics() async {
    if (fail) throw StateError('unavailable');
    return gate == null ? value : gate!.future;
  }

  @override
  Future<bool> permission() async =>
      value.permission == HabitPermission.allowed ||
      value.permission == HabitPermission.unreadable;
  @override
  Future<bool> request() async {
    requests++;
    return permission();
  }

  @override
  Future<void> sync(HabitState state) async {}
  @override
  Future<void> test(HabitState state) async {
    if (fail) throw StateError('test failed');
    tests++;
  }
}

Future<(HabitController, Run14Reminders, LifetimeController)> bootRun14(
  WidgetTester t, {
  HabitState? state,
  double width = 390,
  double scale = 1,
  String locale = 'en',
  String theme = 'light',
  bool pro = true,
  Run14Reminders? reminders,
  Key? boundary,
}) async {
  t.view.physicalSize = Size(width, width >= 1000 ? 900 : 1000);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final disk = f.MemoryStore()
    ..value = (state ?? run14Seed(locale: locale)).copy({
      'settings': {
        ...(state ?? run14Seed(locale: locale)).settings,
        'onboarded': true,
        'locale': locale,
        'theme': theme,
      },
    });
  final c = HabitController(open: () async => disk, clock: () => host.now);
  await c.load();
  final port = p.FakeHabitStore();
  final store = LifetimeController(
    const MonetizationConfig(productId: p.FakeHabitStore.product),
    port,
  )..accept(p.FakeHabitStore.snapshot(pro ? 'owned' : 'ready', pro: pro));
  final r = reminders ?? Run14Reminders();
  await t.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: HabitApp(
        controller: c,
        clock: () => host.now,
        reminders: r,
        device: false,
        lifetime: store,
      ),
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
    store.dispose();
  });
  return (c, r, store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final vi in [false, true]) {
    test('localized short date and ranges ${vi ? 'VI' : 'EN'}', () {
      expect(insightDate('2026-11-02', vi: vi), vi ? '2 thg 11' : 'Nov 2');
      expect(
        insightRange('2026-11-01', '2026-11-10', vi: vi),
        vi ? '1–10 thg 11, 2026' : '1–10 Nov, 2026',
      );
      final crossing = insightRange('2025-12-30', '2026-01-02', vi: vi);
      expect(crossing, contains('2025'));
      expect(crossing, contains('2026'));
      expect(crossing, isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));
    });
    p.proTest(
      'findings and PDF preview contain localized dates and no method paragraphs $vi',
      (t) async {
        await bootRun14(t, locale: vi ? 'vi' : 'en');
        await host.go(t, '/progress/smart');
        String texts() => t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .join('\n');
        expect(texts(), isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));
        expect(texts(), isNot(contains('Same elapsed portion')));
        final c = t.element(find.byKey(const Key('smart-month'))),
            review = smartReview(c, run14Seed(), '2024-01-08', 'month');
        expect(
          review.expand((s) => [s.$1, ...s.$2]).join(),
          isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))),
        );
        await tap(t, 'smart-method-0');
        expect(
          texts(),
          contains(vi ? 'Chỉ tính ngày đã hết' : 'Only closed days'),
        );
        host.nav(t).pop();
        await t.pumpAndSettle();
        await tap(t, 'smart-report');
        expect(find.text(review.first.$2.first), findsOneWidget);
        expect(find.text(review.first.$2[1]), findsOneWidget);
        expect(texts(), isNot(contains('Asia/Ho_Chi_Minh')));
        expect(texts(), isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));
      },
    );
  }
  p.proTest(
    'five filter dimensions count, dismiss and Clear do not mutate history',
    (t) async {
      final (c, _, _) = await bootRun14(t);
      await host.go(t, '/progress/smart');
      final before = jsonEncode(c.state!.toJson());
      for (final (id, v) in [
        ('collection', 'Learning'),
        ('time', 'morning'),
        ('direction', 'build'),
        ('weekday', '1'),
        ('outcome', 'kept'),
      ]) {
        final chip = find.byKey(Key('smart-filter-$id'));
        await t.ensureVisible(find.byType(InsightFilters));
        await Scrollable.ensureVisible(t.element(chip), alignment: .5);
        await t.pumpAndSettle();
        await t.tap(chip);
        await t.pumpAndSettle();
        await tap(t, 'smart-option-$id-$v');
      }
      expect(
        t.widget<Text>(find.byKey(const Key('smart-filter-count'))).data,
        '5',
      );
      expect(
        insightFilterCount(
          t.widget<InsightFilters>(find.byType(InsightFilters)).value,
        ),
        5,
      );
      await tap(t, 'smart-filter-clear');
      expect(
        t.widget<Text>(find.byKey(const Key('smart-filter-count'))).data,
        '0',
      );
      expect(jsonEncode(c.state!.toJson()), before);
      await tap(t, 'smart-filter-time');
      host.nav(t).pop();
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const Key('smart-filter-count'))).data,
        '0',
      );
    },
  );
  p.proTest(
    'focused heatmap has 48px targets, no cell labels, and details on tap',
    (t) async {
      await bootRun14(t);
      await host.go(t, '/progress/smart');
      final cell = find.byKey(const Key('smart-cell-read-2024-01-07'));
      await t.ensureVisible(cell);
      await t.pumpAndSettle();
      expect(t.getSize(cell).shortestSide, greaterThanOrEqualTo(48));
      expect(
        find.descendant(of: cell, matching: find.byType(Text)),
        findsNothing,
      );
      await t.tap(cell);
      await t.pumpAndSettle();
      expect(find.textContaining('known goals'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  for (final permission in HabitPermission.values)
    p.proTest('diagnostics ${permission.name} never asks permission', (
      t,
    ) async {
      final r = Run14Reminders(
        value: ReminderDiagnostics(
          permission: permission,
          exactAllowed: false,
          batteryExempt: false,
          lastScheduled: DateTime.utc(2024, 1, 8),
          scheduled: 2,
          failed: permission == HabitPermission.error,
        ),
      )..available = permission != HabitPermission.unsupported;
      await bootRun14(t, reminders: r);
      await host.go(t, '/settings/notifications/diagnostics');
      expect(find.byKey(const Key('diagnostics-permission')), findsOneWidget);
      expect(r.requests, 0);
      final test = find.byKey(const Key('diagnostics-test'));
      if (permission == HabitPermission.unsupported) {
        expect(test, findsNothing);
      } else {
        await t.ensureVisible(test);
        final b = t.widget<FilledButton>(test);
        expect(
          b.onPressed == null,
          ![
            HabitPermission.allowed,
            HabitPermission.unreadable,
          ].contains(permission),
        );
      }
      if (permission == HabitPermission.allowed) {
        await tap(t, 'diagnostics-test');
        expect(r.tests, 1);
        expect(find.textContaining('Test sent.'), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  p.proTest(
    'diagnostics loading and read failure retry; Android settings link',
    (t) async {
      final r = Run14Reminders()..gate = Completer<ReminderDiagnostics>();
      await bootRun14(t, reminders: r);
      unawaited(host.nav(t).pushNamed('/settings/notifications/diagnostics'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('diagnostics-loading')), findsOneWidget);
      r.gate!.complete(r.value);
      r.gate = null;
      await t.pumpAndSettle();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(habitSystemChannel, (c) async {
            calls.add(c.method);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(habitSystemChannel, null),
      );
      await tap(t, 'diagnostics-battery');
      expect(calls, ['battery']);
      r.fail = true;
      await tap(t, 'diagnostics-refresh');
      expect(find.byKey(const Key('diagnostics-error')), findsOneWidget);
      r.fail = false;
      await tap(t, 'diagnostics-refresh');
      expect(find.byKey(const Key('diagnostics-permission')), findsOneWidget);
    },
  );
  p.proTest('unsupported reminder settings have no OS switches or test', (
    t,
  ) async {
    await bootRun14(t, reminders: Run14Reminders()..available = false);
    await host.go(t, '/settings/notifications');
    for (final key in [
      'set-notifications',
      'set-run-notice',
      'settings-private-notifications',
      'notification-test',
    ])
      expect(find.byKey(Key(key)), findsNothing);
  });
  test(
    'widget payload privacy, selection, removed targets and Pro palettes',
    () {
      var s = run14Seed().copy({
        'moods': [
          MoodEntry(
            day: '2024-01-08',
            mood: 5,
            note: 'PRIVATE_MOOD_NOTE',
            tags: ['PRIVATE_TAG'],
            recordedAt: '2024-01-08T00:00:00Z',
          ).toJson(),
        ],
      });
      for (final vi in [false, true])
        for (final dark in [false, true])
          for (final pro in [false, true]) {
            s = s.copy({
              'settings': {
                ...s.settings,
                'widgetShowNames': false,
                'widgetHabit': 'walk',
                'widgetRoutine': 'r',
                'studio': {'palette': 'grove'},
              },
            });
            final views = habitWidgetViews(
                  s,
                  '2024-01-08',
                  vi: vi,
                  pro: pro,
                  dark: dark,
                ),
                raw = jsonEncode(views.map((k, v) => MapEntry(k, v.toData())));
            expect(raw, isNot(contains('PRIVATE_')));
            expect(raw, isNot(contains('Walk outside')));
            expect(raw, isNot(contains('An easy morning')));
            expect(views['habit']!.uri, 'handy-habit://checkin/walk');
            expect(views['routine']!.uri, 'handy-habit://routine/r');
            expect(views['today']!.progress, isNotNull);
            expect(views['today']!.rows, isEmpty);
            expect(
              views['habit']!.extra['palette'],
              pro ? 'grove' : 'vermilion',
            );
          }
      s = s.copy({
        'habits': [
          for (final h in s.habits) h.copy({'archived': true}).toJson(),
        ],
      });
      expect(
        habitWidgetViews(s, '2024-01-08', vi: false, pro: false)['habit']!.uri,
        'handy-habit://widgets',
      );
    },
  );
  test(
    'amount and reduction widget taps never record an incident or amount',
    () {
      final s = run14Seed();
      expect(
        habitWidgetViews(s, '2024-01-08', vi: false, pro: false)['habit']!.uri,
        'handy-habit://habit/read',
      );
      final h = Habit(
        id: 'n',
        title: 'Less',
        created: '2024-01-01',
        direction: 'reduce',
        type: 'count',
        schedules: [Schedule(id: 'ns', from: '2024-01-01')],
        negativeGoals: [
          NegativeGoal(id: 'ng', from: '2024-01-01', limit: 1000),
        ],
      );
      expect(
        habitWidgetUri(h, '2024-01-08', HabitState(habits: [h])),
        'handy-habit://habit/n',
      );
    },
  );
  p.proTest('widget settings preview, selection and privacy', (t) async {
    final (c, _, _) = await bootRun14(t);
    await host.go(t, '/settings/widgets');
    final before = jsonEncode(c.state!.toJson());
    await tap(t, 'widget-size-large');
    expect(jsonEncode(c.state!.toJson()), before);
    await tap(t, 'widget-habit-choice');
    await tap(t, 'widget-habit-choice-walk');
    expect(c.state!.settings['widgetHabit'], 'walk');
    await tap(t, 'widget-names');
    expect(c.state!.settings['widgetShowNames'], false);
  });
  p.proTest(
    'real Android scheduling is flexible, private, bounded and has device-local diagnostics',
    (t) async {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      SharedPreferences.setMockInitialValues({});
      final calls = <MethodCall>[];
      const plugin = MethodChannel('dexterous.com/flutter/local_notifications');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(plugin, (c) async {
            calls.add(c);
            if (c.method == 'pendingNotificationRequests')
              return <Map<String, dynamic>>[];
            return true;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            habitSystemChannel,
            (c) async => {'exactAllowed': false, 'batteryExempt': true},
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(plugin, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(habitSystemChannel, null);
      });
      final r = HabitReminders(), base = run14Seed();
      final s = base.copy({
        'habits': [
          for (final h in base.habits)
            h.copy({'note': 'PRIVATE_HABIT_NOTE'}).toJson(),
        ],
        'moods': [
          MoodEntry(
            day: '2024-01-08',
            mood: 5,
            note: 'PRIVATE_MOOD_NOTE',
            recordedAt: '2024-01-08T00:00:00Z',
          ).toJson(),
        ],
      });
      await r.sync(s);
      final scheduled = calls
          .where((c) => c.method == 'zonedSchedule')
          .toList();
      expect(scheduled, hasLength(50));
      for (final call in scheduled) {
        final android = (call.arguments as Map)['platformSpecifics'] as Map;
        expect(android['scheduleMode'], 'inexactAllowWhileIdle');
      }
      expect(
        jsonEncode(scheduled.map((c) => c.arguments).toList()),
        isNot(contains('Read')),
      );
      expect(
        scheduled.any(
          (c) => (c.arguments as Map)['payload'].toString().startsWith(
            'routine-reminder:',
          ),
        ),
        true,
      );
      final d = await r.diagnostics();
      expect(d.permission, HabitPermission.allowed);
      expect(d.scheduled, 50);
      expect(d.lastScheduled, isNotNull);
      expect(d.exactAllowed, false);
      expect(d.batteryExempt, true);
      expect(
        jsonEncode(calls.map((c) => c.arguments).toList()),
        isNot(contains('PRIVATE_')),
      );
      await r.sync(
        s.copy({
          'settings': {...s.settings, 'privateNotifications': false},
        }),
      );
      expect(
        jsonEncode(calls.map((c) => c.arguments).toList()),
        isNot(contains('PRIVATE_')),
      );
      await r.test(s);
      expect(calls.last.method, 'show');
      final off = s.copy({
        'settings': {...s.settings, 'notifications': false},
      });
      await r.sync(off);
      expect((await r.diagnostics()).scheduled, 0);
      expect(
        r.port.windows!.appUserModelId,
        windowsIdentity('habit')!.appUserModelId,
      ); // identity values checked below; instances may differ.
    },
  );
  p.proTest(
    'three native feeds publish prefixes and clear rows when privacy changes',
    (t) async {
      final data = <String, dynamic>{}, providers = <String>[];
      const channel = MethodChannel('home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            final a = c.arguments as Map;
            if (c.method == 'getWidgetData') return data[a['id']];
            if (c.method == 'saveWidgetData')
              data[a['id'] as String] = a['data'];
            if (c.method == 'updateWidget')
              providers.add(a['qualifiedAndroidName'] as String);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final s = run14Seed(),
          feeds = [
            HomeWidgetFeed(habitWidgetClass),
            HomeWidgetFeed(singleHabitWidgetClass, prefix: 'habit_'),
            HomeWidgetFeed(routineWidgetClass, prefix: 'routine_'),
          ];
      final views = habitWidgetViews(s, '2024-01-08', vi: false, pro: false);
      for (var i = 0; i < 3; i++)
        await feeds[i].publish(views[['today', 'habit', 'routine'][i]]!);
      expect(providers, [
        habitWidgetClass,
        singleHabitWidgetClass,
        routineWidgetClass,
      ]);
      expect(data['habit_uri'], 'handy-habit://habit/read');
      await feeds.first.publish(
        habitWidgetViews(
          s.copy({
            'settings': {...s.settings, 'widgetShowNames': false},
          }),
          '2024-01-08',
          vi: false,
          pro: false,
        )['today']!,
      );
      expect(data['row0_text'], isNull);
      expect(data['palette'], 'vermilion');
    },
  );
}
