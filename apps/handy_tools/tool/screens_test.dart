// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_tools/app.dart';
import 'package:handy_ui/kit.dart';
import '../test/pilot_test.dart'
    show FixtureFiles, MemoryPreferences, QrTestDocuments;

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

final _root = GlobalKey();

Future<void> shot(WidgetTester t, String name, {bool settle = true}) async {
  final dir = Platform.environment['SHOTS_DIR'] ?? 'build/shots';
  Directory(dir).createSync(recursive: true);
  if (settle) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await t.pump();
  }
  await t.runAsync(() async {
    final b =
        _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> boot(WidgetTester t, Size size, {String theme = 'light'}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final repo = MemoryPreferences()
    ..state = HandyPreferences(
      theme: theme,
      locale: 'vi',
      favorites: ['split-bill', 'loan', 'units'],
    );
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: HandyToolsApp(
        repository: repo,
        files: FixtureFiles(),
        qrHistoryDocuments: QrTestDocuments(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> enter(WidgetTester t, String text, {bool submit = true}) async {
  await t.enterText(find.byKey(const Key('bench-input')), text);
  await t.pumpAndSettle();
  if (submit) {
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
  }
}

Future<void> openTool(WidgetTester t, String id) async {
  await t.tap(find.byKey(const Key('open-catalog')));
  await t.pumpAndSettle();
  final row = find.byKey(Key('catalog-$id'));
  await t.scrollUntilVisible(
    row,
    120,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.tap(row);
  await t.pumpAndSettle();
}

Future<void> type(WidgetTester t, String key, String text) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.enterText(find.byKey(Key(key)), text);
  await t.pumpAndSettle();
}

Future<void> fillTape(WidgetTester t) async {
  await enter(t, '1.385.000 / 3');
  await enter(t, '15% của 2.400.000');
  await enter(t, '4 x 125.000');
  await enter(t, '5 km sang mi');
  await enter(t, '1.385.000 / 3', submit: false);
}

/// Frames of a transition for the review GIFs (`name-film-000.png`…).
Future<void> film(
  WidgetTester t,
  String name,
  Future<void> Function() action, {
  int frames = 16,
  Duration step = const Duration(milliseconds: 25),
}) async {
  await action();
  for (var i = 0; i < frames; i++) {
    await shot(t, '$name-film-${i.toString().padLeft(3, '0')}', settle: false);
    await t.pump(step);
  }
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    const ui = '../../packages/handy_ui/fonts';
    await _font('packages/handy_ui/Geist', [
      '$ui/Geist-Regular.ttf',
      '$ui/Geist-Medium.ttf',
      '$ui/Geist-Bold.ttf',
    ]);
    await _font('packages/handy_ui/GeistMono', ['$ui/GeistMono-Regular.ttf']);
    await _font('packages/handy_ui/Bricolage', [
      '$ui/BricolageGrotesque-Medium.ttf',
      '$ui/BricolageGrotesque-Display.ttf',
    ]);
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    await _font('MaterialIcons', [
      '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(768, 1024)),
    ('laptop', const Size(1024, 768)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label empty', (t) async {
      await boot(t, size);
      await shot(t, '$label-1-empty');
    });
    testWidgets('$label working', (t) async {
      await boot(t, size);
      await fillTape(t);
      await shot(t, '$label-2-working');
    });
    testWidgets('$label text chain', (t) async {
      await boot(t, size);
      await enter(
        t,
        'Nguyễn Văn An\nnguyễn văn an\nTrần Thị Bình',
        submit: false,
      );
      await t.tap(find.byKey(const Key('transform-accents')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('transform-title-case')));
      await t.pumpAndSettle();
      await shot(t, '$label-3-chain');
    });
    testWidgets('$label loan form', (t) async {
      await boot(t, size);
      await openTool(t, 'loan');
      await type(t, 'field-principal', '250000000');
      await type(t, 'field-rate', '9.5');
      await type(t, 'field-months', '24');
      await t.scrollUntilVisible(
        find.byKey(const Key('bench-answer')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await shot(t, '$label-4-loan');
    });
    testWidgets('$label qr', (t) async {
      await boot(t, size);
      await openTool(t, 'qr');
      await t.tap(find.byKey(const Key('qr-mode-wifi')));
      await t.pumpAndSettle();
      await type(t, 'qr-field-0', 'Nha Minh 5G');
      await type(t, 'qr-field-1', 'bep-ga-2026');
      await shot(t, '$label-5-qr');
    });
    testWidgets('$label password', (t) async {
      await boot(t, size);
      await openTool(t, 'password');
      await shot(t, '$label-6-password');
    });
    testWidgets('$label catalog', (t) async {
      await boot(t, size);
      await t.tap(find.byKey(const Key('open-catalog')));
      await t.pumpAndSettle();
      await shot(t, '$label-7-catalog');
    });
    testWidgets('$label settings', (t) async {
      await boot(t, size);
      await t.tap(find.byKey(const Key('open-settings')));
      await t.pumpAndSettle();
      await shot(t, '$label-8-settings');
    });
  }
  testWidgets('phone dark working', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await fillTape(t);
    await shot(t, 'phone-9-dark');
  });
  testWidgets('films', (t) async {
    await boot(t, const Size(390, 844));
    await film(t, 'phone-answer', () async {
      await t.enterText(
        find.byKey(const Key('bench-input')),
        '15% của 2.400.000',
      );
      await t.pump();
    });
    await film(t, 'phone-tape', () async {
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
    });
    await film(t, 'phone-catalog', () async {
      await t.tap(find.byKey(const Key('open-catalog')).first);
      await t.pump();
    });
  });
}
