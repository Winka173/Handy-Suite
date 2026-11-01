// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_save/app.dart';
import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../test/controller_test.dart' show TestStore;
import '../test/widget_test.dart' show OpeningController, Preferences;

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

Future<OpeningController> boot(
  WidgetTester t,
  Size size, {
  String theme = 'light',
  bool empty = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final store = PictureStore();
  final c = OpeningController(store);
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
    await t.runAsync(() async {
      for (final (i, l) in _links.indexed) {
        if (l.$4 != 0) store.pictures[ids[i]] = await picture(l.$4, l.$5);
      }
    });
  }
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: SaveApp(
        controller: c,
        preferences: Preferences()
          ..value = HandyPreferences(locale: 'vi', theme: theme),
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
      if (size.width >= 1100)
        await tapKey(t, 'details-${c.library!.bookmarks.first.id}');
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
  testWidgets('phone focus', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'place-focus');
    await shot(t, 'phone-6-focus');
  });
  testWidgets('phone add', (t) async {
    await boot(t, const Size(390, 844));
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
  testWidgets('films', (t) async {
    final c = await boot(t, const Size(390, 844));
    final first =
        c.library!.bookmarks.where((b) => b.collectionId == null).toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    await film(t, 'phone-file', () async {
      await t.tap(find.byKey(Key('file-${first.first.id}-food')));
      await t.pump();
    }, frames: 20);
  });
  testWidgets('desktop film', (t) async {
    final c = await boot(t, const Size(1440, 900));
    await tapKey(t, 'details-${c.library!.bookmarks[0].id}');
    await film(t, 'desktop-pick', () async {
      await t.tap(
        find.byKey(Key('details-${c.library!.bookmarks[5].id}')).first,
      );
      await t.pump();
    });
  });
}
