import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'ui_test.dart' as fixtures;

// Test-only sink. Production keeps SystemHandyFiles; this proves real bytes,
// not OS document-provider access.
class EvidenceFiles implements HandyFiles {
  final String locale;
  EvidenceFiles(this.locale);
  final output = <String, Uint8List>{};
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    final ext = name.split('.').last;
    final file = File(
      '../../docs/qa/evidence/habit-export/report-$locale.$ext',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    output[ext] = bytes;
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
  );
}

void main() {
  for (final locale in ['en', 'vi']) {
    testWidgets(
      'actual $locale PDF/CSV/MD/JSON/ZIP exports and cancellation preserve state',
      (tester) async {
        final store = fixtures.MemoryStore();
        store.value = fixtures.seeded().copy({
          'habits': [
            fixtures.seeded().habits.single.copy({
              'title': 'Đọc sách mỗi ngày',
            }).toJson(),
          ],
          'events': [
            HabitEvent(
              id: 'export-entry',
              habit: 'h',
              day: '2024-01-01',
              value: 1000,
              note: 'Ghi chú riêng tư\nhai dòng',
            ).toJson(),
          ],
          'pauses': [
            Pause(
              id: 'trip',
              from: '2024-01-02',
              until: '2024-01-03',
              reason: 'Đi Huế',
            ).toJson(),
          ],
          'settings': {'onboarded': true, 'locale': locale},
        });
        final c = HabitController(open: () async => store);
        await c.load();
        final files = EvidenceFiles(locale);
        await tester.pumpWidget(
          HabitApp(
            controller: c,
            files: files,
            clock: () => DateTime.utc(2024, 1, 8, 12),
          ),
        );
        await tester.pumpAndSettle();
        final before = jsonEncode(c.state!.toJson());
        Future<void> confirmAndWait(String format) async {
          await tester.tap(find.byKey(const Key('confirm-action')));
          for (var i = 0; i < 100 && !files.output.containsKey(format); i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();
          expect(files.output[format], isNotEmpty, reason: format);
          // Let the "Exported" message go; it sits over the buttons.
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }

        // The range report: backing out of the warning writes nothing.
        await fixtures.tapKey(tester, 'nav-3');
        await fixtures.tapKey(tester, 'export-csv');
        await fixtures.tapKey(tester, 'confirm-cancel');
        expect(files.output, isEmpty);
        for (final format in ['csv', 'md', 'pdf']) {
          await fixtures.tapKey(tester, 'export-$format');
          await confirmAndWait(format);
        }
        // Full backups from settings.
        await fixtures.tapKey(tester, 'nav-0');
        await fixtures.tapKey(tester, 'open-settings');
        await fixtures.tapKey(tester, 'habit-backup');
        await confirmAndWait('zip');
        await fixtures.tapKey(tester, 'settings-data-tools');
        await fixtures.tapKey(tester, 'habit-backup-json');
        await confirmAndWait('json');
        expect(
          restore(files.output['zip']!, zip: true).habits.single.title,
          store.value.habits.single.title,
        );
        expect(
          restore(
            files.output['json']!,
            zip: false,
          ).routines.single.steps.length,
          2,
        );
        expect(ascii.decode(files.output['pdf']!.take(5).toList()), '%PDF-');
        expect(
          importCsvLogs(
            store.value.copy({'events': []}),
            files.output['csv']!,
          ).events.single.note,
          'Ghi chú riêng tư\nhai dòng',
        );
        // Pauses travel in the backups and the CSV, and the report names them.
        expect(restore(files.output['zip']!).pauses.single.reason, 'Đi Huế');
        expect(
          importCsvLogs(
            store.value.copy({'events': [], 'pauses': []}),
            files.output['csv']!,
          ).pauses.single.id,
          'trip',
        );
        expect(
          utf8.decode(files.output['md']!),
          contains(locale == 'vi' ? '## Kỳ nghỉ' : '## Pauses'),
        );
        expect(jsonEncode(c.state!.toJson()), before);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
}
