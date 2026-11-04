import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';

void main() {
  const now = '2026-11-02T00:00:00.000Z';
  InventoryAsset item(
    String id,
    String name,
    String bought, [
    List<String> again = const [],
  ]) => createAsset(
    id: id,
    name: name,
    now: now,
    fields: {'purchasedOn': bought, 'restocks': again},
  );

  test('run-out is learned from the days an item was bought', () {
    final state = KeepState(
      assets: [
        // Bought again every ~30 days; one late purchase does not swing it.
        item('coffee', 'Cà phê hạt', '2026-07-01', [
          '2026-07-31',
          '2026-08-30',
          '2026-10-10',
        ]),
        // Two packs saved as separate items count as one history.
        item('aa1', 'Pin AA', '2026-05-01'),
        item('aa2', 'pin  aa', '2026-08-01'),
        // Bought once: nothing to learn yet.
        item('tv', 'TV', '2025-01-01'),
      ],
    );
    final r = runOutEstimates(state);
    // Soonest first: the batteries were due yesterday.
    expect(r.map((x) => x.asset.id), ['aa1', 'coffee']);
    expect((r[0].every, r[0].expected), (92, '2026-11-01'));
    expect(r[0].daysLeft('2026-11-02'), -1);
    expect((r[1].every, r[1].expected, r[1].purchases), (30, '2026-11-09', 4));
    expect(r[1].daysLeft('2026-11-02'), 7);
  });

  test('restock days survive a round trip; version 2 files still load', () {
    final a = item('c', 'Cà phê', '2026-01-01', [
      '2026-02-01',
      '2026-02-01',
      '2026-01-15',
    ]);
    expect(a.restocks, ['2026-01-15', '2026-02-01']);
    final back = validateKeepState(
      jsonDecode(serializeKeepState(KeepState(assets: [a]))),
    );
    expect(back.assets.single.restocks, a.restocks);
    final old = jsonDecode(serializeKeepState(KeepState(assets: [a]))) as Map;
    old['version'] = 2;
    (old['assets'] as List).first.remove('restocks');
    expect(validateKeepState(old).assets.single.restocks, isEmpty);
  });

  test('collectibles and lasting things never run out; consumables do', () {
    InventoryAsset as(InventoryAsset a, String profile) =>
        a.copyWith({'profile': profile});
    final state = KeepState(
      assets: [
        as(item('f1', 'Labubu', '2026-05-01'), 'collectible'),
        as(item('f2', 'labubu', '2026-08-01'), 'collectible'),
        as(item('c1', 'USB-C cable', '2026-06-01'), 'asset'),
        as(item('c2', 'USB-C cable', '2026-09-01'), 'asset'),
        as(item('s1', 'Dish soap', '2026-08-01', ['2026-09-01']), 'consumable'),
        // No profile yet: still read from its purchases.
        item('aa1', 'Pin AA', '2026-05-01'),
        item('aa2', 'Pin AA', '2026-08-01'),
      ],
    );
    expect(runOutEstimates(state).map((r) => r.asset.name).toSet(), {
      'Dish soap',
      'Pin AA',
    });
    expect(runOutFor(state, state.assets.first), isNull);
  });
}
