import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/home/home_sections.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'collection_view_test.dart' show twoCollections;
import 'new_flows_test.dart' show boot, settle;
import 'share_sheet_test.dart' show showSheet;
import 'widget_test.dart' show tapKey;

void main() {
  Bookmark byUrl(SaveLibrary l, String part) =>
      l.bookmarks.firstWhere((b) => b.originalUrl.contains(part));

  testWidgets('a save in the app offers its likeliest collections; one tap '
      'files it and Undo puts it back in Not sorted', (t) async {
    final (c, _) = await boot(t, seed: twoCollections);
    // a.com already lives somewhere: that collection is offered first.
    final home = byUrl(c.library!, 'a.com/one').collectionId!;
    await t.enterText(
      find.byKey(const Key('bookmark-inline-url')),
      'https://a.com/two',
    );
    await t.pump();
    await tapKey(t, 'bookmark-inline-save');
    await settle(t);
    expect(byUrl(c.library!, 'a.com/two').collectionId, isNull);
    final chips = [
      for (final w in t.widgetList<ActionChip>(
        find.descendant(
          of: find.byKey(const Key('saved-put-in')),
          matching: find.byType(ActionChip),
        ),
      ))
        w.key,
    ];
    expect(chips.first, Key('saved-into-$home'));
    expect(chips.last, const Key('saved-into-other'));
    // No page opens by itself: the person stays where they saved.
    expect(find.byKey(const Key('save-home')), findsOneWidget);

    await tapKey(t, 'saved-into-$home');
    await settle(t);
    expect(byUrl(c.library!, 'a.com/two').collectionId, home);
    expect(find.byKey(const Key('saved-filed')), findsOneWidget);
    await tapKey(t, 'saved-filed-undo');
    await settle(t);
    expect(byUrl(c.library!, 'a.com/two').collectionId, isNull);
  });

  testWidgets('Home keeps its own cards or rows choice', (t) async {
    final (c, _) = await boot(t, seed: twoCollections);
    await t.scrollUntilVisible(
      find.byKey(const Key('view-rows')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final first = c.library!.bookmarks.first.id;
    expect(find.byKey(ValueKey('recent-$first')), findsOneWidget);
    await tapKey(t, 'view-rows');
    await settle(t);
    expect(c.preferences[RecentlySaved.pref], isFalse);
    expect(find.byKey(ValueKey('recent-$first')), findsNothing);
    expect(find.byKey(ValueKey('bookmark-$first')), findsOneWidget);
    // The app-wide choice for other lists is untouched.
    expect(c.preferences['cards'], isNot(false));
  });

  testWidgets('with collections, a save not sorted is counted once: under '
      'Not sorted, not in Focus', (t) async {
    final (c, _) = await boot(
      t,
      seed: (c) => c.update(
        (l) => l.copyWith(
          collections: [SaveCollection(id: 'food', name: 'Food')],
          bookmarks: [
            for (final (i, b) in l.bookmarks.indexed)
              i == 0 ? b.copyWith(collectionId: 'food') : b,
          ],
        ),
      ),
    );
    expect(c.library!.bookmarks.where((b) => !b.isRead), hasLength(3));
    expect(find.text('2 saves not sorted'), findsOneWidget);
    expect(find.text('1 save not read yet'), findsOneWidget);
  });

  testWidgets('a share from a site already kept in a collection is '
      'suggested there', (t) async {
    final (c, _) = await showSheet(t, text: 'https://example.com/new');
    expect(c.places.first.collection?.id, 'c' * 32);
    expect(c.places.first.suggested, isTrue);
    expect(find.textContaining('Suggested'), findsOneWidget);
  });

  testWidgets('a share from somewhere new suggests nothing', (t) async {
    final (c, _) = await showSheet(t, text: 'https://other.org/x');
    expect(c.places.where((p) => p.suggested), isEmpty);
    expect(find.textContaining('Suggested'), findsNothing);
  });
}
