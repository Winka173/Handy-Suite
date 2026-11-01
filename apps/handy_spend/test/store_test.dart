import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_spend/data/store_native.dart';
import 'package:sqlite3/sqlite3.dart';

SpendState sample(int count) => SpendState(
  revision: 1,
  accounts: [
    Account(
      id: 'cash',
      name: 'Cash',
      currency: 'VND',
      opening: BigInt.from(1000000),
      asOf: '2024-01-01',
    ),
  ],
  entries: List.generate(
    count,
    (i) => Entry(
      id: 'e$i',
      account: 'cash',
      kind: 'expense',
      amount: -BigInt.one,
      when: '2024-02-01T00:00:00Z',
    ),
  ),
);
void main() {
  late Directory directory;
  late String path;
  late NativeSpendStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('handy-spend-test-');
    path = '${directory.path}/ledger.sqlite';
    store = NativeSpendStore(path);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test(
    'real killed writer leaves uncommitted WAL data invisible after recovery',
    () async {
      final original = sample(2);
      await store.commit(original, expectedRevision: 0);
      final writer = await Process.start('python', [
        '-u',
        '-c',
        r'''
import json, sqlite3, sys, time
db=sqlite3.connect(sys.argv[1])
db.execute('PRAGMA journal_mode=WAL')
db.execute('PRAGMA cache_size=1')
db.execute('PRAGMA cache_spill=ON')
db.execute('BEGIN IMMEDIATE')
db.execute('UPDATE state SET revision=999 WHERE id=1')
for i in range(2000):
    db.execute('INSERT INTO entries VALUES(?,?,?,?,?,?,?,?)',('uncommitted-'+str(i),'cash',None,'2024-02-01T00:00:00Z','expense','posted','-1',json.dumps({'uncommitted':True,'padding':'x'*512})))
print('UNCOMMITTED',flush=True)
while True: time.sleep(1)
''',
        path,
      ]);
      final diagnostic = writer.stderr.transform(utf8.decoder).join();
      try {
        expect(
          await writer.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .first
              .timeout(const Duration(seconds: 20)),
          'UNCOMMITTED',
        );
        expect(await File('$path-wal').length(), greaterThan(0));
        expect(writer.kill(ProcessSignal.sigkill), isTrue);
        expect(await writer.exitCode, isNot(0));
        expect(await diagnostic, isEmpty);
        expect(
          (await NativeSpendStore(path).read()).toJson(),
          original.toJson(),
        );
        expect(await store.integrity(), 'ok');
      } finally {
        writer.kill(ProcessSignal.sigkill);
        await writer.exitCode;
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
  test(
    'actual SQLite schema, reopen and exact metadata/BigInt roundtrip',
    () async {
      expect((await store.read()).revision, 0);
      final next = sample(5);
      await store.commit(next, expectedRevision: 0);
      expect((await NativeSpendStore(path).read()).toJson(), next.toJson());
      expect(await store.integrity(), 'ok');
      final db = sqlite3.open(path);
      try {
        expect(db.userVersion, 1);
        expect(db.select('SELECT COUNT(*) AS n FROM entries').single['n'], 5);
        expect(db.select('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        db.close();
      }
    },
  );
  test(
    'real mid-transaction SQLite failure rolls back whole batch and revision',
    () async {
      await store.read();
      final db = sqlite3.open(path);
      db.execute(
        "CREATE TRIGGER fail_entry BEFORE INSERT ON entries WHEN NEW.id='e1' BEGIN SELECT RAISE(ABORT,'test write failure'); END;",
      );
      db.close();
      await expectLater(
        store.commit(sample(3), expectedRevision: 0),
        throwsA(anything),
      );
      final actual = await store.read();
      expect(actual.entries, isEmpty);
      expect(actual.accounts, isEmpty);
      expect(actual.revision, 0);
      expect(await store.integrity(), 'ok');
    },
  );
  test(
    'concurrent connections refuse stale revision; no lost updates',
    () async {
      await store.read();
      await store.commit(sample(1), expectedRevision: 0);
      final before = await store.read();
      await store.commit(
        before.copy({
          'revision': 2,
          'settings': {'currency': 'USD'},
        }),
        expectedRevision: 1,
      );
      await expectLater(
        NativeSpendStore(path).commit(
          before.copy({
            'revision': 2,
            'settings': {'currency': 'EUR'},
          }),
          expectedRevision: 1,
        ),
        throwsStateError,
      );
      expect((await store.read()).currency, 'USD');
    },
  );
  test('unknown future schema and corrupt database are preserved', () async {
    final db = sqlite3.open(path);
    db.userVersion = 2;
    db.close();
    final before = await File(path).readAsBytes();
    await expectLater(store.read(), throwsA(anything));
    expect(await File(path).readAsBytes(), before);
    final corrupt = '${directory.path}/corrupt.sqlite';
    await File(corrupt).writeAsString('not sqlite');
    await expectLater(NativeSpendStore(corrupt).read(), throwsA(anything));
    expect(await File(corrupt).readAsString(), 'not sqlite');
  });
  test(
    '1k, 10k and 100k native records: actual write/read/integrity',
    () async {
      var revision = 0;
      for (final count in [1000, 10000, 100000]) {
        final watch = Stopwatch()..start(),
            next = sample(count).copy({'revision': revision + 1});
        await store.commit(next, expectedRevision: revision);
        final writeMs = watch.elapsedMilliseconds;
        watch.reset();
        final actual = await store.read();
        final readMs = watch.elapsedMilliseconds;
        expect(actual.entries, hasLength(count));
        expect(actual.revision, ++revision);
        expect(
          balances(actual, '2024-02-01')['cash'],
          BigInt.from(1000000 - count),
        );
        expect(await store.integrity(), 'ok');
        // Native SQLite test VM measurements are not UI/frame/browser guarantees.
        // ignore: avoid_print -- Explicit benchmark, counts/timings only.
        print(
          'Spend native SQLite count=$count writeMs=$writeMs readMs=$readMs',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
