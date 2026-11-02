import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/form.dart';
import 'editors.dart';

Map<String, String> ruleTriggers(BuildContext context) => {
  'created': tr(context, 'Task created', 'Tạo task'),
  'moved': tr(context, 'Category moved', 'Đổi nhóm'),
  'completed': tr(context, 'Completed', 'Hoàn tất'),
  'due changed': tr(context, 'Due date changed', 'Đổi hạn'),
  'opened': tr(
    context,
    'App opened · once per task/day',
    'Mở app · một lần mỗi task/ngày',
  ),
};

String ruleActionLabel(
  BuildContext context,
  BoardsState s,
  Map<String, dynamic> a,
) {
  final value = a['value'];
  return switch (a['type']) {
    'priority' =>
      '${tr(context, 'Priority', 'Ưu tiên')}: ${[tr(context, 'Low', 'Thấp'), tr(context, 'Normal', 'Thường'), tr(context, 'High', 'Cao'), tr(context, 'Urgent', 'Khẩn')][value as int]}',
    'category' =>
      '${tr(context, 'Move to', 'Chuyển tới')}: ${s.get('categories', value).str('title')}',
    'tag' =>
      '${tr(context, 'Tag', 'Nhãn')}: ${s.get('tags', value).str('title')}',
    'checklist' => '${tr(context, 'Checklist', 'Checklist')}: $value',
    'suggestStatus' =>
      '${tr(context, 'Suggest', 'Đề xuất')}: ${s.get('statuses', value).str('title')}',
    'remindMinutes' => tr(
      context,
      'Remind after $value minutes',
      'Nhắc sau $value phút',
    ),
    'generate' => tr(
      context,
      'Generate bounded recurring occurrences',
      'Tạo lượt lặp trong giới hạn',
    ),
    _ => tr(context, 'Unsupported action', 'Hành động không hỗ trợ'),
  };
}

Future<void> editAutomationRule(
  BuildContext context,
  BoardsScope scope,
  String board, {
  BoardRecord? old,
}) async {
  final s = scope.state,
      actions = (old?.data['actions'] as List? ?? []).map(object).toList();
  dynamic first(String type) =>
      actions.where((a) => a['type'] == type).firstOrNull?['value'];
  final keep = tr(context, 'Keep unchanged', 'Giữ nguyên');
  await boardForm(
    context,
    tr(context, 'Automation rule', 'Quy tắc tự động'),
    [
      const BoardField('title', 'Name', 'Tên'),
      BoardField(
        'trigger',
        'Event',
        'Sự kiện',
        kind: 'select',
        options: ruleTriggers(context),
      ),
      BoardField(
        'priority',
        'Set priority',
        'Đặt ưu tiên',
        kind: 'select',
        options: {
          '': keep,
          '0': tr(context, 'Low', 'Thấp'),
          '1': tr(context, 'Normal', 'Thường'),
          '2': tr(context, 'High', 'Cao'),
          '3': tr(context, 'Urgent', 'Khẩn'),
        },
      ),
      BoardField(
        'category',
        'Move category',
        'Chuyển nhóm',
        kind: 'select',
        options: {'': keep, ...choices(s, 'categories', board)},
      ),
      BoardField(
        'tags',
        'Add tags',
        'Thêm nhãn',
        kind: 'multi',
        optional: true,
        options: choices(s, 'tags', board),
      ),
      const BoardField(
        'checklist',
        'Append checklist items · one per line',
        'Thêm checklist · mỗi dòng một mục',
        kind: 'note',
        optional: true,
      ),
      BoardField(
        'suggest',
        'Suggest status for review',
        'Đề xuất trạng thái để duyệt',
        kind: 'select',
        options: {'': keep, ...choices(s, 'statuses', board)},
      ),
      const BoardField(
        'remind',
        'Reminder after minutes · optional',
        'Nhắc sau số phút · tùy chọn',
        kind: 'number',
        optional: true,
      ),
      BoardField(
        'generate',
        'Generate recurring instances',
        'Tạo lượt lặp',
        kind: 'select',
        options: {
          '': tr(context, 'None', 'Không'),
          for (final r
              in s.rows('recurrence').where((r) => r.str('board') == board))
            r.id: s.get('tasks', r.str('task')).str('title'),
        },
      ),
      BoardField(
        'sample',
        'Preview on a task · no data saved',
        'Xem trước trên task · chưa lưu dữ liệu',
        kind: 'select',
        options: {
          '': tr(context, 'Actions only', 'Chỉ xem hành động'),
          for (final t in topTasks(s, board: board)) t.id: t.str('title'),
        },
      ),
    ],
    {
      'title': old?.str('title') ?? '',
      'trigger': old?.str('trigger') ?? 'created',
      'priority': first('priority')?.toString() ?? '',
      'category': first('category') ?? '',
      'tags': [
        for (final a in actions.where((a) => a['type'] == 'tag')) a['value'],
      ],
      'checklist': actions
          .where((a) => a['type'] == 'checklist')
          .map((a) => a['value'])
          .join('\n'),
      'suggest': first('suggestStatus') ?? '',
      'remind': first('remindMinutes')?.toString() ?? '',
      'generate': first('generate') ?? '',
      'sample': '',
    },
    (v) async {
      final nextActions = <Map<String, dynamic>>[
        if (v['priority'] != '')
          {'type': 'priority', 'value': int.parse(v['priority'])},
        if (v['category'] != '') {'type': 'category', 'value': v['category']},
        for (final tag in v['tags'] as List) {'type': 'tag', 'value': tag},
        for (final line
            in (v['checklist'] as String)
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty))
          {'type': 'checklist', 'value': line},
        if (v['suggest'] != '')
          {'type': 'suggestStatus', 'value': v['suggest']},
        if (v['remind'] != '')
          {'type': 'remindMinutes', 'value': int.parse(v['remind'])},
        if (v['generate'] != '') {'type': 'generate', 'value': v['generate']},
      ];
      if (nextActions.isEmpty)
        throw FormatException(
          tr(context, 'Add at least one action', 'Thêm ít nhất một hành động'),
        );
      final rule = BoardRecord({
        'id': old?.id ?? newId(),
        'board': board,
        'title': v['title'],
        'trigger': v['trigger'],
        'enabled': old?.flag('enabled') ?? true,
        'actions': nextActions,
      });
      final revision = scope.state.revision;
      validateAutomation(scope.state, rule);
      final summary = [
        for (final a in nextActions) ruleActionLabel(context, scope.state, a),
      ];
      if (v['sample'] != '') {
        // Isolate this rule. Preview is a pure engine operation; no adapter or write.
        final edit = BoardsEdit(scope.state);
        for (final r in scope.state.rows('rules')) edit.remove('rules', r.id);
        for (final r in scope.state.rows('executions'))
          edit.remove('executions', r.id);
        edit.put('rules', rule.copy({'enabled': true}));
        final before = edit.finish();
        final after = runAutomations(
          before,
          v['sample'],
          v['trigger'],
          'preview:${newId()}',
          now: scope.clock(),
          preview: true,
        );
        summary.add(
          tr(
            context,
            'Preview adds ${after.rows('checklist').length - before.rows('checklist').length} checklist items, ${after.rows('reminders').length - before.rows('reminders').length} reminders and ${after.rows('occurrences').length - before.rows('occurrences').length} recurring occurrences.',
            'Xem trước thêm ${after.rows('checklist').length - before.rows('checklist').length} mục checklist, ${after.rows('reminders').length - before.rows('reminders').length} lời nhắc và ${after.rows('occurrences').length - before.rows('occurrences').length} lượt lặp.',
          ),
        );
      }
      if (!context.mounted) return;
      if (!await confirmBoards(
        context,
        tr(context, 'Save these actions?', 'Lưu các hành động này?'),
        summary.join('\n'),
      ))
        throw FormatException(
          'Preview cancelled / Đã hủy xem trước. Nothing saved / Chưa lưu thay đổi.',
        );
      await scope.controller.change((current) {
        if (current.revision != revision)
          throw const FormatException(
            'Data changed during preview. Review again.',
          );
        return current.put('rules', rule);
      });
    },
    saveLabel: tr(context, 'Preview & save', 'Xem trước và lưu'),
  );
}
