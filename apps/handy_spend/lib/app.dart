library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data' show BytesBuilder;
import 'package:flutter/foundation.dart' show compute, kIsWeb, listEquals;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:handy_ui/handy_ui.dart';
import 'package:handy_ui/local_app.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:crypto/crypto.dart' show sha256;
import 'controller.dart';
import 'editor.dart';
import 'reminders.dart';
import 'privacy.dart';
import 'capabilities.dart';
part 'editors.dart';
part 'planning_ui.dart';
part 'import_wizard.dart';
part 'desktop_ui.dart';

class SpendApp extends StatefulWidget {
  final SpendController? controller;
  final HandyFiles files;
  const SpendApp({
    super.key,
    this.controller,
    this.files = const SystemHandyFiles(),
  });
  @override
  State<SpendApp> createState() => _SpendAppState();
}

class _SpendAppState extends State<SpendApp> {
  late final controller = widget.controller ?? SpendController();
  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = DevicePreferencesRepository(
      'handy-spend',
      knownTools: {},
      workflowSteps: {},
    );
    return SpendPrivacyGate(
      controller: controller,
      child: LocalApp(
        title: 'Handy Spend',
        accent: const Color(0xFF7C3AED),
        adsVisible: controller.adsVisible,
        loadPreferences: () async {
          final p = await prefs.load();
          return {'locale': p.locale, 'theme': p.theme};
        },
        savePreferences: (p) async => prefs.save(
          (await prefs.load()).copyWith(
            locale: p['locale']!,
            theme: p['theme']!,
          ),
        ),
        content: (context, settings) => SpendHome(
          controller: controller,
          files: widget.files,
          settings: settings,
        ),
      ),
    );
  }
}

class SpendHome extends StatefulWidget {
  final bool enableDrop;
  final SpendController? controller;
  final HandyFiles files;
  final Widget settings;
  const SpendHome({
    super.key,
    this.controller,
    this.files = const SystemHandyFiles(),
    this.settings = const SizedBox(),
    this.enableDrop = true,
  });
  @override
  State<SpendHome> createState() => _SpendHomeState();
}

class _SpendHomeState extends State<SpendHome> with WidgetsBindingObserver {
  late final c = widget.controller ?? SpendController();
  final reminders = SpendReminders();
  final privacy = SpendPrivacy();
  int tab = 0, page = 1, horizon = 30;
  bool busy = false, conservative = true;
  String search = '',
      filterAccount = '',
      filterCategory = '',
      filterKind = '',
      filterStatus = '',
      filterTag = '',
      minAmount = '',
      maxAmount = '';
  late String from = day(
    DateTime.utc(DateTime.now().year, DateTime.now().month, 1),
  );
  late String until = day(
    DateTime.utc(DateTime.now().year, DateTime.now().month + 1, 1),
  );
  final selected = <String>{};
  final searchFocus = FocusNode();
  final searchText = TextEditingController();
  double tableWidth = 200;
  SpendState get s => c.state!;
  String get today =>
      reportDay(DateTime.now().toUtc().toIso8601String(), s.zone);
  String get end => day(calendar(today).add(Duration(days: horizon - 1)));
  Set<String> get planningAccounts => eligible(s, s.currency);
  void refresh(VoidCallback action) => setState(action);
  bool get pro => LifetimeScope.maybeOf(context)?.pro == true;
  String t(String en, String vi) => tr(context, en, vi);
  String money(BigInt value, [String? currency]) =>
      s.settings['hideAmounts'] == true
      ? '••••'
      : formatFigure(
          context,
          '${decimalMoney(value, currency ?? s.currency)} ${currency ?? s.currency}',
        );
  String dateLabel(String raw) {
    final d = calendar(raw);
    return s.settings['dateFormat'] == 'iso'
        ? raw
        : MaterialLocalizations.of(context).formatMediumDate(d);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(changed);
    if (c.state == null) unawaited(c.load());
  }

  @override
  void dispose() {
    searchFocus.dispose();
    searchText.dispose();
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(changed);
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && c.state != null)
      unawaited(syncReminders());
  }

  void changed() {
    if (mounted) setState(() {});
    if (c.state != null) unawaited(syncReminders());
  }

  Future<void> syncReminders() async {
    try {
      await reminders.sync(s);
    } catch (_) {
      /* In-app upcoming list remains available; OS failure is shown in settings. */
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    c.adsVisible.value = false;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'Operation failed. Check input or storage; existing data was preserved.',
                'Thao tác thất bại. Kiểm tra dữ liệu hoặc dung lượng; dữ liệu hiện có được giữ lại.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => busy = false);
        c.adsVisible.value = tab != 2;
      }
    }
  }

  Future<bool> confirm(String en, String vi) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t('Confirm', 'Xác nhận')),
          content: Text(t(en, vi)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('Cancel', 'Hủy')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t('Confirm', 'Xác nhận')),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> edit(
    String en,
    String vi,
    List<EditField> fields,
    Map<String, dynamic> initial,
    Future<void> Function(Map<String, dynamic>) save,
  ) async {
    c.adsVisible.value = false;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SpendEditor(
          en: en,
          vi: vi,
          fields: fields,
          initial: initial,
          save: save,
        ),
      ),
    );
    if (mounted) c.adsVisible.value = tab != 2;
  }

  Future<void> pageRoute(
    String en,
    String vi,
    Widget Function(BuildContext) body,
  ) async {
    c.adsVisible.value = false;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(tr(context, en, vi))),
          body: body(context),
        ),
      ),
    );
    if (mounted) c.adsVisible.value = tab != 2;
  }

  Widget section(String en, String vi, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t(en, vi), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget amountRow(String label, BigInt value, {String? currency}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 20,
      children: [
        Text(label),
        Text(
          money(value, currency),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
  Widget button(String en, String vi, IconData icon, VoidCallback action) =>
      OutlinedButton.icon(
        onPressed: busy ? null : action,
        icon: Icon(icon),
        label: Text(t(en, vi)),
      );
  List<Entry> get filtered {
    final q = search.toLowerCase(),
        accountMap = {for (final a in s.accounts) a.id: a};
    final low = minAmount.isEmpty ? null : minor(minAmount, s.currency),
        high = maxAmount.isEmpty ? null : minor(maxAmount, s.currency);
    final rows = s.entries.where((e) {
      final date = reportDay(e.when, s.zone);
      return date.compareTo(from) >= 0 &&
          date.compareTo(until) < 0 &&
          (filterAccount.isEmpty ||
              e.account == filterAccount ||
              e.toAccount == filterAccount) &&
          (filterCategory.isEmpty || e.category == filterCategory) &&
          (filterKind.isEmpty || e.kind == filterKind) &&
          (filterStatus.isEmpty || e.status == filterStatus) &&
          (filterTag.isEmpty ||
              e.tags.any((v) => v.toLowerCase() == filterTag.toLowerCase())) &&
          (low == null ||
              accountMap[e.account]!.currency == s.currency &&
                  e.amount.abs() >= low) &&
          (high == null ||
              accountMap[e.account]!.currency == s.currency &&
                  e.amount.abs() <= high) &&
          ('${e.payee} ${e.note} ${e.tags.join(' ')} ${accountMap[e.account]?.name}'
              .toLowerCase()
              .contains(q));
    }).toList();
    rows.sort((a, b) => b.when.compareTo(a.when));
    return rows;
  }

  Future<void> filters() async => edit(
    'Filters and reporting period',
    'Bộ lọc và kỳ báo cáo',
    [
      const EditField(
        'from',
        'From (YYYY-MM-DD, inclusive)',
        'Từ ngày (YYYY-MM-DD, bao gồm)',
      ),
      const EditField(
        'until',
        'Until (YYYY-MM-DD, excluded)',
        'Đến ngày (YYYY-MM-DD, không gồm)',
      ),
      EditField(
        'account',
        'Account',
        'Tài khoản',
        options: {
          '': t('All', 'Tất cả'),
          for (final a in s.accounts) a.id: a.name,
        },
        requiredValue: false,
      ),
      EditField(
        'category',
        'Category',
        'Danh mục',
        options: {
          '': t('All', 'Tất cả'),
          for (final a in s.categories) a.id: a.name,
        },
        requiredValue: false,
      ),
      EditField(
        'kind',
        'Type',
        'Loại',
        options: {
          '': t('All', 'Tất cả'),
          for (final kind in [
            'expense',
            'income',
            'transfer',
            'refund',
            'adjustment',
          ])
            kind: kindLabel(kind),
        },
        requiredValue: false,
      ),
      EditField(
        'status',
        'Status',
        'Trạng thái',
        options: {
          '': t('All', 'Tất cả'),
          'posted': t('Posted', 'Đã ghi sổ'),
          'pending': t('Pending', 'Dự kiến'),
        },
        requiredValue: false,
      ),
      const EditField('tag', 'Tag', 'Nhãn', requiredValue: false),
      const EditField(
        'min',
        'Minimum absolute amount (report currency)',
        'Số tiền tuyệt đối tối thiểu (tiền báo cáo)',
        number: true,
        requiredValue: false,
      ),
      const EditField(
        'max',
        'Maximum absolute amount',
        'Số tiền tuyệt đối tối đa',
        number: true,
        requiredValue: false,
      ),
    ],
    {
      'from': from,
      'until': until,
      'account': filterAccount,
      'category': filterCategory,
      'kind': filterKind,
      'status': filterStatus,
      'tag': filterTag,
      'min': minAmount,
      'max': maxAmount,
    },
    (v) async {
      if (!calendar(
        v['until'] as String,
      ).isAfter(calendar(v['from'] as String)))
        throw const FormatException('Period');
      for (final k in ['min', 'max']) {
        if ((v[k] as String).isNotEmpty &&
            minor(v[k] as String, s.currency).isNegative)
          throw const FormatException('Amount');
      }
      setState(() {
        from = v['from'] as String;
        until = v['until'] as String;
        filterAccount = v['account'] as String? ?? '';
        filterCategory = v['category'] as String? ?? '';
        filterKind = v['kind'] as String? ?? '';
        filterStatus = v['status'] as String? ?? '';
        filterTag = v['tag'] as String;
        minAmount = v['min'] as String;
        maxAmount = v['max'] as String;
        page = 1;
        selected.clear();
      });
    },
  );
  String kindLabel(String kind) => switch (kind) {
    'income' => t('Income', 'Thu nhập'),
    'transfer' => t('Transfer', 'Chuyển khoản'),
    'refund' => t('Refund', 'Hoàn tiền'),
    'adjustment' => t('Adjustment', 'Điều chỉnh'),
    _ => t('Expense', 'Chi tiêu'),
  };
  Widget home() {
    final funds = balances(s, today),
        safe = safeToSpend(
          s,
          today,
          end,
          accounts: planningAccounts,
          conservative: conservative,
        ),
        rows = report(s, from, until);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (s.accounts.isEmpty)
          section('Start with your accounts', 'Bắt đầu với tài khoản', [
            Text(
              t(
                'Manual balances only. No bank connection or account is required.',
                'Số dư nhập thủ công. Không kết nối ngân hàng hay yêu cầu đăng ký.',
              ),
            ),
            button(
              'Add account',
              'Thêm tài khoản',
              Icons.account_balance_wallet,
              () => unawaited(accountEditor()),
            ),
          ]),
        section('Safe to Spend · estimate', 'Có thể chi · ước tính', [
          Text(
            money(safe.available),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          amountRow(t('Per day', 'Mỗi ngày'), safe.perDay),
          if (safe.shortfall > BigInt.zero)
            amountRow(t('Shortfall', 'Thiếu hụt'), safe.shortfall),
          Text(
            '${dateLabel(today)} – ${dateLabel(end)} · ${t('Assumptions in Plan; not a guarantee.', 'Xem giả định tại Kế hoạch; không phải bảo đảm.')}',
          ),
          button('Review plan', 'Xem kế hoạch', Icons.tune, () {
            c.adsVisible.value = false;
            setState(() => tab = 2);
          }),
        ]),
        section('Account balances', 'Số dư tài khoản', [
          for (final a in s.accounts.where((a) => !a.archived))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(a.name),
              subtitle: Text(
                '${a.currency} · ${t(a.liability ? 'Liability' : 'Asset', a.liability ? 'Nợ phải trả' : 'Tài sản')}',
              ),
              trailing: Text(money(funds[a.id]!, a.currency)),
              onTap: () => unawaited(accountEditor(a)),
            ),
        ]),
        section('Actual cash flow', 'Dòng tiền thực tế', [
          Text(
            '${dateLabel(from)} – ${dateLabel(until)} (${t('end excluded', 'không gồm ngày cuối')})',
          ),
          amountRow(t('Income', 'Thu nhập'), rows['income']!),
          amountRow(
            t('Expense, net of refunds', 'Chi tiêu sau hoàn tiền'),
            rows['expense']!,
          ),
          amountRow(
            t('Net income less expense', 'Thu trừ chi'),
            rows['income']! - rows['expense']!,
          ),
          Text(
            t(
              'Transfers and opening balances are excluded from income/expense. Currencies are never silently combined.',
              'Chuyển khoản và số dư ban đầu không tính vào thu/chi. Không tự cộng các loại tiền.',
            ),
          ),
        ]),
        section(
          'Upcoming and overdue bills',
          'Hóa đơn sắp đến và quá hạn',
          billRows(limit: 5),
        ),
        section('Local data', 'Dữ liệu cục bộ', [
          Text(
            t(
              'Keep a portable backup, especially on Web where browser data may be cleared.',
              'Nên sao lưu, nhất là trên Web vì trình duyệt có thể xóa dữ liệu.',
            ),
          ),
          button(
            'Backup ZIP',
            'Sao lưu ZIP',
            Icons.backup,
            () => unawaited(run(() => exportData('zip'))),
          ),
        ]),
      ],
    );
  }

  Widget history() => LayoutBuilder(
    builder: (context, size) =>
        size.maxWidth >= 900 ? desktopHistory() : mobileHistory(),
  );
  Widget mobileHistory() {
    final rows = filtered, shown = rows.take(page * 100).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('spend-search'),
                  controller: searchText,
                  focusNode: searchFocus,
                  decoration: InputDecoration(
                    labelText: t(
                      'Search payee, notes, tags',
                      'Tìm đối tác, ghi chú, nhãn',
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() {
                    search = v;
                    page = 1;
                  }),
                ),
              ),
              IconButton(
                tooltip: t('Filters', 'Bộ lọc'),
                onPressed: () => unawaited(filters()),
                icon: const Icon(Icons.filter_list),
              ),
            ],
          ),
        ),
        if (selected.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              Text('${selected.length} ${t('selected', 'đã chọn')}'),
              TextButton(
                onPressed: () => unawaited(run(() => bulkDelete())),
                child: Text(t('Delete selected', 'Xóa mục chọn')),
              ),
              TextButton(
                onPressed: () =>
                    unawaited(run(() => exportData('csv', onlySelected: true))),
                child: Text(t('Export selected', 'Xuất mục chọn')),
              ),
              TextButton(
                onPressed: () => setState(selected.clear),
                child: Text(t('Clear selection', 'Bỏ chọn')),
              ),
            ],
          ),
        if (rows.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                t(
                  'No transactions in this period.',
                  'Chưa có giao dịch trong kỳ này.',
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: shown.length + 1,
              itemBuilder: (context, index) {
                if (index == shown.length)
                  return rows.length > shown.length
                      ? TextButton(
                          onPressed: () => setState(() => page++),
                          child: Text(t('Load 100 more', 'Tải thêm 100 mục')),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '${rows.length} ${t('transactions', 'giao dịch')}',
                          ),
                        );
                final e = shown[index],
                    a = s.accounts.firstWhere((a) => a.id == e.account);
                return Card(
                  child: ListTile(
                    leading: Checkbox(
                      value: selected.contains(e.id),
                      onChanged: (v) => setState(
                        () => v == true
                            ? selected.add(e.id)
                            : selected.remove(e.id),
                      ),
                    ),
                    title: Text(
                      e.payee.isEmpty ? kindLabel(e.kind) : e.payee,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${dateLabel(reportDay(e.when, s.zone))} · ${a.name} · ${kindLabel(e.kind)}${e.status == 'pending' ? ' · ${t('PENDING', 'DỰ KIẾN')}' : ''}',
                    ),
                    trailing: Text(money(e.amount, a.currency)),
                    onTap: () => unawaited(transactionEditor(e)),
                    onLongPress: () => unawaited(transactionActions(e)),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> transactionActions(Entry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t('Edit', 'Sửa')),
              onTap: () {
                Navigator.pop(context);
                unawaited(transactionEditor(entry));
              },
            ),
            if (entry.kind == 'expense' && entry.status == 'posted')
              ListTile(
                title: Text(t('Record refund', 'Ghi hoàn tiền')),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(transactionEditor(null, entry));
                },
              ),
            ListTile(
              title: Text(t('Delete transaction', 'Xóa giao dịch')),
              onTap: () {
                Navigator.pop(context);
                unawaited(
                  run(() async {
                    if (await confirm(
                      'Delete this transaction? Refund dependencies may prevent deletion.',
                      'Xóa giao dịch này? Giao dịch hoàn tiền liên quan có thể ngăn xóa.',
                    ))
                      await c.change(
                        (s) => s.copy({
                          'entries': s.entries
                              .where((e) => e.id != entry.id)
                              .map((e) => e.toJson())
                              .toList(),
                        }),
                        'delete_transaction',
                      );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> bulkDelete() async {
    if (!await confirm(
      'Delete selected transactions atomically?',
      'Xóa các giao dịch đã chọn trong một lần?',
    ))
      return;
    final ids = Set<String>.of(selected);
    await c.change(
      (s) => s.copy({
        'entries': s.entries
            .where((e) => !ids.contains(e.id))
            .map((e) => e.toJson())
            .toList(),
      }),
      'bulk_delete',
    );
    setState(selected.clear);
  }

  Widget reports() {
    final r = report(
          s,
          from,
          until,
          account: filterAccount.isEmpty ? null : filterAccount,
          category: filterCategory.isEmpty ? null : filterCategory,
        ),
        funds = balances(s, today);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        button(
          'Reporting filters',
          'Bộ lọc báo cáo',
          Icons.filter_list,
          () => unawaited(filters()),
        ),
        Text('${dateLabel(from)} – ${dateLabel(until)} · ${s.currency}'),
        section('Actual income vs expense', 'Thu so với chi thực tế', [
          amountRow(t('Income', 'Thu'), r['income']!),
          amountRow(t('Expense', 'Chi'), r['expense']!),
          amountRow(
            t('Corrections (not income)', 'Điều chỉnh (không phải thu nhập)'),
            r['adjustment']!,
          ),
        ]),
        section('Spending by category', 'Chi tiêu theo danh mục', [
          for (final e in r.entries.where((e) => e.key.startsWith('category:')))
            amountRow(
              s.categories
                      .where((c) => c.id == e.key.substring(9))
                      .firstOrNull
                      ?.name ??
                  t('Uncategorized', 'Chưa phân loại'),
              e.value,
            ),
        ]),
        section('Account movement', 'Biến động tài khoản', [
          for (final a in s.accounts.where((a) => a.currency == s.currency))
            amountRow(a.name, r['account:${a.id}'] ?? BigInt.zero),
        ]),
        section('Net worth by currency', 'Tài sản ròng theo loại tiền', [
          for (final currency in s.accounts.map((a) => a.currency).toSet())
            amountRow(
              currency,
              s.accounts
                  .where((a) => a.currency == currency)
                  .fold(BigInt.zero, (BigInt n, a) => n + funds[a.id]!),
              currency: currency,
            ),
          Text(
            t(
              'Liabilities use signed balances; no exchange rates are assumed.',
              'Nợ dùng số dư có dấu; không tự giả định tỷ giá.',
            ),
          ),
        ]),
        section('Monthly trend', 'Xu hướng tháng', [
          for (var offset = 5; offset >= 0; offset--) ...monthlyReport(offset),
        ]),
        section('Budgets', 'Ngân sách', [
          for (final b in s.budgets)
            ListTile(
              title: Text(b.name),
              subtitle: Text('${b.start} → ${b.end}'),
              trailing: Text(money(budgetRemaining(s, b), b.currency)),
              onTap: () => unawaited(budgetEditor(b)),
            ),
          button(
            'Add budget',
            'Thêm ngân sách',
            Icons.add,
            () => unawaited(budgetEditor()),
          ),
        ]),
        Wrap(
          spacing: 8,
          children: [
            for (final f in ['csv', 'xlsx', 'json', 'pdf'])
              button(
                'Export $f',
                'Xuất $f',
                Icons.download,
                () => unawaited(run(() => exportData(f))),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> monthlyReport(int offset) {
    final now = calendar(today),
        a = day(DateTime.utc(now.year, now.month - offset, 1)),
        b = day(DateTime.utc(now.year, now.month - offset + 1, 1)),
        r = report(s, a, b);
    return [
      amountRow('${a.substring(0, 7)} · ${t('income', 'thu')}', r['income']!),
      amountRow('${a.substring(0, 7)} · ${t('expense', 'chi')}', r['expense']!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (c.state == null)
      return Scaffold(
        appBar: AppBar(title: const Text('Handy Spend')),
        body: Center(
          child: c.error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t(
                        'Local data could not be opened. No reset was performed.',
                        'Không mở được dữ liệu cục bộ. Chưa xóa hay đặt lại dữ liệu.',
                      ),
                    ),
                    TextButton(
                      onPressed: () => unawaited(c.load()),
                      child: Text(t('Retry', 'Thử lại')),
                    ),
                  ],
                ),
        ),
      );
    final scaffold = HandyScaffold(
      title: 'Handy Spend',
      selected: tab,
      onSelect: (v) {
        setState(() => tab = v);
        c.adsVisible.value = v != 2;
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          label: t('Home', 'Trang chủ'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          label: t('Transactions', 'Giao dịch'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.route_outlined),
          label: t('Plan', 'Kế hoạch'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.bar_chart),
          label: t('Reports', 'Báo cáo'),
        ),
      ],
      actions: [
        IconButton(
          tooltip: t('Accounts', 'Tài khoản'),
          onPressed: busy ? null : () => unawaited(accountsPage()),
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
        IconButton(
          key: const Key('spend-add'),
          tooltip: t('Add transaction', 'Thêm giao dịch'),
          onPressed: busy ? null : () => unawaited(transactionEditor()),
          icon: const Icon(Icons.add_circle_outline),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'settings') unawaited(settingsPage());
            if (v == 'categories') unawaited(categoriesPage());
            if (v == 'import') unawaited(importWizard());
            if (v == 'backup') unawaited(run(() => exportData('zip')));
            if (v == 'restore') unawaited(run(restoreBackup));
            if (v == 'undo') unawaited(run(c.undo));
            if (v == 'rules') unawaited(rulesPage());
            if (v == 'imports') unawaited(importHistoryPage());
          },
          itemBuilder: (context) => [
            for (final e in {
              'settings': t('Settings', 'Cài đặt'),
              'categories': t('Categories', 'Danh mục'),
              'import': t('Import statement', 'Nhập sao kê'),
              'backup': t('Backup ZIP', 'Sao lưu ZIP'),
              'restore': t('Restore backup', 'Khôi phục sao lưu'),
              'undo': t('Undo last change', 'Hoàn tác thay đổi cuối'),
              'rules': t('Categorization rules', 'Quy tắc phân loại'),
              'imports': t('Import history', 'Lịch sử nhập'),
            }.entries)
              PopupMenuItem(value: e.key, child: Text(e.value)),
          ],
        ),
      ],
      body: Stack(
        children: [
          Positioned.fill(
            child: switch (tab) {
              0 => home(),
              1 => history(),
              2 => plan(),
              _ => reports(),
            },
          ),
          if (busy)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
    return widget.enableDrop && SpendCapabilities.current.dragDrop
        ? DropTarget(
            enable: !busy,
            onDragDone: (details) => unawaited(
              run(() async {
                if (details.files.length != 1)
                  throw const FormatException('Drop one statement at a time');
                final imported = await readDroppedStatement(
                  details.files.single,
                );
                await importWizard(initial: imported);
              }),
            ),
            child: keyboardCommands(scaffold),
          )
        : keyboardCommands(scaffold);
  }
}
