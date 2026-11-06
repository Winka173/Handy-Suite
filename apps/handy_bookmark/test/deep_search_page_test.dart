import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/pro/entitlements.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show settle;
import 'reader_test.dart' show boot, copyOf, longArticle;
import 'widget_test.dart' show tapKey;

void main() {
  testWidgets('words only inside a saved article: Free search is unchanged '
      'and says how many more Pro would find; it never shows the passage', (
    t,
  ) async {
    await boot(
      t,
      seed: (c, id) => c.putReadingCopies({id: copyOf(longArticle(3))}),
    );
    await tapKey(t, 'open-search');
    await t.enterText(find.byKey(const Key('save-search')), 'skim it often');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(t);
    expect(find.text('0 found'), findsOneWidget, reason: 'ordinary search');
    expect(find.byKey(const Key('deep-locked')), findsOneWidget);
    expect(find.byKey(const Key('deep-matches')), findsNothing);
    await tapKey(t, 'deep-locked');
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
  });

  testWidgets('a title match is not counted again as a deep match', (t) async {
    await boot(
      t,
      seed: (c, id) => c.putReadingCopies({id: copyOf(longArticle(3))}),
    );
    await tapKey(t, 'open-search');
    // "Page one" is the title; the article does not say it.
    await t.enterText(find.byKey(const Key('save-search')), 'page');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(t);
    expect(find.text('1 found'), findsOneWidget);
    expect(find.byKey(const Key('deep-locked')), findsNothing);
  });

  testWidgets('with Pro, the item is listed with where it was found and the '
      'real passage; a highlight note is found too', (t) async {
    debugProOverride = true;
    addTearDown(() => debugProOverride = null);
    await boot(
      t,
      seed: (c, id) async {
        await c.putReadingCopies({id: copyOf(longArticle(3))});
      },
    );
    await tapKey(t, 'open-search');
    await t.enterText(find.byKey(const Key('save-search')), 'skim it often');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(t);
    expect(find.byKey(const Key('deep-matches')), findsOneWidget);
    expect(find.text('Inside article'), findsOneWidget);
    expect(
      find.textContaining('skim it often', findRichText: true),
      findsWidgets,
    );
  });
}
