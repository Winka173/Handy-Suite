import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show boot, settle;
import 'widget_test.dart' show tapKey;

void main() {
  testWidgets('Home is a launchpad: at most four recent saves, newest '
      'first, never archived or deleted ones; the Focus count is the real '
      'unread count', (t) async {
    final urls = [for (var i = 0; i < 7; i++) 'https://site$i.com/p'];
    final (c, _) = await boot(
      t,
      urls: urls,
      seed: (c) => c.update((l) {
        final byUrl = {for (final b in l.bookmarks) b.originalUrl: b};
        String at(int i) => '2026-11-0${i + 1}T10:00:00Z';
        final list = [
          for (final (i, u) in urls.indexed)
            byUrl[u]!.copyWith(
              savedAt: at(i),
              // site6 (newest) is archived; site0 and site1 were read.
              isArchived: i == 6,
              isRead: i < 2,
            ),
        ];
        // site5 goes to Trash.
        return moveToTrash(l.copyWith(bookmarks: list), [
          byUrl[urls[5]]!.id,
        ], '2026-11-06T00:00:00Z');
      }),
    );
    final id = {for (final b in c.library!.bookmarks) b.originalUrl: b.id};
    final shown = [
      for (final u in urls)
        if (id[u] != null &&
            find.byKey(Key('recent-${id[u]}')).evaluate().isNotEmpty)
          u,
    ];
    await t.scrollUntilVisible(
      find.byKey(const Key('recent')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final rows = [
      for (final u in urls)
        if (id[u] != null &&
            find
                .byKey(Key('recent-${id[u]}'), skipOffstage: false)
                .evaluate()
                .isNotEmpty)
          u,
    ];
    expect(shown.length, lessThanOrEqualTo(4));
    expect(rows, [urls[1], urls[2], urls[3], urls[4]]);
    final ys = [
      for (final u in rows.reversed)
        t.getTopLeft(find.byKey(Key('recent-${id[u]}'))).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()), reason: 'newest first');
    // Unread and live: site2, site3, site4 (site5 is in Trash, site6 is
    // archived, site0 and site1 were read).
    expect(find.text('3 things waiting to revisit'), findsOneWidget);
    await tapKey(t, 'recent-all');
    expect(find.byKey(const Key('save-home')), findsNothing);
  });

  testWidgets('with nothing unread, Focus is one calm line', (t) async {
    final (c, _) = await boot(
      t,
      seed: (c) => c.update(
        (l) => l.copyWith(
          bookmarks: [for (final b in l.bookmarks) b.copyWith(isRead: true)],
        ),
      ),
    );
    expect(find.text('All caught up. Nothing waiting in Focus.'), findsOne);
    expect(c.library!.bookmarks, hasLength(3));
    await tapKey(t, 'place-focus');
    await settle(t);
    expect(find.byKey(const Key('save-home')), findsNothing);
  });

  testWidgets('a fresh library has one Save: the Quick Save row', (t) async {
    await boot(t, urls: const []);
    expect(find.byKey(const Key('bookmark-inline-url')), findsOneWidget);
    expect(find.byKey(const Key('save-new')), findsOneWidget);
    // The one filled button on Home is Save itself.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byKey(const Key('recent')), findsNothing);
    expect(find.byKey(const Key('place-focus')), findsNothing);
  });
}
