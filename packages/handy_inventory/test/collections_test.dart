import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';

const now = '2026-11-04T08:00:00.000Z';
final png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
  ),
);
final jpg = Uint8List.fromList([255, 216, 255, 224, 0, 16, 74, 70, 73, 70]);

KeepState shelf() {
  var s = saveCollection(
    emptyKeepState(),
    InventoryCollection(id: 'figs', name: 'Figure', kind: 'figures', hue: 2),
  );
  s = saveCollection(
    s,
    InventoryCollection(id: 'gifts', name: 'Quà tặng', target: 3),
  );
  s = saveAsset(
    s,
    createAsset(
      id: 'miku',
      name: 'Miku 1/7',
      now: now,
      fields: {
        'profile': 'collectible',
        'collections': ['figs', 'gifts'],
        'series': 'Racing',
        'condition': 'Mint',
        'fields': {'scale': '1/7'},
      },
    ),
  );
  return saveAsset(
    s,
    createAsset(
      id: 'rin',
      name: 'Rin',
      now: now,
      fields: {
        'status': 'wanted',
        'priority': 'high',
        'collections': ['figs'],
        'budget': '1500000',
        'budgetCurrency': 'VND',
        'link': 'https://example.com/rin',
      },
    ),
  );
}

void main() {
  test('a version 3 library loads as it was and gains no fields', () {
    final v3 = {
      'version': 3,
      'assets': [
        createAsset(id: 'drill', name: 'Drill', now: now).toJson()
          ..['restocks'] = ['2026-01-02'],
      ],
      'boxes': [],
    };
    final state = validateKeepState(v3);
    expect(state.collections, isEmpty);
    final drill = state.assets.single;
    expect(drill.profile, 'asset');
    expect(drill.status, 'owned');
    expect(drill.toJson().keys, isNot(contains('collections')));
    final again = validateKeepState(jsonDecode(jsonEncode(state.toJson())));
    expect(again.toJson()['version'], keepStateVersion);
    expect(again.assets.single.toJson(), drill.toJson());
  });

  test('an item sits in two collections without being copied', () {
    final s = shelf();
    expect(s.assets.where((a) => a.name == 'Miku 1/7'), hasLength(1));
    expect(collectionItems(s, 'figs').map((a) => a.id), ['miku', 'rin']);
    expect(collectionItems(s, 'gifts').map((a) => a.id), ['miku']);
    // Removing a collection keeps its items.
    final left = removeCollection(s, 'gifts');
    expect(left.assets, hasLength(2));
    expect(left.assets.first.collections, ['figs']);
  });

  test('own order and cover follow the items they name', () {
    var s = saveCollection(
      shelf(),
      shelf().collections.first.copyWith({
        'order': ['rin', 'miku'],
        'coverAssetId': 'rin',
      }),
    );
    expect(collectionItems(s, 'figs').map((a) => a.id), ['rin', 'miku']);
    s = removeAsset(s, 'rin');
    expect(s.collections.first.order, ['miku']);
    expect(s.collections.first.coverAssetId, '');
    s = setItemCollections(s, 'miku', ['gifts'], now: now);
    expect(collectionItems(s, 'figs'), isEmpty);
  });

  test('wishlist: wanted is not lendable, and arrives as the same record', () {
    final s = shelf();
    expect(
      () => saveAsset(
        s,
        s.assets.last.copyWith({'borrower': 'Lan', 'lentOn': '2026-11-01'}),
      ),
      throwsFormatException,
    );
    final got = markOwned(
      s,
      'rin',
      purchasedOn: '2026-11-04',
      price: '1450000',
      currency: 'VND',
      now: now,
    );
    final rin = got.assets.firstWhere((a) => a.id == 'rin');
    expect(rin.status, 'owned');
    expect(rin.price, '1450000');
    expect(rin.budget, '1500000');
    expect(got.assets, hasLength(2));
  });

  test('completion counts what is owned against the person\'s target', () {
    final s = shelf();
    final figs = collectionCompletion(s, 'figs');
    expect((figs.owned, figs.wanted, figs.target, figs.missing), (1, 1, 0, 0));
    final gifts = collectionCompletion(s, 'gifts');
    expect((gifts.owned, gifts.target, gifts.missing), (1, 3, 2));
  });

  test('changing the profile keeps the values it hides', () {
    final s = shelf();
    final miku = s.assets.first.copyWith({'profile': 'asset'});
    final back = saveAsset(
      s,
      miku,
    ).assets.first.copyWith({'profile': 'collectible'});
    expect(back.series, 'Racing');
    expect(back.fields, {'scale': '1/7'});
  });

  test('bad references and values are refused', () {
    final s = shelf();
    for (final change in <Map<String, Object?>>[
      {
        'collections': ['nope'],
      },
      {'link': 'javascript:alert(1)'},
      {'budget': '10'},
      {'status': 'sold'},
      {
        'fields': {'Bad Key': 'x'},
      },
      {'photos': List.generate(12, (i) => 'file:///p$i.png')},
    ]) {
      expect(
        () => saveAsset(s, s.assets.first.copyWith(change)),
        throwsFormatException,
        reason: '$change',
      );
    }
    expect(
      () => saveCollection(
        s,
        InventoryCollection(id: 'x', name: 'X', coverAssetId: 'ghost'),
      ),
      throwsFormatException,
    );
  });

  test('a ZIP keeps collections, fields and more photos in order', () {
    var s = shelf();
    s = saveAsset(
      s,
      s.assets.first.copyWith({
        'photoUri': 'file:///m/cover.png',
        'photos': ['file:///m/b.jpg', 'file:///m/a.png'],
      }),
    );
    final zip = buildKeepZip(s, {
      'file:///m/cover.png': png,
      'file:///m/b.jpg': jpg,
      'file:///m/a.png': png,
    });
    final bundle = parseKeepZip(zip);
    var i = 0;
    final restored = bundle.materialize({
      for (final f in bundle.files) f.path: 'file:///new/${i++}',
    });
    final miku = restored.assets.firstWhere((a) => a.id == 'miku');
    expect(restored.collections.map((c) => c.id), ['figs', 'gifts']);
    expect(miku.collections, ['figs', 'gifts']);
    expect(miku.fields, {'scale': '1/7'});
    expect(miku.photos, hasLength(2));
    // b.jpg was first, so its staged copy comes first.
    final first = bundle.files.firstWhere(
      (f) => f.role == 'gallery' && f.index == 0,
    );
    expect(first.mime, 'image/jpeg');
    expect(miku.photos.first, isNot(miku.photos.last));
    expect(exportKeepBackup(s), isNot(contains('file:///m/')));
  });
}
