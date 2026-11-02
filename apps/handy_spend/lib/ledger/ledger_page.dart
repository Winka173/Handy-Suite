import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../entry/entry_sheet.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'entry_row.dart';
import 'export.dart';
import 'filter_sheet.dart';
import 'ledger_filter.dart';
import 'month_panel.dart';

const _page = 100;

/// The ledger: one month (or any period) at a time, the month's totals and
/// where its money went beside the entries, grouped by day.
class LedgerPage extends StatefulWidget {
  final SpendScope scope;
  final FocusNode searchFocus;
  const LedgerPage({super.key, required this.scope, required this.searchFocus});
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  SpendScope get scope => widget.scope;
  late LedgerFilter filter = LedgerFilter.month(scope.today);
  final search = TextEditingController();
  final selected = <String>{};
  bool selecting = false;
  int pages = 1;

  @override
  void initState() {
    super.initState();
    scope.ledgerAccount.addListener(_fromAccount);
    _fromAccount();
  }

  @override
  void dispose() {
    scope.ledgerAccount.removeListener(_fromAccount);
    search.dispose();
    super.dispose();
  }

  void _fromAccount() {
    final id = scope.ledgerAccount.value;
    if (id == null) return;
    scope.ledgerAccount.value = null;
    setFilter(filter.copyWith(account: id));
  }

  void setFilter(LedgerFilter next) {
    if (!mounted) return;
    setState(() {
      filter = next;
      pages = 1;
      selected.clear();
      selecting = false;
    });
  }

  void select(String id, bool on) => setState(() {
    on ? selected.add(id) : selected.remove(id);
    selecting = selected.isNotEmpty;
  });

  Future<void> deleteSelected() async {
    final ids = Set<String>.of(selected);
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Delete ${ids.length} entries?',
        'Xóa ${ids.length} giao dịch?',
      ),
      message: tr(
        context,
        'All of them go in one change, with their receipts and splits; a linked refund stops it.',
        'Tất cả xóa trong một lần, cùng hóa đơn và phần chia tiền; khoản hoàn tiền gắn kèm sẽ chặn lại.',
      ),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await scope.write(
      context,
      () => scope.controller.deleteEntries(ids, 'bulk_delete'),
      done: (c) => tr(
        c,
        '${ids.length} entries deleted.',
        'Đã xóa ${ids.length} giao dịch.',
      ),
    );
    if (done) setFilter(filter);
  }

  Future<void> export(String format, List<Entry> rows) async {
    try {
      await exportEntries(context, scope, format, rows, filter);
    } catch (e) {
      if (mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Not exported: ${errorText(context, e)}. Nothing changed.',
            'Chưa xuất: ${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
    }
  }

  String periodTitle(BuildContext context) {
    if (filter.isMonth) {
      final d = calendar(filter.from);
      return tr(
        context,
        '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][d.month - 1]} ${d.year}',
        'Tháng ${d.month}, ${d.year}',
      );
    }
    final last = day(calendar(filter.until).subtract(const Duration(days: 1)));
    return '${dayLabel(context, scope, filter.from)} – ${dayLabel(context, scope, last)}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = applyFilter(scope.state, filter);
    return LayoutBuilder(
      builder: (context, size) {
        final wide = size.maxWidth >= 1000;
        final panel = MonthPanel(
          scope: scope,
          filter: filter,
          onFilter: setFilter,
        );
        final items = _items(rows);
        final head = [
          _header(context, rows),
          _searchRow(context),
          FilterChips(scope: scope, filter: filter, onFilter: setFilter),
          if (selecting) _selectionBar(context),
          const SizedBox(height: HandySpace.s),
        ];
        Widget list(List<Widget> before) => ListView.builder(
          key: const Key('ledger-list'),
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: before.length + items.length + 1,
          itemBuilder: (context, i) {
            if (i < before.length) return before[i];
            i -= before.length;
            if (i == items.length) return _footer(context, rows.length);
            return items[i];
          },
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 360,
                child: ListView(
                  padding: const EdgeInsets.all(HandySpace.l),
                  children: [panel],
                ),
              ),
              const VerticalDivider(width: 1),
              // Rows keep a readable width: the amount stays near its name.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: list([
                      for (final w in head)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HandySpace.l,
                          ),
                          child: w,
                        ),
                    ]),
                  ),
                ),
              ),
            ],
          );
        }
        return list([
          for (final w in [head.first, panel, ...head.skip(1)])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HandySpace.l),
              child: w,
            ),
        ]);
      },
    );
  }

  List<Widget> _items(List<Entry> rows) {
    final out = <Widget>[];
    String? last;
    for (final e in rows.take(pages * _page)) {
      final d = reportDay(e.when, scope.state.zone);
      if (d != last) {
        out.add(_DayHeader(scope: scope, date: d, rows: rows));
        last = d;
      }
      out.add(
        EntryRow(
          scope: scope,
          entry: e,
          selecting: selecting,
          selected: selected.contains(e.id),
          onSelect: (on) => select(e.id, on),
          onTap: () => openEntry(context, scope, entry: e),
          onLongPress: () => select(e.id, !selected.contains(e.id)),
        ),
      );
    }
    if (rows.isEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: HandyEmpty(
            title: filter.narrowed
                ? tr(context, 'Nothing matches', 'Không có giao dịch khớp')
                : tr(
                    context,
                    'Nothing recorded in this period',
                    'Kỳ này chưa ghi gì',
                  ),
            action: filter.narrowed
                ? TextButton(
                    onPressed: () {
                      search.clear();
                      setFilter(filter.cleared());
                    },
                    child: Text(tr(context, 'Show everything', 'Hiện tất cả')),
                  )
                : null,
          ),
        ),
      );
    }
    return out;
  }

  Widget _footer(BuildContext context, int total) {
    final shown = total < pages * _page ? total : pages * _page;
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(HandySpace.l),
      child: Row(
        children: [
          Text(
            tr(
              context,
              '$shown of $total entries',
              '$shown / $total giao dịch',
            ),
            style: TextStyle(color: HandyColors.of(context).muted),
          ),
          const Spacer(),
          if (shown < total)
            OutlinedButton(
              key: const Key('ledger-more'),
              onPressed: () => setState(() => pages++),
              child: Text(tr(context, 'Show $_page more', 'Thêm $_page dòng')),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, List<Entry> rows) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.m, bottom: HandySpace.s),
      child: Row(
        children: [
          if (filter.isMonth)
            IconButton(
              key: const Key('month-prev'),
              tooltip: tr(context, 'Previous month', 'Tháng trước'),
              onPressed: () => setFilter(filter.shiftMonth(-1)),
              icon: const Icon(Icons.chevron_left),
            ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                periodTitle(context),
                key: const Key('ledger-period'),
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (filter.isMonth)
            IconButton(
              key: const Key('month-next'),
              tooltip: tr(context, 'Next month', 'Tháng sau'),
              onPressed: () => setFilter(filter.shiftMonth(1)),
              icon: const Icon(Icons.chevron_right),
            )
          else
            TextButton(
              onPressed: () => setFilter(LedgerFilter.month(scope.today)),
              child: Text(tr(context, 'This month', 'Tháng này')),
            ),
          HandyMenuButton(
            items: [
              HandyMenuItem(
                Icons.checklist,
                tr(context, 'Select', 'Chọn nhiều'),
                rows.isEmpty ? null : () => setState(() => selecting = true),
                key: const Key('ledger-select'),
              ),
              for (final f in ['csv', 'xlsx', 'json', 'pdf'])
                HandyMenuItem(
                  Icons.download_outlined,
                  tr(
                    context,
                    'Export ${f.toUpperCase()}',
                    'Xuất ${f.toUpperCase()}',
                  ),
                  () => export(f, rows),
                  key: Key('export-$f'),
                ),
              HandyMenuItem(
                Icons.upload_file_outlined,
                tr(context, 'Import a statement', 'Nhập sao kê'),
                () => Navigator.pushNamed(context, '/import'),
                key: const Key('ledger-import'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchRow(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          key: const Key('spend-search'),
          controller: search,
          focusNode: widget.searchFocus,
          decoration: InputDecoration(
            hintText: tr(
              context,
              'Find payee, note, tag',
              'Tìm đối tác, ghi chú, nhãn',
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: tr(context, 'Clear search', 'Xóa tìm kiếm'),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      search.clear();
                      setFilter(filter.copyWith(search: ''));
                    },
                  ),
          ),
          onChanged: (v) => setFilter(filter.copyWith(search: v)),
        ),
      ),
      const SizedBox(width: HandySpace.s),
      OutlinedButton.icon(
        key: const Key('ledger-filter'),
        onPressed: () => openFilterSheet(context, scope, filter, setFilter),
        icon: const Icon(Icons.tune, size: 18),
        label: Text(tr(context, 'Filter', 'Lọc')),
      ),
    ],
  );

  Widget _selectionBar(BuildContext context) {
    final rows = applyFilter(
      scope.state,
      filter,
    ).where((e) => selected.contains(e.id)).toList();
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.s),
      child: Row(
        children: [
          IconButton(
            tooltip: tr(context, 'Stop selecting', 'Bỏ chọn'),
            onPressed: () => setState(() {
              selected.clear();
              selecting = false;
            }),
            icon: const Icon(Icons.close),
          ),
          Expanded(
            child: Text(
              tr(
                context,
                '${selected.length} selected',
                'Đã chọn ${selected.length}',
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton(
            key: const Key('selected-export'),
            onPressed: rows.isEmpty ? null : () => export('csv', rows),
            child: Text(tr(context, 'Export CSV', 'Xuất CSV')),
          ),
          TextButton(
            key: const Key('selected-delete'),
            onPressed: rows.isEmpty ? null : deleteSelected,
            style: TextButton.styleFrom(
              foregroundColor: HandyColors.of(context).negative,
            ),
            child: Text(tr(context, 'Delete', 'Xóa')),
          ),
        ],
      ),
    );
  }
}

/// A day's heading: the date, and what that day spent in the report
/// currency.
class _DayHeader extends StatelessWidget {
  final SpendScope scope;
  final String date;
  final List<Entry> rows;
  const _DayHeader({
    required this.scope,
    required this.date,
    required this.rows,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final spent = rows
        .where(
          (e) =>
              reportDay(e.when, scope.state.zone) == date &&
              e.status == 'posted' &&
              (e.kind == 'expense' || e.kind == 'refund') &&
              scope.account(e.account).currency == scope.currency,
        )
        .fold(BigInt.zero, (n, e) => n - e.amount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        HandySpace.l,
        HandySpace.l,
        4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                whenLabel(context, scope, date),
                style: theme.textTheme.labelLarge?.copyWith(color: c.muted),
              ),
            ),
          ),
          if (spent != BigInt.zero)
            Text(
              moneyText(context, scope, spent, scope.currency),
              style: theme.textTheme.labelLarge?.copyWith(
                color: c.muted,
                fontFeatures: tabular,
              ),
            ),
        ],
      ),
    );
  }
}
