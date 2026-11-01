part of 'app.dart';

extension _Editors on _SpendHomeState {
  Map<String, String> get accountOptions => {
    for (final a in s.accounts.where((a) => !a.archived))
      a.id: '${a.name} · ${a.currency}',
  };
  Future<void> accountsPage() => pageRoute(
    'Accounts · manual balances',
    'Tài khoản · số dư thủ công',
    (context) => AnimatedBuilder(
      animation: c,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t(
              'Asset balances are positive; debts are negative. Opening balances are not income.',
              'Tài sản dùng số dư dương; nợ dùng số dư âm. Số dư đầu kỳ không phải thu nhập.',
            ),
          ),
          for (final a in s.accounts)
            Card(
              child: ListTile(
                title: Text(
                  '${a.name}${a.archived ? ' · ${t('archived', 'đã lưu trữ')}' : ''}',
                ),
                subtitle: Text('${a.currency} · ${a.asOf}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') unawaited(accountEditor(a));
                    if (v == 'reconcile') unawaited(reconcile(a));
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(t('Edit / archive', 'Sửa / lưu trữ')),
                    ),
                    PopupMenuItem(
                      value: 'reconcile',
                      child: Text(t('Reconcile balance', 'Đối chiếu số dư')),
                    ),
                  ],
                ),
                onTap: () => unawaited(accountEditor(a)),
              ),
            ),
          button(
            'Add account',
            'Thêm tài khoản',
            Icons.add,
            () => unawaited(accountEditor()),
          ),
        ],
      ),
    ),
  );
  Future<void> accountEditor([Account? a]) => edit(
    'Account',
    'Tài khoản',
    [
      const EditField('name', 'Name', 'Tên'),
      EditField(
        'currency',
        'Currency',
        'Loại tiền',
        options: {
          for (final key in a == null ? scales.keys : [a.currency]) key: key,
        },
      ),
      EditField(
        'type',
        'Type',
        'Loại',
        options: {
          'cash': t('Cash', 'Tiền mặt'),
          'bank': t('Bank', 'Ngân hàng'),
          'wallet': t('E-wallet', 'Ví điện tử'),
          'savings': t('Savings', 'Tiết kiệm'),
          'credit': t('Credit card (debt negative)', 'Thẻ tín dụng (nợ âm)'),
          'loan': t('Loan (debt negative)', 'Khoản vay (nợ âm)'),
          'other': t('Other', 'Khác'),
        },
      ),
      const EditField(
        'opening',
        'Opening balance · decimal dot',
        'Số dư đầu kỳ · dấu thập phân chấm',
        number: true,
      ),
      const EditField(
        'asOf',
        'Opening as of YYYY-MM-DD',
        'Ngày số dư đầu kỳ YYYY-MM-DD',
      ),
      const EditField(
        'liquid',
        'Liquid funds (savings/debts excluded by default)',
        'Tiền thanh khoản (mặc định loại tiết kiệm/nợ)',
        toggle: true,
      ),
      const EditField(
        'archived',
        'Archive, keep all history',
        'Lưu trữ, giữ nguyên lịch sử',
        toggle: true,
      ),
    ],
    {
      'name': a?.name ?? '',
      'currency': a?.currency ?? s.currency,
      'type': a?.type ?? 'cash',
      'opening': decimalMoney(
        a?.opening ?? BigInt.zero,
        a?.currency ?? s.currency,
      ),
      'asOf': a?.asOf ?? today,
      'liquid': a?.liquid ?? true,
      'archived': a?.archived ?? false,
    },
    (v) async {
      final next = Account(
        id: a?.id ?? newId(),
        name: v['name'] as String,
        currency: v['currency'] as String,
        type: v['type'] as String,
        opening: minor(v['opening'] as String, v['currency'] as String),
        asOf: v['asOf'] as String,
        liquid: v['liquid'] == true,
        archived: v['archived'] == true,
      );
      await c.change(
        (s) => s.copy({
          'accounts': [
            for (final x in s.accounts)
              if (x.id != next.id) x.toJson(),
            next.toJson(),
          ],
        }),
        'save_account',
      );
    },
  );
  Future<void> reconcile(Account a) => edit(
    'Reconcile account',
    'Đối chiếu tài khoản',
    [
      EditField(
        'balance',
        'Actual signed balance (${a.currency})',
        'Số dư thực tế có dấu (${a.currency})',
        number: true,
      ),
      const EditField('note', 'Reason', 'Lý do'),
    ],
    {
      'balance': decimalMoney(balances(s, today)[a.id]!, a.currency),
      'note': '',
    },
    (v) async {
      final target = minor(v['balance'] as String, a.currency),
          delta = target - balances(s, today)[a.id]!;
      if (delta != BigInt.zero)
        await c.putEntry(
          Entry(
            id: newId(),
            account: a.id,
            kind: 'adjustment',
            amount: delta,
            when: localTimestamp(today, s.zone),
            note: v['note'] as String,
          ),
        );
    },
  );
  Future<void> transactionEditor([Entry? e, Entry? refund]) async {
    if (accountOptions.isEmpty) {
      await accountEditor();
      if (accountOptions.isEmpty) return;
    }
    final account = e?.account ?? refund?.account ?? accountOptions.keys.first,
        a = s.accounts.firstWhere((a) => a.id == account),
        kind = e?.kind ?? (refund == null ? 'expense' : 'refund');
    await edit(
      'Transaction',
      'Giao dịch',
      [
        EditField(
          'kind',
          'Type',
          'Loại',
          options: refund != null
              ? {'refund': kindLabel('refund')}
              : {
                  for (final k in [
                    'expense',
                    'income',
                    'transfer',
                    'adjustment',
                    if (e?.kind == 'refund') 'refund',
                  ])
                    k: kindLabel(k),
                },
        ),
        EditField(
          'account',
          'Account',
          'Tài khoản',
          options: {...accountOptions, if (e != null) e.account: a.name},
        ),
        const EditField(
          'amount',
          'Amount (positive; adjustments may be signed; decimal dot)',
          'Số tiền dương (điều chỉnh có thể có dấu; thập phân chấm)',
          number: true,
        ),
        const EditField(
          'date',
          'Transaction date YYYY-MM-DD',
          'Ngày giao dịch YYYY-MM-DD',
        ),
        EditField(
          'category',
          'Category (must match type)',
          'Danh mục (phải khớp loại)',
          options: {
            '': t('Uncategorized', 'Chưa phân loại'),
            for (final x in s.categories.where(
              (x) => !x.archived || x.id == e?.category,
            ))
              x.id: x.name,
          },
          requiredValue: false,
        ),
        EditField(
          'payee',
          'Payee / merchant',
          'Đối tác / cửa hàng',
          requiredValue: false,
          suggestions: s.entries.reversed
              .map((e) => e.payee)
              .where((e) => e.isNotEmpty)
              .toSet()
              .take(8)
              .toList(),
        ),
        const EditField('note', 'Note', 'Ghi chú', requiredValue: false),
        const EditField(
          'tags',
          'Tags, comma separated',
          'Nhãn, cách nhau dấu phẩy',
          requiredValue: false,
        ),
        EditField(
          'status',
          'Status',
          'Trạng thái',
          options: {
            'posted': t(
              'Posted (changes real balance)',
              'Đã ghi sổ (đổi số dư thật)',
            ),
            'pending': t('Pending (projection only)', 'Dự kiến (chỉ dự báo)'),
          },
        ),
        EditField(
          'to',
          'Transfer destination (transfers only)',
          'Tài khoản nhận (chỉ chuyển khoản)',
          options: {'': t('None', 'Không'), ...accountOptions},
          requiredValue: false,
        ),
        const EditField(
          'rate',
          'FX rate: destination major units per source unit',
          'Tỷ giá: đơn vị tiền đích trên 1 đơn vị tiền nguồn',
          number: true,
          requiredValue: false,
        ),
        const EditField(
          'fee',
          'Transfer fee in source currency',
          'Phí chuyển theo tiền nguồn',
          number: true,
          requiredValue: false,
        ),
      ],
      {
        'kind': kind,
        'account': account,
        'amount': decimalMoney(
          e?.kind == 'adjustment'
              ? e!.amount
              : (e?.amount.abs() ?? refund?.amount.abs() ?? BigInt.one),
          a.currency,
        ),
        'date': e == null ? today : reportDay(e.when, s.zone),
        'category': e?.category ?? refund?.category ?? '',
        'payee': e?.payee ?? refund?.payee ?? '',
        'note': e?.note ?? '',
        'tags': e?.tags.join(', ') ?? '',
        'status': e?.status ?? 'posted',
        'to': e?.toAccount ?? '',
        'rate': e?.rate ?? '',
        'fee': decimalMoney(e?.fee ?? BigInt.zero, a.currency),
      },
      (v) async {
        final ac = s.accounts.firstWhere((a) => a.id == v['account']),
            type = v['kind'] as String,
            isTransfer = type == 'transfer',
            enteredAmount = minor(v['amount'] as String, ac.currency),
            amount = type == 'expense' || type == 'transfer'
                ? -enteredAmount
                : enteredAmount,
            to = isTransfer ? v['to'] as String : null,
            dest = isTransfer ? s.accounts.firstWhere((a) => a.id == to) : null,
            rate = (v['rate'] as String).isEmpty ? null : v['rate'] as String;
        if (type != 'adjustment' && enteredAmount.isNegative)
          throw const FormatException(
            'Enter a positive amount; type controls direction',
          );
        final next = Entry(
          id: e?.id ?? newId(),
          account: ac.id,
          kind: type,
          amount: amount,
          when: e != null && reportDay(e.when, s.zone) == v['date']
              ? e.when
              : localTimestamp(v['date'] as String, s.zone),
          created: e?.created,
          payee: v['payee'] as String,
          note: v['note'] as String,
          tags: (v['tags'] as String)
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList(),
          status: v['status'] as String,
          category: (v['category'] as String? ?? '').isEmpty
              ? null
              : v['category'] as String,
          toAccount: to,
          target: isTransfer
              ? (ac.currency == dest!.currency
                    ? -amount
                    : convert(-amount, ac.currency, dest.currency, rate ?? ''))
              : null,
          rate: isTransfer ? rate : null,
          fee: isTransfer
              ? minor(
                  (v['fee'] as String).isEmpty ? '0' : v['fee'] as String,
                  ac.currency,
                )
              : BigInt.zero,
          refundOf: type == 'refund' ? (e?.refundOf ?? refund?.id) : null,
          batch: e?.batch,
          occurrence: e?.occurrence,
        );
        await c.putEntry(next);
      },
    );
  }

  Future<void> categoriesPage() => pageRoute(
    'Categories',
    'Danh mục',
    (context) => AnimatedBuilder(
      animation: c,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final x in s.categories)
            ListTile(
              title: Text(x.name),
              subtitle: Text(
                '${kindLabel(x.kind)}${x.archived ? ' · ${t('archived', 'lưu trữ')}' : ''}',
              ),
              leading: Icon(
                Icons.category,
                color: Color(
                  int.parse(x.color.substring(1), radix: 16) | 0xff000000,
                ),
              ),
              onTap: () => unawaited(categoryEditor(x)),
            ),
          button(
            'Add category',
            'Thêm danh mục',
            Icons.add,
            () => unawaited(categoryEditor()),
          ),
        ],
      ),
    ),
  );
  Future<void> categoryEditor([Category? x]) => edit(
    'Category',
    'Danh mục',
    [
      const EditField('name', 'Name', 'Tên'),
      EditField(
        'kind',
        'Classification',
        'Phân loại',
        options: {
          'expense': kindLabel('expense'),
          'income': kindLabel('income'),
        },
      ),
      EditField(
        'parent',
        'Parent',
        'Danh mục cha',
        options: {
          '': t('None', 'Không'),
          for (final p in s.categories.where((p) => p.id != x?.id))
            p.id: p.name,
        },
        requiredValue: false,
      ),
      const EditField('color', 'Color #RRGGBB', 'Màu #RRGGBB'),
      EditField(
        'icon',
        'Icon',
        'Biểu tượng',
        options: {
          'category': t('Category', 'Danh mục'),
          'food': t('Food', 'Ăn uống'),
          'home': t('Home', 'Nhà cửa'),
          'travel': t('Travel', 'Đi lại'),
          'work': t('Work', 'Công việc'),
        },
      ),
      const EditField(
        'archived',
        'Archive (retain transactions)',
        'Lưu trữ (giữ giao dịch)',
        toggle: true,
      ),
    ],
    {
      'name': x?.name ?? '',
      'kind': x?.kind ?? 'expense',
      'parent': x?.parent ?? '',
      'color': x?.color ?? '#7C3AED',
      'icon': x?.icon ?? 'category',
      'archived': x?.archived ?? false,
    },
    (v) async {
      final next = Category(
        id: x?.id ?? newId(),
        name: v['name'] as String,
        kind: v['kind'] as String,
        parent: v['parent'] == '' ? null : v['parent'] as String?,
        color: v['color'] as String,
        icon: v['icon'] as String,
        archived: v['archived'] == true,
      );
      await c.change(
        (s) => s.copy({
          'categories': [
            for (final a in s.categories)
              if (a.id != next.id) a.toJson(),
            next.toJson(),
          ],
        }),
        'save_category',
      );
    },
  );
  Future<void> budgetEditor([Budget? b]) => edit(
    'Budget',
    'Ngân sách',
    [
      const EditField('name', 'Name', 'Tên'),
      EditField(
        'currency',
        'Currency',
        'Tiền tệ',
        options: {for (final key in scales.keys) key: key},
      ),
      const EditField(
        'limit',
        'Limit (decimal dot)',
        'Hạn mức (thập phân chấm)',
        number: true,
      ),
      const EditField(
        'start',
        'Start inclusive YYYY-MM-DD',
        'Bắt đầu bao gồm YYYY-MM-DD',
      ),
      const EditField(
        'end',
        'End excluded YYYY-MM-DD',
        'Kết thúc không gồm YYYY-MM-DD',
      ),
      EditField(
        'account',
        'Account scope',
        'Phạm vi tài khoản',
        options: {
          '': t('All in currency', 'Tất cả cùng loại tiền'),
          ...accountOptions,
        },
        requiredValue: false,
      ),
      EditField(
        'category',
        'Category scope',
        'Phạm vi danh mục',
        options: {
          '': t('All expenses', 'Tất cả khoản chi'),
          for (final x in s.categories.where((x) => x.kind == 'expense'))
            x.id: x.name,
        },
        requiredValue: false,
      ),
      const EditField(
        'rollover',
        'Carry unused previous equal period (one period only)',
        'Chuyển dư kỳ liền trước cùng độ dài (một kỳ)',
        toggle: true,
      ),
    ],
    {
      'name': b?.name ?? '',
      'currency': b?.currency ?? s.currency,
      'limit': decimalMoney(b?.limit ?? BigInt.zero, b?.currency ?? s.currency),
      'start': b?.start ?? from,
      'end': b?.end ?? until,
      'account': b?.account ?? '',
      'category': b?.category ?? '',
      'rollover': b?.rollover ?? false,
    },
    (v) async {
      final next = Budget(
        id: b?.id ?? newId(),
        name: v['name'] as String,
        currency: v['currency'] as String,
        start: v['start'] as String,
        end: v['end'] as String,
        limit: minor(v['limit'] as String, v['currency'] as String),
        account: v['account'] == '' ? null : v['account'] as String?,
        category: v['category'] == '' ? null : v['category'] as String?,
        rollover: v['rollover'] == true,
      );
      await c.change(
        (s) => s.copy({
          'budgets': [
            for (final x in s.budgets)
              if (x.id != next.id) x.toJson(),
            next.toJson(),
          ],
        }),
        'save_budget',
      );
    },
  );
  Future<void> goalEditor([Goal? g]) async {
    if (accountOptions.isEmpty) {
      await accountEditor();
      if (accountOptions.isEmpty) return;
    }
    final a = s.accounts.firstWhere(
      (a) => a.id == (g?.account ?? accountOptions.keys.first),
    );
    await edit(
      'Savings reserve',
      'Khoản dành mục tiêu',
      [
        const EditField('name', 'Name', 'Tên'),
        EditField(
          'account',
          'Funding account',
          'Tài khoản dành tiền',
          options: accountOptions,
        ),
        const EditField(
          'target',
          'Target in account currency',
          'Mục tiêu theo tiền tài khoản',
          number: true,
        ),
        const EditField(
          'reserved',
          'Already reserved (not a second transaction)',
          'Đã dành riêng (không ghi thêm giao dịch)',
          number: true,
        ),
        const EditField('due', 'Due YYYY-MM-DD', 'Hạn YYYY-MM-DD'),
      ],
      {
        'name': g?.name ?? '',
        'account': a.id,
        'target': decimalMoney(g?.target ?? BigInt.one, a.currency),
        'reserved': decimalMoney(g?.reserved ?? BigInt.zero, a.currency),
        'due': g?.due ?? end,
      },
      (v) async {
        final ac = s.accounts.firstWhere((a) => a.id == v['account']),
            next = Goal(
              id: g?.id ?? newId(),
              name: v['name'] as String,
              account: ac.id,
              due: v['due'] as String,
              target: minor(v['target'] as String, ac.currency),
              reserved: minor(v['reserved'] as String, ac.currency),
            );
        await c.change(
          (s) => s.copy({
            'goals': [
              for (final x in s.goals)
                if (x.id != next.id) x.toJson(),
              next.toJson(),
            ],
          }),
          'save_goal',
        );
      },
    );
  }

  Future<void> billEditor([Bill? b]) async {
    if (accountOptions.isEmpty) {
      await accountEditor();
      if (accountOptions.isEmpty) return;
    }
    final a = s.accounts.firstWhere(
      (a) => a.id == (b?.account ?? accountOptions.keys.first),
    );
    await edit(
      'Recurring obligation / expected income',
      'Khoản định kỳ / thu nhập dự kiến',
      [
        const EditField('name', 'Name', 'Tên'),
        EditField('account', 'Account', 'Tài khoản', options: accountOptions),
        const EditField(
          'amount',
          'Signed amount (expense negative)',
          'Số tiền có dấu (chi âm)',
          number: true,
        ),
        const EditField(
          'due',
          'Anchor due date YYYY-MM-DD',
          'Ngày đến hạn gốc YYYY-MM-DD',
        ),
        EditField(
          'frequency',
          'Frequency',
          'Tần suất',
          options: {
            'once': t('Once', 'Một lần'),
            'weekly': t('Weekly', 'Hàng tuần'),
            'monthly': t('Monthly', 'Hàng tháng'),
            'yearly': t('Yearly', 'Hàng năm'),
          },
        ),
        EditField(
          'category',
          'Category',
          'Danh mục',
          options: {
            '': t('None', 'Không'),
            for (final x in s.categories) x.id: x.name,
          },
          requiredValue: false,
        ),
        const EditField(
          'reliable',
          'Reliable income (still excluded in conservative mode)',
          'Thu chắc chắn (vẫn loại khi tính thận trọng)',
          toggle: true,
        ),
        const EditField('enabled', 'Enabled', 'Đang áp dụng', toggle: true),
        const EditField(
          'remind',
          'Remind if OS permission is enabled',
          'Nhắc nếu đã bật quyền thông báo',
          toggle: true,
        ),
        EditField(
          'to',
          'Transfer destination, optional',
          'Tài khoản nhận, tùy chọn',
          options: {'': t('None', 'Không'), ...accountOptions},
          requiredValue: false,
        ),
        const EditField(
          'rate',
          'Explicit FX rate if currencies differ',
          'Tỷ giá nhập tay nếu khác loại tiền',
          number: true,
          requiredValue: false,
        ),
      ],
      {
        'name': b?.name ?? '',
        'account': a.id,
        'amount': decimalMoney(b?.amount ?? -BigInt.one, a.currency),
        'due': b?.due ?? today,
        'frequency': b?.frequency ?? 'monthly',
        'category': b?.category ?? '',
        'reliable': b?.reliable ?? false,
        'enabled': b?.enabled ?? true,
        'remind': b?.remind ?? false,
        'to': b?.toAccount ?? '',
        'rate': b?.rate ?? '',
      },
      (v) async {
        final ac = s.accounts.firstWhere((a) => a.id == v['account']),
            amount = minor(v['amount'] as String, ac.currency),
            to = v['to'] as String? ?? '',
            destination = to.isEmpty
                ? null
                : s.accounts.firstWhere((a) => a.id == to),
            rate = (v['rate'] as String).isEmpty ? null : v['rate'] as String,
            next = Bill(
              id: b?.id ?? newId(),
              name: v['name'] as String,
              account: ac.id,
              amount: amount,
              due: v['due'] as String,
              frequency: v['frequency'] as String,
              category: v['category'] == '' ? null : v['category'] as String?,
              reliable: v['reliable'] == true,
              enabled: v['enabled'] == true,
              remind: v['remind'] == true,
              toAccount: destination?.id,
              target: destination == null
                  ? null
                  : ac.currency == destination.currency
                  ? -amount
                  : convert(
                      -amount,
                      ac.currency,
                      destination.currency,
                      rate ?? '',
                    ),
              rate: rate,
            );
        await c.change(
          (s) => s.copy({
            'bills': [
              for (final x in s.bills)
                if (x.id != next.id) x.toJson(),
              next.toJson(),
            ],
          }),
          'save_bill',
        );
      },
    );
  }

  Future<void> rulesPage() => pageRoute(
    'Categorization rules',
    'Quy tắc phân loại',
    (context) => AnimatedBuilder(
      animation: c,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t(
              'First matching explicit text rule wins. Review import results before committing.',
              'Quy tắc văn bản đầu tiên khớp được áp dụng. Xem lại trước khi nhập.',
            ),
          ),
          for (final rule in s.rules)
            ListTile(
              title: Text(rule['contains'] as String),
              subtitle: Text(
                s.categories
                        .where((c) => c.id == rule['category'])
                        .firstOrNull
                        ?.name ??
                    '',
              ),
              trailing: IconButton(
                tooltip: t('Delete rule', 'Xóa quy tắc'),
                onPressed: () => unawaited(
                  run(
                    () => c.change(
                      (s) => s.copy({
                        'rules': s.rules
                            .where((r) => r['id'] != rule['id'])
                            .toList(),
                      }),
                      'delete_rule',
                    ),
                  ),
                ),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          button(
            'Add text rule',
            'Thêm quy tắc văn bản',
            Icons.add,
            () => unawaited(
              edit(
                'Text rule',
                'Quy tắc văn bản',
                [
                  const EditField('contains', 'Payee contains', 'Đối tác chứa'),
                  EditField(
                    'category',
                    'Assign category',
                    'Gán danh mục',
                    options: {
                      for (final c in s.categories.where((c) => !c.archived))
                        c.id: c.name,
                    },
                  ),
                ],
                {},
                (v) async {
                  if ((v['contains'] as String).trim().isEmpty)
                    throw const FormatException('Empty rule');
                  await c.change(
                    (s) => s.copy({
                      'rules': [
                        ...s.rules,
                        {
                          'id': newId(),
                          'contains': v['contains'],
                          'category': v['category'],
                        },
                      ],
                    }),
                    'save_rule',
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> settingsPage() => pageRoute(
    'Settings and privacy',
    'Cài đặt và riêng tư',
    (context) => AnimatedBuilder(
      animation: c,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          widget.settings,
          SwitchListTile(
            title: Text(t('Hide amounts', 'Ẩn số tiền')),
            value: s.settings['hideAmounts'] == true,
            onChanged: (v) => unawaited(
              run(
                () => c.change(
                  (s) => s.copy({
                    'settings': {...s.settings, 'hideAmounts': v},
                  }),
                  'privacy_mask',
                ),
              ),
            ),
          ),
          button(
            'Currency, timezone and buffer',
            'Tiền tệ, múi giờ và dự phòng',
            Icons.tune,
            () => unawaited(
              edit(
                'Financial settings',
                'Cài đặt tài chính',
                [
                  EditField(
                    'currency',
                    'Report currency (no automatic conversion)',
                    'Tiền báo cáo (không tự quy đổi)',
                    options: {for (final key in scales.keys) key: key},
                  ),
                  const EditField(
                    'zone',
                    'Reporting IANA timezone',
                    'Múi giờ IANA cho báo cáo',
                  ),
                  EditField(
                    'dateFormat',
                    'Date display',
                    'Hiển thị ngày',
                    options: {
                      'locale': t('Regional format', 'Theo vùng'),
                      'iso': 'YYYY-MM-DD',
                    },
                  ),
                  const EditField(
                    'buffer',
                    'Minimum cash buffer in report currency',
                    'Dự phòng tối thiểu theo tiền báo cáo',
                    number: true,
                  ),
                ],
                {
                  'currency': s.currency,
                  'zone': s.zone,
                  'dateFormat': s.settings['dateFormat'] ?? 'locale',
                  'buffer': decimalMoney(
                    BigInt.parse(s.settings['buffer'] as String? ?? '0'),
                    s.currency,
                  ),
                },
                (v) async {
                  location(v['zone'] as String);
                  final buffer = minor(
                    v['buffer'] as String,
                    v['currency'] as String,
                  );
                  if (buffer.isNegative)
                    throw const FormatException('Negative buffer');
                  await c.change(
                    (s) => s.copy({
                      'settings': {...s.settings, ...v, 'buffer': '$buffer'},
                    }),
                    'financial_settings',
                  );
                },
              ),
            ),
          ),
          if (reminders.supported)
            button(
              'Enable local reminders',
              'Bật nhắc cục bộ',
              Icons.notifications_outlined,
              () => unawaited(
                run(() async {
                  final allowed = await reminders.request();
                  if (!allowed) throw StateError('Permission denied');
                  await c.change(
                    (s) => s.copy({
                      'settings': {...s.settings, 'notifications': true},
                    }),
                    'enable_reminders',
                  );
                }),
              ),
            ),
          button(
            'Disable reminders',
            'Tắt nhắc',
            Icons.notifications_off_outlined,
            () => unawaited(
              run(
                () => c.change(
                  (s) => s.copy({
                    'settings': {...s.settings, 'notifications': false},
                  }),
                  'disable_reminders',
                ),
              ),
            ),
          ),
          button(
            'Check local data integrity',
            'Kiểm tra dữ liệu cục bộ',
            Icons.verified_outlined,
            () => unawaited(
              run(() async {
                final result = await c.store!.integrity();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result == 'ok'
                          ? t(
                              'Integrity check passed',
                              'Kiểm tra dữ liệu thành công',
                            )
                          : t(
                              'Integrity check failed; export and preserve data',
                              'Kiểm tra lỗi; hãy xuất và giữ nguyên dữ liệu',
                            ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Text(
            t(
              'All financial data is local and is not encrypted at rest by this app. No bank login, SMS reading, account, cloud sync or remote analytics. Exported files contain private data. Browser storage can be cleared. Notifications contain no amounts or merchants; OS delivery may be delayed.',
              'Dữ liệu tài chính ở máy và chưa được app mã hóa khi lưu. Không đăng nhập ngân hàng, đọc SMS, tài khoản, đồng bộ cloud hay phân tích từ xa. File xuất chứa dữ liệu riêng tư. Trình duyệt có thể xóa dữ liệu. Thông báo không chứa số tiền hay đối tác; OS có thể giao trễ.',
            ),
          ),
          if (privacy.supported)
            button(
              s.settings['deviceLock'] == true
                  ? 'Disable device lock'
                  : 'Enable biometrics / device PIN',
              s.settings['deviceLock'] == true
                  ? 'Tắt khóa thiết bị'
                  : 'Bật sinh trắc / PIN thiết bị',
              Icons.lock_outline,
              () => unawaited(
                run(() async {
                  if (!await privacy.available())
                    throw StateError('Device authentication not configured');
                  if (!await privacy.unlock(
                    t(
                      'Authorize Handy Spend privacy lock',
                      'Xác nhận khóa riêng tư Handy Spend',
                    ),
                  ))
                    return;
                  await c.change(
                    (s) => s.copy({
                      'settings': {
                        ...s.settings,
                        'deviceLock': s.settings['deviceLock'] != true,
                        'lockSeconds': s.settings['lockSeconds'] ?? 60,
                      },
                    }),
                    'device_lock',
                  );
                }),
              ),
            ),
          if (privacy.supported)
            button(
              'Lock timeout',
              'Thời gian tự khóa',
              Icons.timer_outlined,
              () => unawaited(
                edit(
                  'Lock timeout',
                  'Thời gian tự khóa',
                  [
                    EditField(
                      'seconds',
                      'After leaving app',
                      'Sau khi rời app',
                      options: {
                        '0': t('Immediately', 'Ngay lập tức'),
                        '30': t('30 seconds', '30 giây'),
                        '60': t('1 minute', '1 phút'),
                        '300': t('5 minutes', '5 phút'),
                      },
                    ),
                  ],
                  {'seconds': '${s.settings['lockSeconds'] ?? 60}'},
                  (v) async {
                    await c.change(
                      (s) => s.copy({
                        'settings': {
                          ...s.settings,
                          'lockSeconds': int.parse(v['seconds'] as String),
                        },
                      }),
                      'lock_timeout',
                    );
                  },
                ),
              ),
            ),
          Text(
            t(
              'Device lock uses OS credentials; it does not encrypt the database or exports. Configure a device PIN/biometrics first. Hide amounts is only a visual mask. Web has no verified device-lock adapter.',
              'Khóa dùng xác thực của hệ điều hành; không mã hóa database hay file xuất. Hãy cấu hình PIN/sinh trắc của thiết bị trước. Ẩn số tiền chỉ che giao diện. Web chưa có adapter khóa thiết bị được xác nhận.',
            ),
          ),
        ],
      ),
    ),
  );
}
