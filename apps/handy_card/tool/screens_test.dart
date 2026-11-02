// Review shots of Handy Card with its real faces:
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card/app.dart';
import 'package:handy_card/data/store.dart';
import 'package:handy_card/editor/canvas.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/card_flow_test.dart' show MemoryFiles;

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

final boundary = GlobalKey();

Future<void> shot(WidgetTester t, String name) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await t.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final im = await render.toImage(pixelRatio: 1.5);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/shots')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    im.dispose();
  });
}

CardProfile profile() => CardProfile(
  id: 'anh',
  displayName: 'Nguyễn Minh Anh',
  role: 'Kiến trúc sư',
  organization: 'Studio Ánh Minh',
  phones: const [ProfileValue('cell', '0912 345 678')],
  emails: const [ProfileValue('', 'minhanh@example.com')],
  websites: const [ProfileValue('', 'minhanh.example.com')],
  addresses: const [ProfileValue('', '12 Nguyễn Huệ, Quận 1, TP.HCM')],
);

Future<MemoryCardStore> seeded() async {
  final store = MemoryCardStore();
  final r = ElementRegistry.standard();
  final p = profile();
  await store.put(
    'profile',
    p.id,
    '{"id":"anh","displayName":"Nguyễn Minh Anh","role":"Kiến trúc sư","organization":"Studio Ánh Minh","phones":[{"label":"cell","value":"0912 345 678"}],"emails":[{"label":"","value":"minhanh@example.com"}],"websites":[{"label":"","value":"minhanh.example.com"}],"addresses":[{"label":"","value":"12 Nguyễn Huệ, Quận 1, TP.HCM"}]}',
  );
  for (final (i, id) in ['minimal', 'gradient', 'elegant', 'badge'].indexed) {
    final t = cardTemplates.firstWhere((x) => x.id == id);
    final d = t
        .build(r, DateTime.utc(2026, 11, 2 - i))
        .copyWith(
          name: t.vi,
          profileId: p.id,
          updatedAt: '2026-11-0${2 - i % 2}T0$i:00:00Z',
        );
    await store.put('design', d.id, d.encode());
  }
  return store;
}

Future<void> boot(
  WidgetTester t,
  Size size,
  CardStore store, {
  String locale = 'vi',
  String theme = 'light',
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await store.put('settings', 'app', '{"locale":"$locale","theme":"$theme"}');
  await t.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: CardApp(
        store: store,
        files: MemoryFiles(),
        clock: () => DateTime.utc(2026, 11, 2, 9),
      ),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    const ui = '../../packages/handy_ui/fonts';
    await loadFont('HankenGrotesk', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        'fonts/HankenGrotesk-$w.ttf',
    ]);
    await loadFont('CardSerif', [
      'fonts/Literata-Regular.ttf',
      'fonts/Literata-Bold.ttf',
    ]);
    await loadFont('packages/handy_ui/Bricolage', [
      '$ui/BricolageGrotesque-Medium.ttf',
      '$ui/BricolageGrotesque-Display.ttf',
    ]);
    await loadFont('packages/handy_ui/GeistMono', [
      '$ui/GeistMono-Regular.ttf',
    ]);
    await loadFont('packages/handy_ui/Geist', [
      '$ui/Geist-Regular.ttf',
      '$ui/Geist-Medium.ttf',
      '$ui/Geist-Bold.ttf',
    ]);
    await loadFont('MaterialIcons', [
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$name home empty', (t) async {
      await boot(t, size, MemoryCardStore());
      await shot(t, '$name-1-home-empty');
    });
    testWidgets('$name home', (t) async {
      await boot(t, size, await seeded());
      await shot(t, '$name-2-home');
    });
    testWidgets('$name studio', (t) async {
      final store = await seeded();
      await boot(t, size, store);
      final id = store.records['design']!.entries
          .firstWhere((e) => e.value.contains('Hiện đại'))
          .key;
      t
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/design/$id');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await t.pumpAndSettle();
      await shot(t, '$name-3-studio');
      // Select the name and look at the inspector (or its sheet on a phone).
      final canvas = t.getRect(find.byType(CardCanvas));
      await t.tapAt(Offset(canvas.center.dx - 40, canvas.center.dy - 10));
      await t.pumpAndSettle();
      await shot(t, '$name-4-selected');
      if (name == 'phone') {
        await t.tap(find.byKey(const Key('bar-edit')));
        await t.pumpAndSettle();
        await shot(t, '$name-5-inspector');
      }
    });
    testWidgets('$name export', (t) async {
      await boot(t, size, await seeded());
      await t.tap(find.textContaining('Tối giản').first);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('studio-export')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('export-pdf')));
      await t.pumpAndSettle();
      await shot(t, '$name-6-export');
    });
    testWidgets('$name new and profile', (t) async {
      await boot(t, size, await seeded());
      await t.tap(find.byKey(const Key('home-new')));
      await t.pumpAndSettle();
      await shot(t, '$name-7-new');
      await t.tap(find.text('Hủy').last);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Nguyễn Minh Anh').last,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Nguyễn Minh Anh').last);
      await t.pumpAndSettle();
      await shot(t, '$name-8-profile');
    });
  }
  testWidgets('dark studio', (t) async {
    await boot(t, const Size(1440, 900), await seeded(), theme: 'dark');
    await t.tap(find.textContaining('Thẻ hội nghị').first);
    await t.pumpAndSettle();
    await shot(t, 'dark-studio');
  });
}
