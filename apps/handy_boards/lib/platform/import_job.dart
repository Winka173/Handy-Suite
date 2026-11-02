import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_files/handy_files.dart';
export 'import_job_stub.dart' if (dart.library.io) 'import_job_native.dart';

class BoardsPreparedImport {
  final ImportedBytes? file;
  final BoardsState? snapshot;
  final Future<void> Function() cleanup;
  const BoardsPreparedImport(this.file, this.snapshot, this.cleanup);
}
