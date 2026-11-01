import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_keep/deep_links.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  final inventory = saveAsset(
    saveAsset(
      saveBox(emptyKeepState(), InventoryBox(id: 'box1', name: 'Moving box')),
      createAsset(id: 'camera', name: 'Camera', fields: {'boxId': 'box1'}),
    ),
    createAsset(id: 'other', name: 'Other'),
  );
  Future<void> deliver(String url) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      KeepDeepLinks.channel.name,
      codec.encodeMethodCall(MethodCall('openLabel', url)),
      (_) {},
    );
  }

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      KeepDeepLinks.channel,
      null,
    );
  });

  testWidgets(
    'cold label waits for inventory and opens only the matching local item',
    (tester) async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        KeepDeepLinks.channel,
        (call) async => 'handy-keep://item/camera',
      );
      final store = Store()..text = serializeKeepState(inventory);
      await start(tester, store: store);
      expect(find.byKey(const Key('item-view')), findsOneWidget);
      expect(find.text('Camera'), findsWidgets);
      expect(store.text, serializeKeepState(inventory));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'warm box resets filters; unknown and unsafe URLs never open or change data',
    (tester) async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        KeepDeepLinks.channel,
        (call) async => null,
      );
      final store = Store()..text = serializeKeepState(inventory);
      await start(tester, store: store);
      await tester.enterText(find.byKey(const Key('keep-search')), 'Other');
      await deliver('handy-keep://box/box1');
      await tester.pumpAndSettle();
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
      for (final value in [
        'handy-keep://item/missing',
        'file:///private/secret',
        'handy-keep://item/camera?path=file:///private/secret',
      ]) {
        await deliver(value);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('item-view')), findsNothing);
        expect(store.text, serializeKeepState(inventory));
      }
      await deliver('handy-keep://item/camera');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-view')), findsOneWidget);
      expect(store.text, serializeKeepState(inventory));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
