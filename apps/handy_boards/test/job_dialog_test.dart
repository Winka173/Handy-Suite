import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards/platform/export_job.dart';
import 'package:handy_boards/ui/job_dialog.dart';

void main() {
  testWidgets('immediate export closes its progress route exactly once', (
    t,
  ) async {
    String? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await runBoardsJob(ctx, (_) async => 'ready');
            },
            child: const Text('Export'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Export'));
    await t.pumpAndSettle();
    expect(result, 'ready');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Export'), findsOneWidget);
  });
  testWidgets('cancel interrupts the job and closes progress without success', (
    t,
  ) async {
    Object? error;
    var success = false;
    final gate = Completer<void>();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              try {
                await runBoardsJob(ctx, (job) async {
                  job.interrupt = () => gate.complete();
                  await gate.future;
                  job.check();
                  success = true;
                });
              } catch (e) {
                error = e;
              }
            },
            child: const Text('Export'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Export'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(error, isA<BoardsJobCancelled>());
    expect(success, false);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
