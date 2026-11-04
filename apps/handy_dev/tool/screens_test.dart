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

Future<void> boot(
  WidgetTester t,
  Size size, {
  String theme = 'light',
  String? history,
}) async {
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
            favorites: ['jwt', 'json-filter'],
          ),
        files: Files(),
        documents: store,
        history: Store()..text = history,
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
    await _font('SpaceGrotesk', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
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
  // The utility lenses (timestamp, IDs, diff, cron, bases, URL, HMAC).
  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label timestamp', (t) async {
      await boot(t, size);
      await paste(t, '1730505600');
      await shot(t, '$label-7-timestamp');
    });
    testWidgets('$label ids', (t) async {
      await boot(t, size);
      await tap(t, 'make-v7');
      await t.enterText(find.byKey(const Key('id-count')), '6');
      await tap(t, 'id-generate');
      await shot(t, '$label-8-ids');
    });
    testWidgets('$label diff', (t) async {
      await boot(t, size);
      await paste(
        t,
        'service: billing\nreplicas: 3\nimage: billing:1.8\nport: 8080\n'
        'log: info\ntimeout: 30s\nretries: 2\nregion: sg\nowner: payments',
      );
      await tap(t, 'kind-text');
      await tap(t, 'lens-text-diff');
      await t.enterText(
        find.byKey(const Key('lens-option')),
        'service: billing\nreplicas: 5\nimage: billing:1.9\nport: 8080\n'
        'log: info\ntimeout: 30s\nretries: 2\nregion: sg\nowner: payments\n'
        'canary: true',
      );
      await t.pumpAndSettle();
      await shot(t, '$label-9-diff');
    });
    testWidgets('$label cron', (t) async {
      await boot(t, size);
      await paste(t, '*/15 9-17 * * 1-5');
      await shot(t, '$label-10-cron');
    });
    testWidgets('$label bases', (t) async {
      await boot(t, size);
      await paste(t, '-42');
      await tap(t, 'pick-bits-16');
      await shot(t, '$label-11-bases');
    });
    testWidgets('$label url', (t) async {
      await boot(t, size);
      await paste(
        t,
        'https://shop.example.vn/search?q=%C3%A1o+m%C6%B0a&size=M&utm_source=zalo#results',
      );
      await t.enterText(find.byKey(const Key('query-value-1')), 'L');
      await t.pumpAndSettle();
      await shot(t, '$label-12-url');
    });
    testWidgets('$label hmac', (t) async {
      await boot(t, size);
      await paste(t, '{"event":"order.paid","order":1042,"total":607000}');
      await tap(t, 'lens-hmac');
      await t.enterText(find.byKey(const Key('lens-option')), 'whsec_demo');
      await t.pumpAndSettle();
      await shot(t, '$label-13-hmac');
    });
  }
  testWidgets('phone bases error', (t) async {
    await boot(t, const Size(390, 844));
    await paste(t, '0x1ff');
    await tap(t, 'pick-bits-8');
    await shot(t, 'phone-14-error');
  });
  testWidgets('phone dark diff', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await paste(t, 'a\nb\nc');
    await tap(t, 'lens-text-diff');
    await t.enterText(find.byKey(const Key('lens-option')), 'a\nB\nc\nd');
    await t.pumpAndSettle();
    await shot(t, 'phone-15-dark-diff');
  });
  testWidgets('phone json broken', (t) async {
    await boot(t, const Size(390, 844));
    await paste(t, '{\n  "id": 1042,\n  "items": [1, 2],\n}');
    await shot(t, 'phone-16-json-broken');
  });
  testWidgets('phone sent history', (t) async {
    var h = SendHistory(on: true);
    final at = DateTime(2026, 11, 4, 9, 12);
    for (final (i, (id, status, ms)) in [
      ('r1', 200, 84),
      ('r2', 422, 131),
      ('r1', null, 0),
      ('r3', 200, 240),
    ].indexed) {
      final r = [
        ApiRequest(
          id: 'r1',
          name: 'Đơn hàng 1042',
          url: 'https://api.example.com/v1/orders/1042?expand=items',
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
          url: 'https://api.example.com/v1/customers?page=2',
        ),
      ].firstWhere((r) => r.id == id);
      h = recordSend(
        h,
        r,
        at: at.add(Duration(minutes: 7 * i)),
        status: status,
        elapsedMs: ms,
        bytes: status == null ? 0 : 1840,
      );
    }
    await boot(t, const Size(390, 844), history: exportSendHistory(h));
    await t.tap(find.byKey(const Key('area')));
    await t.tap(find.text('Request').last);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('sent-3')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-17-sent');
  });
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
      await t.tap(find.byKey(const Key('lens-convert')));
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
