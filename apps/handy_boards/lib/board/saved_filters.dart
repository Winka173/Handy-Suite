import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import 'board_menus.dart' show ProBadge;

/// The board's saved filters: pick one (it narrows the board until cleared),
/// remove one, or make one (Pro): a name, all or any, and a few conditions
/// (column, category, priority, due between two days, has a reminder).
/// Returns the picked filter's id, '' to clear, or null.
Future<String?> savedFiltersSheet(
  BuildContext context,
  BoardsScope scope,
  String board,
  String? active,
) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => ListenableBuilder(
    listenable: scope.controller,
    builder: (sheet, _) {
      final theme = Theme.of(sheet);
      final p = BoardsPalette.of(sheet);
      final list = savedFilters(scope.state, board);
      return ListView(
        key: const Key('filters-sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(sheet, 'Saved filters', 'Bộ lọc đã lưu'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (!hasPro(sheet)) const ProBadge(),
            ],
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                tr(
                  sheet,
                  'None yet. Category, search and "Due in 3 days" stay free; '
                      'saved filters combine conditions and keep a name.',
                  'Chưa có. Nhóm, tìm kiếm và "Hạn trong 3 ngày" vẫn miễn phí; '
                      'bộ lọc đã lưu kết hợp nhiều điều kiện và có tên.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
            ),
          for (final f in list)
            ListTile(
              key: Key('filter-${f.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                f.id == active ? Icons.filter_alt : Icons.filter_alt_outlined,
              ),
              title: Text(f.str('title')),
              subtitle: Text(
                f.str('mode') == 'or'
                    ? tr(
                        sheet,
                        'Any of ${(f.data['conditions'] as List).length}',
                        'Một trong ${(f.data['conditions'] as List).length} điều kiện',
                      )
                    : tr(
                        sheet,
                        'All of ${(f.data['conditions'] as List).length}',
                        'Đủ ${(f.data['conditions'] as List).length} điều kiện',
                      ),
              ),
              onTap: () async {
                if (await requirePro(sheet, ProFeature.savedFilters) &&
                    sheet.mounted) {
                  Navigator.pop(sheet, f.id);
                }
              },
              trailing: IconButton(
                key: Key('filter-delete-${f.id}'),
                tooltip: tr(sheet, 'Remove', 'Xoá'),
                onPressed: () => scope.run(
                  sheet,
                  () => scope.controller.change((s) => deleteFilter(s, f.id)),
                ),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          if (active != null)
            TextButton(
              key: const Key('filter-clear'),
              onPressed: () => Navigator.pop(sheet, ''),
              child: Text(tr(sheet, 'Show every card', 'Hiện mọi thẻ')),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('filter-new'),
            onPressed: () async {
              if (!await requirePro(sheet, ProFeature.savedFilters) ||
                  !sheet.mounted) {
                return;
              }
              final made = await showDialog<(String, bool, List<Json>)>(
                context: sheet,
                builder: (_) => _NewFilter(scope: scope, board: board),
              );
              if (made == null || !sheet.mounted) return;
              await scope.run(
                sheet,
                () => scope.controller.change(
                  (s) => saveFilter(s, board, made.$1, made.$3, any: made.$2),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: Text(tr(sheet, 'New filter', 'Bộ lọc mới')),
          ),
        ],
      );
    },
  ),
);

class _NewFilter extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  const _NewFilter({required this.scope, required this.board});
  @override
  State<_NewFilter> createState() => _NewFilterState();
}

class _NewFilterState extends State<_NewFilter> {
  final name = TextEditingController();
  bool any = false;
  String? column, category;
  int? priority;
  bool? reminder;
  String dueFrom = '', dueTo = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.scope.state;
    final conditions = <Json>[
      if (column != null) {'status': column},
      if (category != null) {'category': category},
      if (priority != null) {'priority': priority},
      if (reminder != null) {'hasReminder': reminder},
      if (dueFrom.isNotEmpty || dueTo.isNotEmpty)
        {
          if (dueFrom.isNotEmpty) 'dueFrom': dueFrom,
          if (dueTo.isNotEmpty) 'dueTo': dueTo,
        },
    ];
    DropdownMenuItem<T> item<T>(T v, String label) =>
        DropdownMenuItem(value: v, child: Text(label));
    return AlertDialog(
      title: Text(tr(context, 'New filter', 'Bộ lọc mới')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('filter-name'),
              controller: name,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                labelText: tr(context, 'Name', 'Tên'),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('filter-column'),
              initialValue: column,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                labelText: tr(context, 'Column', 'Cột'),
              ),
              items: [
                item(null, tr(context, 'Any', 'Bất kỳ')),
                for (final c in columnsOf(s, widget.board))
                  item(c.id, c.str('title')),
              ],
              onChanged: (v) => setState(() => column = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('filter-category'),
              initialValue: category,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                labelText: tr(context, 'Category', 'Nhóm'),
              ),
              items: [
                item(null, tr(context, 'Any', 'Bất kỳ')),
                for (final c in categoriesOf(s, widget.board))
                  item(c.id, c.str('title')),
              ],
              onChanged: (v) => setState(() => category = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: const Key('filter-priority'),
              initialValue: priority,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                labelText: tr(context, 'Priority', 'Ưu tiên'),
              ),
              items: [
                item(null, tr(context, 'Any', 'Bất kỳ')),
                item(3, tr(context, 'High', 'Cao')),
                item(2, tr(context, 'Medium', 'Vừa')),
                item(1, tr(context, 'Normal', 'Thường')),
                item(0, tr(context, 'Low', 'Thấp')),
              ],
              onChanged: (v) => setState(() => priority = v),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    key: const Key('filter-due-from'),
                    onPressed: () async {
                      final v = await pickHandyDate(context, dueFrom);
                      if (v != null) setState(() => dueFrom = v);
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      dueFrom.isEmpty
                          ? tr(context, 'Due from', 'Hạn từ')
                          : dueFrom,
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    key: const Key('filter-due-to'),
                    onPressed: () async {
                      final v = await pickHandyDate(context, dueTo);
                      if (v != null) setState(() => dueTo = v);
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      dueTo.isEmpty ? tr(context, 'Due to', 'Hạn đến') : dueTo,
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: const Key('filter-any'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(context, 'Any condition is enough', 'Chỉ cần một điều kiện'),
              ),
              value: any,
              onChanged: (v) => setState(() => any = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Huỷ')),
        ),
        FilledButton(
          key: const Key('filter-save'),
          onPressed: conditions.isEmpty || name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (name.text, any, conditions)),
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
      ],
    );
  }
}
