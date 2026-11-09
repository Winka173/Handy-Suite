import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import 'board_history.dart';
import 'time_actions.dart';
import 'rules_page.dart';
import '../card/fields_ui.dart';
import '../card/card_templates_ui.dart';
import '../card/card_sheet.dart' show openCard;
import '../design/theme.dart';
import 'key_dates.dart';
import '../pro/pro.dart';
import '../scope.dart';
import '../ui/look.dart';
import 'board_page.dart';

Future<T?> _sheet<T>(
  BuildContext context,
  String title,
  List<Widget> Function(BuildContext) rows,
) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  // Never the whole height: a tap above the sheet still closes it.
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * .85,
  ),
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

/// A small heading that groups a menu's rows.
Widget _section(BuildContext context, String title, {Key? key}) => Padding(
  key: key,
  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
  child: Semantics(
    header: true,
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: BoardsPalette.of(context).muted),
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

    final pro = hasPro(sheet);
    return [
      _section(
        sheet,
        tr(sheet, 'Board', 'Bảng'),
        key: const Key('menu-sec-board'),
      ),
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
      if (onLook != null)
        _row(
          sheet,
          Icons.palette_outlined,
          tr(sheet, 'Look and cover', 'Giao diện và ảnh bìa'),
          () => then(() async => onLook()),
          key: const Key('menu-board-look'),
        ),
      if (onLook == null)
        _row(
          sheet,
          Icons.image_outlined,
          tr(sheet, 'Change cover', 'Đổi ảnh bìa'),
          () => then(() => pickBoardCover(context, scope, board)),
          key: const Key('menu-board-cover'),
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
      _section(
        sheet,
        tr(sheet, 'Show and set up', 'Hiển thị và cấu trúc'),
        key: const Key('menu-sec-setup'),
      ),
      // One switch that always says the same thing (it was a row whose
      // words flipped between two opposite actions).
      SwitchListTile(
        key: const Key('menu-presentation'),
        secondary: Icon(
          Icons.checklist_rounded,
          color: BoardsPalette.of(sheet).muted,
        ),
        title: Text(
          tr(sheet, 'Show subtasks on cards', 'Hiện việc con trên thẻ'),
        ),
        subtitle: Text(
          detailed
              ? tr(
                  sheet,
                  'Each card lists its subtasks to tick',
                  'Mỗi thẻ liệt kê việc con để tích',
                )
              : tr(
                  sheet,
                  'Cards show only their count, like 1/3',
                  'Thẻ chỉ hiện số đếm, như 1/3',
                ),
        ),
        value: detailed,
        onChanged: (on) => then(
          () => scope.run(
            context,
            () => scope.controller.change(
              (s) => setBoardLook(
                s,
                board,
                presentation: on ? 'detailed' : 'compact',
              ),
            ),
          ),
        ),
      ),
      _row(
        sheet,
        Icons.view_column_outlined,
        tr(sheet, 'Add column', 'Thêm cột'),
        () => then(() => addColumnDialog(context, scope, board)),
      ),
      _row(
        sheet,
        Icons.tune,
        tr(sheet, 'Custom fields', 'Trường tuỳ chỉnh'),
        () => then(() async {
          if (!await requirePro(context, ProFeature.fields) ||
              !context.mounted) {
            return;
          }
          await fieldsSheet(context, scope, board);
        }),
        key: const Key('menu-fields'),
        trailing: pro ? null : const ProBadge(),
      ),
      _row(
        sheet,
        Icons.flag_outlined,
        tr(sheet, 'Key dates', 'Ngày quan trọng'),
        () => then(() => editMilestones(context, scope, board)),
        key: const Key('menu-key-dates'),
      ),
      _section(
        sheet,
        tr(sheet, 'Pro tools', 'Công cụ Pro'),
        key: const Key('menu-sec-pro'),
      ),
      _row(
        sheet,
        Icons.bolt_outlined,
        tr(sheet, 'Automation rules', 'Luật tự động'),
        () => then(() async {
          if (!await requirePro(context, ProFeature.automation) ||
              !context.mounted) {
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => RulesPage(scope: scope, board: board),
            ),
          );
        }),
        key: const Key('menu-rules'),
        trailing: pro ? null : const ProBadge(),
      ),
      _row(
        sheet,
        Icons.history,
        tr(sheet, 'Board history', 'Lịch sử bảng'),
        () => then(() async {
          if (!await requirePro(context, ProFeature.history) ||
              !context.mounted) {
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => BoardHistoryPage(scope: scope, board: board),
            ),
          );
        }),
        key: const Key('menu-board-history'),
        trailing: pro ? null : const ProBadge(),
      ),
      _row(
        sheet,
        Icons.insights_outlined,
        tr(sheet, 'Board insights', 'Thống kê bảng'),
        () => then(() async {
          if (await requirePro(context, ProFeature.insights) && context.mounted)
            await Navigator.pushNamed(context, '/insights', arguments: board);
        }),
        trailing: pro ? null : const ProBadge(),
        key: const Key('menu-insights'),
      ),
      _section(
        sheet,
        tr(sheet, 'Share', 'Chia sẻ'),
        key: const Key('menu-sec-share'),
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
      const Divider(height: 24),
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

/// A card's menu: when to work on it, the drag-free way to move it, and
/// copy, archive, delete. [inSheet]: opened from the card itself, which
/// already has its column, so "Move to…" is left out there.
Future<void> cardMenu(
  BuildContext context,
  BoardsScope scope,
  String card, {
  required Future<void> Function(String card, String column, int index) onMoved,
  bool inSheet = false,
}) {
  final t = scope.state.get('tasks', card);
  final now = scope.clock(), today = calendarDay(now);
  final planned = scheduledDay(t);
  final open = isOpenCard(scope.state, t);
  return _sheet<void>(context, t.str('title'), (sheet) {
    void then(Future<void> Function() action) {
      Navigator.pop(sheet);
      action();
    }

    return [
      _row(
        sheet,
        Icons.checklist_rounded,
        tr(sheet, 'Add a subtask', 'Thêm việc con'),
        () => then(() => openCard(context, scope, card, addSubtask: true)),
        key: const Key('card-menu-subtask'),
      ),
      if (open && planned != today)
        _row(
          sheet,
          Icons.today_outlined,
          tr(sheet, 'Do it today', 'Làm hôm nay'),
          () => then(
            () => quickSchedule(
              context,
              scope,
              [card],
              reason: planned != null && planned.isBefore(today)
                  ? 'move to now'
                  : 'do early',
            ),
          ),
          key: const Key('menu-do-today'),
        ),
      if (open)
        _row(
          sheet,
          Icons.event_available_outlined,
          planned == null
              ? tr(sheet, 'Plan a day…', 'Lên lịch…')
              : tr(
                  sheet,
                  'Plan another day… (now ${shortDay(planned, now)})',
                  'Đổi ngày làm… (đang ${shortDay(planned, now)})',
                ),
          () => then(() async {
            final day = await pickHandyDate(context, isoDay(planned ?? today));
            if (day == null || !context.mounted) return;
            await quickSchedule(
              context,
              scope,
              [card],
              reason: 'plan',
              day: DateTime.parse(day),
            );
          }),
          key: const Key('menu-plan'),
        ),
      if (open && planned != null)
        _row(
          sheet,
          Icons.event_busy_outlined,
          tr(sheet, 'Take the planned day off', 'Bỏ ngày làm'),
          () => then(() async {
            await scope.run(
              context,
              () => scope.controller.change(
                (s) => scheduleCards(s, [card], null, reason: 'plan', now: now),
              ),
            );
            if (context.mounted)
              showUndo(
                context,
                scope,
                tr(context, 'Planned day taken off', 'Đã bỏ ngày làm'),
              );
          }),
          key: const Key('menu-unplan'),
        ),
      if (!inSheet)
        _row(
          sheet,
          Icons.drive_file_move_outline,
          tr(sheet, 'Move to…', 'Chuyển tới…'),
          () => then(() => moveCardSheet(context, scope, card, onMoved)),
          key: const Key('menu-move-card'),
        ),
      _row(
        sheet,
        Icons.content_copy_outlined,
        tr(sheet, 'Save as card template', 'Lưu làm mẫu thẻ'),
        () => then(() => saveAsCardTemplate(context, scope, card)),
        key: const Key('menu-save-template'),
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
    (sheet) {
      final p = BoardsPalette.of(sheet);
      final theme = Theme.of(sheet);
      void move(String column, int index) {
        Navigator.pop(sheet);
        onMoved(card, column, index);
      }

      return [
        for (final c in columns)
          Builder(
            builder: (_) {
              final here = c.id == t.str('status');
              final n = cardsIn(s, c.id).length;
              final count = tr(sheet, n == 1 ? '1 card' : '$n cards', '$n thẻ');
              // A row per column: the card's own column tinted and named
              // as where it is; a tap on another moves it to the end.
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  key: Key('move-to-${c.id}'),
                  color: here ? p.tint : p.raised,
                  borderRadius: BorderRadius.circular(BoardsRadii.card),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: here ? null : () => move(c.id, n),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 60),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.str('title'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: here ? p.pressed : p.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    here
                                        ? tr(
                                            sheet,
                                            'Here now · $count',
                                            'Đang ở đây · $count',
                                          )
                                        : count,
                                    key: here ? const Key('move-here') : null,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: here ? p.pressed : p.muted,
                                      fontWeight: here ? FontWeight.w600 : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              key: Key('move-to-top-${c.id}'),
                              onPressed: () => move(c.id, 0),
                              child: Text(tr(sheet, 'Top', 'Đầu')),
                            ),
                            TextButton(
                              key: Key('move-to-end-${c.id}'),
                              onPressed: () => move(c.id, n),
                              child: Text(tr(sheet, 'End', 'Cuối')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ];
    },
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
        // What the switch changes, so it reads without explaining.
        subtitle: Text(
          tr(
            sheet,
            'They count as done, are never late, and show a tick on the column',
            'Được tính là xong, không bị báo trễ hạn, và cột có dấu ✓',
          ),
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
