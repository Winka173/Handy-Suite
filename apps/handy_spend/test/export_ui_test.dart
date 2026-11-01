import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

/// Test-only file sink: actual UI/export implementation, no system-picker claim.
class EvidenceFiles implements HandyFiles {
  final String language;
  EvidenceFiles(this.language);
  final output = <String, Uint8List>{};
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    final extension = name.split('.').last;
    final file = File(
      '../../docs/qa/evidence/spend-export/report-$language.$extension',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    output[extension] = bytes;
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
  for (final vi in [false, true])
    testWidgets(
      'the ledger exports CSV XLSX JSON PDF and settings a ZIP (${vi ? 'vi' : 'en'}); cancel writes nothing',
      (tester) async {
        final date = today(),
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
              when: '${date}T00:30:00+07:00',
              payee: 'Tiếng Việt',
              note: 'Private note',
              tags: ['cà phê'],
            );
        final files = EvidenceFiles(vi ? 'vi' : 'en');
        final c = await start(
          tester,
          store: TestSpendStore()
            ..value = SpendState(accounts: [account], entries: [entry]),
          locale: vi ? 'vi' : 'en',
          files: files,
        );
        final before = jsonEncode(c.state!.toJson());
        await tapKey(tester, 'nav-1');
        // Backing out of the warning writes nothing.
        await tapKey(tester, 'more-menu');
        await tapKey(tester, 'export-csv');
        await tapKey(tester, 'confirm-cancel');
        expect(files.output, isEmpty);
        for (final format in ['csv', 'xlsx', 'json', 'pdf']) {
          await tapKey(tester, 'more-menu');
          await tester.tap(find.byKey(Key('export-$format')));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byKey(const Key('confirm-action')));
          await settleReal(tester, () => files.output.containsKey(format));
          expect(files.output[format], isNotNull, reason: format);
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
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

        await tapKey(tester, 'nav-0');
        await tapKey(tester, 'open-settings');
        await tapKey(tester, 'spend-backup');
        await tester.tap(find.byKey(const Key('confirm-action')));
        await settleReal(tester, () => files.output.containsKey('zip'));
        expect(restore(files.output['zip']!).toJson(), c.state!.toJson());
        expect(jsonEncode(c.state!.toJson()), before);
        expect(tester.takeException(), isNull);
      },
    );
}
