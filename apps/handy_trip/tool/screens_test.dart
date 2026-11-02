// Render actual product screens with test-owned data and bundled fonts.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_trip/app.dart';
import 'package:handy_trip/controller.dart';
import 'package:handy_trip/features/sharing/memory_book.dart';
import 'package:handy_trip/features/passport/stamp_export.dart';
import 'package:handy_trip/features/passport/stamp_studio.dart';
import 'package:handy_trip/features/trips/replay.dart';
import 'package:handy_trip/features/media/photo_proposal.dart';
import '../test/ui_test.dart' as fixtures;
import '../test/memory_ui_test.dart' as memories;

final boundary = GlobalKey();
Future<void> font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

Future<void> shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await t.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/shots')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.trip/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
    const fonts = '../../packages/handy_ui/fonts';
    await font('packages/handy_ui/Geist', [
      '$fonts/Geist-Regular.ttf',
      '$fonts/Geist-Medium.ttf',
      '$fonts/Geist-Bold.ttf',
    ]);
    await font('packages/handy_ui/Bricolage', [
      '$fonts/BricolageGrotesque-Medium.ttf',
      '$fonts/BricolageGrotesque-Display.ttf',
    ]);
    await font('packages/handy_ui/GeistMono', ['$fonts/GeistMono-Regular.ttf']);
    await font('Archivo', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    await font('MaterialIcons', [
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });
  for (final (name, width, height, locale, theme) in [
    ('phone', 390.0, 844.0, 'en', 'light'),
    ('narrow-vi', 320.0, 812.0, 'vi', 'light'),
    ('tablet', 768.0, 1024.0, 'en', 'light'),
    ('desktop', 1440.0, 1000.0, 'en', 'light'),
    ('dark', 1024.0, 900.0, 'en', 'dark'),
  ]) {
    testWidgets('$name product review', (t) async {
      t.view.physicalSize = Size(width, height);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = TripController(
        open: () async => fixtures.MemoryStore(
          memories.seeded().copy({
            'settings': {'onboarded': true, 'locale': locale, 'theme': theme},
          }),
        ),
      );
      await c.load();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: TripApp(
            controller: c,
            clock: () => DateTime.utc(2026, 11, 2, 2, 30),
          ),
        ),
      );
      await shot(t, '$name-trips');
      for (final (en, vi, id) in [
        ('Explore', 'Địa điểm', 'explore'),
        ('Journal', 'Nhật ký', 'journal'),
        ('Passport', 'Hộ chiếu', 'passport'),
        ('Trips', 'Chuyến đi', 'trips-return'),
      ]) {
        await fixtures.tap(t, find.text(locale == 'vi' ? vi : en).last);
        if (id != 'trips-return') await shot(t, '$name-$id');
      }
      await fixtures.tap(t, find.text('Three days by the sea').first);
      await shot(t, '$name-overview');
      for (final (en, vi, id) in [
        ('Itinerary', 'Lịch trình', 'itinerary'),
        ('Packing', 'Hành lý', 'packing'),
        ('Bookings', 'Đặt chỗ', 'bookings'),
        ('Expenses', 'Chi tiêu', 'expenses'),
      ]) {
        await fixtures.tap(
          t,
          find.widgetWithText(ChoiceChip, locale == 'vi' ? vi : en),
        );
        await shot(t, '$name-$id');
      }
      await t.pumpWidget(const SizedBox());
      final scope = fixtures.makeScope(c)..chooseTrip('t');
      for (final (id, open) in <(String, Future<void> Function(BuildContext))>[
        ('stamp', (context) => exportPersonalStamp(context, scope, 'v')),
        ('stamp-studio', (context) => openStampStudio(context, scope, 'v')),
        ('memory-book', (context) => exportMemoryBook(context, scope, 't')),
        ('replay', (context) => showTripReplay(context, scope, 't')),
        (
          'exif',
          (context) =>
              showPhotoProposal(context, scope, scope.state.assets.first.key),
        ),
      ]) {
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: HandyApp(
              brand: HandyBrand.trip,
              app: 'trip',
              title: 'Handy Trip',
              accent: const Color(0xff0284c7),
              locale: locale,
              theme: theme,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => open(context),
                    child: const Text('Open review'),
                  ),
                ),
              ),
            ),
          ),
        );
        await fixtures.tap(t, find.text('Open review'));
        await shot(t, '$name-$id');
        await t.pumpWidget(const SizedBox());
      }
      scope.dispose();
      c.dispose();
    });
  }
}
