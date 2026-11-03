import 'package:handy_ui/kit.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/labels.dart';
import 'board_views.dart';
import 'rule_editor.dart';
import 'saved_view_editor.dart';
import 'remaining_views.dart';

bool boardsPro(BuildContext context) =>
    LifetimeScope.maybeOf(context)?.pro == true;
Future<bool> requireBoardsPro(BuildContext context) async {
  if (boardsPro(context)) return true;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr(context, 'Pro Lifetime', 'Pro trọn đời')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(
              context,
              'This advanced tool requires verified Pro ownership. Core tasks and full backups stay free. Store purchase is available only after publisher configuration.',
              'Công cụ nâng cao cần quyền Pro đã xác minh. Task cơ bản và sao lưu đầy đủ vẫn miễn phí. Chỉ mua được sau khi cấu hình nhà phát hành.',
            ),
          ),
          const LifetimeSettings(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Close', 'Đóng')),
        ),
      ],
    ),
  );
  return false;
}

class AdvancedPage extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  const AdvancedPage({super.key, required this.scope, required this.board});
  @override
  State<AdvancedPage> createState() => _AdvancedState();
}

class _AdvancedState extends State<AdvancedPage> {
  String tab = 'priority';
  BoardsScope get scope => widget.scope;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scope.controller,
    builder: (context, _) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Advanced planning', 'Kế hoạch nâng cao')),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (id, en, vi) in [
                      ('priority', 'Smart priority', 'Ưu tiên thông minh'),
                      ('fields', 'Custom fields', 'Trường tùy chỉnh'),
                      ('views', 'Saved views', 'View đã lưu'),
                      ('rules', 'Rules', 'Quy tắc'),
                      ('study-report', 'Study report', 'Báo cáo học tập'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tr(context, en, vi)),
                          selected: tab == id,
                          onSelected: (_) => setState(() => tab = id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!boardsPro(context))
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr(
                              context,
                              'Advanced planning uses Pro Lifetime. Your existing task dates, dependencies and data are preserved.',
                              'Kế hoạch nâng cao dùng Pro trọn đời. Ngày, phụ thuộc và dữ liệu task hiện có được giữ nguyên.',
                            ),
                          ),
                          TextButton(
                            onPressed: () => requireBoardsPro(context),
                            child: Text(
                              tr(
                                context,
                                'View purchase availability',
                                'Xem khả năng mua',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: switch (tab) {
                    'priority' => _priority(context),
                    'fields' => _fields(context),
                    'views' => _views(context),
                    'study-report' => StudyReports(
                      scope: scope,
                      board: widget.board,
                    ),
                    _ => _rules(context),
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
  Widget _priority(BuildContext context) {
    final s = scope.state,
        b = s.get('boards', widget.board),
        weights = object(b.data['priorityWeights'] ?? {}),
        tasks = queryTasks(
          s,
          board: widget.board,
        ).where((t) => !completed(s, t)).toList();
    final scores = {
      for (final t in tasks)
        t.id: smartPriority(s, t, scope.clock(), weights: weights),
    };
    tasks.sort(
      (a, b) => (scores[b.id]!['score'] as num).compareTo(
        scores[a.id]!['score'] as num,
      ),
    );
    return ListView(
      children: [
        Text(
          tr(
            context,
            'Deterministic scoring, not AI. You can override the result by pinning or changing priority.',
            'Chấm điểm theo quy tắc, không phải AI. Bạn có thể ghim hoặc đổi ưu tiên để điều chỉnh.',
          ),
        ),
        SwitchListTile(
          title: Text(
            tr(context, 'Enable smart suggestions', 'Bật gợi ý ưu tiên'),
          ),
          value: b.data['priorityEnabled'] != false,
          onChanged: (v) => scope.run(
            context,
            () => scope.controller.change(
              (s) => s.put(
                'boards',
                s.get('boards', widget.board).copy({'priorityEnabled': v}),
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () => scope.run(
            context,
            () => boardForm(
              context,
              tr(context, 'Score weights', 'Trọng số điểm'),
              [
                for (final key in [
                  'priority',
                  'pin',
                  'blocked',
                  'overdue',
                  'soon',
                  'short',
                  'planned',
                  'category',
                ])
                  BoardField(
                    key,
                    key,
                    {
                      'priority': 'Ưu tiên',
                      'pin': 'Ghim',
                      'blocked': 'Bị chặn',
                      'overdue': 'Quá hạn',
                      'soon': 'Sắp hạn',
                      'short': 'Việc ngắn',
                      'planned': 'Dự kiến hôm nay',
                      'category': 'Trọng số nhóm',
                    }[key]!,
                    kind: 'number',
                  ),
              ],
              {
                'priority': '${weights['priority'] ?? 10}',
                'pin': '${weights['pin'] ?? 50}',
                'blocked': '${weights['blocked'] ?? 100}',
                'overdue': '${weights['overdue'] ?? 40}',
                'soon': '${weights['soon'] ?? 20}',
                'short': '${weights['short'] ?? 5}',
                'planned': '${weights['planned'] ?? 15}',
                'category': '${weights['category'] ?? 1}',
              },
              (v) async {
                final w = {for (final key in v.keys) key: double.parse(v[key])};
                if (tasks.isNotEmpty)
                  smartPriority(s, tasks.first, scope.clock(), weights: w);
                await scope.controller.change(
                  (s) => s.put('boards', b.copy({'priorityWeights': w})),
                );
              },
            ),
          ),
          child: Text(tr(context, 'Configure scoring', 'Cấu hình điểm')),
        ),
        if (b.data['priorityEnabled'] != false)
          for (final t in tasks.take(200))
            ListTile(
              title: Text(t.str('title')),
              subtitle: Text(
                (scores[t.id]!['reasons'] as List)
                    .cast<String>()
                    .map((r) => priorityReason(context, r))
                    .join(' · '),
              ),
              trailing: Text('${scores[t.id]!['score']}'),
            ),
      ],
    );
  }

  Widget _fields(BuildContext context) => ListView(
    children: [
      TextButton.icon(
        onPressed: () => scope.run(context, () => _field(context)),
        icon: const Icon(Icons.add),
        label: Text(
          tr(context, 'Add field definition', 'Thêm định nghĩa trường'),
        ),
      ),
      for (final f
          in scope.state
              .rows('fields')
              .where((f) => f.str('board') == widget.board))
        ListTile(
          title: Text(f.str('title')),
          subtitle: Text(f.str('type')),
          onTap: () => scope.run(context, () => _field(context, old: f)),
        ),
    ],
  );
  Future<void> _field(BuildContext context, {BoardRecord? old}) => boardForm(
    context,
    tr(context, 'Custom field', 'Trường tùy chỉnh'),
    [
      const BoardField('title', 'Name', 'Tên'),
      BoardField(
        'type',
        'Type',
        'Kiểu',
        kind: 'select',
        options: {
          'text': tr(context, 'Text', 'Văn bản'),
          'number': tr(context, 'Decimal', 'Thập phân'),
          'date': tr(context, 'Date', 'Ngày'),
          'checkbox': tr(context, 'Checkbox', 'Đánh dấu'),
          'single': tr(context, 'Single select', 'Chọn một'),
          'multi': tr(context, 'Multi select', 'Chọn nhiều'),
          'url': 'URL',
        },
      ),
      const BoardField(
        'options',
        'Choices separated by commas',
        'Các lựa chọn ngăn dấu phẩy',
        optional: true,
      ),
      const BoardField(
        'default',
        'Default (multiple choices: comma separated; checkbox: true/false; empty = none)',
        'Mặc định (nhiều lựa chọn: ngăn dấu phẩy; đánh dấu: true/false; trống = không có)',
        optional: true,
      ),
    ],
    {
      'title': old?.str('title') ?? '',
      'type': old?.str('type') ?? 'text',
      'options': old?.strings('options').join(',') ?? '',
      'default': old?.data['default'] == null
          ? ''
          : old?.str('type') == 'multi'
          ? (old!.data['default'] as List).join(', ')
          : old!.data['default'].toString(),
    },
    (v) async {
      await scope.controller.change(
        (s) => s.put(
          'fields',
          BoardRecord({
            ...?old?.data,
            'id': old?.id ?? newId(),
            'board': widget.board,
            'title': v['title'],
            'type': v['type'],
            'default': v['default'] == ''
                ? null
                : v['type'] == 'multi'
                ? (v['default'] as String)
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .toList()
                : v['type'] == 'checkbox'
                ? switch (v['default']) {
                    'true' => true,
                    'false' => false,
                    _ => throw const FormatException(
                      'Checkbox default: true or false',
                    ),
                  }
                : v['default'],
            'options': (v['options'] as String)
                .split(',')
                .map((v) => v.trim())
                .where((v) => v.isNotEmpty)
                .toList(),
          }),
        ),
      );
    },
    footer: [
      Text(
        tr(
          context,
          'Changes are rejected if existing task values would become invalid.',
          'Từ chối thay đổi nếu làm giá trị task hiện có không hợp lệ.',
        ),
      ),
    ],
  );
  Widget _views(BuildContext context) => ListView(
    children: [
      TextButton.icon(
        onPressed: () => scope.run(context, () => _view(context)),
        icon: const Icon(Icons.add),
        label: Text(tr(context, 'Save a smart view', 'Lưu view thông minh')),
      ),
      for (final v
          in scope.state
              .rows('views')
              .where((v) => v.str('board') == widget.board))
        ExpansionTile(
          title: Text(v.str('title')),
          subtitle: Text(
            '${smartViewTasks(scope.state, v).length} ${tr(context, 'tasks', 'task')}',
          ),
          children: [
            TextButton(
              onPressed: () => scope.run(context, () => _view(context, old: v)),
              child: Text(tr(context, 'Edit saved view', 'Sửa view đã lưu')),
            ),
            ..._viewRows(context, v),
            TextButton(
              onPressed: () => scope.run(
                context,
                () => scope.controller.change((s) => s.remove('views', {v.id})),
              ),
              child: Text(tr(context, 'Delete view', 'Xóa view')),
            ),
          ],
        ),
    ],
  );
  List<Widget> _viewRows(BuildContext context, BoardRecord view) {
    final tasks = smartViewTasks(scope.state, view).take(100),
        groups = <String, List<BoardRecord>>{};
    if (view.str('group', 'flat') == 'flat')
      return [for (final t in tasks) TaskRow(scope: scope, task: t)];
    for (final t in tasks) {
      final key = switch (view.str('group')) {
        'category' =>
          scope.state.maybe('categories', t.data['category'])?.str('title') ??
              tr(context, 'Uncategorized', 'Chưa phân nhóm'),
        'status' => scope.state.get('statuses', t.str('status')).str('title'),
        _ =>
          t.data['due'] == null
              ? tr(context, 'No deadline', 'Chưa có hạn')
              : deadlineDay(
                  object(t.data['due']),
                  scope.state.get('boards', widget.board).str('zone'),
                ),
      };
      (groups[key] ??= []).add(t);
    }
    return [
      for (final e in groups.entries) ...[
        Text(e.key, style: Theme.of(context).textTheme.titleMedium),
        for (final t in e.value) TaskRow(scope: scope, task: t),
      ],
    ];
  }

  Future<void> _view(BuildContext context, {BoardRecord? old}) =>
      editSavedView(context, scope, widget.board, old: old);
  Widget _rules(BuildContext context) => ListView(
    children: [
      Text(
        tr(
          context,
          'Local rules run transactionally on matching edits while Pro is active. Actions never recursively trigger more rules. No background server.',
          'Quy tắc cục bộ chạy trong giao dịch khi sửa phù hợp và Pro đang hoạt động. Hành động không tự kích hoạt chuỗi quy tắc. Không server nền.',
        ),
      ),
      TextButton.icon(
        onPressed: () => scope.run(context, () => _rule(context)),
        icon: const Icon(Icons.add),
        label: Text(tr(context, 'New rule', 'Quy tắc mới')),
      ),
      TextButton.icon(
        onPressed: () => scope.run(
          context,
          () => scope.controller.change(
            (s) => reconcileOpenRules(s, scope.clock()),
          ),
        ),
        icon: const Icon(Icons.play_arrow_outlined),
        label: Text(
          tr(
            context,
            'Process next app-open batch (up to 100 tasks)',
            'Xử lý lượt mở app tiếp theo (tối đa 100 task)',
          ),
        ),
      ),
      for (final r
          in scope.state
              .rows('rules')
              .where((r) => r.str('board') == widget.board))
        SwitchListTile(
          title: Text(r.str('title')),
          subtitle: Text(
            '${ruleTriggers(context)[r.str('trigger')]}\n${(r.data['actions'] as List).map((a) => ruleActionLabel(context, scope.state, object(a))).join('; ')}',
          ),
          secondary: PopupMenuButton<String>(
            onSelected: (action) => scope.run(context, () async {
              if (action == 'edit') {
                await editAutomationRule(context, scope, widget.board, old: r);
                return;
              }
              if (!await confirmBoards(
                context,
                tr(context, 'Delete rule?', 'Xóa quy tắc?'),
                r.str('title'),
              ))
                return;
              await scope.controller.change((s) {
                final e = BoardsEdit(s);
                e.remove('rules', r.id);
                for (final x
                    in s.rows('executions').where((x) => x.str('rule') == r.id))
                  e.remove('executions', x.id);
                return e.finish();
              });
            }),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(tr(context, 'Edit & preview', 'Sửa và xem trước')),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(tr(context, 'Delete', 'Xóa')),
              ),
            ],
          ),
          value: r.flag('enabled'),
          onChanged: (v) => scope.run(
            context,
            () => scope.controller.change(
              (s) => s.put('rules', r.copy({'enabled': v})),
            ),
          ),
        ),
      const Divider(),
      for (final r
          in scope.state
              .rows('executions')
              .where(
                (r) =>
                    scope.state.maybe('tasks', r.str('task'))?.str('board') ==
                    widget.board,
              )
              .take(100))
        ListTile(
          title: Text(scope.state.get('tasks', r.str('task')).str('title')),
          subtitle: Text(
            '${r.str('at')}${r.flag('delayed') ? ' · ${tr(context, 'App-open processing', 'Xử lý khi mở app')}' : ''}',
          ),
        ),
    ],
  );
  Future<void> _rule(BuildContext context) =>
      editAutomationRule(context, scope, widget.board);
}
