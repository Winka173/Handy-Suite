import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/pro/entitlements.dart';
import 'package:handy_habit/pro/pro_demos.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_store/handy_store.dart';
import 'package:handy_ui/kit.dart';
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;
import 'ui_test.dart' as f;

/// Synthetic host responses, never evidence of a verified store transaction.
class FakeHabitStore implements LifetimeStorePort {
  static const product = 'handy_habit_pro';
  StoreSnapshot value = snapshot('ready', price: '99.000 đ');
  Completer<StoreSnapshot>? gate;
  bool fail = false, disposed = false;
  int buys = 0, restores = 0, reads = 0;
  void Function(StoreSnapshot)? listener;
  static StoreSnapshot snapshot(
    String status, {
    String? price,
    bool pro = false,
    String reason = '',
  }) => StoreSnapshot(
    status: status,
    productId: product,
    price: price,
    owned: pro,
    verified: pro,
    reason: reason,
  );
  Future<StoreSnapshot> result() async {
    if (fail) throw PlatformException(code: 'offline');
    return gate == null ? value : gate!.future;
  }

  @override
  Future<StoreSnapshot> read() {
    reads++;
    return result();
  }

  @override
  Future<StoreSnapshot> purchase() {
    buys++;
    return result();
  }

  @override
  Future<StoreSnapshot> restore() {
    restores++;
    return result();
  }

  @override
  void listen(void Function(StoreSnapshot) handler) => listener = handler;
  void emit(StoreSnapshot value) => listener?.call(value);
  @override
  Future<void> dispose() async {
    disposed = true;
    listener = null;
  }
}

class TestAds implements AdProvider {
  @override
  Widget banner(LifetimeController model) => const Text('test banner');
  @override
  void privacyOptions(LifetimeController model) {}
}

Future<(HabitController, LifetimeController, FakeHabitStore)> bootPro(
  WidgetTester t, {
  HabitState? state,
  Key? boundary,
  bool open = true,
  FakeHabitStore? fake,
  bool loading = false,
  double width = 390,
  double scale = 1,
  String locale = 'en',
  String theme = 'light',
  bool configured = true,
  f.MemoryStore? memoryStore,
}) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final memory = (memoryStore ?? f.MemoryStore())
    ..value = (state ?? f.seeded()).copy({
      'settings': {
        ...(state ?? f.seeded()).settings,
        'onboarded': true,
        'locale': locale,
        'theme': theme,
      },
    });
  final c = HabitController(open: () async => memory, clock: () => host.now);
  await c.load();
  final port = fake ?? FakeHabitStore();
  final store = LifetimeController(
    MonetizationConfig(productId: configured ? FakeHabitStore.product : ''),
    port,
  );
  store.accept(port.value);
  await t.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: HabitApp(
        controller: c,
        clock: () => host.now,
        device: false,
        lifetime: store,
      ),
    ),
  );
  await t.pumpAndSettle();
  if (open) await host.go(t, '/pro');
  if (loading) {
    port.gate = Completer<StoreSnapshot>();
    unawaited(store.action('read'));
    await t.pump();
  }
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
    store.dispose();
  });
  return (c, store, port);
}

void proTest(String name, WidgetTesterCallback body) =>
    testWidgets(name, (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await body(t);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

void main() {
  proTest('wide Help uses a full index before opening an article pane', (
    t,
  ) async {
    await bootPro(t, open: false, width: 1440);
    await host.go(t, '/help');
    expect(
      t.getSize(find.byKey(const Key('help-topic-start'))).width,
      greaterThan(600),
    );
    await tap(t, 'help-topic-start');
    expect(find.byKey(const Key('help-article-start')), findsOneWidget);
  });

  proTest('verified Pro removes the shared advertising slot', (t) async {
    final port = FakeHabitStore();
    final store = LifetimeController(
      const MonetizationConfig(
        productId: FakeHabitStore.product,
        adsEnabled: true,
      ),
      port,
    );
    final previous = HandyAdSlot.provider;
    HandyAdSlot.provider = TestAds();
    try {
      await t.pumpWidget(
        MaterialApp(
          home: LifetimeScope(notifier: store, child: const LifetimeBanner()),
        ),
      );
      expect(find.text('test banner'), findsOneWidget);
      store.accept(FakeHabitStore.snapshot('owned', pro: true));
      await t.pump();
      expect(find.text('test banner'), findsNothing);
    } finally {
      HandyAdSlot.provider = previous;
      await t.pumpWidget(const SizedBox());
      store.dispose();
    }
  });

  for (final theme in ['light', 'dark']) {
    for (final locale in ['en', 'vi']) {
      proTest('Pro accessibility at 320 text1.5 $theme $locale', (t) async {
        final semantics = t.ensureSemantics();
        await bootPro(t, width: 320, scale: 1.5, theme: theme, locale: locale);
        await t.ensureVisible(find.byKey(const Key('pro-purchase')));
        await t.pumpAndSettle();
        for (final guideline in [
          labeledTapTargetGuideline,
          androidTapTargetGuideline,
          iOSTapTargetGuideline,
          textContrastGuideline,
        ]) {
          await expectLater(t, meetsGuideline(guideline));
        }
        semantics.dispose();
      });
    }
  }

  proTest('loading and unconfigured Android never enable checkout', (t) async {
    final (_, store, fake) = await bootPro(t, loading: true);
    expect(find.text('Loading store price and ownership…'), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('pro-buy'))).onPressed,
      isNull,
    );
    fake.gate!.complete(fake.value);
    fake.gate = null;
    await t.pumpAndSettle();
    expect(store.busy, false);
  });

  proTest('Android without monetization config says it is not on sale', (
    t,
  ) async {
    final (_, _, fake) = await bootPro(t, configured: false);
    expect(find.text('Pro is not on sale in this build yet.'), findsOneWidget);
    expect(find.byKey(const Key('pro-buy')), findsNothing);
    expect(fake.buys + fake.restores, 0);
  });

  proTest('reduced motion shows a final demo and still allows interaction', (
    t,
  ) async {
    final base = f.seeded();
    await bootPro(
      t,
      state: base.copy({
        'settings': {...base.settings, 'reducedMotion': true},
      }),
    );
    expect(find.text('Saturday'), findsOneWidget);
    await tap(t, 'pro-demo-toggle');
    expect(find.text('Monday'), findsOneWidget);
    await tap(t, 'pro-demo-play');
    expect(find.text('Saturday'), findsOneWidget);
    expect(t.binding.transientCallbackCount, 0);
  });

  test(
    'habit/android config and native channel carry the product, optional key and live price',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final config = MonetizationConfig.parse(
        '{"habit":{"android":{"productId":"handy_habit_pro","androidPublicKey":"public-test-key"}}}',
        'habit',
        'android',
      );
      const channel = MethodChannel('habit-store-test');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return {
              'status': 'ready',
              'productId': FakeHabitStore.product,
              'price': '99.000 đ',
              'owned': false,
              'verified': false,
            };
          });
      final store = NativeLifetimeStore(
        productId: config.productId,
        androidPublicKey: config.androidPublicKey,
        channel: channel,
      );
      expect((await store.read()).price, '99.000 đ');
      await store.purchase();
      await store.restore();
      expect(calls.map((c) => c.method), ['read', 'buy', 'restore']);
      expect(
        calls.every(
          (c) =>
              (c.arguments as Map)['productId'] == FakeHabitStore.product &&
              (c.arguments as Map)['publicKey'] == 'public-test-key',
        ),
        true,
      );
      await store.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  proTest(
    'live price, pending duplicate prevention, confirmed purchase then refund',
    (t) async {
      final (_, store, fake) = await bootPro(t);
      expect(find.text('Get Pro · 99.000 đ'), findsOneWidget);
      fake.value = FakeHabitStore.snapshot('pending', price: '99.000 đ');
      await tap(t, 'pro-buy');
      expect(fake.buys, 1);
      expect(store.pro, false);
      expect(
        t.widget<FilledButton>(find.byKey(const Key('pro-buy'))).onPressed,
        isNull,
      );
      expect(
        t.widget<TextButton>(find.byKey(const Key('pro-restore'))).onPressed,
        isNull,
      );
      fake.emit(FakeHabitStore.snapshot('owned', pro: true));
      await t.pumpAndSettle();
      expect(
        find.text('Pro is active on this device. Thank you.'),
        findsOneWidget,
      );
      expect(store.pro, true);
      expect(find.byKey(const Key('pro-retry')), findsNothing);
      fake.value = FakeHabitStore.snapshot('ready', price: '99.000 đ');
      await store.action('read');
      await t.pumpAndSettle();
      expect(store.pro, false);
      expect(find.byKey(const Key('pro-buy')), findsOneWidget);
    },
  );

  for (final status in ['canceled', 'error', 'unavailable']) {
    proTest('$status never grants Pro and offers recovery', (t) async {
      final (_, store, fake) = await bootPro(t);
      fake.value = FakeHabitStore.snapshot(status);
      await tap(t, 'pro-buy');
      expect(store.pro, false);
      final message = t.widget<Text>(find.byKey(const Key('pro-status'))).data!;
      expect(
        message,
        contains(
          status == 'canceled'
              ? 'cancelled'
              : status == 'error'
              ? 'could not confirm'
              : 'Store unavailable',
        ),
      );
      fake.value = FakeHabitStore.snapshot('ready', price: '99.000 đ');
      await tap(t, 'pro-retry');
      expect(find.text('Get Pro · 99.000 đ'), findsOneWidget);
    });
  }

  proTest('restore progress, no purchase, then restored entitlement', (
    t,
  ) async {
    final (_, store, fake) = await bootPro(t);
    fake.gate = Completer<StoreSnapshot>();
    await t.ensureVisible(find.byKey(const Key('pro-restore')));
    await t.tap(find.byKey(const Key('pro-restore')));
    await t.pump();
    expect(find.text('Restoring purchases…'), findsOneWidget);
    expect(store.pro, false);
    expect(
      t.widget<TextButton>(find.byKey(const Key('pro-restore'))).onPressed,
      isNull,
    );
    fake.gate!.complete(fake.value);
    fake.gate = null;
    await t.pumpAndSettle();
    expect(
      find.text('No Pro purchase found for this store account.'),
      findsOneWidget,
    );
    fake.value = FakeHabitStore.snapshot('owned', pro: true);
    await tap(t, 'pro-restore');
    expect(store.pro, true);
    expect(fake.restores, 2);
  });

  proTest(
    'offline exception preserves a prior verified owner, never creates one',
    (t) async {
      final (_, store, fake) = await bootPro(t);
      fake.fail = true;
      await tap(t, 'pro-restore');
      expect(store.pro, false);
      store.accept(FakeHabitStore.snapshot('owned', pro: true));
      await store.action('read');
      await t.pumpAndSettle();
      expect(store.pro, true);
      expect(
        find.textContaining('Offline · using verified ownership'),
        findsOneWidget,
      );
    },
  );

  proTest('foreign and unverified responses do not unlock', (t) async {
    final (_, store, fake) = await bootPro(t);
    fake.emit(
      const StoreSnapshot(
        status: 'owned',
        productId: 'another_app',
        owned: true,
        verified: true,
      ),
    );
    expect(store.pro, false);
    fake.emit(
      const StoreSnapshot(
        status: 'owned',
        productId: FakeHabitStore.product,
        owned: true,
      ),
    );
    await t.pumpAndSettle();
    expect(store.pro, false);
  });

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    proTest('$platform has an honest page and no checkout', (t) async {
      debugDefaultTargetPlatformOverride = platform;
      final (_, _, fake) = await bootPro(t);
      expect(find.text('Not available on this platform yet.'), findsOneWidget);
      expect(find.byKey(const Key('pro-buy')), findsNothing);
      expect(find.byKey(const Key('pro-restore')), findsNothing);
      expect(fake.buys + fake.restores + fake.reads, 0);
    });
  }

  proTest('unconfigured build and absent price cannot buy', (t) async {
    final fake = FakeHabitStore()..value = FakeHabitStore.snapshot('ready');
    await bootPro(t, fake: fake);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('pro-buy'))).onPressed,
      isNull,
    );
    expect(find.byKey(const Key('pro-retry')), findsOneWidget);
  });

  proTest('all demos play with engine results and never mutate real data', (
    t,
  ) async {
    final (c, _, _) = await bootPro(t);
    final before = c.state!.toJson();
    // The page lists nine parts; each plays its own demo.
    for (final f in [
      HabitProFeature.days,
      HabitProFeature.choices,
      HabitProFeature.blocks,
      HabitProFeature.comparisons,
      HabitProFeature.goals,
      HabitProFeature.mood,
      HabitProFeature.heatmap,
      HabitProFeature.studio,
      HabitProFeature.convenience,
    ]) {
      await tap(t, 'pro-part-${f.name}');
      expect(find.byKey(Key('pro-demo-${f.name}')), findsOneWidget);
      await tap(t, 'pro-demo-play');
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
    expect(c.state!.toJson(), before);
    final context = t.element(find.byKey(const Key('pro-demo-input')).first);
    expect(
      demoPlan(context, HabitProFeature.days, true).$2.single.note,
      'Skipped',
    );
    expect(
      demoPlan(context, HabitProFeature.durations, true).$2.single.seconds,
      900,
    );
    expect(
      demoPlan(context, HabitProFeature.dependencies, true).$2.last.note,
      'Ready',
    );
  });

  proTest(
    'builder draft survives badge, purchase and Back; gates update immediately',
    (t) async {
      final (c, store, fake) = await bootPro(t, open: false);
      await host.go(t, '/routine/r/edit');
      await t.enterText(
        find.byKey(const Key('field-title')),
        'My unsaved plan',
      );
      await tap(t, 'routine-advanced');
      await tap(t, 'pro-badge-blocks');
      expect(find.byKey(const Key('pro-demo-blocks')), findsOneWidget);
      fake.value = FakeHabitStore.snapshot('owned', pro: true);
      await tap(t, 'pro-buy');
      expect(store.pro, true);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('My unsaved plan'), findsOneWidget);
      expect(find.byKey(const Key('pro-badge-blocks')), findsNothing);
      expect(c.state!.routines.single.title, isNot('My unsaved plan'));
    },
  );

  proTest('every advanced badge opens its exact demo', (t) async {
    await bootPro(t, open: false);
    await host.go(t, '/routine/r/edit');
    await tap(t, 'routine-advanced');
    for (final f in [HabitProFeature.blocks, HabitProFeature.presets]) {
      await tap(t, 'pro-badge-${f.name}');
      expect(find.byKey(Key('pro-demo-${f.name}')), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
    }
    await tap(t, 'draft-edit-a');
    await tap(t, 'step-advanced');
    for (final f in HabitProFeature.values.where(
      (f) =>
          f.index < 9 &&
          f != HabitProFeature.blocks &&
          f != HabitProFeature.presets,
    )) {
      await tap(t, 'pro-badge-${f.name}');
      expect(find.byKey(Key('pro-demo-${f.name}')), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
    }
  });

  proTest('help replay rows and shell identity/contextual primary actions', (
    t,
  ) async {
    await bootPro(t, open: false);
    expect(find.byKey(const Key('habit-mark')), findsOneWidget);
    expect(find.text('New habit'), findsOneWidget);
    await host.go(t, '/routines');
    expect(find.text('New routine'), findsOneWidget);
    await host.go(t, '/help');
    expect(find.text('Watch the welcome again'), findsOneWidget);
    expect(find.text('Topics'), findsOneWidget);
    for (final tile in t.widgetList<ListTile>(find.byType(ListTile))) {
      expect(tile.subtitle, isNotNull);
      expect((tile.title! as Text).data, isNot(matches(r'^\d+\.')));
    }
  });
}
