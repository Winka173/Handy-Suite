// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev/app.dart';
import 'package:handy_dev/http_transport.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../test/helpers.dart' show DevPreferences, Files, Store;

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
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
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

const _order =
    '{"order": 1042, "customer": {"name": "Trần Bình", "city": "Đà Nẵng"}, '
    '"items": [{"sku": "A-17", "qty": 2, "price": 129000}, {"sku": "B-03", "qty": 1, "price": 349000}], '
    '"paid": true, "total": 607000}';

Future<void> boot(WidgetTester t, Size size, {String theme = 'light'}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final ws = ApiWorkspace(
    requests: [
      ApiRequest(
        id: 'r1',
        name: 'Đơn hàng 1042',
        url: 'https://api.example.com/v1/orders/1042',
      ),
      ApiRequest(
        id: 'r2',
        name: 'Tạo đơn',
        url: 'https://api.example.com/v1/orders',
        method: 'POST',
      ),
      ApiRequest(
        id: 'r3',
        name: 'Danh sách khách',
        url: 'https://api.example.com/v1/customers',
      ),
    ],
  );
  final store = Store()
    ..text = exportWorkspace(
      saveRequest(
        saveRequest(saveRequest(ws, ws.requests[0]), ws.requests[1]),
        ws.requests[2],
      ),
    );
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: DevApp(
        preferences: DevPreferences()
          ..value = HandyPreferences(
            theme: theme,
            locale: 'vi',
            favorites: ['jwt', 'jsonpath'],
          ),
        files: Files(),
        documents: store,
        transport: HttpTransport(
          clientFactory: () => MockClient(
            (_) async => http.Response.bytes(
              utf8.encode(_order),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> paste(WidgetTester t, String s) async {
  await t.enterText(find.byKey(const Key('dev-input')), s);
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key)).first;
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
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
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label empty', (t) async {
      await boot(t, size);
      await shot(t, '$label-1-empty');
    });
    testWidgets('$label json', (t) async {
      await boot(t, size);
      await paste(t, _order);
      await tap(t, r'tree-row-$.items');
      await tap(t, r'tree-row-$.items[0]');
      await shot(t, '$label-2-json');
    });
    testWidgets('$label jwt', (t) async {
      await boot(t, size);
      await paste(
        t,
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyLTQyIiwicm9sZSI6ImFkbWluIiwiZXhwIjoxNzk4NzYxNjAwfQ.',
      );
      await shot(t, '$label-3-jwt');
    });
    testWidgets('$label yaml', (t) async {
      await boot(t, size);
      await paste(
        t,
        'service: billing\nreplicas: 3\nports:\n  - 8080\n  - 9090',
      );
      await shot(t, '$label-4-yaml');
    });
    testWidgets('$label request', (t) async {
      await boot(t, size);
      await t.tap(find.byKey(const Key('area')));
      await t.tap(find.text('Request').last);
      await t.pumpAndSettle();
      await tap(t, 'request-r1');
      await tap(t, 'send');
      await shot(t, '$label-5-request');
    });
  }
  testWidgets('phone dark json', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await paste(t, _order);
    await shot(t, 'phone-6-dark');
  });
  testWidgets('films', (t) async {
    await boot(t, const Size(1440, 900));
    await film(t, 'desktop-paste', () async {
      await t.enterText(find.byKey(const Key('dev-input')), _order);
      await t.pump();
    });
    await film(t, 'desktop-lens', () async {
      await t.tap(find.byKey(const Key('lens-json-yaml')));
      await t.pump();
    });
    await film(t, 'desktop-send', () async {
      await t.tap(find.byKey(const Key('area')));
      await t.tap(find.text('Request').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('request-r1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('send')));
      await t.pump();
    }, frames: 20);
  });
}
