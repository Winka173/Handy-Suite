import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/services/share_inbox.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestInbox;
import 'new_flows_test.dart' show boot, settle;
import 'widget_test.dart' show tapKey;

Future<void> withCollections(dynamic c) => c.update(
  (SaveLibrary l) => l.copyWith(
    collections: [
      SaveCollection(id: 'food', name: 'Food', position: 0),
      SaveCollection(id: 'trip', name: 'Trips', position: 1),
    ],
  ),
);

void main() {
  testWidgets('a Share is saved first, then the sheet asks where it goes; '
      'choosing a collection and Pin moves it there', (t) async {
    final (c, _) = await boot(t, urls: const [], seed: withCollections);
    final inbox = c.inbox as TestInbox;
    inbox.pending = [
      const SharedLink('s1', 'https://example.com/pho', 'Phở bò'),
    ];
    // The write queue lives in the test's zone: drain outside runAsync.
    unawaited(c.drain());
    await settle(t);
    await settle(t);
    // Already saved and acknowledged before anything is asked.
    expect(inbox.acknowledgments, ['s1']);
    final saved = c.library!.bookmarks.single;
    expect(saved.collectionId, isNull);
    expect(find.byKey(const Key('file-shared')), findsOneWidget);
    expect(find.text('Phở bò'), findsWidgets);
    await tapKey(t, 'file-shared-food');
    expect(find.text('Put in Food'), findsOneWidget);
    await tapKey(t, 'file-shared-pin');
    await tapKey(t, 'file-shared-done');
    await settle(t);
    expect(find.byKey(const Key('file-shared')), findsNothing);
    final moved = c.library!.bookmarks.single;
    expect(moved.collectionId, 'food');
    expect(moved.isPinned, isTrue);
  });

  testWidgets('closing the sheet leaves the share in Not sorted; a share '
      'into a chosen collection is not asked about', (t) async {
    final (c, _) = await boot(t, urls: const [], seed: withCollections);
    final inbox = c.inbox as TestInbox;
    inbox.pending = [const SharedLink('s1', 'https://example.com/a', null)];
    // The write queue lives in the test's zone: drain outside runAsync.
    unawaited(c.drain());
    await settle(t);
    await settle(t);
    expect(find.byKey(const Key('file-shared')), findsOneWidget);
    await t.tapAt(const Offset(200, 40));
    await settle(t);
    expect(find.byKey(const Key('file-shared')), findsNothing);
    expect(c.library!.bookmarks.single.collectionId, isNull);

    inbox.pending = [
      const SharedLink('s2', 'https://example.com/b', null, [], 'trip'),
    ];
    // The write queue lives in the test's zone: drain outside runAsync.
    unawaited(c.drain());
    await settle(t);
    await settle(t);
    expect(find.byKey(const Key('file-shared')), findsNothing);
    expect(
      c.library!.bookmarks
          .firstWhere((b) => b.originalUrl.endsWith('/b'))
          .collectionId,
      'trip',
    );
  });

  testWidgets('New collection in the sheet makes one and chooses it', (
    t,
  ) async {
    final (c, _) = await boot(t, urls: const []);
    (c.inbox as TestInbox).pending = [
      const SharedLink('s1', 'https://example.com/a', null),
    ];
    // The write queue lives in the test's zone: drain outside runAsync.
    unawaited(c.drain());
    await settle(t);
    await settle(t);
    await tapKey(t, 'file-shared-new');
    await t.enterText(find.byKey(const Key('collection-name')), 'Reading');
    await tapKey(t, 'editor-save');
    await settle(t);
    expect(find.text('Put in Reading'), findsOneWidget);
    await tapKey(t, 'file-shared-done');
    await settle(t);
    final made = c.library!.collections.single;
    expect(c.library!.bookmarks.single.collectionId, made.id);
  });
}
