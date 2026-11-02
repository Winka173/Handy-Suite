import 'package:handy_files/handy_files.dart';
import '../data/store.dart';
import 'export_job.dart';
import 'import_job.dart';

bool supportsStagedImport(BoardsStore? store, HandyFiles files) => false;
Future<BoardsPreparedImport?> prepareBoardsImport(BoardsJob job) =>
    throw UnsupportedError('Native staged import unavailable');
