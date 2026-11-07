// SHOTS_DIR=<dir> flutter test --no-pub tool/story_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/design/identity.dart';
import 'package:handy_boards/design/theme.dart';
import 'package:handy_boards/welcome/motion.dart';
import 'package:handy_boards/welcome/story_scene.dart';
import 'package:handy_ui/kit.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
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

  for (final size in [const Size(360, 520), const Size(600, 840)]) {
    for (final locale in ['vi', 'en']) {
      testWidgets('story $locale ${size.width.toInt()}×${size.height.toInt()}', (
        t,
      ) async {
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
            for (var frame = 0; frame < 50; frame++) {
              await t.pump(const Duration(milliseconds: 16));
              expect(t.takeException(), isNull, reason: 'flight frame $frame');
            }
          }
          await t.pumpAndSettle();
          // Give the bundled icon's decode a real event-loop turn.
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          final directory = Platform.environment['SHOTS_DIR'];
          if (directory != null && directory.isNotEmpty) {
            await t.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              Directory(directory).createSync(recursive: true);
              final name =
                  '$locale-$state-${size.width.toInt()}x${size.height.toInt()}';
              File(
                '$directory/$name.png',
              ).writeAsBytesSync(data!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      });
    }
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
}
