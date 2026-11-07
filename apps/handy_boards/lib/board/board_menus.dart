import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import '../ui/look.dart';
import 'board_page.dart';
import 'categories_sheet.dart';

Future<T?> _sheet<T>(
  BuildContext context,
  String title,
  List<Widget> Function(BuildContext) rows,
) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...rows(context),
        ],
      ),
    ),
  ),
);

Widget _row(
  BuildContext context,
  IconData icon,
  String label,
  VoidCallback onTap, {
  Key? key,
  bool danger = false,
  Widget? trailing,
}) {
  final p = BoardsPalette.of(context);
  return ListTile(
    key: key,
    leading: Icon(icon, color: danger ? p.danger : p.muted),
    title: Text(label, style: danger ? TextStyle(color: p.danger) : null),
    trailing: trailing,
    onTap: onTap,
  );
}

Future<String?> askText(
  BuildContext context, {
  required String title,
  String value = '',
  String? hint,
  String? action,
  int max = 200,
}) {
  final text = TextEditingController(text: value);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('ask-text'),
        controller: text,
        autofocus: true,
        maxLength: max,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Huỷ')),
        ),
        FilledButton(
          key: const Key('ask-text-save'),
          onPressed: () => Navigator.pop(context, text.text.trim()),
          child: Text(action ?? tr(context, 'Save', 'Lưu')),
        ),
      ],
    ),
  );
}

/// Everything about the board that is not a card.
Future<void> boardMenu(
  BuildContext context,
  BoardsScope scope,
  String board, {
  VoidCallback? onLook,
}) {
  final b = scope.state.get('boards', board);
  final detailed = b.str('presentation') == 'detailed';
  return _sheet<void>(context, b.str('title'), (sheet) {
    void then(Future<void> Function() action) {
      Navigator.pop(sheet);
      action();
    }

    return [
      _row(
        sheet,
        Icons.edit_outlined,
        tr(sheet, 'Rename board', 'Đổi tên bảng'),
        () => then(() async {
          final name = await askText(
            context,
            title: tr(context, 'Rename board', 'Đổi tên bảng'),
            value: b.str('title'),
          );
          if (name == null || name.isEmpty || !context.mounted) return;
          await scope.run(
            context,
            () => scope.controller.change(
              (s) =>
                  s.put('boards', s.get('boards', board).copy({'title': name})),
            ),
          );
        }),
        key: const Key('menu-rename-board'),
      ),
      _row(
        sheet,
        Icons.image_outlined,
        tr(sheet, 'Change cover', 'Đổi ảnh bìa'),
        () => then(() => pickBoardCover(context, scope, board)),
        key: const Key('menu-board-cover'),
      ),
      _row(
        sheet,
        detailed ? Icons.view_agenda_outlined : Icons.view_stream_outlined,
        detailed
            ? tr(sheet, 'Show compact cards', 'Hiện thẻ gọn')
            : tr(sheet, 'Show subtasks on cards', 'Hiện việc con trên thẻ'),
        () => then(
          () => scope.run(
            context,
            () => scope.controller.change(
              (s) => setBoardLook(
                s,
                board,
                presentation: detailed ? 'compact' : 'detailed',
              ),
            ),
          ),
        ),
        key: const Key('menu-presentation'),
      ),
      _row(
        sheet,
        Icons.space_dashboard_outlined,
        tr(sheet, 'Edit categories', 'Sửa nhóm'),
        () => then(() => editCategories(context, scope, board)),
      ),
      _row(
        sheet,
        Icons.view_column_outlined,
        tr(sheet, 'Add column', 'Thêm cột'),
        () => then(() => addColumnDialog(context, scope, board)),
      ),
      _row(
        sheet,
        b.flag('pinned') ? Icons.push_pin : Icons.push_pin_outlined,
        b.flag('pinned')
            ? tr(sheet, 'Unpin from the top', 'Bỏ ghim')
            : tr(sheet, 'Pin to the top', 'Ghim lên đầu'),
        () => then(
          () => scope.run(
            context,
            () => scope.controller.change(
              (s) => setBoardLook(s, board, pinned: !b.flag('pinned')),
            ),
          ),
        ),
      ),
      _row(
        sheet,
        Icons.copy_all_outlined,
        tr(sheet, 'Duplicate board', 'Nhân bản bảng'),
        () => then(() async {
          final name = await askText(
            context,
            title: tr(context, 'Duplicate board', 'Nhân bản bảng'),
            value: tr(
              context,
              '${b.str('title')} (copy)',
              '${b.str('title')} (bản sao)',
            ),
            action: tr(context, 'Duplicate', 'Nhân bản'),
          );
          if (name == null || name.isEmpty || !context.mounted) return;
          await scope.run(
            context,
            () => scope.controller.change(
              (s) => duplicateBoard(s, board, title: name, now: scope.clock()),
            ),
          );
          if (context.mounted)
            showUndo(
              context,
              scope,
              tr(context, 'Board duplicated', 'Đã nhân bản bảng'),
            );
        }),
      ),
      if (onLook != null)
        _row(
          sheet,
          Icons.palette_outlined,
          tr(sheet, 'Board look', 'Giao diện bảng'),
          () => then(() async => onLook()),
          key: const Key('menu-board-look'),
        ),
      _row(
        sheet,
        Icons.insights_outlined,
        tr(sheet, 'Board insights', 'Thống kê bảng'),
        () => then(() async {
          if (await requirePro(context, ProFeature.insights) && context.mounted)
            await Navigator.pushNamed(context, '/insights', arguments: board);
        }),
        trailing: const ProBadge(),
      ),
      _row(
        sheet,
        Icons.ios_share,
        tr(sheet, 'Export board', 'Xuất bảng'),
        () => then(() async {
          await Navigator.pushNamed(context, '/export', arguments: board);
        }),
        key: const Key('menu-export'),
      ),
      _row(
        sheet,
        Icons.archive_outlined,
        tr(sheet, 'Archive board', 'Lưu trữ bảng'),
        () => then(() async {
          await scope.run(
            context,
            () => scope.controller.change(
              (s) => s.put(
                'boards',
                s.get('boards', board).copy({'archived': true}),
              ),
            ),
          );
          if (!context.mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          showUndo(
            context,
            scope,
            tr(
              context,
              'Board archived. Find it in Settings › Data.',
              'Đã lưu trữ bảng. Xem lại ở Cài đặt › Dữ liệu.',
            ),
          );
        }),
      ),
      _row(
        sheet,
        Icons.delete_outline,
        tr(sheet, 'Delete board', 'Xoá bảng'),
        () => then(() async {
          final ok = await confirmHandy(
            context,
            title: tr(
              context,
              'Delete ${b.str('title')}?',
              'Xoá bảng ${b.str('title')}?',
            ),
            message: tr(
              context,
              'Its columns, categories and every card go with it. You can undo right after; backups keep their own copy.',
              'Mọi cột, nhóm và thẻ của bảng sẽ bị xoá. Có thể hoàn tác ngay sau đó; bản sao lưu vẫn giữ bản riêng.',
            ),
            confirmLabel: tr(context, 'Delete board', 'Xoá bảng'),
            destructive: true,
          );
          if (!ok || !context.mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          await scope.run(
            context,
            () => scope.controller.change(
              (s) => deleteBoard(s, board, confirmed: true),
            ),
          );
          if (context.mounted)
            showUndo(
              context,
              scope,
              tr(context, 'Board deleted', 'Đã xoá bảng'),
            );
        }),
        danger: true,
        key: const Key('menu-delete-board'),
      ),
    ];
  });
}

Future<void> addColumnDialog(
  BuildContext context,
  BoardsScope scope,
  String board,
) async {
  final name = await askText(
    context,
    title: tr(context, 'New column', 'Cột mới'),
    hint: tr(context, 'e.g. Waiting', 'VD: Đang chờ'),
    action: tr(context, 'Add', 'Thêm'),
  );
  if (name == null || name.isEmpty || !context.mounted) return;
  await scope.run(
    context,
    () => scope.controller.change((s) => addColumn(s, board, name)),
  );
}

/// A card's menu: the drag-free way to move it, and copy, archive, delete.
Future<void> cardMenu(
  BuildContext context,
  BoardsScope scope,
  String card, {
  required Future<void> Function(String card, String column, int index) onMoved,
}) {
  final t = scope.state.get('tasks', card);
  return _sheet<void>(context, t.str('title'), (sheet) {
    void then(Future<void> Function() action) {
      Navigator.pop(sheet);
      action();
    }

    return [
      _row(
        sheet,
        Icons.drive_file_move_outline,
        tr(sheet, 'Move to…', 'Chuyển tới…'),
        () => then(() => moveCardSheet(context, scope, card, onMoved)),
        key: const Key('menu-move-card'),
      ),
      _row(
        sheet,
        Icons.copy_outlined,
        tr(sheet, 'Duplicate card', 'Nhân bản thẻ'),
        () => then(() async {
          await scope.run(
            context,
            () => scope.controller.change(
              (s) => duplicateCard(s, card, now: scope.clock()),
            ),
          );
          if (context.mounted)
            showUndo(
              context,
              scope,
              tr(context, 'Card duplicated', 'Đã nhân bản thẻ'),
            );
        }),
        key: const Key('menu-duplicate-card'),
      ),
      _row(
        sheet,
        Icons.archive_outlined,
        tr(sheet, 'Archive card', 'Lưu trữ thẻ'),
        () => then(() async {
          await scope.run(
            context,
            () => scope.controller.change(
              (s) => saveTask(
                s,
                s.get('tasks', card).copy({'archived': true}),
                now: scope.clock(),
              ),
            ),
          );
          if (context.mounted)
            showUndo(
              context,
              scope,
              tr(context, 'Card archived', 'Đã lưu trữ thẻ'),
            );
        }),
      ),
      _row(
        sheet,
        Icons.delete_outline,
        tr(sheet, 'Delete card', 'Xoá thẻ'),
        () => then(() async {
          await scope.run(
            context,
            () => scope.controller.change(
              (s) => trashTasks(s, {card}, now: scope.clock()),
            ),
          );
          if (context.mounted)
            showUndo(
              context,
              scope,
              tr(context, 'Card moved to Trash', 'Đã chuyển thẻ vào Thùng rác'),
            );
        }),
        danger: true,
        key: const Key('menu-delete-card'),
      ),
    ];
  });
}

/// Move a card without dragging: pick the column, then the top or the end.
Future<void> moveCardSheet(
  BuildContext context,
  BoardsScope scope,
  String card,
  Future<void> Function(String card, String column, int index) onMoved,
) {
  final s = scope.state, t = s.get('tasks', card);
  final columns = columnsOf(s, t.str('board'));
  return _sheet<void>(
    context,
    tr(
      context,
      'Move “${t.str('title')}” to',
      'Chuyển “${t.str('title')}” tới',
    ),
    (sheet) => [
      for (final c in columns)
        ListTile(
          key: Key('move-to-${c.id}'),
          leading: Icon(
            c.id == t.str('status')
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: BoardsPalette.of(sheet).muted,
          ),
          title: Text(c.str('title')),
          subtitle: Text(
            tr(
              sheet,
              '${cardsIn(s, c.id).length} cards',
              '${cardsIn(s, c.id).length} thẻ',
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  onMoved(card, c.id, 0);
                },
                child: Text(tr(sheet, 'Top', 'Đầu')),
              ),
              TextButton(
                key: Key('move-to-end-${c.id}'),
                onPressed: () {
                  Navigator.pop(sheet);
                  onMoved(card, c.id, cardsIn(s, c.id).length);
                },
                child: Text(tr(sheet, 'End', 'Cuối')),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Rename, move, mark finished, remove (its cards go where the person says).
Future<void> columnMenu(
  BuildContext context,
  BoardsScope scope,
  String column,
) {
  final s = scope.state, c = s.get('statuses', column);
  final columns = columnsOf(s, c.str('board'));
  final i = columns.indexWhere((x) => x.id == column);
  Future<void> swap(int with_) => scope.run(context, () {
    final ids = columns.map((x) => x.id).toList();
    final id = ids.removeAt(i);
    ids.insert(with_, id);
    return scope.controller.change((s) => reorder(s, 'statuses', ids));
  });
  return _sheet<void>(context, c.str('title'), (sheet) {
    void then(Future<void> Function() action) {
      Navigator.pop(sheet);
      action();
    }

    return [
      _row(
        sheet,
        Icons.edit_outlined,
        tr(sheet, 'Rename column', 'Đổi tên cột'),
        () => then(() async {
          final name = await askText(
            context,
            title: tr(context, 'Rename column', 'Đổi tên cột'),
            value: c.str('title'),
          );
          if (name == null || name.isEmpty || !context.mounted) return;
          await scope.run(
            context,
            () => scope.controller.change(
              (s) => s.put(
                'statuses',
                s.get('statuses', column).copy({'title': name}),
              ),
            ),
          );
        }),
      ),
      if (i > 0)
        _row(
          sheet,
          Icons.arrow_back,
          tr(sheet, 'Move left', 'Chuyển sang trái'),
          () => then(() => swap(i - 1)),
        ),
      if (i < columns.length - 1)
        _row(
          sheet,
          Icons.arrow_forward,
          tr(sheet, 'Move right', 'Chuyển sang phải'),
          () => then(() => swap(i + 1)),
        ),
      SwitchListTile(
        secondary: Icon(
          Icons.check_circle_outline,
          color: BoardsPalette.of(sheet).muted,
        ),
        title: Text(
          tr(sheet, 'Cards here are finished', 'Thẻ ở đây là đã xong'),
        ),
        value: c.flag('done'),
        onChanged: (v) => then(
          () => scope.run(
            context,
            () => scope.controller.change(
              (s) => s.put(
                'statuses',
                s.get('statuses', column).copy({'done': v}),
              ),
            ),
          ),
        ),
      ),
      if (columns.length > 1)
        _row(
          sheet,
          Icons.delete_outline,
          tr(sheet, 'Delete column', 'Xoá cột'),
          () => then(() => _deleteColumn(context, scope, column)),
          danger: true,
          key: const Key('menu-delete-column'),
        ),
    ];
  });
}

Future<void> _deleteColumn(
  BuildContext context,
  BoardsScope scope,
  String column,
) async {
  final s = scope.state, c = s.get('statuses', column);
  final others = columnsOf(
    s,
    c.str('board'),
  ).where((x) => x.id != column).toList();
  final count = s.rows('tasks').where((t) => t.str('status') == column).length;
  var target = others.first.id;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => AlertDialog(
        title: Text(
          tr(
            context,
            'Delete ${c.str('title')}?',
            'Xoá cột ${c.str('title')}?',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 0
                  ? tr(context, 'It has no cards.', 'Cột này không có thẻ.')
                  : tr(
                      context,
                      'Its $count cards move to:',
                      '$count thẻ của cột chuyển sang:',
                    ),
            ),
            if (count > 0)
              RadioGroup<String>(
                groupValue: target,
                onChanged: (v) => set(() => target = v ?? target),
                child: Column(
                  children: [
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
            key: const Key('column-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Delete column', 'Xoá cột')),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  await scope.run(
    context,
    () => scope.controller.change(
      (s) => deleteColumn(s, column, moveTo: count == 0 ? null : target),
    ),
  );
  if (context.mounted)
    showUndo(context, scope, tr(context, 'Column deleted', 'Đã xoá cột'));
}

/// The small "Pro" mark beside a Pro feature (never on Free ones).
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'Pro',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).brightness == Brightness.dark
              ? p.ink
              : p.pressed,
        ),
      ),
    );
  }
}

/// A category's name for menus (Uncategorised when none).
String categoryLabel(BuildContext context, BoardsState s, String? id) =>
    categoryName(context, s.maybe('categories', id));
