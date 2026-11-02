import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/labels.dart';
import 'editors.dart';

Future<void> editSavedView(
  BuildContext context,
  BoardsScope scope,
  String board, {
  BoardRecord? old,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _SavedViewEditor(scope, board, old),
);

class _SavedViewEditor extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  final BoardRecord? old;
  const _SavedViewEditor(this.scope, this.board, this.old);
  @override
  State<_SavedViewEditor> createState() => _SavedViewState();
}

class _SavedViewState extends State<_SavedViewEditor> {
  late final title = TextEditingController(
    text: widget.old?.str('title') ?? '',
  );
  late final search = TextEditingController(
    text: widget.old?.str('search') ?? '',
  );
  late String mode = widget.old?.str('mode', 'and') ?? 'and',
      sort = widget.old?.str('sort', 'manual') ?? 'manual',
      group = widget.old?.str('group', 'flat') ?? 'flat';
  late final conditions = (widget.old?.data['conditions'] as List? ?? [])
      .map((v) => Map<String, dynamic>.of(object(v)))
      .toList();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    search.dispose();
    super.dispose();
  }

  Map<String, String> get labels => {
    'category': tr(context, 'Category', 'Nhóm'),
    'status': tr(context, 'Status', 'Trạng thái'),
    'priority': tr(context, 'Priority', 'Ưu tiên'),
    'tag': tr(context, 'Tag', 'Nhãn'),
    'assignee': tr(context, 'Assignee label', 'Nhãn phụ trách'),
    'due': tr(context, 'Due range', 'Khoảng hạn'),
    'estimate': tr(context, 'Estimate range', 'Khoảng ước lượng'),
    'hasReminder': tr(context, 'Enabled reminder', 'Lời nhắc bật'),
    'blocked': tr(context, 'Blocked', 'Bị chặn'),
    'archived': tr(context, 'Archived', 'Đã lưu trữ'),
  };
  String description(Json condition) {
    final s = widget.scope.state;
    return condition.entries
        .map((e) {
          final label =
              labels[e.key] ??
              switch (e.key) {
                'dueFrom' => tr(context, 'Due from', 'Hạn từ'),
                'dueTo' => tr(context, 'Due through', 'Hạn đến'),
                'estimateMin' => tr(
                  context,
                  'Minimum minutes',
                  'Phút tối thiểu',
                ),
                'estimateMax' => tr(context, 'Maximum minutes', 'Phút tối đa'),
                _ => e.key,
              };
          final value = switch (e.key) {
            'category' =>
              s.maybe('categories', e.value)?.str('title') ??
                  tr(context, 'Uncategorized', 'Chưa phân nhóm'),
            'status' => s.get('statuses', e.value).str('title'),
            'tag' => s.get('tags', e.value).str('title'),
            _ =>
              e.value is bool
                  ? tr(
                      context,
                      e.value ? 'Yes' : 'No',
                      e.value ? 'Có' : 'Không',
                    )
                  : e.value.toString(),
          };
          return '$label: $value';
        })
        .join(' AND ');
  }

  Future<void> condition({int? index}) async {
    final old = index == null ? <String, dynamic>{} : conditions[index];
    final initial = old.containsKey('dueFrom') || old.containsKey('dueTo')
        ? 'due'
        : old.containsKey('estimateMin') || old.containsKey('estimateMax')
        ? 'estimate'
        : old.keys.firstOrNull ?? 'category';
    String? type;
    await boardForm(
      context,
      tr(context, 'Condition type', 'Loại điều kiện'),
      [
        BoardField(
          'type',
          'Property',
          'Thuộc tính',
          kind: 'select',
          options: labels,
        ),
      ],
      {'type': initial},
      (v) async {
        type = v['type'];
      },
    );
    if (type == null || !mounted) return;
    final property = type!, s = widget.scope.state;
    final options = switch (property) {
      'category' => {
        '': tr(context, 'Uncategorized', 'Chưa phân nhóm'),
        ...choices(s, 'categories', widget.board),
      },
      'status' => choices(s, 'statuses', widget.board),
      'tag' => choices(s, 'tags', widget.board),
      'priority' => {
        '0': tr(context, 'Low', 'Thấp'),
        '1': tr(context, 'Normal', 'Thường'),
        '2': tr(context, 'High', 'Cao'),
        '3': tr(context, 'Urgent', 'Khẩn'),
      },
      'hasReminder' || 'blocked' || 'archived' => {
        'true': tr(context, 'Yes', 'Có'),
        'false': tr(context, 'No', 'Không'),
      },
      _ => null,
    };
    if (options != null && options.isEmpty) {
      setState(
        () => error = tr(context, 'Create a tag first', 'Hãy tạo nhãn trước'),
      );
      return;
    }
    final range = property == 'due' || property == 'estimate';
    await boardForm(
      context,
      labels[property]!,
      [
        if (range) ...[
          BoardField(
            'from',
            'From (optional)',
            'Từ (tùy chọn)',
            kind: property == 'due' ? 'date' : 'number',
            optional: true,
          ),
          BoardField(
            'to',
            'Through (optional)',
            'Đến (tùy chọn)',
            kind: property == 'due' ? 'date' : 'number',
            optional: true,
          ),
        ] else
          BoardField(
            'value',
            'Value',
            'Giá trị',
            kind: options != null ? 'select' : 'text',
            options: options,
          ),
      ],
      range
          ? {
              'from':
                  old[property == 'due' ? 'dueFrom' : 'estimateMin']
                      ?.toString() ??
                  (property == 'due' ? null : ''),
              'to':
                  old[property == 'due' ? 'dueTo' : 'estimateMax']
                      ?.toString() ??
                  (property == 'due' ? null : ''),
            }
          : {
              'value': old.containsKey(property)
                  ? old[property]?.toString() ?? ''
                  : options?.keys.first ?? '',
            },
      (v) async {
        final Json next;
        if (range) {
          final from = v['from'], to = v['to'];
          next = {
            if (from != null && from != '')
              property == 'due' ? 'dueFrom' : 'estimateMin': property == 'due'
                  ? from
                  : int.parse(from),
            if (to != null && to != '')
              property == 'due' ? 'dueTo' : 'estimateMax': property == 'due'
                  ? to
                  : int.parse(to),
          };
          if (next.isEmpty)
            throw const FormatException('Set at least one bound');
        } else {
          next = {
            property: property == 'priority'
                ? int.parse(v['value'])
                : ['hasReminder', 'blocked', 'archived'].contains(property)
                ? v['value'] == 'true'
                : property == 'category' && v['value'] == ''
                ? null
                : v['value'],
          };
        }
        validateTaskFilter(next);
        if (!mounted) return;
        setState(() {
          if (index == null) {
            conditions.add(next);
          } else {
            conditions[index] = next;
          }
          error = null;
        });
      },
    );
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final record = BoardRecord({
        'id': widget.old?.id ?? newId(),
        'board': widget.board,
        'title': title.text.trim(),
        'search': search.text,
        'mode': mode,
        'sort': sort,
        'group': group,
        'conditions': conditions,
      });
      await widget.scope.controller.change((s) => s.put('views', record));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          error = boardsError(context, e);
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(tr(context, 'Saved view', 'View đã lưu')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText: tr(context, 'Name', 'Tên'),
                ),
                enabled: !busy,
              ),
              TextField(
                controller: search,
                decoration: InputDecoration(
                  labelText: tr(context, 'Search text', 'Từ tìm kiếm'),
                ),
                enabled: !busy,
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: mode,
                decoration: InputDecoration(
                  labelText: tr(
                    context,
                    'Combine conditions',
                    'Kết hợp điều kiện',
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'and', child: Text('AND')),
                  DropdownMenuItem(value: 'or', child: Text('OR')),
                ],
                onChanged: busy ? null : (v) => setState(() => mode = v!),
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: sort,
                decoration: InputDecoration(
                  labelText: tr(context, 'Sort', 'Sắp xếp'),
                ),
                items: [
                  for (final (id, en, vi) in [
                    ('manual', 'Manual', 'Thủ công'),
                    ('due', 'Deadline', 'Hạn'),
                    ('priority', 'Priority', 'Ưu tiên'),
                    ('title', 'Title', 'Tên'),
                    ('created', 'Created', 'Ngày tạo'),
                    ('updated', 'Updated', 'Cập nhật'),
                  ])
                    DropdownMenuItem(
                      value: id,
                      child: Text(tr(context, en, vi)),
                    ),
                ],
                onChanged: busy ? null : (v) => setState(() => sort = v!),
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: group,
                decoration: InputDecoration(
                  labelText: tr(context, 'Group rows', 'Nhóm các dòng'),
                ),
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
                onChanged: busy ? null : (v) => setState(() => group = v!),
              ),
              for (var i = 0; i < conditions.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(description(conditions[i])),
                  onTap: busy ? null : () => condition(index: i),
                  trailing: IconButton(
                    tooltip: tr(context, 'Remove condition', 'Xóa điều kiện'),
                    onPressed: busy
                        ? null
                        : () => setState(() => conditions.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              TextButton.icon(
                onPressed: busy || conditions.length >= 30
                    ? null
                    : () => condition(),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'Add condition', 'Thêm điều kiện')),
              ),
              Text(
                tr(
                  context,
                  'Search always applies. Conditions are combined as selected. No tasks are copied.',
                  'Tìm kiếm luôn áp dụng. Điều kiện kết hợp theo lựa chọn. Không sao chép task.',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
      ],
    ),
  );
}
