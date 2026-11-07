import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/look.dart';

/// Add, rename, recolour, reorder and remove a board's categories, in one
/// light sheet. Removing a category never removes a card: its cards go to
/// Uncategorised or to the category the person picks.
Future<void> editCategories(
  BuildContext context,
  BoardsScope scope,
  String board,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) => _CategoriesSheet(scope: scope, board: board),
  ),
);

class _CategoriesSheet extends StatelessWidget {
  final BoardsScope scope;
  final String board;
  const _CategoriesSheet({required this.scope, required this.board});

  @override
  Widget build(BuildContext context) {
    final s = scope.controller.state;
    if (s == null || s.maybe('boards', board) == null)
      return const SizedBox.shrink();
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final list = categoriesOf(s, board);
    final counts = {
      for (final b in categoryProgress(s, board)) b.category?.id: b.total,
    };
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      maxChildSize: .95,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Categories', 'Nhóm'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const Key('category-add'),
                  onPressed: () => _add(context, s),
                  icon: const Icon(Icons.add),
                  label: Text(tr(context, 'Add', 'Thêm')),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              tr(
                context,
                'A category stays with its cards in every column. Drag to reorder.',
                'Nhóm đi theo thẻ qua mọi cột. Kéo để sắp xếp.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        tr(
                          context,
                          'No categories yet. Subjects, clients, rooms: anything you sort work by.',
                          'Chưa có nhóm. Môn học, khách hàng, phòng: bất cứ thứ gì bạn dùng để chia việc.',
                        ),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  )
                : ReorderableListView.builder(
                    scrollController: controller,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: list.length,
                    onReorderItem: (from, to) {
                      final ids = list.map((c) => c.id).toList();
                      final id = ids.removeAt(from);
                      ids.insert(to, id);
                      scope.run(
                        context,
                        () => scope.controller.change(
                          (s) => reorder(s, 'categories', ids),
                        ),
                      );
                    },
                    itemBuilder: (context, i) {
                      final c = list[i];
                      final hue = categoryHue(context, c);
                      final n = counts[c.id] ?? 0;
                      return Material(
                        key: ValueKey(c.id),
                        color: Colors.transparent,
                        child: ListTile(
                          key: Key('category-row-${c.id}'),
                          leading: IconButton(
                            tooltip: tr(context, 'Colour', 'Màu'),
                            onPressed: () => _recolour(context, c),
                            icon: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: hue.mark,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          title: Text(
                            c.str('title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            tr(
                              context,
                              n == 1 ? '1 card' : '$n cards',
                              '$n thẻ',
                            ),
                          ),
                          onTap: () => _rename(context, c),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: tr(
                                  context,
                                  'Remove category',
                                  'Xoá nhóm',
                                ),
                                onPressed: () => _remove(context, s, c, n),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: p.muted,
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.drag_indicator,
                                    color: p.muted,
                                    semanticLabel: tr(
                                      context,
                                      'Drag to reorder',
                                      'Kéo để sắp xếp',
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
      ),
    );
  }

  Future<String?> _ask(
    BuildContext context,
    String title, [
    String value = '',
  ]) {
    final text = TextEditingController(text: value);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('category-name'),
          controller: text,
          autofocus: true,
          maxLength: 120,
          decoration: InputDecoration(
            hintText: tr(context, 'e.g. Maths', 'VD: Toán'),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'Huỷ')),
          ),
          FilledButton(
            key: const Key('category-name-save'),
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: Text(tr(context, 'Save', 'Lưu')),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, BoardsState s) async {
    final name = await _ask(context, tr(context, 'New category', 'Nhóm mới'));
    if (name == null || name.isEmpty || !context.mounted) return;
    final existing = categoriesOf(s, board);
    // The next colour not yet used on this board.
    final used = existing.map((c) => c.number('color')).toSet();
    final color = List.generate(
      8,
      (i) => i,
    ).firstWhere((i) => !used.contains(i), orElse: () => existing.length % 8);
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => s.put(
          'categories',
          BoardRecord({
            'id': newId(),
            'board': board,
            'title': name,
            'order': existing.isEmpty ? 0 : existing.last.number('order') + 1,
            'color': color,
            'icon': 'folder',
            'preview': 3,
          }),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, BoardRecord c) async {
    final name = await _ask(
      context,
      tr(context, 'Rename category', 'Đổi tên nhóm'),
      c.str('title'),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => s.put('categories', c.copy({'title': name})),
      ),
    );
  }

  Future<void> _recolour(BuildContext context, BoardRecord c) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Colour', 'Màu')),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < HandyPalette.count; i++)
              Semantics(
                button: true,
                selected: c.number('color') == i,
                label: tr(context, 'Colour ${i + 1}', 'Màu ${i + 1}'),
                child: InkResponse(
                  onTap: () => Navigator.pop(context, i),
                  radius: 28,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: HandyPalette.of(context, i).mark,
                      shape: BoxShape.circle,
                      border: c.number('color') == i
                          ? Border.all(
                              color: BoardsPalette.of(context).ink,
                              width: 3,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => s.put('categories', c.copy({'color': picked})),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    BoardsState s,
    BoardRecord c,
    int cards,
  ) async {
    final others = categoriesOf(s, board).where((o) => o.id != c.id).toList();
    // '' = Uncategorised.
    String target = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(
            tr(
              context,
              'Remove ${c.str('title')}?',
              'Xoá nhóm ${c.str('title')}?',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cards == 0
                    ? tr(context, 'It has no cards.', 'Nhóm này chưa có thẻ.')
                    : tr(
                        context,
                        'Its $cards cards stay on the board. Move them to:',
                        '$cards thẻ của nhóm vẫn ở trên bảng. Chuyển chúng sang:',
                      ),
              ),
              if (cards > 0)
                RadioGroup<String>(
                  groupValue: target,
                  onChanged: (v) => set(() => target = v ?? ''),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: '',
                        title: Text(
                          tr(context, 'Uncategorised', 'Chưa phân nhóm'),
                        ),
                      ),
                      for (final o in others)
                        RadioListTile<String>(
                          value: o.id,
                          title: Text(o.str('title')),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Cancel', 'Huỷ')),
            ),
            FilledButton(
              key: const Key('category-remove-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'Remove category', 'Xoá nhóm')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => deleteCategory(s, c.id, moveTo: target.isEmpty ? null : target),
      ),
    );
  }
}
