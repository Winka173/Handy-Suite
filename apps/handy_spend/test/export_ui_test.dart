import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/handy_ui.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_spend/app.dart';
import 'package:handy_spend/controller.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'controller_test.dart' show TestSpendStore;

/// Test-only file sink: actual UI/export implementation, no system-picker claim.
class EvidenceFiles implements HandyFiles {
  final output = <String, Uint8List>{};
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    final extension = name.split('.').last;
    output[extension] = bytes;
    final file = File('../../docs/qa/evidence/spend-export/report.$extension');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) => exportBytes(
    name,
    Uint8List.fromList(utf8.encode(text)),
    mimeType: 'text/plain',
    cancellation: cancellation,
  );
}

void main() {
  testWidgets(
    'actual UI exports CSV XLSX JSON PDF ZIP; export cancellation preserves ledger',
    (tester) async {
      final date = reportDay(
            DateTime.now().toUtc().toIso8601String(),
            'Asia/Ho_Chi_Minh',
          ),
          account = Account(
            id: 'cash',
            name: 'Cash',
            currency: 'VND',
            opening: BigInt.from(100000),
            asOf: date,
          ),
          entry = Entry(
            id: 'expense',
            account: account.id,
            kind: 'expense',
            amount: BigInt.from(-1234),
            when: localTimestamp(date, 'Asia/Ho_Chi_Minh'),
            payee: 'Tiếng Việt',
            note: 'Private note',
            tags: ['cà phê'],
          );
      final store = TestSpendStore()
            ..value = SpendState(accounts: [account], entries: [entry]),
          c = SpendController(open: () async => store),
          files = EvidenceFiles();
      await c.load();
      final before = jsonEncode(c.state!.toJson());
      await tester.pumpWidget(
        MaterialApp(
          home: SpendHome(controller: c, files: files, enableDrop: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Export csv'),
        350,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 30,
      );
      await tester.tap(find.text('Export csv'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(files.output, isEmpty);
      for (final format in ['csv', 'xlsx', 'json', 'pdf']) {
        await tester.ensureVisible(find.text('Export $format'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export $format'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.runAsync(() async {
          for (var i = 0; i < 100 && !files.output.containsKey(format); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        });
        await tester.pumpAndSettle();
        expect(files.output[format], isNotNull, reason: format);
      }
      expect(
        readTransactionRows(
          c.state!,
          csvParse(utf8.decode(files.output['csv']!)),
        ).single.toJson(),
        entry.toJson(),
      );
      expect(
        readTransactionRows(
          c.state!,
          xlsxParse(files.output['xlsx']!),
        ).single.toJson(),
        entry.toJson(),
      );
      expect(
        (jsonDecode(utf8.decode(files.output['json']!)) as Map)['entries'],
        [entry.toJson()],
      );
      expect(ascii.decode(files.output['pdf']!.take(5).toList()), '%PDF-');
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Backup ZIP'),
        350,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 30,
      );
      await tester.tap(find.text('Backup ZIP'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && !files.output.containsKey('zip'); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pumpAndSettle();
      expect(restore(files.output['zip']!).toJson(), c.state!.toJson());
      expect(jsonEncode(c.state!.toJson()), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
