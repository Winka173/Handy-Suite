import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/history_page.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_ui/handy_ui.dart';
import '../test/export_history_test.dart' show HistoryFiles;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native history snapshots reopen with exact metadata and no result content',
    (tester) async {
      ExportHistory history() => ExportHistory(
        'tools',
        documents: localDocuments(
          'handy-tools-history-integration',
          maxBytes: 200000,
        ),
      );
      final store = history();
      await store.clear();
      await store.record(
        tool: 'uppercase',
        uri: 'file:///user-chosen/uppercase.txt',
        mime: 'text/plain',
        data: Uint8List.fromList('PRIVATE RESULT'.codeUnits),
      );
      final before = serializeExportHistory(await store.load());
      expect(before, isNot(contains('PRIVATE RESULT')));
      expect(serializeExportHistory(await history().load()), before);
      await tester.pumpWidget(
        MaterialApp(
          theme: handyTheme(const Color(0xFF2563EB), Brightness.light),
          home: ExportHistoryPage(history: history(), files: HistoryFiles()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('uppercase ·'), findsOneWidget);
      expect(find.text('file:///user-chosen/uppercase.txt'), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('tools-export-history');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
