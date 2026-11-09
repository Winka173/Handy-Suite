import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import '../board/board_menus.dart' show askText, ProBadge;

/// Card ⋮ › Save as card template (Pro): asks for a name, keeps the pattern.
Future<void> saveAsCardTemplate(
  BuildContext context,
  BoardsScope scope,
  String card,
) async {
  if (!await requirePro(context, ProFeature.cardTemplates) ||
      !context.mounted) {
    return;
  }
  final name = await askText(
    context,
    title: tr(context, 'Name this card template', 'Đặt tên mẫu thẻ'),
    value: scope.state.get('tasks', card).str('title'),
    max: 200,
  );
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  await scope.run(
    context,
    () => scope.controller.change(
      (s) => cardTemplateFromCard(s, card, title: name, now: scope.clock()),
    ),
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // Shown long enough to act on, then it goes (with an action
        // Flutter would keep it until dismissed).
        persist: false,
        content: Text(
          tr(
            context,
            'Saved. Use it from "From my templates" in any column.',
            'Đã lưu. Dùng ở "Từ mẫu của tôi" trong cột bất kỳ.',
          ),
        ),
      ),
    );
  }
}

/// Column › From my templates: the person's card templates; one tap makes
/// a fresh card at the top of [column]. Browsing is free; making one asks
/// for Pro.
Future<void> addFromCardTemplate(
  BuildContext context,
  BoardsScope scope,
  String column,
) async {
  if (!await requirePro(context, ProFeature.cardTemplates) ||
      !context.mounted) {
    return;
  }
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) => _TemplateList(scope: scope, pick: true),
  );
  if (picked == null || !context.mounted) return;
  late TemplateApply result;
  await scope.run(
    context,
    () => scope.controller.change((s) {
      result = applyCardTemplate(s, picked, column, now: scope.clock());
      return result.state;
    }),
  );
  if (!context.mounted) return;
  final skipped = result.skippedFields;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      // Shown long enough to act on, then it goes (with an action
      // Flutter would keep it until dismissed).
      persist: false,
      content: Text(
        skipped.isEmpty
            ? tr(context, 'Card added from your template', 'Đã thêm thẻ từ mẫu')
            : tr(
                context,
                'Card added; this board has no field ${skipped.join(', ')}, '
                    'so it was left out',
                'Đã thêm thẻ; bảng này không có trường ${skipped.join(', ')} '
                    'nên bỏ qua',
              ),
      ),
    ),
  );
}

/// Settings › My card templates: rename, change, remove.
class CardTemplatesPage extends StatelessWidget {
  final BoardsScope scope;
  const CardTemplatesPage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, 'My card templates', 'Mẫu thẻ của tôi')),
    ),
    body: _TemplateList(scope: scope, pick: false),
  );
}

class _TemplateList extends StatelessWidget {
  final BoardsScope scope;
  final bool pick;
  const _TemplateList({required this.scope, required this.pick});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final p = BoardsPalette.of(context);
      final list = cardTemplates(scope.state);
      String line(BoardRecord t) => [
        if ((t.data['checklist'] as List?)?.isNotEmpty == true)
          tr(
            context,
            '${(t.data['checklist'] as List).length} subtasks',
            '${(t.data['checklist'] as List).length} việc con',
          ),
        if (t.data['planIn'] != null)
          tr(
            context,
            'plan +${t.data['planIn']} d',
            'làm sau ${t.data['planIn']} ngày',
          ),
        if (t.data['dueIn'] != null)
          tr(
            context,
            'due +${t.data['dueIn']} d',
            'hạn sau ${t.data['dueIn']} ngày',
          ),
        if (t.data['category'] != null) t.str('category'),
      ].join(' · ');
      return ListView(
        key: const Key('card-templates'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (pick)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(context, 'From my templates', 'Từ mẫu của tôi'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (!hasPro(context)) const ProBadge(),
                ],
              ),
            ),
          if (list.isEmpty)
            Padding(
              key: const Key('card-templates-empty'),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                tr(
                  context,
                  'No card templates yet. Open a card you repeat often, then '
                      '⋮ › Save as card template. Its subtasks, note and '
                      'category come along; its dates and progress do not.',
                  'Chưa có mẫu thẻ. Mở một thẻ hay lặp lại, chọn ⋮ › Lưu làm '
                      'mẫu thẻ. Việc con, ghi chú và nhóm được giữ; ngày và '
                      'tiến độ thì không.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
            ),
          for (final t in list)
            ListTile(
              key: Key('card-template-${t.id}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.content_copy_outlined),
              title: Text(t.str('title')),
              subtitle: line(t).isEmpty ? null : Text(line(t)),
              onTap: pick
                  ? () => Navigator.pop(context, t.id)
                  : () => _edit(context, t),
              trailing: pick
                  ? null
                  : IconButton(
                      key: Key('card-template-delete-${t.id}'),
                      tooltip: tr(context, 'Remove template', 'Xoá mẫu'),
                      onPressed: () => scope.run(
                        context,
                        () => scope.controller.change(
                          (s) => deleteCardTemplate(s, t.id),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
            ),
        ],
      );
    },
  );

  Future<void> _edit(BuildContext context, BoardRecord t) async {
    final title = TextEditingController(text: t.str('title'));
    final notes = TextEditingController(text: t.str('notes'));
    final steps = TextEditingController(
      text: ((t.data['checklist'] as List?) ?? const []).join('\n'),
    );
    int? planIn = t.data['planIn'] as int?, dueIn = t.data['dueIn'] as int?;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, set) {
          Widget days(String label, int? v, ValueChanged<int?> on, Key key) =>
              Row(
                children: [
                  Expanded(child: Text(label)),
                  DropdownButton<int?>(
                    key: key,
                    value: v,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(tr(sheet, 'None', 'Không')),
                      ),
                      for (final n in const [0, 1, 2, 3, 7, 14, 30])
                        DropdownMenuItem(
                          value: n,
                          child: Text(
                            n == 0
                                ? tr(sheet, 'Same day', 'Cùng ngày')
                                : tr(sheet, '+$n days', 'sau $n ngày'),
                          ),
                        ),
                    ],
                    onChanged: (n) => set(() => on(n)),
                  ),
                ],
              );
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(sheet).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('tpl-title'),
                    controller: title,
                    decoration: InputDecoration(
                      labelText: tr(sheet, 'Card title', 'Tên thẻ'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: tr(sheet, 'Note', 'Ghi chú'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('tpl-steps'),
                    controller: steps,
                    minLines: 2,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: tr(
                        sheet,
                        'Subtasks, one per line',
                        'Việc con, mỗi dòng một việc',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  days(
                    tr(sheet, 'Work on it', 'Ngày làm'),
                    planIn,
                    (v) => planIn = v,
                    const Key('tpl-plan'),
                  ),
                  days(
                    tr(sheet, 'Due', 'Hạn nộp'),
                    dueIn,
                    (v) => dueIn = v,
                    const Key('tpl-due'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('tpl-save'),
                    onPressed: () => Navigator.pop(sheet, true),
                    child: Text(tr(sheet, 'Save', 'Lưu')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (saved != true || !context.mounted || title.text.trim().isEmpty) return;
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => saveCardTemplate(
          s,
          id: t.id,
          title: title.text,
          notes: notes.text,
          checklist: steps.text.split('\n'),
          planIn: planIn,
          dueIn: dueIn,
          priority: t.data['priority'] as int?,
          category: t.data['category'] as String?,
          cover: t.data['cover'] as String?,
          custom: [
            for (final c in (t.data['custom'] as List? ?? const []))
              Map<String, dynamic>.from(c as Map),
          ],
          now: scope.clock(),
        ),
      ),
    );
  }
}
