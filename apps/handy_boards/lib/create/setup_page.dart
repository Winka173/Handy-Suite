import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_menus.dart' show ProBadge;
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import 'new_board.dart';
import 'template_parts.dart';

String timeLine(BuildContext context, TimePreset t) {
  final span = switch (t.unit) {
    'day' => tr(context, 'today', 'hôm nay'),
    'month' => tr(context, 'a month', 'theo tháng'),
    _ => tr(context, 'a week', 'theo tuần'),
  };
  return t.pinned
      ? tr(
          context,
          'Time view: $span, pinned',
          'Thời gian: $span, ghim cạnh tên',
        )
      : tr(
          context,
          'Time view: $span, in the menu',
          'Thời gian: $span, ở menu',
        );
}

BoardsState _sample(
  BoardTemplate t,
  TemplateAnswers a,
  bool vi,
  DateTime now,
) => buildBoard(
  BoardsState(),
  planBoard(t, a, vi: vi, now: now),
  now: now,
  boardId: previewBoard,
);

/// A template's board as it comes, with its example cards, before anything
/// is asked. Pro ones too: nothing here is saved.
class TemplatePreviewPage extends StatelessWidget {
  final BoardsScope scope;
  final BoardTemplate template;
  const TemplatePreviewPage({
    super.key,
    required this.scope,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final t = template, vi = isVi(context), now = scope.clock();
    final s = _sample(
      t,
      {...defaultAnswers(t, vi: vi, now: now), examplesKey: true},
      vi,
      now,
    );
    // A Pro template is previewed free, but Pro is asked for here, before
    // a single question, never after the person has filled everything in.
    final locked = t.pro && !hasPro(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.name.of(vi))),
      body: PreviewBody(
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.goal.of(vi),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (t.pro) const ProBadge(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${columnsLine(t, vi)}\n${timeLine(context, t.time)}',
                style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
              ),
            ],
          ),
        ),
        board: BoardPreview(state: s, now: now),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                locked
                    ? tr(
                        context,
                        'A Pro template · free to look at, Pro to use. '
                            'Unlock first, then answer its questions.',
                        'Mẫu Pro · xem miễn phí, cần Pro để dùng. Mở khoá '
                            'trước, rồi mới trả lời câu hỏi.',
                      )
                    : tr(
                        context,
                        'Preview with example cards · nothing is saved',
                        'Xem trước kèm thẻ ví dụ · chưa lưu gì',
                      ),
                key: const Key('template-note'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('template-use'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () async {
                  if (locked &&
                      !await requirePro(context, ProFeature.templates)) {
                    return;
                  }
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SetupPage(scope: scope, template: t),
                    ),
                  );
                },
                // The lock says what the tap does before it is tapped.
                icon: Icon(
                  locked ? Icons.lock_open_outlined : Icons.arrow_forward,
                ),
                label: Text(
                  locked
                      ? tr(context, 'Unlock with Pro', 'Mở khoá với Pro')
                      : tr(context, 'Use this template', 'Dùng mẫu này'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Smart Setup: the template's few questions, each saying what it changes,
/// with its suggestion filled in; then a preview of exactly that board.
/// The answers live here, so Back from the preview finds them as they were.
class SetupPage extends StatefulWidget {
  final BoardsScope scope;
  final BoardTemplate template;
  const SetupPage({super.key, required this.scope, required this.template});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  TemplateAnswers? answers;
  Map<String, L10n> errors = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    answers ??= defaultAnswers(
      widget.template,
      vi: isVi(context),
      now: widget.scope.clock(),
    );
  }

  void _set(String id, Object? v) => setState(() {
    answers![id] = v;
    if (errors.containsKey(id)) errors = {...errors}..remove(id);
  });

  void _preview() {
    final t = widget.template;
    final found = validateAnswers(t, answers!);
    setState(() => errors = found);
    if (found.isNotEmpty) return;
    final vi = isVi(context), now = widget.scope.clock();
    final plan = planBoard(t, answers!, vi: vi, now: now);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            PlanPreviewPage(scope: widget.scope, template: t, plan: plan),
      ),
    );
  }

  List<String?> _range(Object? v) => v is List
      ? [
          v.isNotEmpty ? v[0] as String? : null,
          v.length > 1 ? v[1] as String? : null,
        ]
      : [null, null];

  Widget _field(SetupField f) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final vi = isVi(context);
    final error = errors[f.id]?.of(vi);
    final value = answers![f.id];
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          f.label.of(vi) +
              // Selects and switches always hold a value.
              (f.required ||
                      f.kind == FieldKind.select ||
                      f.kind == FieldKind.toggle
                  ? ''
                  : tr(context, ' (optional)', ' (không bắt buộc)')),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          f.help.of(vi),
          style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
        ),
        const SizedBox(height: 8),
      ],
    );
    final Widget body = switch (f.kind) {
      FieldKind.text => TextFormField(
        key: Key('setup-${f.id}'),
        initialValue: value as String? ?? '',
        maxLength: 80,
        decoration: InputDecoration(
          counterText: '',
          hintText: f.placeholder?.of(vi),
          errorText: error,
        ),
        onChanged: (v) => _set(f.id, v),
      ),
      FieldKind.chips => _ChipsEditor(
        key: Key('setup-${f.id}'),
        values: [for (final c in value as List? ?? const []) '$c'],
        hues: widget.template.hues,
        max: f.maxChips,
        addLabel: f.placeholder?.of(vi) ?? tr(context, 'Add', 'Thêm'),
        error: error,
        onChanged: (v) => _set(f.id, v),
      ),
      FieldKind.date => _DateButton(
        key: Key('setup-${f.id}'),
        value: value as String?,
        onChanged: (v) => _set(f.id, v),
      ),
      FieldKind.dateRange => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateButton(
            key: Key('setup-${f.id}-start'),
            value: _range(value)[0],
            onChanged: (v) => _set(f.id, [v, _range(value)[1]]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text((f.endLabel ?? f.label).of(vi)),
          ),
          _DateButton(
            key: Key('setup-${f.id}-end'),
            value: _range(value)[1],
            onChanged: (v) => _set(f.id, [_range(value)[0], v]),
          ),
          if (error != null)
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(color: p.danger),
            ),
        ],
      ),
      FieldKind.select => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final o in f.options)
            ChoiceChip(
              key: Key('setup-${f.id}-${o.id}'),
              label: Text(o.label.of(vi)),
              selected: value == o.id,
              onSelected: (_) => _set(f.id, o.id),
            ),
        ],
      ),
      FieldKind.toggle => SwitchListTile(
        key: Key('setup-${f.id}'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          value == true ? tr(context, 'On', 'Bật') : tr(context, 'Off', 'Tắt'),
        ),
        value: value == true,
        onChanged: (v) => _set(f.id, v),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [head, body],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template, vi = isVi(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.name.of(vi))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              for (final f in t.fields) _field(f),
              SwitchListTile(
                key: const Key('setup-examples'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tr(context, 'Add a few example cards', 'Thêm vài thẻ ví dụ'),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Off: the board starts empty. On: a few cards show how it '
                        'is used; delete them any time.',
                    'Tắt: bảng bắt đầu trống. Bật: vài thẻ cho thấy cách dùng; '
                        'xoá lúc nào cũng được.',
                  ),
                ),
                value: answers![examplesKey] == true,
                onChanged: (v) => _set(examplesKey, v),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const Key('setup-preview'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _preview,
            child: Text(
              tr(context, 'Preview my board', 'Xem trước bảng của tôi'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Exactly the board the answers make. Create it, or go back with the
/// answers kept. Pro was asked for before the questions; Create checks it
/// once more only as a safety net.
class PlanPreviewPage extends StatelessWidget {
  final BoardsScope scope;
  final BoardTemplate template;
  final BoardPlan plan;
  const PlanPreviewPage({
    super.key,
    required this.scope,
    required this.template,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final now = scope.clock();
    final s = buildBoard(BoardsState(), plan, now: now, boardId: previewBoard);
    final locked = template.pro && !hasPro(context);
    return Scaffold(
      appBar: AppBar(title: Text(plan.title)),
      body: PreviewBody(
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            '${plan.columns.map((c) => c.$1).join(' → ')}\n'
            '${timeLine(context, plan.time)}',
            style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
          ),
        ),
        board: BoardPreview(state: s, now: now),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('plan-edit'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, 'Change answers', 'Sửa câu trả lời')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('plan-create'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () =>
                      createPlan(context, scope, plan, pro: template.pro),
                  child: Text(
                    locked
                        ? tr(context, 'Create with Pro', 'Tạo với Pro')
                        : tr(context, 'Create board', 'Tạo bảng'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Repeatable names as rows: edit in place, drag to reorder, remove, add.
class _ChipsEditor extends StatefulWidget {
  final List<String> values;
  final List<int> hues;
  final int max;
  final String addLabel;
  final String? error;
  final ValueChanged<List<String>> onChanged;
  const _ChipsEditor({
    super.key,
    required this.values,
    required this.hues,
    required this.max,
    required this.addLabel,
    required this.error,
    required this.onChanged,
  });
  @override
  State<_ChipsEditor> createState() => _ChipsEditorState();
}

class _ChipsEditorState extends State<_ChipsEditor> {
  late final rows = [
    for (final v in widget.values)
      (key: UniqueKey(), text: TextEditingController(text: v)),
  ];

  @override
  void dispose() {
    for (final r in rows) r.text.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged([for (final r in rows) r.text.text]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) {
            setState(() => rows.insert(to, rows.removeAt(from)));
            _emit();
          },
          children: [
            for (final (i, r) in rows.indexed)
              Padding(
                key: r.key,
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    HandyDot(widget.hues[i % widget.hues.length], size: 12),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        key: Key('chip-$i'),
                        controller: r.text,
                        maxLength: 40,
                        decoration: const InputDecoration(
                          counterText: '',
                          isDense: true,
                        ),
                        onChanged: (_) => _emit(),
                      ),
                    ),
                    IconButton(
                      key: Key('chip-remove-$i'),
                      tooltip: tr(context, 'Remove', 'Xoá'),
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => rows.removeAt(i).text.dispose());
                        _emit();
                      },
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: Tooltip(
                        message: tr(
                          context,
                          'Drag to reorder',
                          'Kéo để sắp xếp',
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.drag_indicator),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.error!,
              style: theme.textTheme.bodySmall?.copyWith(color: p.danger),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('chip-add'),
            onPressed: rows.length >= widget.max
                ? null
                : () {
                    setState(
                      () => rows.add((
                        key: UniqueKey(),
                        text: TextEditingController(),
                      )),
                    );
                    _emit();
                  },
            icon: const Icon(Icons.add),
            label: Text(widget.addLabel),
          ),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _DateButton({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final day = value == null ? null : localDate(value!);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              day == null
                  ? tr(context, 'Pick a date', 'Chọn ngày')
                  : MaterialLocalizations.of(context).formatMediumDate(day),
            ),
            onPressed: () async {
              final picked = await pickHandyDate(context, value ?? '');
              if (picked != null) onChanged(picked);
            },
          ),
        ),
        if (value != null)
          IconButton(
            tooltip: tr(context, 'No date', 'Bỏ ngày'),
            icon: const Icon(Icons.close),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}
