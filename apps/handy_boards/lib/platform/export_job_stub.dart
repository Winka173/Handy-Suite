import 'export_job.dart';

bool supportsStreamingExport(BoardsExportRequest request) => false;
Future<String?> saveStreamingExport(
  BoardsExportRequest request,
  BoardsJob job,
) => throw UnsupportedError('Native streaming export is unavailable');
