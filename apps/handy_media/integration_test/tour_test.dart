// A guided walk through the app for a screen recording on a device:
// python tooling/device-tour.py --device <serial> media
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/app.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:integration_test/integration_test.dart';
import '../test/guide_export_test.dart' show GuideFiles;
import '../test/helpers.dart' show Memory, Prefs, menu;
import '../tool/screens_test.dart' show library, screen;

/// Lets the viewer see the screen before the next step.
Future<void> pause(WidgetTester t, [int ms = 1200]) async {
  await t.pumpAndSettle();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

/// A message from the last step may float over the next control.
Future<void> clearMessages(WidgetTester t) async {
  final messenger = find.byType(ScaffoldMessenger);
  if (messenger.evaluate().isEmpty) return;
  t.state<ScaffoldMessengerState>(messenger.first).clearSnackBars();
  await t.pumpAndSettle();
}

/// Brings [f] on screen. On a narrow editor the picture and its panel share
/// one list, and the picture is dropped once scrolled past: look from the
/// top down.
Future<void> reveal(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    final list = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .hitTestable()
        .first;
    t.state<ScrollableState>(list).position.jumpTo(0);
    await t.pumpAndSettle();
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(f, 160, scrollable: list);
    }
  }
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await clearMessages(t);
  await reveal(t, f);
  await t.tap(f.first);
  await pause(t, 700);
}

Future<void> type(WidgetTester t, String key, String text) async {
  final f = find.byKey(Key(key));
  await reveal(t, f);
  // A new text-input client after the last one closed on the device.
  await t.tap(f);
  await t.pumpAndSettle();
  await t.enterText(f, text);
  await pause(t, 700);
}

/// Puts the keyboard away so the viewer sees what the words changed.
Future<void> doneTyping(WidgetTester t) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await pause(t, 500);
}

/// Real image work runs on the device's clock: pump until [done], without
/// settling, since a progress bar may animate meanwhile.
Future<void> waitUntil(
  WidgetTester t,
  bool Function() done, {
  int seconds = 30,
}) async {
  for (var i = 0; i < seconds * 10 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 30}) =>
    waitUntil(t, () => f.evaluate().isNotEmpty, seconds: seconds);

/// Undo and redo sit in the bar on wide screens, in "More" on narrow ones.
Future<void> history(WidgetTester t, String key) async {
  if (find.byKey(Key(key)).hitTestable().evaluate().isNotEmpty) {
    await tap(t, key);
  } else {
    await menu(t, key);
    await pause(t, 700);
  }
}

/// Goes back the way a person does: the top bar's back arrow, or the
/// system back when the screen has none.
Future<void> back(WidgetTester t) async {
  await t.pumpAndSettle();
  final arrow = find.byType(BackButton).hitTestable();
  if (arrow.evaluate().isNotEmpty) {
    await t.tap(arrow.last);
  } else {
    await t.binding.handlePopRoute();
  }
  await pause(t, 700);
}

const _srt =
    '1\n00:00:01,200 --> 00:00:03,800\nXin chào, hôm nay chúng ta học nấu phở.\n\n'
    '2\n00:00:04,000 --> 00:00:06,500\nĐầu tiên, rửa sạch xương bò.\n\n'
    '3\n00:00:06,900 --> 00:00:09,400\nChần xương trong nước sôi năm phút.\n';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Handy Media tour', (t) async {
    // Three guides with their pictures and notes, all in memory: nothing
    // is written to the device, and no picker, camera or share sheet opens.
    final store = Memory()..text = (await library(t)).serialize();
    final files = GuideFiles();
    final drafts = <String, DocumentRepository>{};
    await t.pumpWidget(
      MediaApp(
        files: files,
        documents: store,
        preferences: Prefs()
          ..value = HandyPreferences(locale: 'vi', theme: 'light'),
        drafts: (id) => drafts[id] ??= Memory(),
      ),
    );
    await pause(t, 2000);

    // The studio: each guide as a strip of film, newest first.
    await pause(t, 4200);

    // Open the Wi-Fi guide and walk its steps on the strip.
    await tap(t, 'guide-wifi');
    await pause(t, 3400);
    await tap(t, 'step-frame-wifi-2');
    await pause(t, 2600);
    await tap(t, 'step-frame-wifi-3');
    await pause(t, 2600);

    // The box tool: drag across the picture to draw a note.
    await tap(t, 'capture-tool-rect');
    final picture = find.byKey(const Key('capture-shape-input'));
    await reveal(t, picture);
    final area = t.getRect(picture);
    await t.timedDragFrom(
      area.topLeft + Offset(area.width * .06, area.height * .38),
      Offset(area.width * .88, area.height * .08),
      const Duration(milliseconds: 900),
    );
    await pause(t, 2600);

    // Its colour, then the words of the text note under it.
    await tap(t, 'capture-color-#2563EB');
    await pause(t, 2000);
    await tap(t, 'layer-c2');
    await pause(t, 1700);
    await type(t, 'capture-layer-text', 'Bấm Kết nối, chờ vài giây');
    await doneTyping(t);
    await pause(t, 2600);

    // Undo the words, then bring them back.
    await history(t, 'capture-undo');
    await pause(t, 2600);
    await history(t, 'capture-redo');
    await pause(t, 2600);

    // The export sheet, then Markdown through the review dialog. The fake
    // files record the output instead of opening a save dialog.
    await tap(t, 'guide-export-options');
    await pause(t, 3400);
    await tap(t, 'guide-export-md');
    await pause(t, 4200);
    // The progress bar animates until the export is done: no settle here.
    await t.tap(find.byKey(const Key('guide-review-confirm')));
    await waitUntil(
      t,
      () =>
          find.byType(SnackBar).evaluate().isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty,
      seconds: 15,
    );
    expect(files.outputs.keys, contains('handy-media-guide.md'));
    await pause(t, 4200);

    // Save, which goes back to the studio.
    await tap(t, 'capture-save');
    await pause(t, 4200);

    // Fix pictures: a screenshot made on the spot stands in for the picker.
    final shot = await t.runAsync(
      () => screen(
        'Đăng ký',
        [
          ('Họ và tên', 'Trần Thị Mai'),
          ('Số điện thoại', '0912 345 678'),
          ('Email', 'mai.tran@example.com'),
        ],
        button: 'Tạo tài khoản',
        hue: 0xFF7A4B2A,
      ),
    );
    files.next = ImportedBytes('Ảnh đăng ký.png', shot!);
    await tap(t, 'studio-image');
    await pause(t, 2600);
    await tap(t, 'media-import');
    await pause(t, 3400);

    // Crop to a square, through the real image engine.
    await tap(t, 'crop-preset-1:1');
    await pause(t, 2600);
    await tap(t, 'media-apply');
    await waitFor(t, find.byKey(const Key('media-result-title')));
    await pause(t, 4200);

    // Stamp Vietnamese words in the middle.
    await tap(t, 'media-tool-watermark');
    await pause(t, 2000);
    await type(t, 'watermark-text', 'Ảnh của nhà Mai');
    await doneTyping(t);
    await tap(t, 'watermark-center');
    await pause(t, 1700);
    await tap(t, 'media-apply');
    await waitFor(t, find.byKey(const Key('media-result-title')));
    await reveal(t, find.byKey(const Key('media-output-preview')));
    await pause(t, 4200);

    // Save the result: the fake files keep it.
    await tap(t, 'media-export');
    await pause(t, 3400);
    await back(t);
    await pause(t, 2600);

    // Subtitles: paste a short SRT, then shift it half a second at a time.
    await tap(t, 'studio-subtitles');
    await pause(t, 2600);
    await type(t, 'subtitle-input', _srt);
    await doneTyping(t);
    await pause(t, 3400);
    for (final key in [
      'subtitle-later',
      'subtitle-later',
      'subtitle-later',
      'subtitle-earlier',
    ]) {
      await tap(t, key);
      await pause(t, 2000);
    }
    await pause(t, 3400);
    await back(t);
    await pause(t, 2600);

    // Settings.
    await tap(t, 'open-settings');
    await pause(t, 3400);
    await reveal(t, find.byKey(const Key('open-export-history')));
    await pause(t, 3400);
    await back(t);
    await pause(t, 2600);
  });
}
