import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/view/library_view.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'new_flows_test.dart' show NetController, boot, settle;
import 'widget_test.dart' show tapKey;

Future<void> twoCollections(NetController c) => c.update(
  (l) => l.copyWith(
    collections: [
      SaveCollection(id: 'food', name: 'Food', position: 0),
      SaveCollection(id: 'trip', name: 'Trips', position: 1),
    ],
    bookmarks: [
      for (final (i, b) in l.bookmarks.indexed)
        b.copyWith(collectionId: i == 0 ? 'trip' : 'food'),
    ],
  ),
);

void main() {
  testWidgets('cards or rows is remembered per collection', (t) async {
    final (c, _) = await boot(
      t,
      size: const Size(1280, 800),
      seed: twoCollections,
    );
    await tapKey(t, 'collection-food');
    await settle(t);
    expect(find.byTooltip('Show as cards'), findsOneWidget);
    await tapKey(t, 'save-view');
    await settle(t);
    expect(find.byTooltip('Show as rows'), findsOneWidget);
    final views = c.preferences['collectionViews'] as Map;
    expect((views['food'] as Map)['cards'], isTrue);
    expect(c.preferences['cards'], isNot(true), reason: 'the app default');

    await tapKey(t, 'collection-trip');
    await settle(t);
    expect(find.byTooltip('Show as cards'), findsOneWidget);
    await tapKey(t, 'collection-food');
    await settle(t);
    expect(find.byTooltip('Show as rows'), findsOneWidget);
  });

  testWidgets('a collection opens in the order it was last left in', (t) async {
    final (c, _) = await boot(t, seed: twoCollections);
    final v = LibraryView(c);
    addTearDown(v.dispose);
    v.show(Place.collection, 'food');
    v.filter(v.filters.withSort('oldest'));
    await settle(t, 200);
    v.show(Place.collection, 'trip');
    expect(v.filters.sort, 'newest');
    v.show(Place.collection, 'food');
    expect(v.filters.sort, 'oldest');
    expect(
      ((c.preferences['collectionViews'] as Map)['food'] as Map)['sort'],
      'oldest',
    );
    await settle(t, 200);
  });

  test('changing the order or kind keeps the other filters', () {
    const f = Filters(kind: 'image', tag: 'x', savedBefore: '2026-01-01');
    final g = f.withSort('title');
    expect(
      (g.kind, g.tag, g.savedBefore, g.sort),
      ('image', 'x', '2026-01-01', 'title'),
    );
    expect(g.withKind(null).sort, 'title');
  });
}
