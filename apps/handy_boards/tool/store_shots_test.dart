// Google Play phone screenshots: 1080 × 2160 (360 × 720 at 3x), English
// and Vietnamese, from the real app with the sample library of
// screens_test.dart. Nothing here touches lib/.
//
//   STORE_DIR=<dir> flutter test --no-pub tool/store_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import 'screens_test.dart'
    show boundary, sample, boot, tap, loadFont, settle, board;

Future<void> store(WidgetTester t, String name) async {
  await settle(t);
  expect(t.takeException(), isNull, reason: name);
  await t.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final im = await render.toImage(pixelRatio: 3);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['STORE_DIR'] ?? 'build/store')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    im.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
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

  const size = Size(360, 720);
  for (final lang in ['en', 'vi']) {
    final vi = lang == 'vi';
    testWidgets('store $lang', (t) async {
      final c = await boot(t, sample(locale: lang), size: size);
      await store(t, '$lang-1-home');
      await tap(t, find.byKey(const Key('board-$board')));
      await store(t, '$lang-2-board');
      // The time span: tapping the week's dates opens its settings.
      await tap(t, find.byKey(const Key('week-setup')));
      await store(t, '$lang-3-time');
      await t.binding.handlePopRoute();
      await settle(t);
      final card = topTasks(c.state!, board: board).first;
      await tap(t, find.text(card.str('title')).first);
      await store(t, '$lang-4-card');
      await t.binding.handlePopRoute();
      await settle(t);
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).popUntil((r) => r.isFirst);
      await settle(t);
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).pushNamed('/templates');
      await settle(t);
      await store(t, '$lang-5-templates');
      await tap(t, find.byKey(const Key('template-semester')));
      await store(t, '$lang-6-preview');
    });
  }
}
