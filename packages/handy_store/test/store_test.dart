import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_store/handy_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native channel calls only product config and requires verified matching ownership',
    () async {
      const channel = MethodChannel('handy_store_test');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return {
              'productId': 'app.pro',
              'status': 'owned',
              'owned': true,
              'verified': true,
            };
          });
      final store = NativeLifetimeStore(
        productId: 'app.pro',
        androidPublicKey: 'PUBLIC_KEY',
        channel: channel,
      );
      expect((await store.restore()).isPro, isTrue);
      expect(calls.single.method, 'restore');
      expect(calls.single.arguments, {
        'productId': 'app.pro',
        'publicKey': 'PUBLIC_KEY',
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => {
              'productId': 'other.pro',
              'status': 'owned',
              'owned': true,
              'verified': true,
            },
          );
      await expectLater(store.read(), throwsFormatException);
      await store.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
}
