import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/settings/settings_parts.dart';
import 'package:handy_habit/pro/pro_demos.dart';
import 'package:handy_habit/habits/habit_appearance.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'pro_test.dart' as p;
import 'run14_test.dart' as f;
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;

HabitState oneGoal({int habits = 1}) => HabitState(
  habits: [
    for (var i = 0; i < habits; i++)
      Habit(
        id: 'h$i',
        title: 'Read $i',
        created: '2024-01-08',
        schedules: [Schedule(id: 's$i', from: '2024-01-08')],
      ),
  ],
  settings: const {'onboarded': true},
);

void main() {
  test(
    'all 44 habit and 11 routine icons render and survive instantiation',
    () {
      const expected = <String, IconData>{
        'water-morning': Icons.water_drop_outlined,
        'make-bed': Icons.bed_outlined,
        'stretch': Icons.self_improvement,
        'plan-day': Icons.edit_outlined,
        'tidy-desk': Icons.desk_outlined,
        'journal': Icons.edit_outlined,
        'prep-tomorrow': Icons.event_available_outlined,
        'gratitude': Icons.favorite_outline,
        'walk': Icons.directions_walk,
        'steps': Icons.directions_walk,
        'workout': Icons.fitness_center,
        'pushups': Icons.fitness_center,
        'read': Icons.menu_book_outlined,
        'language': Icons.translate,
        'review-cards': Icons.style_outlined,
        'deep-work': Icons.timer_outlined,
        'bed-time': Icons.bedtime_outlined,
        'no-caffeine': Icons.coffee_outlined,
        'wind-down': Icons.bedtime_outlined,
        'same-wake': Icons.alarm,
        'cleanse': Icons.spa_outlined,
        'sunscreen': Icons.wb_sunny_outlined,
        'moisturise': Icons.spa_outlined,
        'water': Icons.water_drop_outlined,
        'phone-free-meal': Icons.restaurant_outlined,
        'social-cap': Icons.phone_android_outlined,
        'inbox-zero': Icons.mail_outline,
        'screen-off': Icons.phone_android_outlined,
        'dishes': Icons.kitchen_outlined,
        'ten-minute-tidy': Icons.home_outlined,
        'laundry': Icons.local_laundry_service_outlined,
        'plants': Icons.yard_outlined,
        'vegetables': Icons.restaurant_outlined,
        'breathe': Icons.self_improvement,
        'call-family': Icons.people_outline,
        'kind-message': Icons.chat_bubble_outline,
        'money-check': Icons.savings_outlined,
        'save-small': Icons.savings_outlined,
        'sugary-drinks': Icons.local_drink_outlined,
        'smoking': Icons.smoking_rooms_outlined,
        'late-snacks': Icons.restaurant_outlined,
        'social-checks': Icons.phone_android_outlined,
        'impulse-buys': Icons.shopping_bag_outlined,
        'phone-bed': Icons.phone_android_outlined,
      };
      expect(habitPresets.length, 44);
      expect(expected.keys.toSet(), habitPresets.map((h) => h.id).toSet());
      for (final h in habitPresets) {
        expect(habitIcon(h.icon), expected[h.id], reason: h.id);
      }
      expect(routineTemplateCatalog.length, 11);
      for (final r in routineTemplateCatalog) {
        expect(habitIcon(r.icon), isNot(Icons.check), reason: r.id);
        expect(r.instantiate().icon, r.icon, reason: r.id);
      }
    },
  );

  for (final width in [390.0, 1440.0]) {
    for (final count in [0, 1]) {
      testWidgets('one Today creation path $count habits at $width', (t) async {
        await f.bootRun14(
          t,
          state: oneGoal(habits: count),
          width: width,
        );
        expect(find.byKey(const Key('habit-add')), findsNothing);
        expect(
          find.byKey(const Key('today-new')),
          count == 0 ? findsNothing : findsOneWidget,
        );
        await tap(t, count == 0 ? 'today-add-habit' : 'today-new');
        // One way in: the quick sheet, with the gallery one tap further.
        expect(find.byKey(const Key('quick-add')), findsOneWidget);
        await tap(t, 'quick-add-templates');
        expect(find.byKey(const Key('template-search')), findsOneWidget);
      });
    }
  }

  testWidgets('free featured templates have no Free badge', (t) async {
    await f.bootRun14(t);
    await host.go(t, '/templates');
    expect(find.text('Free'), findsNothing);
    await tap(t, 'templates-routines');
    expect(find.text('Free'), findsNothing);
  });

  for (final id in ['water', 'water-morning']) {
    testWidgets('$id drop icon appears in gallery, preview and saved habit', (
      t,
    ) async {
      final (c, _, _) = await f.bootRun14(t, state: oneGoal(habits: 0));
      await host.go(t, '/templates');
      await t.enterText(find.byKey(const Key('template-search')), 'water');
      await t.pumpAndSettle();
      final row = find.byKey(Key('preset-$id'));
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(Icons.water_drop_outlined),
        ),
        findsOneWidget,
      );
      await tap(t, 'preset-$id');
      // The editor shows the template's icon in its colour.
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
      await tap(t, 'editor-save');
      expect(c.state!.habits.single.icon, Icons.water_drop_outlined.codePoint);
    });
  }

  for (final accessible in [false, true]) {
    testWidgets('Undo uses kit timing and accessible action $accessible', (
      t,
    ) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(accessibleNavigation: accessible);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final semantics = t.ensureSemantics();
      final (c, _, _) = await f.bootRun14(t, state: oneGoal());
      await tap(t, 'bead-h0');
      final snack = t.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.duration, const SnackBar(content: Text('kit')).duration);
      expect(snack.persist, accessible);
      await t.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('snack-undo')), findsOneWidget);
      expect(
        t.getSemantics(find.byKey(const Key('snack-undo'))),
        matchesSemantics(
          label: 'Undo',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      if (accessible) {
        await t.pump(const Duration(seconds: 10));
        await tap(t, 'snack-undo');
        expect(c.state!.events, isEmpty);
      } else {
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('snack-undo')), findsNothing);
      }
      semantics.dispose();
    });
  }

  for (final count in [1, 2]) {
    testWidgets('Progress goal grammar and counting sheet $count', (t) async {
      await f.bootRun14(t, state: oneGoal(habits: count), pro: false);
      await tap(t, 'bead-h0');
      if (count == 2) await tap(t, 'bead-h1');
      await tap(t, 'nav-3');
      expect(
        find.text('$count of $count ${count == 1 ? 'goal' : 'goals'} kept'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Each day or whole week counts once.'),
        findsNothing,
      );
      await tap(t, 'progress-method');
      expect(
        find.textContaining('Each day or whole week counts once.'),
        findsOneWidget,
      );
      await tap(t, 'progress-method-done');
      expect(
        find.textContaining('Each day or whole week counts once.'),
        findsNothing,
      );
    });
  }

  for (final owned in [false, true]) {
    p.proTest(
      'Settings inline badges, order and offline Pro navigation $owned',
      (t) async {
        final fake = p.FakeHabitStore()
          ..value = p.FakeHabitStore.snapshot('unavailable', pro: owned);
        await p.bootPro(t, fake: fake, open: false, width: 1440);
        await host.go(t, '/settings');
        final groups = t
            .widget<HandyPage>(find.byType(HandyPage))
            .children
            .whereType<SettingsGroup>();
        expect(groups.map((g) => g.title), [
          'General',
          'Habits',
          'Make it yours',
          'Data',
          'Help',
          'About',
        ]);
        final group = groups.firstWhere((g) => g.title == 'Make it yours');
        expect(group.badge == null, owned);
        await tap(t, 'settings-pro');
        expect(host.route(t), '/pro');
      },
    );
  }

  p.proTest('unconfigured Settings Pro row still opens benefits', (t) async {
    await p.bootPro(t, configured: false, open: false);
    await host.go(t, '/settings');
    await t.scrollUntilVisible(
      find.byKey(const Key('settings-pro')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Upgrade to Pro'), findsOneWidget);
    await tap(t, 'settings-pro');
    expect(host.route(t), '/pro');
  });

  p.proTest('Pro convenience has one demo and Retry belongs with status', (
    t,
  ) async {
    final fake = p.FakeHabitStore()
      ..value = p.FakeHabitStore.snapshot('unavailable');
    await p.bootPro(t, fake: fake);
    await host.go(t, '/pro?feature=convenience');
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.byType(HabitProDemo), findsOneWidget);
    // On the stage and in its own row's still frame.
    expect(find.text('After morning: Water +1'), findsWidgets);
    expect(find.text('Handy Habit'), findsNothing);
    final purchase = find.byKey(const Key('pro-purchase'));
    // Restore on the left, Get Pro to its right, in one bar.
    expect(purchase, findsOneWidget);
    expect(
      t.getRect(find.byKey(const Key('pro-restore'))).right,
      lessThan(t.getRect(find.byKey(const Key('pro-buy'))).left),
    );
    expect(find.byKey(const Key('pro-retry')), findsOneWidget);
  });

  p.proTest('changing Pro feature mounts only one demo during transition', (
    t,
  ) async {
    await p.bootPro(t);
    await tap(t, 'pro-part-heatmap');
    await t.pump(const Duration(seconds: 1));
    await t.ensureVisible(find.byKey(const Key('pro-part-convenience')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pro-part-convenience')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    expect(find.byType(HabitProDemo), findsOneWidget);
    expect(
      t.widget<HabitProDemo>(find.byType(HabitProDemo)).feature.name,
      'convenience',
    );
    expect(find.text('Handy Habit'), findsNothing);
    await t.pumpAndSettle();
  });

  for (final locale in ['en', 'vi']) {
    p.proTest('Pro report uses short localized dates and plain copy $locale', (
      t,
    ) async {
      await p.bootPro(t, locale: locale);
      await host.go(t, '/pro?feature=reports');
      final text = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .join('\n');
      expect(text, isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));
      expect(text, isNot(contains('pair sizes on paper')));
    });
  }
}
