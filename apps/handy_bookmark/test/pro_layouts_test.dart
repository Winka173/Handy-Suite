import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/design/identity.dart';
import 'package:handy_bookmark/design/theme.dart';
import 'package:handy_bookmark/pro/layouts.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestStore, TestInbox;
import 'new_flows_test.dart' show settle;
import 'widget_test.dart' show start, tapKey;

void main() {
  test('backups keep a collection layout id, and drop a malformed one', () {
    final views = SavePortable.readCollectionViews(
      {
        'a': {'layout': 'magazine', 'cards': true},
        'b': {'layout': 'BAD id!'},
      },
      ['a', 'b'],
    );
    expect(views['a'], {'layout': 'magazine', 'cards': true});
    expect(views.containsKey('b'), isFalse);
  });

  for (final (size, scale) in [
    (const Size(320, 900), 2.0),
    (const Size(390, 900), 1.0),
  ]) {
    testWidgets('all eight Pro layouts draw at ${size.width.toInt()} px, '
        'text x$scale, with links, a picture-less save and a long title', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = SaveController(
        open: () async => TestStore(),
        shares: TestInbox(),
      );
      await t.runAsync(c.initialize);
      for (final (i, u) in [
        'https://www.youtube.com/watch?v=1',
        'https://shopee.vn/p/2',
        'https://vnexpress.net/a-3',
      ].indexed) {
        await c.quickSave(
          u,
          title: i == 2
              ? 'Mùa đẹp nhất để đi Hà Giang: lịch trình bốn ngày qua Đồng Văn, Mèo Vạc và Hoàng Su Phì'
              : 'Item $i',
        );
      }
      expect(galleryLayouts, hasLength(8));
      for (final l in galleryLayouts) {
        await t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              theme: bookmarkTheme(
                buildHandyTheme(
                  const Color(0xFF0E7490),
                  Brightness.light,
                  bookmarkIdentity,
                ),
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Builder(
                    builder: (context) => l.build(
                      context,
                      LayoutData(
                        controller: c,
                        rows: c.library!.bookmarks,
                        onOpen: (_) {},
                        onDetails: (_) {},
                        onToggle: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pump();
        expect(t.takeException(), isNull, reason: l.id);
      }
      c.dispose();
    });
  }

  testWidgets('Free previews a Pro layout on its own list; using it leads '
      'to Explore Pro and nothing is stored', (t) async {
    final c = await start(
      t,
      seed: (c) async {
        await c.update(
          (l) => l.copyWith(
            collections: [SaveCollection(id: 'food', name: 'Food')],
          ),
        );
        await c.quickSave('https://a.com/x', title: 'Phở');
        await c.update(
          (l) => l.copyWith(
            bookmarks: [
              for (final b in l.bookmarks) b.copyWith(collectionId: 'food'),
            ],
          ),
        );
      },
    );
    await tapKey(t, 'collection-food');
    await tapKey(t, 'save-layout');
    await tapKey(t, 'layout-magazine');
    expect(find.text('Use with Pro'), findsOneWidget);
    await tapKey(t, 'layout-next');
    await tapKey(t, 'layout-use');
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
    await t.pageBack();
    await settle(t);
    await tapKey(t, 'layout-keep');
    final views = c.preferences['collectionViews'] as Map? ?? const {};
    expect((views['food'] as Map?)?['layout'], isNull);
  });
}
