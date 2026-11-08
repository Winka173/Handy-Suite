import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/sync/drive_sync.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'kanban_app_test.dart' show TestStore, studyState, board;

Future<BoardsController> device(BoardsState s) async {
  final c = BoardsController(open: () async => TestStore(s));
  await c.load();
  return c;
}

BoardsDriveSync drive(
  BoardsController c,
  MemorySyncProvider folder, {
  bool allow = true,
}) => BoardsDriveSync(
  c,
  provider: () => folder,
  authorize: () async => allow,
  revoke: () async {},
  base: MemoryBaseStore(),
  delay: const Duration(milliseconds: 1),
);

void main() {
  test('turning sync on uploads; a second device receives everything and '
      'keeps its own settings', () async {
    final folder = MemorySyncProvider();
    final a = await device(studyState());
    final b = await device(BoardsState(preferences: {'theme': 'dark'}));
    final da = drive(a, folder), db = drive(b, folder);
    expect(await da.enable(), isTrue);
    expect(da.state, DriveSyncState.idle);
    expect(da.lastSync, isNotNull);
    await db.enable();
    expect(b.state!.maybe('boards', board), isNotNull);
    expect(
      topTasks(b.state!, board: board).length,
      topTasks(a.state!, board: board).length,
    );
    expect(b.state!.preferences['theme'], 'dark');
  });

  test('an edit on one device reaches the other; undo history is not '
      'filled by syncs', () async {
    final folder = MemorySyncProvider();
    final a = await device(studyState());
    final b = await device(BoardsState());
    final da = drive(a, folder), db = drive(b, folder);
    await da.enable();
    await db.enable();
    final card = topTasks(a.state!, board: board).first;
    await a.change(
      (s) => saveTask(s, s.get('tasks', card.id).copy({'title': 'Đổi tên'})),
    );
    await da.syncNow();
    await db.syncNow();
    expect(b.state!.get('tasks', card.id).str('title'), 'Đổi tên');
    expect(b.canUndo, isFalse);
  });

  test('saying no to Google changes nothing', () async {
    final folder = MemorySyncProvider();
    final a = await device(studyState());
    final da = drive(a, folder, allow: false);
    expect(await da.enable(), isFalse);
    expect(da.enabled, isFalse);
    expect(folder.writes, 0);
  });

  test(
    'a broken connection leaves the boards as they were and says so',
    () async {
      final folder = MemorySyncProvider();
      final a = await device(studyState());
      final da = drive(a, folder);
      await da.enable();
      final before = syncRecordsOf(a.state!);
      await a.change((s) => saveTask(s, newTask(s, board, 'Mới')));
      folder.failWrites = 1;
      await da.syncNow();
      expect(da.state, DriveSyncState.failed);
      expect(topTasks(a.state!).any((t) => t.str('title') == 'Mới'), isTrue);
      expect(syncRecordsOf(a.state!)['boards'], before['boards']);
      // It goes through next time.
      await da.syncNow();
      expect(da.state, DriveSyncState.idle);
    },
  );

  test('turning sync off deletes nothing and forgets the base', () async {
    final folder = MemorySyncProvider();
    final a = await device(studyState());
    final da = drive(a, folder);
    await da.enable();
    final tasks = a.state!.rows('tasks').length;
    await da.disable();
    expect(da.enabled, isFalse);
    expect(a.state!.rows('tasks').length, tasks);
    expect(folder.files.keys, contains('$boardsSyncRoot/boards.json'));
  });
}
