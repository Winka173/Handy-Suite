import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_spend/people/people_logic.dart';
import 'package:handy_spend/people/split_logic.dart';
import 'package:handy_spend/receipts/receipt_logic.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

TestSpendStore seeded(SpendState s) => TestSpendStore()..value = s;
Uint8List jpeg([int n = 32]) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(n, 9)]);

Entry lunch({String id = 'lunch', int amount = 900000, String? payee}) => Entry(
  id: id,
  account: 'cash',
  kind: 'expense',
  amount: BigInt.from(-amount),
  when: localTimestamp(today(), 'Asia/Ho_Chi_Minh'),
  payee: payee ?? 'Lẩu Thái',
);

void main() {
  group('receipts', () {
    test('picked files are checked as a whole against every limit', () {
      final s = SpendState(accounts: [cash()], entries: [lunch()]);
      expect(
        () => checkReceipts(s, 'lunch', [
          ImportedBytes('fake.jpg', Uint8List.fromList(utf8.encode('hello'))),
        ]),
        throwsFormatException,
      );
      final ok = checkReceipts(s, 'lunch', [
        for (var i = 0; i < 10; i++) ImportedBytes('r$i.jpg', jpeg()),
      ]);
      expect(ok, hasLength(10));
      expect(
        () => checkReceipts(s, 'lunch', [
          ImportedBytes('more.jpg', jpeg()),
        ], waiting: ok),
        throwsFormatException,
      );
    });

    testWidgets(
      'attach on Save, a mark on the ledger row, open, remove with Undo; deleting the entry takes them along',
      (tester) async {
        final files = Files()..next = ImportedBytes('bill.jpg', jpeg());
        final store = seeded(
          SpendState(accounts: [cash()], entries: [lunch()]),
        );
        final c = await start(tester, store: store, files: files);
        await tapKey(tester, 'nav-1');
        await tapKey(tester, 'entry-lunch');
        await tapKey(tester, 'receipt-add');
        // Waiting in the sheet; Cancel would drop it.
        expect(c.state!.receipts, isEmpty);
        await tapKey(tester, 'editor-save');
        final r = c.state!.receipts.single;
        expect(r.entry, 'lunch');
        expect(r.mime, 'image/jpeg');
        expect(store.files[r.id], jpeg());
        // The ledger row says so with an icon and a count.
        expect(find.byIcon(Icons.attach_file), findsWidgets);

        await tapKey(tester, 'entry-lunch');
        await tapKey(tester, 'receipt-${r.id}');
        expect(find.byKey(const Key('receipt-zoom')), findsOneWidget);
        await tapKey(tester, 'receipt-delete');
        expect(c.state!.receipts, isEmpty);
        await tester.tap(find.byKey(const Key('snack-undo')));
        await tester.pumpAndSettle();
        expect(c.state!.receipts.single.id, r.id);

        // A file that only claims to be a photo is refused; nothing saved.
        await tapKey(tester, 'sheet-cancel');
        files.next = ImportedBytes(
          'fake.jpg',
          Uint8List.fromList(utf8.encode('x')),
        );
        await tapKey(tester, 'entry-lunch');
        await tapKey(tester, 'receipt-add');
        expect(find.byKey(const Key('sheet-error')), findsOneWidget);
        await tapKey(tester, 'sheet-cancel');
        expect(c.state!.receipts, hasLength(1));

        // Deleting the transaction removes its receipt in the same change.
        await tapKey(tester, 'entry-lunch');
        await tapKey(tester, 'more-menu');
        await tapKey(tester, 'entry-delete');
        await tapKey(tester, 'confirm-action');
        expect(c.state!.entries, isEmpty);
        expect(c.state!.receipts, isEmpty);
        await tester.tap(find.byKey(const Key('snack-undo')));
        await tester.pumpAndSettle();
        expect(c.state!.receipts.single.id, r.id);
        // The file stays until the next start sweeps unlisted ones.
        expect(store.files.containsKey(r.id), isTrue);
      },
    );

    testWidgets('ZIP backup carries receipt files and restores them', (
      tester,
    ) async {
      final r = Receipt.of('lunch', 'bill.jpg', jpeg());
      final store = seeded(
        attachReceipts(SpendState(accounts: [cash()], entries: [lunch()]), [r]),
      )..files[r.id] = jpeg();
      final files = Files();
      final c = await start(tester, store: store, files: files);
      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'spend-backup');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await settleReal(tester, () => files.output.containsKey('zip'));
      final back = readBackup(files.output['zip']!);
      expect(back.state.toJson(), c.state!.toJson());
      expect(back.receipts[r.id], jpeg());

      // Restore into an empty ledger brings the files with it.
      store.files.clear();
      files.next = ImportedBytes('backup.zip', files.output['zip']!);
      await tapKey(tester, 'spend-restore');
      await settleReal(
        tester,
        () => find.byKey(const Key('confirm-action')).evaluate().isNotEmpty,
      );
      await tapKey(tester, 'confirm-action');
      await tapKey(tester, 'confirm-action');
      await settleReal(tester, () => store.files.containsKey(r.id));
      expect(store.files[r.id], jpeg());
      expect(c.state!.receipts.single.id, r.id);
    });
  });

  group('split and IOU', () {
    test('the draft divides exactly and builds a valid split', () {
      const d = SplitDraft(
        lines: [SplitLine(me), SplitLine('hoa'), SplitLine('nam')],
      );
      expect(d.parts(BigInt.from(100)).map((p) => p.amount), [
        BigInt.from(34),
        BigInt.from(33),
        BigInt.from(33),
      ]);
      final exact = SplitDraft(
        method: 'exact',
        lines: [
          SplitLine(me, amount: BigInt.from(500)),
          SplitLine('hoa', amount: BigInt.from(400)),
        ],
      );
      expect(exact.gap(BigInt.from(1000)), BigInt.from(-100));
      expect(() => exact.parts(BigInt.from(1000)), throwsFormatException);
    });

    testWidgets(
      'split while recording, settle part of it into the account chosen, owed shown on Today',
      (tester) async {
        final c = await start(
          tester,
          store: seeded(
            SpendState(
              accounts: [
                cash(opening: 5000000),
                cash(id: 'momo', opening: 0),
              ],
            ),
          ),
        );
        await tapKey(tester, 'spend-add');
        await typeKey(tester, 'field-amount', '900.000');
        await typeKey(tester, 'field-payee', 'Lẩu');
        await tapKey(tester, 'entry-split');
        for (final name in ['Hoa', 'Nam']) {
          await typeKey(tester, 'split-new-person', name);
          await tapKey(tester, 'split-add-person');
        }
        expect(find.textContaining('Adds up to'), findsOneWidget);
        await tapKey(tester, 'split-done');
        await tapKey(tester, 'editor-save');
        final x = c.state!.splits.single;
        expect(x.parts.map((p) => p.amount).toSet(), {BigInt.from(300000)});
        expect(c.state!.people.map((p) => p.name), ['Hoa', 'Nam']);
        expect(iouTotals(c.state!, 'VND'), (BigInt.from(600000), BigInt.zero));
        // Owed to you is not free to spend yet; Today says it once.
        expect(find.byKey(const Key('today-owed')), findsOneWidget);

        final hoa = c.state!.people.first;
        await tapKey(tester, 'today-owed');
        await tapKey(tester, 'person-${hoa.id}');
        await tapKey(tester, 'person-settle');
        await typeKey(tester, 'field-amount', '100000');
        // No account is picked for the person.
        await tapKey(tester, 'editor-save');
        expect(find.byKey(const Key('sheet-error')), findsOneWidget);
        await tapKey(tester, 'field-account-momo');
        await tapKey(tester, 'editor-save');
        final paid = c.state!.entries.firstWhere((e) => e.settles == x.id);
        expect(paid.kind, 'refund');
        expect(paid.account, 'momo');
        expect(paid.amount, BigInt.from(100000));
        expect(outstanding(c.state!, x, hoa.id), BigInt.from(200000));
      },
    );

    testWidgets('exact amounts that do not add up are refused', (tester) async {
      final c = await start(
        tester,
        store: seeded(SpendState(accounts: [cash()], entries: [lunch()])),
      );
      await tapKey(tester, 'nav-1');
      await tapKey(tester, 'entry-lunch');
      await tapKey(tester, 'entry-split');
      await typeKey(tester, 'split-new-person', 'Hoa');
      await tapKey(tester, 'split-add-person');
      await tester.tap(find.text('Exact'));
      await tester.pumpAndSettle();
      await typeKey(tester, 'split-amount-me', '500000');
      expect(find.textContaining('over the total'), findsOneWidget);
      await tapKey(tester, 'split-done');
      expect(find.byKey(const Key('sheet-error')), findsOneWidget);
      await tapKey(tester, 'sheet-cancel');
      await tapKey(tester, 'sheet-cancel');
      expect(c.state!.splits, isEmpty);
    });

    test('settling both ways closes each side; a part needs one side', () {
      final s0 = SpendState(
        accounts: [cash(opening: 5000000)],
        entries: [lunch()],
        people: [Person(id: 'hoa', name: 'Hoa')],
      );
      final mine = CostSplit(
        id: 'a',
        payer: me,
        currency: 'VND',
        date: today(),
        name: 'Lẩu',
        method: 'equal',
        total: BigInt.from(900000),
        entry: 'lunch',
        parts: splitParts(BigInt.from(900000), 'equal', [
          (me, 1, null),
          ('hoa', 1, null),
        ]),
      );
      final theirs = CostSplit(
        id: 'b',
        payer: 'hoa',
        currency: 'VND',
        date: today(),
        name: 'Vé',
        method: 'exact',
        total: BigInt.from(200000),
        parts: splitParts(BigInt.from(200000), 'exact', [
          (me, 0, BigInt.from(100000)),
          ('hoa', 0, BigInt.from(100000)),
        ]),
      );
      final s = s0.copy({
        'splits': [mine.toJson(), theirs.toJson()],
      });
      expect(
        () => settleUp(
          s,
          'hoa',
          'VND',
          BigInt.from(100000),
          account: 'cash',
          date: today(),
          payee: (_) => 'Hoa',
        ),
        throwsFormatException,
      );
      final all = settleUp(
        s,
        'hoa',
        'VND',
        BigInt.from(350000),
        account: 'cash',
        date: today(),
        payee: (_) => 'Hoa',
      );
      final after = s.copy({
        'entries': [
          ...s.entries.map((e) => e.toJson()),
          ...all.map((e) => e.toJson()),
        ],
      });
      expect(owedByPerson(after), isEmpty);
      expect(
        balances(after, today())['cash']! - balances(s, today())['cash']!,
        BigInt.from(350000),
      );
    });
  });

  testWidgets(
    'a repeating payment is suggested in Plan; Add makes it recurring, Not recurring hides it',
    (tester) async {
      Entry sub(String id, int monthsAgo, String payee) {
        final now = calendar(today());
        final d = DateTime.utc(now.year, now.month - monthsAgo, 3);
        return Entry(
          id: id,
          account: 'cash',
          kind: 'expense',
          amount: BigInt.from(-59000),
          when: localTimestamp(day(d), 'Asia/Ho_Chi_Minh'),
          payee: payee,
        );
      }

      final c = await start(
        tester,
        store: seeded(
          SpendState(
            accounts: [cash(since: 120)],
            entries: [
              for (final (i, m) in [1, 2, 3].indexed) sub('s$i', m, 'Spotify'),
              for (final (i, m) in [1, 2, 3].indexed) sub('g$i', m, 'Gym'),
            ],
          ),
        ),
      );
      final found = recurringSuggestions(c.state!, today());
      expect(found.map((g) => g.name).toSet(), {'Spotify', 'Gym'});
      await tapKey(tester, 'nav-2');
      final spotify = found.firstWhere((g) => g.name == 'Spotify');
      await tapKey(tester, 'suggest-add-${spotify.key}');
      await tapKey(tester, 'editor-save');
      expect(c.state!.bills.single.name, 'Spotify');
      expect(c.state!.bills.single.amount, BigInt.from(-59000));
      final gym = found.firstWhere((g) => g.name == 'Gym');
      await tapKey(tester, 'suggest-dismiss-${gym.key}');
      expect(recurringSuggestions(c.state!, today()), isEmpty);
      expect(find.byKey(Key('suggest-${gym.key}')), findsNothing);
    },
  );

  testWidgets(
    'a saved template fills the mapping for the same headers, and can be set aside',
    (tester) async {
      final headers = ['Ngày', 'Nội dung', 'Số tiền'];
      final t = statementTemplate(
        name: 'Thẻ VCB',
        headers: headers,
        mapping: const StatementMapping(
          account: 'cash',
          dateFormat: 'dmy',
          decimal: ',',
          group: '.',
        ),
        delimiter: ';',
      );
      final files = Files()
        ..next = ImportedBytes(
          'saoke.csv',
          Uint8List.fromList(
            utf8.encode(
              'Ngày;Nội dung;Số tiền\n${_dmy(today())};Cà phê;-45.000\n',
            ),
          ),
        );
      final c = await start(
        tester,
        files: files,
        store: seeded(saveTemplate(SpendState(accounts: [cash(since: 5)]), t)),
      );
      await tapKey(tester, 'nav-1');
      await tapKey(tester, 'more-menu');
      await tapKey(tester, 'ledger-import');
      await tester.tap(find.byKey(const Key('import-pick')));
      await settleReal(
        tester,
        () =>
            find.byKey(const Key('import-validate')).evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(find.textContaining('Thẻ VCB'), findsWidgets);
      await tester.tap(find.byKey(const Key('import-validate')));
      await settleReal(
        tester,
        () =>
            find.byKey(const Key('import-counts')).evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(find.textContaining('1 new'), findsOneWidget);
      await tapKey(tester, 'import-commit');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await settleReal(
        tester,
        () =>
            find.byKey(const Key('import-done')).evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(c.state!.entries.single.amount, BigInt.from(-45000));

      // Settings lists it; deleting it has Undo.
      await tapKey(tester, 'import-done');
      await tapKey(tester, 'nav-0');
      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'spend-templates');
      await tapKey(tester, 'more-menu');
      await tapKey(tester, 'template-delete-${t['id']}');
      expect(c.state!.profiles, isEmpty);
      await tester.tap(find.byKey(const Key('snack-undo')));
      await tester.pumpAndSettle();
      expect(c.state!.profiles.single['name'], 'Thẻ VCB');
    },
  );

  testWidgets(
    'what-ifs are drawn over the forecast, compared, and never touch the ledger',
    (tester) async {
      final c = await start(
        tester,
        store: seeded(SpendState(accounts: [cash(opening: 1000000, since: 0)])),
      );
      await tapKey(tester, 'nav-2');
      await tapKey(tester, 'whatif-purchase');
      await typeKey(tester, 'field-name', 'Laptop');
      await typeKey(tester, 'field-cost', '3000000');
      await tapKey(tester, 'editor-save');
      final x = c.state!.scenarios.single;
      expect(c.state!.entries, isEmpty);
      // Turned on at once and compared against the forecast as it is.
      expect(find.byKey(Key('whatif-compare-${x.id}')), findsOneWidget);
      expect(find.textContaining('Never short'), findsNothing);
      await tapKey(tester, 'whatif-toggle-${x.id}');
      expect(find.byKey(Key('whatif-compare-${x.id}')), findsNothing);
      await tapKey(tester, 'whatif-toggle-${x.id}');
      // The old link still opens it.
      await tapKey(tester, 'whatif-${x.id}');
      expect(find.byKey(const Key('whatif-record')), findsOneWidget);
      expect(c.state!.entries, isEmpty);
    },
  );
}

String _dmy(String iso) =>
    '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
