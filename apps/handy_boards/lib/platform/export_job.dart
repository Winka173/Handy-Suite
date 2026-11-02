import 'package:flutter/foundation.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../data/store.dart';
export 'export_job_stub.dart' if (dart.library.io) 'export_job_native.dart';

class BoardsJobCancelled implements Exception {
  const BoardsJobCancelled();
  @override
  String toString() => 'Operation cancelled; existing data preserved';
}

class BoardsJob extends ValueNotifier<double?> {
  BoardsJob() : super(null);
  bool cancelled = false;
  void Function()? interrupt;
  void cancel() {
    cancelled = true;
    interrupt?.call();
  }

  void check() {
    if (cancelled) throw const BoardsJobCancelled();
  }

  void progress(double fraction) {
    check();
    value = fraction.clamp(0, 1);
  }
}

class BoardsExportRequest {
  final BoardsState state;
  final BoardsStore store;
  final String format;
  final String? board;
  final Uint8List? font;
  final bool vi;
  const BoardsExportRequest(
    this.state,
    this.store,
    this.format, {
    this.board,
    this.font,
    this.vi = false,
  });
}
