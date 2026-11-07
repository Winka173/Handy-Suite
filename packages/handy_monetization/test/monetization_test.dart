import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_store/handy_store.dart';

class Store implements LifetimeStorePort {
  StoreSnapshot value = const StoreSnapshot(
    status: 'ready',
    productId: 'app.pro',
  );
  int calls = 0;
  bool fail = false;
  void Function(StoreSnapshot)? callback;
  @override
  void listen(void Function(StoreSnapshot) listener) => callback = listener;
  @override
  Future<StoreSnapshot> read() async {
    calls++;
    if (fail) throw StateError('Store unavailable');
    return value;
  }

  @override
  Future<StoreSnapshot> purchase() => read();
  @override
  Future<StoreSnapshot> restore() => read();
  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'per-app config rejects malformed IDs and never accepts imported Pro flags',
    () {
      final c = MonetizationConfig.parse(
        '{"tools":{"windows":{"productId":"app.pro","pro":true}},"keep":{"windows":{"productId":"keep.pro"}}}',
        'tools',
        'windows',
      );
      expect(c.productId, 'app.pro');
      expect(c.adsEnabled, isFalse);
      expect(MonetizationConfig.parse('{}', 'tools', 'web').productId, isEmpty);
      expect(
        () => MonetizationConfig.parse(
          '{"tools":{"android":{"productId":"bad id"}}}',
          'tools',
          'android',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'unconfigured builds do not call a store or fabricate purchases',
    () async {
      final store = Store(),
          controller = LifetimeController(const MonetizationConfig(), store);
      await controller.action('read');
      await controller.action('buy');
      expect(store.calls, 0);
      expect(controller.pro, isFalse);
      controller.dispose();
    },
  );
  test('on Android a product id is enough: Google Play’s word is taken, '
      'the licence key is optional', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = Store(),
        controller = LifetimeController(
          const MonetizationConfig(productId: 'app.pro'),
          store,
        );
    expect(controller.configured, isTrue);
    await controller.action('read');
    expect(store.calls, 1);
    controller.dispose();
  });
  test(
    'pending/canceled/unverified/foreign products never grant Pro',
    () async {
      final store = Store(),
          controller = LifetimeController(
            const MonetizationConfig(productId: 'app.pro'),
            store,
          );
      for (final status in ['pending', 'canceled', 'error', 'unavailable']) {
        store.value = StoreSnapshot(status: status, productId: 'app.pro');
        await controller.action('buy');
        expect(controller.pro, isFalse);
      }
      expect(
        () => StoreSnapshot.parse({
          'productId': 'app.pro',
          'status': 'owned',
          'owned': true,
          'verified': false,
        }, 'app.pro'),
        throwsFormatException,
      );
      controller.accept(
        const StoreSnapshot(
          status: 'owned',
          productId: 'foreign',
          owned: true,
          verified: true,
        ),
      );
      expect(controller.pro, isFalse);
      controller.dispose();
    },
  );
  test(
    'verified ownership, restore, revocation and offline failure use native evidence',
    () async {
      final store = Store(),
          controller = LifetimeController(
            const MonetizationConfig(productId: 'app.pro'),
            store,
          );
      store.value = const StoreSnapshot(
        status: 'owned',
        productId: 'app.pro',
        owned: true,
        verified: true,
      );
      await controller.action('restore');
      expect(controller.pro, isTrue);
      store.fail = true;
      await controller.action('read');
      expect(controller.pro, isTrue);
      controller.accept(
        const StoreSnapshot(status: 'ready', productId: 'app.pro'),
      );
      expect(controller.pro, isFalse);
      controller.dispose();
      store.callback!(
        const StoreSnapshot(
          status: 'owned',
          productId: 'app.pro',
          owned: true,
          verified: true,
        ),
      );
      expect(controller.pro, isFalse);
    },
  );
}
