import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestStore, TestInbox;
import 'new_flows_test.dart' show boot, settle, idOf;
import 'widget_test.dart' show tapKey;

Future<void> push(WidgetTester t, String route) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed(route);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('delete goes to Recently Deleted with Undo; restore and delete '
      'for good work from the Trash screen', (t) async {
    final (c, _) = await boot(t);
    final one = idOf(c, 'https://a.com/one');
    final two = idOf(c, 'https://b.org/two');
    await c.update((l) => moveToTrash(l, [one, two], saveTime()));
    await settle(t);
    expect(c.library!.bookmarks.map((b) => b.id), isNot(contains(one)));
    expect(c.library!.trash.length, 2);
    expect(c.store is TestStore, isTrue);
    expect((c.store as TestStore).trash.keys, unorderedEquals([one, two]));

    // It shows in the places list while something is there.
    expect(find.byKey(const Key('place-trash'), skipOffstage: false), findsOne);
    await push(t, '/trash');
    expect(find.text('Còn 30 ngày · Chưa xếp'), findsNothing); // English UI
    expect(find.textContaining('30 days left'), findsNWidgets(2));

    await tapKey(t, 'trash-restore-$one');
    await settle(t);
    expect(c.library!.bookmarks.map((b) => b.id), contains(one));
    expect(find.text('Restored.'), findsOneWidget);

    await tapKey(t, 'trash-purge-$two');
    expect(find.text('Delete for good?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tapKey(t, 'confirm-action');
    await settle(t);
    expect(c.library!.trash, isEmpty);
    expect(c.library!.tombstones.single.id, two);
    expect(find.byKey(const Key('trash-empty')), findsOneWidget);
  });

  test('an offline copy follows its item into Trash and back', () async {
    final store = TestStore();
    final c = SaveController(open: () async => store, shares: TestInbox());
    await c.initialize();
    final saved = await c.quickSave('https://example.org/article');
    final id = saved.single.id;
    await c.putReadingCopies({
      id: ReadingCopy.fromJson({
        'url': 'https://example.org/article',
        'title': 'Bài đọc',
        'savedAt': '2026-11-06T00:00:00.000Z',
        'blocks': [
          {'k': 'p', 't': 'Giữ khi ở Thùng rác.'},
        ],
      }),
    });
    await c.update((l) => moveToTrash(l, [id], saveTime()));
    expect(store.reading.containsKey(id), isFalse);
    expect(store.trashedCopies.containsKey(id), isTrue);
    expect(c.readingIds.containsKey(id), isFalse);
    await c.update((l) => restoreFromTrash(l, [id], saveTime()));
    expect(store.reading.containsKey(id), isTrue);
    expect(c.readingIds.containsKey(id), isTrue);
    c.dispose();
  });

  test(
    'opening the library deletes for good what has waited 30 days',
    () async {
      final store = TestStore();
      final old = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 31))
          .toIso8601String();
      final recent = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 2))
          .toIso8601String();
      Map<String, dynamic> item(String id, String deletedAt) => {
        ...Bookmark(
          id: id,
          originalUrl: 'https://example.org/$id',
          normalizedUrl: 'https://example.org/$id',
          savedAt: '2026-09-01T00:00:00.000Z',
          updatedAt: '2026-09-01T00:00:00.000Z',
        ).toJson(),
        'deletedAt': deletedAt,
      };
      store.trash['old'] = item('old', old);
      store.trash['recent'] = item('recent', recent);
      final c = SaveController(open: () async => store, shares: TestInbox());
      await c.initialize();
      expect(c.library!.trash.map((b) => b.id), ['recent']);
      expect(c.library!.tombstones.single.id, 'old');
      expect(store.trash.keys, ['recent']);
      c.dispose();
    },
  );

  testWidgets('deleting a collection with its links sends them to Trash, and '
      'restoring brings them to Not sorted', (t) async {
    final (c, _) = await boot(
      t,
      seed: (c) async {
        await c.update(
          (l) => l.copyWith(
            collections: [SaveCollection(id: 'trip', name: 'Trip')],
            bookmarks: [
              for (final b in l.bookmarks) b.copyWith(collectionId: 'trip'),
            ],
          ),
        );
      },
    );
    final scope = c;
    expect(scope.library!.bookmarks.length, 3);
    await c.update((l) {
      final trashed = moveToTrash(l, [
        for (final b in l.bookmarks) b.id,
      ], saveTime());
      return withCollectionTombstones(trashed.copyWith(collections: []), [
        'trip',
      ], saveTime());
    });
    await settle(t);
    expect(c.library!.trash.every((b) => b.collectionId == null), isTrue);
    expect(c.library!.tombstones.map((x) => x.entity), contains('collection'));
    await push(t, '/trash');
    await tapKey(t, 'trash-restore-${c.library!.trash.first.id}');
    await settle(t);
    expect(c.library!.bookmarks.single.collectionId, isNull);
  });
}
