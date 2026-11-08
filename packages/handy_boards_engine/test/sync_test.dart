import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

final now = DateTime(2026, 11, 8, 9);

/// One device: its state and the base it keeps between syncs.
class Device {
  BoardsState s;
  Map<String, String> base = {};
  Device(this.s);
}

/// What the app does: sync from a snapshot, then apply onto the state as
/// it is now (here the same, unless [meanwhile] edits it during the sync).
Future<BoardsSyncResult> sync(
  Device d,
  SyncProvider folder, {
  BoardsState Function(BoardsState)? meanwhile,
}) async {
  final snap = syncRecordsOf(d.s);
  final r = await syncBoardsOnce(
    local: snap,
    base: d.base,
    remote: folder,
    files: StateSyncFiles(d.s),
  );
  if (meanwhile != null) d.s = meanwhile(d.s);
  d.s = applySyncResult(d.s, snap, r);
  d.base = r.base;
  return r;
}

String b(BoardsState s) => s.rows('boards').single.id;
BoardRecord card(BoardsState s, String title) =>
    topTasks(s).firstWhere((t) => t.str('title') == title);

BoardsState start() => createFromTemplate(
  BoardsState(preferences: {'locale': 'vi', 'theme': 'dark'}),
  templateById('semester')!,
  vi: true,
  examples: true,
  now: now,
);

Map<String, Object?> records(BoardsState s) =>
    jsonDecode(jsonEncode(syncRecordsOf(s))) as Map<String, Object?>;

void main() {
  test(
    'a second device receives the board; settings stay on each device',
    () async {
      final folder = MemorySyncProvider();
      final a = Device(start());
      final phone = Device(BoardsState(preferences: {'theme': 'light'}));
      await sync(a, folder);
      await sync(phone, folder);
      expect(records(phone.s), records(a.s));
      expect(phone.s.preferences['theme'], 'light');
      phone.s.validate();
    },
  );

  test('edits on both devices meet; nothing is written when nothing '
      'changed', () async {
    final folder = MemorySyncProvider();
    final a = Device(start());
    await sync(a, folder);
    final c = Device(BoardsState());
    await sync(c, folder);
    // A renames one card, C ticks a subtask of another.
    final lab = card(a.s, 'Lab 1: dựng khung dự án');
    a.s = saveTask(a.s, lab.copy({'title': 'Lab 1 (đã sửa)'}), now: now);
    final essay = card(c.s, 'Bài luận 250 từ');
    final step = subtasksOf(c.s, essay.id).first;
    c.s = toggleChecklist(c.s, step.id, true, now: now);
    await sync(a, folder);
    await sync(c, folder);
    await sync(a, folder);
    expect(records(a.s), records(c.s));
    expect(card(c.s, 'Lab 1 (đã sửa)').id, lab.id);
    expect(a.s.get('checklist', step.id).flag('done'), isTrue);
    final writes = folder.writes;
    final r = await sync(a, folder);
    expect(r.wrote, isFalse);
    expect(folder.writes, writes);
  });

  test(
    'the same card changed on both: the later edit wins everywhere',
    () async {
      final folder = MemorySyncProvider();
      final a = Device(start());
      await sync(a, folder);
      final c = Device(BoardsState());
      await sync(c, folder);
      final id = card(a.s, 'Bài luận 250 từ').id;
      a.s = saveTask(
        a.s,
        a.s.get('tasks', id).copy({'title': 'Từ A'}),
        now: now.add(const Duration(minutes: 1)),
      );
      c.s = saveTask(
        c.s,
        c.s.get('tasks', id).copy({'title': 'Từ C, sau hơn'}),
        now: now.add(const Duration(minutes: 5)),
      );
      await sync(a, folder);
      await sync(c, folder);
      await sync(a, folder);
      expect(a.s.get('tasks', id).str('title'), 'Từ C, sau hơn');
      expect(c.s.get('tasks', id).str('title'), 'Từ C, sau hơn');
    },
  );

  test(
    'a deletion follows; an edit made elsewhere after it lives on',
    () async {
      final folder = MemorySyncProvider();
      final a = Device(start());
      await sync(a, folder);
      final c = Device(BoardsState());
      await sync(c, folder);
      final gone = card(a.s, 'Ôn chương 2').id;
      final kept = card(a.s, 'Vẽ ERD cho đề tài').id;
      a.s = a.s.remove('tasks', {gone, kept});
      c.s = saveTask(
        c.s,
        c.s.get('tasks', kept).copy({'notes': 'Thêm bảng Sách'}),
        now: now,
      );
      await sync(a, folder);
      await sync(c, folder);
      await sync(a, folder);
      for (final d in [a, c]) {
        expect(d.s.maybe('tasks', gone), isNull);
        expect(d.s.get('tasks', kept).str('notes'), 'Thêm bảng Sách');
      }
    },
  );

  test('a column deleted on one device: cards added to it elsewhere move to '
      'the first column; a lost category becomes none', () async {
    final folder = MemorySyncProvider();
    final a = Device(start());
    await sync(a, folder);
    final c = Device(BoardsState());
    await sync(c, folder);
    final board = b(a.s);
    final doing = columnsOf(a.s, board)[1];
    final first = columnsOf(a.s, board).first.id;
    final subject = categoriesOf(a.s, board).last;
    // A deletes "In progress" (moving its cards) and a subject.
    a.s = deleteColumn(a.s, doing.id, moveTo: first);
    a.s = deleteCategory(a.s, subject.id);
    // C, offline, adds a card in "In progress" with that subject.
    final added = newTask(
      c.s,
      board,
      'Thẻ mới trên máy C',
      category: subject.id,
    ).copy({'status': doing.id});
    c.s = saveTask(c.s, added, now: now);
    await sync(a, folder);
    await sync(c, folder);
    await sync(a, folder);
    for (final d in [a, c]) {
      final t = d.s.get('tasks', added.id);
      expect(t.str('status'), first);
      expect(t.data['category'], isNull);
      d.s.validate();
    }
    expect(records(a.s), records(c.s));
  });

  test('attachments travel by content and are checked', () async {
    final folder = MemorySyncProvider();
    var s = start();
    final t = topTasks(s).first;
    final bytes = Uint8List.fromList(List.generate(500, (i) => i % 251));
    final hash = sha256.convert(bytes).toString();
    s = s.copy(files: {'assets/photo1.png': bytes});
    s = s.put(
      'attachments',
      BoardRecord({
        'id': 'a0000000-0000-4000-8000-000000000001',
        'task': t.id,
        'board': t.str('board'),
        'name': 'photo1.png',
        'path': 'assets/photo1.png',
        'sha256': hash,
      }),
    );
    s.validate();
    final a = Device(s);
    final r = await sync(a, folder);
    expect(r.sent, 1);
    expect(folder.files.keys, contains('$boardsSyncRoot/media/$hash'));
    final c = Device(BoardsState());
    final got = await sync(c, folder);
    expect(got.files.keys, ['assets/photo1.png']);
    expect(c.s.file('assets/photo1.png'), bytes);
    // A damaged blob is refused and nothing changes on the device.
    final d = Device(BoardsState());
    folder.files['$boardsSyncRoot/media/$hash'] = (
      Uint8List.fromList([1, 2, 3]),
      'x',
    );
    await expectLater(sync(d, folder), throwsFormatException);
    expect(d.s.rows('boards'), isEmpty);
  });

  test(
    'a write from another device in between is merged and retried',
    () async {
      final folder = MemorySyncProvider();
      final a = Device(start());
      await sync(a, folder);
      final c = Device(BoardsState());
      await sync(c, folder);
      final board = b(a.s);
      a.s = saveTask(a.s, newTask(a.s, board, 'Từ máy A'), now: now);
      c.s = saveTask(c.s, newTask(c.s, board, 'Từ máy C'), now: now);
      folder.beforeWrite = () => sync(c, folder);
      final r = await sync(a, folder);
      expect(r.attempts, 2);
      await sync(c, folder);
      for (final d in [a, c]) {
        expect(
          topTasks(d.s).map((t) => t.str('title')),
          containsAll(['Từ máy A', 'Từ máy C']),
        );
      }
    },
  );

  test('edits typed while a sync runs survive it', () async {
    final folder = MemorySyncProvider();
    final a = Device(start());
    await sync(a, folder);
    final board = b(a.s);
    await sync(
      a,
      folder,
      meanwhile: (s) =>
          saveTask(s, newTask(s, board, 'Gõ trong lúc chờ'), now: now),
    );
    expect(card(a.s, 'Gõ trong lúc chờ'), isNotNull);
    // The next sync sends it.
    final c = Device(BoardsState());
    await sync(a, folder);
    await sync(c, folder);
    expect(card(c.s, 'Gõ trong lúc chờ'), isNotNull);
  });

  test('a file from something else is refused before anything changes', () {
    expect(
      () => decodeSyncRecords(Uint8List.fromList(utf8.encode('{"x":1}'))),
      throwsFormatException,
    );
  });
}
