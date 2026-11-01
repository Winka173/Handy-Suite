import 'package:flutter_test/flutter_test.dart';
import 'package:handy_save/controller.dart';
import 'package:handy_save/view/library_view.dart';
import 'package:handy_save_engine/handy_save_engine.dart';
import 'controller_test.dart' show TestStore, TestInbox;

Future<(SaveController, LibraryView)> setUpView() async {
  final c = SaveController(open: () async => TestStore(), shares: TestInbox());
  await c.initialize();
  await c.quickSave('https://www.youtube.com/watch?v=abc123');
  await c.quickSave('https://example.com/recipes/pho');
  await c.quickSave('https://shopee.vn/product/1/2');
  final recipes = SaveCollection(id: 'recipes', name: 'Recipes');
  await c.update(
    (l) => l.copyWith(
      collections: [recipes],
      bookmarks: [
        for (final b in l.bookmarks)
          b.originalUrl.contains('pho')
              ? b.copyWith(collectionId: 'recipes')
              : b,
      ],
    ),
  );
  final v = LibraryView(c)..place = Place.inbox;
  await v.reload();
  return (c, v);
}

void main() {
  test('places narrow the list: unsorted, a collection, all', () async {
    final (c, v) = await setUpView();
    expect(v.place, Place.inbox);
    expect(v.total, 2, reason: 'only the two links with no collection');
    v.place = Place.collection;
    v.id = 'recipes';
    await v.reload();
    expect(v.results.single.originalUrl, contains('pho'));
    v.place = Place.all;
    await v.reload();
    expect(v.total, 3);
    v.dispose();
    c.dispose();
  });

  test('archived links leave every place but the archive', () async {
    final (c, v) = await setUpView();
    v.place = Place.all;
    await v.reload();
    v.toggle(v.results.first.id);
    await v.batch((b) => b.copyWith(isArchived: true));
    await v.reload();
    expect(v.total, 2);
    v.place = Place.archive;
    await v.reload();
    expect(v.total, 1);
    v.dispose();
    c.dispose();
  });

  test('a batch change undoes once, and not after another change', () async {
    final (c, v) = await setUpView();
    v.place = Place.all;
    await v.reload();
    await v.selectAll();
    expect(v.selected.length, 3);
    await v.deleteSelected();
    expect(c.library!.bookmarks, isEmpty);
    expect(await v.undo(), isTrue);
    expect(c.library!.bookmarks.length, 3);
    expect(await v.undo(), isFalse);
    v.dispose();
    c.dispose();
  });

  test('a failed write keeps the library and the selection', () async {
    final store = TestStore();
    final c = SaveController(open: () async => store, shares: TestInbox());
    await c.initialize();
    await c.quickSave('https://example.com/a');
    final v = LibraryView(c);
    await v.reload();
    v.toggle(v.results.single.id);
    store.fail = true;
    await expectLater(v.deleteSelected(), throwsA(anything));
    expect(c.library!.bookmarks.length, 1);
    expect(v.canUndo, isFalse);
    v.dispose();
    c.dispose();
  });
}
