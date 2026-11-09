import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/services/metadata_client.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestStore, TestInbox;
import 'link_tasks_test.dart' show FakeNet, article;
import 'widget_test.dart' show Preferences, tapKey;

/// Opens nothing outside; records what would have opened.
class NetController extends SaveController {
  NetController(TestStore store, FakeNet net)
    : super(open: () async => store, shares: TestInbox(), metadataClient: net);
  @override
  Future<bool> open(Bookmark bookmark, {bool browser = false}) async => true;
}

/// Hands over one prepared file, as if the person picked it.
class OneFile implements HandyFiles {
  ImportedBytes? next;
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => next;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async => name;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async => name;
}

Future<(NetController, FakeNet)> boot(
  WidgetTester t, {
  Size size = const Size(400, 900),
  bool web = false,
  HandyFiles? files,
  List<String> urls = const [
    'https://a.com/one',
    'https://b.org/two',
    'https://c.net/three',
  ],
  Future<void> Function(NetController)? seed,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final net = FakeNet(available: !web);
  final c = NetController(TestStore(), net);
  await t.runAsync(c.initialize);
  for (final u in urls) {
    await c.quickSave(u, title: 'Page ${u.split('/').last}');
  }
  await seed?.call(c);
  await t.pumpWidget(
    SaveApp(
      controller: c,
      files: files ?? OneFile(),
      preferences: Preferences()..value = HandyPreferences(locale: 'en'),
      guide: false,
    ),
  );
  await settle(t);
  addTearDown(c.dispose);
  return (c, net);
}

/// Lets isolates, timers and the job runner finish, then settles frames.
Future<void> settle(WidgetTester t, [int ms = 60]) async {
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await t.pumpAndSettle();
}

String idOf(SaveController c, String url) =>
    c.library!.bookmarks.firstWhere((b) => b.originalUrl == url).id;

Future<void> openDetail(WidgetTester t, String id) async {
  Navigator.of(
    t.element(find.byType(Scaffold).first),
  ).pushNamed('/bookmark/$id');
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Pocket: preview first, Cancel changes nothing, Add files into '
      'Pocket with Undo', (t) async {
    final files = OneFile()
      ..next = ImportedBytes(
        'part_000000.csv',
        File(
          '../../packages/handy_bookmark_engine/test/fixtures/part_000000.csv',
        ).readAsBytesSync(),
      );
    final (c, _) = await boot(t, size: const Size(1440, 900), files: files);
    await tapKey(t, 'open-settings');
    // Other apps' exports sit under Advanced export and import.
    await tapKey(t, 'set-advanced-data');
    await tapKey(t, 'save-import-pocket');
    await settle(t, 300);
    expect(find.text('Bring in 3 links from Pocket?'), findsOneWidget);
    expect(find.textContaining('1 archived'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(c.library!.bookmarks, hasLength(3));
    await tapKey(t, 'save-import-pocket');
    await settle(t, 300);
    await t.tap(find.byKey(const Key('pocket-add')));
    await settle(t);
    final l = c.library!;
    expect(l.bookmarks, hasLength(6));
    expect(l.collections.single.name, 'Pocket');
    expect(l.bookmarks.where((b) => b.isArchived), hasLength(1));
    expect(find.text('3 links added from Pocket.'), findsOneWidget);
  });

  testWidgets('offline copy: save from details, read it calmly, size sticks', (
    t,
  ) async {
    final (c, net) = await boot(t);
    final id = idOf(c, 'https://a.com/one');
    net.pages['https://a.com/one'] = PageResult(
      html: article,
      uri: Uri.parse('https://a.com/one'),
    );
    await openDetail(t, id);
    await tapKey(t, 'detail-tools');
    expect(find.byKey(const Key('detail-read-offline')), findsNothing);
    await t.ensureVisible(find.byKey(const Key('detail-copy-save')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('detail-copy-save')));
    await t.pump();
    // The page is read in an isolate; give it real time while it spins.
    expect(find.byKey(const Key('detail-copy-stop')), findsOneWidget);
    for (var i = 0; i < 50 && c.readingIds.isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
    }
    await settle(t);
    expect(c.readingIds.keys, [id]);
    expect(find.text('Saved for offline reading.'), findsOneWidget);
    await tapKey(t, 'detail-read-offline');
    await settle(t);
    expect(find.text('Pho at home'), findsOneWidget);
    expect(find.textContaining('Toast the spices'), findsOneWidget);
    await t.tap(find.byKey(const Key('reader-larger')));
    await settle(t);
    expect(c.preferences['readerSize'], 20);
    await t.tap(find.byKey(const Key('reader-tone')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('reader-tone-dark')).last);
    await settle(t);
    expect(c.preferences['readerTone'], 'dark');
    expect(t.takeException(), isNull);
  });

  testWidgets('a moved link is never changed until asked; Undo puts it back', (
    t,
  ) async {
    final (c, net) = await boot(t);
    final id = idOf(c, 'https://b.org/two');
    net.probes['https://b.org/two'] = [
      const LinkProbe(status: 200, permanentUrl: 'https://b.org/2026/two'),
    ];
    await openDetail(t, id);
    await tapKey(t, 'detail-tools');
    await tapKey(t, 'detail-check');
    await settle(t, 200);
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == id).originalUrl,
      'https://b.org/two',
    );
    expect(find.textContaining('Moved'), findsWidgets);
    await tapKey(t, 'detail-adopt');
    await settle(t);
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == id).originalUrl,
      'https://b.org/2026/two',
    );
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == id).originalUrl,
      'https://b.org/two',
    );
  });

  testWidgets('in the browser, both network tools say plainly they are off', (
    t,
  ) async {
    final (c, net) = await boot(t, web: true);
    await openDetail(t, idOf(c, 'https://a.com/one'));
    await tapKey(t, 'detail-tools');
    expect(find.text('Not available in the browser.'), findsWidgets);
    await tapKey(t, 'detail-copy-save');
    expect(find.text('Not available in the browser'), findsOneWidget);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    await tapKey(t, 'detail-check');
    expect(find.text('Not available in the browser'), findsOneWidget);
    expect(net.asked, isEmpty);
  });

  testWidgets(
    'checking a list reports, and Broken links gathers the problems',
    (t) async {
      final (c, net) = await boot(t, size: const Size(1440, 900));
      net.probes['https://b.org/two'] = [const LinkProbe(status: 404)];
      net.probes['https://c.net/three'] = [const LinkProbe(error: 'timeout')];
      // From the Library overview to the list it checks.
      await tapKey(t, 'place-all');
      await tapKey(t, 'list-more');
      await tapKey(t, 'check-here');
      await settle(t, 600);
      expect(find.byKey(const Key('task-report')), findsOneWidget);
      expect(
        find.textContaining(
          'Checked 3 links: 1 work, 1 gone, 1 could not tell',
        ),
        findsOneWidget,
      );
      await tapKey(t, 'task-broken');
      await settle(t);
      expect(find.byKey(const Key('place-broken')), findsOneWidget);
      expect(find.text('Broken links'), findsWidgets);
      expect(find.textContaining('Gone · 404'), findsOneWidget);
      expect(find.textContaining('Could not tell'), findsOneWidget);
    },
  );

  testWidgets('saved searches: a kept one opens its words from Library > '
      'Advanced; no new ones are offered', (t) async {
    final (c, _) = await boot(
      t,
      seed: (c) => c.update(
        (l) => l.copyWith(
          savedSearches: [
            SavedSearch(
              id: 's1',
              name: 'Page two',
              query: {'text': 'two', 'place': 'all'},
            ),
          ],
        ),
      ),
    );
    // Retired on 2026-11-06: not on the home, only kept under Advanced.
    expect(find.byKey(const Key('search-s1')), findsNothing);
    await tapKey(t, 'home-library');
    await tapKey(t, 'library-advanced');
    await tapKey(t, 'search-s1');
    await settle(t);
    expect(find.text('Page two'), findsWidgets);
    expect(
      find.byKey(ValueKey('card-${idOf(c, 'https://b.org/two')}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('bookmark-${idOf(c, 'https://a.com/one')}')),
      findsNothing,
    );
    // A search can no longer be saved from its list.
    await tapKey(t, 'list-more');
    expect(find.byKey(const Key('save-search-here')), findsNothing);
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(c.library!.savedSearches, hasLength(1));
    // The kept one can still be renamed and deleted from the Library.
    await t.binding.handlePopRoute();
    await settle(t);
    await tapKey(t, 'search-menu-s1');
    await tapKey(t, 'search-delete');
    await settle(t);
    expect(c.library!.savedSearches, isEmpty);
  });
}
