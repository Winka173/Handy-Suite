import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/library/deep_matches.dart' show pictureTexts;
import 'package:handy_bookmark/pro/entitlements.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ocr/handy_ocr.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show OneFile, boot, settle;
import 'pictures_test.dart' show png;
import 'widget_test.dart' show tapKey;

class FakeOcr implements OcrEngine {
  int reads = 0;
  @override
  OcrPixelFormat get format => OcrPixelFormat.bgra;
  @override
  Future<OcrSupport> support() async =>
      const OcrSupport(available: true, engine: 'fake');
  @override
  Future<Map<Object?, Object?>> read(OcrInput input, String? language) async {
    reads++;
    return {
      'lines': [
        {
          'text': 'HÓA ĐƠN TIỀN ĐIỆN',
          'box': {'x': 1, 'y': 1, 'w': 6, 'h': 1},
        },
        {
          'text': 'Thành tiền: 512.340 đ',
          'box': {'x': 1, 'y': 4, 'w': 6, 'h': 1},
        },
      ],
    };
  }
}

Future<String> savePicture(WidgetTester t, OneFile files) async {
  files.next = ImportedBytes('Hóa đơn.png', png(64, 48));
  await tapKey(t, 'save-new');
  await tapKey(t, 'save-photo');
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await settle(t);
  return '';
}

void main() {
  late FakeOcr ocr;
  setUp(() {
    ocr = FakeOcr();
    ocrEngineOverride = ocr;
  });
  tearDown(() {
    ocrEngineOverride = null;
    debugProOverride = null;
  });

  Future<void> openViewer(WidgetTester t, String id) async {
    Navigator.of(
      t.element(find.byType(Scaffold).first),
    ).pushNamed('/bookmark/$id');
    await settle(t);
    await tapKey(t, 'detail-picture');
    await settle(t);
  }

  testWidgets('Free: Copy text in the viewer asks for Pro and reads nothing', (
    t,
  ) async {
    final files = OneFile();
    final (c, _) = await boot(t, files: files, urls: const []);
    await savePicture(t, files);
    final id = c.library!.bookmarks.single.id;
    await openViewer(t, id);
    await tapKey(t, 'picture-read-text');
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
    expect(ocr.reads, 0);
  });

  testWidgets('Pro: a new picture is read in the background, its text is '
      'shown to copy, kept on this device, and found by Search', (t) async {
    debugProOverride = true;
    final files = OneFile();
    final (c, _) = await boot(t, files: files, urls: const []);
    await savePicture(t, files);
    final id = c.library!.bookmarks.single.id;
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await settle(t);
    expect(ocr.reads, 1, reason: 'read after saving, without waiting');
    expect(pictureTexts(c)[id], contains('512.340'));

    await openViewer(t, id);
    await tapKey(t, 'picture-read-text');
    await settle(t);
    expect(find.byKey(const Key('picture-text')), findsOneWidget);
    expect(ocr.reads, 1, reason: 'what was read is kept');
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    await t.binding.handlePopRoute();
    await settle(t);
    await t.binding.handlePopRoute();
    await settle(t);

    await tapKey(t, 'open-search');
    await t.enterText(find.byKey(const Key('save-search')), 'tien dien');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(t);
    expect(find.text('From picture'), findsOneWidget);
  });
}
