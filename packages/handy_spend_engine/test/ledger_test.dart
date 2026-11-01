import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';

Account account(
  String id, {
  String currency = 'VND',
  String type = 'bank',
  int opening = 100000,
}) => Account(
  id: id,
  name: id,
  currency: currency,
  type: type,
  opening: BigInt.from(opening),
  asOf: '2024-01-01',
);
Entry expense(
  String id,
  int amount, {
  String account = 'cash',
  String date = '2024-02-01',
  String? occurrence,
  String? batch,
}) => Entry(
  id: id,
  account: account,
  kind: 'expense',
  amount: -BigInt.from(amount),
  when: localTimestamp(date, 'Asia/Ho_Chi_Minh'),
  payee: 'Cafe',
  occurrence: occurrence,
  batch: batch,
);
SpendState library({
  List<Entry> entries = const [],
  List<Bill> bills = const [],
  List<Goal> goals = const [],
}) => SpendState(
  accounts: [
    account('cash'),
    account('card', type: 'credit', opening: 0),
  ],
  entries: entries,
  bills: bills,
  goals: goals,
);

void main() {
  test('saved account selection is honored by sandbox and archived/debt accounts stay excluded',(){
    final original=library(),s=original.copy({'settings':{'eligibleAccounts':['card']}});expect(eligible(s,'VND'),isEmpty);expect(forecast(s,'2024-02-01','2024-02-02').opening,BigInt.zero);
    final renamed=original.copy({'revision':1,'audit':[{'id':'audit'}]});expect(financialFingerprint(renamed),financialFingerprint(original));expect(financialFingerprint(original.copy({'entries':[expense('changed',5).toJson()]})),isNot(financialFingerprint(original)));
  });
  test(
    'statement closing balance reconciles; liability credits require manual classification',
    () {
      final s = SpendState(
            accounts: [
              account('cash', opening: 100000),
              account('card', type: 'credit', opening: -1000),
            ],
          ),
          rows = [
            ['date', 'payee', 'amount', 'balance'],
            ['2024-02-01', 'Payment', '1000', '0'],
          ],
          p = previewStatement(
            s,
            rows,
            const StatementMapping(account: 'card', balance: 3),
            Uint8List(0),
          );
      expect(p.rows.single.status, 'needs classification');
      expect(() => p.commit(s, {2}), throwsFormatException);
      final entry = p.rows.single.entry!.copy({
            'kind': 'transfer',
            'account': 'cash',
            'toAccount': 'card',
            'amount': '-1000',
            'target': '1000',
          }),
          reviewed = StatementPreview(
            p.fileHash,
            p.batchId,
            [StatementRow(2, entry, 'reviewed')],
            statementAccount: p.statementAccount,
            balanceAt: p.balanceAt,
            closingBalance: p.closingBalance,
          ),
          next = reviewed.commit(s, {2});
      expect(
        next.imports.single['reconciliation'],
        containsPair('difference', '0'),
      );
      expect(report(next, '2024-02-01', '2024-03-01')['income'], BigInt.zero);
      expect(balances(next, '2024-02-01')['card'], BigInt.zero);
    },
  );
  test(
    'strict timestamps and amount grouping reject normalization surprises',
    () {
      for (final value in [
        '2024-02-30T00:00:00Z',
        '2024-01-01T25:00:00Z',
        '2024-01-01T00:00:00+25:00',
        '2024-01-01 12:00:00',
      ]) {
        expect(() => timestamp(value), throwsFormatException);
      }
      final s = library(),
          rows = [
            ['date', 'payee', 'amount'],
            ['2024-02-01T23:30:00+07:00', 'Cafe', '-1,234'],
            ['2024-02-01', 'Bad', '-12,34'],
          ];
      final p = previewStatement(
        s,
        rows,
        const StatementMapping(account: 'cash'),
        Uint8List(0),
      );
      expect(p.rows.first.entry!.when, '2024-02-01T16:30:00.000Z');
      expect(p.rows.last.status, 'error');
    },
  );
  test(
    'old weekly anchor is fast-forwarded without losing current occurrences',
    () {
      final s = library(
        bills: [
          Bill(
            id: 'old',
            name: 'Old',
            account: 'cash',
            amount: -BigInt.one,
            due: '1500-01-01',
            frequency: 'weekly',
          ),
        ],
      );
      expect(
        upcoming(
          s,
          '2024-02-01',
          '2024-02-29',
        ).where((o) => o.date.compareTo('2024-02-01') >= 0).length,
        inInclusiveRange(4, 5),
      );
    },
  );
  test('exact variable precision and huge amounts never use doubles', () {
    for (final c in scales.keys) {
      final text = scale(c) == 0
          ? '9007199254740993'
          : '9007199254740993.${'1'.padRight(scale(c), '0')}';
      expect(decimalMoney(minor(text, c), c), text);
    }
    expect(() => minor('1.01', 'VND'), throwsFormatException);
    expect(() => minor('1e6', 'USD'), throwsFormatException);
    expect(() => minor('NaN', 'VND'), throwsFormatException);
    expect(() => minor('1,000', 'USD'), throwsFormatException);
    expect(
      convert(minor('1.01', 'USD'), 'USD', 'VND', '25000'),
      BigInt.from(25250),
    );
    expect(convert(BigInt.one, 'USD', 'VND', '50'), BigInt.one);
    expect(roundedRatio(BigInt.from(-5), BigInt.two), BigInt.from(-3));
  });
  test('credit expense, repayment and refund are not counted twice', () {
    final buy = expense('purchase', 1000, account: 'card'),
        pay = Entry(
          id: 'payment',
          account: 'cash',
          kind: 'transfer',
          amount: BigInt.from(-400),
          toAccount: 'card',
          target: BigInt.from(400),
          when: buy.when,
        ),
        refund = Entry(
          id: 'refund',
          account: 'card',
          kind: 'refund',
          refundOf: buy.id,
          amount: BigInt.from(200),
          when: buy.when,
        );
    final s = library(entries: [buy, pay, refund]);
    s.validate();
    expect(balances(s, '2024-02-01')['card'], BigInt.from(-400));
    expect(balances(s, '2024-02-01')['cash'], BigInt.from(99600));
    final r = report(s, '2024-02-01', '2024-03-01');
    expect(r['expense'], BigInt.from(800));
    expect(r['income'], BigInt.zero);
    expect(
      () => s.copy({
        'entries': [
          buy.toJson(),
          refund.copy({'amount': '1001'}).toJson(),
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => s.copy({
        'entries': [
          pay.copy({'target': '401'}).toJson(),
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => s.copy({
        'entries': [refund.toJson()],
      }),
      throwsFormatException,
    );
  });
  test('cross-currency atomic transfer has explicit rounded rate and fee', () {
    final e = Entry(
          id: 'fx',
          account: 'usd',
          kind: 'transfer',
          amount: BigInt.from(-101),
          fee: BigInt.from(2),
          toAccount: 'vnd',
          target: BigInt.from(25250),
          rate: '25000',
          when: '2024-02-01T00:00:00Z',
        ),
        s = SpendState(
          accounts: [
            account('usd', currency: 'USD', opening: 1000),
            account('vnd', opening: 0),
          ],
          entries: [e],
          settings: {'currency': 'USD'},
        );
    s.validate();
    expect(balances(s, '2024-02-02')['usd'], BigInt.from(897));
    expect(balances(s, '2024-02-02')['vnd'], BigInt.from(25250));
    expect(report(s, '2024-02-01', '2024-03-01')['expense'], BigInt.two);
    expect(
      () => s.copy({
        'entries': [
          e.copy({'rate': null}).toJson(),
        ],
      }),
      throwsFormatException,
    );
  });
  test(
    'opening balances and corrections are not income; pending is separate',
    () {
      final e = Entry(
            id: 'fix',
            account: 'cash',
            kind: 'adjustment',
            amount: BigInt.from(-5),
            when: '2024-02-01T00:00:00Z',
          ),
          pending = expense('later', 20).copy({'status': 'pending'}),
          s = library(entries: [e, pending]);
      s.validate();
      expect(balances(s, '2024-02-01')['cash'], BigInt.from(99995));
      expect(report(s, '2024-02-01', '2024-03-01')['income'], BigInt.zero);
      expect(report(s, '2024-02-01', '2024-03-01')['expense'], BigInt.zero);
      expect(
        () => s.copy({
          'entries': [expense('bad', 1, date: '2023-12-31').toJson()],
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'safe spend deducts commitments, goal reserves and buffer exactly once',
    () {
      final bills = [
            Bill(
              id: 'rent',
              name: 'Rent',
              account: 'cash',
              amount: BigInt.from(-30000),
              due: '2024-02-10',
              frequency: 'once',
            ),
            Bill(
              id: 'salary',
              name: 'Salary',
              account: 'cash',
              amount: BigInt.from(50000),
              due: '2024-02-11',
              frequency: 'once',
              reliable: true,
            ),
          ],
          goals = [
            Goal(
              id: 'goal',
              name: 'Reserve',
              account: 'cash',
              due: '2024-03-01',
              target: BigInt.from(50000),
              reserved: BigInt.from(20000),
            ),
          ],
          s = library(bills: bills, goals: goals);
      final safe = safeToSpend(
        s,
        '2024-02-01',
        '2024-02-29',
        buffer: BigInt.from(10000),
      );
      expect(safe.available, BigInt.from(40000));
      expect(safe.days, 29);
      expect(safe.perDay, BigInt.from(1379));
      expect(
        safeToSpend(
          s,
          '2024-02-01',
          '2024-02-29',
          conservative: false,
        ).available,
        BigInt.from(100000),
      );
      final paid = s.copy({
        'entries': [
          upcoming(s, '2024-02-01', '2024-02-29').first.post(s.zone).toJson(),
        ],
      });
      expect(
        safeToSpend(
          paid,
          '2024-02-10',
          '2024-02-29',
          buffer: BigInt.from(10000),
        ).available,
        BigInt.from(40000),
      );
    },
  );
  test(
    'forecast identifies first shortfall and late income does not hide minimum',
    () {
      final s = library(
            bills: [
              Bill(
                id: 'rent',
                name: 'Rent',
                account: 'cash',
                amount: BigInt.from(-120000),
                due: '2024-02-02',
                frequency: 'once',
              ),
              Bill(
                id: 'income',
                name: 'Income',
                account: 'cash',
                amount: BigInt.from(50000),
                due: '2024-02-05',
                frequency: 'once',
                reliable: true,
              ),
            ],
          ),
          p = forecast(s, '2024-02-01', '2024-02-29', includeIncome: true);
      expect(p.shortfall, '2024-02-02');
      expect(p.lowest, BigInt.from(-20000));
      expect(p.ending, BigInt.from(30000));
      final safe = safeToSpend(s, '2024-02-01', '2024-02-29');
      expect(safe.shortfall, BigInt.from(20000));
      expect(safe.perDay, BigInt.zero);
    },
  );
  test(
    'month-end and leap anchors resume 31st; schedules do not post actuals',
    () {
      final s = library(
        bills: [
          Bill(
            id: 'monthly',
            name: 'Bill',
            account: 'cash',
            amount: BigInt.from(-10),
            due: '2024-01-31',
          ),
        ],
      );
      final before = jsonEncode(s.toJson()),
          dates = upcoming(
            s,
            '2024-01-01',
            '2024-04-30',
          ).map((o) => o.date).toList();
      expect(dates, ['2024-01-31', '2024-02-29', '2024-03-31', '2024-04-30']);
      forecast(s, '2024-02-01', '2024-02-29');
      expect(jsonEncode(s.toJson()), before);
    },
  );
  test(
    'timezone reporting and DST count calendar days not 24-hour periods',
    () {
      expect(
        reportDay('2024-03-01T00:30:00Z', 'America/New_York'),
        '2024-02-29',
      );
      final s = library().copy({
        'settings': {'currency': 'VND', 'zone': 'America/New_York'},
      });
      expect(forecast(s, '2024-03-09', '2024-03-11').points.length, 3);
      expect(
        reportDay(localTimestamp('2024-03-10', s.zone), s.zone),
        '2024-03-10',
      );
      expect(() => calendar('2023-02-29'), throwsFormatException);
    },
  );
  test(
    'installment split reconciles exactly and scenario baseline is deeply immutable',
    () {
      final s = library(),
          before = jsonEncode(s.toJson()),
          staged = purchasePlan(
            account: 'cash',
            cost: BigInt.from(100),
            date: '2024-01-31',
            zone: s.zone,
            installments: 3,
          ),
          scenario = Scenario(
            id: 'case',
            name: 'Case',
            asOf: '2024-02-01',
            baseline: s.toJson(),
            staged: staged,
          );
      expect(
        staged.fold(BigInt.zero, (BigInt n, e) => n - e.amount),
        BigInt.from(100),
      );
      expect(staged.map((e) => reportDay(e.when, s.zone)), [
        '2024-01-31',
        '2024-02-29',
        '2024-03-31',
      ]);
      expect(
        () =>
            ((scenario.baseline['accounts'] as List).first as Map)['opening'] =
                '0',
        throwsUnsupportedError,
      );
      expect(() => s.settings['x'] = 1, throwsUnsupportedError);
      forecast(s, '2024-02-01', '2024-03-31', staged: staged);
      expect(jsonEncode(s.toJson()), before);
    },
  );
  test(
    'future schema, duplicate IDs, bad category cycle and refund totals refuse',
    () {
      final s = library();
      expect(
        () => SpendState.fromJson({...s.toJson(), 'version': 2}),
        throwsFormatException,
      );
      expect(
        () => s.copy({
          'accounts': [account('cash').toJson(), account('cash').toJson()],
        }),
        throwsFormatException,
      );
      expect(
        () => s.copy({
          'categories': [
            Category(id: 'a', name: 'A', parent: 'b').toJson(),
            Category(id: 'b', name: 'B', parent: 'a').toJson(),
          ],
        }),
        throwsFormatException,
      );
    },
  );
  final state = library(entries: [expense('one', 100)]).copy({
    'categories': [Category(id: 'food', name: 'Food').toJson()],
    'settings': {
      'currency': 'VND',
      'zone': 'Asia/Ho_Chi_Minh',
      'eligibleAccounts': ['cash'],
    },
  });
  for (final zip in [false, true])
    test(
      'full ${zip ? 'ZIP' : 'JSON'} backup roundtrip and corrupted refusal',
      () {
        final bytes = backup(state, zip: zip);
        expect(restore(bytes, zip: zip).toJson(), state.toJson());
        expect(
          () => restore(Uint8List.fromList([1, 2, 3]), zip: zip),
          throwsA(anything),
        );
      },
    );
  for (final xlsx in [false, true])
    test(
      '${xlsx ? 'XLSX' : 'CSV'} transaction roundtrip preserves IDs, precision, Unicode and formula safety',
      () {
        final s = library(
              entries: [
                expense('unicode', 100).copy({
                  'payee': '=HYPERLINK("bad")',
                  'note': 'Tiếng Việt\n"quoted"',
                  'tags': ['food', 'cafe'],
                }),
              ],
            ),
            rows = transactionRows(s, s.entries),
            encoded = xlsx
                ? xlsxEncode(rows)
                : Uint8List.fromList(utf8.encode(csvEncode(rows))),
            decoded = xlsx
                ? xlsxParse(encoded)
                : csvParse(utf8.decode(encoded));
        expect(decoded, rows);
        expect(decoded[1][1], startsWith("'="));
        expect(
          readTransactionRows(s, decoded).single.toJson(),
          s.entries.single.toJson(),
        );
      },
    );
  test(
    'statement mapping, duplicate/reversal review, explicit partial and safe batch Undo',
    () {
      final s = library(),
          rows = csvParse(
            'date,payee,amount\n2024-02-01,Cafe,-100\n2024-02-01,Cafe,-100\n2024-02-01,Cafe,100\n2024-02-30,Bad,20',
          ),
          preview = previewStatement(
            s,
            rows,
            const StatementMapping(account: 'cash'),
            Uint8List.fromList([1]),
          );
      expect(preview.rows.map((r) => r.status), [
        'new',
        'duplicate',
        'possible reversal',
        'error',
      ]);
      expect(() => preview.commit(s, {2}), throwsFormatException);
      final imported = preview.commit(s, {2}, allowPartial: true);
      expect(imported.entries, hasLength(1));
      expect(undoImport(imported, preview.batchId).entries, isEmpty);
      final changed = imported.copy({
        'entries': [
          imported.entries.single.copy({'note': 'edited'}).toJson(),
        ],
      });
      expect(() => undoImport(changed, preview.batchId), throwsFormatException);
    },
  );
  test(
    'semicolon decimal comma, debit/credit, BOM and multiline Vietnamese parse',
    () {
      final rows = csvParse(
            '\ufeffdate;description;debit;credit\r\n29/02/2024;"Ăn uống\nCà phê";"1.234,50";\r\n',
            delimiter: ';',
          ),
          s = SpendState(accounts: [account('eur', currency: 'EUR')]),
          p = previewStatement(
            s,
            rows,
            const StatementMapping(
              account: 'eur',
              amount: -1,
              debit: 2,
              credit: 3,
              dateFormat: 'dmy',
              decimal: ',',
              group: '.',
            ),
            Uint8List(0),
          );
      expect(p.rows.single.entry!.amount, BigInt.from(-123450));
      expect(p.rows.single.entry!.payee, contains('\n'));
      expect(() => csvParse('a,b\n"unterminated'), throwsFormatException);
    },
  );
  test('ZIP traversal and spreadsheet formulas/external entities refused', () {
    final archive = Archive()
      ..addFile(ArchiveFile('../data.json', 2, utf8.encode('{}')));
    expect(
      () => restore(Uint8List.fromList(ZipEncoder().encode(archive))),
      throwsFormatException,
    );
    final original = xlsxEncode([
          ['date', 'payee', 'amount'],
          ['2024-02-01', 'Cafe', '-1'],
        ]),
        decoded = ZipDecoder().decodeBytes(original),
        mutated = Archive();
    for (final f in decoded) {
      var bytes = f.content;
      if (f.name == 'xl/worksheets/sheet1.xml')
        bytes = utf8.encode(
          utf8.decode(bytes).replaceFirst('<is>', '<f>1+1</f><is>'),
        );
      mutated.addFile(ArchiveFile(f.name, bytes.length, bytes));
    }
    expect(
      () => xlsxParse(Uint8List.fromList(ZipEncoder().encode(mutated))),
      throwsFormatException,
    );
  });
}
