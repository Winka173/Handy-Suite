part of 'app.dart';

extension _Planning on _SpendHomeState {
  List<Widget> recurringTotals(String currency) {
    final ac = {for (final a in s.accounts) a.id: a},
        yearly = s.bills
            .where(
              (b) =>
                  b.enabled &&
                  b.amount.isNegative &&
                  b.toAccount == null &&
                  ac[b.account]!.currency == currency,
            )
            .fold(
              BigInt.zero,
              (BigInt n, b) =>
                  n +
                  b.amount.abs() *
                      BigInt.from(
                        b.frequency == 'weekly'
                            ? 52
                            : b.frequency == 'monthly'
                            ? 12
                            : b.frequency == 'yearly'
                            ? 1
                            : 0,
                      ),
            );
    return [
      amountRow(
        t('Yearly commitment estimate', 'Ước tính cam kết hàng năm'),
        yearly,
        currency: currency,
      ),
      amountRow(
        t('Monthly run-rate estimate', 'Ước tính chi phí mỗi tháng'),
        roundedRatio(yearly, BigInt.from(12)),
        currency: currency,
      ),
    ];
  }

  List<Widget> billRows({int limit = 30}) {
    final occurrences = upcoming(s, today, end).take(limit).toList();
    if (occurrences.isEmpty)
      return [
        Text(
          t(
            'No unpaid commitments in this horizon.',
            'Không có khoản chưa thanh toán trong khoảng này.',
          ),
        ),
      ];
    return [
      for (final o in occurrences)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(o.bill.name),
          subtitle: Text(
            '${dateLabel(o.date)}${o.date.compareTo(today) < 0 ? ' · ${t('OVERDUE', 'QUÁ HẠN')}' : ''}',
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') unawaited(billEditor(o.bill));
              if (v == 'paid')
                unawaited(
                  run(() async {
                    if (await confirm(
                      'Record this occurrence as an actual transaction today?',
                      'Ghi lần đến hạn này thành giao dịch thật hôm nay?',
                    ))
                      await c.putEntry(
                        o.post(s.zone, when: localTimestamp(today, s.zone)),
                      );
                  }),
                );
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'paid',
                child: Text(
                  t('Record payment / receipt', 'Ghi thanh toán / nhận tiền'),
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Text(t('Edit schedule', 'Sửa lịch')),
              ),
            ],
          ),
        ),
    ];
  }

  Widget plan() {
    final safe = safeToSpend(
          s,
          today,
          end,
          accounts: planningAccounts,
          conservative: conservative,
        ),
        projection = forecast(
          s,
          today,
          end,
          accounts: planningAccounts,
          includeIncome: !conservative,
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t(
            'ESTIMATES · verify manual balances before deciding. No financial advice or guarantee.',
            'ƯỚC TÍNH · đối chiếu số dư thủ công trước khi quyết định. Không phải tư vấn hay bảo đảm.',
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final days in [7, 30, 90])
              ChoiceChip(
                label: Text('$days ${t('days', 'ngày')}'),
                selected: horizon == days,
                onSelected: (v) {
                  if (days > 30 && !pro) {
                    unawaited(
                      pageRoute(
                        'Pro Lifetime',
                        'Pro trọn đời',
                        (_) => SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: widget.settings,
                        ),
                      ),
                    );
                    return;
                  }
                  refresh(() => horizon = days);
                },
              ),
          ],
        ),
        SwitchListTile(
          title: Text(
            t(
              'Conservative: posted funds only',
              'Thận trọng: chỉ tiền đã ghi sổ',
            ),
          ),
          subtitle: Text(
            t(
              'Otherwise include explicitly reliable scheduled income.',
              'Nếu tắt, cộng thu nhập theo lịch được đánh dấu chắc chắn.',
            ),
          ),
          value: conservative,
          onChanged: (v) => refresh(() => conservative = v),
        ),
        section('Included liquid accounts', 'Tài khoản thanh khoản được chọn', [
          for (final a in s.accounts.where(
            (a) => a.currency == s.currency && !a.archived && !a.liability,
          ))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(a.name),
              subtitle: Text(
                '${a.currency}${a.type == 'savings' ? ' · ${t('savings: explicit opt-in', 'tiết kiệm: chỉ cộng khi chủ động chọn')}' : ''}',
              ),
              value: planningAccounts.contains(a.id),
              onChanged: (v) => unawaited(
                run(() async {
                  final ids = Set<String>.of(planningAccounts);
                  v == true ? ids.add(a.id) : ids.remove(a.id);
                  await c.change(
                    (s) => s.copy({
                      'settings': {
                        ...s.settings,
                        'eligibleAccounts': ids.toList(),
                      },
                    }),
                    'planning_accounts',
                  );
                }),
              ),
            ),
        ]),
        section('Safe to Spend breakdown', 'Phân tích khoản có thể chi', [
          amountRow(
            t('Posted liquid balance', 'Số dư thanh khoản đã ghi sổ'),
            safe.liquid,
          ),
          amountRow(
            t('Included future inflows', 'Khoản vào tương lai được cộng'),
            safe.income,
          ),
          amountRow(
            t('Remaining committed outflows', 'Khoản ra còn cam kết'),
            -safe.committed,
          ),
          amountRow(
            t('Goal reserves (once only)', 'Tiền dành mục tiêu (trừ một lần)'),
            -safe.reserves,
          ),
          amountRow(t('Minimum buffer', 'Dự phòng tối thiểu'), -safe.buffer),
          const Divider(),
          amountRow(
            t('Available estimate', 'Ước tính có thể chi'),
            safe.available,
          ),
          amountRow(
            '${t('Per day', 'Mỗi ngày')} · ${safe.days} ${t('calendar days', 'ngày lịch')}',
            safe.perDay,
          ),
          if (safe.shortfall > BigInt.zero)
            amountRow(
              t(
                'Shortfall (not hidden as zero)',
                'Thiếu hụt (không che bằng số 0)',
              ),
              safe.shortfall,
            ),
        ]),
        section('Future balance · projection', 'Số dư tương lai · dự báo', [
          amountRow(
            t('Opening actual', 'Số dư thực ban đầu'),
            projection.opening,
          ),
          amountRow(
            t('Lowest projected balance', 'Số dư dự báo thấp nhất'),
            projection.lowest,
          ),
          amountRow(
            t('Ending projected balance', 'Số dư dự báo cuối kỳ'),
            projection.ending,
          ),
          Text(
            '${t('First shortfall', 'Ngày thiếu đầu tiên')}: ${projection.shortfall ?? t('none in this horizon', 'không có trong kỳ')}',
          ),
          Semantics(
            label: t(
              'Projected balance chart; exact daily values follow',
              'Biểu đồ số dư dự báo; bảng số chính xác ở dưới',
            ),
            child: SizedBox(
              height: 150,
              child: CustomPaint(
                painter: _BalancePainter(
                  projection.points.map((p) => p.balance).toList(),
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          ExpansionTile(
            title: Text(t('Exact daily table', 'Bảng từng ngày chính xác')),
            children: [
              for (final p in projection.points)
                ListTile(
                  title: Text(dateLabel(p.date)),
                  subtitle: Text(
                    '${t('In', 'Vào')}: ${money(p.inflow)} · ${t('Out', 'Ra')}: ${money(p.outflow)}',
                  ),
                  trailing: Text(money(p.balance)),
                ),
            ],
          ),
          Text(
            t(
              'Inclusive calendar days in the reporting timezone. Unpaid overdue occurrences from the previous 366 days are due today in this estimate; older schedules require manual review. Month-end schedules retain their original day anchor.',
              'Tính ngày lịch bao gồm hai đầu theo múi giờ báo cáo. Lần đến hạn chưa trả trong 366 ngày trước được tính hôm nay; lịch cũ hơn cần rà soát thủ công. Lịch cuối tháng giữ mốc ngày gốc.',
            ),
          ),
        ]),
        section('Financial Sandbox · SIMULATION', 'Financial Sandbox · MÔ PHỎNG', [
          Text(
            t(
              'Saved baseline snapshots. Hypothetical entries never alter your ledger automatically.',
              'Dùng ảnh chụp dữ liệu gốc đã lưu. Giao dịch giả định không tự thay đổi sổ thật.',
            ),
          ),
          for (final scenario in s.scenarios)
            ListTile(
              title: Text(scenario.name),
              subtitle: Text(
                '${t('Baseline', 'Dữ liệu gốc')}: ${scenario.asOf} · r${scenario.baseline['revision']}',
              ),
              onTap: () => unawaited(scenarioPage(scenario)),
            ),
          button(
            'Try a purchase',
            'Thử một khoản mua',
            Icons.science_outlined,
            () => unawaited(scenarioEditor()),
          ),
          if (s.scenarios.length >= 2)
            button(
              'Compare scenarios (Pro)',
              'So sánh kịch bản (Pro)',
              Icons.compare_arrows,
              () => unawaited(compareScenarios()),
            ),
        ]),
        section('Goals and reservations', 'Mục tiêu và khoản dành riêng', [
          for (final g in s.goals)
            ListTile(
              title: Text(g.name),
              subtitle: Text(
                '${g.due} · ${t('Reserved', 'Đã dành')}: ${money(g.reserved, s.accounts.firstWhere((a) => a.id == g.account).currency)}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') unawaited(goalEditor(g));
                  if (v == 'delete')
                    unawaited(
                      run(() async {
                        if (await confirm(
                          'Release this goal reservation? No transactions are deleted.',
                          'Bỏ khoản dành mục tiêu này? Không xóa giao dịch.',
                        ))
                          await c.change(
                            (s) => s.copy({
                              'goals': s.goals
                                  .where((x) => x.id != g.id)
                                  .map((x) => x.toJson())
                                  .toList(),
                            }),
                            'delete_goal',
                          );
                      }),
                    );
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(t('Edit', 'Sửa'))),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(t('Release reserve', 'Bỏ khoản dành')),
                  ),
                ],
              ),
            ),
          button(
            'Add goal reserve',
            'Thêm mục tiêu',
            Icons.flag_outlined,
            () => unawaited(goalEditor()),
          ),
        ]),
        section(
          'Recurring and hidden-cost radar',
          'Khoản định kỳ và chi phí duy trì',
          [
            ...billRows(),
            for (final currency in s.accounts.map((a) => a.currency).toSet())
              ...recurringTotals(currency),
            for (final bill in s.bills.where(
              (b) => b.enabled && b.amount.isNegative && b.toAccount == null,
            )) ...[
              amountRow(
                '${bill.name} · ${t('annual equivalent estimate', 'ước tính quy năm')}',
                bill.amount.abs() *
                    BigInt.from(
                      bill.frequency == 'weekly'
                          ? 52
                          : bill.frequency == 'monthly'
                          ? 12
                          : bill.frequency == 'yearly'
                          ? 1
                          : 0,
                    ),
                currency: s.accounts
                    .firstWhere((a) => a.id == bill.account)
                    .currency,
              ),
              TextButton(
                onPressed: () => unawaited(
                  run(() async {
                    if (await confirm(
                      'Disable this schedule while retaining payment history?',
                      'Tắt lịch này và giữ nguyên lịch sử thanh toán?',
                    ))
                      await c.change(
                        (s) => s.copy({
                          'bills': [
                            for (final b in s.bills)
                              if (b.id == bill.id)
                                {...b.toJson(), 'enabled': false}
                              else
                                b.toJson(),
                          ],
                        }),
                        'disable_bill',
                      );
                  }),
                ),
                child: Text('${t('Disable', 'Tắt')}: ${bill.name}'),
              ),
            ],
            Text(
              t(
                'Weekly annual equivalents use 52 payments; monthly use 12. They are estimates, not issuer totals. No predicted payment is posted automatically.',
                'Khoản tuần quy năm theo 52 lần; khoản tháng theo 12 lần. Đây là ước tính, không phải tổng ngân hàng. Không tự ghi giao dịch dự đoán.',
              ),
            ),
            button(
              'Add recurring item',
              'Thêm khoản định kỳ',
              Icons.event_repeat,
              () => unawaited(billEditor()),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> scenarioEditor([Scenario? existing]) async {
    final available = {
      for (final a in s.accounts.where(
        (a) => !a.archived && !a.liability && a.currency == s.currency,
      ))
        a.id: a.name,
    };
    if (available.isEmpty) {
      await accountEditor();
      return;
    }
    if (existing == null && s.scenarios.isNotEmpty && !pro) {
      await pageRoute(
        'Pro Lifetime',
        'Pro trọn đời',
        (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: widget.settings,
        ),
      );
      return;
    }
    final first = existing?.staged.firstOrNull,
        total =
            existing?.staged.fold(BigInt.zero, (BigInt n, e) => n - e.amount) ??
            BigInt.one;
    await edit(
      'Purchase simulation',
      'Mô phỏng khoản mua',
      [
        const EditField('name', 'Scenario name', 'Tên kịch bản'),
        EditField(
          'account',
          'Funding account (report currency)',
          'Tài khoản chi (tiền báo cáo)',
          options: available,
        ),
        const EditField(
          'cost',
          'Total cost, no assumed interest',
          'Tổng chi phí, không giả định lãi',
          number: true,
        ),
        const EditField(
          'date',
          'Purchase date YYYY-MM-DD',
          'Ngày mua YYYY-MM-DD',
        ),
        const EditField(
          'installments',
          'Number of equal monthly installments (1=cash)',
          'Số kỳ trả tháng bằng nhau (1=tiền mặt)',
          number: true,
        ),
        EditField(
          'category',
          'Budget category',
          'Danh mục ngân sách',
          options: {
            '': t('Uncategorized', 'Chưa phân loại'),
            for (final c in s.categories.where((c) => c.kind == 'expense'))
              c.id: c.name,
          },
          requiredValue: false,
        ),
        EditField(
          'skip',
          'Replace / skip one recurring obligation',
          'Thay / bỏ một khoản định kỳ',
          options: {
            '': t('None', 'Không'),
            for (final bill in s.bills.where((b) => b.enabled))
              bill.id: bill.name,
          },
          requiredValue: false,
        ),
      ],
      {
        'name': existing?.name ?? '',
        'account': first?.account ?? available.keys.first,
        'cost': decimalMoney(total, s.currency),
        'date': first == null ? today : reportDay(first.when, s.zone),
        'installments': existing?.staged.length.toString() ?? '1',
        'category': first?.category ?? '',
        'skip': existing?.skipBills.firstOrNull ?? '',
      },
      (v) async {
        final base =
                existing?.baseline ??
                (s.toJson()
                  ..['scenarios'] = []
                  ..['audit'] = []
                  ..['imports'] = []
                  ..['profiles'] = []
                  ..['rules'] = []),
            baseState = SpendState.fromJson(base),
            actions = purchasePlan(
              account: v['account'] as String,
              cost: minor(v['cost'] as String, baseState.currency),
              date: v['date'] as String,
              zone: baseState.zone,
              installments: int.parse(v['installments'] as String),
              category: v['category'] == '' ? null : v['category'] as String?,
            ),
            next = Scenario(
              id: existing?.id ?? newId(),
              name: v['name'] as String,
              asOf: existing?.asOf ?? today,
              baseline: base,
              staged: actions,
              skipBills: v['skip'] == '' ? [] : [v['skip'] as String],
            );
        await c.change(
          (s) => s.copy({
            'scenarios': [
              for (final x in s.scenarios)
                if (x.id != next.id) x.toJson(),
              next.toJson(),
            ],
          }),
          'save_scenario',
        );
      },
    );
  }

  Future<void> scenarioPage(Scenario scenario) async {
    final base = SpendState.fromJson(scenario.baseline),
        start = scenario.asOf,
        endMonth = day(
          DateTime.utc(calendar(start).year, calendar(start).month + 1, 0),
        ),
        baseProjection = forecast(base, start, endMonth),
        changed = forecast(
          base,
          start,
          endMonth,
          staged: scenario.staged,
          skipBills: scenario.skipBills.toSet(),
        ),
        safe = safeToSpend(
          base,
          start,
          endMonth,
          staged: scenario.staged,
          skipBills: scenario.skipBills.toSet(),
        );
    final simulated = base.copy({
      'entries': [
        ...base.entries.map((e) => e.toJson()),
        ...scenario.staged.map((e) => e.copy({'status': 'posted'}).toJson()),
      ],
    });
    await pageRoute(
      'SIMULATION · ${scenario.name}',
      'MÔ PHỎNG · ${scenario.name}',
      (context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${t('Immutable baseline revision', 'Bản dữ liệu gốc bất biến')}: ${base.revision} · $start',
          ),
          if (financialFingerprint(base) != financialFingerprint(s))
            Text(
              t(
                'Live data has changed. This scenario still uses its saved baseline.',
                'Sổ hiện tại đã thay đổi. Kịch bản vẫn dùng dữ liệu gốc đã lưu.',
              ),
            ),
          amountRow(
            t('Baseline month-end balance', 'Số dư cuối tháng gốc'),
            baseProjection.ending,
            currency: base.currency,
          ),
          amountRow(
            t('Scenario month-end balance', 'Số dư cuối tháng giả định'),
            changed.ending,
            currency: base.currency,
          ),
          amountRow(
            t('Lowest projected liquidity', 'Thanh khoản dự báo thấp nhất'),
            changed.lowest,
            currency: base.currency,
          ),
          amountRow(
            t('Scenario Safe to Spend', 'Có thể chi theo giả định'),
            safe.available,
            currency: base.currency,
          ),
          for (final budget in base.budgets) ...[
            Text(
              '${t('Budget impact', 'Ảnh hưởng ngân sách')}: ${budget.name}',
            ),
            amountRow(
              t('Baseline remaining', 'Còn lại theo gốc'),
              budgetRemaining(base, budget),
              currency: budget.currency,
            ),
            amountRow(
              t('Simulated remaining', 'Còn lại theo giả định'),
              budgetRemaining(simulated, budget),
              currency: budget.currency,
            ),
          ],
          Text(
            '${t('First shortfall', 'Ngày thiếu đầu tiên')}: ${changed.shortfall ?? t('none', 'không có')}',
          ),
          for (final e in scenario.staged)
            ListTile(
              title: Text(dateLabel(reportDay(e.when, base.zone))),
              trailing: Text(money(e.amount, base.currency)),
            ),
          Text(
            t(
              'Installments divide the entered total exactly; no interest or lender fees are assumed. Goal completion dates cannot be inferred without a contribution plan. Reservations remain unchanged.',
              'Các kỳ chia chính xác tổng tiền đã nhập; không giả định lãi hay phí bên cho vay. Không suy ra ngày hoàn tất mục tiêu khi chưa có lịch góp. Khoản dành riêng không đổi.',
            ),
          ),
          button('Edit / rename', 'Sửa / đổi tên', Icons.edit, () {
            Navigator.pop(context);
            unawaited(scenarioEditor(scenario));
          }),
          button(
            'Discard scenario',
            'Bỏ kịch bản',
            Icons.delete_outline,
            () => unawaited(
              run(() async {
                if (await confirm(
                  'Discard this simulation? Actual transactions stay unchanged.',
                  'Bỏ mô phỏng này? Giao dịch thật được giữ nguyên.',
                )) {
                  await c.change(
                    (s) => s.copy({
                      'scenarios': s.scenarios
                          .where((x) => x.id != scenario.id)
                          .map((x) => x.toJson())
                          .toList(),
                    }),
                    'discard_scenario',
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              }),
            ),
          ),
          if (pro)
            button(
              'Duplicate scenario',
              'Nhân bản kịch bản',
              Icons.copy,
              () => unawaited(
                run(
                  () => c.change(
                    (s) => s.copy({
                      'scenarios': [
                        ...s.scenarios.map((x) => x.toJson()),
                        {
                          ...scenario.toJson(),
                          'id': newId(),
                          'name': '${scenario.name} (2)',
                        },
                      ],
                    }),
                    'duplicate_scenario',
                  ),
                ),
              ),
            ),
          if (!(s.settings['convertedScenarios'] as List? ?? []).contains(
            scenario.id,
          ))
            button(
              'Explicitly record these as real transactions',
              'Chủ động ghi thành giao dịch thật',
              Icons.playlist_add_check,
              () => unawaited(
                run(() async {
                  if (!await confirm(
                    'Write this purchase into the real ledger? Past/today entries are posted; future installments stay pending until approved. This can only be done once per scenario.',
                    'Ghi khoản mua vào sổ thật? Khoản hôm nay/quá khứ được ghi sổ; kỳ tương lai chờ duyệt. Mỗi kịch bản chỉ ghi một lần.',
                  ))
                    return;
                  await c.change((s) {
                    if ((s.settings['convertedScenarios'] as List? ?? [])
                        .contains(scenario.id))
                      throw StateError('Already converted');
                    return s.copy({
                      'entries': [
                        ...s.entries.map((e) => e.toJson()),
                        ...scenario.staged.map(
                          (e) => e.copy({
                            'id': newId(),
                            'status':
                                reportDay(e.when, s.zone).compareTo(today) <= 0
                                ? 'posted'
                                : 'pending',
                            'note':
                                '${t('Converted from scenario', 'Chuyển từ kịch bản')}: ${scenario.name}',
                          }).toJson(),
                        ),
                      ],
                      'settings': {
                        ...s.settings,
                        'convertedScenarios': [
                          ...s.settings['convertedScenarios'] as List? ?? [],
                          scenario.id,
                        ],
                      },
                    });
                  }, 'convert_scenario');
                  if (context.mounted) Navigator.pop(context);
                }),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> compareScenarios() async {
    if (!pro) {
      await pageRoute(
        'Pro Lifetime',
        'Pro trọn đời',
        (_) => SingleChildScrollView(child: widget.settings),
      );
      return;
    }
    await pageRoute(
      'Scenario comparison',
      'So sánh kịch bản',
      (context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final x in s.scenarios.take(3))
            section(x.name, x.name, [
              Text('${x.asOf} · r${x.baseline['revision']}'),
              amountRow(
                t('Ending projection (30 days)', 'Dự báo cuối kỳ (30 ngày)'),
                forecast(
                  SpendState.fromJson(x.baseline),
                  x.asOf,
                  day(calendar(x.asOf).add(const Duration(days: 29))),
                  staged: x.staged,
                  skipBills: x.skipBills.toSet(),
                ).ending,
                currency: SpendState.fromJson(x.baseline).currency,
              ),
            ]),
        ],
      ),
    );
  }
}

class _BalancePainter extends CustomPainter {
  final List<BigInt> values;
  final Color color;
  _BalancePainter(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final low = values.reduce((a, b) => a < b ? a : b),
        high = values.reduce((a, b) => a > b ? a : b),
        range = high - low,
        path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1),
          y = range == BigInt.zero
              ? size.height / 2
              : size.height -
                    ((values[i] - low) * BigInt.from(1000000) ~/ range)
                            .toDouble() /
                        1000000 *
                        size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BalancePainter old) =>
      !listEquals(old.values, values) || old.color != color;
}
