import 'dart:convert';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../data/store.dart';
import '../scope.dart';
import '../ui/labels.dart';
import 'board_views.dart';
import 'task_table.dart';

class PagedTasks extends StatefulWidget {
  final BoardsScope scope;
  final String board, search, sort, group;
  final Json filter;
  final bool table;
  final Set<String> selected;
  final ValueChanged<String> onSort, onGroup;
  final void Function(String, bool) select;
  final VoidCallback bulk, clearSelection;
  const PagedTasks({
    super.key,
    required this.scope,
    required this.board,
    required this.search,
    required this.sort,
    required this.group,
    required this.filter,
    required this.table,
    required this.selected,
    required this.onSort,
    required this.onGroup,
    required this.select,
    required this.bulk,
    required this.clearSelection,
  });
  @override
  State<PagedTasks> createState() => _PagedTasksState();
}

class _PagedTasksState extends State<PagedTasks> {
  int offset = 0, generation = 0;
  String key = '';
  BoardsTaskPage? page;
  Object? error;
  bool loading = true;
  String get queryKey => jsonEncode([
    widget.board,
    widget.search,
    widget.sort,
    widget.filter,
    widget.scope.state.revision,
  ]);
  @override
  void initState() {
    super.initState();
    key = queryKey;
    fetch();
  }

  @override
  void didUpdateWidget(covariant PagedTasks old) {
    super.didUpdateWidget(old);
    if (key != queryKey) {
      key = queryKey;
      offset = 0;
      fetch();
    }
  }

  Future<void> fetch() async {
    final token = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await (widget.scope.controller.store as BoardsPagedStore)
          .taskPage(
            board: widget.board,
            search: widget.search,
            filter: {...widget.filter, 'parentOnly': true},
            sort: widget.sort,
            offset: offset,
            limit: 100,
            expectedRevision: widget.scope.state.revision,
          );
      if (!mounted || token != generation) return;
      setState(() {
        page = result;
        loading = false;
      });
    } catch (e) {
      if (mounted && token == generation)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[], tasks = page?.tasks ?? <BoardRecord>[];
    if (widget.group == 'flat') {
      rows.addAll(tasks);
    } else {
      final groups = <String, List<BoardRecord>>{};
      for (final t in tasks) {
        final value = switch (widget.group) {
          'category' =>
            widget.scope.state
                    .maybe('categories', t.data['category'])
                    ?.str('title') ??
                tr(context, 'Uncategorized', 'Chưa phân nhóm'),
          'status' =>
            widget.scope.state.get('statuses', t.str('status')).str('title'),
          _ =>
            t.data['due'] == null
                ? tr(context, 'No deadline', 'Chưa có hạn')
                : deadlineLabel(
                    context,
                    object(t.data['due']),
                    widget.scope.state.get('boards', widget.board).str('zone'),
                  ),
        };
        (groups[value] ??= []).add(t);
      }
      for (final e in groups.entries) {
        rows.add('${e.key} · ${e.value.length}');
        rows.addAll(e.value);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${page?.total ?? 0} ${tr(context, 'tasks', 'task')}'),
            DropdownButton<String>(
              value: widget.sort,
              items: [
                for (final (id, en, vi) in [
                  ('manual', 'Manual', 'Thủ công'),
                  ('due', 'Deadline', 'Hạn'),
                  ('priority', 'Priority', 'Ưu tiên'),
                  ('title', 'Title', 'Tên'),
                  ('created', 'Created', 'Ngày tạo'),
                  ('updated', 'Updated', 'Cập nhật'),
                ])
                  DropdownMenuItem(value: id, child: Text(tr(context, en, vi))),
              ],
              onChanged: (v) => widget.onSort(v!),
            ),
            if (!widget.table)
              DropdownButton<String>(
                value: widget.group,
                items: [
                  for (final (id, en, vi) in [
                    ('flat', 'Ungrouped', 'Không nhóm'),
                    ('category', 'Category', 'Nhóm'),
                    ('status', 'Status', 'Trạng thái'),
                    ('date', 'Deadline', 'Hạn'),
                  ])
                    DropdownMenuItem(
                      value: id,
                      child: Text(tr(context, en, vi)),
                    ),
                ],
                onChanged: (v) => widget.onGroup(v!),
              ),
            if (widget.selected.isNotEmpty) ...[
              Text(
                '${widget.selected.length} ${tr(context, 'selected', 'đã chọn')}',
              ),
              TextButton(
                onPressed: widget.bulk,
                child: Text(tr(context, 'Bulk edit', 'Sửa hàng loạt')),
              ),
              IconButton(
                tooltip: tr(context, 'Clear selection', 'Bỏ chọn'),
                onPressed: widget.clearSelection,
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(boardsError(context, error!)),
          TextButton(
            onPressed: () => widget.scope.run(context, () async {
              await widget.scope.controller.load();
              if (mounted) fetch();
            }),
            child: Text(tr(context, 'Reload & retry', 'Tải lại và thử lại')),
          ),
        ],
        if (!loading && error == null && tasks.isEmpty)
          Text(tr(context, 'No matching tasks', 'Không có task phù hợp')),
        Expanded(
          child: widget.table
              ? TaskTable(
                  scope: widget.scope,
                  board: widget.board,
                  tasks: tasks,
                  selected: widget.selected,
                  select: widget.select,
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    if (row is String)
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          row,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      );
                    final task = row as BoardRecord;
                    return TaskRow(
                      scope: widget.scope,
                      task: task,
                      selected: widget.selected.contains(task.id),
                      onSelected: (v) => widget.select(task.id, v),
                    );
                  },
                ),
        ),
        if (widget.group != 'flat' && !widget.table)
          Text(
            tr(
              context,
              'Grouping applies within this page. Selection is kept across pages.',
              'Nhóm trong trang hiện tại. Lựa chọn được giữ khi đổi trang.',
            ),
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: loading || offset == 0
                  ? null
                  : () {
                      offset = (offset - 100).clamp(0, offset);
                      fetch();
                    },
              icon: const Icon(Icons.chevron_left),
              label: Text(tr(context, 'Previous', 'Trước')),
            ),
            Text(
              '${page?.total == 0 ? 0 : offset + 1}–${(offset + tasks.length).clamp(0, page?.total ?? 0)} / ${page?.total ?? 0}',
            ),
            TextButton.icon(
              onPressed: loading || offset + tasks.length >= (page?.total ?? 0)
                  ? null
                  : () {
                      offset += 100;
                      fetch();
                    },
              icon: const Icon(Icons.chevron_right),
              label: Text(tr(context, 'Next', 'Tiếp')),
            ),
          ],
        ),
      ],
    );
  }
}
