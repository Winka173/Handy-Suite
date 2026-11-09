import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_core/handy_core.dart' show CancellationToken;
import 'package:handy_bookmark/ui/visual.dart' show ReadingShade;
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestStore, TestInbox;

class OpeningController extends SaveController {
  OpeningController(TestStore store)
    : super(open: () async => store, shares: TestInbox());
  String? openedUrl;
  @override
  Future<bool> open(Bookmark bookmark, {bool browser = false}) async {
    openedUrl = bookmark.originalUrl;
    return true;
  }
}

class Preferences implements PreferencesRepository {
  HandyPreferences value = HandyPreferences(locale: 'en');
  @override
  Future<HandyPreferences> load() async => value;
  @override
  Future<void> save(HandyPreferences next) async => value = next;
}

Future<OpeningController> start(
  WidgetTester tester, {
  TestStore? store,
  Size size = const Size(400, 900),
  Future<void> Function(OpeningController)? seed,
  double textScale = 1,
  String theme = 'light',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = OpeningController(store ?? TestStore());
  await tester.runAsync(c.initialize);
  // No pages are read here: a reading retried after a pause would outlive
  // the test.
  c.preferences['automaticMetadata'] = false;
  // The write queue lives in the test's zone: seed outside runAsync.
  await seed?.call(c);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(
        tester.view,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: SaveApp(
        controller: c,
        preferences: Preferences()
          ..value = HandyPreferences(locale: 'en', theme: theme),
        guide: false,
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
  addTearDown(c.dispose);
  return c;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty)
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pumpAndSettle();
}

Future<void> recipes(OpeningController c) async {
  await c.quickSave('https://www.youtube.com/watch?v=pho123');
  await c.update(
    (l) => l.copyWith(
      collections: [SaveCollection(id: 'recipes', name: 'Recipes')],
    ),
  );
}

void main() {
  testWidgets(
    'cancel writes nothing; a saved link waits in Not sorted and opens',
    (tester) async {
      final store = TestStore();
      final c = await start(tester, store: store);
      expect(find.text('Save something worth keeping'), findsOneWidget);
      await tapKey(tester, 'save-new');
      await tapKey(tester, 'save-add');
      await tester.enterText(
        find.byKey(const Key('save-text-input')),
        'https://github.com/flutter/flutter',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.rows, isEmpty);
      await tapKey(tester, 'save-new');
      await tapKey(tester, 'save-add');
      await tester.enterText(
        find.byKey(const Key('save-text-input')),
        'https://github.com/flutter/flutter',
      );
      await tapKey(tester, 'save-text-confirm');
      expect(store.rows, hasLength(1));
      final id = store.rows.keys.single;
      expect(find.byKey(ValueKey('recent-$id')), findsOneWidget);
      expect(find.text('1 item · 1 not sorted'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('recent-$id')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save-open-original')), findsOneWidget);
      await tapKey(tester, 'save-open-original');
      expect(c.openedUrl, 'https://github.com/flutter/flutter');
    },
  );

  testWidgets('one tap files a link; a failed write brings the card back', (
    tester,
  ) async {
    final store = TestStore();
    final c = await start(tester, store: store, seed: recipes);
    final id = c.library!.bookmarks.single.id;
    store.fail = true;
    // Home's Not sorted rows offer the usual collections as chips.
    await tapKey(tester, 'file-$id-recipes');
    expect(c.library!.bookmarks.single.collectionId, isNull);
    expect(find.byKey(Key('unsorted-$id')), findsOneWidget);
    store.fail = false;
    await tapKey(tester, 'file-$id-recipes');
    expect(c.library!.bookmarks.single.collectionId, 'recipes');
    // Filed: it leaves Not sorted.
    expect(find.byKey(Key('unsorted-$id')), findsNothing);
  });

  testWidgets('a card whose page is being read shows it, then stops', (
    tester,
  ) async {
    final c = await start(
      tester,
      seed: (c) => c.quickSave('https://example.com/a'),
    );
    final id = c.library!.bookmarks.single.id;
    final semantics = tester.ensureSemantics();
    c.fetching[id] = CancellationToken();
    c.changed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ReadingShade), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Reading the page')), findsWidgets);
    // The link is saved meanwhile: it is in the library already.
    expect(c.library!.bookmarks, hasLength(1));
    c.fetching.remove(id);
    c.changed();
    await tester.pumpAndSettle();
    expect(find.byType(ReadingShade), findsNothing);
    semantics.dispose();
  });

  testWidgets('a link saved twice asks before adding a copy', (tester) async {
    final c = await start(
      tester,
      seed: (c) => c.quickSave('https://example.com/a'),
    );
    await tapKey(tester, 'save-new');
    await tapKey(tester, 'save-add');
    await tester.enterText(
      find.byKey(const Key('save-text-input')),
      'https://example.com/a',
    );
    await tapKey(tester, 'save-text-confirm');
    expect(find.text('Already saved'), findsOneWidget);
    await tapKey(tester, 'dup-copy');
    expect(c.library!.bookmarks, hasLength(2));
  });

  testWidgets('select, archive, and undo from the message', (tester) async {
    final c = await start(
      tester,
      seed: (c) async {
        await c.quickSave('https://example.com/a');
        await c.quickSave('https://example.com/b');
      },
    );
    await tapKey(tester, 'open-search');
    await tester.enterText(find.byKey(const Key('save-search')), 'example');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
    final first = c.library!.bookmarks.first.id;
    await tester.longPress(find.byKey(ValueKey('card-$first')));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tapKey(tester, 'batch-archive');
    expect(c.library!.bookmarks.where((b) => b.isArchived), hasLength(1));
    await tester.tap(find.text('Undo'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(c.library!.bookmarks.where((b) => b.isArchived), isEmpty);
  });

  testWidgets('wide screens show places, links and the chosen link together', (
    tester,
  ) async {
    final c = await start(tester, size: const Size(1440, 900), seed: recipes);
    final id = c.library!.bookmarks.single.id;
    expect(find.byKey(const Key('place-inbox')), findsOneWidget);
    expect(find.byKey(const Key('collection-recipes')), findsOneWidget);
    await tapKey(tester, 'details-$id');
    await tapKey(tester, 'item-details');
    expect(find.byKey(const Key('save-open-original')), findsOneWidget);
    await tapKey(tester, 'detail-favorite');
    expect(c.library!.bookmarks.single.isFavorite, isTrue);
  });

  testWidgets('deleting a collection sends its links back to Not sorted', (
    tester,
  ) async {
    final c = await start(
      tester,
      size: const Size(1440, 900),
      seed: (c) async {
        await recipes(c);
        await c.update(
          (l) => l.copyWith(
            bookmarks: [
              for (final b in l.bookmarks) b.copyWith(collectionId: 'recipes'),
            ],
          ),
        );
      },
    );
    await tapKey(tester, 'collection-menu-recipes');
    await tapKey(tester, 'collection-delete');
    await tapKey(tester, 'delcol-inbox');
    expect(c.library!.collections, isEmpty);
    expect(c.library!.bookmarks.single.collectionId, isNull);
  });

  testWidgets('narrow large-text home, filters and settings remain usable', (
    tester,
  ) async {
    await start(
      tester,
      size: const Size(360, 800),
      textScale: 1.6,
      seed: recipes,
    );
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'open-search');
    await tester.enterText(find.byKey(const Key('save-search')), 'pho');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'save-filters');
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tapKey(tester, 'open-settings');
    expect(tester.takeException(), isNull);
  });
}
