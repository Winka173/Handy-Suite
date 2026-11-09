import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/links/link_tasks.dart';
import 'package:handy_bookmark/reader/keep_pictures.dart';
import 'package:handy_bookmark/services/metadata_client.dart';
import 'package:handy_bookmark/view/library_view.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'controller_test.dart' show TestStore, TestInbox;

const article =
    '<html><head><title>Pho at home</title></head><body><article>'
    '<p>Toast the spices, char the onion and ginger, then simmer the bones '
    'for hours, skimming often, until the broth is clear and deep.</p>'
    '<p>Slice the beef thin, pour the boiling broth over it, and add herbs, '
    'lime and chilli at the table, to taste.</p></article></body></html>';

/// Answers from a table instead of the network; records what was asked.
class FakeNet implements MetadataClient {
  FakeNet({this.available = true});
  @override
  final bool available;
  final asked = <String>[];
  final probes = <String, List<LinkProbe>>{};
  final pages = <String, PageResult>{};
  Completer<void>? gate;
  @override
  Future<LinkProbe> probe(String url, {CancellationToken? cancellation}) async {
    asked.add(url);
    await gate?.future;
    cancellation?.check();
    final list = probes[url];
    if (list == null || list.isEmpty) return const LinkProbe(status: 200);
    return list.length == 1 ? list.single : list.removeAt(0);
  }

  @override
  Future<PageResult> fetchPage(
    String url, {
    CancellationToken? cancellation,
  }) async {
    asked.add(url);
    return pages[url] ?? const PageResult(errorCode: 'httpStatus');
  }

  @override
  Future<MetadataResult> fetch(
    String url, {
    CancellationToken? cancellation,
  }) async => const MetadataResult(status: 'failed');
  @override
  Future<ThumbnailResult> fetchThumbnail(
    String url, {
    CancellationToken? cancellation,
  }) async => const ThumbnailResult();

  /// Pictures for kept copies, by address (none unless a test sets them).
  final articlePictures = <String, Uint8List>{};
  final pictureAsks = <String>[];
  @override
  Future<ThumbnailResult> fetchArticlePicture(
    String url, {
    CancellationToken? cancellation,
  }) async {
    pictureAsks.add(url);
    final bytes = articlePictures[url];
    return bytes == null
        ? const ThumbnailResult(errorCode: 'httpStatus')
        : ThumbnailResult(bytes: bytes, contentType: 'image/jpeg');
  }

  @override
  void dispose() {}
}

Future<(SaveController, FakeNet, TestStore)> boot({
  bool available = true,
}) async {
  final net = FakeNet(available: available);
  final store = TestStore();
  final c = SaveController(
    open: () async => store,
    shares: TestInbox(),
    metadataClient: net,
  );
  await c.initialize();
  for (final u in [
    'https://a.com/ok',
    'https://a.com/moved',
    'https://b.org/gone',
    'https://c.net/down',
  ]) {
    await c.quickSave(u);
  }
  return (c, net, store);
}

String idOf(SaveController c, String url) =>
    c.library!.bookmarks.firstWhere((b) => b.originalUrl == url).id;

void main() {
  test(
    'checks record a status per link, never change an address, and wait per host',
    () async {
      final (c, net, _) = await boot();
      net.probes['https://a.com/moved'] = [
        const LinkProbe(status: 200, permanentUrl: 'https://a.com/new-home'),
      ];
      net.probes['https://b.org/gone'] = [const LinkProbe(status: 404)];
      net.probes['https://c.net/down'] = [
        const LinkProbe(error: 'busy'),
        const LinkProbe(error: 'timeout'),
      ];
      final tasks = LinkTasks(
        c,
        hostSpacing: const Duration(milliseconds: 150),
        retryDelay: const Duration(milliseconds: 10),
      );
      final watch = Stopwatch()..start();
      final report = await tasks.checkLinks(
        c.library!.bookmarks.map((b) => b.id),
      );
      expect(report.done, 4);
      expect(report.counts, {'ok': 1, 'moved': 1, 'gone': 1, 'unreachable': 1});
      expect(report.broken, 3);
      // a.com was asked twice, at least one spacing apart; b and c filled
      // the gap instead of waiting.
      expect(net.asked.indexOf('https://b.org/gone'), lessThan(2));
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(150));
      // busy was retried, then the real answer recorded.
      expect(net.asked.where((u) => u == 'https://c.net/down'), hasLength(2));
      final moved = c.library!.bookmarks.firstWhere(
        (b) => b.id == idOf(c, 'https://a.com/moved'),
      );
      expect(moved.originalUrl, 'https://a.com/moved');
      expect(moved.linkCheck!.movedTo, 'https://a.com/new-home');
      final view = LibraryView(c)..place = Place.broken;
      await view.reload();
      expect(view.total, 3);
      view.dispose();
      c.dispose();
    },
  );

  test('stopping keeps the checks already done; one job at a time', () async {
    final (c, net, _) = await boot();
    final tasks = LinkTasks(c, hostSpacing: Duration.zero);
    net.gate = Completer<void>();
    final running = tasks.checkLinks(c.library!.bookmarks.map((b) => b.id));
    await Future<void>.delayed(Duration.zero);
    expect(tasks.running, isTrue);
    await expectLater(tasks.saveCopies(['x']), throwsStateError);
    // Let the first answer through, then stop.
    final first = net.gate!;
    net.gate = Completer<void>();
    first.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    tasks.cancel();
    net.gate!.complete();
    final report = await running;
    expect(report.cancelled, isTrue);
    expect(report.done, 1);
    expect(
      c.library!.bookmarks.where((b) => b.linkCheck != null),
      hasLength(1),
    );
    expect(tasks.running, isFalse);
    c.dispose();
  });

  test('runs are capped and refused where the network is unsafe', () async {
    final (c, _, _) = await boot(available: false);
    final tasks = LinkTasks(c);
    await expectLater(
      tasks.checkLinks(c.library!.bookmarks.map((b) => b.id)),
      throwsUnsupportedError,
    );
    c.dispose();
    final (c2, net, _) = await boot();
    for (var i = 0; i < LinkTasks.maxCopies + 3; i++) {
      await c2.quickSave('https://many$i.example.com/');
    }
    final report = await LinkTasks(
      c2,
      hostSpacing: Duration.zero,
    ).saveCopies(c2.library!.bookmarks.map((b) => b.id));
    expect(report.overCap, report.asked - LinkTasks.maxCopies);
    expect(report.done, LinkTasks.maxCopies);
    expect(net.asked, hasLength(LinkTasks.maxCopies));
    c2.dispose();
  });

  test(
    'reading copies are saved apart and go with their link on delete',
    () async {
      final (c, net, store) = await boot();
      final ok = idOf(c, 'https://a.com/ok');
      net.pages['https://a.com/ok'] = PageResult(
        html: article,
        uri: Uri.parse('https://a.com/ok'),
      );
      net.pages['https://a.com/moved'] = const PageResult(
        html: '<html><body><nav>Menu</nav></body></html>',
      );
      final report = await LinkTasks(c, hostSpacing: Duration.zero).saveCopies([
        ok,
        idOf(c, 'https://a.com/moved'),
        idOf(c, 'https://b.org/gone'),
      ]);
      expect(report.counts, {'saved': 1, 'noText': 1, 'failed': 1});
      expect(c.readingIds.keys, [ok]);
      final copy = (await c.readingCopy(ok))!;
      expect(copy.title, 'Pho at home');
      expect(copy.blocks, hasLength(2));
      // The bookmark row never carries the text.
      expect(store.rows[ok]!.containsKey('blocks'), isFalse);
      expect((await c.allReadingCopies()).keys, [ok]);
      await c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              if (b.id != ok) b,
          ],
        ),
      );
      expect(c.readingIds, isEmpty);
      expect(store.reading, isEmpty);
      c.dispose();
    },
  );

  test('schema 1 order in preferences moves into the library', () async {
    final store = TestStore();
    final c = SaveController(open: () async => store, shares: TestInbox());
    await c.initialize();
    await c.quickSave('https://a.com/1');
    await c.quickSave('https://a.com/2');
    final ids = c.library!.bookmarks.map((b) => b.id).toList();
    store.state = {
      ...store.state,
      'version': 1,
      'preferences': {'bookmarkOrder': ids.reversed.toList(), 'cards': true},
    }..remove('manualOrder');
    c.dispose();
    final again = SaveController(open: () async => store, shares: TestInbox());
    await again.initialize();
    expect(again.library!.manualOrder, ids.reversed);
    expect(again.preferences.containsKey('bookmarkOrder'), isFalse);
    expect(again.preferences['cards'], isTrue);
    await again.update((l) => l);
    expect(store.state['manualOrder'], ids.reversed);
    expect(store.state['version'], 2);
    again.dispose();
  });

  test('saved searches capture and restore place, words and filters', () async {
    final (c, _, _) = await boot();
    await c.update(
      (l) => l.copyWith(
        collections: [SaveCollection(id: 'col', name: 'Col')],
        bookmarks: [
          for (final b in l.bookmarks)
            b.originalUrl.contains('a.com')
                ? b.copyWith(collectionId: 'col', tags: ['t'])
                : b,
        ],
      ),
    );
    final v = LibraryView(c);
    v.show(Place.collection, 'col');
    v.text = 'moved';
    v.filters = const Filters(tag: 't', sort: 'title');
    expect(v.canSaveSearch, isTrue);
    final saved = SavedSearch(id: 's', name: 'Moved', query: v.savedQuery());
    v.show(Place.all);
    v.text = '';
    v.filters = const Filters();
    v.applySaved(saved);
    await v.reload();
    expect((v.place, v.id, v.text), (Place.collection, 'col', 'moved'));
    expect((v.filters.tag, v.filters.sort), ('t', 'title'));
    expect(v.results.single.originalUrl, 'https://a.com/moved');
    // A search from the earlier app (SearchQuery shape, no place).
    v.applySaved(
      SavedSearch(
        id: 'old',
        name: 'Old',
        query: {
          'text': '',
          'isFavorite': true,
          'tags': ['t'],
        },
      ),
    );
    expect((v.place, v.filters.tag), (Place.favorites, 't'));
    // Its collection was deleted: fall back to All links.
    v.applySaved(
      SavedSearch(id: 'x', name: 'X', query: {'collectionId': 'nope'}),
    );
    expect((v.place, v.id), (Place.all, null));
    v.dispose();
    c.dispose();
  });

  test(
    'a kept copy carries its article pictures; a failed one is left out',
    () async {
      final (c, net, _) = await boot();
      final ok = idOf(c, 'https://a.com/ok');
      const words =
          'Broth, noodles, herbs and lime, slowly, the way it is made at home in Hà Nội every morning. ';
      net.pages['https://a.com/ok'] = PageResult(
        html:
            '<html><head><title>Phở</title></head><body><article>'
            '<p>${words * 2}</p><img src="/bowl.jpg" alt="Bowl">'
            '<p>${words * 2}</p><img src="https://cdn.a.com/gone.jpg">'
            '<p>$words</p></article></body></html>',
        uri: Uri.parse('https://a.com/ok'),
      );
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);
      net.articlePictures['https://a.com/bowl.jpg'] = jpeg;
      final report = await LinkTasks(
        c,
        hostSpacing: Duration.zero,
      ).saveCopies([ok]);
      expect(report.counts, {'saved': 1});
      expect(net.pictureAsks, [
        'https://a.com/bowl.jpg',
        'https://cdn.a.com/gone.jpg',
      ]);
      final copy = (await c.readingCopy(ok))!;
      final pics = copy.blocks.where((b) => b.isPicture).toList();
      expect(pics, hasLength(2));
      expect(pics.first.picture, jpeg);
      expect(pics.first.text, 'Bowl');
      expect(pics.last.picture, isNull, reason: 'the text is kept anyway');
    },
  );

  test('no pictures are asked for where the network is off', () async {
    final (c, net, _) = await boot(available: false);
    final copy = ReadingCopy(
      url: 'https://a.com/x',
      title: 'x',
      savedAt: '2026-11-09T00:00:00Z',
      blocks: [
        ReadingBlock('p', 'Some words to read.'),
        ReadingBlock('img', '', url: 'https://a.com/p.jpg'),
      ],
    );
    final kept = await withArticlePictures(
      c.metadata,
      copy,
      CancellationToken(),
    );
    expect(identical(kept, copy), isTrue);
    expect(net.pictureAsks, isEmpty);
  });
}
