import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/image/frame_page.dart';
import 'package:handy_media/image/screenshots_page.dart';
import 'package:handy_media/image/stitch_page.dart';
import 'package:handy_ui/kit.dart';
import 'batch_import_test.dart' show BatchFiles;
import 'helpers.dart' show kitTheme;
import 'quick_tools_test.dart' show png;

Future<void> pickWith(WidgetTester t, BatchFiles files) async {
  await t.pumpWidget(
    MaterialApp(
      theme: kitTheme,
      home: ScreenshotsPage(files: files),
    ),
  );
  await t.runAsync(() async {
    await t.tap(find.byKey(const Key('screenshots-pick')));
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await t.pump();
    }
  });
  await t.pump();
}

void main() {
  testWidgets('one screenshot opens the frame', (t) async {
    final files = BatchFiles()..selected = [ImportedBytes('a.png', png())];
    await pickWith(t, files);
    expect(find.byType(FramePage), findsOneWidget);
    expect(find.byType(StitchPage), findsNothing);
  });

  testWidgets('several screenshots open the join, in the order picked', (
    t,
  ) async {
    final files = BatchFiles()
      ..selected = [
        ImportedBytes('top.png', png()),
        ImportedBytes('bottom.png', png()),
      ];
    await pickWith(t, files);
    expect(find.byType(StitchPage), findsOneWidget);
    expect(find.byKey(const Key('stitch-join')), findsOneWidget);
  });
}
