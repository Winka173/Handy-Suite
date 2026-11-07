// SHOTS_DIR=<dir> flutter test --no-pub tool/story_test.dart
// STORY_TEST_AHEM=1 also checks Flutter's wider fallback test font.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/design/identity.dart';
import 'package:handy_boards/design/theme.dart';
import 'package:handy_boards/welcome/motion.dart';
import 'package:handy_boards/welcome/story_scene.dart';
import 'package:handy_boards/welcome/welcome_page.dart';
import 'package:handy_ui/kit.dart';

// Keep the real soft flight shadows in these visual checks.
class _StoryBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

// Same real-font loading helper as screens_test.dart.
Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

Future<void> shot(WidgetTester t, GlobalKey boundary, String name) async {
  final directory = Platform.environment['SHOTS_DIR'];
  if (directory == null || directory.isEmpty) return;
  await t.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(directory).createSync(recursive: true);
    File('$directory/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  _StoryBinding();
  setUpAll(() async {
    const root = '../../packages/handy_ui/fonts';
    if (Platform.environment['STORY_TEST_AHEM'] != '1') {
      await loadFont('packages/handy_ui/Geist', [
        '$root/Geist-Regular.ttf',
        '$root/Geist-Medium.ttf',
        '$root/Geist-Bold.ttf',
      ]);
      await loadFont('PlusJakartaSans', [
        for (final f in Directory('fonts').listSync())
          if (f.path.endsWith('.ttf')) f.path,
      ]);
    }
    final flutter =
        Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/Winka/flutter';
    await loadFont('MaterialIcons', [
      '$flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final size in [const Size(360, 520), const Size(600, 840)]) {
    for (final locale in ['vi', 'en']) {
      testWidgets(
        'story $locale ${size.width.toInt()}×${size.height.toInt()}',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final boundary = GlobalKey();
          var gathered = false;
          late StateSetter update;
          await t.pumpWidget(
            HandyApp(
              app: 'handy_boards',
              title: 'Handy Boards',
              accent: GuideColors.teal,
              brand: boardsIdentity,
              locale: locale,
              theme: 'light',
              themeOverride: boardsTheme,
              home: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Scaffold(
                    backgroundColor: GuideColors.paper,
                    body: RepaintBoundary(
                      key: boundary,
                      child: SizedBox.expand(
                        child: ColoredBox(
                          color: GuideColors.paper,
                          child: BeatStage(
                            child: BoardsStoryScene(
                              key: const ValueKey('story'),
                              gathered: gathered,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          for (final state in ['scattered', 'gathered']) {
            if (state == 'gathered') {
              update(() => gathered = true);
              await t.pump();
              // Exercise the actual flight, including its mid-size layouts.
              for (var frame = 0; frame < 75; frame++) {
                await t.pump(const Duration(milliseconds: 16));
                expect(
                  t.takeException(),
                  isNull,
                  reason: 'flight frame $frame',
                );
                if (size.width == 360 && [14, 29, 44].contains(frame)) {
                  await shot(
                    t,
                    boundary,
                    '$locale-flight-${(frame + 1) * 16}ms',
                  );
                }
              }
            }
            await t.pumpAndSettle();
            // Give the bundled icon's decode a real event-loop turn.
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            await shot(
              t,
              boundary,
              '$locale-$state-${size.width.toInt()}x${size.height.toInt()}',
            );
            if (state == 'gathered') {
              final cards = [
                for (final title in [
                  'Revise chapter 3',
                  'Hand in maths',
                  'Buy markers',
                  'Hand in the essay',
                  'Call the AC repair',
                ])
                  t.getRect(find.byKey(ValueKey('story-card-$title'))),
              ];
              expect(
                cards.map((r) => r.height.round()).toSet().length,
                greaterThan(2),
              );
              expect(cards[3].top, greaterThan(cards[1].bottom));
              expect(cards[4].top, greaterThan(cards[0].bottom));
              expect(cards[2].height, lessThan(cards[0].height));
            }
          }
        },
      );
    }
  }

  for (final locale in ['vi', 'en']) {
    testWidgets('actual guide $locale 390x844', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final boundary = GlobalKey();
      await t.pumpWidget(
        HandyApp(
          app: 'handy_boards',
          title: 'Handy Boards',
          accent: GuideColors.teal,
          brand: boardsIdentity,
          locale: locale,
          theme: 'light',
          themeOverride: boardsTheme,
          home: RepaintBoundary(
            key: boundary,
            child: WelcomePage(onDone: (_) async {}),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await shot(t, boundary, '$locale-guide-scattered-390x844');
      await t.tap(find.byKey(const Key('welcome-primary')));
      await t.pump();
      for (var frame = 0; frame < 100; frame++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(t.takeException(), isNull, reason: 'guide flight frame $frame');
      }
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await shot(t, boundary, '$locale-guide-gathered-390x844');
      final scene = t.getRect(find.byType(BoardsStoryScene));
      for (final card
          in find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                      'story-card-',
                    ),
              )
              .evaluate()) {
        final rect = t.getRect(find.byWidget(card.widget));
        expect(scene.contains(rect.topLeft), isTrue);
        expect(scene.contains(rect.bottomRight), isTrue);
      }
    });
  }

  for (final gathered in [false, true]) {
    testWidgets('reduced motion rests with clock at zero: $gathered', (
      t,
    ) async {
      t.view.physicalSize = const Size(360, 520);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final boundary = GlobalKey();

      Future<List<int>> pixels({required bool reduced}) async {
        await t.pumpWidget(
          MaterialApp(
            theme: boardsTheme(ThemeData.light()),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 520),
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(reduced ? 2.4 : 1),
                ),
                child: Beat(
                  clock: AlwaysStoppedAnimation(reduced ? 0.0 : 1.0),
                  child: RepaintBoundary(
                    key: boundary,
                    child: SizedBox.expand(
                      child: BoardsStoryScene(gathered: gathered),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        return (await t.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final data = await image.toByteData();
          final bytes = data!.buffer.asUint8List();
          image.dispose();
          return bytes;
        }))!;
      }

      final resting = await pixels(reduced: false);
      expect(
        await pixels(reduced: true),
        orderedEquals(resting),
        reason:
            'Reduced motion and large system text must preserve the end-state picture',
      );
    });
  }

  testWidgets('enabling reduced motion during flight settles immediately', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 520);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var gathered = false, reduced = false;
    late StateSetter update;
    await t.pumpWidget(
      MaterialApp(
        theme: boardsTheme(ThemeData.light()),
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: Scaffold(body: BoardsStoryScene(gathered: gathered)),
            );
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    update(() => gathered = true);
    await t.pump();
    await t.pump(const Duration(milliseconds: 320));
    final card = find.byKey(const ValueKey('story-card-Revise chapter 3'));
    final inFlight = t.getRect(card);
    update(() => reduced = true);
    await t.pump();
    final rested = t.getRect(card);
    expect(rested, isNot(inFlight));
    await t.pump(const Duration(seconds: 2));
    expect(t.getRect(card), rested);
    expect(t.takeException(), isNull);
    // Going back, even immediately after the setting changes, also rests.
    update(() => gathered = false);
    await t.pump();
    final scrap = t.getRect(find.text('Buy markers').last);
    await t.pump(const Duration(seconds: 2));
    expect(t.getRect(find.text('Buy markers').last), scrap);
    expect(t.takeException(), isNull);
  });
}
