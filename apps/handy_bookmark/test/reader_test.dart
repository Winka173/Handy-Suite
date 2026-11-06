import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark/reader/find_in_text.dart';
import 'package:handy_bookmark/reader/reading_position.dart';
import 'package:handy_bookmark/services/metadata_client.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestStore;
import 'link_tasks_test.dart' show FakeNet, article;
import 'new_flows_test.dart' show NetController, OneFile, settle;
import 'widget_test.dart' show Preferences;

/// A network whose page answers wait for [gate], and honour Cancel.
class GatedNet extends FakeNet {
  GatedNet({super.available});
  Completer<void>? pageGate;
  @override
  Future<PageResult> fetchPage(
    String url, {
    CancellationToken? cancellation,
  }) async {
    asked.add(url);
    await pageGate?.future;
    if (cancellation?.isCancelled == true) {
      return const PageResult(errorCode: 'cancelled');
    }
    return pages[url] ?? const PageResult(errorCode: 'httpStatus');
  }
}

/// Records what the person asked to open outside the app.
class OpeningController extends NetController {
  OpeningController(super.store, super.net);
  final opened = <String>[];
  @override
  Future<bool> open(Bookmark bookmark, {bool browser = false}) async {
    opened.add(bookmark.originalUrl);
    return true;
  }
}

const url = 'https://a.com/one';

/// A long article: [n] paragraphs, every one mentioning broth.
String longArticle(int n) =>
    '<html><head><title>Long broth</title></head><body><article>'
    '${[for (var i = 0; i < n; i++) '<p>Paragraph $i. Simmer the broth slowly, skim it often, and taste it again before the herbs go in, so the bowl stays clear.</p>'].join()}'
    '</article></body></html>';

ReadingCopy copyOf(String html) =>
    extractReadingCopy(html, url: url, savedAt: '2026-11-01T08:00:00Z')!;

Future<(OpeningController, GatedNet, String)> boot(
  WidgetTester t, {
  Size size = const Size(400, 900),
  bool web = false,
  double textScale = 1,
  Future<void> Function(OpeningController, String)? seed,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final net = GatedNet(available: !web);
  final c = OpeningController(TestStore(), net);
  await t.runAsync(c.initialize);
  await c.quickSave(url, title: 'Page one');
  final id = c.library!.bookmarks.single.id;
  await seed?.call(c, id);
  await t.pumpWidget(
    SaveApp(
      controller: c,
      files: OneFile(),
      preferences: Preferences()..value = HandyPreferences(locale: 'en'),
      guide: false,
    ),
  );
  await settle(t);
  addTearDown(c.dispose);
  return (c, net, id);
}

/// Opens `/read/<id>` and waits for the page read (an isolate) to land.
Future<void> openReader(WidgetTester t, String id) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/read/$id');
  await t.pump();
  for (var i = 0; i < 40; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    final shown = find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> &&
          (k.value == 'reader-text' ||
              k.value == 'reader-fetching' ||
              k.value.startsWith('reader-problem'));
    });
    if (shown.evaluate().isNotEmpty) break;
  }
  // The online progress bar never settles; everything else does.
  if (find.byKey(const Key('reader-fetching')).evaluate().isEmpty) {
    await t.pumpAndSettle();
  }
}

String countText(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('reader-find-count'))).data ?? '';

double offsetOf(WidgetTester t) => t
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('reader-text')),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .pixels;

void main() {
  late MemorySpotStore spots;
  setUp(() {
    spots = MemorySpotStore();
    ReadingPositions.instance = ReadingPositions(spots);
  });

  group('find in text', () {
    test('ignores case and Vietnamese marks, keeps offsets', () {
      final f = TextFinder(['Hà Giang đẹp quanh năm.', 'Đi HÀ GIANG sớm.']);
      final m = f.search('ha giang');
      expect(m, [const TextMatch(0, 0, 8), const TextMatch(1, 3, 11)]);
      expect(f.search('dep'), [const TextMatch(0, 9, 12)]);
      expect(f.search('   '), isEmpty);
      expect(foldForFind('Ơ ĐÂY').length, 'Ơ ĐÂY'.length);
    });

    test('stops at the limit', () {
      final f = TextFinder(['a' * 50]);
      expect(f.search('a', limit: 10), hasLength(10));
    });
  });

  group('reading positions', () {
    test(
      'a changed text forgets the spot; only recent items are kept',
      () async {
        final p = ReadingPositions(spots);
        await p.remember('x', 'v1', const ReaderSpot(4, .5));
        expect((await p.spot('x', 'v1'))?.block, 4);
        expect(await p.spot('x', 'v2'), isNull);
        // A fresh instance reads what was written (as after a restart).
        final again = ReadingPositions(spots);
        expect((await again.spot('x', 'v1'))?.into, .5);
        await again.remember('x', 'v1', const ReaderSpot(0, 0));
        expect(await again.spot('x', 'v1'), isNull);
        for (var i = 0; i < ReadingPositions.keep + 5; i++) {
          await again.remember('i$i', 'v', ReaderSpot(i + 1, 0));
        }
        final last = ReadingPositions(spots);
        expect(await last.spot('i0', 'v'), isNull);
        expect(
          (await last.spot('i${ReadingPositions.keep + 4}', 'v'))?.block,
          ReadingPositions.keep + 5,
        );
      },
    );

    test('damaged or unavailable storage reads as no spot', () async {
      spots.text = '{not json';
      expect(await ReadingPositions(spots).spot('x', 'v'), isNull);
      expect(await ReadingPositions(DeviceSpotStore()).spot('x', 'v'), isNull);
    });

    test('the version follows the words, not the save time', () {
      final a = copyOf(article);
      final b = extractReadingCopy(
        article,
        url: url,
        savedAt: '2026-11-05T08:00:00Z',
      )!;
      expect(copyVersion(a), copyVersion(b));
      expect(copyVersion(a), isNot(copyVersion(copyOf(longArticle(3)))));
    });
  });

  testWidgets('reading online: the page is read on open, marked not saved, '
      'and Save offline keeps it without fetching again', (t) async {
    final (c, net, id) = await boot(t);
    net.pages[url] = PageResult(html: article, uri: Uri.parse(url));
    expect(net.asked, isEmpty);
    await openReader(t, id);
    expect(net.asked, [url]);
    expect(find.text('Pho at home'), findsOneWidget);
    expect(find.textContaining('Toast the spices'), findsOneWidget);
    expect(find.byKey(const Key('reader-status-online')), findsOneWidget);
    expect(find.textContaining('not saved on this device'), findsOneWidget);
    expect(c.readingIds, isEmpty);

    await t.tap(find.byKey(const Key('reader-save-offline')));
    await settle(t);
    expect(c.readingIds.keys, [id]);
    expect(net.asked, [url]);
    expect(find.text('Saved for offline reading.'), findsOneWidget);
    expect(find.byKey(const Key('reader-status-saved')), findsOneWidget);
    expect(find.byKey(const Key('reader-save-offline')), findsNothing);
    expect((await c.readingCopy(id))!.blocks.first.text, startsWith('Toast'));
    expect(t.takeException(), isNull);
  });

  testWidgets('a saved copy opens without touching the network', (t) async {
    final (_, net, id) = await boot(
      t,
      seed: (c, id) => c.putReadingCopies({id: copyOf(article)}),
    );
    await openReader(t, id);
    expect(net.asked, isEmpty);
    expect(find.byKey(const Key('reader-status-saved')), findsOneWidget);
    expect(find.textContaining('Offline copy'), findsWidgets);
  });

  testWidgets('a failed read says why and offers the original and Try again', (
    t,
  ) async {
    final (c, net, id) = await boot(t);
    await openReader(t, id);
    expect(find.text('Couldn’t read this page'), findsOneWidget);
    expect(
      find.text('The site answered with an error instead of the page.'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('reader-open-original')));
    await settle(t);
    expect(c.opened, [url]);
    net.pages[url] = PageResult(html: article, uri: Uri.parse(url));
    await t.tap(find.byKey(const Key('reader-retry')));
    for (var i = 0; i < 20; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(find.text('Pho at home'), findsOneWidget);
    expect(c.readingIds, isEmpty);
  });

  testWidgets('Cancel stops the read at once and a late answer is dropped', (
    t,
  ) async {
    final (_, net, id) = await boot(t);
    net.pages[url] = PageResult(html: article, uri: Uri.parse(url));
    net.pageGate = Completer<void>();
    await openReader(t, id);
    // Let the page finish sliding in (the progress bar never settles).
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('reader-fetching')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('reader-fetching')),
        matching: find.text('a.com'),
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('reader-cancel')));
    await t.pump();
    expect(find.text('Stopped'), findsOneWidget);
    net.pageGate!.complete();
    await settle(t, 200);
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.text('Pho at home'), findsNothing);
  });

  testWidgets('in the browser nothing is fetched and the reader says so', (
    t,
  ) async {
    final (c, net, id) = await boot(t, web: true);
    await openReader(t, id);
    expect(net.asked, isEmpty);
    expect(
      find.text('Reading online isn’t available in the browser'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('reader-open-original')));
    await settle(t);
    expect(c.opened, [url]);
  });

  testWidgets('a picture is never read', (t) async {
    final (_, net, id) = await boot(
      t,
      seed: (c, id) => c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              b.copyWith(
                kind: 'image',
                media: MediaRef(
                  id: 'a' * 64,
                  mime: 'image/png',
                  width: 10,
                  height: 10,
                  bytes: 100,
                ),
              ),
          ],
        ),
      ),
    );
    await openReader(t, id);
    expect(net.asked, isEmpty);
    expect(find.text('Pictures have no text to read.'), findsOneWidget);
    expect(find.byKey(const Key('reader-find')), findsOneWidget);
    expect(
      t.widget<IconButton>(find.byKey(const Key('reader-find'))).onPressed,
      isNull,
    );
  });

  testWidgets('find: count, next and previous by keyboard, Esc closes', (
    t,
  ) async {
    final (_, _, id) = await boot(
      t,
      seed: (c, id) => c.putReadingCopies({id: copyOf(longArticle(30))}),
    );
    await openReader(t, id);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('reader-find-field')), findsOneWidget);
    await t.enterText(find.byKey(const Key('reader-find-field')), 'BROTH');
    await t.pumpAndSettle();
    expect(countText(t), '1 of 30');
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(countText(t), '2 of 30');
    await t.tap(find.byKey(const Key('reader-find-next')));
    await t.pumpAndSettle();
    expect(countText(t), '3 of 30');
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pumpAndSettle();
    expect(countText(t), '2 of 30');
    await t.tap(find.byKey(const Key('reader-find-prev')));
    await t.tap(find.byKey(const Key('reader-find-prev')));
    await t.pumpAndSettle();
    expect(countText(t), '30 of 30');
    // The last match is far down: it was brought into view.
    expect(offsetOf(t), greaterThan(1000));
    expect(find.textContaining('Paragraph 29.'), findsOneWidget);
    await t.enterText(find.byKey(const Key('reader-find-field')), 'zzz');
    await t.pumpAndSettle();
    expect(countText(t), 'No matches');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('reader-find-field')), findsNothing);
    expect(find.byKey(const Key('reader-text')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('find fits a 320 px screen at 200% text', (t) async {
    final (_, _, id) = await boot(
      t,
      size: const Size(320, 700),
      textScale: 2,
      seed: (c, id) => c.putReadingCopies({id: copyOf(longArticle(8))}),
    );
    await openReader(t, id);
    await t.tap(find.byKey(const Key('reader-find')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('reader-find-field')), 'broth');
    await t.pumpAndSettle();
    expect(countText(t), '1 of 8');
    await t.tap(find.byKey(const Key('reader-find-next')));
    await t.pumpAndSettle();
    expect(countText(t), '2 of 8');
    expect(t.takeException(), isNull);
  });

  testWidgets('the reading spot comes back on reopening, for this text only', (
    t,
  ) async {
    final (c, _, id) = await boot(
      t,
      seed: (c, id) => c.putReadingCopies({id: copyOf(longArticle(60))}),
    );
    await openReader(t, id);
    await t.drag(find.byKey(const Key('reader-text')), const Offset(0, -2500));
    await t.pumpAndSettle();
    final before = offsetOf(t);
    expect(before, greaterThan(1500));

    // The spot is written a moment after scrolling stops.
    await t.pump(const Duration(seconds: 1));
    final version = copyVersion((await c.readingCopy(id))!);
    final spot = await ReadingPositions(spots).spot(id, version);
    expect(spot, isNotNull);
    expect(spot!.block, greaterThan(5));
    Navigator.of(t.element(find.byKey(const Key('reader-text')))).pop();
    await t.pumpAndSettle();

    // A fresh store over the same text, as after a restart.
    ReadingPositions.instance = ReadingPositions(spots);
    await openReader(t, id);
    expect((offsetOf(t) - before).abs(), lessThan(40));
    expect(find.textContaining('Paragraph ${spot.block}.'), findsOneWidget);
  });

  testWidgets('a spot saved for another version of the text is ignored', (
    t,
  ) async {
    final (_, _, id) = await boot(
      t,
      seed: (c, id) async {
        await c.putReadingCopies({id: copyOf(longArticle(60))});
        await ReadingPositions(
          spots,
        ).remember(id, 'an-old-version', const ReaderSpot(40, .2));
      },
    );
    ReadingPositions.instance = ReadingPositions(spots);
    await openReader(t, id);
    expect(offsetOf(t), 0);
    expect(find.text('Long broth'), findsOneWidget);
  });
}
