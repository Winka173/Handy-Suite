import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/share.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_keep/app.dart';
import 'package:handy_keep/labels.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

void main() {
  final asset = createAsset(
    id: 'legacy',
    name: 'Máy ảnh',
    fields: {'serial': 'ABC'},
  );
  final inventory = saveAsset(emptyKeepState(), asset);

  Future<void> page(WidgetTester tester, Files files) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHandyTheme(keepAccent, Brightness.light),
        home: InventoryLabelPage(
          label: InventoryLabel('item', asset.id),
          inventory: inventory,
          files: files,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'dossier sharing requires review and snapshots exact saved UTF-8 text',
    (tester) async {
      await page(tester, Files());
      expect(find.byKey(const Key('keep-dossier-share')), findsNothing);
      await tapKey(tester, 'keep-dossier-open');
      await tapKey(tester, 'keep-dossier-review');
      final share = tester.widget<ShareOutputButton>(
        find.byKey(const Key('keep-dossier-share')),
      );
      expect(share.mimeType, 'text/plain');
      expect(share.bytes(), utf8.encode(itemDossier(asset, inventory)));
      expect(inventory.assets.single.toJson(), asset.toJson());
    },
  );

  testWidgets(
    'record label exports real existing QR engine PNG and bilingual dossier',
    (tester) async {
      final files = Files();
      await page(tester, files);
      await tapKey(tester, 'keep-label-export');
      expect(files.png, qrPng('handy-keep://item/legacy'));
      await tapKey(tester, 'keep-dossier-export');
      expect(files.text, itemDossier(asset, inventory));
      expect(files.text, contains('Serial: ABC'));
    },
  );

  testWidgets('the printable label is the whole card, not the bare code', (
    tester,
  ) async {
    final files = Files();
    await page(tester, files);
    await tapKey(tester, 'keep-label-card-export', settle: false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(files.png!.sublist(0, 4), [137, 80, 78, 71]);
    expect(files.png, isNot(qrPng('handy-keep://item/legacy')));
    expect(find.text('File exported'), findsOneWidget);
  });

  testWidgets('cancel and export failure preserve QR and record for retry', (
    tester,
  ) async {
    final files = Files()..fail = true;
    await page(tester, files);
    await tapKey(tester, 'keep-label-export');
    expect(find.textContaining('Export failed'), findsOneWidget);
    files
      ..fail = false
      ..cancel = true;
    await tapKey(tester, 'keep-label-export');
    expect(find.text('Export canceled'), findsOneWidget);
    expect(files.png, isNull);
    files.cancel = false;
    await tapKey(tester, 'keep-label-export');
    expect(files.png, isNotNull);
    expect(inventory.assets.single.toJson(), asset.toJson());
  });

  testWidgets(
    'box label resets stale search and shows only that box, by its original ID',
    (tester) async {
      final state = saveAsset(
        saveAsset(
          saveBox(
            emptyKeepState(),
            InventoryBox(id: 'box1', name: 'Legacy box'),
          ),
          asset.copyWith({'boxId': 'box1'}),
        ),
        createAsset(id: 'other', name: 'Other'),
      );
      final store = Store()..text = serializeKeepState(state);
      await start(tester, store: store);
      await tester.enterText(find.byKey(const Key('keep-search')), 'Other');
      await tester.pumpAndSettle();
      expect(find.text('Máy ảnh'), findsNothing);
      await tapKey(tester, 'keep-scan-bottom');
      await tester.enterText(
        find.byKey(const Key('keep-label-input')),
        'handy-keep://box/box1',
      );
      await tapKey(tester, 'keep-label-open');
      expect(find.text('Máy ảnh'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
      expect(find.byKey(const Key('box-filter')), findsOneWidget);
      expect(store.text, serializeKeepState(state));
    },
  );

  testWidgets(
    'old labels open the item while invalid or missing labels never navigate',
    (tester) async {
      final store = Store()..text = serializeKeepState(inventory);
      await start(tester, store: store);
      await tapKey(tester, 'keep-scan-bottom');
      for (final value in [
        'https://example.org',
        'handy-keep://item/missing',
      ]) {
        await tester.enterText(
          find.byKey(const Key('keep-label-input')),
          value,
        );
        await tapKey(tester, 'keep-label-open');
        expect(find.byType(OpenInventoryLabel), findsOneWidget);
        expect(find.byKey(const Key('item-view')), findsNothing);
      }
      await tester.enterText(
        find.byKey(const Key('keep-label-input')),
        'handy-keep://item/legacy',
      );
      await tapKey(tester, 'keep-label-open');
      expect(find.byKey(const Key('item-view')), findsOneWidget);
      expect(store.text, serializeKeepState(inventory));
    },
  );
}
