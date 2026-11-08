import 'dart:ui' show Size;
import 'package:flutter/material.dart' show Key, Offset, Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/pro/entitlements.dart';
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
  testWidgets('a collection shows its folders and makes a new one from its '
      'options (Pro); a folder offers no folder of its own', (t) async {
    // ignore: invalid_use_of_visible_for_testing_member
    debugProOverride = true;
    // ignore: invalid_use_of_visible_for_testing_member
    addTearDown(() => debugProOverride = null);
    final (c, _) = await boot(
      t,
      seed: (c) async {
        await twoCollections(c);
        await c.update(
          (l) => l.copyWith(
            collections: [
              ...l.collections,
              SaveCollection(id: 'dn', name: 'Da Nang', parentId: 'trip'),
            ],
          ),
        );
      },
    );
    await tapKey(t, 'home-library');
    await tapKey(t, 'collection-trip');
    await settle(t);
    expect(find.byKey(const Key('sub-dn')), findsOneWidget);
    expect(find.textContaining('1 folder'), findsOneWidget);
    await tapKey(t, 'list-more');
    await tapKey(t, 'collection-sub');
    await t.enterText(find.byKey(const Key('collection-name')), 'Hoi An');
    await tapKey(t, 'editor-save');
    await settle(t);
    final made = c.library!.collections.firstWhere((x) => x.name == 'Hoi An');
    expect(made.parentId, 'trip');
    expect(find.byKey(Key('sub-${made.id}')), findsOneWidget);
    // Inside a folder: one level only, so no New folder.
    await tapKey(t, 'sub-${made.id}');
    await settle(t);
    await tapKey(t, 'list-more');
    expect(find.byKey(const Key('collection-sub')), findsNothing);
    expect(find.byKey(const Key('collection-edit')), findsOneWidget);
  });

  testWidgets('without Pro, New folder opens Pro and makes nothing; the '
      'folders already there still open', (t) async {
    final (c, _) = await boot(
      t,
      seed: (c) async {
        await twoCollections(c);
        await c.update(
          (l) => l.copyWith(
            collections: [
              ...l.collections,
              SaveCollection(id: 'dn', name: 'Da Nang', parentId: 'trip'),
            ],
          ),
        );
      },
    );
    await tapKey(t, 'home-library');
    await tapKey(t, 'collection-trip');
    await settle(t);
    await tapKey(t, 'list-more');
    expect(find.textContaining('(Pro)'), findsWidgets);
    await tapKey(t, 'collection-sub');
    await settle(t);
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
    expect(find.byKey(const Key('collection-name')), findsNothing);
    expect(c.library!.collections, hasLength(3));
  });

  testWidgets('cards or rows is remembered per collection', (t) async {
    final (c, _) = await boot(
      t,
      size: const Size(1280, 800),
      seed: twoCollections,
    );
    // The choice is a labelled row in the list's options sheet.
    Future<String> offered() async {
      await tapKey(t, 'list-more');
      final words = find.descendant(
        of: find.byKey(const Key('save-view')),
        matching: find.byType(Text),
      );
      final text = t.widget<Text>(words.first).data!;
      await t.tapAt(const Offset(640, 20));
      await settle(t);
      return text;
    }

    await tapKey(t, 'collection-food');
    await settle(t);
    // Cards are the default; rows are the choice to make.
    expect(await offered(), 'Show as rows');
    await tapKey(t, 'list-more');
    await tapKey(t, 'save-view');
    await settle(t);
    expect(await offered(), 'Show as cards');
    final views = c.preferences['collectionViews'] as Map;
    expect((views['food'] as Map)['cards'], isFalse);
    expect(c.preferences['cards'], isNot(false), reason: 'the app default');

    await tapKey(t, 'collection-trip');
    await settle(t);
    expect(await offered(), 'Show as rows');
    await tapKey(t, 'collection-food');
    await settle(t);
    expect(await offered(), 'Show as cards');
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
