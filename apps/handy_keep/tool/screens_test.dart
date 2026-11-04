// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_keep/app.dart';
import 'package:handy_keep/inventory/keep_store.dart' show today;
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../test/helpers.dart';

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

/// Frames of a transition, for the review GIFs: [action] starts it, then
/// one frame every [step] for [frames] frames (`name-film-000.png`…).
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

/// Brings a keyed widget on screen without tapping it.
Future<void> reveal(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
}

String day(int n) => DateTime.parse(
  '${today()}T00:00:00Z',
).add(Duration(days: n)).toIso8601String().substring(0, 10);

/// A household in the middle of a move.
KeepState household() {
  var s = emptyKeepState();
  s = saveBox(
    s,
    InventoryBox(id: 'b1', name: 'Thùng 1 · Đồ bếp', location: 'Phòng khách'),
  );
  s = saveBox(
    s,
    InventoryBox(id: 'b2', name: 'Thùng 2 · Sách', location: 'Gác xép'),
  );
  s = saveBox(
    s,
    InventoryBox(id: 'b3', name: 'Thùng 3', location: 'Hành lang'),
  );
  var n = 0;
  void add(String name, [Map<String, Object?> f = const {}]) =>
      s = saveAsset(s, createAsset(id: 'i${++n}', name: name, fields: f));
  add('Nồi cơm điện', {
    'boxId': 'b1',
    'price': '1890000',
    'currency': 'VND',
    'purchasedOn': day(-400),
    'warrantyUntil': day(330),
  });
  add('Bộ dao Nhật', {'boxId': 'b1', 'price': '2400000', 'currency': 'VND'});
  add('Máy xay sinh tố', {'boxId': 'b1', 'price': '990000', 'currency': 'VND'});
  add('Sách nấu ăn', {'boxId': 'b2'});
  add('Lò vi sóng', {
    'location': 'Tủ bếp',
    'purchasedOn': day(-718),
    'warrantyUntil': day(12),
    'serial': 'MW-2291-0457',
    'price': '2790000',
    'currency': 'VND',
  });
  add('Máy lọc nước', {
    'location': 'Tủ bếp',
    'maintenanceDue': day(20),
    'price': '6500000',
    'currency': 'VND',
  });
  add('Loa bluetooth', {
    'location': 'Kệ tivi',
    'price': '1200000',
    'currency': 'VND',
  });
  add('Ổ cứng di động 2 TB', {
    'location': 'Ngăn kéo bàn làm việc',
    'serial': 'WX41A82',
    'price': '89.99',
    'currency': 'USD',
  });
  add('Thang nhôm', {'location': 'Gác xép'});
  add('Máy khoan pin', {
    'location': 'Gác xép',
    'borrower': 'Lan',
    'lentOn': day(-19),
    'returnDue': day(-5),
    'notes': 'Kèm hai viên pin và hộp mũi khoan.',
    'price': '1650000',
    'currency': 'VND',
  });
  add('Lều cắm trại', {
    'location': 'Gác xép',
    'borrower': 'Minh',
    'lentOn': day(-3),
    'returnDue': day(9),
    'price': '1100000',
    'currency': 'VND',
  });
  add('Thước dây');
  return s;
}

/// The household plus two collections, one with a target and wishes.
KeepState collector() {
  var s = household();
  s = saveCollection(
    s,
    InventoryCollection(
      id: 'cars',
      name: 'Xe mô hình 1:64',
      kind: 'models',
      hue: 3,
      target: 24,
    ),
  );
  s = saveCollection(
    s,
    InventoryCollection(id: 'books', name: 'Tủ sách', kind: 'books', hue: 2),
  );
  var n = 0;
  void add(String name, String col, [Map<String, Object?> f = const {}]) =>
      s = saveAsset(
        s,
        createAsset(
          id: 'c${++n}',
          name: name,
          fields: {
            'profile': 'collectible',
            'collections': [col],
            if ((f['status'] ?? 'owned') == 'owned') 'location': 'Kệ kính',
            ...f,
          },
        ),
      );
  add('Supra đỏ', 'cars', {'series': 'Phố đêm', 'number': '12'});
  add('Civic Type R trắng', 'cars', {'series': 'Phố đêm', 'number': '7'});
  add('GT-R xanh dương', 'cars', {'series': 'Đường đua', 'number': '3'});
  add('Xe buýt hai tầng', 'cars', {'variant': 'Bản giới hạn'});
  add('Xe cứu hỏa', 'cars', {'condition': 'Còn hộp'});
  add('Xe tải chở kem', 'cars');
  add('RX-7 vàng', 'cars', {'status': 'ordered'});
  add('911 xanh lá', 'cars', {
    'status': 'wanted',
    'priority': 'high',
    'budget': '450000',
    'budgetCurrency': 'VND',
  });
  add('Xe đua F1 đen', 'cars', {'status': 'wanted', 'priority': 'low'});
  for (final b in ['Dế Mèn phiêu lưu ký', 'Truyện Kiều', 'Số đỏ', 'Tắt đèn']) {
    add(b, 'books');
  }
  return s;
}

Future<void> boot(
  WidgetTester t,
  Size size, {
  String theme = 'light',
  KeepState? state,
  Files? files,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: KeepApp(
        documents: Store()..text = serializeKeepState(state ?? household()),
        files: files ?? Files(),
        camera: Camera(),
        preferences: Preferences()
          ..value = HandyPreferences(locale: 'vi', theme: theme),
        reminders: testReminders(),
      ),
    ),
  );
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
    await _font('BeVietnamPro', [
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
    testWidgets('$label home', (t) async {
      await boot(t, size);
      if (size.width >= 900) await tapKey(t, 'item-i10');
      await shot(t, '$label-1-home');
    });
    testWidgets('$label boxes', (t) async {
      await boot(t, size);
      await tapKey(t, 'filter-boxes');
      await shot(t, '$label-2-boxes');
    });
  }
  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('narrow', const Size(320, 700)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label collection', (t) async {
      await boot(t, size, state: collector());
      await tapKey(t, 'shelf-cars');
      await shot(t, '$label-c2-collection');
    });
  }
  testWidgets('phone shelf', (t) async {
    await boot(t, const Size(390, 844), state: collector());
    await reveal(t, 'collection-shelf');
    await shot(t, 'phone-c1-shelf');
  });
  testWidgets('phone shelf empty', (t) async {
    await boot(t, const Size(390, 844));
    await reveal(t, 'shelf-start');
    await shot(t, 'phone-c0-shelf-empty');
  });
  testWidgets('phone dark collection', (t) async {
    await boot(t, const Size(390, 844), state: collector(), theme: 'dark');
    await tapKey(t, 'shelf-cars');
    await shot(t, 'phone-c3-collection-dark');
  });
  testWidgets('phone wishlist', (t) async {
    await boot(t, const Size(390, 844), state: collector());
    await tapKey(t, 'shelf-wishlist');
    await shot(t, 'phone-c4-wishlist');
  });
  testWidgets('phone wanted item', (t) async {
    await boot(t, const Size(390, 844), state: collector());
    await tapKey(t, 'shelf-cars');
    await tapKey(t, 'collection-item-c8');
    await shot(t, 'phone-c5-wanted-item');
  });
  testWidgets('phone collector editor', (t) async {
    await boot(t, const Size(390, 844), state: collector());
    await tapKey(t, 'shelf-cars');
    await tapKey(t, 'collection-add');
    await reveal(t, 'item-series');
    await shot(t, 'phone-c6-editor');
  });
  testWidgets('phone item', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'item-i5');
    await shot(t, 'phone-3-item');
  });
  testWidgets('phone editor', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'item-new');
    await t.enterText(find.byKey(const Key('item-name')), 'Bàn ủi hơi nước');
    await t.enterText(find.byKey(const Key('item-location')), 't');
    await t.pumpAndSettle();
    await shot(t, 'phone-4-editor');
  });
  testWidgets('phone label', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'filter-boxes');
    await tapKey(t, 'box-menu-b1');
    await tapKey(t, 'box-label');
    await shot(t, 'phone-5-label');
  });
  // Nothing chosen on a wide screen: the pane lists every date.
  testWidgets('desktop dates', (t) async {
    await boot(t, const Size(1440, 900));
    await shot(t, 'desktop-6-dates');
  });
  testWidgets('desktop settings', (t) async {
    await boot(t, const Size(1440, 900));
    await tapKey(t, 'open-settings');
    await shot(t, 'desktop-7-settings');
  });
  testWidgets('phone lend', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'item-i9');
    await tapKey(t, 'item-lend');
    await t.enterText(find.byKey(const Key('lend-who')), 'Hùng');
    await t.pumpAndSettle();
    await shot(t, 'phone-10-lend');
  });
  testWidgets('desktop editor', (t) async {
    await boot(t, const Size(1440, 900));
    await tapKey(t, 'item-i5');
    await tapKey(t, 'item-edit');
    await shot(t, 'desktop-11-editor');
  });
  testWidgets('films', (t) async {
    await boot(t, const Size(390, 844));
    await reveal(t, 'item-i5');
    await film(t, 'phone-open-item', () async {
      await t.tap(find.byKey(const Key('item-i5')));
      await t.pump();
    });
    await film(t, 'phone-take-back', () async {
      Navigator.of(t.element(find.byKey(const Key('item-view')))).pop();
      await t.pumpAndSettle();
      await tapKey(t, 'item-i10');
      await t.tap(find.byKey(const Key('item-return')));
      await t.pump();
    });
  });
  testWidgets('desktop film', (t) async {
    await boot(t, const Size(1440, 900));
    await tapKey(t, 'item-i5');
    await reveal(t, 'item-i7');
    await film(t, 'desktop-pick-item', () async {
      await t.tap(find.byKey(const Key('item-i7')));
      await t.pump();
    });
    await t.drag(find.byType(ListView).first, const Offset(0, 4000));
    await t.pumpAndSettle();
    await film(t, 'desktop-filter', () async {
      await t.tap(find.byKey(const Key('filter-boxes')));
      await t.pump();
    });
  });
  testWidgets('phone list menu', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'keep-list-menu');
    await shot(t, 'phone-12-menu');
  });
  testWidgets('phone lent value', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'filter-lent');
    await shot(t, 'phone-13-lent');
  });
  testWidgets('phone batch start', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'keep-list-menu');
    await tapKey(t, 'batch-add');
    await shot(t, 'phone-14-batch-start');
  });
  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('narrow', const Size(320, 640)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label batch review', (t) async {
      final files = Files()
        ..nextMany = [
          ImportedBytes('IMG_2041.jpg', pngBytes),
          ImportedBytes('IMG_2042.jpg', pngBytes),
          ImportedBytes('IMG_2043.heic', Uint8List.fromList([0, 0, 0, 24])),
          ImportedBytes('IMG_2044.jpg', pngBytes),
        ];
      await boot(t, size, files: files);
      await tapKey(t, 'filter-boxes');
      await tapKey(t, 'box-menu-b2');
      await tapKey(t, 'box-batch-add');
      await tapKey(t, 'batch-files');
      await t.enterText(
        find.byKey(const Key('batch-name-0')),
        'Từ điển Anh Việt',
      );
      await t.enterText(find.byKey(const Key('batch-name-1')), 'Truyện Kiều');
      await tapKey(t, 'batch-save');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await shot(t, '$label-15-batch-review');
    });
  }
  testWidgets('phone editor price', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'item-i5');
    await tapKey(t, 'item-edit');
    await reveal(t, 'item-price');
    await shot(t, 'phone-16-editor-price');
  });
  testWidgets('narrow boxes', (t) async {
    await boot(t, const Size(320, 640));
    await tapKey(t, 'filter-boxes');
    await shot(t, 'narrow-17-boxes');
  });
  testWidgets('phone dark', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await shot(t, 'phone-8-dark');
  });
  testWidgets('phone empty', (t) async {
    await boot(t, const Size(390, 844), state: emptyKeepState());
    await shot(t, 'phone-9-empty');
  });
}
