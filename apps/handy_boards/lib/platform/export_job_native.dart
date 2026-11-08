import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../data/store.dart';
import '../data/store_native.dart';
import 'export_job.dart';

bool supportsStreamingExport(BoardsExportRequest request) =>
    request.store is NativeBoardsStore &&
    ['zip', 'pdf'].contains(request.format);

/// Owns only a fresh private temporary directory, never the user's destination.
Future<String?> saveStreamingExport(
  BoardsExportRequest request,
  BoardsJob job,
) async {
  final dir = await (await getTemporaryDirectory()).createTemp(
    'boards-export-',
  );
  final output = '${dir.path}/handy-boards.${request.format}';
  try {
    await runBoardsExportWorker(
      (request.store as NativeBoardsStore).path,
      request.state.revision,
      request.format,
      output,
      job,
      board: request.board,
      font: request.font,
      vi: request.vi,
    );
    job.check();
    if (Platform.isAndroid || Platform.isIOS) {
      const bridge = MethodChannel('handy.boards/files');
      job.interrupt = () {
        unawaited(bridge.invokeMethod('cancel'));
      };
      final saved = await bridge.invokeMethod<String>('save', {
        'path': output,
        'name': 'handy-boards.${request.format}',
        'mime': request.format == 'zip' ? 'application/zip' : 'application/pdf',
      });
      job.check();
      return saved;
    }
    final folder = await FilePicker.getDirectoryPath();
    job.check();
    if (folder == null) return null;
    final suffix = newId();
    final target = File('$folder/handy-boards-$suffix.${request.format}');
    final partial = File('${target.path}.part');
    try {
      final sink = partial.openWrite();
      try {
        await for (final chunk in File(output).openRead()) {
          job.check();
          sink.add(chunk);
          await sink.flush();
        }
      } finally {
        await sink.close();
      }
      job.check();
      if (await target.exists()) throw StateError('Destination already exists');
      await partial.rename(target.path);
      return target.path;
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  } finally {
    job.interrupt = null;
    await dir.delete(recursive: true);
  }
}

/// The full backup ZIP as bytes, for the automatic copies. On the device
/// store it is written by the export worker (originals included) into a
/// private temporary folder, read, and the folder removed.
Future<Uint8List> fullBackupBytes(BoardsState state, BoardsStore? store) async {
  if (store is! NativeBoardsStore) return exportBackupAsync(state);
  final dir = await (await getTemporaryDirectory()).createTemp('boards-auto-');
  try {
    final output = '${dir.path}/handy-boards.zip';
    await runBoardsExportWorker(
      store.path,
      state.revision,
      'zip',
      output,
      BoardsJob(),
    );
    return await File(output).readAsBytes();
  } finally {
    await dir.delete(recursive: true);
  }
}

/// Cancel kills this export-only isolate. It can never mutate the source DB.
Future<void> runBoardsExportWorker(
  String database,
  int revision,
  String format,
  String output,
  BoardsJob job, {
  String? board,
  Uint8List? font,
  bool vi = false,
}) async {
  job.check();
  final receive = ReceivePort(), done = Completer<void>();
  final isolate = await Isolate.spawn(
    _exportWorker,
    [receive.sendPort, database, revision, format, output, board, font, vi],
    onError: receive.sendPort,
    onExit: receive.sendPort,
  );
  job.interrupt = () {
    isolate.kill(priority: Isolate.immediate);
  };
  final subscription = receive.listen((message) {
    if (done.isCompleted) return;
    if (message is double) {
      if (!job.cancelled) job.progress(message);
      return;
    }
    if (message == 'done') {
      done.complete();
      return;
    }
    if (message is List && message.first == 'error') {
      done.completeError(FormatException(message[1] as String));
      return;
    }
    if (message is List || message == null)
      done.completeError(
        job.cancelled
            ? const BoardsJobCancelled()
            : StateError('Export worker stopped before completion'),
      );
  });
  try {
    job.check();
    await done.future;
  } finally {
    job.interrupt = null;
    isolate.kill(priority: Isolate.immediate);
    await subscription.cancel();
    receive.close();
  }
}

Future<void> _exportWorker(List<dynamic> args) async {
  final port = args[0] as SendPort, db = openBoardsDatabase(args[1] as String);
  try {
    final s = readBoardsRevision(db, args[1] as String, args[2] as int);
    s.validate();
    if (args[3] == 'zip') {
      await writeBoardsZip(
        s,
        args[4] as String,
        onProgress: (n) => port.send(n),
      );
    } else {
      await writeBoardsPdf(
        s,
        args[5] as String,
        args[6] as Uint8List,
        args[4] as String,
        vi: args[7] as bool,
        onProgress: (n) => port.send(n),
      );
    }
    port.send('done');
  } catch (e) {
    port.send(['error', e.toString()]);
  } finally {
    db.close();
  }
}

/// Streams metadata and copies one bounded original at a time into a stored ZIP.
Future<void> writeBoardsZip(
  BoardsState s,
  String output, {
  void Function(double)? onProgress,
}) async {
  final work = await Directory(
    '${File(output).parent.path}/zip-work-${newId()}',
  ).create();
  final encoder = ZipFileEncoder();
  var opened = false;
  try {
    final metadata = File('${work.path}/boards.json'),
        sink = metadata.openWrite();
    try {
      sink.write(
        '{"app":"handy-boards","schema":4,"revision":${s.revision},"preferences":${jsonEncode(s.preferences)}',
      );
      for (final k in kinds) {
        sink.write(',${jsonEncode(k)}:[');
        var first = true, count = 0;
        for (final r in s.rows(k)) {
          if (!first) sink.write(',');
          first = false;
          sink.write(jsonEncode(r.data));
          if (++count % 250 == 0) await sink.flush();
        }
        sink.write(']');
        await sink.flush();
      }
      sink.write('}');
    } finally {
      await sink.close();
    }
    if (await metadata.length() > 100000000)
      throw const FormatException('Backup metadata exceeds 100 MB');
    final checks = <String, Json>{
      'boards.json': {
        'bytes': await metadata.length(),
        'sha256': (await sha256.bind(metadata.openRead()).first).toString(),
      },
    };
    if (s.filePaths.length > 9998)
      throw const FormatException('Backup exceeds 10000 entries');
    encoder.create(output, level: ZipFileEncoder.store);
    opened = true;
    await encoder.addFile(metadata, 'boards.json', ZipFileEncoder.store);
    var index = 0;
    for (final path in s.filePaths) {
      final file = File('${work.path}/asset.tmp');
      final bytes = await s.readFile(path);
      final info = s.assetInfo(path);
      if (bytes.length != info['bytes'] ||
          sha256.convert(bytes).toString() != info['sha256'])
        throw const FormatException('Backup checksum mismatch');
      await file.writeAsBytes(bytes, flush: true);
      await encoder.addFile(file, path, ZipFileEncoder.store);
      checks[path] = info;
      onProgress?.call(++index / (s.filePaths.length + 1));
      await file.delete();
    }
    final manifest = File('${work.path}/manifest.json');
    await manifest.writeAsString(
      jsonEncode({
        'app': 'handy-boards',
        'schema': 4,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'files': checks,
      }),
    );
    await encoder.addFile(manifest, 'manifest.json', ZipFileEncoder.store);
    await encoder.close();
    opened = false;
    onProgress?.call(1);
  } finally {
    if (opened) await encoder.close();
    await work.delete(recursive: true);
  }
}

class _FilePdfStream extends PdfStream {
  final RandomAccessFile file;
  int _position = 0;
  _FilePdfStream(this.file);
  @override
  int get offset => _position;
  @override
  void putByte(int b) {
    file.writeByteSync(b);
    _position++;
  }

  @override
  void putBytes(List<int> bytes) {
    file.writeFromSync(bytes);
    _position += bytes.length;
  }

  @override
  void setBytes(int offset, Iterable<int> bytes) {
    file.setPositionSync(offset);
    file.writeFromSync(bytes.toList());
    file.setPositionSync(_position);
  }

  @override
  void putStream(PdfStream stream) => putBytes(stream.output());
  @override
  Uint8List output() => throw UnsupportedError('PDF is streamed to disk');
}

Future<void> writeBoardsPdf(
  BoardsState s,
  String board,
  Uint8List font,
  String output, {
  bool vi = false,
  void Function(double)? onProgress,
}) async {
  final doc = pw.Document(),
      theme = pw.ThemeData.withFont(
        base: pw.Font.ttf(ByteData.sublistView(font)),
      );
  final tasks = s
      .rows('tasks')
      .where(
        (t) =>
            t.str('board') == board &&
            !t.flag('trashed') &&
            !t.flag('archived'),
      );
  final total = tasks.length;
  var count = 0;
  var batch = <BoardRecord>[];
  void page() {
    final rows = List<BoardRecord>.of(batch);
    batch.clear();
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        maxPages: 20,
        build: (_) => [
          pw.Header(text: s.get('boards', board).str('title')),
          pw.Text('$total ${vi ? 'công việc' : 'tasks'}'),
          for (final t in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(t.str('title')),
                  pw.Text(
                    '${s.maybe('categories', t.data['category'])?.str('title') ?? '—'} / ${s.get('statuses', t.str('status')).str('title')}',
                  ),
                  if (t.data['due'] != null)
                    pw.Text(deadlineSort(object(t.data['due']))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  for (final t in tasks) {
    batch.add(t);
    count++;
    if (batch.length == 40) {
      page();
      onProgress?.call(count / (total + 1));
      await Future<void>.delayed(Duration.zero);
    }
  }
  if (batch.isNotEmpty || total == 0) page();
  final file = File(output).openSync(mode: FileMode.write);
  try {
    await doc.write(_FilePdfStream(file), enableEventLoopBalancing: true);
    file.flushSync();
  } finally {
    file.closeSync();
  }
  onProgress?.call(1);
}
