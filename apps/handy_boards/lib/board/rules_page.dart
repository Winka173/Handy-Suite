import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import 'board_menus.dart' show ProBadge, askText;

/// Board ⋮ › Automation rules (Pro). Each rule reads as a sentence; a switch
/// turns it on or off; the runs on this device are listed under them. Free
/// people can look, open the editor and see its preview; turning a rule on
/// or saving asks for Pro.
class RulesPage extends StatelessWidget {
  final BoardsScope scope;
  final String board;
  const RulesPage({super.key, required this.scope, required this.board});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final p = BoardsPalette.of(context);
      final s = scope.state;
      if (s.maybe('boards', board) == null) return const SizedBox.shrink();
      final rules = rulesOf(s, board);
      final log = ruleLog(s, board: board).take(20).toList();
      final loc = MaterialLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Automation rules', 'Luật tự động')),
          actions: [
            if (!hasPro(context))
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(child: ProBadge()),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('rule-new'),
          onPressed: rules.length >= rulesPerBoard
              ? null
              : () => editRule(context, scope, board),
          icon: const Icon(Icons.add),
          label: Text(tr(context, 'New rule', 'Luật mới')),
        ),
        body: ListView(
          key: const Key('rules-page'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            Text(
              tr(
                context,
                'Small steps done for you on this board, right when it '
                    'happens. A rule never starts another rule, and Undo takes '
                    'back your change and the rule\'s together.',
                'Những bước nhỏ được làm thay bạn trên bảng này, ngay lúc việc '
                    'xảy ra. Luật không kích hoạt luật khác, và Hoàn tác lấy lại '
                    'cả thao tác của bạn lẫn việc luật đã làm.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 12),
            if (rules.isEmpty) ...[
              Text(
                tr(context, 'Start from an example', 'Bắt đầu từ ví dụ'),
                style: theme.textTheme.titleSmall,
              ),
              for (final (i, ex) in _examples(context, s, board).indexed)
                Card(
                  key: Key('rule-example-$i'),
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    leading: const Icon(Icons.bolt_outlined),
                    title: Text(ex.str('title')),
                    subtitle: Text(ruleSentence(context, s, ex)),
                    onTap: () => editRule(context, scope, board, start: ex),
                  ),
                ),
            ],
            for (final r in rules)
              Card(
                key: Key('rule-${r.id}'),
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  title: Text(
                    r.str('title').isEmpty
                        ? tr(context, 'Rule', 'Luật')
                        : r.str('title'),
                  ),
                  subtitle: Text(ruleSentence(context, s, r)),
                  onTap: () => editRule(context, scope, board, start: r),
                  trailing: Switch(
                    key: Key('rule-on-${r.id}'),
                    value: r.flag('enabled') && hasPro(context),
                    onChanged: (r.data['actions'] as List).isEmpty
                        ? null
                        : (v) async {
                            if (v &&
                                !await requirePro(
                                  context,
                                  ProFeature.automation,
                                )) {
                              return;
                            }
                            if (!context.mounted) return;
                            await scope.run(
                              context,
                              () => scope.controller.change(
                                (s) => saveRule(
                                  s,
                                  r.copy({'enabled': v}),
                                  now: scope.clock(),
                                ),
                              ),
                            );
                          },
                  ),
                ),
              ),
            if (rules.isNotEmpty) ...[
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  tr(context, 'Recent runs', 'Lần chạy gần đây'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                tr(
                  context,
                  'On this device. Skipped steps say why.',
                  'Trên máy này. Bước bị bỏ qua có ghi lý do.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
              ),
              if (log.isEmpty)
                Padding(
                  key: const Key('rule-log-empty'),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    tr(
                      context,
                      'Nothing has run yet.',
                      'Chưa có lần chạy nào.',
                    ),
                  ),
                ),
              for (final x in log)
                Padding(
                  key: Key('rule-log-${x.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.bolt_outlined, size: 20, color: p.muted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.maybe('tasks', x.str('task'))?.str('title') ??
                                  '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${s.maybe('rules', x.str('rule'))?.str('title') ?? ''}'
                              ' · ${_steps(context, x)}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${loc.formatShortMonthDay(DateTime.parse(x.str('at')).toLocal())} '
                        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(DateTime.parse(x.str('at')).toLocal()), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

String _steps(BuildContext context, BoardRecord x) =>
    (x.data['steps'] as List? ?? const [])
        .map((raw) {
          final step = '$raw';
          final type = step.split(':').first;
          final name = _actionName(context, type);
          if (!step.contains('skipped')) return name;
          final why = step.contains('another rule')
              ? tr(context, 'another rule set it', 'luật khác đã đặt')
              : step.contains('missing')
              ? tr(context, 'template removed', 'mẫu đã bị xoá')
              : tr(context, 'already so', 'đã có sẵn');
          return '$name (${tr(context, 'skipped', 'bỏ qua')}: $why)';
        })
        .join(', ');

String _actionName(BuildContext context, String type) => switch (type) {
  'priority' => tr(context, 'priority', 'ưu tiên'),
  'category' => tr(context, 'category', 'nhóm'),
  'checklist' => tr(context, 'subtask', 'việc con'),
  'template' => tr(context, 'template subtasks', 'việc con từ mẫu'),
  'suggestStatus' => tr(context, 'moved', 'chuyển cột'),
  'remindMinutes' => tr(context, 'reminder', 'nhắc nhở'),
  'notify' => tr(context, 'notification', 'thông báo'),
  _ => type,
};

String _priority(BuildContext context, int v) => switch (v) {
  3 => tr(context, 'High', 'Cao'),
  2 => tr(context, 'Medium', 'Vừa'),
  1 => tr(context, 'Normal', 'Thường'),
  _ => tr(context, 'Low', 'Thấp'),
};

String _remind(BuildContext context, int minutes) => switch (minutes) {
  60 => tr(context, '1 hour', '1 giờ'),
  180 => tr(context, '3 hours', '3 giờ'),
  1440 => tr(context, '1 day', '1 ngày'),
  2880 => tr(context, '2 days', '2 ngày'),
  _ => tr(context, '$minutes min', '$minutes phút'),
};

/// "When a card moves to Review, if High: set priority High, add subtask…"
String ruleSentence(BuildContext context, BoardsState s, BoardRecord r) {
  String name(String kind, Object? id) =>
      s.maybe(kind, '$id')?.str('title') ?? '?';
  final when = r.data['when'] is Map ? r.data['when'] as Map : const {};
  final trigger = switch (r.str('trigger')) {
    'created' => tr(context, 'When a card is added', 'Khi thêm thẻ'),
    'moved' =>
      when['status'] != null
          ? tr(
              context,
              'When a card moves to ${name('statuses', when['status'])}',
              'Khi thẻ chuyển vào ${name('statuses', when['status'])}',
            )
          : tr(context, 'When a card moves', 'Khi thẻ chuyển cột'),
    'completed' => tr(context, 'When a card is finished', 'Khi thẻ xong'),
    'due soon' =>
      r.number('days') == 0
          ? tr(context, 'On a card\'s due day', 'Vào ngày đến hạn')
          : tr(
              context,
              r.number('days') == 1
                  ? 'The day before a deadline'
                  : '${r.number('days')} days before a deadline',
              'Trước hạn ${r.number('days')} ngày',
            ),
    _ => r.str('trigger'),
  };
  final ifs = [
    if (when['status'] != null && r.str('trigger') != 'moved')
      tr(
        context,
        'in ${name('statuses', when['status'])}',
        'ở cột ${name('statuses', when['status'])}',
      ),
    if (when['category'] != null) name('categories', when['category']),
    if (when['priority'] is int)
      tr(
        context,
        '${_priority(context, when['priority'] as int)} or higher',
        'ưu tiên ${_priority(context, when['priority'] as int)} trở lên',
      ),
  ];
  final actions = [
    for (final raw in r.data['actions'] as List)
      actionText(context, s, object(raw)),
  ];
  return '$trigger${ifs.isEmpty ? '' : ' (${ifs.join(', ')})'}: '
      '${actions.isEmpty ? tr(context, 'nothing yet', 'chưa làm gì') : actions.join('; ')}';
}

String actionText(BuildContext context, BoardsState s, Json a) {
  final v = a['value'];
  return switch (a['type']) {
    'priority' => tr(
      context,
      'set priority ${_priority(context, v as int)}',
      'đặt ưu tiên ${_priority(context, v)}',
    ),
    'category' => tr(
      context,
      'put in ${s.maybe('categories', '$v')?.str('title') ?? '?'}',
      'đưa vào nhóm ${s.maybe('categories', '$v')?.str('title') ?? '?'}',
    ),
    'checklist' => tr(context, 'add subtask "$v"', 'thêm việc con "$v"'),
    'template' => tr(
      context,
      'add the subtasks of "${s.maybe('templates', '$v')?.str('title') ?? '?'}"',
      'thêm việc con của mẫu "${s.maybe('templates', '$v')?.str('title') ?? '?'}"',
    ),
    'suggestStatus' => tr(
      context,
      'move to ${s.maybe('statuses', '$v')?.str('title') ?? '?'}',
      'chuyển sang ${s.maybe('statuses', '$v')?.str('title') ?? '?'}',
    ),
    'remindMinutes' => tr(
      context,
      'remind me ${_remind(context, v as int)} before the deadline',
      'nhắc tôi trước hạn ${_remind(context, v)}',
    ),
    'notify' => tr(context, 'notify me', 'báo cho tôi'),
    _ => tr(context, 'an older action', 'một hành động cũ'),
  };
}

List<BoardRecord> _examples(BuildContext context, BoardsState s, String board) {
  final cols = columnsOf(s, board);
  return [
    BoardRecord({
      'id': 'example-new',
      'board': board,
      'title': tr(
        context,
        'Every new card has a first step',
        'Thẻ mới có bước đầu',
      ),
      'trigger': 'created',
      'actions': [
        {
          'type': 'checklist',
          'value': tr(context, 'Decide the first step', 'Chọn bước đầu tiên'),
        },
      ],
    }),
    BoardRecord({
      'id': 'example-due',
      'board': board,
      'title': tr(context, 'Urgent the day before', 'Gấp trước hạn 1 ngày'),
      'trigger': 'due soon',
      'days': 1,
      'actions': [
        {'type': 'priority', 'value': 3},
        {'type': 'notify', 'value': true},
      ],
    }),
    if (cols.length > 2)
      BoardRecord({
        'id': 'example-moved',
        'board': board,
        'title': tr(
          context,
          'A last check in ${cols[cols.length - 2].str('title')}',
          'Kiểm tra lần cuối ở ${cols[cols.length - 2].str('title')}',
        ),
        'trigger': 'moved',
        'when': {'status': cols[cols.length - 2].id},
        'actions': [
          {
            'type': 'checklist',
            'value': tr(context, 'Check it once more', 'Xem lại một lần'),
          },
        ],
      }),
  ];
}

/// The rule editor, full screen: When › Only if › Then, with a live
/// preview. [start] is a rule to edit or an example to begin from.
Future<void> editRule(
  BuildContext context,
  BoardsScope scope,
  String board, {
  BoardRecord? start,
}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => _RuleEditor(scope: scope, board: board, start: start),
  ),
);

class _RuleEditor extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  final BoardRecord? start;
  const _RuleEditor({required this.scope, required this.board, this.start});
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final bool existing =
      widget.start != null &&
      widget.scope.state.maybe('rules', widget.start!.id) != null;
  late final title = TextEditingController(
    text: widget.start?.str('title') ?? '',
  );
  late String trigger = widget.start?.str('trigger', 'created') ?? 'created';
  late int days = widget.start?.data['days'] as int? ?? 1;
  late final Map<String, Object?> when = {
    ...?(widget.start?.data['when'] as Map?)?.cast<String, Object?>(),
  };
  late final List<Json> actions = [
    for (final a in (widget.start?.data['actions'] as List? ?? const []))
      object(a),
  ];

  BoardRecord _rule() => BoardRecord({
    'id': existing ? widget.start!.id : newId(),
    'board': widget.board,
    'title': title.text.trim().isEmpty
        ? tr(context, 'Rule', 'Luật')
        : title.text.trim(),
    'trigger': trigger,
    'enabled': existing ? widget.start!.flag('enabled') : true,
    if (trigger == 'due soon') 'days': days,
    'when': when.isEmpty ? null : {...when},
    'actions': [
      for (final a in actions)
        if (a['type'] != 'notify' || trigger == 'due soon') a,
    ],
  });

  Future<T?> _pick<T>(String heading, List<(T, String)> options) =>
      showDialog<T>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: Text(heading),
          children: [
            for (final (v, label) in options)
              SimpleDialogOption(
                key: Key('rule-pick-$v'),
                onPressed: () => Navigator.pop(dialog, v),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(label),
                ),
              ),
          ],
        ),
      );

  Future<void> _addAction() async {
    final s = widget.scope.state;
    final type = await _pick<String>(tr(context, 'Then', 'Thì'), [
      ('priority', tr(context, 'Set the priority', 'Đặt ưu tiên')),
      if (categoriesOf(s, widget.board).isNotEmpty)
        ('category', tr(context, 'Put in a category', 'Đưa vào nhóm')),
      ('checklist', tr(context, 'Add a subtask', 'Thêm việc con')),
      if (cardTemplates(s).isNotEmpty)
        (
          'template',
          tr(
            context,
            'Add a card template\'s subtasks',
            'Thêm việc con từ mẫu thẻ',
          ),
        ),
      ('suggestStatus', tr(context, 'Move to a column', 'Chuyển sang cột')),
      (
        'remindMinutes',
        tr(context, 'Remind me before the deadline', 'Nhắc tôi trước hạn'),
      ),
      if (trigger == 'due soon')
        ('notify', tr(context, 'Notify me', 'Báo cho tôi')),
    ]);
    if (type == null || !mounted) return;
    final value = await _valueFor(type);
    if (!mounted) return;
    if (value == null || (value is String && value.trim().isEmpty)) return;
    setState(() {
      actions.removeWhere(
        (a) => a['type'] == type && type != 'checklist' && type != 'template',
      );
      actions.add({'type': type, 'value': value});
    });
  }

  Future<Object?> _valueFor(String type) {
    final s = widget.scope.state;
    return switch (type) {
      'priority' => _pick<int>(tr(context, 'Priority', 'Ưu tiên'), [
        for (final v in [3, 2, 1, 0]) (v, _priority(context, v)),
      ]),
      'category' => _pick<String>(tr(context, 'Category', 'Nhóm'), [
        for (final c in categoriesOf(s, widget.board)) (c.id, c.str('title')),
      ]),
      'checklist' => askText(
        context,
        title: tr(context, 'Subtask', 'Việc con'),
        max: 200,
      ),
      'template' => _pick<String>(tr(context, 'Card template', 'Mẫu thẻ'), [
        for (final t in cardTemplates(s)) (t.id, t.str('title')),
      ]),
      'suggestStatus' => _pick<String>(tr(context, 'Column', 'Cột'), [
        for (final c in columnsOf(s, widget.board)) (c.id, c.str('title')),
      ]),
      'remindMinutes' => _pick<int>(
        tr(context, 'How long before', 'Trước bao lâu'),
        [
          for (final v in [60, 180, 1440, 2880]) (v, _remind(context, v)),
        ],
      ),
      _ => Future.value(true),
    };
  }

  Future<void> _save() async {
    if (!await requirePro(context, ProFeature.automation) || !mounted) return;
    final rule = _rule();
    await widget.scope.run(
      context,
      () => widget.scope.controller.change(
        (s) => saveRule(s, rule, now: widget.scope.clock()),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await widget.scope.run(
      context,
      () => widget.scope.controller.change(
        (s) => deleteRule(s, widget.start!.id),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final s = widget.scope.state;
    final rule = _rule();
    final matches = rulePreviewCards(s, rule, widget.scope.clock());
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall),
      ),
    );
    DropdownMenuItem<T> item<T>(T v, String label) =>
        DropdownMenuItem(value: v, child: Text(label));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          existing
              ? tr(context, 'Edit rule', 'Sửa luật')
              : tr(context, 'New rule', 'Luật mới'),
        ),
        actions: [
          if (existing)
            IconButton(
              key: const Key('rule-delete'),
              tooltip: tr(context, 'Delete rule', 'Xoá luật'),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const Key('rule-save'),
            onPressed: actions.isEmpty ? null : _save,
            child: Text(
              hasPro(context)
                  ? tr(context, 'Save rule', 'Lưu luật')
                  : tr(context, 'Save rule with Pro', 'Lưu luật với Pro'),
            ),
          ),
        ),
      ),
      body: ListView(
        key: const Key('rule-editor'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextField(
            key: const Key('rule-title'),
            controller: title,
            maxLength: 80,
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelText: tr(context, 'Name', 'Tên'),
            ),
            onChanged: (_) => setState(() {}),
          ),
          heading(tr(context, 'When', 'Khi')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (v, label) in [
                ('created', tr(context, 'A card is added', 'Thêm thẻ')),
                ('moved', tr(context, 'A card moves', 'Thẻ chuyển cột')),
                ('completed', tr(context, 'A card is finished', 'Thẻ xong')),
                ('due soon', tr(context, 'A deadline is near', 'Sắp đến hạn')),
              ])
                ChoiceChip(
                  key: Key('rule-trigger-$v'),
                  label: Text(label),
                  selected: trigger == v,
                  onSelected: (_) => setState(() => trigger = v),
                ),
            ],
          ),
          if (trigger == 'due soon')
            Row(
              children: [
                Expanded(
                  child: Text(
                    days == 0
                        ? tr(context, 'On the due day', 'Vào ngày đến hạn')
                        : tr(
                            context,
                            days == 1 ? 'The day before' : '$days days before',
                            'Trước $days ngày',
                          ),
                  ),
                ),
                IconButton(
                  key: const Key('rule-days-less'),
                  tooltip: tr(context, 'Fewer days', 'Bớt ngày'),
                  onPressed: days > 0 ? () => setState(() => days--) : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  key: const Key('rule-days-more'),
                  tooltip: tr(context, 'More days', 'Thêm ngày'),
                  onPressed: days < 14 ? () => setState(() => days++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          heading(tr(context, 'Only if', 'Chỉ khi')),
          DropdownButtonFormField<String?>(
            key: const Key('rule-when-status'),
            initialValue: when['status'] as String?,
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelText: trigger == 'moved'
                  ? tr(context, 'It moves into', 'Chuyển vào cột')
                  : tr(context, 'It is in column', 'Đang ở cột'),
            ),
            items: [
              item(null, tr(context, 'Any', 'Bất kỳ')),
              for (final c in columnsOf(s, widget.board))
                item(c.id, c.str('title')),
            ],
            onChanged: (v) => setState(
              () => v == null ? when.remove('status') : when['status'] = v,
            ),
          ),
          const SizedBox(height: 12),
          if (categoriesOf(s, widget.board).isNotEmpty)
            DropdownButtonFormField<String?>(
              key: const Key('rule-when-category'),
              initialValue: when['category'] as String?,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                labelText: tr(context, 'Category', 'Nhóm'),
              ),
              items: [
                item(null, tr(context, 'Any', 'Bất kỳ')),
                for (final c in categoriesOf(s, widget.board))
                  item(c.id, c.str('title')),
              ],
              onChanged: (v) => setState(
                () =>
                    v == null ? when.remove('category') : when['category'] = v,
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            key: const Key('rule-when-priority'),
            initialValue: when['priority'] as int?,
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelText: tr(context, 'Priority at least', 'Ưu tiên từ'),
            ),
            items: [
              item(null, tr(context, 'Any', 'Bất kỳ')),
              for (final v in [3, 2, 1]) item(v, _priority(context, v)),
            ],
            onChanged: (v) => setState(
              () => v == null ? when.remove('priority') : when['priority'] = v,
            ),
          ),
          heading(tr(context, 'Then', 'Thì')),
          for (final (i, a) in actions.indexed)
            if (a['type'] != 'notify' || trigger == 'due soon')
              ListTile(
                key: Key('rule-action-$i'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.subdirectory_arrow_right),
                title: Text(actionText(context, s, a)),
                trailing: IconButton(
                  tooltip: tr(context, 'Remove', 'Bỏ'),
                  onPressed: () => setState(() => actions.removeAt(i)),
                  icon: const Icon(Icons.close),
                ),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('rule-add-action'),
              onPressed: actions.length >= 10 ? null : _addAction,
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'Add a step', 'Thêm bước')),
            ),
          ),
          heading(tr(context, 'Preview', 'Xem trước')),
          Container(
            key: const Key('rule-preview'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.raised,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ruleSentence(context, s, rule)),
                const SizedBox(height: 8),
                Text(
                  trigger == 'due soon'
                      ? (matches.isEmpty
                            ? tr(
                                context,
                                'No card is that close to its deadline today.',
                                'Hôm nay chưa thẻ nào gần hạn như vậy.',
                              )
                            : tr(
                                context,
                                'Today it would act on ${matches.length} cards:',
                                'Hôm nay luật sẽ làm với ${matches.length} thẻ:',
                              ))
                      : tr(
                          context,
                          'It acts on the next card this happens to. '
                              '${matches.length} cards here match the conditions now.',
                          'Luật làm với thẻ tiếp theo gặp việc này. Hiện có '
                              '${matches.length} thẻ khớp điều kiện.',
                        ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
                if (trigger == 'due soon')
                  for (final c in matches.take(5))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '· ${c.str('title')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                if (trigger == 'due soon') ...[
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      'Changes happen when you open the app; "Notify me" rings '
                          'even when it is closed (quiet hours apply).',
                      'Thay đổi xảy ra khi bạn mở app; "Báo cho tôi" vẫn kêu khi '
                          'app đóng (theo giờ yên lặng).',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
