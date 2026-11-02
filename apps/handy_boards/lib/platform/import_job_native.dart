import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:path_provider/path_provider.dart';
import '../data/store.dart';
import '../data/store_native.dart';
import 'export_job.dart';
import 'import_job.dart';
import 'staged_backup_native.dart';

bool supportsStagedImport(BoardsStore? store, HandyFiles files) =>
    store is NativeBoardsStore && files is SystemHandyFiles;
Future<BoardsPreparedImport?> prepareBoardsImport(BoardsJob job) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['zip', 'json', 'csv', 'md', 'txt'],
  );
  job.check();
  if (files.isEmpty) return null;
  final picked = files.single,
      dir = await (await getTemporaryDirectory()).createTemp('boards-import-');
  try {
    final file = File('${dir.path}/source');
    final sink = file.openWrite();
    var length = 0;
    try {
      await for (final chunk in picked.readAsByteStream()) {
        job.check();
        length += chunk.length;
        if (length > 512000000)
          throw const FormatException('Import exceeds 512 MB');
        sink.add(chunk);
        await sink.flush();
      }
    } finally {
      await sink.close();
    }
    job.check();
    if (length <= 30000000) {
      final bytes = await file.readAsBytes();
      job.check();
      return BoardsPreparedImport(
        ImportedBytes(picked.name, bytes),
        null,
        () => dir.delete(recursive: true),
      );
    }
    if (!picked.name.toLowerCase().endsWith('.zip'))
      throw const FormatException('Large imports require a ZIP backup');
    final stage = await Directory('${dir.path}/verified').create();
    final snapshot = await _prepareSnapshot(file.path, stage.path, job);
    return BoardsPreparedImport(
      null,
      snapshot,
      () => dir.delete(recursive: true),
    );
  } catch (_) {
    await dir.delete(recursive: true);
    rethrow;
  }
}

Future<BoardsState> _prepareSnapshot(
  String source,
  String stage,
  BoardsJob job,
) async {
  final receive = ReceivePort(), done = Completer<BoardsState>();
  final isolate = await Isolate.spawn(
    _prepareWorker,
    [receive.sendPort, source, stage],
    onExit: receive.sendPort,
    onError: receive.sendPort,
  );
  job.interrupt = () => isolate.kill(priority: Isolate.immediate);
  final sub = receive.listen((message) {
    if (done.isCompleted) return;
    if (message is double) {
      if (!job.cancelled) job.progress(message);
      return;
    }
    if (message is BoardsState) {
      done.complete(message);
      return;
    }
    if (message == null) {
      done.completeError(
        job.cancelled
            ? const BoardsJobCancelled()
            : StateError('Import worker stopped'),
      );
      return;
    }
    if (message is List)
      done.completeError(FormatException('${message.first}'));
  });
  if (job.cancelled) isolate.kill(priority: Isolate.immediate);
  try {
    final state = await done.future;
    job.check();
    return state;
  } finally {
    job.interrupt = null;
    isolate.kill(priority: Isolate.immediate);
    await sub.cancel();
    receive.close();
  }
}

Future<void> _prepareWorker(List<dynamic> args) async {
  final port = args[0] as SendPort;
  try {
    port.send(
      await readStagedBoardsZip(
        args[1] as String,
        args[2] as String,
        onProgress: (n) => port.send(n),
      ),
    );
  } catch (e) {
    port.send([e.toString()]);
  }
}
