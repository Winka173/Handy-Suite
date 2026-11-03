import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';

const zone = 'Asia/Ho_Chi_Minh';

Account acc(String id, {String currency = 'VND', String type = 'bank'}) =>
    Account(
      id: id,
      name: id,
      currency: currency,
      type: type,
      opening: BigInt.from(10000000),
      asOf: '2024-01-01',
    );

Entry spend(
  String id,
  int amount, {
  String account = 'bank',
  String date = '2024-02-01',
  String payee = 'Lẩu',
  String kind = 'expense',
  String? category,
}) => Entry(
  id: id,
  account: account,
  kind: kind,
  amount: BigInt.from(kind == 'income' ? amount : -amount),
  when: localTimestamp(date, zone),
  payee: payee,
  category: category,
);

SpendState ledger({
  List<Entry> entries = const [],
  List<Bill> bills = const [],
  List<Person> people = const [],
  List<CostSplit> splits = const [],
}) => SpendState(
  accounts: [
    acc('bank'),
    acc('momo', type: 'wallet'),
  ],
  categories: [Category(id: 'food', name: 'Ăn uống')],
  entries: entries,
  bills: bills,
  people: people,
  splits: splits,
);

Uint8List jpeg([int size = 64]) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(size, 7)]);
Uint8List pdf() => Uint8List.fromList(ascii.encode('%PDF-1.7\n%test\n'));

void main() {
  group('schema 1 to 2', () {
    test('a schema 1 ledger loads, keeps entry JSON and import Undo', () {
      final v1 = SpendState(
        accounts: [acc('bank')],
        entries: [spend('a', 100)],
      );
      final preview = previewStatement(
        v1,
        csvParse('date,payee,amount\n2024-02-02,Grab,-50'),
        const StatementMapping(account: 'bank'),
        Uint8List(1),
      );
      final imported = preview.commit(v1, {2});
      final json = imported.toJson()
        ..['version'] = 1
        ..remove('receipts')
        ..remove('people')
        ..remove('splits')
        ..['profiles'] = [
          {
            'id': 'p1',
            'name': 'bank.csv',
            'headers': ['date', 'payee', 'amount'],
            'mapping': const StatementMapping(account: 'bank').toJson(),
          },
        ];
      final upgraded = SpendState.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(upgraded.toJson()['version'], 2);
      expect(upgraded.entries.first.toJson().containsKey('settles'), isFalse);
      expect(
        upgraded.profiles.single['signature'],
        headerSignature(['date', 'payee', 'amount']),
      );
      expect(upgraded.profiles.single['delimiter'], ',');
      // The batch hashes made under schema 1 still match.
      expect(undoImport(upgraded, preview.batchId).entries, hasLength(1));
      expect(
        () => SpendState.fromJson({...upgraded.toJson(), 'version': 3}),
        throwsFormatException,
      );
    });
  });

  group('receipts', () {
    test('the file signature decides the type, never the name', () {
      expect(receiptMime(jpeg()), 'image/jpeg');
      expect(
        receiptMime(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        'image/png',
      );
      expect(
        receiptMime(
          Uint8List.fromList([
            ...ascii.encode('RIFF'),
            0,
            0,
            0,
            0,
            ...ascii.encode('WEBP'),
          ]),
        ),
        'image/webp',
      );
      expect(receiptMime(pdf()), 'application/pdf');
      expect(
        () =>
            Receipt.of('a', 'bill.jpg', Uint8List.fromList(utf8.encode('hi'))),
        throwsFormatException,
      );
      expect(
        () => Receipt.of('a', 'big.jpg', jpeg(receiptFileLimit)),
        throwsFormatException,
      );
      final r = Receipt.of('a', r'C:\Users\x\..\bill.pdf', pdf());
      expect(r.name, 'bill.pdf');
      expect(r.sha, sha256.convert(pdf()).toString());
      expect(r.matches(pdf()), isTrue);
    });

    test('budgets: per transaction, total, and an existing entry', () {
      final s = ledger(entries: [spend('a', 100)]);
      expect(
        () => attachReceipts(s, [Receipt.of('missing', 'x.jpg', jpeg())]),
        throwsFormatException,
      );
      final ten = [
        for (var i = 0; i < 10; i++) Receipt.of('a', 'x.jpg', jpeg()),
      ];
      final full = attachReceipts(s, ten);
      expect(full.receipts, hasLength(10));
      expect(
        () => attachReceipts(full, [Receipt.of('a', 'x.jpg', jpeg())]),
        throwsFormatException,
      );
      final huge = [
        for (var i = 0; i < 6; i++)
          Receipt(
            id: 'r$i',
            entry: 'a',
            name: 'x.jpg',
            mime: 'image/jpeg',
            size: 9000000,
            sha: '0' * 64,
            added: '2024-02-01T00:00:00Z',
          ),
      ];
      expect(() => attachReceipts(s, huge), throwsFormatException);
    });

    test(
      'deleting a transaction takes its receipts; Undo is the old state',
      () {
        final s = attachReceipts(
          ledger(entries: [spend('a', 1), spend('b', 2)]),
          [Receipt.of('a', 'a.jpg', jpeg()), Receipt.of('b', 'b.pdf', pdf())],
        );
        final next = withoutEntries(s, {'a'});
        expect(next.entries.map((e) => e.id), ['b']);
        expect(next.receipts.map((r) => r.entry), ['b']);
      },
    );

    test('ZIP backup carries receipts; restore checks every one', () {
      final r1 = Receipt.of('a', 'a.jpg', jpeg()),
          r2 = Receipt.of('a', 'b.pdf', pdf());
      final s = attachReceipts(ledger(entries: [spend('a', 1)]), [r1, r2]);
      final files = {r1.id: jpeg(), r2.id: pdf()};
      expect(() => backup(s, receipts: {r1.id: jpeg()}), throwsFormatException);
      final zip = backup(s, receipts: files);
      final back = readBackup(zip);
      expect(back.state.toJson(), s.toJson());
      expect(back.receipts[r1.id], jpeg());
      expect(back.receipts[r2.id], pdf());

      Uint8List rebuild(void Function(Archive a) change) {
        final a = Archive();
        for (final f in ZipDecoder().decodeBytes(zip)) {
          a.addFile(ArchiveFile(f.name, f.size, f.content));
        }
        change(a);
        return Uint8List.fromList(ZipEncoder().encode(a));
      }

      // A damaged receipt, a missing one and an unlisted extra are refused.
      final damaged = Archive();
      for (final f in ZipDecoder().decodeBytes(zip)) {
        final bytes = f.name == 'receipts/${r1.id}'
            ? jpeg(65)
            : Uint8List.fromList(f.content);
        damaged.addFile(ArchiveFile(f.name, bytes.length, bytes));
      }
      expect(
        () => readBackup(Uint8List.fromList(ZipEncoder().encode(damaged))),
        throwsFormatException,
      );
      final missing = Archive();
      for (final f in ZipDecoder().decodeBytes(zip)) {
        if (f.name == 'receipts/${r2.id}') continue;
        missing.addFile(ArchiveFile(f.name, f.size, f.content));
      }
      expect(
        () => readBackup(Uint8List.fromList(ZipEncoder().encode(missing))),
        throwsFormatException,
      );
      expect(
        () => readBackup(
          rebuild(
            (a) => a.addFile(ArchiveFile('receipts/extra', 3, [1, 2, 3])),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => readBackup(
          rebuild((a) => a.addFile(ArchiveFile('../receipts/x', 3, [1, 2, 3]))),
        ),
        throwsFormatException,
      );
      // JSON holds the ledger only; a JSON naming receipts is refused.
      final json = backup(s, zip: false);
      expect(restore(json, zip: false).receipts, isEmpty);
      expect(
        () => readBackup(
          Uint8List.fromList(utf8.encode(jsonEncode(s.toJson()))),
          zip: false,
        ),
        throwsFormatException,
      );
    });

    test('a schema 1 ZIP (empty attachment list) still restores', () {
      final s = ledger(entries: [spend('a', 1)]);
      final data = Uint8List.fromList(
        utf8.encode(jsonEncode(s.toJson()..['version'] = 1)),
      );
      final manifest = utf8.encode(
        jsonEncode({
          'app': 'handy-spend',
          'version': 1,
          'files': {'data.json': sha256.convert(data).toString()},
          'attachments': <String>[],
        }),
      );
      final zip = ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
          ..addFile(ArchiveFile('data.json', data.length, data)),
      );
      expect(
        restore(Uint8List.fromList(zip)).entries.single.id,
        s.entries.single.id,
      );
    });

    test('import Undo is refused once a receipt is on an imported row', () {
      final base = ledger();
      final p = previewStatement(
        base,
        csvParse('date,payee,amount\n2024-02-02,Grab,-50'),
        const StatementMapping(account: 'bank'),
        Uint8List(1),
      );
      final imported = p.commit(base, {2});
      final withReceipt = attachReceipts(imported, [
        Receipt.of(imported.entries.single.id, 'g.jpg', jpeg()),
      ]);
      expect(() => undoImport(withReceipt, p.batchId), throwsFormatException);
    });
  });

  group('splits and IOUs', () {
    final hoa = Person(id: 'hoa', name: 'Hoa'),
        nam = Person(id: 'nam', name: 'Nam');

    test('allocation adds up exactly in minor units', () {
      expect(allocate(BigInt.from(100), [1, 1, 1]), [
        BigInt.from(34),
        BigInt.from(33),
        BigInt.from(33),
      ]);
      expect(allocate(BigInt.from(1000), [2, 1]), [
        BigInt.from(667),
        BigInt.from(333),
      ]);
      expect(allocate(BigInt.from(5), [0, 1]), [BigInt.zero, BigInt.from(5)]);
      expect(() => allocate(BigInt.from(5), [0, 0]), throwsFormatException);
      for (var total = 1; total < 200; total += 7) {
        final parts = allocate(BigInt.from(total), [3, 1, 2, 5]);
        expect(
          parts.fold(BigInt.zero, (BigInt n, v) => n + v),
          BigInt.from(total),
        );
      }
      expect(
        () => splitParts(BigInt.from(900), 'exact', [
          (me, 0, BigInt.from(300)),
          ('hoa', 0, BigInt.from(500)),
        ]),
        throwsFormatException,
      );
    });

    CostSplit dinner({String entry = 'lau'}) => CostSplit(
      id: 'x1',
      payer: me,
      currency: 'VND',
      date: '2024-02-01',
      name: 'Lẩu',
      method: 'equal',
      total: BigInt.from(900000),
      entry: entry,
      category: 'food',
      parts: splitParts(BigInt.from(900000), 'equal', [
        (me, 1, null),
        ('hoa', 1, null),
        ('nam', 1, null),
      ]),
    );

    test('a split must match its expense and name known people', () {
      expect(
        () => ledger(
          entries: [spend('lau', 800000, category: 'food')],
          people: [hoa, nam],
          splits: [dinner()],
        ).validate(),
        throwsFormatException,
      );
      expect(
        () => ledger(
          entries: [spend('lau', 900000, category: 'food')],
          people: [hoa],
          splits: [dinner()],
        ).validate(),
        throwsFormatException,
      );
    });

    test(
      'settling: partial, cross-account refund, never more than owed; Safe to Spend counts only what you owe',
      () {
        var s = ledger(
          entries: [spend('lau', 900000, category: 'food')],
          people: [hoa, nam],
          splits: [dinner()],
        );
        final x = s.splits.single;
        expect(owedByPerson(s), {
          'hoa': {'VND': BigInt.from(300000)},
          'nam': {'VND': BigInt.from(300000)},
        });
        final before = safeToSpend(s, '2024-02-01', '2024-02-29');
        // Hoa pays 100k back into MoMo: a refund across accounts.
        final part = settlement(
          s,
          x,
          'hoa',
          BigInt.from(100000),
          account: 'momo',
          date: '2024-02-03',
          payee: 'Hoa',
        );
        expect(part.kind, 'refund');
        s = s.copy({
          'entries': [...s.entries.map((e) => e.toJson()), part.toJson()],
        });
        expect(outstanding(s, x, 'hoa'), BigInt.from(200000));
        expect(
          report(s, '2024-02-01', '2024-03-01')['expense'],
          BigInt.from(800000),
        );
        expect(
          () => settlement(
            s,
            x,
            'hoa',
            BigInt.from(200001),
            account: 'bank',
            date: '2024-02-04',
          ),
          throwsFormatException,
        );
        final over = part.copy({'id': newId(), 'amount': '300000'});
        expect(
          () => s.copy({
            'entries': [...s.entries.map((e) => e.toJson()), over.toJson()],
          }),
          throwsFormatException,
        );
        // Money owed to you is not counted before it arrives.
        expect(before.owe, BigInt.zero);
        final lent = CostSplit(
          id: 'x2',
          payer: 'linh',
          currency: 'VND',
          date: '2024-02-05',
          name: 'Vé xem phim',
          method: 'exact',
          total: BigInt.from(240000),
          parts: splitParts(BigInt.from(240000), 'exact', [
            (me, 0, BigInt.from(120000)),
            ('linh', 0, BigInt.from(120000)),
          ]),
        );
        s = s.copy({
          'people': [
            ...s.people.map((p) => p.toJson()),
            Person(id: 'linh', name: 'Linh').toJson(),
          ],
          'splits': [...s.splits.map((x) => x.toJson()), lent.toJson()],
        });
        expect(iouTotals(s, 'VND'), (BigInt.from(500000), BigInt.from(120000)));
        final after = safeToSpend(s, '2024-02-06', '2024-02-29');
        expect(after.owe, BigInt.from(120000));
        expect(
          after.available,
          after.liquid +
              after.income -
              after.committed -
              after.reserves -
              after.buffer -
              after.owe,
        );
        final pay = settlement(
          s,
          lent,
          'linh',
          BigInt.from(120000),
          account: 'bank',
          date: '2024-02-06',
        );
        expect(pay.kind, 'expense');
        s = s.copy({
          'entries': [...s.entries.map((e) => e.toJson()), pay.toJson()],
        });
        expect(iouTotals(s, 'VND').$2, BigInt.zero);
        // The expense with a settlement cannot be deleted under it.
        expect(() => withoutEntries(s, {'lau'}), throwsFormatException);
      },
    );

    test('deleting an unsettled split expense removes the split with it', () {
      final s = ledger(
        entries: [spend('lau', 900000, category: 'food')],
        people: [hoa, nam],
        splits: [dinner()],
      );
      final next = withoutEntries(s, {'lau'});
      expect(next.splits, isEmpty);
      expect(next.people, hasLength(2));
    });
  });

  group('recurring suggestions', () {
    Entry monthly(
      String id,
      String date,
      int amount, {
      String payee = 'Spotify',
    }) => spend(id, amount, date: date, payee: payee, account: 'momo');

    test('three monthly payments within 10% become one suggestion', () {
      final s = ledger(
        entries: [
          monthly('a', '2024-01-10', 59000, payee: 'SPOTIFY 123456'),
          monthly('b', '2024-02-10', 59000, payee: 'Spotify 99'),
          monthly('c', '2024-03-11', 62000),
          monthly('d', '2024-03-12', 15000, payee: 'Phở'),
        ],
      );
      final found = recurringSuggestions(s, '2024-03-20');
      expect(found, hasLength(1));
      final g = found.single;
      expect(g.frequency, 'monthly');
      expect(g.count, 3);
      expect(g.amount, BigInt.from(-59000));
      expect(g.due, '2024-04-11');
      expect(g.varies, isTrue);
      expect(g.bill().amount, BigInt.from(-59000));
      // Dismissed stays dismissed; a recurring item with the name hides it.
      expect(
        recurringSuggestions(dismissSuggestion(s, g.key), '2024-03-20'),
        isEmpty,
      );
      final known = s.copy({
        'bills': [
          Bill(
            id: 'b',
            name: 'Spotify',
            account: 'momo',
            amount: BigInt.from(-59000),
            due: '2024-04-10',
          ).toJson(),
        ],
      });
      expect(recurringSuggestions(known, '2024-03-20'), isEmpty);
    });

    test(
      'two payments, unstable amounts, odd gaps or stale runs are not suggested',
      () {
        List<RecurringSuggestion> of(
          List<(String, int)> rows, [
          String today = '2024-03-20',
        ]) => recurringSuggestions(
          ledger(
            entries: [
              for (final (i, (d, a)) in rows.indexed) monthly('e$i', d, a),
            ],
          ),
          today,
        );
        expect(of([('2024-02-10', 59000), ('2024-03-10', 59000)]), isEmpty);
        expect(
          of([
            ('2024-01-10', 50000),
            ('2024-02-10', 59000),
            ('2024-03-10', 70000),
          ]),
          isEmpty,
        );
        expect(
          of([
            ('2024-01-10', 59000),
            ('2024-01-25', 59000),
            ('2024-03-10', 59000),
          ]),
          isEmpty,
        );
        expect(
          of([
            ('2024-01-10', 59000),
            ('2024-02-10', 59000),
            ('2024-03-10', 59000),
          ], '2024-06-01'),
          isEmpty,
        );
        final weekly = of([
          ('2024-03-01', 40000),
          ('2024-03-08', 40000),
          ('2024-03-15', 40000),
        ]);
        expect(weekly.single.frequency, 'weekly');
        expect(weekly.single.due, '2024-03-22');
      },
    );
  });

  group('statement templates', () {
    test('found by header signature; one per layout; columns checked', () {
      expect(
        headerSignature([' Date ', 'PAYEE', 'Amount']),
        headerSignature(['date', 'payee', 'amount']),
      );
      expect(
        headerSignature(['date', 'amount', 'payee']),
        isNot(headerSignature(['date', 'payee', 'amount'])),
      );
      final s = ledger();
      final headers = ['Ngày', 'Nội dung', 'Ghi nợ', 'Ghi có'];
      final t = statementTemplate(
        name: 'Sao kê thẻ',
        headers: headers,
        mapping: const StatementMapping(
          account: 'bank',
          amount: -1,
          debit: 2,
          credit: 3,
          dateFormat: 'dmy',
          decimal: ',',
          group: '.',
        ),
        delimiter: ';',
      );
      var next = saveTemplate(s, t);
      expect(templateFor(next, headers)!['name'], 'Sao kê thẻ');
      next = saveTemplate(next, {...t, 'id': 'other', 'name': 'Mới'});
      expect(next.profiles, hasLength(1));
      expect(next.profiles.single['name'], 'Mới');
      expect(
        () => statementTemplate(
          name: 'x',
          headers: ['a', 'b'],
          mapping: const StatementMapping(account: 'bank', amount: 5),
        ),
        throwsFormatException,
      );
    });
  });
}
