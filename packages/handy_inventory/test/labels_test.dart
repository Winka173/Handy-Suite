import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';

void main() {
  test(
    'original item/box label strings roundtrip and resolve only current inventory',
    () {
      final asset = createAsset(id: 'legacy-item_1', name: 'Máy ảnh');
      final box = InventoryBox(id: 'legacy-box', name: 'Hộp');
      final state = saveBox(saveAsset(emptyKeepState(), asset), box);
      for (final kind in ['item', 'box']) {
        final target = InventoryLabel(kind, kind == 'item' ? asset.id : box.id);
        final parsed = InventoryLabel.parse(' ${target.url}\n');
        expect(parsed.url, target.url);
        expect(
          parsed.resolve(state),
          kind == 'item' ? isA<InventoryAsset>() : isA<InventoryBox>(),
        );
        expect(() => parsed.resolve(emptyKeepState()), throwsFormatException);
      }
      for (final value in [
        'https://example.org',
        'handy-keep://item/x?token=y',
        'handy-keep://item/../x',
        'handy-keep://item/%61',
        'handy-keep://item/x#secret',
        'handy-keep://box/',
        'handy-keep://other/x',
        'handy-keep://item/${'x' * 101}',
        'handy-keep://item/x\nmore',
      ]) {
        expect(() => InventoryLabel.parse(value), throwsFormatException);
      }
      expect(() => InventoryLabel('other', 'x'), throwsFormatException);
    },
  );
  test(
    'legacy bilingual dossier contains metadata and label without asset bytes or paths',
    () {
      final asset = createAsset(
        id: 'item1',
        name: 'Máy ảnh',
        fields: {
          'serial': 'ABC-123',
          'notes': 'Ghi chú',
          'boxId': 'box1',
          'photoUri': 'file:///private/photo.png',
          'borrower': 'An',
          'lentOn': '2026-10-31',
        },
      );
      final state = saveAsset(
        saveBox(
          emptyKeepState(),
          InventoryBox(id: 'box1', name: 'Hộp máy ảnh'),
        ),
        asset,
      );
      final dossier = itemDossier(asset, state);
      expect(dossier, contains('Serial: ABC-123'));
      expect(dossier, contains('Box / Thùng: Hộp máy ảnh'));
      expect(dossier, contains('handy-keep://item/item1'));
      expect(dossier, contains('Review personal details'));
      expect(dossier, isNot(contains('file:///private')));
      expect(dossier, isNot(contains('base64')));
      final restored = parseKeepState(serializeKeepState(state));
      expect(itemDossier(restored.assets.single, restored), dossier);
      expect(
        InventoryLabel.parse('handy-keep://item/item1').resolve(restored),
        isA<InventoryAsset>(),
      );
    },
  );
}
