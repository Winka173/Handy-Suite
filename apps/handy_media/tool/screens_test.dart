// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/app.dart';
import 'package:handy_media/image/frame_page.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media/capture_library.dart';
import 'package:handy_media/guide/text_reader.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../test/helpers.dart';
import '../test/quick_tools_test.dart' show Files;

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

/// Frames of a transition for the review GIFs (`name-film-000.png`…).
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

/// A phone screenshot of a made-up app: a bar, a title, rows and a button.
Future<Uint8List> screen(
  String title,
  List<(String, String)> rows, {
  String button = '',
  int hue = 0xFF2F6F5E,
}) async {
  const w = 540.0, h = 1080.0;
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  c.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFFF6F7F9),
  );
  c.drawRect(const Rect.fromLTWH(0, 0, w, 150), Paint()..color = Color(hue));
  void text(
    String s,
    double x,
    double y,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) {
    TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: 'packages/handy_ui/Geist',
            fontSize: size,
            fontWeight: weight,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout(maxWidth: w - x - 30)
      ..paint(c, Offset(x, y));
  }

  text('9:41', 30, 20, 20, Colors.white, weight: FontWeight.w600);
  text(title, 30, 80, 34, Colors.white, weight: FontWeight.w700);
  var y = 190.0;
  for (final (label, value) in rows) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, y, w - 48, 92),
        const Radius.circular(14),
      ),
      Paint()..color = Colors.white,
    );
    text(
      label,
      48,
      y + 16,
      22,
      const Color(0xFF1C1C1E),
      weight: FontWeight.w600,
    );
    text(value, 48, y + 50, 19, const Color(0xFF6B7280));
    y += 108;
  }
  if (button.isNotEmpty) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, h - 170, w - 48, 84),
        const Radius.circular(42),
      ),
      Paint()..color = Color(hue),
    );
    text(
      button,
      w / 2 - button.length * 6.5,
      h - 144,
      26,
      Colors.white,
      weight: FontWeight.w600,
    );
  }
  final img = await r.endRecording().toImage(w.toInt(), h.toInt());
  return (await img.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
}

ProjectLayer layer(
  String id,
  String kind,
  double x,
  double y,
  double w,
  double h, {
  String text = '',
  String color = '#EA580C',
  List<ProjectPoint>? points,
}) => ProjectLayer.parse({
  'id': id,
  'kind': kind,
  'x': x,
  'y': y,
  'width': w,
  'height': h,
  'color': color,
  'text': text,
  if (points != null) 'points': [for (final p in points) p.toJson()],
});

Future<CaptureLibrary> library(WidgetTester t) async {
  final shots = await t.runAsync(
    () async => [
      await screen('Wi-Fi', [
        ('Wi-Fi', 'Bật'),
        ('Nhà Lan 5G', 'Đã kết nối'),
        ('Văn phòng', 'Có mật khẩu'),
        ('Thêm mạng', ''),
      ]),
      await screen('Văn phòng', [
        ('Mật khẩu', '••••••••'),
        ('Bảo mật', 'WPA2'),
        ('Địa chỉ IP', 'Tự động'),
      ], button: 'Kết nối'),
      await screen(
        'Đăng ký',
        [
          ('Họ và tên', 'Trần Thị Mai'),
          ('Số điện thoại', '0912 345 678'),
          ('Email', 'mai.tran@example.com'),
        ],
        button: 'Tạo tài khoản',
        hue: 0xFF7A4B2A,
      ),
      await screen(
        'Xác nhận',
        [('Mã gửi tới', '0912 345 678'), ('Nhập mã', '— — — — — —')],
        button: 'Xác nhận',
        hue: 0xFF7A4B2A,
      ),
      await screen(
        'Thanh toán',
        [
          ('Đơn hàng', '#A-2041'),
          ('Tổng tiền', '1.250.000 đ'),
          ('Thẻ', '•••• 4821'),
        ],
        button: 'Thanh toán',
        hue: 0xFF34506E,
      ),
    ],
  );
  ProjectStep step(
    String id,
    int i,
    String title,
    String body,
    List<ProjectLayer> notes,
  ) => ProjectStep(
    id: id,
    title: title,
    body: body,
    imageUri: 'file:///handy-media/$id.png',
    imageWidth: 540,
    imageHeight: 1080,
    annotations: notes,
  );
  CaptureProject guide(
    String id,
    String title,
    String kind,
    List<ProjectStep> steps,
    List<String> tags,
    int hoursAgo,
  ) => CaptureProject.parse({
    ...CaptureProject.create(id, title: title).toJson(),
    'kind': kind,
    'tags': tags,
    'steps': [for (final s in steps) s.toJson()],
    'updatedAt': DateTime.now()
        .toUtc()
        .subtract(Duration(hours: hoursAgo))
        .toIso8601String()
        .replaceFirst(RegExp(r'\.\d+Z$'), '.000Z'),
  });
  final wifi = [
    step('wifi-1', 0, 'Mở Wi-Fi', 'Vào Cài đặt rồi chọn Wi-Fi.', [
      layer('a1', 'step', .06, .22, .1, .05, text: '1'),
      layer('a2', 'highlight', .04, .17, .92, .09),
    ]),
    step(
      'wifi-2',
      1,
      'Chọn mạng Văn phòng',
      'Mạng có biểu tượng khóa cần mật khẩu.',
      [
        layer(
          'b1',
          'arrow',
          .7,
          .52,
          .2,
          .1,
          points: [const ProjectPoint(.86, .62), const ProjectPoint(.62, .5)],
        ),
        layer('b2', 'rect', .04, .37, .92, .09),
      ],
    ),
    step('wifi-3', 2, 'Nhập mật khẩu', 'Hỏi lễ tân nếu chưa có mật khẩu.', [
      layer('c1', 'redact', .08, .21, .6, .05, color: '#000000'),
      layer('c2', 'text', .1, .7, .7, .06, text: 'Bấm Kết nối'),
      layer('c3', 'step', .84, .82, .1, .05, text: '3'),
    ]),
  ];
  final signup = [
    step('su-1', 0, 'Điền thông tin', 'Số điện thoại dùng để nhận mã.', [
      layer('d1', 'redact', .08, .35, .55, .05, color: '#000000'),
      layer('d2', 'redact', .08, .45, .7, .05, color: '#000000'),
      layer('d3', 'ellipse', .1, .82, .8, .1),
    ]),
    step('su-2', 1, 'Nhập mã xác nhận', 'Mã có hiệu lực 5 phút.', [
      layer('e1', 'spotlight', .04, .27, .92, .09),
    ]),
  ];
  final pay = [
    step('pay-1', 0, 'Kiểm tra đơn hàng', '', [
      layer(
        'f1',
        'pen',
        .3,
        .3,
        .5,
        .1,
        color: '#2563EB',
        points: [
          const ProjectPoint(.12, .38),
          const ProjectPoint(.4, .41),
          const ProjectPoint(.7, .37),
          const ProjectPoint(.88, .4),
        ],
      ),
    ]),
  ];
  return CaptureLibrary([
    PortableCapture(
      guide('pay', 'Lỗi nút Thanh toán không phản hồi', 'bug', pay, [
        'app-bán-hàng',
      ], 70),
      {'file:///handy-media/pay-1.png': shots![4]},
    ),
    PortableCapture(
      guide('signup', 'Đăng ký tài khoản cho bố mẹ', 'guide', signup, [
        'gia-đình',
      ], 26),
      {
        'file:///handy-media/su-1.png': shots[2],
        'file:///handy-media/su-2.png': shots[3],
      },
    ),
    PortableCapture(
      guide('wifi', 'Kết nối Wi-Fi văn phòng', 'guide', wifi, [
        'văn-phòng',
        'người-mới',
      ], 2),
      {
        'file:///handy-media/wifi-1.png': shots[0],
        'file:///handy-media/wifi-2.png': shots[0],
        'file:///handy-media/wifi-3.png': shots[1],
      },
    ),
  ]);
}

Future<Files> boot(
  WidgetTester t,
  Size size, {
  String theme = 'light',
  bool empty = false,
  PortableCapture? extra,
  TextReader? reader,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final store = Memory();
  if (!empty) {
    final lib = await library(t);
    store.text = CaptureLibrary([...lib.projects, ?extra]).serialize();
  }
  final files = Files();
  final drafts = <String, DocumentRepository>{};
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: MediaApp(
        files: files,
        documents: store,
        preferences: Prefs()
          ..value = HandyPreferences(locale: 'vi', theme: theme),
        drafts: (id) => drafts[id] ??= Memory(),
        reader: reader,
      ),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await t.pumpAndSettle();
  return files;
}

Future<void> openGuide(WidgetTester t, String id) async {
  await t.tap(find.byKey(Key('guide-$id')));
  await t.pumpAndSettle();
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await t.pumpAndSettle();
}

/// The rows of a made-up screen, as a recogniser reads them: each label and
/// value one line, words boxed where [screen] drew them.
List<OcrLine> readRows(List<(String, String)> rows) {
  final lines = <OcrLine>[];
  void line(String text, double x, double y, double size) {
    final words = <OcrWord>[];
    var at = x;
    for (final w in text.split(' ')) {
      final width = w.length * size * .56;
      words.add(OcrWord(w, OcrBox(at, y, width, size * 1.25)));
      at += width + size * .28;
    }
    lines.add(OcrLine(text, OcrBox(x, y, at - x, size * 1.25), words: words));
  }

  var y = 190.0;
  for (final (label, value) in rows) {
    line(label, 48, y + 16, 22);
    if (value.isNotEmpty) line(value, 48, y + 50, 19);
    y += 108;
  }
  return lines;
}

class RowReader implements TextReader {
  final List<OcrLine> lines;
  RowReader(this.lines);
  @override
  bool get supported => true;
  @override
  Future<List<OcrLine>> read(
    Uint8List png, {
    CancellationToken? cancellation,
  }) async => lines;
}

const _profile = [
  ('Email', 'mai.tran@example.com'),
  ('Số điện thoại', '0912 345 678'),
  ('Số tài khoản', '0071 0012 34568'),
  ('Mã OTP', '482913'),
  ('Thành phố', 'Đà Nẵng'),
];

Future<PortableCapture> profileGuide(WidgetTester t) async {
  final pic = await t.runAsync(
    () => screen('Hồ sơ', _profile, button: 'Lưu', hue: 0xFF34506E),
  );
  final step = ProjectStep(
    id: 'profile-1',
    title: 'Mở hồ sơ',
    body: 'Kiểm tra thông tin trước khi gửi ảnh.',
    imageUri: 'file:///handy-media/profile-1.png',
    imageWidth: 540,
    imageHeight: 1080,
  );
  return PortableCapture(
    CaptureProject.parse({
      ...CaptureProject.create('profile', title: 'Gửi ảnh hồ sơ').toJson(),
      'steps': [step.toJson()],
    }),
    {step.imageUri: pic!},
  );
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
    testWidgets('$label studio', (t) async {
      await boot(t, size);
      await shot(t, '$label-1-studio');
    });
  }
  testWidgets('phone empty studio', (t) async {
    await boot(t, const Size(390, 844), empty: true);
    await shot(t, 'phone-2-studio-empty');
  });
  testWidgets('phone editor', (t) async {
    await boot(t, const Size(390, 844));
    await openGuide(t, 'wifi');
    await shot(t, 'phone-3-editor');
    await t.tap(find.byKey(const ValueKey('step-frame-wifi-3')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('layer-c2')));
    await t.pumpAndSettle();
    await shot(t, 'phone-4-editor-note');
  });
  for (final theme in ['light', 'dark']) {
    testWidgets('desktop editor $theme', (t) async {
      await boot(t, const Size(1440, 900), theme: theme);
      await openGuide(t, 'wifi');
      await t.tap(find.byKey(const ValueKey('step-frame-wifi-2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('layer-b2')));
      await t.pumpAndSettle();
      await shot(t, 'desktop-5-editor-$theme');
    });
  }
  testWidgets('phone export sheet', (t) async {
    await boot(t, const Size(390, 844));
    await openGuide(t, 'signup');
    await t.tap(find.byKey(const Key('guide-export-options')));
    await t.pumpAndSettle();
    await shot(t, 'phone-6-export');
  });
  testWidgets('image tools', (t) async {
    final files = await boot(t, const Size(1440, 900));
    final pic = await t.runAsync(
      () => screen(
        'Đăng ký',
        [('Họ và tên', 'Trần Thị Mai'), ('Email', 'mai.tran@example.com')],
        button: 'Tạo tài khoản',
        hue: 0xFF7A4B2A,
      ),
    );
    files.next = ImportedBytes('Ảnh đăng ký.png', pic!);
    await go(t, '/image');
    await t.tap(find.byKey(const Key('media-import')));
    await t.pumpAndSettle();
    await shot(t, 'desktop-7-image-crop');
    await t.tap(find.text('Đóng dấu'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('media-apply')));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await t.pumpAndSettle();
    await shot(t, 'desktop-8-image-stamp');
  });
  testWidgets('phone image', (t) async {
    final files = await boot(t, const Size(390, 844));
    final pic = await t.runAsync(
      () => screen('Wi-Fi', [('Wi-Fi', 'Bật'), ('Nhà Lan 5G', 'Đã kết nối')]),
    );
    files.next = ImportedBytes('Wi-Fi.png', pic!);
    await go(t, '/image');
    await t.tap(find.byKey(const Key('media-import')));
    await t.pumpAndSettle();
    await shot(t, 'phone-9-image');
  });
  testWidgets('desktop settings', (t) async {
    await boot(t, const Size(1440, 900));
    await go(t, '/settings');
    await shot(t, 'desktop-11-settings');
  });
  testWidgets('phone dark studio', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await shot(t, 'phone-12-studio-dark');
  });
  testWidgets('desktop step film', (t) async {
    await boot(t, const Size(1440, 900));
    await openGuide(t, 'wifi');
    await film(t, 'desktop-step-switch', () async {
      await t.tap(find.byKey(const ValueKey('step-frame-wifi-2')));
      await t.pump();
    });
  });
  testWidgets('desktop draw film', (t) async {
    await boot(t, const Size(1440, 900));
    await openGuide(t, 'signup');
    await t.tap(find.byKey(const Key('capture-tool-rect')));
    await t.pumpAndSettle();
    final area = t.getRect(find.byKey(const Key('capture-shape-input')));
    await film(t, 'desktop-draw-note', () async {
      await t.dragFrom(
        area.topLeft + Offset(area.width * .1, area.height * .78),
        Offset(area.width * .8, area.height * .1),
      );
      await t.pump();
    });
  });

  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label gif sheet', (t) async {
      await boot(t, size);
      await openGuide(t, 'wifi');
      await t.tap(find.byKey(const Key('guide-export-options')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('guide-export-gif')));
      await t.pumpAndSettle();
      await shot(t, '$label-13-export-with-gif');
      await t.tap(find.byKey(const Key('guide-export-gif')));
      await t.pumpAndSettle();
      await shot(t, '$label-14-gif-sheet');
    });
    testWidgets('$label sensitive review', (t) async {
      await boot(
        t,
        size,
        extra: await profileGuide(t),
        reader: RowReader(readRows(_profile)),
      );
      await openGuide(t, 'profile');
      await t.ensureVisible(find.byKey(const Key('capture-find-sensitive')));
      await t.pumpAndSettle();
      await shot(t, '$label-15-find-sensitive');
      await t.tap(find.byKey(const Key('capture-find-sensitive')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('sensitive-row-2')));
      await t.tap(find.byKey(const Key('sensitive-row-2')));
      await t.pumpAndSettle();
      await shot(t, '$label-16-sensitive-review');
      await t.tap(find.byKey(const Key('sensitive-apply')));
      await t.pumpAndSettle();
      await shot(t, '$label-17-sensitive-hidden');
    });
    testWidgets('$label windows capture', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const channel = MethodChannel('handy_capture');
      final pic = await t.runAsync(
        () => screen('Hồ sơ', _profile, button: 'Lưu', hue: 0xFF34506E),
      );
      var taken = false;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        const shot = {
          'uri': 'file:///handy-capture/windows/shot-1-1.png',
          'mime': 'image/png',
          'width': 540,
          'height': 1080,
        };
        if (call.method == 'screenshot') taken = true;
        return switch (call.method) {
          'screenshot' => shot,
          'read' => pic,
          _ => {
            'recording': false,
            'pending': false,
            'lastResult': taken ? shot : null,
            'error': null,
          },
        };
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      });
      await boot(t, size);
      await shot(t, '$label-18-studio-windows');
      await go(t, '/capture');
      await shot(t, '$label-19-capture-windows');
      await t.tap(find.byKey(const Key('native-screenshot')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pumpAndSettle();
      await shot(t, '$label-20-capture-windows-result');
      await t.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final (label, size) in const [
    ('phone', Size(390, 844)),
    ('desktop', Size(1440, 900)),
  ]) {
    testWidgets('$label frame', (t) async {
      final files = await boot(t, size);
      final pic = await t.runAsync(
        () => screen(
          'Đăng ký',
          [('Họ và tên', 'Trần Thị Mai'), ('Email', 'mai.tran@example.com')],
          button: 'Tạo tài khoản',
          hue: 0xFF7A4B2A,
        ),
      );
      files.next = ImportedBytes('Ảnh đăng ký.png', pic!);
      await go(t, '/frame');
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('frame-pick')));
        for (
          var i = 0;
          i < 60 && find.byKey(const Key('frame-preview')).evaluate().isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await t.pump();
        }
        await t.tap(find.byKey(const Key('frame-preset-story')));
        await t.enterText(
          find.byKey(const Key('frame-title')),
          'Tạo tài khoản trong 30 giây',
        );
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        await t.pump();
      });
      await t.pump();
      await shot(t, '$label-22-frame');
    });
  }
  testWidgets('frame quick looks', (t) async {
    final pic = await t.runAsync(
      () => screen(
        'Đăng ký',
        [('Họ và tên', 'Trần Thị Mai'), ('Email', 'mai.tran@example.com')],
        button: 'Tạo tài khoản',
        hue: 0xFF7A4B2A,
      ),
    );
    final dir = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/shots')
      ..createSync(recursive: true);
    await t.runAsync(() async {
      final small = framePreviewSource(pic!, maxWidth: 360);
      for (final (id, _, _, look) in framePresets) {
        File(
          '${dir.path}/look-$id.png',
        ).writeAsBytesSync(frameScreenshot(small, look));
      }
    });
  });

  testWidgets('phone screenshots empty', (t) async {
    await boot(t, const Size(390, 844));
    // Mid-screen, clear of the bar pinned at the foot.
    await Scrollable.ensureVisible(
      t.element(find.byKey(const Key('studio-screenshots'))),
      alignment: .5,
    );
    await t.pumpAndSettle();
    // The web entry page; the studio tile goes straight to the picker.
    await go(t, '/screenshots');
    expect(find.byKey(const Key('screenshots-pick')), findsOneWidget);
    await shot(t, 'phone-21-screenshots');
  });
}
