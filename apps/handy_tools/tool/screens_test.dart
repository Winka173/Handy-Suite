// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_tools/app.dart';
import 'package:handy_tools/bench/bench_page.dart';
import 'package:handy_ui/kit.dart';
import '../test/pilot_test.dart'
    show FixtureFiles, MemoryPreferences, QrTestDocuments, fixturePicture;

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
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
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

Future<void> boot(WidgetTester t, Size size, {String theme = 'light'}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final repo = MemoryPreferences()
    ..state = HandyPreferences(
      theme: theme,
      locale: 'vi',
      favorites: ['split-bill', 'loan', 'units'],
    );
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: HandyToolsApp(
        repository: repo,
        files: FixtureFiles(),
        qrHistoryDocuments: QrTestDocuments(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> enter(WidgetTester t, String text, {bool submit = true}) async {
  await t.enterText(find.byKey(const Key('bench-input')), text);
  await t.pumpAndSettle();
  if (submit) {
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
  }
}

Future<void> openTool(WidgetTester t, String id) async {
  await t.tap(find.byKey(const Key('open-catalog')));
  await t.pumpAndSettle();
  final row = find.byKey(Key('catalog-$id'));
  await t.scrollUntilVisible(
    row,
    120,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.tap(row);
  await t.pumpAndSettle();
}

Future<void> type(WidgetTester t, String key, String text) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.enterText(find.byKey(Key(key)), text);
  await t.pumpAndSettle();
}

Future<void> route(
  WidgetTester t,
  String id, [
  Map<String, String> values = const {},
]) async {
  Navigator.of(
    t.element(find.byType(BenchPage)),
  ).pushNamed('/tool/$id', arguments: values);
  await t.pumpAndSettle();
}

Future<void> bank(WidgetTester t) async {
  await route(t, 'qr');
  await t.tap(find.byKey(const Key('qr-mode-bank')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('qr-bank')));
  await t.pumpAndSettle();
  await t.enterText(
    find.descendant(
      of: find.byKey(const Key('qr-bank')),
      matching: find.byType(TextField),
    ),
    'Vietcombank',
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Vietcombank · VCB').last);
  await t.pumpAndSettle();
  await type(t, 'qr-field-0', '0071000123456');
  await type(t, 'qr-field-1', '1.250.000');
  await type(t, 'qr-field-2', 'Tiền nhà tháng 11');
}

const _srt = '''1
00:00:01,200 --> 00:00:03,800
Anh về muộn thế?

2
00:00:04,100 --> 00:00:06,000
Tắc đường ở cầu Chương Dương.

3
00:00:06,500 --> 00:00:09,250
Cơm để trong nồi, còn nóng đấy.

4
00:00:10,000 --> 00:00:12,400
Mai mình về quê ăn giỗ bà nhé.

5
00:00:13,000 --> 00:00:15,500
Ừ, để anh xin nghỉ buổi chiều.
''';

Future<void> fillTape(WidgetTester t) async {
  await enter(t, '1.385.000 / 3');
  await enter(t, '15% của 2.400.000');
  await enter(t, '4 x 125.000');
  await enter(t, '5 km sang mi');
  await enter(t, '1.385.000 / 3', submit: false);
}

/// Frames of a transition for the review GIFs (`name-film-000.png`…).
Future<void> film(
  WidgetTester t,
  String name,
  Future<void> Function() action, {
  int frames = 16,
  Duration step = const Duration(milliseconds: 25),
}) async {
  await action();
  for (var i = 0; i < frames; i++) {
    await shot(t, '$name-film-${i.toString().padLeft(3, '0')}', settle: false);
    await t.pump(step);
  }
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
    await _font('IBMPlexSans', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    await _font('MaterialIcons', [
      '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(768, 1024)),
    ('laptop', const Size(1024, 768)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label empty', (t) async {
      await boot(t, size);
      await shot(t, '$label-1-empty');
    });
    testWidgets('$label working', (t) async {
      await boot(t, size);
      await fillTape(t);
      await shot(t, '$label-2-working');
    });
    testWidgets('$label text chain', (t) async {
      await boot(t, size);
      await enter(
        t,
        'Nguyễn Văn An\nnguyễn văn an\nTrần Thị Bình',
        submit: false,
      );
      await t.tap(find.byKey(const Key('transform-accents')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('transform-title-case')));
      await t.pumpAndSettle();
      await shot(t, '$label-3-chain');
    });
    testWidgets('$label loan form', (t) async {
      await boot(t, size);
      await openTool(t, 'loan');
      await type(t, 'field-principal', '250000000');
      await type(t, 'field-rate', '9.5');
      await type(t, 'field-months', '24');
      await t.scrollUntilVisible(
        find.byKey(const Key('bench-answer')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await shot(t, '$label-4-loan');
    });
    testWidgets('$label qr', (t) async {
      await boot(t, size);
      await openTool(t, 'qr');
      await t.tap(find.byKey(const Key('qr-mode-wifi')));
      await t.pumpAndSettle();
      await type(t, 'qr-field-0', 'Nha Minh 5G');
      await type(t, 'qr-field-1', 'bep-ga-2026');
      await shot(t, '$label-5-qr');
    });
    testWidgets('$label password', (t) async {
      await boot(t, size);
      await openTool(t, 'password');
      await shot(t, '$label-6-password');
    });
    testWidgets('$label measure', (t) async {
      fixturePicture = await t.runAsync(_tablePhoto);
      await boot(t, size);
      await openTool(t, 'measure');
      await t.tap(find.byKey(const Key('measure-pick')));
      // The photo decodes off the test clock; wait for the board, bounded.
      for (
        var i = 0;
        i < 40 && find.byKey(const Key('measure-board')).evaluate().isEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await t.pump();
      }
      final board = find.byKey(const Key('measure-board'));
      await t.ensureVisible(board);
      await t.pumpAndSettle();
      final origin = t.getTopLeft(board), k = t.getSize(board).width / 1600;
      for (final p in const [
        Offset(160, 760),
        Offset(1016, 760),
        Offset(1200, 260),
        Offset(1200, 1100),
      ]) {
        await t.tapAt(origin + p * k);
        await t.pump();
      }
      await t.pumpAndSettle();
      await shot(t, '$label-6c-measure');
      fixturePicture = null;
    });
    testWidgets('$label draw', (t) async {
      await boot(t, size);
      await openTool(t, 'draw');
      await t.tap(find.byKey(const Key('draw-mode-teams')));
      await t.pumpAndSettle();
      await type(t, 'draw-list', 'An\nBình\nChi\nDũng\nEm\nGiang\nHà');
      await t.ensureVisible(find.byKey(const Key('draw-go')));
      await t.tap(find.byKey(const Key('draw-go')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('draw-go')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('draw-result')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await shot(t, '$label-6b-draw');
    });
    testWidgets('$label catalog', (t) async {
      await boot(t, size);
      await t.tap(find.byKey(const Key('open-catalog')));
      await t.pumpAndSettle();
      await shot(t, '$label-7-catalog');
    });
    testWidgets('$label salary', (t) async {
      await boot(t, size);
      await route(t, 'salary', {'date': '2026-11-02', 'dependants': '1'});
      await type(t, 'field-amount', '45.000.000');
      await t.scrollUntilVisible(
        find.byKey(const Key('bench-answer')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await shot(t, '$label-10-salary');
    });
    testWidgets('$label words', (t) async {
      await boot(t, size);
      await route(t, 'number-words', {'number': '1.250.000'});
      await shot(t, '$label-11-words');
    });
    testWidgets('$label lunar', (t) async {
      await boot(t, size);
      await route(t, 'lunar', {'date': '2026-09-25'});
      await shot(t, '$label-12-lunar');
    });
    testWidgets('$label vietqr', (t) async {
      await boot(t, size);
      await bank(t);
      await shot(t, '$label-13-vietqr');
    });
    testWidgets('$label subtitles', (t) async {
      await boot(t, size);
      await route(t, 'subtitles');
      await t.enterText(find.byKey(const Key('subtitle-input')), _srt);
      await t.enterText(find.byKey(const Key('subtitle-offset')), '1500');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      await shot(t, '$label-14-subtitles');
    });
    testWidgets('$label settings', (t) async {
      await boot(t, size);
      await t.tap(find.byKey(const Key('open-settings')));
      await t.pumpAndSettle();
      await shot(t, '$label-8-settings');
    });
  }
  testWidgets('phone 320 new states', (t) async {
    await boot(t, const Size(320, 700));
    await route(t, 'case', {
      'text': 'đơn xin nghỉ phép. kính gửi phòng nhân sự',
    });
    await t.tap(find.text('Đầu câu'));
    await t.pumpAndSettle();
    await shot(t, 'narrow-15-case');
    await t.tap(find.byKey(const Key('tool-close')));
    await t.pumpAndSettle();
    await route(t, 'salary', {
      'date': '2026-11-02',
      'mode': 'net',
      'amount': '20.000.000',
      'insured': '5.310.000',
    });
    await shot(t, 'narrow-16-salary-rules');
    await t.scrollUntilVisible(
      find.byKey(const Key('rows-note')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(t, 'narrow-17-salary-payslip');
    await t.tap(find.byKey(const Key('tool-close')));
    await t.pumpAndSettle();
    await route(t, 'lunar', {
      'direction': 'lunar',
      'lday': '1',
      'lmonth': '5',
      'lyear': '2025',
      'leap': 'yes',
    });
    await shot(t, 'narrow-18-lunar-error');
    await t.tap(find.byKey(const Key('tool-close')));
    await t.pumpAndSettle();
    await route(t, 'subtitles');
    await shot(t, 'narrow-19-subtitles-empty');
    await t.enterText(find.byKey(const Key('subtitle-input')), _srt);
    await t.enterText(find.byKey(const Key('subtitle-offset')), '-2000');
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    await shot(t, 'narrow-20-subtitles-problem');
  });
  testWidgets('phone dark salary', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await route(t, 'salary', {'date': '2026-11-02', 'amount': '30.000.000'});
    await t.scrollUntilVisible(
      find.byKey(const Key('bench-answer')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(t, 'phone-21-dark-salary');
  });
  testWidgets('phone dark working', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await fillTape(t);
    await shot(t, 'phone-9-dark');
  });
  testWidgets('films', (t) async {
    await boot(t, const Size(390, 844));
    await film(t, 'phone-answer', () async {
      await t.enterText(
        find.byKey(const Key('bench-input')),
        '15% của 2.400.000',
      );
      await t.pump();
    });
    await film(t, 'phone-tape', () async {
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
    });
    await film(t, 'phone-catalog', () async {
      await t.tap(find.byKey(const Key('open-catalog')).first);
      await t.pump();
    });
  });

  testWidgets('phone notebook', (t) async {
    await boot(t, const Size(390, 844));
    await t.ensureVisible(find.byKey(const Key('open-notebook')));
    await t.tap(find.byKey(const Key('open-notebook')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('notebook-text')),
      'Tiền nhà: 5tr\nĐiện 1.200.000\nĂn trưa 22 x 35k\ntổng\n\n'
      'tiết kiệm = ans * 10%\nchia 3 = 6.235.000 / 3',
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-22-notebook');
  });
}

/// A table seen from above: a bank card (85.6 mm, 856 px) beside a remote
/// control 840 px long, so the remote reads about 84 mm.
Future<Uint8List> _tablePhoto() async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
    const Rect.fromLTWH(0, 0, 1600, 1200),
    Paint()..color = const Color(0xFFB98A5E),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(160, 220, 856, 540),
      const Radius.circular(32),
    ),
    Paint()..color = const Color(0xFF2F6FB0),
  );
  c.drawRect(
    const Rect.fromLTWH(220, 330, 120, 90),
    Paint()..color = const Color(0xFFE2C46B),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(1140, 260, 120, 840),
      const Radius.circular(40),
    ),
    Paint()..color = const Color(0xFF26282B),
  );
  final image = await rec.endRecording().toImage(1600, 1200);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
