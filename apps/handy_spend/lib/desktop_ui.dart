part of 'app.dart';

extension _Desktop on _SpendHomeState {
  Widget keyboardCommands(Widget child) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
        if (!busy) unawaited(transactionEditor());
      },
      const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
        if (!busy) unawaited(importWizard());
      },
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
        if (!busy) unawaited(run(c.undo));
      },
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
        refresh(() => tab = 1);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) searchFocus.requestFocus();
        });
      },
    },
    child: Focus(autofocus: true, child: child),
  );
  Widget desktopHistory() {
    final rows = filtered,
        shown = rows.take(page * 100).toList(),
        accounts = {for (final a in s.accounts) a.id: a};
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchText,
                  focusNode: searchFocus,
                  key: const Key('spend-search'),
                  decoration: InputDecoration(
                    labelText: t(
                      'Search payee, note, tags · Ctrl+F',
                      'Tìm đối tác, ghi chú, nhãn · Ctrl+F',
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) => refresh(() {
                    search = v;
                    page = 1;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              button(
                'Filters',
                'Bộ lọc',
                Icons.filter_list,
                () => unawaited(filters()),
              ),
            ],
          ),
        ),
        if (selected.isNotEmpty)
          Wrap(
            spacing: 12,
            children: [
              Text('${selected.length} ${t('selected', 'đã chọn')}'),
              TextButton(
                onPressed: () => unawaited(run(bulkDelete)),
                child: Text(t('Delete selected', 'Xóa mục chọn')),
              ),
              TextButton(
                onPressed: () =>
                    unawaited(run(() => exportData('csv', onlySelected: true))),
                child: Text(t('Export selected', 'Xuất mục chọn')),
              ),
              TextButton(
                onPressed: () => refresh(selected.clear),
                child: Text(t('Clear', 'Bỏ chọn')),
              ),
            ],
          ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(t('Date', 'Ngày'))),
                  DataColumn(label: Text(t('Account', 'Tài khoản'))),
                  DataColumn(
                    label: SizedBox(
                      width: tableWidth,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(t('Payee / note', 'Đối tác / ghi chú')),
                          ),
                          Semantics(
                            label: t(
                              'Resize payee column',
                              'Đổi độ rộng cột đối tác',
                            ),
                            onIncrease: () => refresh(
                              () => tableWidth = (tableWidth + 20).clamp(
                                120,
                                500,
                              ),
                            ),
                            onDecrease: () => refresh(
                              () => tableWidth = (tableWidth - 20).clamp(
                                120,
                                500,
                              ),
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeColumn,
                              child: GestureDetector(
                                key: const Key('spend-column-resize'),
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (d) => refresh(
                                  () => tableWidth = (tableWidth + d.delta.dx)
                                      .clamp(120, 500),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_indicator),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataColumn(label: Text(t('Type', 'Loại'))),
                  DataColumn(
                    label: Text(t('Amount', 'Số tiền')),
                    numeric: true,
                  ),
                  DataColumn(label: Text(t('Status', 'Trạng thái'))),
                  DataColumn(label: Text(t('Actions', 'Thao tác'))),
                ],
                rows: [
                  for (final e in shown)
                    DataRow(
                      selected: selected.contains(e.id),
                      onSelectChanged: (v) => refresh(
                        () => v == true
                            ? selected.add(e.id)
                            : selected.remove(e.id),
                      ),
                      cells: [
                        DataCell(Text(dateLabel(reportDay(e.when, s.zone)))),
                        DataCell(Text(accounts[e.account]!.name)),
                        DataCell(
                          SizedBox(
                            width: tableWidth,
                            child: Text(
                              '${e.payee}\n${e.note}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onTap: () => unawaited(transactionEditor(e)),
                        ),
                        DataCell(Text(kindLabel(e.kind))),
                        DataCell(
                          Text(money(e.amount, accounts[e.account]!.currency)),
                        ),
                        DataCell(
                          Text(
                            e.status == 'posted'
                                ? t('Posted', 'Đã ghi sổ')
                                : t('Pending', 'Dự kiến'),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            tooltip: t(
                              'Edit / refund / delete',
                              'Sửa / hoàn tiền / xóa',
                            ),
                            onPressed: () => unawaited(transactionActions(e)),
                            icon: const Icon(Icons.more_horiz),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        Text(
          '${shown.length} / ${rows.length} ${t('transactions · drop one CSV/XLSX to import', 'giao dịch · kéo một CSV/XLSX vào để nhập')}',
        ),
        if (rows.length > shown.length)
          TextButton(
            onPressed: () => refresh(() => page++),
            child: Text(t('Load 100 more', 'Tải thêm 100 mục')),
          ),
      ],
    );
  }
}
