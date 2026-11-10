import 'dart:io';
import 'dart:ui' show ImageByteFormat;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'ui_test.dart' show start, seeded, tapKey, MemoryStore;
import 'safety_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSafetyFonts);
  for (final width in [320.0, 1440.0]) {
    for (final locale in ['en', 'vi']) {
      for (final theme in ['light', 'dark']) {
        testWidgets(
          'trash $width $locale $theme fits with large text and reduced motion',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = 1.5;
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const FakeAccessibilityFeatures(disableAnimations: true);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
            final now = DateTime.utc(2024, 1, 8, 12);
            final store = MemoryStore()
              ..value = trashEntity(seeded(), 'habit', 'h', now).copy({
                'settings': {
                  'onboarded': true,
                  'locale': locale,
                  'theme': theme,
                },
              });
            final c = HabitController(
              open: () async => store,
              clock: () => now,
            );
            await c.load();
            const boundary = Key('trash-capture');
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: HabitApp(controller: c, clock: () => now),
              ),
            );
            await tester.pumpAndSettle();
            Navigator.of(
              tester.element(find.byType(Scaffold).first),
            ).pushNamed('/settings/trash');
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(Key('trash-restore-${c.state!.trash.single.id}')),
              findsOneWidget,
            );
            if (Platform.environment['HABIT_RUN2_SHOTS']
                case final String directory) {
              final render = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(boundary),
              );
              await tester.runAsync(() async {
                final shot = await render.toImage();
                final bytes = await shot.toByteData(
                  format: ImageByteFormat.png,
                );
                final file = File(
                  '$directory/trash-${width.toInt()}-$locale-$theme.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                shot.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox());
            c.dispose();
          },
        );
      }
    }
  }
  testWidgets(
    'trash restores with links; permanent-delete cancel preserves row',
    (tester) async {
      final now = DateTime.utc(2024, 1, 8, 12);
      final c = await start(tester);
      await c.change((_) => trashEntity(seeded(), 'habit', 'h', now));
      Navigator.of(
        tester.element(find.byType(Scaffold).first),
      ).pushNamed('/settings');
      await tester.pumpAndSettle();
      await tapKey(tester, 'habit-trash');
      expect(find.textContaining('30 days left'), findsOneWidget);
      final id = c.state!.trash.single.id;
      await tapKey(tester, 'trash-delete-$id');
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(c.state!.trash, hasLength(1));
      await tapKey(tester, 'trash-restore-$id');
      expect(c.state!.trash, isEmpty);
      expect(c.state!.liveHabits.single.id, 'h');
      expect(c.state!.routines.single.steps.first.habit, isNotNull);
    },
  );
}
