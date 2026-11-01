part of 'import_page.dart';

/// A labelled choice for the mapping step.
Widget _choice(
  ImportPageState w,
  String label,
  String value,
  Map<String, String> options,
  ValueChanged<String> change, {
  Key? key,
}) => Padding(
  padding: const EdgeInsets.only(bottom: HandySpace.m),
  child: HandyField(
    label: label,
    child: DropdownButtonFormField<String>(
      key: key,
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      items: [
        for (final o in options.entries)
          DropdownMenuItem(
            value: o.key,
            child: Text(o.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: w.busy
          ? null
          : (v) {
              if (v != null) w.update(() => change(v));
            },
    ),
  ),
);

Widget _column(
  ImportPageState w,
  String label,
  int value,
  ValueChanged<int> change,
  Key key,
) => _choice(
  w,
  label,
  '$value',
  {
    '-1': tr(w.context, 'Not in this file', 'Không có trong file'),
    for (var i = 0; i < w.rows!.first.length; i++)
      '$i': '${i + 1}. ${w.rows!.first[i]}',
  },
  (v) => change(int.parse(v)),
  key: key,
);

List<Widget> chooseStep(ImportPageState w) {
  final context = w.context;
  return [
    HandyEmpty(
      title: tr(
        context,
        'A CSV or Excel file from your bank',
        'File CSV hoặc Excel từ ngân hàng',
      ),
      message: tr(
        context,
        'Read on this device only. No bank login, no SMS. Up to 12 MB. On a computer you can also drop the file onto the window.',
        'Chỉ đọc trên máy này. Không đăng nhập ngân hàng, không đọc SMS. Tối đa 12 MB. Trên máy tính có thể kéo file thả vào cửa sổ.',
      ),
    ),
  ];
}

List<Widget> mapStep(ImportPageState w) {
  final context = w.context;
  final s = w.s;
  final theme = Theme.of(context);
  return [
    Row(
      children: [
        const Icon(Icons.description_outlined, size: 20),
        const SizedBox(width: HandySpace.s),
        Expanded(
          child: Text(
            tr(
              context,
              '${w.file!.name} · ${w.rows!.length - 1} rows',
              '${w.file!.name} · ${w.rows!.length - 1} dòng',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: w.busy ? null : () => unawaited(w.task(w.pick)),
          child: Text(tr(context, 'Another file', 'File khác')),
        ),
      ],
    ),
    const SizedBox(height: HandySpace.s),
    HandyGroup(children: [w.sample()]),
    HandyLabel(tr(context, 'Into', 'Nhập vào')),
    _choice(
      w,
      tr(context, 'Account', 'Tài khoản'),
      w.account,
      {for (final a in w.scope.openAccounts) a.id: '${a.name} · ${a.currency}'},
      (v) => w.account = v,
      key: const Key('import-account'),
    ),
    if (s.profiles.isNotEmpty)
      _choice(
        w,
        tr(context, 'Saved column profile', 'Hồ sơ cột đã lưu'),
        '',
        {
          '': tr(context, 'None', 'Không dùng'),
          for (final p in s.profiles) p['id'] as String: p['name'] as String,
        },
        (id) {
          if (id.isNotEmpty) w.useProfile(id);
        },
      ),
    HandyLabel(tr(context, 'Columns', 'Các cột')),
    _column(
      w,
      tr(context, 'Date', 'Ngày'),
      w.date,
      (v) => w.date = v,
      const Key('map-date'),
    ),
    _column(
      w,
      tr(context, 'Payee or description', 'Đối tác hoặc mô tả'),
      w.payee,
      (v) => w.payee = v,
      const Key('map-payee'),
    ),
    _column(
      w,
      tr(context, 'Amount with sign', 'Số tiền có dấu'),
      w.amount,
      (v) => w.amount = v,
      const Key('map-amount'),
    ),
    Text(
      tr(
        context,
        'Or leave it out and use separate money-out and money-in columns:',
        'Hoặc bỏ trống và dùng hai cột tiền ra, tiền vào riêng:',
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        color: HandyColors.of(context).muted,
      ),
    ),
    const SizedBox(height: HandySpace.s),
    _column(
      w,
      tr(context, 'Money out', 'Tiền ra'),
      w.debit,
      (v) => w.debit = v,
      const Key('map-debit'),
    ),
    _column(
      w,
      tr(context, 'Money in', 'Tiền vào'),
      w.credit,
      (v) => w.credit = v,
      const Key('map-credit'),
    ),
    _column(
      w,
      tr(
        context,
        'Balance after (to check against)',
        'Số dư sau (để đối chiếu)',
      ),
      w.balance,
      (v) => w.balance = v,
      const Key('map-balance'),
    ),
    HandyLabel(tr(context, 'How it is written', 'Cách ghi trong file')),
    _choice(w, tr(context, 'Dates', 'Ngày'), w.dateFormat, {
      'dmy': 'DD/MM/YYYY',
      'ymd': 'YYYY-MM-DD',
      'mdy': 'MM/DD/YYYY',
      'excel': tr(context, 'Excel day number', 'Số ngày của Excel'),
    }, (v) => w.dateFormat = v),
    Row(
      children: [
        Expanded(
          child: _choice(
            w,
            tr(context, 'Decimal mark', 'Dấu thập phân'),
            w.decimal,
            {'.': '.', ',': ','},
            (v) => w.decimal = v,
          ),
        ),
        const SizedBox(width: HandySpace.m),
        Expanded(
          child:
              _choice(w, tr(context, 'Thousands', 'Dấu hàng nghìn'), w.group, {
                ',': ',',
                '.': '.',
                ' ': tr(context, 'Space', 'Khoảng trắng'),
                '': tr(context, 'None', 'Không'),
              }, (v) => w.group = v),
        ),
      ],
    ),
    Row(
      children: [
        Expanded(
          child: _choice(
            w,
            tr(context, 'Columns split by', 'Cột cách nhau bởi'),
            w.delimiter,
            {
              ',': tr(context, 'Comma', 'Dấu phẩy'),
              ';': tr(context, 'Semicolon', 'Chấm phẩy'),
              '\t': 'Tab',
            },
            (v) => w.delimiter = v,
          ),
        ),
        const SizedBox(width: HandySpace.m),
        Expanded(
          child: _choice(
            w,
            tr(context, 'Text encoding', 'Bảng mã'),
            w.encoding,
            {'utf8': 'UTF-8', 'latin1': 'Latin-1'},
            (v) => w.encoding = v,
          ),
        ),
      ],
    ),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: w.busy ? null : () => unawaited(w.task(w.parse)),
        child: Text(tr(context, 'Read the file again', 'Đọc lại file')),
      ),
    ),
    SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(tr(context, 'Newest rows first', 'Dòng mới nhất ở trên')),
      value: w.newestFirst,
      onChanged: w.busy ? null : (v) => w.update(() => w.newestFirst = v),
    ),
    SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(tr(context, 'Flip signs', 'Đảo dấu số tiền')),
      subtitle: Text(
        tr(
          context,
          'When spending shows as positive.',
          'Khi khoản chi hiện là số dương.',
        ),
      ),
      value: w.reverse,
      onChanged: w.busy ? null : (v) => w.update(() => w.reverse = v),
    ),
  ];
}

List<Widget> reviewStep(ImportPageState w) {
  final context = w.context;
  final c = HandyColors.of(context);
  final theme = Theme.of(context);
  final rows = w.preview!.rows;
  final fresh = rows
      .where((r) => r.status == 'new' || r.status == 'reviewed')
      .length;
  final errors = rows.where((r) => r.status == 'error').length;
  final doubts = rows.length - fresh - errors;
  final page = rows.skip(w.reviewPage * 100).take(100);
  return [
    Text(
      tr(
        context,
        '$fresh new · $doubts may be duplicates · $errors could not be read',
        '$fresh mới · $doubts có thể trùng · $errors không đọc được',
      ),
      key: const Key('import-counts'),
      style: theme.textTheme.titleMedium,
    ),
    const SizedBox(height: HandySpace.xs),
    Text(
      tr(
        context,
        'Possible duplicates and reversals start unticked: same amount, similar payee, a day either side. Transfers and refunds are never guessed; open a row to mark one.',
        'Dòng có thể trùng hoặc đảo bắt đầu ở trạng thái bỏ chọn: cùng số tiền, đối tác gần giống, lệch một ngày. Không tự đoán chuyển khoản hay hoàn tiền; mở dòng để đánh dấu.',
      ),
      style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
    ),
    const SizedBox(height: HandySpace.m),
    HandyGroup(
      children: [
        for (final r in page)
          CheckboxListTile(
            key: Key('import-row-${r.number}'),
            value: w.selected.contains(r.number),
            onChanged:
                w.busy || r.entry == null || r.status == 'needs classification'
                ? null
                : (v) => w.update(
                    () => v == true
                        ? w.selected.add(r.number)
                        : w.selected.remove(r.number),
                  ),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              r.entry == null
                  ? tr(
                      context,
                      'Row ${r.number} · could not be read',
                      'Dòng ${r.number} · không đọc được',
                    )
                  : '${r.entry!.payee.isEmpty ? w.rowKind(r.entry!.kind) : r.entry!.payee}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (r.entry != null) ...[
                  dayLabel(
                    context,
                    w.scope,
                    reportDay(r.entry!.when, w.s.zone),
                  ),
                  w.rowKind(r.entry!.kind),
                  w.amountOf(r.entry!),
                ],
                switch (r.status) {
                  'new' => tr(context, 'new', 'mới'),
                  'reviewed' => tr(context, 'checked by you', 'bạn đã sửa'),
                  'error' => tr(
                    context,
                    'check date, amount and columns',
                    'kiểm tra ngày, số tiền và cột',
                  ),
                  'needs classification' => tr(
                    context,
                    'money into a debt: open to classify',
                    'tiền vào khoản nợ: mở để phân loại',
                  ),
                  _ => tr(context, 'may be a duplicate', 'có thể trùng'),
                },
              ].join(' · '),
              style: TextStyle(
                color: r.status == 'error' || r.status == 'needs classification'
                    ? c.negative
                    : null,
              ),
            ),
            secondary: r.entry == null
                ? null
                : IconButton(
                    tooltip: tr(context, 'Change this row', 'Sửa dòng này'),
                    onPressed: w.busy ? null : () => unawaited(w.review(r)),
                    icon: const Icon(Icons.edit_outlined),
                  ),
          ),
      ],
    ),
    if (rows.length > 100)
      Row(
        children: [
          Text(
            '${w.reviewPage * 100 + 1}–${min((w.reviewPage + 1) * 100, rows.length)} / ${rows.length}',
          ),
          const Spacer(),
          TextButton(
            onPressed: w.busy || w.reviewPage == 0
                ? null
                : () => w.update(() => w.reviewPage--),
            child: Text(tr(context, 'Previous', 'Trước')),
          ),
          TextButton(
            onPressed: w.busy || (w.reviewPage + 1) * 100 >= rows.length
                ? null
                : () => w.update(() => w.reviewPage++),
            child: Text(tr(context, 'Next', 'Tiếp')),
          ),
        ],
      ),
    Wrap(
      spacing: HandySpace.s,
      children: [
        TextButton(
          onPressed: w.busy ? null : () => w.update(w.selected.clear),
          child: Text(tr(context, 'Untick all', 'Bỏ chọn tất cả')),
        ),
        TextButton(
          onPressed: w.busy ? null : () => w.update(() => w.preview = null),
          child: Text(tr(context, 'Back to columns', 'Quay lại ghép cột')),
        ),
      ],
    ),
    if (errors > 0)
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          tr(
            context,
            'Import the readable rows anyway',
            'Vẫn nhập các dòng đọc được',
          ),
        ),
        value: w.partial,
        onChanged: w.busy ? null : (v) => w.update(() => w.partial = v),
      ),
    CheckboxListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        tr(
          context,
          'Remember these columns (Pro)',
          'Nhớ cách ghép cột này (Pro)',
        ),
      ),
      value: w.saveProfile,
      onChanged: w.busy || !w.scope.pro(context)
          ? null
          : (v) => w.update(() => w.saveProfile = v == true),
    ),
  ];
}

List<Widget> doneStep(ImportPageState w) {
  final context = w.context;
  final record = w.s.imports
      .where((r) => r['id'] == w.preview?.batchId)
      .firstOrNull;
  final raw = record?['reconciliation'];
  final account = raw is Map
      ? w.s.accounts.where((a) => a.id == raw['account']).firstOrNull
      : null;
  String amount(String key) => moneyText(
    context,
    w.scope,
    BigInt.parse(raw[key] as String),
    account!.currency,
    sign: key == 'difference',
  );
  return [
    HandyNotice(
      tr(
        context,
        '${w.selected.length} entries are in the ledger.',
        'Đã ghi ${w.selected.length} giao dịch vào sổ.',
      ),
      tone: HandyTone.success,
    ),
    if (account != null && raw is Map)
      HandySection(
        title: tr(context, 'Against the statement', 'So với sao kê'),
        children: [
          HandyTile(
            title: tr(context, 'Statement balance', 'Số dư trên sao kê'),
            subtitle: dayLabel(context, w.scope, raw['asOf'] as String),
            trailing: Text(amount('statement')),
          ),
          HandyTile(
            title: tr(context, 'Ledger balance', 'Số dư trong sổ'),
            trailing: Text(amount('ledger')),
          ),
          HandyTile(
            key: const Key('import-difference'),
            title: tr(
              context,
              'Difference, left as it is',
              'Chênh lệch, giữ nguyên',
            ),
            trailing: Text(amount('difference')),
          ),
        ],
      )
    else
      Padding(
        padding: const EdgeInsets.only(top: HandySpace.l),
        child: Text(
          tr(
            context,
            'No balance column was matched, so nothing was checked. You can check the account by hand.',
            'Không ghép cột số dư nên chưa đối chiếu. Bạn có thể đối chiếu tài khoản bằng tay.',
          ),
        ),
      ),
    const SizedBox(height: HandySpace.l),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton(
        key: const Key('import-undo'),
        onPressed: w.busy ? null : () => unawaited(w.task(w.undoBatch)),
        child: Text(tr(context, 'Undo this import', 'Hoàn tác lần nhập này')),
      ),
    ),
  ];
}
