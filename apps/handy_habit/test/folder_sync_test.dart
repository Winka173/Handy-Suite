import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/sync/folder_provider.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'run15_reliability_test.dart' show dartExecutable;

void main() {
  test(
    'two Windows host processes create or verify the same immutable file',
    () async {
      final folder = Directory.systemTemp.createTempSync(
        'habit-process-writers-',
      );
      addTearDown(() => folder.deleteSync(recursive: true));
      final writers = await Future.wait([
        for (var i = 0; i < 2; i++)
          Process.start(dartExecutable(), [
            'run',
            'tool/folder_writer.dart',
            folder.path,
          ]),
      ]);
      for (final writer in writers) {
        final out = writer.stdout.drain<void>(),
            err = writer.stderr.drain<void>();
        expect(await writer.exitCode, 0);
        await out;
        await err;
      }
      expect(
        await FolderSyncProvider(folder.path).list('handy-habit/commits'),
        {'same-123.json'},
      );
    },
  );
  late Directory dir;
  late FolderSyncProvider provider;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('habit-folder-');
    provider = FolderSyncProvider(dir.path);
  });
  tearDown(() => dir.deleteSync(recursive: true));
  test(
    'immutable create, verify, refusal and interrupted staging files',
    () async {
      const path = 'handy-habit/commits/a-123.json';
      final bytes = Uint8List.fromList([1, 2, 3]);
      await provider.put(path, bytes);
      await provider.put(path, bytes);
      await expectLater(
        provider.put(path, Uint8List.fromList([4])),
        throwsFormatException,
      );
      File(
        '${dir.path}/handy-habit/commits/interrupted.part',
      ).writeAsStringSync('partial', flush: true);
      expect(await provider.list('handy-habit/commits'), {'a-123.json'});
      expect(await provider.read(path), bytes);
      await expectLater(provider.read('../outside'), throwsFormatException);
    },
  );
  test(
    'two providers serialize same generation; conflicting cloud copies stop merge',
    () async {
      const path = 'handy-habit/commits/a-123.json';
      final other = FolderSyncProvider(dir.path);
      await Future.wait([
        provider.put(path, Uint8List.fromList([1])),
        other.put(path, Uint8List.fromList([1])),
      ]);
      File(
        '${dir.path}/handy-habit/commits/a-123 (conflict).json',
      ).writeAsStringSync('bad');
      await expectLater(
        provider.list('handy-habit/commits'),
        throwsFormatException,
      );
    },
  );
  test(
    'R15 folder generations converge, interrupted receipt retries without data loss',
    () async {
      final h = Habit(
        id: 'h',
        title: 'Read',
        created: '2024-01-01',
        schedules: [Schedule(id: 'g', from: '2024-01-01')],
      );
      final s = HabitState(habits: [h]);
      final a = recordChange(
        s,
        record(
          s,
          HabitEvent(id: 'e1', habit: 'h', day: '2024-01-08', value: 1000),
          today: '2024-01-08',
        ),
        actor: 'a',
      );
      final b = recordChange(
        s,
        record(
          s,
          HabitEvent(id: 'e2', habit: 'h', day: '2024-01-09', value: 1000),
          today: '2024-01-09',
        ),
        actor: 'b',
      );
      await syncHabitOnce(local: a, base: [], device: 'a', remote: provider);
      final first = await syncHabitOnce(
        local: b,
        base: [],
        device: 'b',
        remote: FolderSyncProvider(dir.path),
      );
      expect(first.state.events.map((e) => e.id).toSet(), {'e1', 'e2'});
      final again = await syncHabitOnce(
        local: first.state,
        base: first.base,
        device: 'b',
        remote: provider,
      );
      expect(again.state.events.length, 2);
    },
  );
}
