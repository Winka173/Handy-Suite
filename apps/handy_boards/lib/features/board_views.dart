import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/form.dart';
import 'editors.dart';
import 'task_detail.dart';
import '../ui/labels.dart';

const categoryHues = [
  Color(0xff2563eb),
  Color(0xffa16207),
  Color(0xff047857),
  Color(0xffbe185d),
  Color(0xff7e22ce),
  Color(0xff0e7490),
  Color(0xffc2410c),
  Color(0xff525252),
];
Color categoryHue(BoardRecord? c) =>
    categoryHues[(c?.number('color') ?? 7).abs() % categoryHues.length];

class TaskRow extends StatelessWidget {
  final BoardsScope scope;
  final BoardRecord task;
  final bool category;
  final bool? selected;
  final ValueChanged<bool>? onSelected;
  const TaskRow({
    super.key,
    required this.scope,
    required this.task,
    this.category = true,
    this.selected,
    this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    final s = scope.state,
        t = task,
        c = s.maybe('categories', t.data['category']),
        st = s.get('statuses', t.str('status')),
        checklist = s.related('checklist', t.id),
        attachments = s.related('attachments', t.id);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: selected != null
            ? Checkbox(
                value: selected,
                semanticLabel:
                    '${tr(context, 'Select task', 'Chọn task')}: ${t.str('title')}',
                onChanged: (v) => onSelected?.call(v!),
              )
            : Checkbox(
                semanticLabel:
                    '${tr(context, 'Complete task', 'Hoàn tất task')}: ${t.str('title')}',
                value: st.flag('done'),
                onChanged: scope.controller.busy
                    ? null
                    : (v) => scope.run(context, () async {
                        final statuses = s
                            .rows('statuses')
                            .where(
                              (r) =>
                                  r.str('board') == t.str('board') &&
                                  r.flag('done') == v,
                            )
                            .toList();
                        if (statuses.isEmpty)
                          throw const FormatException(
                            'Configure a matching workflow status first',
                          );
                        await scope.controller.change(
                          (s) => changeStatus(
                            s,
                            t.id,
                            statuses.first.id,
                            now: scope.clock(),
                          ),
                        );
                      }),
              ),
        title: Text(
          t.str('title'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (category)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, color: categoryHue(c)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      c?.str('title') ??
                          tr(context, 'Uncategorized', 'Chưa phân nhóm'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            Text(
              st.str('title'),
              style: TextStyle(
                fontWeight: st.flag('done') ? FontWeight.w500 : null,
              ),
            ),
            if (checklist.isNotEmpty)
              Text(
                '${checklist.where((r) => r.flag('done')).length}/${checklist.length} ${tr(context, 'checklist', 'checklist')}',
              ),
            if (attachments.isNotEmpty)
              Text(
                '${attachments.length} ${tr(context, 'attachments', 'tệp')}',
              ),
            for (final id in t.strings('tags').take(3))
              Text('#${s.get('tags', id).str('title')}'),
            if (t.strings('tags').length > 3)
              Text(
                '+${t.strings('tags').length - 3} ${tr(context, 'tags', 'tag')}',
              ),
            if (t.data['due'] != null)
              Text(
                deadlineLabel(
                  context,
                  object(t.data['due']),
                  s.get('boards', t.str('board')).str('zone'),
                ),
              ),
            if (t.number('priority') >= 2)
              Text(
                tr(
                  context,
                  t.number('priority') == 3 ? 'Urgent' : 'High',
                  t.number('priority') == 3 ? 'Khẩn' : 'Cao',
                ),
              ),
            if (blocked(s, t)) Text(tr(context, 'Blocked', 'Bị chặn')),
          ],
        ),
        onTap: () => showTask(context, scope, t.id),
        trailing: PopupMenuButton<String>(
          tooltip: tr(context, 'Change status', 'Đổi trạng thái'),
          onSelected: (id) => scope.run(
            context,
            () => scope.controller.change((s) {
              if (id == '#up' || id == '#down') {
                final siblings = queryTasks(s, board: t.str('board'))
                        .where(
                          (r) =>
                              r.data['category'] == t.data['category'] &&
                              r.data['parent'] == t.data['parent'],
                        )
                        .map((r) => r.id)
                        .toList(),
                    i = siblings.indexOf(t.id),
                    j = id == '#up' ? i - 1 : i + 1;
                if (j < 0 || j >= siblings.length) return s;
                siblings[i] = siblings[j];
                siblings[j] = t.id;
                return reorder(s, 'tasks', siblings);
              }
              return changeStatus(s, t.id, id, now: scope.clock());
            }),
          ),
          itemBuilder: (context) => [
            for (final r
                in s
                    .rows('statuses')
                    .where((r) => r.str('board') == t.str('board')))
              PopupMenuItem(value: r.id, child: Text(r.str('title'))),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: '#up',
              child: Text(tr(context, 'Move earlier', 'Chuyển lên')),
            ),
            PopupMenuItem(
              value: '#down',
              child: Text(tr(context, 'Move later', 'Chuyển xuống')),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryBoard extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  final List<BoardRecord> tasks;
  const CategoryBoard({
    super.key,
    required this.scope,
    required this.board,
    required this.tasks,
  });
  @override
  State<CategoryBoard> createState() => _CategoriesState();
}

class _CategoriesState extends State<CategoryBoard> {
  late final collapsed =
      (object(
                    widget.scope.state.preferences['categoryLayout'] ?? {},
                  )[widget.board]?['collapsed']
                  as List? ??
              [])
          .cast<String>()
          .toSet();
  late bool compact =
      object(
        widget.scope.state.preferences['categoryLayout'] ?? {},
      )[widget.board]?['compact'] !=
      false;
  late bool listLayout =
      object(
        widget.scope.state.preferences['categoryLayout'] ?? {},
      )[widget.board]?['list'] ==
      true;
  void saveLayout(BuildContext context) => widget.scope.run(
    context,
    () => widget.scope.controller.change(
      (s) => s.copy(
        preferences: {
          ...s.preferences,
          'categoryLayout': {
            ...object(s.preferences['categoryLayout'] ?? {}),
            widget.board: {
              'compact': compact,
              'list': listLayout,
              'collapsed': collapsed.toList(),
            },
          },
        },
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final scope = widget.scope,
        s = scope.state,
        categories =
            s
                .rows('categories')
                .where((c) => c.str('board') == widget.board)
                .toList()
              ..sort((a, b) => a.number('order').compareTo(b.number('order')));
    final groups = <String, List<BoardRecord>>{
      for (final c in categories) c.id: [],
      '': [],
    };
    for (final t in widget.tasks.where((t) => t.data['parent'] == null))
      (groups[t.str('category')] ??= []).add(t);
    final shown = <BoardRecord?>[
      ...categories,
      if (groups['']!.isNotEmpty) null,
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        // Four identities in 2x2 at >=344px content; single column at 320 or large text.
        final maxColumns = scale > 1.3 || listLayout
            ? 1
            : box.maxWidth >= 1000
            ? 4
            : box.maxWidth >= 720
            ? 3
            : box.maxWidth >= 328
            ? 2
            : 1;
        final columns = shown.length == 4 && maxColumns == 3 ? 2 : maxColumns;
        final width = (box.maxWidth - (columns - 1) * 16) / columns;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: tr(
                    context,
                    'Toggle category grid/list',
                    'Đổi lưới/danh sách nhóm',
                  ),
                  onPressed: () {
                    setState(() => listLayout = !listLayout);
                    saveLayout(context);
                  },
                  icon: Icon(
                    listLayout ? Icons.grid_view : Icons.view_agenda_outlined,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => scope.run(
                    context,
                    () => editCategory(context, scope, widget.board),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(tr(context, 'Add category', 'Thêm nhóm')),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => compact = !compact);
                    saveLayout(context);
                  },
                  icon: Icon(
                    compact
                        ? Icons.view_agenda_outlined
                        : Icons.grid_view_outlined,
                  ),
                  label: Text(
                    tr(
                      context,
                      compact ? 'Show task previews' : 'Four-block overview',
                      compact ? 'Hiện task xem trước' : 'Tổng quan bốn nhóm',
                    ),
                  ),
                ),
              ],
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    context,
                    'Create any categories you need. Tasks can also stay uncategorized.',
                    'Tạo các nhóm bạn cần. Task cũng có thể để chưa phân nhóm.',
                  ),
                ),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final c in shown)
                  SizedBox(
                    width: width,
                    child: _card(
                      context,
                      c,
                      groups[c?.id ?? ''] ?? [],
                      categories,
                      compact,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _card(
    BuildContext context,
    BoardRecord? c,
    List<BoardRecord> tasks,
    List<BoardRecord> ordered,
    bool dense,
  ) {
    final scope = widget.scope,
        id = c?.id ?? '',
        stats = summary(
          scope.state,
          tasks,
          now: scope.clock(),
          viewZone: scope.state.get('boards', widget.board).str('zone'),
        ),
        due =
            tasks
                .where(
                  (t) => !completed(scope.state, t) && t.data['due'] != null,
                )
                .toList()
              ..sort(
                (a, b) => deadlineSort(
                  object(a.data['due']),
                ).compareTo(deadlineSort(object(b.data['due']))),
              );
    final content = Container(
      key: ValueKey('category-$id'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: categoryHue(c), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openCategory(context, c, tasks),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      c?.str('title') ??
                          tr(context, 'Uncategorized', 'Chưa phân nhóm'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: dense
                          ? Theme.of(context).textTheme.titleSmall
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              if (c != null)
                PopupMenuButton<String>(
                  tooltip: tr(context, 'Category actions', 'Thao tác nhóm'),
                  onSelected: (v) => scope.run(context, () async {
                    if (v == 'edit') {
                      await editCategory(context, scope, widget.board, id: id);
                    }
                    if (v == 'collapse') {
                      setState(
                        () => collapsed.contains(id)
                            ? collapsed.remove(id)
                            : collapsed.add(id),
                      );
                      if (context.mounted) saveLayout(context);
                    }
                    if (v == 'up' || v == 'down') {
                      final ids = ordered.map((r) => r.id).toList(),
                          i = ids.indexOf(id),
                          j = v == 'up' ? i - 1 : i + 1;
                      if (j >= 0 && j < ids.length) {
                        ids[i] = ids[j];
                        ids[j] = id;
                        await scope.controller.change(
                          (s) => reorder(s, 'categories', ids),
                        );
                      }
                    }
                    if (v == 'delete' &&
                        context.mounted &&
                        await confirmBoards(
                          context,
                          tr(context, 'Remove category?', 'Xóa nhóm?'),
                          tr(
                            context,
                            'Tasks move to Uncategorized. Tasks are not deleted.',
                            'Task chuyển sang Chưa phân nhóm, không bị xóa.',
                          ),
                        )) {
                      await scope.controller.change(
                        (s) => deleteCategory(s, id),
                      );
                    }
                  }),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(tr(context, 'Edit', 'Sửa')),
                    ),
                    PopupMenuItem(
                      value: 'collapse',
                      child: Text(tr(context, 'Collapse / expand', 'Thu / mở')),
                    ),
                    PopupMenuItem(
                      value: 'up',
                      child: Text(tr(context, 'Move earlier', 'Chuyển lên')),
                    ),
                    PopupMenuItem(
                      value: 'down',
                      child: Text(tr(context, 'Move later', 'Chuyển xuống')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(tr(context, 'Remove category', 'Xóa nhóm')),
                    ),
                  ],
                ),
            ],
          ),
          Text(
            '${stats['done']} / ${stats['total']} ${tr(context, 'tasks done', 'task xong')} · ${stats['percent'] == null ? '—' : '${(stats['percent'] as num).round()}%'}',
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: stats['total'] == 0
                ? 0
                : (stats['done'] as int) / (stats['total'] as int),
            minHeight: 3,
            color: categoryHue(c),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats['overdue']} ${tr(context, 'overdue', 'quá hạn')}',
            style: stats['overdue'] > 0
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
          Text(
            due.isEmpty
                ? tr(context, 'No upcoming deadline', 'Chưa có hạn sắp tới')
                : '${tr(context, 'Next', 'Tiếp')}: ${deadlineLabel(context, object(due.first.data['due']), scope.state.get('boards', widget.board).str('zone'))}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!dense && !collapsed.contains(id))
            ...tasks
                .take(c?.number('preview', 3) ?? 3)
                .map(
                  (t) => LongPressDraggable<String>(
                    data: t.id,
                    feedback: Material(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t.str('title')),
                      ),
                    ),
                    child: TaskRow(scope: scope, task: t, category: false),
                  ),
                ),
          TextButton.icon(
            onPressed: () => scope.run(
              context,
              () => quickTask(context, scope, widget.board, category: c?.id),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(context, 'Add task', 'Thêm task')),
          ),
        ],
      ),
    );
    final target = DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data.startsWith('category:')
          ? c != null &&
                scope.state
                        .maybe('categories', d.data.substring(9))
                        ?.str('board') ==
                    widget.board
          : scope.state.maybe('tasks', d.data)?.str('board') == widget.board,
      onAcceptWithDetails: (d) => scope.run(
        context,
        () => scope.controller.change((s) {
          if (d.data.startsWith('category:')) {
            final source = d.data.substring(9),
                ids = ordered.map((r) => r.id).toList()..remove(source),
                index = ids.indexOf(id);
            if (index < 0) return s;
            ids.insert(index, source);
            return reorder(s, 'categories', ids);
          }
          return moveTasks(s, {d.data}, widget.board, category: c?.id);
        }),
      ),
      builder: (context, candidates, rejected) => content,
    );
    return c == null
        ? target
        : LongPressDraggable<String>(
            data: 'category:${c.id}',
            feedback: Material(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(c.str('title')),
              ),
            ),
            child: target,
          );
  }

  void _openCategory(
    BuildContext context,
    BoardRecord? c,
    List<BoardRecord> tasks,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            c?.str('title') ?? tr(context, 'Uncategorized', 'Chưa phân nhóm'),
          ),
        ),
        body: AnimatedBuilder(
          animation: widget.scope.controller,
          builder: (context, _) {
            final current = queryTasks(
              widget.scope.state,
              board: widget.board,
              filter: {'category': c?.id, 'parentOnly': true},
            );
            return ListView.builder(
              itemCount: current.length,
              itemBuilder: (context, i) =>
                  TaskRow(scope: widget.scope, task: current[i]),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: tr(context, 'Add task', 'Thêm task'),
          onPressed: () => widget.scope.run(
            context,
            () =>
                quickTask(context, widget.scope, widget.board, category: c?.id),
          ),
          child: const Icon(Icons.add),
        ),
      ),
    ),
  );
}

class KanbanBoard extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  final List<BoardRecord> tasks;
  const KanbanBoard({
    super.key,
    required this.scope,
    required this.board,
    required this.tasks,
  });
  @override
  State<KanbanBoard> createState() => _KanbanState();
}

class _KanbanState extends State<KanbanBoard> {
  late final ScrollController horizontal;
  BoardsScope get scope => widget.scope;
  String get board => widget.board;
  List<BoardRecord> get tasks => widget.tasks;
  @override
  void initState() {
    super.initState();
    final statuses =
        scope.state
            .rows('statuses')
            .where((r) => r.str('board') == board)
            .toList()
          ..sort((a, b) => a.number('order').compareTo(b.number('order')));
    final first = statuses.indexWhere(
      (st) => tasks.any((t) => t.str('status') == st.id),
    );
    horizontal = ScrollController(
      initialScrollOffset: first < 0 ? 0 : first * 296.0,
    );
  }

  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statuses =
        scope.state
            .rows('statuses')
            .where((r) => r.str('board') == board)
            .toList()
          ..sort((a, b) => a.number('order').compareTo(b.number('order')));
    final groups = <String, List<BoardRecord>>{};
    for (final t in tasks.where((r) => r.data['parent'] == null))
      (groups[t.str('status')] ??= []).add(t);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                scope.run(context, () => editStatus(context, scope, board)),
            icon: const Icon(Icons.add),
            label: Text(tr(context, 'Add workflow status', 'Thêm trạng thái')),
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: horizontal,
            scrollDirection: Axis.horizontal,
            itemCount: statuses.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final st = statuses[i], rows = groups[st.id] ?? [];
              return SizedBox(
                width: 280,
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (d) =>
                      scope.state.maybe('tasks', d.data)?.str('board') == board,
                  onAcceptWithDetails: (d) => scope.run(
                    context,
                    () => scope.controller.change(
                      (s) => changeStatus(s, d.data, st.id, now: scope.clock()),
                    ),
                  ),
                  builder: (context, candidates, rejected) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        // The status keeps its colour as a dot; the name
                        // reads in ink.
                        title: Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: categoryHue(st),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: '  ${st.str('title')} · ${rows.length}',
                              ),
                            ],
                          ),
                        ),
                        subtitle: st.number('wip') > 0
                            ? Text(
                                'WIP ${rows.length}/${st.number('wip')}',
                                style: rows.length > st.number('wip')
                                    ? TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      )
                                    : null,
                              )
                            : null,
                        trailing: IconButton(
                          tooltip: tr(context, 'Edit status', 'Sửa trạng thái'),
                          icon: const Icon(Icons.more_horiz),
                          onPressed: () => scope.run(
                            context,
                            () => editStatus(context, scope, board, id: st.id),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, j) =>
                              LongPressDraggable<String>(
                                data: rows[j].id,
                                feedback: Material(
                                  elevation: 4,
                                  child: SizedBox(
                                    width: 260,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(rows[j].str('title')),
                                    ),
                                  ),
                                ),
                                child: Card(
                                  elevation: 0,
                                  child: TaskRow(scope: scope, task: rows[j]),
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
