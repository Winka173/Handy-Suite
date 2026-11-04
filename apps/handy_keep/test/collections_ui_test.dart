import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';
import 'keep_ui_test.dart' show sample, saved, stored;

void main() {
  testWidgets('a sample shelf comes in one tap and leaves in one', (t) async {
    final store = stored(sample());
    await start(t, store: store);
    expect(find.byKey(const Key('shelf-start')), findsOneWidget);
    await tapKey(t, 'shelf-sample');
    expect(find.byKey(const Key('shelf-sample-games')), findsOneWidget);
    // The sample's wanted item is on the wishlist, not under a place.
    expect(find.byKey(const Key('shelf-wishlist')), findsOneWidget);
    await tapKey(t, 'shelf-sample-games');
    expect(
      t.widget<Text>(find.byKey(const Key('collection-count'))).data,
      '3 of 6',
    );
    expect(find.text('Still wanted'), findsOneWidget);
    await tapKey(t, 'collection-menu');
    await tapKey(t, 'sample-remove');
    final s = saved(store);
    expect(s.collections, isEmpty);
    expect(s.assets.map((a) => a.id), ['camera', 'drill', 'lamp']);
  });

  testWidgets('a new collection takes an item, and a wish becomes owned', (
    t,
  ) async {
    final store = stored(sample());
    await start(t, store: store);
    await tapKey(t, 'shelf-start');
    await t.enterText(find.byKey(const Key('collection-name')), 'Figure');
    await t.enterText(find.byKey(const Key('collection-target')), '12');
    await tapKey(t, 'collection-save');
    // Straight to the new, empty collection.
    expect(find.text('Nothing in it yet'), findsOneWidget);
    final id = saved(store).collections.single.id;

    await tapKey(t, 'collection-add');
    expect(
      t.widget<FilterChip>(find.byKey(Key('item-collection-$id'))).selected,
      isTrue,
    );
    await t.enterText(find.byKey(const Key('item-name')), 'Miku 1/7');
    await t.enterText(find.byKey(const Key('item-series')), 'Racing');
    await tapKey(t, 'item-more-collector');
    await t.enterText(find.byKey(const Key('item-own-scale')), '1/7');
    await tapKey(t, 'item-save');
    var miku = saved(store).assets.firstWhere((a) => a.name == 'Miku 1/7');
    expect(miku.collections, [id]);
    expect(miku.profile, 'collectible');
    expect(miku.series, 'Racing');
    expect(miku.fields, {'scale': '1/7'});

    await tapKey(t, 'collection-add-wanted');
    await t.enterText(find.byKey(const Key('item-name')), 'Rin');
    await tapKey(t, 'item-save');
    final rin = saved(store).assets.firstWhere((a) => a.name == 'Rin');
    expect(rin.status, 'wanted');
    expect(
      t.widget<Text>(find.byKey(const Key('collection-count'))).data,
      '1 of 12',
    );

    await tapKey(t, 'collection-item-${rin.id}');
    await tapKey(t, 'item-got-it');
    miku = saved(store).assets.firstWhere((a) => a.id == rin.id);
    expect(miku.status, 'owned');
    expect(miku.purchasedOn, isNotEmpty);
    expect(saved(store).assets, hasLength(5));
  });

  testWidgets('a household item saves as before when there is no collection', (
    t,
  ) async {
    final store = stored(sample());
    await start(t, store: store);
    final before = saved(store).assets.firstWhere((a) => a.id == 'lamp');
    await tapKey(t, 'item-lamp');
    await tapKey(t, 'item-edit');
    expect(find.byKey(const Key('item-status')), findsNothing);
    await t.enterText(find.byKey(const Key('item-notes')), 'Bulb E27');
    await tapKey(t, 'item-save');
    final after = saved(store).assets.firstWhere((a) => a.id == 'lamp');
    expect(after.toJson().keys.toSet(), before.toJson().keys.toSet());
    expect(after.notes, 'Bulb E27');
  });

  testWidgets('the wishlist lists wanted items and takes "got it"', (t) async {
    final state = saveAsset(
      saveCollection(sample(), InventoryCollection(id: 'c', name: 'Cards')),
      createAsset(
        id: 'pika',
        name: 'Holo card',
        fields: {
          'status': 'wanted',
          'priority': 'high',
          'collections': ['c'],
        },
      ),
    );
    final store = stored(state);
    await start(t, store: store);
    // Not under any place on the home list.
    expect(find.byKey(const Key('item-pika')), findsNothing);
    await tapKey(t, 'shelf-wishlist');
    expect(find.textContaining('high priority'), findsOneWidget);
    await tapKey(t, 'wish-got-pika');
    expect(saved(store).assets.firstWhere((a) => a.id == 'pika').owned, isTrue);
    expect(find.text('Nothing wanted now'), findsOneWidget);
  });
}
