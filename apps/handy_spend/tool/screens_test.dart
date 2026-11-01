// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend/app.dart';
import 'package:handy_spend/controller.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
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

/// Frames of a transition, for the review GIFs.
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

const zone = 'Asia/Ho_Chi_Minh';
String at(int days) => localTimestamp(inDays(days), zone);

/// Day [d] of the month [months] away, as a date.
String dom(int months, int d) {
  final now = calendar(today());
  final m = DateTime.utc(now.year, now.month + months, 1);
  return day(DateTime.utc(m.year, m.month, d));
}

/// One person in Hồ Chí Minh City: pay on the 28th, rent on the 5th.
SpendState household() {
  Account acc(
    String id,
    String name,
    String type,
    int opening, {
    bool liquid = true,
  }) => Account(
    id: id,
    name: name,
    currency: 'VND',
    type: type,
    opening: BigInt.from(opening),
    asOf: inDays(-75),
    liquid: liquid,
  );
  Category cat(String id, String name, [String kind = 'expense']) => Category(
    id: id,
    name: name,
    kind: kind,
    color: '#3A6FD8',
    icon: 'category',
  );
  var n = 0;
  final entries = <Entry>[];
  void spend(
    int days,
    String account,
    int amount,
    String payee,
    String? category, {
    String kind = 'expense',
    String? to,
  }) => entries.add(
    Entry(
      id: 'e${++n}',
      account: account,
      kind: kind,
      amount: BigInt.from(kind == 'income' ? amount : -amount),
      when: at(days),
      payee: payee,
      category: category,
      toAccount: to,
      target: to == null ? null : BigInt.from(amount),
    ),
  );
  // Last pay day, then a month of ordinary life.
  for (final (d, a, v, p, c) in [
    (-66, 'vcb', 18000000, 'Lương tháng 8', 'pay'),
    (-35, 'vcb', 18000000, 'Lương tháng 9', 'pay'),
    (-4, 'vcb', 18000000, 'Lương tháng 10', 'pay'),
  ]) {
    spend(d, a, v, p, c, kind: 'income');
  }
  for (final (d, a, v, p, c) in [
    (-60, 'vcb', 5500000, 'Tiền nhà tháng 9', 'home'),
    (-31, 'vcb', 5500000, 'Tiền nhà tháng 10', 'home'),
    (-52, 'vcb', 742000, 'EVN tiền điện', 'bills'),
    (-21, 'vcb', 816000, 'EVN tiền điện', 'bills'),
    (-48, 'vcb', 220000, 'FPT Internet', 'bills'),
    (-17, 'vcb', 220000, 'FPT Internet', 'bills'),
    (-40, 'momo', 1250000, 'Co.op Mart', 'food'),
    (-26, 'momo', 980000, 'Bách Hóa Xanh', 'food'),
    (-12, 'momo', 1130000, 'Co.op Mart', 'food'),
    (-3, 'momo', 640000, 'Bách Hóa Xanh', 'food'),
    (-38, 'cash', 45000, 'Phở Hòa', 'food'),
    (-29, 'cash', 55000, 'Highlands Coffee', 'food'),
    (-22, 'cash', 35000, 'Bánh mì Huỳnh Hoa', 'food'),
    (-14, 'cash', 59000, 'Highlands Coffee', 'food'),
    (-9, 'cash', 65000, 'Cơm tấm Ba Ghiền', 'food'),
    (-6, 'cash', 45000, 'Phở Hòa', 'food'),
    (-2, 'cash', 32000, 'Cà phê sữa đá', 'food'),
    (-1, 'cash', 39000, 'Bánh cuốn', 'food'),
    (-33, 'momo', 72000, 'Grab', 'ride'),
    (-18, 'momo', 58000, 'Grab', 'ride'),
    (-8, 'momo', 64000, 'Grab', 'ride'),
    (-2, 'momo', 81000, 'Be', 'ride'),
    (-25, 'vib', 1490000, 'Uniqlo', 'shop'),
    (-11, 'vib', 359000, 'Shopee', 'shop'),
    (-20, 'vib', 260000, 'Netflix', 'fun'),
    (-16, 'cash', 180000, 'CGV Vincom', 'fun'),
    (0, 'cash', 35000, 'Highlands Coffee', 'food'),
    (0, 'momo', 76000, 'Grab', 'ride'),
  ]) {
    spend(d, a, v, p, c);
  }
  spend(
    -30,
    'vcb',
    3000000,
    'Gửi tiết kiệm',
    null,
    kind: 'transfer',
    to: 'save',
  );
  spend(-28, 'vcb', 2000000, 'Nạp MoMo', null, kind: 'transfer', to: 'momo');
  spend(-7, 'vcb', 1500000, 'Rút tiền mặt', null, kind: 'transfer', to: 'cash');
  Bill bill(
    String id,
    String name,
    String account,
    int amount,
    int dayOfMonth, {
    String? category,
    bool reliable = false,
    String? to,
  }) => Bill(
    id: id,
    name: name,
    account: account,
    amount: BigInt.from(amount),
    due: dom(dayOfMonth < calendar(today()).day ? 1 : 0, dayOfMonth),
    frequency: 'monthly',
    category: category,
    reliable: reliable,
    remind: amount < 0,
    toAccount: to,
    target: to == null ? null : BigInt.from(-amount),
  );
  return SpendState(
    accounts: [
      acc('cash', 'Tiền mặt', 'cash', 900000),
      acc('vcb', 'Vietcombank', 'bank', 3200000),
      acc('momo', 'MoMo', 'wallet', 3500000),
      acc('save', 'Tiết kiệm', 'savings', 24000000, liquid: false),
      acc('vib', 'Thẻ VIB', 'credit', 0, liquid: false),
    ],
    categories: [
      cat('food', 'Ăn uống'),
      cat('ride', 'Đi lại'),
      cat('home', 'Nhà ở'),
      cat('bills', 'Hóa đơn'),
      cat('shop', 'Mua sắm'),
      cat('fun', 'Giải trí'),
      cat('pay', 'Lương', 'income'),
    ],
    entries: entries,
    bills: [
      bill('rent', 'Tiền nhà', 'vcb', -5500000, 5, category: 'home'),
      bill('power', 'Tiền điện', 'vcb', -800000, 12, category: 'bills'),
      bill('net', 'FPT Internet', 'vcb', -220000, 15, category: 'bills'),
      bill('netflix', 'Netflix', 'vib', -260000, 20, category: 'fun'),
      bill(
        'pay',
        'Lương',
        'vcb',
        18000000,
        28,
        category: 'pay',
        reliable: true,
      ),
      bill('saving', 'Gửi tiết kiệm', 'vcb', -3000000, 29, to: 'save'),
    ],
    goals: [
      Goal(
        id: 'trip',
        name: 'Đà Lạt dịp Tết',
        account: 'vcb',
        due: inDays(80),
        target: BigInt.from(6000000),
        reserved: BigInt.from(2000000),
      ),
    ],
    budgets: [
      Budget(
        id: 'food',
        name: 'Ăn uống',
        currency: 'VND',
        start: dom(-1, 1),
        end: dom(0, 1),
        limit: BigInt.from(4000000),
        category: 'food',
      ),
    ],
    rules: [
      {'id': 'r1', 'contains': 'grab', 'category': 'ride'},
      {'id': 'r2', 'contains': 'highlands', 'category': 'food'},
    ],
    settings: {'buffer': '500000', 'currency': 'VND', 'zone': zone},
  );
}

Future<SpendController> boot(
  WidgetTester t,
  Size size, {
  String theme = 'light',
  SpendState? state,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final c = SpendController(
    open: () async => TestSpendStore()..value = state ?? household(),
  );
  await c.load();
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: SpendApp(
        controller: c,
        files: Files(),
        preferences: Preferences('vi')
          ..value = HandyPreferences(locale: 'vi', theme: theme),
        privacy: NoLock(),
        enableDrop: false,
      ),
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  return c;
}

Future<void> area(WidgetTester t, int i) async {
  final wide = t.view.physicalSize.width >= HandySpace.wide;
  await tapKey(t, wide ? 'area-$i' : 'nav-$i');
}

void main() {
  setUpAll(() async {
    const fonts = '../../packages/handy_ui/fonts';
    await _font('packages/handy_ui/Geist', [
      '$fonts/Geist-Regular.ttf',
      '$fonts/Geist-Medium.ttf',
      '$fonts/Geist-Bold.ttf',
    ]);
    await _font('packages/handy_ui/GeistMono', [
      '$fonts/GeistMono-Regular.ttf',
    ]);
    await _font('packages/handy_ui/Bricolage', [
      '$fonts/BricolageGrotesque-Medium.ttf',
      '$fonts/BricolageGrotesque-Display.ttf',
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
    testWidgets('$label today', (t) async {
      await boot(t, size);
      await shot(t, '$label-1-today');
    });
    testWidgets('$label ledger', (t) async {
      await boot(t, size);
      await area(t, 1);
      await tapKey(t, 'month-prev');
      await shot(t, '$label-2-ledger');
    });
    testWidgets('$label plan', (t) async {
      await boot(t, size);
      await area(t, 2);
      await shot(t, '$label-3-plan');
    });
    testWidgets('$label accounts', (t) async {
      await boot(t, size);
      await area(t, 3);
      await shot(t, '$label-4-accounts');
    });
  }
  testWidgets('phone record', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'spend-add');
    await t.enterText(find.byKey(const Key('field-amount')), '45k');
    await t.enterText(find.byKey(const Key('field-payee')), 'High');
    await t.pumpAndSettle();
    await shot(t, 'phone-5-record');
  });
  testWidgets('desktop record', (t) async {
    await boot(t, const Size(1440, 900));
    await tapKey(t, 'spend-add');
    await t.enterText(find.byKey(const Key('field-amount')), '1.250.000');
    await t.pumpAndSettle();
    await shot(t, 'desktop-5-record');
  });
  testWidgets('phone ledger month', (t) async {
    await boot(t, const Size(390, 844));
    await area(t, 1);
    await tapKey(t, 'month-prev');
    await t.scrollUntilVisible(
      find.byKey(const Key('spend-search')),
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await shot(t, 'phone-6-ledger-rows');
  });
  testWidgets('phone account', (t) async {
    await boot(t, const Size(390, 844));
    await area(t, 3);
    await tapKey(t, 'account-vcb');
    await shot(t, 'phone-7-account');
  });
  testWidgets('phone what-if', (t) async {
    final c = await boot(t, const Size(390, 844));
    await area(t, 2);
    await tapKey(t, 'whatif-purchase');
    await t.enterText(
      find.byKey(const Key('field-name')),
      'iPhone trả góp 6 tháng',
    );
    await t.enterText(find.byKey(const Key('field-cost')), '27.000.000');
    await t.enterText(find.byKey(const Key('field-installments')), '6');
    await t.pumpAndSettle();
    await shot(t, 'phone-8-purchase');
    await tapKey(t, 'editor-save');
    await tapKey(t, 'whatif-${c.state!.scenarios.single.id}');
    await shot(t, 'phone-9-whatif');
  });
  testWidgets('phone settings', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'open-settings');
    await shot(t, 'phone-10-settings');
  });
  testWidgets('phone first run', (t) async {
    await boot(t, const Size(390, 844), state: SpendState());
    await shot(t, 'phone-11-first-run');
  });
  testWidgets('phone short', (t) async {
    final s = household();
    await boot(
      t,
      const Size(390, 844),
      state: s.copy({
        'goals': [
          {
            ...s.goals.single.toJson(),
            'reserved': '35000000',
            'target': '35000000',
          },
        ],
      }),
    );
    await shot(t, 'phone-12-short');
  });
  testWidgets('phone dark', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await shot(t, 'phone-13-dark');
    await area(t, 2);
    await shot(t, 'phone-14-dark-plan');
  });
  testWidgets('desktop settings', (t) async {
    await boot(t, const Size(1440, 900));
    await tapKey(t, 'open-settings');
    await shot(t, 'desktop-6-settings');
  });
  testWidgets('films', (t) async {
    await boot(t, const Size(390, 844));
    await film(t, 'phone-open-record', () async {
      await t.tap(find.byKey(const Key('spend-add')));
      await t.pump();
    });
  });
}
