import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/reader/article_view.dart';
import 'package:handy_bookmark/reader/highlights_sheet.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show settle;
import 'reader_test.dart' show boot, copyOf, longArticle, openReader;
import 'widget_test.dart' show tapKey;

void main() {
  testWidgets('highlights made earlier stay readable and editable without '
      'Pro, show in the text, and making a new one asks for Pro', (t) async {
    final (c, _, id) = await boot(
      t,
      seed: (c, id) async {
        await c.putReadingCopies({id: copyOf(longArticle(6))});
        await c.update(
          (l) => l,
          prefs: {
            ...c.preferences,
            'highlights': {
              id: [
                const Highlight(
                  id: 'h1',
                  block: 2,
                  start: 14,
                  end: 30,
                  quote: 'Simmer the broth',
                  color: 'green',
                  note: 'Low heat',
                  createdAt: '2026-11-06T10:00:00Z',
                ).toJson(),
              ],
            },
          },
        );
      },
    );
    await openReader(t, id);
    // Drawn in place, in its colour.
    final view = t.widget<ArticleView>(find.byType(ArticleView));
    expect(view.marks.values.expand((m) => m).single.$3, 'green');
    expect(find.text('1'), findsOneWidget, reason: 'the badge counts it');

    await tapKey(t, 'reader-highlights');
    expect(find.text('Simmer the broth'), findsOneWidget);
    expect(find.text('Low heat'), findsOneWidget);
    await tapKey(t, 'highlight-h1-edit');
    await t.enterText(find.byKey(const Key('highlight-note')), 'Very low');
    await tapKey(t, 'highlight-color-pink');
    await tapKey(t, 'highlight-save');
    await settle(t);
    final h = highlightsOf(c, id).single;
    expect((h.note, h.color), ('Very low', 'pink'));

    // Deleting one with a note asks first; Cancel keeps it.
    await tapKey(t, 'highlight-h1-delete');
    await t.tap(find.text('Cancel').last);
    await settle(t);
    expect(highlightsOf(c, id), hasLength(1));
    await t.tapAt(const Offset(200, 40));
    await settle(t);

    // A new highlight is Pro: the menu's action goes to Explore Pro and
    // writes nothing.
    t.widget<ArticleView>(find.byType(ArticleView)).onHighlight!('the broth');
    await settle(t);
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
    expect(highlightsOf(c, id), hasLength(1));
  });
}
