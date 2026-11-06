import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show boot, settle, idOf;
import 'widget_test.dart' show tapKey;

Future<void> push(WidgetTester t, String route) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed(route);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a link saved twice is offered for merging; the chosen copy '
      'stays and takes the other\'s note and collection', (t) async {
    final (c, _) = await boot(
      t,
      seed: (c) async {
        await c.quickSave(
          'https://a.com/one?utm_source=chat',
          title: 'Same page again',
          allowDuplicates: true,
        );
        final copy = c.library!.bookmarks.last;
        await c.update(
          (l) => l.copyWith(
            bookmarks: [
              for (final b in l.bookmarks)
                b.id == copy.id ? b.copyWith(note: 'ask Minh') : b,
            ],
          ),
        );
      },
    );
    expect(c.library!.bookmarks, hasLength(4));
    final copyId = c.library!.bookmarks.last.id;

    await push(t, '/settings');
    // Merging is one of the advanced library tools.
    await tapKey(t, 'set-library-tools');
    await t.scrollUntilVisible(
      find.byKey(const Key('save-duplicates')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 link saved twice'), findsOneWidget);
    await tapKey(t, 'save-duplicates');
    // Keep the newer copy this time.
    await tapKey(t, 'duplicates-keep-$copyId');
    await tapKey(t, 'duplicates-merge-0');
    await settle(t);
    expect(c.library!.bookmarks, hasLength(3));
    final kept = c.library!.bookmarks.firstWhere((b) => b.id == copyId);
    expect(kept.note, 'ask Minh');
    expect(kept.savedAt, isNot(isEmpty));
    expect(find.byKey(const Key('duplicates-none')), findsOneWidget);
    expect(idOf(c, 'https://b.org/two'), isNotEmpty);
  });

  testWidgets('with nothing saved twice, settings shows no merge entry', (
    t,
  ) async {
    await boot(t);
    await push(t, '/settings');
    await tapKey(t, 'set-library-tools');
    // The tools are there; the merge entry is not.
    await t.scrollUntilVisible(
      find.byKey(const Key('save-integrity')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('save-duplicates')), findsNothing);
  });
}
