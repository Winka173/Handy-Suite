import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show boot, settle;
import 'widget_test.dart' show tapKey;

Future<void> openFind(WidgetTester t) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/find');
  await settle(t);
}

void main() {
  testWidgets('Search before a word: what the library holds, its tags and '
      'the latest saves; a word turns it into results', (t) async {
    final (c, _) = await boot(
      t,
      seed: (c) => c.update(
        (l) => l.copyWith(
          collections: [SaveCollection(id: 'food', name: 'Food')],
          tags: ['soup'],
          bookmarks: [
            for (final (i, b) in l.bookmarks.indexed)
              b.copyWith(tags: i == 0 ? ['soup'] : null, isFavorite: i == 1),
          ],
        ),
      ),
    );
    await openFind(t);
    expect(find.byKey(const Key('search-start')), findsOneWidget);
    expect(find.byKey(const Key('search-overview')), findsOneWidget);
    // 1 collection, 3 saved, 1 favourite, 3 not opened.
    expect(
      find.descendant(
        of: find.byKey(const Key('start-items')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('start-favorites')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('start-tag-soup')), findsOneWidget);
    for (final b in c.library!.bookmarks) {
      expect(find.byKey(Key('clip-${b.id}')), findsOneWidget);
    }
    expect(t.takeException(), isNull);

    await t.enterText(find.byType(TextField).first, 'one');
    await settle(t);
    expect(find.byKey(const Key('search-start')), findsNothing);

    await t.enterText(find.byType(TextField).first, '');
    await settle(t);
    await tapKey(t, 'start-tag-soup');
    await settle(t);
    expect(find.text('#soup'), findsWidgets);
  });

  testWidgets('an empty library says how Search will work, with zeros as '
      'zeros', (t) async {
    await boot(t, urls: const []);
    await openFind(t);
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(4));
  });

  testWidgets('Search start fits 320 px at 200% text', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await boot(t, size: const Size(320, 640));
    await openFind(t);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await settle(t);
    expect(t.takeException(), isNull);
  });
}
