import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/image/frame_page.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import 'helpers.dart' show kitTheme;
import 'quick_tools_test.dart' show Files;

/// Runs [action] on real time, so the isolate work it starts can finish,
/// then waits (bounded) for [until].
Future<void> settleWork(
  WidgetTester t,
  Finder until, [
  Future<void> Function()? action,
]) async {
  await t.runAsync(() async {
    await action?.call();
    for (var i = 0; i < 60 && until.evaluate().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await t.pump();
    }
  });
  await t.pump();
}

void main() {
  testWidgets('a shot is framed in the preview and saved at full size', (
    t,
  ) async {
    final files = Files()
      ..next = ImportedBytes(
        'shot.png',
        Uint8List.fromList(
          img.encodePng(
            img.Image(width: 540, height: 960)
              ..clear(img.ColorRgb8(20, 90, 160)),
          ),
        ),
      );
    await t.pumpWidget(
      MaterialApp(
        theme: kitTheme,
        home: FramePage(files: files),
      ),
    );
    expect(find.byKey(const Key('frame-save')), findsNothing);
    await settleWork(
      t,
      find.byKey(const Key('frame-preview')),
      () => t.tap(find.byKey(const Key('frame-pick'))),
    );
    expect(find.byKey(const Key('frame-preview')), findsOneWidget);
    Uint8List shown() =>
        (t.widget<Image>(find.byKey(const Key('frame-preview'))).image
                as MemoryImage)
            .bytes;
    final before = shown();
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('frame-ground-2')));
      for (var i = 0; i < 60 && identical(shown(), before); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await t.pump();
      }
    });
    expect(identical(shown(), before), isFalse, reason: 'preview follows');
    await t.scrollUntilVisible(
      find.byKey(const Key('frame-device-phone')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settleWork(
      t,
      find.text('Updating the preview…'),
      () => t.tap(find.byKey(const Key('frame-device-phone'))),
    );
    await settleWork(
      t,
      find.text('The framed picture is saved.'),
      () => t.tap(find.byKey(const Key('frame-save'))),
    );
    final out = img.decodePng(files.exported!)!;
    // 540 wide: a 14 px phone body each side, 8% of 540 (43 px) around it.
    expect(out.width, 540 + 2 * 14 + 2 * 43);
  });
}
