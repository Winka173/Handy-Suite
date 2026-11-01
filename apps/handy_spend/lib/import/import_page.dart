import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show compute;
import 'package:handy_files/handy_files.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'review_row.dart';
import 'statement_io.dart';
part 'import_steps.dart';

/// A bank statement into one account, in four steps: choose the file, match
/// its columns, look over every row, done. Nothing is written before the
/// last confirmation, and the batch can be undone afterwards.
class ImportPage extends StatefulWidget {
  final SpendScope scope;
  final String? account;
  final ImportedBytes? initialFile;
  const ImportPage({
    super.key,
    required this.scope,
    this.account,
    this.initialFile,
  });
  @override
  State<ImportPage> createState() => ImportPageState();
}

class ImportPageState extends State<ImportPage> {
  SpendScope get scope => widget.scope;
  SpendState get s => scope.state;
  ImportedBytes? file;
  List<List<String>>? rows;
  StatementPreview? preview;
  String delimiter = ',', encoding = 'utf8', dateFormat = 'ymd';
  String decimal = '.', group = ',', account = '', zone = '';
  int date = 0, payee = 1, amount = 2, debit = -1, credit = -1, balance = -1;
  int reviewPage = 0, revision = 0;
  bool newestFirst = false, reverse = false, busy = false;
  bool partial = false, saveProfile = false, finished = false;
  final selected = <int>{};
  String error = '';

  int get step => file == null || rows == null
      ? 0
      : preview == null
      ? 1
      : finished
      ? 3
      : 2;

  @override
  void initState() {
    super.initState();
    final open = scope.openAccounts;
    account = open.any((a) => a.id == widget.account)
        ? widget.account!
        : open.first.id;
    zone = s.zone;
    if (widget.initialFile != null) {
      file = widget.initialFile;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(task(parse));
      });
    }
  }

  Future<void> task(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Could not read this file or mapping (${errorText(context, e)}). Check the encoding, columns, dates and amounts. No row was imported.',
            'Không đọc được file hoặc cách ghép cột (${errorText(context, e)}). Kiểm tra mã chữ, cột, ngày và số tiền. Chưa nhập dòng nào.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  StatementMapping get mapping => StatementMapping(
    account: account,
    date: date,
    payee: payee,
    amount: amount,
    debit: debit,
    credit: credit,
    balance: balance,
    newestFirst: newestFirst,
    dateFormat: dateFormat,
    decimal: decimal,
    group: group,
    zone: zone,
    reverse: reverse,
  );

  Future<void> pick() async {
    final next = await scope.files.importBytes(
      extensions: ['csv', 'txt', 'xlsx', 'json'],
      maxBytes: 12000000,
    );
    if (next == null) return;
    file = next;
    await parse();
  }

  Future<void> parse() async {
    final f = file!;
    if (f.name.toLowerCase().endsWith('.json')) {
      final data = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(f.bytes)) as Map,
      );
      if (data['app'] != 'handy-spend-transactions' || data['version'] != 1)
        throw const FormatException(
          'Use Restore for full backups / Dùng Khôi phục cho bản sao lưu',
        );
      final entries = (data['entries'] as List)
          .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      rows = transactionRows(s, entries);
    } else {
      rows = await compute(parseStatement, {
        'bytes': f.bytes,
        'extension': f.name.toLowerCase().endsWith('.xlsx') ? 'xlsx' : 'csv',
        'encoding': encoding,
        'delimiter': delimiter,
      });
    }
    if (rows!.first.length < 2)
      throw const FormatException(
        'Choose another delimiter / Hãy chọn dấu phân cột khác',
      );
    preview = null;
    finished = false;
    selected.clear();
  }

  Future<void> validate() async {
    revision = s.revision;
    if (rows!.first.last == '_handy_entry_v1') {
      final entries = readTransactionRows(s, rows!),
          batchId = newId(),
          existing = s.entries.map((e) => e.id).toSet();
      preview = StatementPreview(
        sha256.convert(file!.bytes).toString(),
        batchId,
        [
          for (var i = 0; i < entries.length; i++)
            StatementRow(
              i + 2,
              entries[i].copy({'batch': batchId}),
              existing.contains(entries[i].id) ? 'duplicate' : 'new',
            ),
        ],
      );
    } else {
      preview = await compute(validateStatement, {
        'state': s.toJson(),
        'rows': rows,
        'mapping': mapping.toJson(),
        'bytes': file!.bytes,
      });
    }
    reviewPage = 0;
    selected
      ..clear()
      ..addAll(
        preview!.rows.where((r) => r.status == 'new').map((r) => r.number),
      );
  }

  /// Asks first, then shows the work as busy only while it writes.
  Future<void> confirmCommit() async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Import ${selected.length} rows?',
        'Nhập ${selected.length} dòng?',
      ),
      message: tr(
        context,
        'They go into the ledger together, in one change you can undo.',
        'Tất cả vào sổ cùng lúc, trong một thay đổi có thể hoàn tác.',
      ),
      confirmLabel: tr(context, 'Import', 'Nhập'),
    );
    if (ok && mounted) await task(commit);
  }

  Future<void> commit() async {
    await scope.controller.change((current) {
      if (current.revision != revision)
        throw StateError('The ledger changed since the check; check again');
      var next = preview!.commit(current, selected, allowPartial: partial);
      if (saveProfile && scope.pro(context))
        next = next.copy({
          'profiles': [
            ...next.profiles,
            {
              'id': newId(),
              'name': file!.name,
              'headers': rows!.first,
              'mapping': mapping.toJson(),
            },
          ],
        });
      return next;
    }, 'statement_import');
    finished = true;
  }

  Future<void> undoBatch() async {
    await scope.controller.change(
      (s) => undoImport(s, preview!.batchId),
      'undo_import',
    );
    if (mounted) Navigator.pop(context);
  }

  void useProfile(String id) {
    final p = s.profiles.firstWhere((p) => p['id'] == id);
    if (jsonEncode(p['headers']) != jsonEncode(rows!.first)) {
      setState(
        () => error = tr(
          context,
          'That profile has other columns; match them here.',
          'Hồ sơ đó có cột khác; hãy ghép cột ở đây.',
        ),
      );
      return;
    }
    final m = StatementMapping.fromJson(
      Map<String, dynamic>.from(p['mapping'] as Map),
    );
    setState(() {
      date = m.date;
      payee = m.payee;
      amount = m.amount;
      debit = m.debit;
      credit = m.credit;
      balance = m.balance;
      newestFirst = m.newestFirst;
      dateFormat = m.dateFormat;
      decimal = m.decimal;
      group = m.group;
      zone = m.zone;
      reverse = m.reverse;
    });
  }

  Future<void> review(StatementRow row) async {
    if (busy || row.entry == null) return;
    final references = <String, Entry>{
      for (final e in s.entries) e.id: e,
      for (final r in preview!.rows)
        if (r.entry != null) r.entry!.id: r.entry!,
    };
    await reviewStatementRow(context, scope, row, references, (changed) {
      setState(() {
        final old = preview!;
        preview = StatementPreview(
          old.fileHash,
          old.batchId,
          List.unmodifiable([
            for (final r in old.rows)
              r.number == row.number
                  ? StatementRow(r.number, changed, 'reviewed')
                  : r,
          ]),
          statementAccount: old.statementAccount,
          balanceAt: old.balanceAt,
          closingBalance: old.closingBalance,
        );
        selected.add(row.number);
      });
    });
  }

  String rowKind(String kind) => kindLabel(context, kind);

  /// For the step builders in `import_steps.dart`.
  void update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final titles = [
      tr(context, 'Choose the file', 'Chọn file'),
      tr(context, 'Match the columns', 'Ghép cột'),
      tr(context, 'Look over the rows', 'Soát các dòng'),
      tr(context, 'Done', 'Xong'),
    ];
    final Widget? primary = switch (step) {
      0 => FilledButton.icon(
        key: const Key('import-pick'),
        onPressed: busy ? null : () => unawaited(task(pick)),
        icon: const Icon(Icons.upload_file_outlined),
        label: Text(tr(context, 'Choose a statement', 'Chọn file sao kê')),
      ),
      1 => FilledButton(
        key: const Key('import-validate'),
        onPressed: busy ? null : () => unawaited(task(validate)),
        child: Text(tr(context, 'Check the rows', 'Kiểm tra các dòng')),
      ),
      2 => FilledButton(
        key: const Key('import-commit'),
        onPressed: busy || selected.isEmpty
            ? null
            : () => unawaited(confirmCommit()),
        child: Text(
          tr(
            context,
            'Import ${selected.length} rows',
            'Nhập ${selected.length} dòng',
          ),
        ),
      ),
      _ => FilledButton(
        key: const Key('import-done'),
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Done', 'Xong')),
      ),
    };
    return PopScope(
      canPop: !busy,
      child: HandyPage(
        title: tr(context, 'Import a statement', 'Nhập sao kê'),
        subtitle: tr(
          context,
          'Step ${step + 1} of 4 · ${titles[step]}',
          'Bước ${step + 1}/4 · ${titles[step]}',
        ),
        bottom: primary,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: HandySpace.m),
              child: HandyNotice(error, tone: HandyTone.error),
            ),
          ...switch (step) {
            0 => chooseStep(this),
            1 => mapStep(this),
            2 => reviewStep(this),
            _ => doneStep(this),
          },
        ],
      ),
    );
  }

  /// The first rows of the file, as it was read.
  Widget sample() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowHeight: 40,
      columns: [
        for (var i = 0; i < min(8, rows!.first.length); i++)
          DataColumn(label: Text('${i + 1}. ${rows!.first[i]}')),
      ],
      rows: [
        for (final row in rows!.skip(1).take(5))
          DataRow(
            cells: [
              for (var i = 0; i < min(8, rows!.first.length); i++)
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Text(
                      i < row.length ? row[i] : '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
      ],
    ),
  );

  String amountOf(Entry e) => moneyText(
    context,
    scope,
    e.amount,
    scope.account(e.account).currency,
    sign: true,
  );
}
