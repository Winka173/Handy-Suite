import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/history_page.dart';
import 'package:handy_tools/specs.dart';
import 'package:handy_tools/bench/tape.dart';
import 'package:handy_tools/bench/tool_panel.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_ui/kit.dart';

class HistoryDocuments implements DocumentRepository {
  String? text;
  bool fail = false;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String value) async {
    if (fail) throw StateError('Disk full');
    text = value;
  }
}

class HistoryFiles implements HandyFiles {
  String? next;
  bool cancel = true;
  String? output;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async {
    if (cancel) return null;
    output = text;
    return 'file:///exports/$name';
  }

  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => next == null ? null : ImportedText('history.json', next!);
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async => null;
}

Future<void> pressHistory(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty)
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'only successful export records metadata; history write failure keeps actual exported output',
    (tester) async {
      final documents = HistoryDocuments(), files = HistoryFiles();
      final history = ExportHistory('tools', documents: documents);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHandyTheme(const Color(0xFFD97706), Brightness.light),
          home: Scaffold(
            body: ListView(
              children: [
                ToolPanel(
                  spec: specById['case']!,
                  files: files,
                  tape: TapeController(),
                  draft: 'private source',
                  history: history,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Legacy raw drafts fill the text field; the result is live.
      expect(find.text('PRIVATE SOURCE'), findsOneWidget);
      await tester.tap(find.byKey(const Key('export-result')));
      await tester.pumpAndSettle();
      expect(await history.load(), isEmpty);
      files.cancel = false;
      await tester.tap(find.byKey(const Key('export-result')));
      await tester.pumpAndSettle();
      expect((await history.load()).single.tool, 'case');
      expect(documents.text, isNot(contains('PRIVATE SOURCE')));
      documents.fail = true;
      await tester.tap(find.byKey(const Key('export-result')));
      await tester.pumpAndSettle();
      expect(files.output, 'PRIVATE SOURCE');
      expect(
        find.text('File saved; export history could not be updated.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'history import confirmation cancel and corrupt JSON preserve metadata, clear removes only records',
    (tester) async {
      final documents = HistoryDocuments(),
          files = HistoryFiles()..cancel = false,
          history = ExportHistory('tools', documents: HistoryDocuments());
      final source = ExportHistory('tools', documents: documents);
      await source.record(
        tool: 'uppercase',
        uri: 'file:///old.txt',
        mime: 'text/plain',
        data: Uint8List.fromList(utf8.encode('private')),
      );
      await history.restore(serializeExportHistory(await source.load()));
      final before = serializeExportHistory(await history.load());
      await tester.pumpWidget(
        MaterialApp(
          home: ExportHistoryPage(history: history, files: files),
        ),
      );
      await tester.pumpAndSettle();
      files.next = serializeExportHistory([]);
      await pressHistory(tester, find.byKey(const Key('history-import')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(serializeExportHistory(await history.load()), before);
      files.next = 'corrupt';
      await pressHistory(tester, find.byKey(const Key('history-import')));
      await tester.pumpAndSettle();
      expect(serializeExportHistory(await history.load()), before);
      await pressHistory(tester, find.byKey(const Key('history-clear')));
      await tester.tap(find.byKey(const Key('history-confirm')));
      await tester.pumpAndSettle();
      expect(await history.load(), isEmpty);
      expect(documents.text, isNotNull);
    },
  );
}
