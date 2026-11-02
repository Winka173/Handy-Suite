import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards/app.dart';
import 'package:handy_boards/controller.dart';
import '../test/ui_test.dart' as fixtures;

final boundary = GlobalKey();
Future<void> shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await t.runAsync(() async {
    final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary,
        im = await render.toImage(pixelRatio: 1.5),
        bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/shots')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    im.dispose();
  });
}

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths)
    loader.addFont(
      Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
    );
  await loader.load();
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
    await loadFont('packages/handy_ui/Bricolage', [
      '$root/BricolageGrotesque-Medium.ttf',
      '$root/BricolageGrotesque-Display.ttf',
    ]);
    await loadFont('PlusJakartaSans', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    await loadFont('MaterialIcons', [
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });
  for (final (name, width, locale, theme, scale) in [
    ('phone', 375.0, 'en', 'light', 1.0),
    ('large-phone', 430.0, 'en', 'light', 1.0),
    ('narrow-vi', 320.0, 'vi', 'light', 1.0),
    ('large-text', 320.0, 'vi', 'light', 2.0),
    ('tablet', 768.0, 'en', 'light', 1.0),
    ('desktop', 1440.0, 'en', 'light', 1.0),
    ('dark', 1024.0, 'vi', 'dark', 1.0),
  ])
    testWidgets('$name product review', (t) async {
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final c = BoardsController(
        open: () async =>
            fixtures.TestStore(fixtures.sample(locale: locale, theme: theme)),
      );
      await c.load();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: BoardsApp(
            controller: c,
            clock: () => DateTime.utc(2026, 11, 2),
          ),
        ),
      );
      await shot(t, '$name-categories');
      for (final (en, vi, id) in [
        ('Kanban', 'Kanban', 'kanban'),
        ('List', 'Danh sách', 'list'),
        ('Table', 'Bảng dữ liệu', 'table'),
      ]) {
        await fixtures.tap(
          t,
          find.widgetWithText(ChoiceChip, locale == 'vi' ? vi : en),
        );
        await shot(t, '$name-$id');
      }
      for (final (en, vi, id) in [
        ('Today', 'Hôm nay', 'today'),
        ('Calendar', 'Lịch', 'calendar'),
        ('Insights', 'Thống kê', 'insights'),
      ]) {
        await fixtures.tap(t, find.text(locale == 'vi' ? vi : en).last);
        await shot(t, '$name-$id');
      }
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
}
