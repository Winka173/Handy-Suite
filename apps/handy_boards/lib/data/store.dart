import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart'
    as platform;

abstract interface class BoardsStore {
  Future<BoardsState> read();
  Future<void> commit(BoardsState next, {required int expectedRevision});
  Future<String> integrity();
}

abstract interface class BoardsSnapshotStore {
  BoardsState? get currentSnapshot;
  void close();
}

class BoardsTaskPage {
  final List<BoardRecord> tasks;
  final int total, revision;
  const BoardsTaskPage(this.tasks, this.total, this.revision);
}

abstract interface class BoardsPagedStore {
  Future<BoardsTaskPage> taskPage({
    String? board,
    String search = '',
    Json filter = const {},
    String sort = 'manual',
    int offset = 0,
    int limit = 100,
    int? expectedRevision,
  });
}

Future<BoardsStore> openBoardsStore() => platform.openStore();
