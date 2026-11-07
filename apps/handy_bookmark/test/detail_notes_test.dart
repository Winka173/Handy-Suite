import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show boot, idOf, openDetail, settle;
import 'widget_test.dart' show tapKey;

void main() {
  testWidgets('tags and the note are on the page: add and remove a tag, '
      'type a note and it saves itself', (t) async {
    final (c, _) = await boot(t);
    final id = idOf(c, 'https://a.com/one');
    await openDetail(t, id);
    expect(find.byKey(const Key('detail-notes')), findsOneWidget);

    await t.ensureVisible(find.byKey(const Key('detail-tag-add')));
    await tapKey(t, 'detail-tag-add');
    await t.enterText(find.byKey(const Key('tag-input')), '#soup');
    await tapKey(t, 'tag-add');
    await settle(t);
    expect(c.library!.bookmarks.firstWhere((b) => b.id == id).tags, ['soup']);
    expect(find.byKey(const Key('detail-tag-soup')), findsOneWidget);

    await t.ensureVisible(find.byKey(const Key('detail-note')));
    await t.enterText(find.byKey(const Key('detail-note')), 'Try on Sunday');
    // Saved a moment after typing stops, without pressing anything.
    await t.pump(const Duration(milliseconds: 800));
    await settle(t);
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == id).note,
      'Try on Sunday',
    );

    await t.ensureVisible(find.byKey(const Key('detail-tag-soup')));
    await t.tap(find.byTooltip('Remove #soup'));
    await settle(t);
    expect(c.library!.bookmarks.firstWhere((b) => b.id == id).tags, isEmpty);
  });

  testWidgets('a tag used elsewhere is offered to pick', (t) async {
    final (c, _) = await boot(
      t,
      seed: (c) => c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final (i, b) in l.bookmarks.indexed)
              i == 1 ? b.copyWith(tags: ['weekend']) : b,
          ],
        ),
      ),
    );
    final id = idOf(c, 'https://a.com/one');
    await openDetail(t, id);
    await t.ensureVisible(find.byKey(const Key('detail-tag-add')));
    await tapKey(t, 'detail-tag-add');
    await tapKey(t, 'tag-pick-weekend');
    await settle(t);
    expect(c.library!.bookmarks.firstWhere((b) => b.id == id).tags, [
      'weekend',
    ]);
  });

  testWidgets('Refresh reads the page again, only when pressed', (t) async {
    // Reading after saving switched off: only Refresh may read the page.
    final (c, _) = await boot(
      t,
      urls: const [],
      seed: (c) async {
        await c.update(
          (l) => l,
          prefs: {...c.preferences, 'automaticMetadata': false},
        );
        await c.quickSave('https://a.com/one', title: 'Page one');
      },
    );
    final id = idOf(c, 'https://a.com/one');
    String status() =>
        c.library!.bookmarks.firstWhere((b) => b.id == id).metadataStatus;
    expect(status(), isNot('failed'), reason: 'nothing read before');
    await openDetail(t, id);
    await tapKey(t, 'detail-refresh');
    await settle(t, 200);
    // The fake page cannot be read: the attempt is recorded.
    expect(status(), 'failed');
  });
}
