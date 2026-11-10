// Host raster evidence only. Store responses are synthetic; no device involved.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_store/handy_store.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import '../test/pro_test.dart' as f;
import '../test/run13_smart_studio_test.dart' show smartSeed;
import '../test/run3_ui_test.dart' as host;
import '../test/run4_routines_test.dart' show tap;
import 'run10_screens_test.dart' show fonts;

final root = GlobalKey();
HabitState rasterSeed(String locale) {
  final vi = locale == 'vi', base = smartSeed();
  final walk = Habit(
    id: 'walk',
    title: vi ? 'Đi bộ ngoài trời' : 'Walk outside',
    created: '2023-10-01',
    category: vi ? 'Vận động' : 'Movement',
    schedules: [Schedule(id: 'walk-s', from: '2023-10-01')],
  );
  return base.copy({
    'habits': [
      base.habits.single.copy({
        'title': vi ? 'Đọc 6 trang' : 'Read 6 pages',
        'category': vi ? 'Học tập' : 'Learning',
      }).toJson(),
      walk.toJson(),
    ],
    'settings': {
      ...base.settings,
      'habitDayParts': {'read': 'morning', 'walk': 'evening'},
    },
    'events': [
      for (final e in base.events) e.toJson(),
      for (var i = 0; i < 99; i++)
        if (i % 7 < 5)
          HabitEvent(
            id: 'walk-e$i',
            habit: 'walk',
            day: addDays(walk.created, i),
            value: 1000,
          ).toJson(),
    ],
  });
}

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 1000));
  await t.pump(const Duration(milliseconds: 300));
  await t.runAsync(() async {
    final boundary =
        root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final im = await boundary.toImage(pixelRatio: 1.25);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    final folder = Platform.environment['SHOTS_DIR'] ?? 'build/run13/round1';
    Directory(folder).createSync(recursive: true);
    File('$folder/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    im.dispose();
  });
  expect(t.takeException(), isNull, reason: name);
}

Future<void> focus(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder.first);
  await t.pump(const Duration(milliseconds: 400));
  Scrollable.ensureVisible(t.element(finder.first), alignment: 0);
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(fonts);
  for (final width in [320.0, 390.0, 1440.0])
    for (final locale in ['en', 'vi'])
      for (final theme in ['light', 'dark'])
        for (final scale in [1.0, 1.5])
          testWidgets('run13 $width $locale $theme $scale', (t) async {
            debugDefaultTargetPlatformOverride = TargetPlatform.android;
            try {
              final (_, store, fake) = await f.bootPro(
                t,
                open: false,
                boundary: root,
                state: rasterSeed(locale),
                width: width,
                locale: locale,
                theme: theme,
                scale: scale,
              );
              final stem =
                  '${width.toInt()}-$locale-$theme-${scale == 1 ? 100 : 150}';
              await host.go(t, '/pro');
              await shot(t, '$stem-pro-ready');
              for (final (state, reason) in [
                ('pending', ''),
                ('owned', ''),
                ('canceled', ''),
                ('error', 'verification_failed'),
                ('unavailable', 'store_unavailable'),
              ]) {
                store.accept(
                  f.FakeHabitStore.snapshot(
                    state,
                    pro: state == 'owned',
                    reason: reason,
                    price: state == 'pending' ? '99.000 đ' : null,
                  ),
                );
                await shot(t, '$stem-pro-$state');
              }
              store.accept(
                f.FakeHabitStore.snapshot('ready', price: '99.000 đ'),
              );
              fake.gate = Completer<StoreSnapshot>();
              unawaited(store.action('read'));
              await shot(t, '$stem-pro-loading');
              fake.gate!.complete(fake.value);
              fake.gate = null;
              await t.pumpAndSettle();
              fake.gate = Completer<StoreSnapshot>();
              await t.tap(find.byKey(const Key('pro-restore')));
              await shot(t, '$stem-pro-restore');
              fake.gate!.complete(fake.value);
              fake.gate = null;
              await t.pumpAndSettle();
              await shot(t, '$stem-pro-not-found');
              store.accept(f.FakeHabitStore.snapshot('unavailable', pro: true));
              await shot(t, '$stem-pro-offline-owned');
              debugDefaultTargetPlatformOverride = TargetPlatform.windows;
              store.accept(fake.value);
              await shot(t, '$stem-pro-unsupported');
              debugDefaultTargetPlatformOverride = TargetPlatform.android;
              store.accept(fake.value);
              await t.pump();
              for (final feature in ['comparisons', 'mood', 'studio']) {
                await tap(t, 'pro-part-$feature');
                await focus(t, find.byKey(const Key('pro-demo-input')));
                await shot(t, '$stem-pro-demo-$feature');
              }
              store.accept(fake.value);
              await host.go(t, '/progress/smart');
              await shot(t, '$stem-insights-free');
              store.accept(f.FakeHabitStore.snapshot('owned', pro: true));
              await t.pumpAndSettle();
              await shot(t, '$stem-insights-month');
              await tap(t, 'smart-quarter');
              await shot(t, '$stem-insights-quarter');
              for (final title in [
                locale == 'en'
                    ? 'Morning and evening · last 28 days'
                    : 'Sáng và tối · 28 ngày qua',
                locale == 'en'
                    ? 'By collection · last 28 days'
                    : 'Theo nhóm · 28 ngày qua',
                locale == 'en'
                    ? 'Difficulty & missed weekdays'
                    : 'Độ khó & thứ hay lỡ',
                locale == 'en'
                    ? 'Mood alongside habits'
                    : 'Tâm trạng cùng thói quen',
              ]) {
                final heading = find.text(title);
                await focus(t, heading);
                await t.tap(heading);
                await t.pumpAndSettle();
                await focus(t, heading);
                await shot(
                  t,
                  '$stem-insights-${title.startsWith('Mood') || title.startsWith('Tâm')
                      ? 'mood'
                      : title.startsWith('Morning') || title.startsWith('Sáng')
                      ? 'groups'
                      : title.startsWith('By') || title.startsWith('Theo')
                      ? 'collections'
                      : 'patterns'}',
                );
              }
              await focus(t, find.byKey(const Key('smart-filter-collection-')));
              await shot(t, '$stem-insights-filters');
              await tap(t, 'smart-report');
              await shot(t, '$stem-report');
              host.nav(t).pop();
              await t.pumpAndSettle();
              await host.go(t, '/settings/studio');
              await shot(t, '$stem-studio-top');
              await tap(t, 'studio-palette-grove');
              await tap(t, 'studio-layout-cards');
              await shot(t, '$stem-studio-picker');
              await tap(t, 'studio-palette-ochre');
              await tap(t, 'studio-spacing-airy');
              await focus(t, find.byKey(const Key('studio-preview')));
              await shot(t, '$stem-studio-ochre');
              await tap(t, 'studio-icon-leaf');
              await shot(t, '$stem-studio-icons');
              store.accept(fake.value);
              await shot(t, '$stem-studio-free');
            } finally {
              debugDefaultTargetPlatformOverride = null;
            }
          });
}
