import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_files/handy_files.dart';
import 'new_flows_test.dart' show OneFile, boot, settle;
import 'pictures_test.dart' show png;
import 'widget_test.dart' show tapKey;

void main() {
  testWidgets('Links / Pictures narrows the library; All brings both back', (
    t,
  ) async {
    final files = OneFile()..next = ImportedBytes('Bảng giá.png', png(64, 48));
    final (c, _) = await boot(
      t,
      files: files,
      urls: ['https://a.com/one', 'https://b.org/two'],
    );
    await tapKey(t, 'save-new');
    await tapKey(t, 'save-photo');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(t);
    expect(find.text('Pictures 1'), findsOneWidget);
    expect(find.text('Links 2'), findsOneWidget);
    await tapKey(t, 'kind-image');
    await settle(t);
    expect(find.text('Bảng giá'), findsWidgets);
    expect(find.text('Page one'), findsNothing);
    await tapKey(t, 'kind-link');
    await settle(t);
    expect(find.text('Page one'), findsWidgets);
    expect(find.text('Bảng giá'), findsNothing);
    await tapKey(t, 'kind-all');
    await settle(t);
    expect(c.library!.bookmarks, hasLength(3));
    expect(find.byKey(const Key('save-home')), findsOneWidget);
  });

  testWidgets('without pictures there is nothing to choose between', (t) async {
    await boot(t);
    expect(find.byKey(const Key('kind-image')), findsNothing);
  });

  testWidgets('collections show as covers that open the collection', (t) async {
    final (c, _) = await boot(
      t,
      seed: (c) => c.update(
        (l) => l.copyWith(
          collections: [SaveCollection(id: 'food', name: 'Món ngon')],
          bookmarks: [
            for (final b in l.bookmarks) b.copyWith(collectionId: 'food'),
          ],
        ),
      ),
    );
    expect(find.text('3 links'), findsOneWidget);
    // The cover names it (the shelf above shows it on each card too).
    expect(
      find.descendant(
        of: find.byKey(const Key('collection-food')),
        matching: find.text('Món ngon'),
      ),
      findsOneWidget,
    );
    await tapKey(t, 'collection-food');
    await settle(t);
    expect(find.text('Page one'), findsWidgets);
    expect(c.library!.collections.single.name, 'Món ngon');
  });

  testWidgets('one Save button holds every way to add', (t) async {
    await boot(t);
    await tapKey(t, 'save-new');
    for (final key in [
      'bookmark-inline-url',
      'save-paste',
      'save-add',
      'save-photo',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });
}
