part of 'app.dart';

Future<ImportedBytes> readDroppedStatement(DropItem file) async {
  if (file is! DropItemFile ||
      ![
        'csv',
        'txt',
        'xlsx',
        'json',
      ].any((e) => file.name.toLowerCase().endsWith('.$e')))
    throw const FormatException('Choose a statement file');
  if (await file.length() > 12000000)
    throw const FormatException('File exceeds 12MB');
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (bytes.length + chunk.length > 12000000)
      throw const FormatException('File exceeds 12MB');
    bytes.add(chunk);
  }
  return ImportedBytes(file.name, bytes.takeBytes());
}

List<List<String>> _parseStatement(Map<String, dynamic> input) {
  final bytes = input['bytes'] as Uint8List,
      extension = input['extension'] as String;
  if (extension == 'xlsx') return xlsxParse(bytes);
  return csvParse(
    decodeStatement(bytes, encoding: input['encoding'] as String),
    delimiter: input['delimiter'] as String,
  );
}

StatementPreview _validateStatement(Map<String, dynamic> input) =>
    previewStatement(
      SpendState.fromJson(Map<String, dynamic>.from(input['state'] as Map)),
      List<List<String>>.from(
        (input['rows'] as List).map((e) => List<String>.from(e as List)),
      ),
      StatementMapping.fromJson(
        Map<String, dynamic>.from(input['mapping'] as Map),
      ),
      input['bytes'] as Uint8List,
    );

extension _Portability on _SpendHomeState {
  Future<void> importHistoryPage() => pageRoute(
    'Import history',
    'Lịch sử nhập',
    (context) => AnimatedBuilder(
      animation: c,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (s.imports.isEmpty)
            Text(t('No imports yet.', 'Chưa có lần nhập nào.')),
          for (final record in s.imports.reversed)
            Card(
              child: ListTile(
                title: Text(
                  '${record['imported']} / ${record['totalRows']} ${t('rows', 'hàng')}',
                ),
                subtitle: Text(
                  '${record['at']} · ${record['undone'] == true ? t('undone', 'đã hoàn tác') : t('committed', 'đã ghi')}',
                ),
                trailing: record['undone'] == true
                    ? null
                    : TextButton(
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                run(() async {
                                  if (await confirm(
                                    'Undo this batch only if its rows remain unchanged and have no dependent refunds?',
                                    'Hoàn tác lần nhập này nếu hàng chưa thay đổi và không có hoàn tiền liên quan?',
                                  ))
                                    await c.change(
                                      (s) =>
                                          undoImport(s, record['id'] as String),
                                      'undo_import',
                                    );
                                }),
                              ),
                        child: Text(t('Undo batch', 'Hoàn tác lần nhập')),
                      ),
              ),
            ),
        ],
      ),
    ),
  );
  Future<void> importWizard({ImportedBytes? initial}) async {
    final routeContext = context;
    if (accountOptions.isEmpty) {
      await accountEditor();
      if (accountOptions.isEmpty) return;
    }
    if (!routeContext.mounted) return;
    c.adsVisible.value = false;
    await Navigator.push(
      routeContext,
      MaterialPageRoute<void>(
        builder: (context) => StatementWizard(
          controller: c,
          files: widget.files,
          pro: pro,
          initialFile: initial,
        ),
      ),
    );
    if (mounted) c.adsVisible.value = tab != 2;
  }

  Future<void> restoreBackup() async {
    final file = await widget.files.importBytes(
      extensions: ['zip', 'json'],
      maxBytes: 30000000,
    );
    if (file == null) return;
    final restored = await compute(_restoreBytes, {
      'bytes': file.bytes,
      'zip': file.name.toLowerCase().endsWith('.zip'),
    });
    final revision = s.revision;
    if (!privacy.supported &&
        restored.settings['deviceLock'] == true &&
        !await confirm(
          'Device authentication is unavailable on this platform. Restoring will disable the device-lock flag here; exported data is not encrypted. Continue?',
          'Nền tảng này không hỗ trợ xác thực thiết bị. Khôi phục sẽ tắt cờ khóa thiết bị tại đây; file không được mã hóa. Tiếp tục?',
        ))
      return;
    if (!await confirm(
      'Validated backup: ${restored.accounts.length} accounts, ${restored.entries.length} transactions. Replace current financial data? The current change remains auditable and can be undone before another change.',
      'Sao lưu hợp lệ: ${restored.accounts.length} tài khoản, ${restored.entries.length} giao dịch. Thay dữ liệu tài chính hiện tại? Thay đổi được ghi vết và có thể hoàn tác trước thay đổi tiếp theo.',
    ))
      return;
    if (!await confirm(
      'Confirm replacement. Keep your existing backup file.',
      'Xác nhận thay thế. Hãy giữ file sao lưu hiện tại.',
    ))
      return;
    await c.change((s) {
      if (s.revision != revision)
        throw StateError('Data changed during review');
      return !privacy.supported && restored.settings['deviceLock'] == true
          ? restored.copy({
              'settings': {...restored.settings, 'deviceLock': false},
            })
          : restored;
    }, 'restore_backup');
  }

  Future<void> exportData(String format, {bool onlySelected = false}) async {
    if (!await confirm(
      'The exported file contains private financial data. Continue?',
      'File xuất chứa dữ liệu tài chính riêng tư. Tiếp tục?',
    ))
      return;
    final selectedRows = onlySelected
        ? s.entries.where((e) => selected.contains(e.id)).toList()
        : filtered;
    final byId = {for (final e in s.entries) e.id: e},
        ids = selectedRows.map((e) => e.id).toSet();
    for (final e in selectedRows) {
      if (e.refundOf != null) ids.add(e.refundOf!);
    }
    final rows = ids.map((id) => byId[id]!).toList(),
        table = transactionRows(s, rows);
    Uint8List bytes;
    String mime,
        name = 'handy-spend-${DateTime.now().millisecondsSinceEpoch}.$format';
    if (format == 'zip') {
      bytes = await compute(_backupState, s.toJson());
      mime = 'application/zip';
    } else if (format == 'csv') {
      bytes = Uint8List.fromList(utf8.encode(csvEncode(table)));
      mime = 'text/csv';
    } else if (format == 'xlsx') {
      bytes = await compute(xlsxEncode, table);
      mime =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    } else if (format == 'json') {
      bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'app': 'handy-spend-transactions',
            'version': 1,
            'currency': s.currency,
            'reportTimezone': s.zone,
            'from': from,
            'untilExcluded': until,
            'accounts': s.accounts
                .where(
                  (a) =>
                      rows.any((e) => e.account == a.id || e.toAccount == a.id),
                )
                .map((a) => a.toJson())
                .toList(),
            'categories': s.categories.map((c) => c.toJson()).toList(),
            'entries': rows.map((e) => e.toJson()).toList(),
          }),
        ),
      );
      mime = 'application/json';
    } else if (format == 'pdf') {
      final font = pw.Font.ttf(
            await rootBundle.load(
              'packages/handy_ui/assets/fonts/Geist-Regular.ttf',
            ),
          ),
          doc = pw.Document();
      if (rows.length > 5000)
        throw const FormatException('PDF limit 5000 rows; use CSV or XLSX');
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          maxPages: 200,
          theme: pw.ThemeData.withFont(base: font),
          build: (_) => [
            pw.Text('Handy Spend', style: pw.TextStyle(fontSize: 22)),
            pw.Text('$from - $until (${s.zone}; end excluded)'),
            pw.Text(
              t(
                'Actual records; refunds may include original expense dependencies. Amounts retain original currency.',
                'Dữ liệu thật; hoàn tiền có thể kèm khoản chi gốc liên quan. Giữ tiền tệ ban đầu.',
              ),
            ),
            pw.TableHelper.fromTextArray(
              headers: [
                t('Date', 'Ngày'),
                t('Payee', 'Đối tác'),
                t('Amount', 'Số tiền'),
                t('Currency', 'Tiền'),
              ],
              data: [
                for (final row in table.skip(1))
                  [row[0].substring(0, 10), row[1], row[2], row[3]],
              ],
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      );
      bytes = await doc.save();
      mime = 'application/pdf';
    } else {
      throw ArgumentError('Unsupported export');
    }
    if (bytes.length > 30000000)
      throw const FormatException('Export exceeds 30MB');
    final result = await widget.files.exportBytes(name, bytes, mimeType: mime);
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb
              ? t(
                  'Download requested; verify the saved file.',
                  'Đã yêu cầu tải; hãy kiểm tra file đã lưu.',
                )
              : t('Export complete', 'Đã xuất file'),
        ),
      ),
    );
  }
}

SpendState _restoreBytes(Map<String, dynamic> input) =>
    restore(input['bytes'] as Uint8List, zip: input['zip'] as bool);
Uint8List _backupState(Map<String, dynamic> json) =>
    backup(SpendState.fromJson(json));

class StatementWizard extends StatefulWidget {
  final ImportedBytes? initialFile;
  final SpendController controller;
  final HandyFiles files;
  final bool pro;
  const StatementWizard({
    super.key,
    required this.controller,
    required this.files,
    required this.pro,
    this.initialFile,
  });
  @override
  State<StatementWizard> createState() => _StatementWizardState();
}

class _StatementWizardState extends State<StatementWizard> {
  ImportedBytes? file;
  List<List<String>>? rows;
  StatementPreview? preview;
  String delimiter = ',',
      encoding = 'utf8',
      dateFormat = 'ymd',
      decimal = '.',
      group = ',',
      account = '',
      zone = '';
  int date = 0,
      payee = 1,
      amount = 2,
      debit = -1,
      credit = -1,
      balance = -1,
      reviewPage = 0,
      revision = 0;
  bool newestFirst = false;
  bool reverse = false,
      busy = false,
      partial = false,
      saveProfile = false,
      finished = false;
  final selected = <int>{};
  String error = '';
  SpendState get s => widget.controller.state!;
  String t(String en, String vi) => tr(context, en, vi);
  @override
  void initState() {
    super.initState();
    account = s.accounts.firstWhere((a) => !a.archived).id;
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
    } catch (_) {
      if (mounted)
        setState(
          () => error = t(
            'Could not process this file or mapping. Check encoding, columns, dates, amounts and storage. No unconfirmed rows were imported.',
            'Không xử lý được file hoặc ánh xạ. Kiểm tra mã chữ, cột, ngày, số tiền và dung lượng. Không nhập hàng chưa xác nhận.',
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
    final next = await widget.files.importBytes(
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
        throw const FormatException('Use Restore for full backups');
      final entries = (data['entries'] as List)
          .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      rows = transactionRows(s, entries);
    } else {
      rows = await compute(_parseStatement, {
        'bytes': f.bytes,
        'extension': f.name.toLowerCase().endsWith('.xlsx') ? 'xlsx' : 'csv',
        'encoding': encoding,
        'delimiter': delimiter,
      });
    }
    if (rows!.first.length < 2)
      throw const FormatException('Choose delimiter or mapping');
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
      preview = await compute(_validateStatement, {
        'state': s.toJson(),
        'rows': rows,
        'mapping': mapping.toJson(),
        'bytes': file!.bytes,
      });
    }
    reviewPage = 0;
    selected.clear();
    selected.addAll(
      preview!.rows.where((r) => r.status == 'new').map((r) => r.number),
    );
  }

  Future<void> commit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Confirm import', 'Xác nhận nhập')),
        content: Text(
          '${selected.length} ${t('selected rows. Commit atomically?', 'hàng đã chọn. Ghi trong một giao dịch nguyên tử?')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Cancel', 'Hủy')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Import', 'Nhập')),
          ),
        ],
      ),
    );
    if (result != true) return;
    await widget.controller.change((current) {
      if (current.revision != revision)
        throw StateError('Data changed since preview');
      var next = preview!.commit(current, selected, allowPartial: partial);
      if (saveProfile && widget.pro)
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

  String rowKind(String kind) => switch (kind) {
    'expense' => t('Expense', 'Chi tiêu'),
    'income' => t('Income', 'Thu nhập'),
    'transfer' => t('Transfer', 'Chuyển khoản'),
    'refund' => t('Refund', 'Hoàn tiền'),
    _ => t('Adjustment', 'Điều chỉnh'),
  };
  Future<void> reviewRow(StatementRow row) async {
    if (busy || row.entry == null) return;
    final e = row.entry!,
        ac = s.accounts.firstWhere((a) => a.id == e.account),
        references = <String, Entry>{
          for (final entry in s.entries) entry.id: entry,
          for (final r in preview!.rows)
            if (r.entry != null) r.entry!.id: r.entry!,
        };
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SpendEditor(
          en: 'Review statement row ${row.number}',
          vi: 'Rà hàng sao kê ${row.number}',
          fields: [
            EditField(
              'kind',
              'Classification',
              'Phân loại',
              options: {
                for (final kind in [
                  'expense',
                  'income',
                  'transfer',
                  'refund',
                  'adjustment',
                ])
                  kind: rowKind(kind),
              },
            ),
            EditField(
              'account',
              'Source account',
              'Tài khoản nguồn',
              options: {
                for (final a in s.accounts.where((a) => !a.archived))
                  a.id: '${a.name} · ${a.currency}',
              },
            ),
            const EditField(
              'amount',
              'Signed source amount (expense/transfer negative)',
              'Số tiền nguồn có dấu (chi/chuyển âm)',
              number: true,
            ),
            const EditField(
              'when',
              'Effective ISO timestamp with timezone',
              'Thời điểm ISO kèm múi giờ',
            ),
            const EditField('payee', 'Payee', 'Đối tác', requiredValue: false),
            EditField(
              'category',
              'Category',
              'Danh mục',
              options: {
                '': t('None', 'Không'),
                for (final category in s.categories) category.id: category.name,
              },
              requiredValue: false,
            ),
            EditField(
              'to',
              'Transfer destination',
              'Tài khoản nhận',
              options: {
                '': t('None', 'Không'),
                for (final a in s.accounts.where((a) => !a.archived))
                  a.id: '${a.name} · ${a.currency}',
              },
              requiredValue: false,
            ),
            const EditField(
              'rate',
              'Explicit FX rate if currencies differ',
              'Tỷ giá nhập tay nếu khác tiền',
              number: true,
              requiredValue: false,
            ),
            EditField(
              'refund',
              'Original expense for refund',
              'Khoản chi gốc cho hoàn tiền',
              options: {
                '': t('None', 'Không'),
                for (final original in references.values.where(
                  (r) => r.kind == 'expense' && r.id != e.id,
                ))
                  original.id:
                      '${reportDay(original.when, s.zone)} · ${original.payee} · ${original.amount}',
              },
              requiredValue: false,
            ),
          ],
          initial: {
            'kind': e.kind,
            'account': e.account,
            'amount': decimalMoney(e.amount, ac.currency),
            'when': e.when,
            'payee': e.payee,
            'category': e.category ?? '',
            'to': e.toAccount ?? '',
            'rate': e.rate ?? '',
            'refund': e.refundOf ?? '',
          },
          save: (v) async {
            final account = s.accounts.firstWhere((a) => a.id == v['account']),
                type = v['kind'] as String,
                amount = minor(v['amount'] as String, account.currency),
                to = type == 'transfer'
                    ? s.accounts.firstWhere((a) => a.id == v['to'])
                    : null,
                rate = (v['rate'] as String).isEmpty
                    ? null
                    : v['rate'] as String;
            final changed = e.copy({
              'account': account.id,
              'kind': type,
              'amount': '$amount',
              'when': v['when'],
              'payee': v['payee'],
              'category': v['category'] == '' ? null : v['category'],
              'toAccount': to?.id,
              'target': to == null
                  ? null
                  : (to.currency == account.currency
                            ? -amount
                            : convert(
                                -amount,
                                account.currency,
                                to.currency,
                                rate ?? '',
                              ))
                        .toString(),
              'rate': to == null ? null : rate,
              'refundOf': type == 'refund' ? v['refund'] : null,
              'fee': '0',
            });
            SpendState(
              accounts: s.accounts,
              categories: s.categories,
              settings: s.settings,
              entries: [
                if (changed.refundOf != null)
                  references[changed.refundOf] ??
                      (throw const FormatException('Missing refund source')),
                changed,
              ],
            ).validate();
            setState(() {
              final old = preview!;
              preview = StatementPreview(
                old.fileHash,
                old.batchId,
                List.unmodifiable([
                  for (final r in old.rows)
                    if (r.number == row.number)
                      StatementRow(r.number, changed, 'reviewed')
                    else
                      r,
                ]),
                statementAccount: old.statementAccount,
                balanceAt: old.balanceAt,
                closingBalance: old.closingBalance,
              );
              selected.add(row.number);
            });
          },
        ),
      ),
    );
  }

  Widget reconciliationSummary() {
    final record = s.imports
            .where((r) => r['id'] == preview?.batchId)
            .firstOrNull,
        raw = record?['reconciliation'];
    if (raw is! Map)
      return Text(
        t(
          'No comparable closing-balance column was mapped. Reconcile manually if needed.',
          'Chưa ánh xạ cột số dư có thể đối chiếu. Hãy đối chiếu thủ công nếu cần.',
        ),
      );
    final account = s.accounts.where((a) => a.id == raw['account']).firstOrNull;
    if (account == null) return const SizedBox();
    String amount(String key) => formatFigure(
      context,
      '${decimalMoney(BigInt.parse(raw[key] as String), account.currency)} ${account.currency}',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t('Reconciliation at calendar day', 'Đối chiếu theo ngày lịch')}: ${raw['asOf']}',
        ),
        Text(
          '${t('Statement closing balance', 'Số dư cuối sao kê')}: ${amount('statement')}',
        ),
        Text(
          '${t('Ledger balance after selected rows', 'Số dư sổ sau hàng đã chọn')}: ${amount('ledger')}',
        ),
        Text(
          '${t('Difference (never silently corrected)', 'Chênh lệch (không tự điều chỉnh')}: ${amount('difference')}',
        ),
      ],
    );
  }

  Widget choice(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: busy
          ? null
          : (v) {
              if (v != null) setState(() => change(v));
            },
    ),
  );
  Widget column(String label, int value, ValueChanged<int> change) =>
      choice(label, '$value', {
        '-1': t('Not mapped', 'Không ánh xạ'),
        for (var i = 0; i < rows!.first.length; i++)
          '$i': '${i + 1}: ${rows!.first[i]}',
      }, (v) => change(int.parse(v)));
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(t('Import statement', 'Nhập sao kê'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                t(
                  'Select → Preview → Map → Validate → Review duplicates → Import → Results',
                  'Chọn → Xem trước → Ánh xạ → Kiểm tra → Rà trùng → Nhập → Kết quả',
                ),
              ),
              Text(
                t(
                  'Files are processed locally. No bank connection, credentials, SMS or notification reading.',
                  'File xử lý tại máy. Không kết nối ngân hàng, thông tin đăng nhập, đọc SMS hay thông báo.',
                ),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error.isNotEmpty)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (file == null)
                FilledButton(
                  onPressed: busy ? null : () => unawaited(task(pick)),
                  child: Text(t('Choose statement file', 'Chọn file sao kê')),
                ),
              if (file != null) ...[
                Text(file!.name),
                TextButton(
                  onPressed: busy ? null : () => unawaited(task(pick)),
                  child: Text(t('Choose another file', 'Chọn file khác')),
                ),
                if (rows == null || preview == null) ...[
                  choice(
                    t('CSV delimiter', 'Dấu phân cột CSV'),
                    delimiter,
                    {
                      ',': t('Comma', 'Phẩy'),
                      ';': t('Semicolon', 'Chấm phẩy'),
                      '\t': 'Tab',
                    },
                    (v) => delimiter = v,
                  ),
                  choice(t('Text encoding', 'Mã chữ'), encoding, {
                    'utf8': 'UTF-8 / UTF-16 BOM',
                    'latin1': 'Latin-1 (explicit)',
                  }, (v) => encoding = v),
                  OutlinedButton(
                    onPressed: busy ? null : () => unawaited(task(parse)),
                    child: Text(
                      t('Parse / reparse file', 'Đọc / đọc lại file'),
                    ),
                  ),
                ],
              ],
              if (rows != null && !finished) ...[
                Text('${rows!.length - 1} ${t('data rows', 'hàng dữ liệu')}'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      for (var i = 0; i < min(8, rows!.first.length); i++)
                        DataColumn(label: Text(rows!.first[i])),
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
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (preview == null) ...[
                  choice(
                    t('Destination account', 'Tài khoản nhập'),
                    account,
                    {
                      for (final a in s.accounts.where((a) => !a.archived))
                        a.id: '${a.name} · ${a.currency}',
                    },
                    (v) => account = v,
                  ),
                  if (s.profiles.isNotEmpty)
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: t(
                          'Saved mapping profile',
                          'Hồ sơ ánh xạ đã lưu',
                        ),
                      ),
                      isExpanded: true,
                      items: s.profiles
                          .map(
                            (p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(p['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (id) {
                              final p = s.profiles.firstWhere(
                                (p) => p['id'] == id,
                              );
                              if (jsonEncode(p['headers']) !=
                                  jsonEncode(rows!.first)) {
                                setState(
                                  () => error = t(
                                    'Profile columns differ; map manually.',
                                    'Cột khác hồ sơ; hãy ánh xạ thủ công.',
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
                            },
                    ),
                  column(t('Date column', 'Cột ngày'), date, (v) => date = v),
                  column(
                    t('Payee / description column', 'Cột đối tác / mô tả'),
                    payee,
                    (v) => payee = v,
                  ),
                  column(
                    t(
                      'Signed amount column (or unmapped for debit/credit)',
                      'Cột số tiền có dấu (hoặc bỏ để dùng nợ/có)',
                    ),
                    amount,
                    (v) => amount = v,
                  ),
                  column(
                    t('Debit column', 'Cột ghi nợ'),
                    debit,
                    (v) => debit = v,
                  ),
                  column(
                    t('Credit column', 'Cột ghi có'),
                    credit,
                    (v) => credit = v,
                  ),
                  column(
                    t(
                      'Closing/running balance column (optional)',
                      'Cột số dư (tùy chọn)',
                    ),
                    balance,
                    (v) => balance = v,
                  ),
                  SwitchListTile(
                    title: Text(
                      t(
                        'File rows are newest first',
                        'Hàng trong file mới nhất ở trên',
                      ),
                    ),
                    value: newestFirst,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => newestFirst = v),
                  ),
                  choice(t('Date format', 'Dạng ngày'), dateFormat, {
                    'ymd': 'YYYY-MM-DD',
                    'dmy': 'DD/MM/YYYY',
                    'mdy': 'MM/DD/YYYY',
                    'excel': t(
                      'Excel serial, 1900 system',
                      'Số ngày Excel, hệ 1900',
                    ),
                  }, (v) => dateFormat = v),
                  choice(
                    t('Decimal separator', 'Dấu thập phân'),
                    decimal,
                    {'.': '.', ',': ','},
                    (v) => decimal = v,
                  ),
                  choice(t('Grouping separator', 'Dấu nhóm số'), group, {
                    ',': ',',
                    '.': '.',
                    ' ': 'Space',
                    '': 'None',
                  }, (v) => group = v),
                  TextFormField(
                    initialValue: zone,
                    decoration: InputDecoration(
                      labelText: t(
                        'Statement IANA timezone',
                        'Múi giờ IANA của sao kê',
                      ),
                    ),
                    onChanged: (v) => zone = v,
                  ),
                  SwitchListTile(
                    title: Text(t('Reverse signs', 'Đảo dấu số tiền')),
                    value: reverse,
                    onChanged: busy ? null : (v) => setState(() => reverse = v),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => unawaited(task(validate)),
                    child: Text(
                      t(
                        'Validate and review duplicates',
                        'Kiểm tra và rà bản trùng',
                      ),
                    ),
                  ),
                ],
                if (preview != null) ...[
                  Text(
                    '${t('New', 'Mới')}: ${preview!.rows.where((r) => r.status == 'new').length} · ${t('Duplicate / possible reversal', 'Trùng / có thể đảo giao dịch')}: ${preview!.rows.where((r) => r.status != 'new' && r.status != 'error').length} · ${t('Errors', 'Lỗi')}: ${preview!.rows.where((r) => r.status == 'error').length}',
                  ),
                  Text(
                    t(
                      'Duplicates and possible reversals are unselected. Confirm manually; nothing is deleted automatically.',
                      'Bản trùng và khả năng đảo giao dịch chưa được chọn. Xác nhận thủ công; không tự xóa mục nào.',
                    ),
                  ),
                  Text(
                    t(
                      'Transfers and refunds are not inferred. Edit the row to create a linked transfer or refund, or skip it and record it manually. Positive liability credits require explicit classification.',
                      'Không tự suy ra chuyển khoản hay hoàn tiền. Sửa hàng để tạo liên kết hoặc bỏ qua và ghi thủ công. Khoản vào tài khoản nợ cần phân loại rõ.',
                    ),
                  ),
                  for (final row
                      in preview!.rows.skip(reviewPage * 100).take(100))
                    CheckboxListTile(
                      secondary: row.entry == null
                          ? null
                          : IconButton(
                              tooltip: t(
                                'Review row classification',
                                'Sửa phân loại hàng',
                              ),
                              onPressed: busy
                                  ? null
                                  : () => unawaited(reviewRow(row)),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                      title: Text(
                        '${row.number} · ${row.entry?.payee ?? t('Invalid row', 'Hàng lỗi')}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (row.entry != null)
                            Text(
                              '${reportDay(row.entry!.when, s.zone)} · ${rowKind(row.entry!.kind)} · ${decimalMoney(row.entry!.amount, s.accounts.firstWhere((a) => a.id == row.entry!.account).currency)} ${s.accounts.firstWhere((a) => a.id == row.entry!.account).currency}',
                            ),
                          Text(
                            row.status == 'new'
                                ? t('New', 'Mới')
                                : row.status == 'error'
                                ? t(
                                    'Invalid date, amount, mapping or account boundary',
                                    'Ngày, số tiền, ánh xạ hoặc mốc tài khoản không hợp lệ',
                                  )
                                : t(
                                    'Potential duplicate or reversal',
                                    'Có thể trùng hoặc đảo giao dịch',
                                  ),
                          ),
                        ],
                      ),
                      value: selected.contains(row.number),
                      onChanged:
                          busy ||
                              row.entry == null ||
                              row.status == 'needs classification'
                          ? null
                          : (v) => setState(
                              () => v == true
                                  ? selected.add(row.number)
                                  : selected.remove(row.number),
                            ),
                    ),
                  if (preview!.rows.length > 100)
                    Wrap(
                      spacing: 12,
                      children: [
                        Text(
                          '${reviewPage * 100 + 1} - ${min((reviewPage + 1) * 100, preview!.rows.length)} / ${preview!.rows.length}',
                        ),
                        TextButton(
                          onPressed: busy || reviewPage == 0
                              ? null
                              : () => setState(() => reviewPage--),
                          child: Text(t('Previous', 'Trước')),
                        ),
                        TextButton(
                          onPressed:
                              busy ||
                                  (reviewPage + 1) * 100 >= preview!.rows.length
                              ? null
                              : () => setState(() => reviewPage++),
                          child: Text(t('Next', 'Tiếp')),
                        ),
                      ],
                    ),
                  TextButton(
                    onPressed: busy ? null : () => setState(selected.clear),
                    child: Text(t('Unselect all', 'B? ch?n t?t c?')),
                  ),
                  SwitchListTile(
                    title: Text(
                      t(
                        'Explicitly allow partial import if errors exist',
                        'Cho phép nhập phần hợp lệ khi có lỗi',
                      ),
                    ),
                    value: partial,
                    onChanged: busy ? null : (v) => setState(() => partial = v),
                  ),
                  CheckboxListTile(
                    title: Text(
                      t(
                        'Save reusable mapping profile (Pro)',
                        'Lưu hồ sơ ánh xạ tái sử dụng (Pro)',
                      ),
                    ),
                    value: saveProfile,
                    onChanged: busy || !widget.pro
                        ? null
                        : (v) => setState(() => saveProfile = v == true),
                  ),
                  FilledButton(
                    onPressed: busy || selected.isEmpty
                        ? null
                        : () => unawaited(task(commit)),
                    child: Text(
                      '${t('Import selected rows', 'Nhập hàng đã chọn')}: ${selected.length}',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => preview = null),
                    child: Text(t('Back to mapping', 'Trở lại ánh xạ')),
                  ),
                ],
              ],
              if (finished) ...[
                reconciliationSummary(),
                Text(
                  '${t('Committed transactions', 'Giao dịch đã ghi')}: ${selected.length}',
                ),
                Text(
                  t(
                    'The import is recorded in history. Undo refuses changed or dependent rows.',
                    'Lần nhập được ghi lịch sử. Hoàn tác từ chối hàng đã sửa hoặc có liên kết.',
                  ),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => unawaited(
                          task(() async {
                            await widget.controller.change(
                              (s) => undoImport(s, preview!.batchId),
                              'undo_import',
                            );
                            if (context.mounted) Navigator.pop(context);
                          }),
                        ),
                  child: Text(t('Undo this batch', 'Hoàn tác lần nhập này')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('Done', 'Xong')),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
