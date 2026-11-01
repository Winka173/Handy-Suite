import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_keep/app.dart';
import 'package:handy_keep/library.dart';
import 'package:handy_keep/labels.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';

/// The label opener sits in the bottom bar on phones and the top bar on wide screens.
Finder labelButton() {
  final wide = find.byKey(const Key('keep-open-label'));
  return wide.evaluate().isEmpty
      ? find.byKey(const Key('keep-scan-bottom'))
      : wide;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'receipt PDF previews locally after exact library restore without changing item data',
    (tester) async {
      final pdf = await qrPdf('handy-keep://item/receipt-item');
      final asset = createAsset(
        id: 'receipt-item',
        name: 'Camera with invoice',
        fields: {
          'receipts': [
            {
              'id': 'invoice1',
              'name': 'Invoice.pdf',
              'mime': 'application/pdf',
              'uri': 'file:///handy-assets/invoice1.pdf',
            },
          ],
        },
      );
      final library = InventoryLibrary(saveAsset(emptyKeepState(), asset), {
        'file:///handy-assets/invoice1.pdf': pdf,
      });
      final store = localDocuments(
        'handy-keep-receipt-integration',
        maxBytes: 16000000,
      );
      final saved = library.serialize();
      await store.save(saved);
      final prefs = DevicePreferencesRepository(
        'handy-keep-receipt-integration',
      );
      await prefs.save(HandyPreferences(locale: 'en', theme: 'light'));
      await tester.pumpWidget(KeepApp(documents: store, preferences: prefs));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('item-receipt-item')));
      await tester.pumpAndSettle();
      final receipt = find.byKey(const Key('receipt-open-invoice1'));
      await tester.scrollUntilVisible(
        receipt,
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(receipt.hitTestable());
      for (
        var i = 0;
        i < 100 &&
            find.byKey(const Key('local-pdf-preview')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('local-pdf-preview')), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('keep-pdf-receipt');
      }
      expect(await store.load(), saved);
      await tester.pumpWidget(const SizedBox());
      await store.save(InventoryLibrary(emptyKeepState(), {}).serialize());
    },
  );
  testWidgets(
    'legacy printed QR label opens actual local item and renders portable PNG',
    (tester) async {
      final item = createAsset(
        id: 'legacy-printed',
        name: 'Máy ảnh cũ',
        fields: {'serial': 'LEGACY-123'},
      );
      final state = saveAsset(emptyKeepState(), item);
      final store = localDocuments('handy-keep-label-integration');
      await store.save(serializeKeepState(state));
      final prefs = DevicePreferencesRepository('handy-keep-label-integration');
      await prefs.save(HandyPreferences(locale: 'en', theme: 'light'));
      await tester.pumpWidget(KeepApp(documents: store, preferences: prefs));
      await tester.pumpAndSettle();
      await tester.tap(labelButton());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('keep-label-input')),
        'handy-keep://item/legacy-printed',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('keep-label-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-view')), findsOneWidget);
      expect(find.text('LEGACY-123'), findsOneWidget);
      expect(
        parseKeepState((await store.load())!).assets.single.id,
        'legacy-printed',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHandyTheme(keepAccent, Brightness.light),
          home: InventoryLabelPage(
            label: InventoryLabel('item', item.id),
            inventory: state,
            files: const SystemHandyFiles(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('keep-label-qr')), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('keep-legacy-qr-label');
      }
      await store.save(serializeKeepState(emptyKeepState()));
    },
  );
  testWidgets(
    'native inventory snapshots and photo ZIP survive restart and portable restore',
    (tester) async {
      final store = localDocuments('handy-keep-integration');
      final item = createAsset(
        id: 'integration-camera',
        name: 'Integration Camera',
        fields: {
          'location': 'Office',
          'photoUri': 'file:///handy-assets/test.png',
        },
      );
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
      );
      final library = InventoryLibrary(saveAsset(emptyKeepState(), item), {
        'file:///handy-assets/test.png': png,
      });
      await store.save(library.serialize());
      final prefs = DevicePreferencesRepository('handy-keep-integration');
      await prefs.save(HandyPreferences(locale: 'en'));
      await tester.pumpWidget(KeepApp(documents: store, preferences: prefs));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('keep-home-light');
      }
      expect(find.text('Integration Camera'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final restored = InventoryLibrary.fromPortable(library.portable());
      await localDocuments('handy-keep-integration').save(restored.serialize());
      await tester.pumpWidget(
        KeepApp(
          documents: localDocuments('handy-keep-integration'),
          preferences: prefs,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Integration Camera'), findsOneWidget);
      expect(
        InventoryLibrary.parse((await store.load())!).blobs.values.single,
        png,
      );
      await store.save(InventoryLibrary(emptyKeepState(), {}).serialize());
    },
  );
}
