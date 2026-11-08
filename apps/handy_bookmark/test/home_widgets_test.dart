import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/platform/home_widgets.dart';
import 'package:handy_bookmark/platform/widget_styles.dart';
import 'package:handy_bookmark/pro/entitlements.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show boot;
import 'widget_test.dart' show tapKey;

Bookmark item(
  String id,
  String saved, {
  bool read = false,
  bool favorite = false,
  String? collection,
  String? opened,
  String title = '',
}) => Bookmark(
  id: id,
  originalUrl: 'https://$id.com/',
  normalizedUrl: 'https://$id.com/',
  canonicalUrl: 'https://$id.com/',
  platform: 'web',
  contentType: 'article',
  sourceDomain: '$id.com',
  title: title.isEmpty ? 'Item $id' : title,
  savedAt: saved,
  updatedAt: saved,
  isRead: read,
  isFavorite: favorite,
  collectionId: collection,
  lastOpenedAt: opened,
);

final now = DateTime.utc(2026, 11, 9, 8);

SaveLibrary lib() => SaveLibrary(
  collections: [
    SaveCollection(id: 'c' * 32, name: 'Food'),
    SaveCollection(id: 'd' * 32, name: 'Trips', position: 1),
  ],
  bookmarks: [
    item('new1', '2026-11-08T10:00:00Z'),
    item('new2', '2026-11-07T10:00:00Z', collection: 'c' * 32),
    item('old', '2026-08-01T10:00:00Z'),
    item('fav', '2026-09-01T10:00:00Z', read: true, favorite: true),
    item('readc', '2026-10-01T10:00:00Z', read: true, collection: 'c' * 32),
    item('trip', '2026-10-02T10:00:00Z', read: true, collection: 'd' * 32),
  ],
);

void main() {
  test('reading queue: newest unread first, three names, a count', () {
    final v = queueView(lib(), vi: false);
    expect(v.value, '3 unread');
    expect(v.rows.map((r) => r.$1), ['Item new1', 'Item new2', 'Item old']);
    expect(v.rows.first.$2, 'handy-bookmark://item?id=new1');
    expect(queueView(lib(), vi: true, names: false).rows, isEmpty);
    final empty = queueView(SaveLibrary(), vi: true);
    expect((empty.value, empty.detail), ('0 chưa đọc', 'Chưa có gì để đọc'));
  });

  test('shelf: the picked collection, else the fullest, else Not sorted', () {
    expect(shelfView(lib(), vi: false).title, 'Food');
    expect(shelfView(lib(), vi: false, collection: 'd' * 32).title, 'Trips');
    // A deleted collection falls back.
    expect(shelfView(lib(), vi: false, collection: 'gone').title, 'Food');
    expect(shelfView(SaveLibrary(), vi: true).title, 'Chưa xếp');
  });

  test('picks: four labelled lines, no item twice, the same all day', () {
    final picks = readingPicks(lib(), now, vi: false);
    expect(picks.map((p) => p.$1), [
      'Just saved',
      'Waiting a while',
      'Favourite',
      'Food',
    ]);
    expect(picks.map((p) => p.$2.id).toSet(), hasLength(4));
    expect(picks[1].$2.id, 'old');
    final later = readingPicks(
      lib(),
      now.add(const Duration(hours: 10)),
      vi: false,
    );
    expect(later.map((p) => p.$2.id), picks.map((p) => p.$2.id));
    // Locked without Pro: no data at all.
    final locked = picksView(lib(), now, vi: false, pro: false);
    expect(locked.value, 'Unlock in the app');
    expect(locked.rows, isEmpty);
  });

  test(
    'gallery: its picture paths travel as extra keys, cleared beyond four',
    () {
      final b = lib().bookmarks.first;
      final v = galleryView(lib(), [(b, '/x/g0.jpg')], vi: false, pro: true);
      final data = v.toData();
      expect(data['img0'], '/x/g0.jpg');
      expect(data.containsKey('img3'), isTrue);
      expect(data['img3'], isNull);
    },
  );

  test('styles: Pro ones fall back without Pro, the choice is kept', () {
    final prefs = {'widgetStyle': 'reading-room'};
    expect(bookmarkWidgetStyleOf(prefs, pro: false).id, 'system');
    expect(bookmarkWidgetStyleOf(prefs, pro: true).id, 'reading-room');
    expect(bookmarkWidgetStyleOf({}, pro: false).native, isNull);
    expect(bookmarkWidgetStyleById('dark').native!['bg'], 'ff1a1c1e');
  });

  testWidgets('settings: five previews; a Pro style previews and asks only '
      'at Apply; names can be hidden', (t) async {
    debugProOverride = null;
    addTearDown(() => debugProOverride = null);
    final (c, _) = await boot(t, size: const Size(400, 2600));
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/widgets');
    await t.pumpAndSettle();
    for (final k in ['save', 'queue', 'shelf', 'picks', 'gallery']) {
      expect(find.byKey(Key('widget-$k')), findsOneWidget, reason: k);
    }
    await tapKey(t, 'widget-style-dark');
    expect(c.preferences['widgetStyle'], 'dark');
    await tapKey(t, 'widget-style-reading-room');
    expect(c.preferences['widgetStyle'], 'dark');
    expect(find.byKey(const Key('widget-style-apply')), findsOneWidget);
    await tapKey(t, 'widget-style-apply');
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(c.preferences['widgetStyle'], 'dark');
    await tapKey(t, 'widget-hide-names');
    expect(c.preferences['widgetHideNames'], isTrue);
  });
}
