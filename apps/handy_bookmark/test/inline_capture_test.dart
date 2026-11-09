import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestStore;
import 'widget_test.dart' show start, tapKey;

void main() {
  testWidgets(
    'inline URL save keeps failed input and duplicate review never silently adds a second link',
    (t) async {
      final store = TestStore(), c = await start(t, store: store);
      final input = find.byKey(const Key('bookmark-inline-url'));
      await t.enterText(input, 'https://example.org/article');
      store.fail = true;
      await tapKey(t, 'bookmark-inline-save');
      expect(
        t.widget<TextField>(input).controller!.text,
        'https://example.org/article',
      );
      expect(store.rows, isEmpty);
      store.fail = false;
      await tapKey(t, 'bookmark-inline-save');
      expect(store.rows, hasLength(1));
      expect(t.widget<TextField>(input).controller!.text, isEmpty);
      final id = store.rows.keys.single;
      await t.enterText(input, 'https://example.org/article');
      // The Save button comes with the next frame.
      await t.pump();
      await tapKey(t, 'bookmark-inline-save');
      expect(find.text('Already saved'), findsOneWidget);
      await t.tap(find.text('Cancel').last);
      await t.pumpAndSettle();
      expect(store.rows.keys, [id]);
      expect(c.library!.bookmarks, hasLength(1));
    },
  );
}
