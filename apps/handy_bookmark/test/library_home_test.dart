import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart' show saveTime;
import 'package:handy_bookmark/view/library_view.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show NetController, boot, settle;
import 'widget_test.dart' show tapKey;

/// Two collections; Food holds two saves with page pictures, Trips one.
Future<void> pictured(NetController c) => c.update(
  (l) => l.copyWith(
    collections: [
      SaveCollection(id: 'food', name: 'Food', position: 0),
      SaveCollection(id: 'trip', name: 'Trips', position: 1),
    ],
    bookmarks: [
      for (final (i, b) in l.bookmarks.indexed)
        b.copyWith(
          collectionId: i == 0 ? 'trip' : 'food',
          thumbnailUrl: 'https://img.example.com/$i.jpg',
        ),
    ],
  ),
);

Map<String, dynamic> viewOf(NetController c, String id) =>
    ((c.preferences['collectionViews'] as Map?)?[id] as Map?)
        ?.cast<String, dynamic>() ??
    {};

void main() {
  testWidgets('the phone home is short; every place is one tap away in '
      'the Library', (t) async {
    await boot(t, seed: pictured);
    // Home: covers, the shelf, and the two doors; no list of places.
    for (final key in ['home-library', 'place-focus', 'collection-food']) {
      expect(
        find.byKey(Key(key), skipOffstage: false),
        findsOneWidget,
        reason: key,
      );
    }
    for (final key in ['place-inbox', 'place-all', 'place-archive']) {
      expect(find.byKey(Key(key), skipOffstage: false), findsNothing);
    }
    expect(find.text('3 items'), findsOneWidget);

    await tapKey(t, 'home-library');
    for (final key in [
      'place-inbox',
      'place-all',
      'place-favorites',
      'place-unread',
      'place-archive',
      'collection-food',
      'collection-trip',
      'collection-new',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    // Nothing kept by rules or search, and no Pro: no Advanced.
    expect(find.byKey(const Key('library-advanced')), findsNothing);
    await tapKey(t, 'place-all');
    await settle(t);
    expect(find.text('Everything'), findsWidgets);
  });

  testWidgets('kept smart collections wait under Advanced in the Library', (
    t,
  ) async {
    await boot(
      t,
      seed: (c) => c.update(
        (l) => l.copyWith(
          smartCollections: [
            SmartCollection(
              id: 'unread',
              name: 'Still unread',
              mode: 'all',
              rules: [
                SmartRule(field: 'isRead', operator: 'equals', value: false),
              ],
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('smart-unread')), findsNothing);
    await tapKey(t, 'home-library');
    expect(find.byKey(const Key('smart-unread')), findsNothing);
    await tapKey(t, 'library-advanced');
    expect(find.byKey(const Key('smart-unread')), findsOneWidget);
    expect(find.byKey(const Key('smart-new')), findsOneWidget);
    await tapKey(t, 'smart-unread');
    await settle(t);
    expect(find.text('Still unread'), findsWidgets);
  });

  testWidgets('a collection cover can be chosen from its own pictures and '
      'falls back to automatic when that save is gone', (t) async {
    final (c, _) = await boot(t, seed: pictured);
    final food = [
      for (final b in c.library!.bookmarks)
        if (b.collectionId == 'food') b.id,
    ];
    await tapKey(t, 'collection-food');
    await tapKey(t, 'list-more');
    await tapKey(t, 'collection-cover');
    // Automatic, then each of the collection's own pictures; no others.
    expect(find.byKey(const Key('cover-auto')), findsOneWidget);
    for (final id in food) {
      expect(find.byKey(Key('cover-$id')), findsOneWidget);
    }
    expect(find.byKey(const Key('cover-trip')), findsNothing);
    await tapKey(t, 'cover-${food.last}');
    await settle(t);
    expect(viewOf(c, 'food')['cover'], food.last);
    final v = LibraryView(c);
    addTearDown(v.dispose);
    expect(v.chosenCover('food')?.id, food.last);

    // Moved to Recently Deleted: the cover is made automatically again,
    // and the choice is not lost from the data until changed.
    await c.update((l) => moveToTrash(l, [food.last], saveTime()));
    await settle(t);
    expect(v.chosenCover('food'), isNull);
    expect(viewOf(c, 'food')['cover'], food.last);

    // Back to automatic forgets it.
    await tapKey(t, 'list-more');
    await tapKey(t, 'collection-cover');
    await tapKey(t, 'cover-auto');
    await settle(t);
    expect(viewOf(c, 'food').containsKey('cover'), isFalse);
  });

  testWidgets('the order is one menu, Newest first by default, kept per '
      'collection, and not counted as a filter', (t) async {
    final (c, _) = await boot(t, seed: pictured);
    await tapKey(t, 'collection-food');
    expect(find.text('Newest first'), findsOneWidget);
    await tapKey(t, 'save-sort');
    await tapKey(t, 'sort-oldest');
    await settle(t);
    expect(viewOf(c, 'food')['sort'], 'oldest');
    expect(find.text('Oldest first'), findsOneWidget);
    expect(find.text('2 saved'), findsOneWidget, reason: 'not "2 found"');
    await t.binding.handlePopRoute();
    await settle(t);
    await tapKey(t, 'collection-trip');
    expect(find.text('Newest first'), findsOneWidget);
    await t.binding.handlePopRoute();
    await settle(t);
    await tapKey(t, 'collection-food');
    expect(find.text('Oldest first'), findsOneWidget);
  });

  testWidgets('batch tools appear only after selecting, with no pin', (
    t,
  ) async {
    final (c, _) = await boot(t, seed: pictured);
    await tapKey(t, 'collection-food');
    expect(find.byKey(const Key('batch-clear')), findsNothing);
    final id = c.library!.bookmarks.firstWhere((b) => b.collectionId == 'food');
    await t.longPress(find.byKey(ValueKey('bookmark-${id.id}')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('batch-clear')), findsOneWidget);
    await tapKey(t, 'batch-more');
    expect(find.textContaining('Pin'), findsNothing);
  });
}
