import 'package:handy_ui/kit.dart';
import 'dart:async';
import '../platform/export_job.dart';

Future<T> runBoardsJob<T>(
  BuildContext context,
  Future<T> Function(BoardsJob) work,
) async {
  final job = BoardsJob();
  BuildContext? dialog;
  final ready = Completer<void>();
  final opened = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      dialog = ctx;
      if (!ready.isCompleted) ready.complete();
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(tr(ctx, 'Preparing your file', 'Đang chuẩn bị tệp')),
          content: ValueListenableBuilder<double?>(
            valueListenable: job,
            builder: (ctx, progress, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 16),
                Text(
                  tr(
                    ctx,
                    'You can cancel. Your boards remain unchanged.',
                    'Có thể hủy; dữ liệu bảng không thay đổi.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: job.cancel,
              child: Text(tr(ctx, 'Cancel', 'Hủy')),
            ),
          ],
        ),
      );
    },
  );
  await ready.future;
  try {
    return await work(job);
  } finally {
    if (dialog?.mounted == true) Navigator.of(dialog!).pop();
    await opened;
    job.dispose();
  }
}
