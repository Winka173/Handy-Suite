import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme;
import 'package:handy_files/handy_files.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media/image/image_page.dart';
import 'package:handy_ui/kit.dart';
import 'quick_tools_test.dart' show Files, png;

class BatchFiles extends Files implements BatchHandyFiles {
  List<ImportedBytes> selected = [];
  bool fail = false;
  @override
  Future<List<ImportedBytes>> importManyBytes({
    required List<String> extensions,
    int maxFiles = 50,
    int maxEachBytes = 20000000,
    int maxTotalBytes = 60000000,
    CancellationToken? cancellation,
  }) async {
    if (fail) throw const FormatException('Batch read failed');
    return selected;
  }
}

void main() {
  testWidgets(
    'multiple import commits only after all selected images validate; cancellation/failure retain prior selection',
    (tester) async {
      final original = ImportedBytes('Original.png', png());
      final files = BatchFiles()
        ..next = original
        ..selected = [original];
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: ImagePage(files: files),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('media-import')));
      await tester.pumpAndSettle();
      for (final mode in ['cancel', 'invalid', 'failed', 'success']) {
        files.fail = mode == 'failed';
        files.selected = mode == 'cancel'
            ? []
            : [
                ImportedBytes('Second.png', png()),
                ImportedBytes(
                  'Third.png',
                  mode == 'invalid' ? Uint8List.fromList([1, 2]) : png(),
                ),
              ];
        await tester.tap(find.byKey(const Key('media-import')));
        await tester.pumpAndSettle();
        expect(find.text('1. Original.png'), findsOneWidget);
        expect(
          find.text('3. Third.png'),
          mode == 'success' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('2. Second.png'),
          mode == 'success' ? findsOneWidget : findsNothing,
        );
      }
      expect(files.next!.bytes, png());
    },
  );
}
