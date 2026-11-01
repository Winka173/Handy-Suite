// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs/app.dart';
import 'package:handy_docs/scan/scan_screen.dart';
import 'package:handy_docs/session.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../test/helpers.dart';

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

/// A photographed page: slightly warm paper, a heading and lines of text.
Future<Uint8List> photo(String heading, List<String> lines, int warm) async {
  const w = 600.0, h = 848.0;
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  c.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..color = Color.fromARGB(255, 250, 247 - warm, 240 - warm * 2),
  );
  var y = 70.0;
  void text(String s, double size, FontWeight weight) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'packages/handy_ui/Geist',
          fontSize: size,
          fontWeight: weight,
          color: const Color(0xFF26231F),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 120);
    p.paint(c, Offset(60, y));
    y += p.height + size * .9;
  }

  text(heading, 34, FontWeight.w700);
  y += 10;
  for (final l in lines) {
    text(l, 19, FontWeight.w400);
  }
  final img = await r.endRecording().toImage(w.toInt(), h.toInt());
  return (await img.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
}

const _draft = '''# Biên bản họp nhóm dự án

**Ngày:** 30/10/2026 · **Người ghi:** Lan

## Đã chốt
- [x] Lịch giao hàng đợt 1: thứ Hai, 9/11
- [x] Kho Bình Dương nhận hàng từ 8 giờ sáng
- [ ] Gửi báo giá vận chuyển cho anh Minh

## Phân việc tuần tới
| Việc | Người làm | Hạn |
| --- | --- | --- |
| In hợp đồng | Hùng | 3/11 |
| Kiểm kho | Mai | 5/11 |

> Ghi chú: mọi thay đổi gửi vào nhóm trước 17 giờ.
''';

Future<Docs> boot(
  WidgetTester t,
  Size size, {
  String theme = 'light',
  bool empty = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final docs = Docs();
  docs.prefs.value = HandyPreferences(locale: 'vi', theme: theme);
  if (!empty) {
    final pages = await t.runAsync(
      () async => [
        await photo('HÓA ĐƠN TIỀN ĐIỆN', [
          'Kỳ: tháng 10/2026',
          'Khách hàng: Nguyễn Thị Lan',
          'Chỉ số mới: 4.812 · Chỉ số cũ: 4.603',
          'Điện năng tiêu thụ: 209 kWh',
          'Thành tiền: 512.340 đ',
          'Hạn thanh toán: 15/11/2026',
        ], 4),
        await photo('Trang 2', [
          'Bậc 1 (0–50 kWh): 1.806 đ/kWh',
          'Bậc 2 (51–100 kWh): 1.866 đ/kWh',
          'Bậc 3 (101–200 kWh): 2.167 đ/kWh',
          'Bậc 4 (201–300 kWh): 2.729 đ/kWh',
          'Thuế GTGT 8%',
        ], 8),
        await photo('Giấy xác nhận', [
          'Xác nhận ông/bà Trần Văn Hùng',
          'đã nộp đủ hồ sơ đăng ký học phần',
          'học kỳ I năm học 2026–2027.',
          '',
          'Hà Nội, ngày 28/10/2026',
        ], 2),
      ],
    );
    docs.scan.text = ScanSession([
      ScanPage('p1', 'Hóa đơn điện T10.jpg', pages![0]),
      ScanPage('p2', 'Hóa đơn điện T10 (2).jpg', pages[1]),
      ScanPage('p3', 'Giấy xác nhận.jpg', pages[2]),
    ]).serialize();
    docs.markdown.text = serializeMarkdownDraft(_draft);
    docs.reader.text = ReaderLibrary([
      for (final (i, n, k, f, s) in [
        (
          1,
          'Hướng dẫn máy giặt.md',
          'markdown',
          'Nhà',
          '# Máy giặt\n\nChọn chế độ **Cotton** cho đồ thường. Đồ len dùng chế độ **Len**, nước lạnh.\n\n1. Cho đồ vào lồng, không quá 8 kg.\n2. Đổ nước giặt vào ngăn II.\n3. Bấm **Bắt đầu**.\n',
        ),
        (
          2,
          'ghi-chu-hop.txt',
          'text',
          'Công việc',
          'Họp thứ Hai: chốt lịch giao hàng.\nGửi báo giá trước thứ Tư.',
        ),
        (
          3,
          'config.yaml',
          'code',
          '',
          'server:\n  port: 8080\n  host: 0.0.0.0\nlog: info\n',
        ),
      ])
        ReaderDocument.parse(
          ReaderDocument(
            id: 'doc-$i',
            name: n,
            kind: k,
            folder: f,
            favorite: i == 1,
            source: s,
            createdAt: '2026-10-2${i}T09:00:00.000Z',
            lastOpenedAt: DateTime.now()
                .subtract(Duration(days: i - 1))
                .toUtc()
                .toIso8601String(),
          ).toJson(),
        ),
    ]).serialize();
  }
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: DocsApp(
        files: docs.files,
        documents: docs.scan,
        markdownDocuments: docs.markdown,
        readerDocuments: docs.reader,
        preferences: docs.prefs,
        camera: docs.camera..on = true,
        history: docs.history,
      ),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await t.pumpAndSettle();
  return docs;
}

Future<void> open(WidgetTester t, String route) async {
  Navigator.of(t.element(find.byKey(const Key('docs-desk')))).pushNamed(route);
  await t.pump(const Duration(milliseconds: 300));
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
    testWidgets('$label desk', (t) async {
      await boot(t, size);
      await shot(t, '$label-1-desk');
    });
  }
  testWidgets('phone empty desk', (t) async {
    await boot(t, const Size(390, 844), empty: true);
    await shot(t, 'phone-2-desk-empty');
  });
  testWidgets('phone dark desk', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await shot(t, 'phone-3-desk-dark');
  });
  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label scan', (t) async {
      await boot(t, size);
      await open(t, '/scan');
      await shot(t, '$label-4-scan');
    });
  }
  testWidgets('phone corners', (t) async {
    await boot(t, const Size(390, 844));
    await open(t, '/scan');
    await t.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('scan-page-p1')),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-5-corners');
  });
  testWidgets('phone write', (t) async {
    await boot(t, const Size(390, 844));
    await open(t, '/write');
    await shot(t, 'phone-6-write');
    await t.tap(find.text('Xem trước'));
    await t.pumpAndSettle();
    await shot(t, 'phone-7-preview');
  });
  testWidgets('phone find', (t) async {
    await boot(t, const Size(390, 844));
    await open(t, '/write');
    await menu(t, 'markdown-find-open');
    await t.enterText(find.byKey(const Key('markdown-find')), 'giao hàng');
    await t.pumpAndSettle();
    await shot(t, 'phone-8-find');
  });
  for (final theme in ['light', 'dark']) {
    testWidgets('desktop write $theme', (t) async {
      await boot(t, const Size(1440, 900), theme: theme);
      await open(t, '/write');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      await shot(t, 'desktop-9-write-$theme');
    });
  }
  testWidgets('phone export sheet', (t) async {
    await boot(t, const Size(390, 844));
    await open(t, '/write');
    await t.tap(find.byKey(const Key('markdown-export')));
    await t.pumpAndSettle();
    await shot(t, 'phone-10-export');
  });
  testWidgets('phone pdf', (t) async {
    await boot(t, const Size(390, 844));
    await open(t, '/pdf');
    await shot(t, 'phone-11-pdf-empty');
  });
  testWidgets('phone read', (t) async {
    await boot(t, const Size(390, 844));
    await open(t, '/read');
    await shot(t, 'phone-12-read');
    await t.tap(find.byKey(const Key('reader-open-doc-1')));
    await t.pumpAndSettle();
    await shot(t, 'phone-13-document');
  });
  testWidgets('desktop read', (t) async {
    await boot(t, const Size(1440, 900));
    await open(t, '/read');
    await t.tap(find.byKey(const Key('reader-open-doc-1')));
    await t.pumpAndSettle();
    await shot(t, 'desktop-14-read');
  });
  testWidgets('desktop settings', (t) async {
    await boot(t, const Size(1440, 900));
    await open(t, '/settings');
    await shot(t, 'desktop-15-settings');
  });
  testWidgets('films', (t) async {
    await boot(t, const Size(390, 844));
    await open(t, '/write');
    await film(t, 'phone-preview', () async {
      await t.tap(find.text('Xem trước'));
      await t.pump();
    });
  });
  testWidgets('scan film', (t) async {
    await boot(t, const Size(390, 844));
    await open(t, '/scan');
    final png = await t.runAsync(
      () => photo('Biên nhận', ['Số: 0412', 'Đã nhận đủ hồ sơ.'], 6),
    );
    await film(t, 'phone-new-page', () async {
      await t.runAsync(() async {
        await t
            .widget<ScanScreen>(find.byType(ScanScreen))
            .store
            .put(png!, 'Biên nhận.jpg');
      });
      await t.pump();
    }, frames: 20);
  });
  testWidgets('desktop read film', (t) async {
    await boot(t, const Size(1440, 900));
    await open(t, '/read');
    await t.tap(find.byKey(const Key('reader-open-doc-1')));
    await t.pumpAndSettle();
    await film(t, 'desktop-read-switch', () async {
      await t.tap(find.byKey(const Key('reader-open-doc-2')));
      await t.pump();
    });
  });
}
