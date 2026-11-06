// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/welcome_test.dart' show StillMotion;
import 'package:handy_files/handy_files.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark/links/batch_size.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import '../test/controller_test.dart' show TestStore;
import '../test/link_tasks_test.dart' show FakeNet;
import '../test/new_flows_test.dart' show NetController, OneFile;
import '../test/reader_test.dart' show GatedNet;
import 'package:handy_bookmark/reader/reading_position.dart';
import 'package:handy_bookmark/services/metadata_client.dart';
import '../test/widget_test.dart' show Preferences;

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

final _root = GlobalKey();

Future<void> shot(WidgetTester t, String name, {bool settle = true}) async {
  final dir = Platform.environment['SHOTS_DIR'] ?? 'build/shots';
  Directory(dir).createSync(recursive: true);
  if (settle) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pump();
  }
  await t.runAsync(() async {
    final b =
        _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> film(
  WidgetTester t,
  String name,
  Future<void> Function() action, {
  int frames = 16,
}) async {
  await action();
  for (var i = 0; i < frames; i++) {
    await shot(t, '$name-film-${i.toString().padLeft(3, '0')}', settle: false);
    await t.pump(const Duration(milliseconds: 25));
  }
  await t.pumpAndSettle();
}

/// A store that keeps pictures, so the shots show the links' faces.
class PictureStore extends TestStore {
  final pictures = <String, Uint8List>{};
  @override
  Future<void> putThumbnail(String id, Uint8List bytes) async =>
      pictures[id] = bytes;
  @override
  Future<Uint8List?> thumbnail(String id) async => pictures[id];
}

/// A flat drawn picture in two colours, standing in for a page's image.
Future<Uint8List> picture(int a, int b) async {
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  c.drawRect(const Rect.fromLTWH(0, 0, 320, 200), Paint()..color = Color(a));
  c.drawCircle(const Offset(230, 70), 60, Paint()..color = Color(b));
  c.drawRect(
    const Rect.fromLTWH(0, 140, 320, 60),
    Paint()..color = Color(b).withValues(alpha: .6),
  );
  final img = await r.endRecording().toImage(320, 200);
  return (await img.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
}

const _links = [
  (
    'https://www.youtube.com/watch?v=bunbo1',
    'Cách nấu bún bò Huế chuẩn vị',
    'food',
    0xFFE9D8B4,
    0xFFB5472B,
  ),
  (
    'https://www.tiktok.com/@chef/video/7301',
    'Mẹo nướng bánh mì giòn bằng nồi chiên',
    'food',
    0xFFF1E3C8,
    0xFF8C5A2B,
  ),
  (
    'https://shopee.vn/product/1201/5531',
    'Nồi chiên không dầu 6L',
    'buy',
    0xFFDDE7EE,
    0xFF34617A,
  ),
  (
    'https://www.facebook.com/groups/dulich/posts/88',
    'Lịch trình 3 ngày Đà Nẵng – Hội An',
    'trip',
    0xFFCFE6E3,
    0xFF2F7F86,
  ),
  (
    'https://maps.google.com/?cid=1234',
    'Bánh xèo Bà Dưỡng',
    'trip',
    0xFFE7E1D3,
    0xFF6E6A3B,
  ),
  (
    'https://vnexpress.net/du-lich/mua-dep-nhat-ha-giang',
    'Mùa đẹp nhất để đi Hà Giang',
    'read',
    0xFFE3E6D8,
    0xFF5D7A3A,
  ),
  ('https://github.com/flutter/flutter', 'flutter/flutter', 'read', 0, 0),
  (
    'https://www.youtube.com/watch?v=yoga20',
    'Yoga 20 phút buổi sáng',
    null,
    0xFFE6DDEB,
    0xFF6B5A7A,
  ),
  (
    'https://www.tiktok.com/@decor/video/9921',
    'Trang trí ban công nhỏ',
    null,
    0xFFDDEBD9,
    0xFF3F7A4A,
  ),
  ('https://shopee.vn/product/88/17', 'Kệ sách gỗ 5 tầng', null, 0, 0),
  (
    'https://www.instagram.com/p/Cx1',
    'Quán cà phê view hồ Tây',
    null,
    0xFFE9E2D2,
    0xFF7A6447,
  ),
];

const _photos = {
  0: 'pho',
  1: 'bun-cha',
  3: 'hoi-an',
  5: 'ga-ha-noi',
  7: 'guitars',
};

Future<NetController> boot(
  WidgetTester t,
  Size size, {
  String theme = 'light',
  bool empty = false,
  FakeNet? net,
  OneFile? files,
  bool extras = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final store = PictureStore();
  final c = NetController(store, net ?? FakeNet());
  await t.runAsync(c.initialize);
  if (!empty) {
    for (final l in _links) {
      await c.quickSave(l.$1, title: l.$2);
    }
    await c.update(
      (l) => l.copyWith(
        collections: [
          SaveCollection(id: 'food', name: 'Công thức nấu ăn', position: 0),
          SaveCollection(id: 'trip', name: 'Du lịch', position: 1),
          SaveCollection(
            id: 'dn',
            name: 'Đà Nẵng',
            parentId: 'trip',
            position: 0,
          ),
          SaveCollection(id: 'buy', name: 'Cần mua', position: 2),
          SaveCollection(id: 'read', name: 'Đọc sau', position: 3),
        ],
        tags: ['món-huế', 'cuối-tuần'],
        bookmarks: [
          for (final (i, b) in l.bookmarks.indexed)
            b.copyWith(
              collectionId: _links[i].$3,
              tags: i == 0 ? ['món-huế'] : (i == 3 ? ['cuối-tuần'] : null),
              isFavorite: i == 0 || i == 4,
              isRead: i == 2 || i == 6,
              savedAt: DateTime.now()
                  .subtract(Duration(hours: i * 7 + 1))
                  .toUtc()
                  .toIso8601String(),
            ),
        ],
      ),
    );
    final ids = c.library!.bookmarks.map((b) => b.id).toList();
    if (extras) await _extras(c, ids);
    await t.runAsync(() async {
      // Fixture pictures: the guide's licensed photos (see
      // assets/welcome/CREDITS.txt) on some saves, none on the rest, so the
      // shots show both real thumbnails and the no-picture face.
      for (final (i, _) in _links.indexed) {
        final photo = _photos[i];
        if (photo != null) {
          store.pictures[ids[i]] = File(
            'assets/welcome/$photo.jpg',
          ).readAsBytesSync();
        }
      }
    });
  }
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: SaveApp(
        controller: c,
        files: files ?? OneFile(),
        preferences: Preferences()
          ..value = HandyPreferences(locale: 'vi', theme: theme),
        guide: false,
      ),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await t.pumpAndSettle();
  addTearDown(c.dispose);
  return c;
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty)
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await t.pumpAndSettle();
}

const _checked = '2026-11-02T08:00:00Z';

/// Checks, a saved search and an offline copy, as after a week of use.
Future<void> _extras(NetController c, List<String> ids) async {
  await c.update(
    (l) => l.copyWith(
      savedSearches: [
        SavedSearch(
          id: 'trip-food',
          name: 'Đà Nẵng ăn gì',
          query: {'text': 'bánh', 'place': 'all'},
        ),
        SavedSearch(
          id: 'videos',
          name: 'Video chưa xem',
          query: {'place': 'unread', 'contentType': 'video'},
        ),
      ],
      bookmarks: [
        for (final (i, b) in l.bookmarks.indexed)
          switch (i) {
            1 => b.copyWith(
              linkCheck: LinkCheck(
                status: 'gone',
                checkedAt: _checked,
                httpStatus: 404,
              ),
            ),
            5 => b.copyWith(
              linkCheck: LinkCheck(
                status: 'moved',
                checkedAt: _checked,
                httpStatus: 200,
                movedTo:
                    'https://vnexpress.net/ha-giang-mua-nao-dep-nhat-4812345.html',
              ),
            ),
            9 => b.copyWith(
              linkCheck: LinkCheck(
                status: 'unreachable',
                checkedAt: _checked,
                httpStatus: 403,
                reason: 'http',
              ),
            ),
            _ => b.copyWith(
              linkCheck: LinkCheck(
                status: 'ok',
                checkedAt: _checked,
                httpStatus: 200,
              ),
            ),
          },
      ],
    ),
  );
  await c.putReadingCopies({
    ids[5]: ReadingCopy(
      url: 'https://vnexpress.net/du-lich/mua-dep-nhat-ha-giang',
      title: 'Mùa đẹp nhất để đi Hà Giang',
      byline: 'Minh Anh',
      siteName: 'VnExpress',
      savedAt: '2026-10-28T07:30:00Z',
      blocks: [
        ReadingBlock(
          'p',
          'Hà Giang đẹp quanh năm, nhưng mỗi mùa mang một gương mặt khác. Nếu chỉ có một chuyến, hãy chọn theo thứ bạn muốn thấy: hoa, lúa chín hay sương sớm trên đèo.',
        ),
        ReadingBlock('h', 'Tháng 10 đến tháng 11: mùa hoa tam giác mạch'),
        ReadingBlock(
          'p',
          'Hoa nở rộ ở Đồng Văn, Mèo Vạc và Sủng Là. Trời hanh, nắng nhẹ, đêm lạnh khoảng 12 đến 15 độ. Đây là lúc đông khách nhất, nên đặt phòng trước ít nhất hai tuần.',
        ),
        ReadingBlock('li', 'Đèo Mã Pì Lèng: đi sớm trước 7 giờ để tránh mây.'),
        ReadingBlock('li', 'Phố cổ Đồng Văn: chợ phiên họp sáng Chủ nhật.'),
        ReadingBlock(
          'quote',
          'Đi chậm thôi, vì mỗi khúc cua là một bức tranh khác.',
        ),
        ReadingBlock('h', 'Tháng 4 đến tháng 5: mùa nước đổ'),
        ReadingBlock(
          'p',
          'Ruộng bậc thang ở Hoàng Su Phì được đổ nước, phản chiếu trời như những tấm gương. Đường đẹp nhưng trơn sau mưa; thuê xe số và người dẫn đường địa phương.',
        ),
      ],
    ),
  });
}

void main() {
  setUpAll(() async {
    const ui = '../../packages/handy_ui/fonts';
    await _font('packages/handy_ui/Geist', [
      '$ui/Geist-Regular.ttf',
      '$ui/Geist-Medium.ttf',
      '$ui/Geist-Bold.ttf',
    ]);
    await _font('packages/handy_ui/GeistMono', ['$ui/GeistMono-Regular.ttf']);
    await _font('packages/handy_ui/Bricolage', [
      '$ui/BricolageGrotesque-Medium.ttf',
      '$ui/BricolageGrotesque-Display.ttf',
    ]);
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    await _font('Newsreader', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    await _font('MaterialIcons', [
      '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(900, 1100)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label home', (t) async {
      final c = await boot(t, size);
      if (size.width >= 1100) {
        await tapKey(t, 'details-${c.library!.bookmarks.first.id}');
        await tapKey(t, 'item-details');
      }
      await shot(t, '$label-1-home');
    });
  }
  testWidgets('phone collection', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'collection-food');
    await shot(t, 'phone-2-collection');
    await tapKey(t, 'save-view');
    await shot(t, 'phone-3-cards');
  });
  testWidgets('phone detail', (t) async {
    final c = await boot(t, const Size(390, 844));
    Navigator.of(
      t.element(find.byKey(const Key('save-home'))),
    ).pushNamed('/bookmark/${c.library!.bookmarks.first.id}');
    await t.pumpAndSettle();
    await shot(t, 'phone-4-detail');
  });
  testWidgets('phone select', (t) async {
    final c = await boot(t, const Size(390, 844));
    await tapKey(t, 'collection-trip');
    await t.longPress(
      find.byKey(ValueKey('bookmark-${c.library!.bookmarks[3].id}')),
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-5-select');
  });
  testWidgets('phone trash', (t) async {
    final c = await boot(t, const Size(390, 844));
    final ids = [for (final b in c.library!.bookmarks.take(4)) b.id];
    final now = DateTime.now().toUtc();
    // Deleted at different times, so the days left differ.
    for (final (i, id) in ids.indexed) {
      await c.update(
        (l) => moveToTrash(l, [
          id,
        ], now.subtract(Duration(days: [1, 8, 22, 29][i])).toIso8601String()),
      );
    }
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/trash');
    await t.pumpAndSettle();
    await shot(t, 'phone-20-trash');
  });
  testWidgets('phone duplicates', (t) async {
    final c = await boot(t, const Size(390, 844));
    // Saved again from a chat link, and again from another app.
    for (final (url, title) in [
      (
        'https://vnexpress.net/du-lich/mua-dep-nhat-ha-giang?utm_source=zalo',
        'Mùa đẹp nhất để đi Hà Giang',
      ),
      ('https://github.com/flutter/flutter?utm_medium=share', ''),
    ]) {
      await c.quickSave(url, title: title, allowDuplicates: true);
    }
    await t.pumpAndSettle();
    Navigator.of(
      t.element(find.byType(Scaffold).first),
    ).pushNamed('/duplicates');
    await t.pumpAndSettle();
    await shot(t, 'phone-19-duplicates');
  });
  testWidgets('phone focus', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'place-focus');
    await shot(t, 'phone-6-focus');
  });
  testWidgets('phone add', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'save-new');
    await tapKey(t, 'save-add');
    await t.enterText(
      find.byKey(const Key('save-text-input')),
      'https://www.youtube.com/watch?v=caphe',
    );
    await t.pump();
    await shot(t, 'phone-7-add');
  });
  testWidgets('desktop settings', (t) async {
    await boot(t, const Size(1440, 900));
    await tapKey(t, 'open-settings');
    await shot(t, 'desktop-8-settings');
  });
  testWidgets('phone dark', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await shot(t, 'phone-9-dark');
  });
  testWidgets('phone empty', (t) async {
    await boot(t, const Size(390, 844), empty: true);
    await shot(t, 'phone-10-empty');
  });
  // The first-run guide, step by step, on a phone, narrow and wide. Motion
  // is reduced so each shot is a step's resting frame.
  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('narrow', const Size(320, 640)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('$label welcome', (t) async {
      t.platformDispatcher.accessibilityFeaturesTestValue = StillMotion();
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await boot(t, size, empty: true);
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).pushNamed('/welcome');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pumpAndSettle();
      await shot(t, '$label-21-welcome-1');
      await tapKey(t, 'welcome-next-0');
      await shot(t, '$label-21-welcome-2');
      await tapKey(t, 'welcome-next-1');
      await shot(t, '$label-21-welcome-3-video');
      await tapKey(t, 'practice-share');
      await shot(t, '$label-21-welcome-4-apps');
      await tapKey(t, 'practice-more');
      await shot(t, '$label-21-welcome-5-share');
      await tapKey(t, 'practice-direct');
      await shot(t, '$label-21-welcome-6-saved');
      await tapKey(t, 'welcome-next-2');
      await shot(t, '$label-21-welcome-7-find');
      // The find stage's button finishes the guide (no nudge stage).
      await tapKey(t, 'welcome-next-3');
    });
  }
  testWidgets('films', (t) async {
    final c = await boot(t, const Size(390, 844));
    final first =
        c.library!.bookmarks.where((b) => b.collectionId == null).toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    await film(t, 'phone-file', () async {
      await t.tap(find.byKey(Key('file-${first.first.id}')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key('file-${first.first.id}-food')));
      await t.pump();
    }, frames: 20);
  });
  testWidgets('phone reader', (t) async {
    final c = await boot(t, const Size(390, 844), extras: true);
    final id = c.library!.bookmarks[5].id;
    Navigator.of(
      t.element(find.byKey(const Key('save-home'))),
    ).pushNamed('/read/$id');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-11-reader');
    await c.update((l) => l, prefs: {...c.preferences, 'readerTone': 'dark'});
    await t.pumpAndSettle();
    await shot(t, 'phone-12-reader-dark');
  });
  testWidgets('phone reader highlights', (t) async {
    final c = await boot(t, const Size(390, 844), extras: true);
    final id = c.library!.bookmarks[5].id;
    final copy = (await t.runAsync(() => c.readingCopy(id)))!;
    final blocks = [for (final b in copy.blocks) b.text];
    var made = 0;
    final marks = [
      for (final (i, color, note) in [
        (1, 'yellow', ''),
        (3, 'green', 'Thử cách này cuối tuần'),
      ])
        if (i < blocks.length && blocks[i].length > 30)
          Highlight(
            id: 'h${made++}',
            block: i,
            start: 0,
            end: blocks[i].length.clamp(0, 70),
            quote: blocks[i].substring(0, blocks[i].length.clamp(0, 70)),
            color: color,
            note: note,
            createdAt: '2026-11-06T10:00:00Z',
          ).toJson(),
    ];
    await c.update(
      (l) => l,
      prefs: {
        ...c.preferences,
        'highlights': {id: marks},
      },
    );
    Navigator.of(
      t.element(find.byKey(const Key('save-home'))),
    ).pushNamed('/read/$id');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-33-reader-highlights');
    await tapKey(t, 'reader-highlights');
    await shot(t, 'phone-33-highlights-list');
    await tapKey(t, 'highlight-h1-edit');
    await shot(t, 'phone-33-highlight-edit');
  });
  testWidgets('desktop reader', (t) async {
    final c = await boot(t, const Size(1440, 900), extras: true);
    Navigator.of(
      t.element(find.byType(Scaffold).first),
    ).pushNamed('/read/${c.library!.bookmarks[5].id}');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    await shot(t, 'desktop-13-reader');
  });
  testWidgets('phone detail links', (t) async {
    final c = await boot(t, const Size(390, 844), extras: true);
    Navigator.of(
      t.element(find.byKey(const Key('save-home'))),
    ).pushNamed('/bookmark/${c.library!.bookmarks[5].id}');
    await t.pumpAndSettle();
    await tapKey(t, 'detail-tools');
    await t.scrollUntilVisible(
      find.byKey(const Key('detail-check')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-14-detail-links');
  });
  testWidgets('phone places with saved searches', (t) async {
    await boot(t, const Size(390, 844), extras: true);
    // Since 2026-11-06 the kept lists wait in Library > Advanced.
    await tapKey(t, 'home-library');
    await tapKey(t, 'library-advanced');
    await t.scrollUntilVisible(
      find.byKey(const Key('search-videos')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-15-places');
  });
  testWidgets('desktop broken links', (t) async {
    final net = FakeNet();
    final c = await boot(t, const Size(1440, 900), extras: true, net: net);
    final urls = c.library!.bookmarks.map((b) => b.originalUrl).toList();
    net.probes[urls[1]] = [const LinkProbe(status: 404)];
    net.probes[urls[3]] = [const LinkProbe(status: 410)];
    net.probes[urls[5]] = [
      const LinkProbe(
        status: 200,
        permanentUrl:
            'https://vnexpress.net/ha-giang-mua-nao-dep-nhat-4812345.html',
      ),
    ];
    net.probes[urls[9]] = [const LinkProbe(status: 403)];
    await tapKey(t, 'list-more');
    await tapKey(t, 'check-here');
    // Same-host links wait about 2 s apart.
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 7)));
    await t.pumpAndSettle();
    await tapKey(t, 'task-broken');
    await tapKey(t, 'details-${c.library!.bookmarks[5].id}');
    await tapKey(t, 'item-details');
    await shot(t, 'desktop-16-broken');
  });
  testWidgets('phone check running', (t) async {
    final net = FakeNet()..gate = Completer<void>();
    final c = await boot(t, const Size(390, 844), extras: true, net: net);
    await tapKey(t, 'home-library');
    await tapKey(t, 'place-all');
    await t.longPress(
      find.byKey(ValueKey('bookmark-${c.library!.bookmarks[3].id}')),
    );
    await t.pumpAndSettle();
    await tapKey(t, 'batch-more');
    await tapKey(t, 'batch-all');
    await tapKey(t, 'batch-more');
    await tapKey(t, 'batch-check');
    for (var i = 0; i < 4; i++) {
      final g = net.gate!;
      net.gate = Completer<void>();
      g.complete();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 400));
    await shot(t, 'phone-17-checking', settle: false);
    net.gate!.complete();
    await t.tap(find.byKey(const Key('task-stop')));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await t.pumpAndSettle();
  });
  testWidgets('phone pocket preview', (t) async {
    final files = OneFile()
      ..next = ImportedBytes(
        'part_000000.csv',
        File(
          '../../packages/handy_bookmark_engine/test/fixtures/part_000000.csv',
        ).readAsBytesSync(),
      );
    await boot(t, const Size(390, 844), files: files);
    Navigator.of(
      t.element(find.byKey(const Key('save-home'))),
    ).pushNamed('/settings');
    await t.pumpAndSettle();
    await tapKey(t, 'set-advanced-data');
    await tapKey(t, 'save-import-pocket');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-19-pocket');
  });
  testWidgets('desktop film', (t) async {
    final c = await boot(t, const Size(1440, 900));
    await tapKey(t, 'details-${c.library!.bookmarks[0].id}');
    await tapKey(t, 'item-details');
    await tapKey(t, 'details-${c.library!.bookmarks[5].id}');
    await film(t, 'desktop-pick', () async {
      await t.tap(find.byKey(const Key('item-details')).last);
      await t.pump();
    });
  });
  testWidgets('phone bounded batch review', (t) async {
    await boot(t, const Size(390, 844));
    final pending = chooseLinkBatch(
      t.element(find.byType(Scaffold).first),
      count: 80,
      maximum: 200,
      reading: true,
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-batch-review');
    await tapKey(t, 'link-batch-cancel');
    expect(await pending, isNull);
  });
  // Save, Trash and Settings (Warm Modern Library, 2026-11-06).
  Future<void> scrolled(WidgetTester t, String name, int pages) async {
    await shot(t, '$name-0');
    for (var i = 1; i <= pages; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -640));
      await t.pumpAndSettle();
      await shot(t, '$name-$i');
    }
  }

  for (final theme in ['light', 'dark']) {
    testWidgets('phone settings $theme', (t) async {
      await boot(t, const Size(390, 844), theme: theme);
      Navigator.of(
        t.element(find.byKey(const Key('save-home'))),
      ).pushNamed('/settings');
      await t.pumpAndSettle();
      await scrolled(t, 'phone-30-settings-$theme', 6);
    });
  }
  testWidgets('small save sheet', (t) async {
    await boot(t, const Size(320, 640));
    await tapKey(t, 'save-new');
    await shot(t, 'small-31-save');
    await t.tapAt(const Offset(160, 40));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('bookmark-inline-url')), 'cà phê');
    await t.pump();
    await shot(t, 'small-31-save-typed');
    await tapKey(t, 'bookmark-inline-save');
    await shot(t, 'small-31-save-error');
  });
  testWidgets('phone quick save done', (t) async {
    await boot(t, const Size(390, 844));
    await t.enterText(
      find.byKey(const Key('bookmark-inline-url')),
      'https://www.foody.vn/ha-noi/bun-cha-huong-lien',
    );
    await t.pump();
    await tapKey(t, 'bookmark-inline-save');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump(const Duration(milliseconds: 400));
    await shot(t, 'phone-32-quick-saved', settle: false);
  });
  testWidgets('phone save sheet dark', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await tapKey(t, 'save-new');
    await shot(t, 'phone-31-save-dark');
  });
  testWidgets('phone trash dark', (t) async {
    final c = await boot(t, const Size(390, 844), theme: 'dark');
    final now = DateTime.now().toUtc();
    for (final (i, b) in c.library!.bookmarks.take(3).indexed) {
      await c.update(
        (l) => moveToTrash(l, [
          b.id,
        ], now.subtract(Duration(days: [2, 15, 29][i])).toIso8601String()),
      );
    }
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/trash');
    await t.pumpAndSettle();
    await shot(t, 'phone-32-trash-dark');
  });
  testWidgets('phone trash empty', (t) async {
    await boot(t, const Size(390, 844));
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/trash');
    await t.pumpAndSettle();
    await shot(t, 'phone-33-trash-empty');
  });
  testWidgets('phone share collection', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'collection-food');
    await tapKey(t, 'list-more');
    await tapKey(t, 'collection-share');
    await shot(t, 'phone-34-share');
  });
  testWidgets('phone filter sheet', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'collection-food');
    await tapKey(t, 'save-filters');
    await shot(t, 'phone-35-filters');
  });
  // Detail, picture and Focus in both themes (Warm Modern Library).
  Future<String> addPicture(WidgetTester t, NetController c) async {
    final bytes = File('assets/welcome/pho.jpg').readAsBytesSync();
    unawaited(
      c.addPictures([
        (bytes: bytes, name: 'Phở Thìn Lò Đúc.jpg'),
      ], collectionId: 'food'),
    );
    for (
      var i = 0;
      i < 50 && !c.library!.bookmarks.any((b) => b.isImage);
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
    }
    await t.pumpAndSettle();
    return c.library!.bookmarks.firstWhere((b) => b.isImage).id;
  }

  Future<void> openItem(WidgetTester t, String id) async {
    Navigator.of(
      t.element(find.byKey(const Key('save-home'))),
    ).pushNamed('/bookmark/$id');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await t.pumpAndSettle();
  }

  testWidgets('phone detail dark', (t) async {
    final c = await boot(t, const Size(390, 844), theme: 'dark');
    await openItem(t, c.library!.bookmarks.first.id);
    await shot(t, 'phone-40-detail-dark');
  });
  for (final theme in ['light', 'dark']) {
    testWidgets('phone picture detail $theme', (t) async {
      final c = await boot(t, const Size(390, 844), theme: theme);
      await openItem(t, await addPicture(t, c));
      await shot(t, 'phone-41-picture-detail-$theme');
      await tapKey(t, 'detail-view-picture');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pumpAndSettle();
      await shot(t, 'phone-42-picture-view-$theme');
    });
  }
  testWidgets('phone focus dark', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await tapKey(t, 'place-focus');
    await shot(t, 'phone-43-focus-dark');
  });

  // Reader: reading online, the find bar.
  Future<void> openRead(WidgetTester t, String id) async {
    ReadingPositions.instance = ReadingPositions(MemorySpotStore());
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/read/$id');
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('phone reader online', (t) async {
    final net = GatedNet()..pageGate = Completer<void>();
    final c = await boot(t, const Size(390, 844), extras: true, net: net);
    final b = c.library!.bookmarks[3];
    net.pages[b.originalUrl] = PageResult(
      html: _tripArticle,
      uri: Uri.parse(b.originalUrl),
    );
    await openRead(t, b.id);
    await t.pump(const Duration(milliseconds: 600));
    await shot(t, 'phone-50-reader-online-loading', settle: false);
    net.pageGate!.complete();
    for (var i = 0; i < 20; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    await t.pumpAndSettle();
    await shot(t, 'phone-51-reader-online');
  });
  testWidgets('phone reader failed', (t) async {
    final c = await boot(t, const Size(390, 844), extras: true);
    await openRead(t, c.library!.bookmarks[3].id);
    await t.pumpAndSettle();
    await shot(t, 'phone-52-reader-failed');
  });
  testWidgets('phone reader find', (t) async {
    final c = await boot(t, const Size(390, 844), extras: true);
    await openRead(t, c.library!.bookmarks[5].id);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('reader-find')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('reader-find-field')), 'đèo');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('reader-find-next')));
    await t.pumpAndSettle();
    await shot(t, 'phone-53-reader-find');
  });
  testWidgets('small reader find dark 200%', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final c = await boot(t, const Size(320, 640), theme: 'dark', extras: true);
    await openRead(t, c.library!.bookmarks[5].id);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('reader-find')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('reader-find-field')), 'hà giang');
    await t.pumpAndSettle();
    await shot(t, 'small-54-reader-find-dark-200');
  });

  // Settings, Reminders: items that still carry a reminder (2026-11-06):
  // one past, two coming.
  for (final theme in ['light', 'dark']) {
    testWidgets('phone existing reminders $theme', (t) async {
      final c = await boot(t, const Size(390, 844), theme: theme);
      final now = DateTime.now().toUtc();
      final due = {
        0: now.add(const Duration(days: 2, hours: 3)),
        3: now.subtract(const Duration(days: 1)),
        5: now.add(const Duration(days: 9)),
      };
      await c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final (i, b) in l.bookmarks.indexed)
              due[i] == null
                  ? b
                  : b.copyWith(reminderAt: due[i]!.toIso8601String()),
          ],
        ),
      );
      await t.pumpAndSettle();
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).pushNamed('/settings');
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('reminders-cancel-all')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.drag(find.byType(Scrollable).first, const Offset(0, 420));
      await t.pumpAndSettle();
      await shot(t, 'phone-44-reminders-$theme');
    });
  }
  // Focus with no pictures at all: the typographic poster.
  Future<void> openFocus(WidgetTester t) async {
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/focus');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
  }

  for (final theme in ['light', 'dark']) {
    testWidgets('phone focus image-less $theme', (t) async {
      final c = await boot(t, const Size(390, 844), theme: theme);
      (c.store! as PictureStore).pictures.clear();
      c.clearThumbnailMemory();
      await openFocus(t);
      await shot(t, 'phone-45-focus-poster-$theme');
      await tapKey(t, 'focus-later');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pumpAndSettle();
      await shot(t, 'phone-45-focus-poster-$theme-2');
    });
  }
  testWidgets('small focus image-less large text', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final c = await boot(t, const Size(320, 640), theme: 'dark');
    (c.store! as PictureStore).pictures.clear();
    c.clearThumbnailMemory();
    await openFocus(t);
    await shot(t, 'small-45-focus-poster-large-text');
  });
  testWidgets('settings advanced views', (t) async {
    await boot(t, const Size(390, 844), extras: true);
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/settings');
    await t.pumpAndSettle();
    await tapKey(t, 'set-library-tools');
    await scrolled(t, 'phone-46-tools', 2);
    Navigator.of(t.element(find.byType(Scaffold).last)).pop();
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('set-advanced-data')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapKey(t, 'set-advanced-data');
    await shot(t, 'phone-47-advanced-data');
    Navigator.of(t.element(find.byType(Scaffold).last)).pop();
    await t.pumpAndSettle();
    await tapKey(t, 'set-storage');
    await shot(t, 'phone-48-storage');
  });
  testWidgets('small settings large text', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await boot(t, const Size(320, 640));
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/settings');
    await t.pumpAndSettle();
    await scrolled(t, 'small-49-settings-large', 4);
  });
  // Item detail, rename, the item menu and sharing (final simplification).
  Future<void> openOne(WidgetTester t, String id) async {
    Navigator.of(
      t.element(find.byType(Scaffold).first),
    ).pushNamed('/bookmark/$id');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await t.pumpAndSettle();
  }

  testWidgets('item rename phone', (t) async {
    final c = await boot(t, const Size(390, 844));
    await openOne(t, c.library!.bookmarks.first.id);
    await tapKey(t, 'detail-rename');
    await shot(t, 'phone-item-1-rename');
    await t.enterText(find.byKey(const Key('rename-field')), '');
    await t.pumpAndSettle();
    await shot(t, 'phone-item-2-rename-empty');
  });
  testWidgets('item rename small dark', (t) async {
    final c = await boot(t, const Size(320, 640), theme: 'dark');
    await openOne(t, c.library!.bookmarks[1].id);
    await tapKey(t, 'detail-rename');
    await shot(t, 'small-item-3-rename-dark');
  });
  testWidgets('item menus', (t) async {
    final c = await boot(t, const Size(390, 844));
    final food = [
      for (final b in c.library!.bookmarks)
        if (b.collectionId == 'food') b.id,
    ];
    await tapKey(t, 'collection-food');
    // Menus float: draw their real shadow, not the test stand-in.
    debugDisableShadows = false;
    await tapKey(t, 'details-${food.last}');
    await shot(t, 'phone-item-4-row-menu');
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await tapKey(t, 'save-view');
    await tapKey(t, 'details-${food.first}');
    await shot(t, 'phone-item-5-card-menu');
    debugDisableShadows = true;
  });
  testWidgets('item detail more and folds', (t) async {
    final c = await boot(t, const Size(390, 844));
    final id = c.library!.bookmarks.first.id;
    await c.update(
      (l) => l.copyWith(
        bookmarks: [
          for (final b in l.bookmarks)
            b.id == id
                ? b.copyWith(
                    note: 'Hỏi quán xin công thức nước dùng.\nĐi sớm trước 7h.',
                    isPinned: true,
                  )
                : b,
        ],
      ),
    );
    await openOne(t, id);
    await tapKey(t, 'detail-more');
    debugDisableShadows = false;
    await shot(t, 'phone-item-6-detail-more');
    debugDisableShadows = true;
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await tapKey(t, 'detail-notes');
    await tapKey(t, 'detail-tools');
    await t.scrollUntilVisible(
      find.byKey(const Key('detail-unpin')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-item-7-detail-folds');
  });
  for (final theme in ['light', 'dark']) {
    testWidgets('item share picture $theme', (t) async {
      final c = await boot(t, const Size(390, 844), theme: theme);
      // A camera photo: the guide's licensed photo with EXIF written in.
      final photo = img.decodeJpg(
        File('assets/welcome/hoi-an.jpg').readAsBytesSync(),
      )!;
      photo.exif.imageIfd['Make'] = 'TestCam';
      photo.exif.imageIfd['ImageDescription'] = 'Hoi An';
      final bytes = img.encodeJpg(photo, quality: 85);
      unawaited(
        c.addPictures([
          (bytes: bytes, name: 'Phố cổ Hội An.jpg'),
        ], collectionId: 'trip'),
      );
      for (
        var i = 0;
        i < 50 && !c.library!.bookmarks.any((b) => b.isImage);
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pump();
      }
      await openOne(t, c.library!.bookmarks.firstWhere((b) => b.isImage).id);
      await shot(t, 'phone-item-8-picture-detail-$theme');
      await tapKey(t, 'detail-share');
      await shot(t, 'phone-item-9-share-picture-$theme');
    });
  }
}

const _tripArticle =
    '<html><head><title>Lịch trình 3 ngày Đà Nẵng – Hội An</title>'
    '<meta property="og:site_name" content="Hội Du lịch bụi"></head><body>'
    '<article><h1>Lịch trình 3 ngày Đà Nẵng – Hội An</h1>'
    '<p>Ba ngày là vừa đủ để ăn, tắm biển và đi bộ phố cổ mà không vội. '
    'Lịch dưới đây đi từ Đà Nẵng, ngủ hai đêm ở thành phố và một tối ở Hội An.</p>'
    '<h2>Ngày 1: biển Mỹ Khê và bán đảo Sơn Trà</h2>'
    '<p>Sáng tắm biển trước 8 giờ khi nước còn mát. Chiều thuê xe máy lên Sơn Trà, '
    'dừng ở chùa Linh Ứng rồi xuống chợ Cồn ăn bánh xèo, nem lụi.</p>'
    '<ul><li>Thuê xe máy: khoảng 120.000 đồng một ngày.</li>'
    '<li>Đường lên Sơn Trà dốc, đi chậm và tránh trời mưa.</li></ul>'
    '<h2>Ngày 2: Bà Nà hoặc Ngũ Hành Sơn</h2>'
    '<p>Nếu thích mát, lên Bà Nà từ sớm; nếu muốn tiết kiệm, Ngũ Hành Sơn chỉ mất nửa ngày '
    'và có nhiều hang động đẹp. Tối ăn mì Quảng ở đường Hải Phòng.</p>'
    '<h2>Ngày 3: Hội An</h2>'
    '<p>Đi Hội An buổi chiều, dạo phố cổ lúc đèn lồng lên, ăn cao lầu và bánh mì. '
    'Nếu ở lại muộn, thả đèn hoa đăng trên sông Hoài.</p>'
    '</article></body></html>';
