import 'package:flutter/foundation.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../data/store.dart';
import 'export_job.dart';

bool supportsStreamingExport(BoardsExportRequest request) => false;
Future<String?> saveStreamingExport(
  BoardsExportRequest request,
  BoardsJob job,
) => throw UnsupportedError('Native streaming export is unavailable');

/// The full backup ZIP as bytes (the automatic copies).
Future<Uint8List> fullBackupBytes(BoardsState state, BoardsStore? store) =>
    exportBackupAsync(state);
