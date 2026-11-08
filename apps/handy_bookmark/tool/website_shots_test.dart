// Website kit: every feature as a marketing still, in Vietnamese and
// English, light and dark, phone (390×844 @3x), tablet and desktop
// (1440×900 @2x), plus frame sequences for short clips. Real fonts and a
// lived-in sample library (no lorem ipsum). Nothing here touches lib/.
//
// KIT_DIR=<dir> [KIT_PHOTOS=<dir of extra .jpg>] [KIT_LANGS=vi,en] \
//   flutter test --no-pub tool/website_shots_test.dart
//
// Photos: assets/welcome (CREDITS.txt there); KIT_PHOTOS may add more
// licensed pictures by name (bun-bo-hue, banh-xeo, ha-giang, egg-coffee,
// mi-quang, my-khe, balcony, yoga, air-fryer, bookshelf, android-phone,
// ha-giang-moto). Every sample has a picture; a missing file fails the run.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark/pro/entitlements.dart';
import 'package:handy_bookmark/reader/reading_position.dart';
import 'package:handy_bookmark/services/metadata_client.dart';
import 'package:handy_bookmark/share_sheet/share_sheet.dart';
import 'package:handy_bookmark/share_sheet/sheet_controller.dart';
import 'package:handy_bookmark/share_sheet/snapshot.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../test/link_tasks_test.dart' show FakeNet;
import '../test/new_flows_test.dart' show NetController, OneFile;
import '../test/share_sheet_test.dart' show FakeBridge, PictureNet;
import '../test/welcome_test.dart' show StillMotion;
import '../test/widget_test.dart' show Preferences;
import 'screens_test.dart' show PictureStore;

final _out = Platform.environment['KIT_DIR'] ?? 'build/website-kit';
final _photoDir = Platform.environment['KIT_PHOTOS'];
final _langs = (Platform.environment['KIT_LANGS'] ?? 'vi,en').split(',');
final _root = GlobalKey();

/// Where a simulated finger is, drawn into clip frames so a viewer sees
/// what was tapped. Never drawn in stills.
final _touch = ValueNotifier<Offset?>(null);

/// [child] with the finger marker on top.
Widget _touchable(Widget child) => Stack(
  textDirection: TextDirection.ltr,
  fit: StackFit.expand,
  children: [
    child,
    IgnorePointer(
      child: ValueListenableBuilder<Offset?>(
        valueListenable: _touch,
        builder: (_, at, _) => at == null
            ? const SizedBox.shrink()
            : CustomPaint(painter: _Finger(at)),
      ),
    ),
  ],
);

class _Finger extends CustomPainter {
  final Offset at;
  const _Finger(this.at);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      at + const Offset(0, 2),
      24,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(at, 22, Paint()..color = const Color(0x8CFFFFFF));
    canvas.drawCircle(
      at,
      22,
      Paint()
        ..color = const Color(0x8C1C2627)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Finger old) => old.at != at;
}

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

/// The forms a scene is drawn in.
enum KitForm {
  mobile(Size(390, 844), 3, 'light'),
  mobileDark(Size(390, 844), 3, 'dark'),
  tablet(Size(834, 1194), 2, 'light'),
  desktop(Size(1440, 900), 2, 'light'),
  desktopDark(Size(1440, 900), 2, 'dark');

  final Size size;
  final double ratio;
  final String theme;
  const KitForm(this.size, this.ratio, this.theme);
  String get label => switch (this) {
    mobile => 'mobile',
    mobileDark => 'mobile-dark',
    tablet => 'tablet',
    desktop => 'desktop',
    desktopDark => 'desktop-dark',
  };
}

/// One scene in one language and form.
class Kit {
  final String lang;
  final KitForm form;
  final String name;
  Kit(this.lang, this.form, this.name);
  bool get vi => lang == 'vi';
  String t(String en, String vi) => this.vi ? vi : en;

  /// A visible tap on [f]: the finger lands, holds for [hold] frames
  /// (filmed as `<clip>`), then lifts and the tap goes through.
  Future<void> press(
    WidgetTester t,
    Finder f,
    String clip, {
    int hold = 9,
  }) async {
    final at = t.getCenter(f.first);
    _touch.value = at;
    final g = await t.startGesture(at);
    await film(t, clip, hold);
    await g.up();
    _touch.value = null;
  }

  /// `<form>-<lang>-<name>[-<suffix>].png`
  Future<void> shot(
    WidgetTester t, [
    String suffix = '',
    bool settle = true,
  ]) async {
    if (settle) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump();
    }
    final file = '${form.label}-$lang-$name${suffix.isEmpty ? '' : '-$suffix'}';
    await _write(t, '$_out/$file.png', form.ratio);
  }

  /// A frame sequence for a clip, at 2x: `films/<lang>-<clip>/000.png`.
  Future<void> film(
    WidgetTester t,
    String clip,
    int frames, {
    Duration step = const Duration(milliseconds: 33),
    Future<void> Function(int frame)? each,
    double ratio = 2,
  }) async {
    final dir = '$_out/films/${form.label}-$lang-$clip';
    Directory(dir).createSync(recursive: true);
    for (var i = 0; i < frames; i++) {
      await each?.call(i);
      await _write(t, '$dir/${i.toString().padLeft(3, '0')}.png', ratio);
      await t.pump(step);
    }
  }
}

Future<void> _write(WidgetTester t, String path, double ratio) async {
  File(path).parent.createSync(recursive: true);
  await t.runAsync(() async {
    final b =
        _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// A saved link of the sample library.
typedef Sample = ({
  String url,
  String enUrl,
  String vi,
  String en,
  String? place,
  String photo,
  int hours,
});

/// A lived-in library: food, trips, things to buy, reading, and four new
/// saves still waiting in Not sorted.
const samples = <Sample>[
  (
    url: 'https://www.youtube.com/watch?v=bunbohue3h',
    enUrl: 'https://www.youtube.com/watch?v=bunbohue3h',
    vi: 'Bún bò Huế chuẩn vị: nấu nước dùng 3 tiếng',
    en: 'Bún bò Huế: a slow three-hour broth',
    place: 'food',
    photo: 'bun-bo-hue',
    hours: 30,
  ),
  (
    url: 'https://www.tiktok.com/@bepnhaminh/video/7301',
    enUrl: 'https://www.tiktok.com/@homecook.minh/video/7301',
    vi: 'Phở bò gia truyền, nước trong mà đậm',
    en: 'Family-recipe beef phở, clear and rich',
    place: 'food',
    photo: 'pho',
    hours: 52,
  ),
  (
    url: 'https://www.tiktok.com/@anvathanoi/video/7402',
    enUrl: 'https://www.tiktok.com/@hanoibites/video/7402',
    vi: 'Bún chả Hà Nội 15 phút',
    en: 'Hanoi bún chả in 15 minutes',
    place: 'food',
    photo: 'bun-cha',
    hours: 75,
  ),
  (
    url: 'https://www.facebook.com/groups/dulichbui/posts/88',
    enUrl: 'https://www.facebook.com/groups/vietnambackpackers/posts/88',
    vi: 'Lịch trình 3 ngày Đà Nẵng – Hội An',
    en: 'Da Nang & Hoi An: a 3-day plan',
    place: 'trip',
    photo: 'hoi-an',
    hours: 20,
  ),
  (
    url: 'https://maps.google.com/?cid=1234',
    enUrl: 'https://maps.google.com/?cid=1234',
    vi: 'Bánh xèo Bà Dưỡng',
    en: 'Bánh xèo Bà Dưỡng, Da Nang',
    place: 'dn',
    photo: 'banh-xeo',
    hours: 26,
  ),
  (
    url: 'https://nhatkydicham.vn/ha-giang-mua-nao-dep-nhat',
    enUrl: 'https://slowtravelnotes.blog/ha-giang-best-season',
    vi: 'Mùa đẹp nhất để đi Hà Giang',
    en: 'The best time of year to visit Ha Giang',
    place: 'read',
    photo: 'ha-giang',
    hours: 40,
  ),
  (
    url: 'https://www.youtube.com/watch?v=taudemhue',
    enUrl: 'https://www.youtube.com/watch?v=taudemhue',
    vi: 'Đi tàu đêm Hà Nội – Huế: cần biết gì',
    en: 'Night train Hanoi to Hue: what to know',
    place: 'trip',
    photo: 'ga-ha-noi',
    hours: 60,
  ),
  (
    url: 'https://www.youtube.com/watch?v=guitar4chords',
    enUrl: 'https://www.youtube.com/watch?v=guitar4chords',
    vi: 'Học guitar: 4 hợp âm đầu tiên',
    en: 'Guitar for beginners: your first four chords',
    place: null,
    photo: 'guitars',
    hours: 3,
  ),
  (
    url: 'https://shopee.vn/noi-chien-khong-dau-6l-i.1201.5531',
    enUrl: 'https://www.amazon.com/dp/B0C6L2AIRF',
    vi: 'Nồi chiên không dầu 6L',
    en: 'Air fryer, 6 litres',
    place: 'buy',
    photo: 'air-fryer',
    hours: 90,
  ),
  (
    url: 'https://shopee.vn/ke-sach-go-5-tang-i.88.17',
    enUrl: 'https://www.amazon.com/dp/B0B5SHELF5',
    vi: 'Kệ sách gỗ 5 tầng',
    en: 'Five-shelf wooden bookcase',
    place: 'buy',
    photo: 'bookshelf',
    hours: 98,
  ),
  (
    url: 'https://www.instagram.com/p/CxHoTay1',
    enUrl: 'https://www.instagram.com/p/CxHoTay1',
    vi: 'Cà phê trứng view hồ Tây',
    en: 'Egg coffee with a West Lake view',
    place: null,
    photo: 'egg-coffee',
    hours: 5,
  ),
  (
    url: 'https://www.tiktok.com/@nhaxinh/video/9921',
    enUrl: 'https://www.tiktok.com/@smallspaces/video/9921',
    vi: 'Trang trí ban công nhỏ với cây leo',
    en: 'Small balcony makeover with climbing plants',
    place: null,
    photo: 'balcony',
    hours: 9,
  ),
  (
    url: 'https://www.youtube.com/watch?v=yoga20sang',
    enUrl: 'https://www.youtube.com/watch?v=yoga20morning',
    vi: 'Yoga 20 phút buổi sáng',
    en: '20-minute morning yoga',
    place: null,
    photo: 'yoga',
    hours: 14,
  ),
  (
    url: 'https://x.com/meoandroid/status/1851',
    enUrl: 'https://x.com/androidtips/status/1851',
    vi: 'Mẹo: chụp màn hình cuộn cả trang trên Android',
    en: 'Tip: capture a whole scrolling page on Android',
    place: 'read',
    photo: 'android-phone',
    hours: 110,
  ),
  (
    url: 'https://www.reddit.com/r/VietNam/comments/hagiang',
    enUrl: 'https://www.reddit.com/r/travel/comments/hagiang',
    vi: 'Lần đầu đi Hà Giang bằng xe máy, cần chuẩn bị gì?',
    en: 'First time riding the Ha Giang loop: what to pack?',
    place: 'read',
    photo: 'ha-giang-moto',
    hours: 120,
  ),
  (
    url: 'https://www.youtube.com/watch?v=miquangga',
    enUrl: 'https://www.youtube.com/watch?v=miquangga',
    vi: 'Mì Quảng gà nhà làm',
    en: 'Homemade chicken mì Quảng',
    place: 'food',
    photo: 'mi-quang',
    hours: 140,
  ),
  (
    url: 'https://nhatkydicham.vn/bien-my-khe-gio-nao-dep',
    enUrl: 'https://slowtravelnotes.blog/my-khe-beach-hours',
    vi: 'Biển Mỹ Khê: tắm giờ nào đẹp nhất',
    en: 'My Khe beach: the best hours for a swim',
    place: 'dn',
    photo: 'my-khe',
    hours: 34,
  ),
];

/// Index of a sample, by what it is.
abstract final class S {
  static const bunBo = 0, pho = 1, bunCha = 2, plan = 3, banhXeo = 4;
  static const haGiang = 5, train = 6, guitar = 7, fryer = 8, shelf = 9;
  static const coffee = 10, balcony = 11, yoga = 12, tip = 13, reddit = 14;
  static const miQuang = 15, myKhe = 16;
}

Uint8List? _photo(String name) {
  for (final dir in [?_photoDir, 'assets/welcome']) {
    final f = File('$dir/$name.jpg');
    if (f.existsSync()) return f.readAsBytesSync();
  }
  return null;
}

/// The sample library, written into [c] in [lang].
Future<List<String>> fill(
  NetController c,
  String lang, {
  bool extras = true,
}) async {
  final vi = lang == 'vi';
  for (final s in samples) {
    await c.quickSave(vi ? s.url : s.enUrl, title: vi ? s.vi : s.en);
  }
  String t(String en, String v) => vi ? v : en;
  await c.update(
    (l) => l.copyWith(
      collections: [
        SaveCollection(
          id: 'food',
          name: t('Recipes', 'Công thức nấu ăn'),
          icon: 'restaurant',
          color: 'hue:1',
          position: 0,
        ),
        SaveCollection(
          id: 'trip',
          name: t('Trips', 'Du lịch'),
          icon: 'luggage',
          color: 'hue:0',
          position: 1,
        ),
        SaveCollection(
          id: 'dn',
          name: t('Da Nang', 'Đà Nẵng'),
          parentId: 'trip',
          position: 0,
        ),
        SaveCollection(
          id: 'buy',
          name: t('To buy', 'Cần mua'),
          icon: 'shopping',
          color: 'hue:2',
          position: 2,
        ),
        SaveCollection(
          id: 'read',
          name: t('Read later', 'Đọc sau'),
          icon: 'book',
          color: 'hue:3',
          position: 3,
        ),
      ],
      tags: [t('hue-food', 'món-huế'), t('weekend', 'cuối-tuần')],
      smartCollections: extras
          ? [
              SmartCollection(
                id: 'videos',
                name: t('Videos to watch', 'Video chưa xem'),
                rules: [
                  SmartRule(
                    field: 'contentType',
                    operator: 'equals',
                    value: 'video',
                  ),
                  SmartRule(field: 'isRead', operator: 'equals', value: false),
                ],
              ),
            ]
          : const [],
      savedSearches: extras
          ? [
              SavedSearch(
                id: 'dn-food',
                name: t('Da Nang eats', 'Đà Nẵng ăn gì'),
                query: {'text': 'bánh', 'place': 'all'},
              ),
              SavedSearch(
                id: 'ha-giang',
                name: 'Hà Giang',
                query: {'text': 'ha giang', 'place': 'all'},
              ),
            ]
          : const [],
      bookmarks: [
        for (final (i, b) in l.bookmarks.indexed)
          b.copyWith(
            collectionId: samples[i].place,
            tags: i == S.bunBo
                ? [t('hue-food', 'món-huế')]
                : (i == S.plan || i == S.myKhe
                      ? [t('weekend', 'cuối-tuần')]
                      : null),
            isFavorite: i == S.bunBo || i == S.banhXeo || i == S.coffee,
            isRead: i == S.fryer || i == S.reddit || i == S.miQuang,
            siteName: switch (i) {
              S.haGiang || S.myKhe => t('Slow Travel Notes', 'Nhật ký đi chậm'),
              _ => null,
            },
            description: switch (i) {
              S.bunBo => t(
                'Beef shank, pork knuckle and lemongrass, simmered slowly. The shrimp paste goes in last.',
                'Bắp bò, giò heo và sả, ninh lửa nhỏ. Mắm ruốc cho vào sau cùng.',
              ),
              S.plan => t(
                'Two nights in Da Nang, one evening in Hoi An, and what to eat on the way.',
                'Hai đêm ở Đà Nẵng, một tối ở Hội An, và ăn gì dọc đường.',
              ),
              S.haGiang => t(
                'Buckwheat flowers, golden rice or water season: pick the face you want to see.',
                'Hoa tam giác mạch, lúa chín hay mùa nước đổ: chọn gương mặt bạn muốn thấy.',
              ),
              _ => null,
            },
            savedAt: DateTime.now()
                .subtract(Duration(hours: samples[i].hours))
                .toUtc()
                .toIso8601String(),
          ),
      ],
    ),
  );
  final ids = c.library!.bookmarks.map((b) => b.id).toList();
  if (extras) {
    await c.putReadingCopies({ids[S.haGiang]: haGiangCopy(lang)});
  }
  return ids;
}

ReadingCopy haGiangCopy(String lang) => lang == 'vi'
    ? ReadingCopy(
        url: samples[S.haGiang].url,
        title: samples[S.haGiang].vi,
        byline: 'Minh Anh',
        siteName: 'Nhật ký đi chậm',
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
          ReadingBlock(
            'li',
            'Đèo Mã Pì Lèng: đi sớm trước 7 giờ để tránh mây.',
          ),
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
      )
    : ReadingCopy(
        url: samples[S.haGiang].enUrl,
        title: samples[S.haGiang].en,
        byline: 'Minh Anh',
        siteName: 'Slow Travel Notes',
        savedAt: '2026-10-28T07:30:00Z',
        blocks: [
          ReadingBlock(
            'p',
            'Ha Giang is beautiful all year, but every season shows a different face. If you only get one trip, choose by what you want to see: flowers, ripe rice, or morning mist over the passes.',
          ),
          ReadingBlock('h', 'October to November: buckwheat flower season'),
          ReadingBlock(
            'p',
            'The flowers bloom around Dong Van, Meo Vac and Sung La. The air is dry, the sun is soft and nights drop to 12 to 15 °C. It is the busiest time, so book a room at least two weeks ahead.',
          ),
          ReadingBlock(
            'li',
            'Ma Pi Leng Pass: go before 7 am, ahead of the clouds.',
          ),
          ReadingBlock(
            'li',
            'Dong Van old quarter: the market meets on Sunday mornings.',
          ),
          ReadingBlock(
            'quote',
            'Go slowly: every bend in the road is another painting.',
          ),
          ReadingBlock('h', 'April to May: water season'),
          ReadingBlock(
            'p',
            'The terraces of Hoang Su Phi are flooded and mirror the sky. The roads are lovely but slippery after rain; rent a manual bike and a local guide.',
          ),
        ],
      );

/// Starts the app on the sample library.
Future<NetController> boot(
  WidgetTester t,
  Kit k, {
  bool empty = false,
  bool extras = true,
  bool pictures = true,
  FakeNet? net,
  OneFile? files,
  Future<void> Function(NetController c, List<String> ids)? before,
}) async {
  t.view.physicalSize = k.form.size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final store = PictureStore();
  final c = NetController(store, net ?? FakeNet());
  await t.runAsync(c.initialize);
  if (net == null) c.preferences['automaticMetadata'] = false;
  if (!empty) {
    final ids = await fill(c, k.lang, extras: extras);
    if (pictures) {
      await t.runAsync(() async {
        for (final (i, s) in samples.indexed) {
          // Every saved thing shows its picture: a missing file is an error,
          // never a silent no-picture tile.
          store.pictures[ids[i]] =
              _photo(s.photo) ??
              (throw StateError('Missing photo ${s.photo}.jpg (KIT_PHOTOS)'));
        }
      });
    }
    await before?.call(c, ids);
  }
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: _touchable(
        SaveApp(
          controller: c,
          files: files ?? OneFile(),
          preferences: Preferences()
            ..value = HandyPreferences(locale: k.lang, theme: k.form.theme),
          guide: false,
        ),
      ),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await t.pumpAndSettle();
  addTearDown(c.dispose);
  return c;
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await t.pumpAndSettle();
}

Future<void> push(WidgetTester t, String route) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed(route);
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pumpAndSettle();
}

Future<void> scrollBy(WidgetTester t, double dy, {bool last = false}) async {
  final s = find.byType(Scrollable);
  await t.drag(last ? s.last : s.first, Offset(0, -dy));
  await t.pumpAndSettle();
}

void pro(bool on) {
  // ignore: invalid_use_of_visible_for_testing_member
  debugProOverride = on ? true : null;
}

/// Defines one scene for every language and the given forms.
void scene(
  String name,
  List<KitForm> forms,
  Future<void> Function(WidgetTester t, Kit k) body, {
  bool isPro = false,
}) {
  for (final lang in _langs) {
    for (final form in forms) {
      testWidgets('$name ${form.label} $lang', (t) async {
        if (isPro) {
          pro(true);
          addTearDown(() => pro(false));
        }
        await body(t, Kit(lang, form, name));
      });
    }
  }
}

const _phones = [KitForm.mobile, KitForm.mobileDark];
const _all = [
  KitForm.mobile,
  KitForm.mobileDark,
  KitForm.desktop,
  KitForm.desktopDark,
];

/// A Pocket export as a person's would look.
String pocketCsv() {
  final rows = [
    (
      'Ten things to do in Hanoi in one weekend',
      'https://slowtravelnotes.blog/hanoi-weekend',
      'travel|hanoi',
      'unread',
    ),
    (
      'Sourdough for beginners',
      'https://www.youtube.com/watch?v=sourdough101',
      'baking',
      'unread',
    ),
    (
      'Cách pha cà phê phin ngon như ngoài quán',
      'https://www.youtube.com/watch?v=caphephin',
      'cà-phê',
      'archive',
    ),
    (
      'How to keep houseplants alive in winter',
      'https://www.reddit.com/r/houseplants/comments/winter',
      'home',
      'unread',
    ),
    (
      'Lịch nghỉ lễ Tết 2027',
      'https://nhatkydicham.vn/lich-nghi-tet',
      '',
      'unread',
    ),
    (
      'Packing list for a two-week trip',
      'https://slowtravelnotes.blog/packing-list',
      'travel',
      'archive',
    ),
    (
      'Da Nang & Hoi An: a 3-day plan',
      'https://www.facebook.com/groups/vietnambackpackers/posts/88',
      'travel',
      'unread',
    ),
  ];
  final b = StringBuffer('title,url,time_added,tags,status\n');
  for (final (i, r) in rows.indexed) {
    b.writeln('"${r.$1}",${r.$2},${1760000000 + i * 86400},${r.$3},${r.$4}');
  }
  return b.toString();
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

  // ---- Home and the library -------------------------------------------
  scene('01-home', [..._all, KitForm.tablet], (t, k) async {
    await boot(t, k);
    await k.shot(t);
    if (k.form.size.height > 1000 || k.form.size.width < 700) {
      await scrollBy(t, 600);
      await k.shot(t, 'scrolled');
    }
  });
  scene('02-home-item-open', [KitForm.desktop, KitForm.desktopDark], (
    t,
    k,
  ) async {
    final c = await boot(t, k);
    await tapKey(t, 'details-${c.library!.bookmarks[S.plan].id}');
    await tapKey(t, 'item-details');
    await k.shot(t);
  });
  scene('03-collection', _all, (t, k) async {
    await boot(t, k);
    await tapKey(t, 'collection-food');
    await k.shot(t);
    await tapKey(t, 'list-more');
    await tapKey(t, 'save-view');
    await k.shot(t, 'cards');
  });
  scene('04-collection-trips', [KitForm.mobile, KitForm.desktop], (t, k) async {
    await boot(t, k);
    await push(t, '/collection/trip');
    await k.shot(t);
  });
  scene('05-item-detail', _all, (t, k) async {
    final c = await boot(t, k);
    final id = c.library!.bookmarks[S.bunBo].id;
    await c.update(
      (l) => l.copyWith(
        bookmarks: [
          for (final b in l.bookmarks)
            b.id == id
                ? b.copyWith(
                    note: k.t(
                      'Ask for the broth recipe. Go before 7 am.',
                      'Hỏi quán xin công thức nước dùng. Đi sớm trước 7h.',
                    ),
                  )
                : b,
        ],
      ),
    );
    await push(t, '/bookmark/$id');
    await k.shot(t);
  });
  scene('06-library', _phones, (t, k) async {
    await boot(t, k);
    await tapKey(t, 'home-library');
    await k.shot(t);
    await tapKey(t, 'library-advanced');
    await t.scrollUntilVisible(
      find.byKey(const Key('smart-new')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await k.shot(t, 'smart-and-saved');
  });
  scene('07-smart-collection', [KitForm.mobile, KitForm.desktop], (t, k) async {
    await boot(t, k);
    await push(t, '/smart/videos');
    await k.shot(t);
  }, isPro: true);
  scene('08-everything', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await tapKey(t, 'home-library');
    await tapKey(t, 'place-all');
    await k.shot(t);
  });
  scene(
    '09-new-collection',
    [KitForm.mobile, KitForm.mobileDark, KitForm.desktop],
    (t, k) async {
      await boot(t, k);
      await t.tap(find.byKey(const Key('collection-new')).first);
      await t.pumpAndSettle();
      await k.shot(t);
      if (k.form.size.width < 700) {
        await tapKey(t, 'template-play-4');
        await k.shot(t, 'template');
      }
    },
  );
  scene('10-cover-chooser', [KitForm.mobile], (t, k) async {
    final c = await boot(t, k);
    await c.update(
      (l) => l.copyWith(
        bookmarks: [
          for (final b in l.bookmarks)
            b.copyWith(thumbnailUrl: 'https://img.example.com/${b.id}.jpg'),
        ],
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pumpAndSettle();
    await tapKey(t, 'collection-food');
    await tapKey(t, 'list-more');
    await tapKey(t, 'collection-cover');
    await k.shot(t);
  });
  scene('11-filters', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await tapKey(t, 'collection-food');
    await tapKey(t, 'save-filters');
    await k.shot(t);
  });
  scene('12-select-move', [KitForm.mobile, KitForm.desktop], (t, k) async {
    final c = await boot(t, k);
    if (k.form.size.width < 700) await tapKey(t, 'home-library');
    await tapKey(t, 'place-all');
    final ids = c.library!.bookmarks.map((b) => b.id).toList();
    await t.longPress(find.byKey(ValueKey('card-${ids[S.guitar]}')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('card-${ids[S.coffee]}')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('card-${ids[S.balcony]}')));
    await t.pumpAndSettle();
    await k.shot(t);
  });

  // ---- Saving ------------------------------------------------------------
  scene('13-share-sheet', _phones, (t, k) async {
    await shareSheet(t, k);
    await k.shot(t);
    await t.tap(find.byKey(const Key('share-place-food')));
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
    await k.shot(t, 'saved', false);
    await t.pump(const Duration(seconds: 10));
  });
  scene('14-save-sheet', _phones, (t, k) async {
    await boot(t, k);
    await tapKey(t, 'save-new');
    await k.shot(t);
    await tapKey(t, 'save-add');
    await t.enterText(
      find.byKey(const Key('save-text-input')),
      'https://www.youtube.com/watch?v=banhcuon-thanhtri',
    );
    await t.pump();
    await k.shot(t, 'paste');
  });
  scene('15-quick-saved', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await t.enterText(
      find.byKey(const Key('bookmark-inline-url')),
      'https://www.youtube.com/watch?v=banhcuon-thanhtri',
    );
    await t.pump();
    await tapKey(t, 'bookmark-inline-save');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump(const Duration(milliseconds: 400));
    await k.shot(t, '', false);
  });
  scene('16-share-how-to', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await tapKey(t, 'save-new');
    await tapKey(t, 'save-how');
    await k.shot(t);
  });
  scene('17-picture', _phones, (t, k) async {
    final c = await boot(t, k);
    final bytes = _photo('hoi-an')!;
    unawaited(
      c.addPictures([
        (bytes: bytes, name: k.t('Hoi An old town.jpg', 'Phố cổ Hội An.jpg')),
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
    await push(
      t,
      '/bookmark/${c.library!.bookmarks.firstWhere((b) => b.isImage).id}',
    );
    await k.shot(t);
    await tapKey(t, 'detail-view-picture');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pumpAndSettle();
    await k.shot(t, 'full');
  });

  // ---- Finding and reading -------------------------------------------------
  scene('18-search', [..._phones, KitForm.desktop], (t, k) async {
    await boot(t, k);
    if (find.byKey(const Key('open-search')).evaluate().isNotEmpty) {
      await tapKey(t, 'open-search');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await k.shot(t, 'start');
    await t.enterText(find.byKey(const Key('save-search')), 'da nang');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await t.pumpAndSettle();
    await k.shot(t, 'results');
  });
  scene('19-deep-search', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await tapKey(t, 'open-search');
    await t.enterText(find.byKey(const Key('save-search')), 'dong van');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await t.pumpAndSettle();
    await k.shot(t);
  }, isPro: true);
  scene('20-focus', [..._phones, KitForm.desktop], (t, k) async {
    await boot(t, k, before: readOld);
    await tapKey(t, 'place-focus');
    await k.shot(t);
  });
  scene('21-focus-skins', _phones, (t, k) async {
    await boot(t, k);
    await tapKey(t, 'place-focus');
    await tapKey(t, 'focus-skins');
    await t.drag(find.byKey(const Key('skin-film')), const Offset(-200, 0));
    await t.pumpAndSettle();
    await k.shot(t);
  }, isPro: true);
  scene('22-reader', [..._all, KitForm.tablet], (t, k) async {
    final c = await boot(t, k);
    await openReader(t, c.library!.bookmarks[S.haGiang].id);
    await k.shot(t);
    if (k.form == KitForm.mobile) {
      await c.update((l) => l, prefs: {...c.preferences, 'readerTone': 'dark'});
      await t.pumpAndSettle();
      await k.shot(t, 'night-tone');
    }
  });
  scene('23-reader-highlights', [..._phones, KitForm.desktop], (t, k) async {
    final c = await boot(t, k);
    final id = c.library!.bookmarks[S.haGiang].id;
    final copy = haGiangCopy(k.lang);
    Map<String, Object?> mark(
      String hid,
      int block,
      int len,
      String color,
      String note,
    ) {
      final text = copy.blocks[block].text;
      final end = len.clamp(0, text.length);
      return Highlight(
        id: hid,
        block: block,
        start: 0,
        end: end,
        quote: text.substring(0, end),
        color: color,
        note: note,
        createdAt: '2026-11-06T10:00:00Z',
      ).toJson();
    }

    await c.update(
      (l) => l,
      prefs: {
        ...c.preferences,
        'highlights': {
          id: [
            mark('h0', 2, 70, 'yellow', ''),
            mark(
              'h1',
              3,
              60,
              'green',
              k.t('Set an alarm for 5:30', 'Đặt báo thức 5h30'),
            ),
            mark('h2', 7, 80, 'blue', ''),
          ],
        },
      },
    );
    await openReader(t, id);
    await k.shot(t);
    await tapKey(t, 'reader-highlights');
    await k.shot(t, 'list');
  }, isPro: true);
  scene('24-reader-find', [KitForm.mobile], (t, k) async {
    final c = await boot(t, k);
    await openReader(t, c.library!.bookmarks[S.haGiang].id);
    await t.tap(find.byKey(const Key('reader-find')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('reader-find-field')),
      k.t('pass', 'đèo'),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('reader-find-next')));
    await t.pumpAndSettle();
    await k.shot(t);
  });

  // ---- Looking after the library ---------------------------------------------
  scene('26-weekly-nudge', [KitForm.mobile], (t, k) async {
    await boot(
      t,
      k,
      before: (c, ids) async {
        c.preferences['revisit'] = true;
        c.preferences['revisitDay'] = DateTime.sunday;
        c.preferences['revisitHour'] = 19;
      },
    );
    await push(t, '/settings');
    await t.scrollUntilVisible(
      find.byKey(const Key('set-revisit')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.drag(find.byType(Scrollable).first, const Offset(0, 260));
    await t.pumpAndSettle();
    await k.shot(t);
  });
  scene('27-trash', _phones, (t, k) async {
    final now = DateTime.now().toUtc();
    final gone = [S.shelf, S.tip, S.reddit, S.yoga];
    await boot(
      t,
      k,
      before: (c, ids) async {
        for (final (i, s) in gone.indexed) {
          await c.update(
            (l) => moveToTrash(
              l,
              [ids[s]],
              now.subtract(Duration(days: [1, 8, 22, 27][i])).toIso8601String(),
            ),
          );
        }
      },
    );
    await push(t, '/trash');
    await k.shot(t);
  });
  scene('28-duplicates', [KitForm.mobile], (t, k) async {
    await boot(
      t,
      k,
      before: (c, ids) async {
        for (final s in [S.haGiang, S.plan]) {
          final url = k.vi ? samples[s].url : samples[s].enUrl;
          await c.quickSave(
            '$url?utm_source=zalo&fbclid=IwAR2x',
            title: k.vi ? samples[s].vi : samples[s].en,
            allowDuplicates: true,
          );
        }
      },
    );
    await push(t, '/duplicates');
    await k.shot(t);
  });
  scene('29-broken-links', [KitForm.mobile, KitForm.desktop], (t, k) async {
    const at = '2026-11-07T08:00:00Z';
    await boot(
      t,
      k,
      before: (c, ids) => c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final (i, b) in l.bookmarks.indexed)
              b.copyWith(
                linkCheck: switch (i) {
                  S.bunCha => LinkCheck(
                    status: 'gone',
                    checkedAt: at,
                    httpStatus: 404,
                  ),
                  S.shelf => LinkCheck(
                    status: 'gone',
                    checkedAt: at,
                    httpStatus: 410,
                  ),
                  S.haGiang => LinkCheck(
                    status: 'moved',
                    checkedAt: at,
                    httpStatus: 200,
                    movedTo: '${b.originalUrl}-2026',
                  ),
                  S.tip => LinkCheck(
                    status: 'unreachable',
                    checkedAt: at,
                    httpStatus: 403,
                    reason: 'http',
                  ),
                  _ => LinkCheck(status: 'ok', checkedAt: at, httpStatus: 200),
                },
              ),
          ],
        ),
      ),
    );
    await push(t, '/place/broken');
    await k.shot(t);
  });
  scene('30-settings', [..._phones, KitForm.desktop, KitForm.desktopDark], (
    t,
    k,
  ) async {
    await boot(t, k);
    if (k.form.size.width > 1000) {
      await tapKey(t, 'open-settings');
      await k.shot(t);
      return;
    }
    await push(t, '/settings');
    await k.shot(t);
    for (var i = 1; i <= 3; i++) {
      await scrollBy(t, 640);
      await k.shot(t, '$i');
    }
  });
  scene('31-backup-and-data', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await push(t, '/settings');
    await tapKey(t, 'set-advanced-data');
    await k.shot(t);
    await scrollBy(t, 600, last: true);
    await k.shot(t, 'more');
  });
  scene('32-library-tools', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await push(t, '/settings');
    await tapKey(t, 'set-library-tools');
    await k.shot(t);
    await t.scrollUntilVisible(
      find.byKey(const Key('set-storage')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tapKey(t, 'set-storage');
    await k.shot(t, 'storage');
  });
  scene('33-pocket-import', [KitForm.mobile], (t, k) async {
    final files = OneFile()
      ..next = ImportedBytes('part_000000.csv', utf8.encode(pocketCsv()));
    await boot(t, k, files: files);
    await push(t, '/settings');
    await tapKey(t, 'set-advanced-data');
    await tapKey(t, 'save-import-pocket');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await t.pumpAndSettle();
    await k.shot(t);
  });
  scene('34-share-collection', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await tapKey(t, 'collection-food');
    await tapKey(t, 'list-more');
    await k.shot(t, 'menu');
    await tapKey(t, 'collection-share');
    await k.shot(t);
  });
  scene('35-how-to', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await push(t, '/how-to');
    await k.shot(t);
  });
  scene('36-empty', [KitForm.mobile, KitForm.desktop], (t, k) async {
    await boot(t, k, empty: true);
    await k.shot(t);
  });

  // ---- Pro ---------------------------------------------------------------
  scene('40-pro', _phones, (t, k) async {
    await boot(t, k);
    pro(false);
    await push(t, '/pro');
    await k.shot(t);
  });
  scene('41-themes', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await push(t, '/looks');
    await k.shot(t);
    for (final look in ['ink-paper', 'midnight-gallery']) {
      await tapKey(t, 'look-$look');
      await k.shot(t, look);
      Navigator.of(t.element(find.byType(Scaffold).last)).pop();
      await t.pumpAndSettle();
    }
  }, isPro: true);
  scene('42-layouts', [KitForm.mobile], (t, k) async {
    await boot(t, k);
    await tapKey(t, 'home-library');
    await tapKey(t, 'place-all');
    await tapKey(t, 'list-more');
    await tapKey(t, 'save-layout');
    await k.shot(t, 'picker');
    await tapKey(t, 'layout-magazine');
    for (var i = 0; i < 8; i++) {
      await k.shot(t, '$i');
      if (i < 7) await tapKey(t, 'layout-next');
    }
  }, isPro: true);
  scene('43-auto-organize', [KitForm.mobile], (t, k) async {
    await boot(
      t,
      k,
      before: (c, ids) async => c.preferences['organizeAuto'] = true,
    );
    await push(t, '/organize');
    await k.shot(t);
  }, isPro: true);
  scene('44-export-studio', [KitForm.mobile, KitForm.desktop], (t, k) async {
    await boot(t, k);
    await push(t, '/export/food');
    await k.shot(t);
  }, isPro: true);

  // ---- First run -------------------------------------------------------------
  for (final form in [KitForm.mobile, KitForm.desktop]) {
    for (final lang in _langs) {
      testWidgets('50-welcome ${form.label} $lang', (t) async {
        t.platformDispatcher.accessibilityFeaturesTestValue = StillMotion();
        addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
        final k = Kit(lang, form, '50-welcome');
        await boot(t, k, empty: true);
        await push(t, '/welcome');
        await k.shot(t, '1');
        await tapKey(t, 'welcome-next-0');
        await k.shot(t, '2');
        await tapKey(t, 'welcome-next-1');
        await k.shot(t, '3-practice');
        await tapKey(t, 'practice-share');
        await k.shot(t, '4-share');
        await tapKey(t, 'practice-more');
        await k.shot(t, '5-apps');
        final apps = t.getTopLeft(find.byKey(const Key('practice-apps')));
        await t.dragFrom(apps + const Offset(60, 30), const Offset(-400, 0));
        await t.pumpAndSettle();
        await tapKey(t, 'practice-target');
        await k.shot(t, '6-pick');
        await tapKey(t, 'practice-pick-food');
        await k.shot(t, '7-saved');
        await tapKey(t, 'welcome-next-2');
        await k.shot(t, '8-find');
      });
    }
  }

  // ---- Clips (frame sequences) -------------------------------------------------
  // Every tap is shown with a finger marker (Kit.press) so a viewer can
  // follow the story; every clip ends on a settled screen.
  for (final lang in _langs) {
    testWidgets('film welcome $lang', (t) async {
      final k = Kit(lang, KitForm.mobile, 'welcome');
      await boot(t, k, empty: true);
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).pushNamed('/welcome');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await k.film(t, 'welcome-01-story', 45);
      await k.press(t, find.byKey(const Key('welcome-next-0')), 'welcome-02');
      await k.film(t, 'welcome-03-gather', 75);
      await k.press(t, find.byKey(const Key('welcome-next-1')), 'welcome-04');
      await k.film(t, 'welcome-05-practice', 40);
      await k.press(t, find.byKey(const Key('practice-share')), 'welcome-06');
      await k.film(t, 'welcome-07-share', 24);
      await k.press(t, find.byKey(const Key('practice-more')), 'welcome-08');
      await k.film(t, 'welcome-09-more', 24);
      final apps = t.getTopLeft(find.byKey(const Key('practice-apps')));
      var finger = apps + const Offset(200, 30);
      await k.film(
        t,
        'welcome-10-find-app',
        24,
        each: (i) async {
          if (i < 8) {
            _touch.value = finger;
            await t.dragFrom(finger, const Offset(-50, 0));
            finger -= const Offset(18, 0);
          } else {
            _touch.value = null;
          }
        },
      );
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      await k.press(t, find.byKey(const Key('practice-target')), 'welcome-11');
      await k.film(t, 'welcome-12-pick', 36);
      await k.press(
        t,
        find.byKey(const Key('practice-pick-food')),
        'welcome-13',
      );
      await k.film(t, 'welcome-14-saved', 45);
      await k.press(t, find.byKey(const Key('welcome-next-2')), 'welcome-15');
      // The find step types its word and shows what it found.
      await k.film(t, 'welcome-16-find', 170);
      // Leaves without the done step's timers running.
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('film share sheet $lang', (t) async {
      final k = Kit(lang, KitForm.mobile, 'share');
      final reveal = ValueNotifier<double>(0);
      await shareSheet(t, k, settle: false, reveal: reveal);
      await t.pumpAndSettle();
      // The video someone is watching, then the sheet rises over it.
      await k.film(t, 'share-1-app', 24);
      await k.film(
        t,
        'share-2-rise',
        14,
        each: (i) async =>
            reveal.value = Curves.easeOutCubic.transform((i + 1) / 14),
      );
      await k.film(t, 'share-3-sheet', 36);
      await k.press(t, find.byKey(const Key('share-place-food')), 'share-4');
      await k.film(t, 'share-5-saved', 60);
      await t.pump(const Duration(seconds: 10));
    });

    testWidgets('film file from not sorted $lang', (t) async {
      final k = Kit(lang, KitForm.mobile, 'file');
      final c = await boot(t, k);
      final id = c.library!.bookmarks[S.coffee].id;
      final home = find
          .descendant(
            of: find.byKey(const Key('save-home')),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(
        find.byKey(Key('file-$id')),
        200,
        scrollable: home,
      );
      // The "Recently saved" heading at the top, not half a tile.
      await t.drag(home, const Offset(0, -60));
      await t.pumpAndSettle();
      await k.film(t, 'file-1', 14);
      await k.press(t, find.byKey(Key('file-$id')), 'file-2');
      await k.film(t, 'file-3', 20);
      await t.pumpAndSettle();
      final chip = find.byKey(Key('file-$id-food'));
      if (chip.evaluate().isEmpty) {
        await t.tap(find.byKey(Key('file-$id-other')));
        await t.pumpAndSettle();
        await k.press(t, find.byKey(const Key('pick-food')), 'file-4');
      } else {
        await k.press(t, chip, 'file-4');
      }
      await k.film(t, 'file-5', 40);
    });

    testWidgets('film collection open $lang', (t) async {
      final k = Kit(lang, KitForm.mobile, 'collection');
      await boot(t, k);
      await k.film(t, 'collection-1', 12);
      await k.press(
        t,
        find.byKey(const Key('collection-food')),
        'collection-2',
      );
      await k.film(t, 'collection-3', 30);
      await t.pumpAndSettle();
      await k.press(t, find.byKey(const Key('list-more')), 'collection-4');
      await k.film(t, 'collection-5', 14);
      await t.pumpAndSettle();
      await k.press(t, find.byKey(const Key('save-view')), 'collection-6');
      await k.film(t, 'collection-7', 36);
    });

    testWidgets('film focus $lang', (t) async {
      final k = Kit(lang, KitForm.mobile, 'focus');
      await boot(t, k, before: readOld);
      await tapKey(t, 'place-focus');
      await k.film(t, 'focus-1', 14);
      Future<void> swipe(String name, Offset step) async {
        var at = t.getCenter(find.byKey(const Key('focus-card')));
        _touch.value = at;
        final g = await t.startGesture(at);
        await k.film(
          t,
          name,
          14,
          each: (i) async {
            await g.moveBy(step);
            at += step;
            _touch.value = at;
          },
        );
        _touch.value = null;
        await g.up();
      }

      // A thumb pushes the card right: done. Then left: later.
      await swipe('focus-2-right', const Offset(24, -2));
      await k.film(t, 'focus-3', 30);
      await t.pumpAndSettle();
      await swipe('focus-4-left', const Offset(-24, -1));
      await k.film(t, 'focus-5', 30);
    });

    testWidgets('film search $lang', (t) async {
      final k = Kit(lang, KitForm.mobile, 'search');
      await boot(t, k);
      await k.film(t, 'search-1', 10);
      await k.press(t, find.byKey(const Key('open-search')), 'search-2');
      await t.pumpAndSettle();
      const word = 'da nang';
      await k.film(t, 'search-3', 8);
      for (var n = 1; n <= word.length; n++) {
        await t.enterText(
          find.byKey(const Key('save-search')),
          word.substring(0, n),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 260)),
        );
        await k.film(t, 'search-4-${n.toString().padLeft(2, '0')}', 4);
      }
      await t.pumpAndSettle();
      await k.film(t, 'search-5', 36);
    });

    testWidgets('film dark mode $lang', (t) async {
      final k = Kit(lang, KitForm.mobile, 'theme');
      await boot(t, k);
      await push(t, '/settings');
      await k.film(t, 'theme-1', 14);
      await k.press(t, find.text(k.t('Dark', 'Tối')).last, 'theme-2');
      await k.film(t, 'theme-3', 24);
      await t.pumpAndSettle();
      Navigator.of(t.element(find.byType(Scaffold).last)).pop();
      await k.film(t, 'theme-4', 36);
    });

    testWidgets('film layouts $lang', (t) async {
      pro(true);
      addTearDown(() => pro(false));
      final k = Kit(lang, KitForm.mobile, 'layouts');
      await boot(t, k);
      await tapKey(t, 'collection-food');
      await tapKey(t, 'list-more');
      await tapKey(t, 'save-layout');
      await tapKey(t, 'layout-magazine');
      // One clean layout after another: the switch is filmed as a tap on
      // the arrow, then the settled layout (no half-faded frames).
      for (var i = 0; i < 8; i++) {
        await k.film(t, 'layouts-$i-a', 22);
        if (i < 7) {
          await k.press(
            t,
            find.byKey(const Key('layout-next')),
            'layouts-$i-b',
            hold: 6,
          );
          await t.pumpAndSettle();
        }
      }
    });
  }
}

/// Marks the two oldest unopened saves without a picture as read, so
/// Focus opens on a picture.
Future<void> readOld(NetController c, List<String> ids) => c.update(
  (l) => l.copyWith(
    bookmarks: [
      for (final (i, b) in l.bookmarks.indexed)
        i == S.tip || i == S.shelf ? b.copyWith(isRead: true) : b,
    ],
  ),
);

Future<void> openReader(WidgetTester t, String id) async {
  ReadingPositions.instance = ReadingPositions(MemorySpotStore());
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/read/$id');
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pumpAndSettle();
}

/// The share sheet over the app it was shared from (a video app, dimmed
/// by the system), its page already read.
Future<void> shareSheet(
  WidgetTester t,
  Kit k, {
  bool settle = true,
  ValueNotifier<double>? reveal,
}) async {
  t.view.physicalSize = k.form.size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final library = SaveLibrary(
    collections: [
      SaveCollection(
        id: 'food',
        name: k.t('Recipes', 'Công thức nấu ăn'),
        icon: 'restaurant',
        color: 'hue:1',
      ),
      SaveCollection(
        id: 'trip',
        name: k.t('Trips', 'Du lịch'),
        icon: 'luggage',
        color: 'hue:0',
        position: 1,
      ),
      SaveCollection(
        id: 'buy',
        name: k.t('To buy', 'Cần mua'),
        icon: 'shopping',
        color: 'hue:2',
        position: 2,
      ),
      SaveCollection(
        id: 'read',
        name: k.t('Read later', 'Đọc sau'),
        icon: 'book',
        color: 'hue:3',
        position: 3,
      ),
    ],
  );
  final raw =
      jsonDecode(
            sheetSnapshot(library, {}, locale: k.lang, theme: k.form.theme),
          )
          as Map;
  for (final (i, col) in (raw['collections'] as List).indexed) {
    (col as Map)['count'] = [12, 7, 4, 9][i];
  }
  final c = SheetController(
    bridge: FakeBridge(
      SheetShare(
        id: 'q',
        text: 'https://www.tiktok.com/@anvathanoi/video/7402',
        snapshot: SheetSnapshot.parse(jsonEncode(raw)),
      ),
    ),
    metadata: PictureNet([
      MetadataResult(
        status: 'complete',
        title: k.t('Hanoi bún chả in 15 minutes', 'Bún chả Hà Nội 15 phút'),
        siteName: 'TikTok',
        description: k.t(
          'How to marinate the pork and mix the dipping sauce.',
          'Cách ướp thịt và pha nước chấm chuẩn vị.',
        ),
        thumbnailUrl: 'https://p16.tiktokcdn.com/buncha.jpg',
      ),
    ], _photo('bun-cha')!),
  );
  addTearDown(c.dispose);
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_photo('pho')!, fit: BoxFit.cover),
            ValueListenableBuilder<double>(
              valueListenable: reveal ?? ValueNotifier(1),
              builder: (_, v, sheet) => Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: v,
                    child: const ColoredBox(color: Color(0x73000000)),
                  ),
                  if (v > 0)
                    FractionalTranslation(
                      translation: Offset(0, 1 - v),
                      child: sheet,
                    ),
                ],
              ),
              child: ShareSheetApp(controller: c),
            ),
            IgnorePointer(
              child: ValueListenableBuilder<Offset?>(
                valueListenable: _touch,
                builder: (_, at, _) => at == null
                    ? const SizedBox.shrink()
                    : CustomPaint(painter: _Finger(at)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  if (settle) await t.pumpAndSettle();
}
