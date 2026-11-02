import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/form.dart';
import 'editors.dart';
import 'task_detail.dart';
import 'task_tools.dart';
import '../ui/labels.dart';

class TaskTable extends StatelessWidget {
  final BoardsScope scope;
  final String board;
  final List<BoardRecord> tasks;
  final Set<String> selected;
  final void Function(String, bool) select;
  const TaskTable({
    super.key,
    required this.scope,
    required this.board,
    required this.tasks,
    required this.selected,
    required this.select,
  });
  @override
  Widget build(BuildContext context) {
    final s = scope.state,
        labels = <String, String>{
          'task': tr(context, 'Task', 'Task'),
          'category': tr(context, 'Category', 'Nhóm'),
          'status': tr(context, 'Status', 'Trạng thái'),
          'priority': tr(context, 'Priority', 'Ưu tiên'),
          'due': tr(context, 'Due', 'Hạn'),
          'estimate': tr(context, 'Estimate (min)', 'Ước lượng (phút)'),
          'tags': tr(context, 'Tags', 'Tag'),
          for (final f
              in s.rows('fields').where((f) => f.str('board') == board))
            'field:${f.id}': f.str('title'),
        };
    final saved = object(s.preferences['tableColumns'] ?? {})[board] as List?;
    final columns = [
      'task',
      ...(saved ?? ['category', 'status', 'due', 'estimate'])
          .cast<String>()
          .where((id) => id != 'task' && labels.containsKey(id)),
    ];
    String value(BoardRecord t, String column) => switch (column) {
      'task' => t.str('title'),
      'category' =>
        s.maybe('categories', t.data['category'])?.str('title') ?? '—',
      'status' => s.get('statuses', t.str('status')).str('title'),
      'priority' => [
        tr(context, 'Low', 'Thấp'),
        tr(context, 'Normal', 'Thường'),
        tr(context, 'High', 'Cao'),
        tr(context, 'Urgent', 'Khẩn'),
      ][t.number('priority')],
      'due' =>
        t.data['due'] == null
            ? '—'
            : deadlineLabel(
                context,
                object(t.data['due']),
                s.get('boards', board).str('zone'),
              ),
      'estimate' => t.number('estimate') == 0 ? '—' : '${t.number('estimate')}',
      'tags' =>
        t
            .strings('tags')
            .map((id) => s.get('tags', id).str('title'))
            .join(', '),
      _ =>
        object(t.data['custom'] ?? {})[column.substring(6)]?.toString() ?? '—',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => scope.run(
              context,
              () => boardForm(
                context,
                tr(context, 'Table columns', 'Cột bảng'),
                [
                  for (final e in labels.entries.where((e) => e.key != 'task'))
                    BoardField(
                      e.key,
                      e.value,
                      e.value,
                      kind: 'bool',
                      optional: true,
                    ),
                ],
                {for (final key in labels.keys) key: columns.contains(key)},
                (v) async {
                  await scope.controller.change(
                    (s) => s.copy(
                      preferences: {
                        ...s.preferences,
                        'tableColumns': {
                          ...object(s.preferences['tableColumns'] ?? {}),
                          board: [
                            for (final key in labels.keys)
                              if (key != 'task' && v[key] == true) key,
                          ],
                        },
                      },
                    ),
                  );
                },
              ),
            ),
            icon: const Icon(Icons.view_column_outlined),
            label: Text(tr(context, 'Choose columns', 'Chọn cột')),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 56,
                dataRowMaxHeight:
                    56 +
                    48 *
                        (MediaQuery.textScalerOf(context).scale(14) / 14 - 1)
                            .clamp(0, 4),
                headingRowHeight:
                    56 *
                    (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                      1,
                      3,
                    ),
                columns: [
                  for (final key in columns)
                    DataColumn(
                      label: Text(labels[key]!),
                      numeric: ['estimate', 'priority'].contains(key),
                    ),
                ],
                rows: [
                  for (final t in tasks)
                    DataRow(
                      selected: selected.contains(t.id),
                      onSelectChanged: (v) => select(t.id, v == true),
                      cells: [
                        for (final key in columns)
                          DataCell(
                            SizedBox(
                              width: key == 'task' ? 220 : 130,
                              child: Text(
                                value(t, key),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onTap: () => scope.run(
                              context,
                              () => key == 'task'
                                  ? showTask(context, scope, t.id)
                                  : _edit(context, t, key, labels[key]!),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    BoardRecord task,
    String key,
    String label,
  ) async {
    if (key == 'tags') {
      await taskTags(context, scope, task.id);
      return;
    }
    if (key.startsWith('field:')) {
      await taskCustomFields(context, scope, task.id);
      return;
    }
    final s = scope.state;
    final options = switch (key) {
      'category' => {
        '': tr(context, 'Uncategorized', 'Chưa phân nhóm'),
        ...choices(s, 'categories', board),
      },
      'status' => choices(s, 'statuses', board),
      'priority' => {
        '0': tr(context, 'Low', 'Thấp'),
        '1': tr(context, 'Normal', 'Thường'),
        '2': tr(context, 'High', 'Cao'),
        '3': tr(context, 'Urgent', 'Khẩn'),
      },
      _ => null,
    };
    await boardForm(
      context,
      label,
      [
        BoardField(
          'value',
          key == 'due'
              ? tr(context, 'Set all-day deadline', 'Đặt hạn cả ngày')
              : label,
          label,
          kind: options != null
              ? 'select'
              : key == 'due'
              ? 'date'
              : 'number',
          options: options,
          optional: key == 'due',
        ),
      ],
      {
        'value': key == 'due'
            ? (task.data['due'] == null
                  ? null
                  : deadlineDay(
                      object(task.data['due']),
                      s.get('boards', board).str('zone'),
                    ))
            : key == 'category'
            ? task.str(key)
            : key == 'status'
            ? task.str(key)
            : '${task.number(key)}',
      },
      (v) async {
        await scope.controller.change(
          (s) => saveTask(
            s,
            s.get('tasks', task.id).copy({
              key: switch (key) {
                'category' => v['value'] == '' ? null : v['value'],
                'priority' || 'estimate' => int.parse(v['value']),
                'due' =>
                  v['value'] == null
                      ? null
                      : {'kind': 'day', 'day': v['value']},
                _ => v['value'],
              },
            }),
            now: scope.clock(),
          ),
        );
      },
    );
  }
}
