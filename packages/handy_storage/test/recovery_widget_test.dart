import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_storage/src/documents_io.dart';

class RecoveryFiles implements HandyFiles {
  Uint8List? output;
  bool cancel = false, fail = false;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    if (fail) throw StateError('Provider failed');
    if (cancel) return null;
    output = bytes;
    return 'saved';
  }

  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async => null;
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
}

Future<void> settleRecovery(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'real file recovery confirms reset, handles provider cancel/failure, and undoes exact bytes',
    (tester) async {
      final folder = await tester.runAsync(
        () => Directory.systemTemp.createTemp('handy-recovery-ui-'),
      );
      final store = FileDocuments('handy-test', 10000, directory: folder);
      final files = RecoveryFiles();
      await tester.runAsync(() => store.save('{"n":1}'));
      final snapshot = File('${folder!.path}/handy-test/a.json');
      await tester.runAsync(() => snapshot.writeAsBytes([0, 255, 42]));
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentRecoveryPage(documents: store, files: files),
        ),
      );
      await settleRecovery(tester);
      await tester.tap(find.byKey(const Key('recovery-reset')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settleRecovery(tester);
      expect(await tester.runAsync(snapshot.readAsBytes), [0, 255, 42]);
      await tester.tap(find.byKey(const Key('recovery-reset')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('recovery-confirm')));
      await settleRecovery(tester);
      expect(await tester.runAsync(store.load), isNull);
      final copies = await tester.runAsync(store.preserved);
      final id = copies!.single.id;
      for (final mode in ['cancel', 'fail', 'success']) {
        files.cancel = mode == 'cancel';
        files.fail = mode == 'fail';
        final button = find.byKey(Key('recovery-export-$id'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await settleRecovery(tester);
        if (mode == 'cancel')
          expect(find.text('Export canceled'), findsOneWidget);
        if (mode == 'fail')
          expect(find.byKey(const Key('recovery-error')), findsOneWidget);
      }
      expect(files.output, isNotEmpty);
      await tester.tap(find.byKey(Key('recovery-undo-$id')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('recovery-confirm')));
      await settleRecovery(tester);
      expect(await tester.runAsync(snapshot.readAsBytes), [0, 255, 42]);
      expect(await tester.runAsync(store.preserved), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => folder.delete(recursive: true));
    },
  );
}
