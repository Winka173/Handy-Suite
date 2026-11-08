import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';

/// 9/11, or 9/11/2027 outside this year.
String shortDay(DateTime d, DateTime now) =>
    '${d.day}/${d.month}${d.year == now.year ? '' : '/${d.year}'}';

/// Plans [ids] for [day] (today by default) after making sure no deadline
/// changes by surprise: when some of them have only a due date, the person
/// confirms that the due date stays, or picks "change the due date"
/// instead. Then one Undo puts every plan back. Returns whether anything
/// was planned.
Future<bool> quickSchedule(
  BuildContext context,
  BoardsScope scope,
  List<String> ids, {
  required String reason,
  DateTime? day,
}) async {
  if (ids.isEmpty) return false;
  final now = scope.clock(), target = calendarDay(day ?? now);
  final s = scope.state;
  final dueOnly = [
    for (final id in ids)
      if (s.get('tasks', id) case final t
          when scheduledDay(t) == null && dueDay(t) != null)
        t,
  ];
  if (dueOnly.isNotEmpty) {
    final choice = await _confirmDueOnly(context, dueOnly, target, now);
    if (choice == null || !context.mounted) return false;
    if (choice == _DueChoice.changeDue) {
      // The other road, said out loud: the deadline itself becomes today.
      await scope.run(
        context,
        () => scope.controller.change((s) {
          for (final t in dueOnly) {
            s = setDueDay(s, t.id, target, now: scope.clock());
          }
          return s;
        }),
      );
      if (context.mounted) {
        _undoBar(
          context,
          tr(
            context,
            'Due date set to ${shortDay(target, now)}',
            'Đã đổi hạn nộp thành ${shortDay(target, now)}',
          ),
          () => scope.controller.undo(),
        );
      }
      if (dueOnly.length == ids.length) return true;
      ids = [
        for (final id in ids)
          if (!dueOnly.any((t) => t.id == id)) id,
      ];
    }
  }
  final before = plansOf(scope.state, ids);
  if (!context.mounted) return false;
  await scope.run(
    context,
    () => scope.controller.change(
      (s) => scheduleCards(s, ids, target, reason: reason, now: scope.clock()),
    ),
  );
  if (!context.mounted) return true;
  final n = ids.length;
  final when = daysBetween(now, target) == 0
      ? tr(context, 'today', 'hôm nay')
      : shortDay(target, now);
  _undoBar(
    context,
    tr(
      context,
      n == 1 ? 'Planned for $when' : 'Planned $n cards for $when',
      n == 1 ? 'Đã lên lịch làm $when' : 'Đã lên lịch $n thẻ cho $when',
    ),
    () => scope.run(
      context,
      () => scope.controller.change(
        (s) => restorePlans(s, before, now: scope.clock()),
      ),
    ),
  );
  return true;
}

void _undoBar(BuildContext context, String message, VoidCallback undo) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      // Undo stays a few seconds, then goes; it never sits over the board.
      persist: false,
      content: Text(message),
      action: SnackBarAction(
        label: tr(context, 'Undo', 'Hoàn tác'),
        onPressed: undo,
      ),
    ),
  );
}

enum _DueChoice { plan, changeDue }

Future<_DueChoice?> _confirmDueOnly(
  BuildContext context,
  List<BoardRecord> cards,
  DateTime day,
  DateTime now,
) {
  final one = cards.length == 1;
  final due = one ? shortDay(dueDay(cards.single)!, now) : '';
  final when = daysBetween(now, day) == 0
      ? tr(context, 'today', 'hôm nay')
      : shortDay(day, now);
  return showDialog<_DueChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        tr(context, 'Plan to work on it $when?', 'Lên lịch làm $when?'),
      ),
      content: Text(
        one
            ? tr(
                context,
                'This card only has a due date ($due). Planning it sets the '
                    'day you work on it; the due date stays $due.',
                'Thẻ này chỉ có hạn nộp ($due). Lên lịch là chọn ngày làm; '
                    'hạn nộp vẫn là $due.',
              )
            : tr(
                context,
                '${cards.length} of these cards only have a due date. '
                    'Planning sets the day you work on them; their due '
                    'dates stay as they are.',
                '${cards.length} thẻ chỉ có hạn nộp. Lên lịch là chọn ngày '
                    'làm; hạn nộp của chúng giữ nguyên.',
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Huỷ')),
        ),
        TextButton(
          key: const Key('due-only-change'),
          onPressed: () => Navigator.pop(context, _DueChoice.changeDue),
          child: Text(tr(context, 'Change the due date', 'Đổi hạn nộp')),
        ),
        FilledButton(
          key: const Key('due-only-plan'),
          onPressed: () => Navigator.pop(context, _DueChoice.plan),
          child: Text(
            one
                ? tr(
                    context,
                    'Plan $when · keep due $due',
                    'Lên lịch làm $when · giữ hạn $due',
                  )
                : tr(context, 'Plan $when', 'Lên lịch làm $when'),
          ),
        ),
      ],
    ),
  );
}

/// One history line in words.
String eventText(BuildContext context, BoardRecord e) {
  final d = e.data['details'] is Map
      ? Map<String, Object?>.from(e.data['details'] as Map)
      : const <String, Object?>{};
  String day(Object? v) {
    final x = v is String ? DateTime.tryParse(v) : null;
    return x == null
        ? tr(context, 'none', 'không có')
        : '${x.day}/${x.month}/${x.year}';
  }

  String? name(String key) => d[key] is String ? d[key] as String : null;
  return switch (e.str('action')) {
    'created' =>
      d['copyOf'] != null
          ? tr(context, 'Created as a copy', 'Tạo từ một bản sao')
          : d['repeatOf'] != null
          ? tr(context, 'Created by a repeat', 'Tạo từ thẻ lặp lại')
          : tr(context, 'Created', 'Tạo thẻ'),
    'completed' => tr(
      context,
      'Finished${name('toName') == null ? '' : ' · ${name('toName')}'}',
      'Hoàn thành${name('toName') == null ? '' : ' · ${name('toName')}'}',
    ),
    'reopened' => tr(
      context,
      'Reopened · ${name('toName') ?? ''}',
      'Mở lại · ${name('toName') ?? ''}',
    ),
    'status changed' => tr(
      context,
      'Moved ${name('fromName') ?? ''} → ${name('toName') ?? ''}',
      'Chuyển ${name('fromName') ?? ''} → ${name('toName') ?? ''}',
    ),
    'due changed' => tr(
      context,
      'Due date ${day(d['from'])} → ${day(d['to'])}',
      'Hạn nộp ${day(d['from'])} → ${day(d['to'])}',
    ),
    'scheduled' => switch (d['reason']) {
      'undo' => tr(
        context,
        'Plan undone: ${day(d['to'])}',
        'Hoàn tác lịch làm: ${day(d['to'])}',
      ),
      'move to now' => tr(
        context,
        'Moved to now: plan ${day(d['from'])} → ${day(d['to'])}',
        'Chuyển về hiện tại: ngày làm ${day(d['from'])} → ${day(d['to'])}',
      ),
      'carry over' => tr(
        context,
        'Carried over: plan ${day(d['from'])} → ${day(d['to'])}',
        'Tự chuyển tồn: ngày làm ${day(d['from'])} → ${day(d['to'])}',
      ),
      'do early' => tr(
        context,
        'Done early: plan ${day(d['from'])} → ${day(d['to'])}',
        'Làm sớm: ngày làm ${day(d['from'])} → ${day(d['to'])}',
      ),
      _ => tr(
        context,
        'Plan ${day(d['from'])} → ${day(d['to'])}',
        'Ngày làm ${day(d['from'])} → ${day(d['to'])}',
      ),
    },
    'category changed' => tr(
      context,
      'Category → ${name('toName') ?? 'none'}',
      'Nhóm → ${name('toName') ?? 'không có'}',
    ),
    'subtask' =>
      d['done'] == true
          ? tr(context, 'A subtask ticked', 'Đánh dấu xong một việc con')
          : tr(context, 'A subtask unticked', 'Bỏ đánh dấu một việc con'),
    'archived' => tr(context, 'Archived', 'Lưu trữ'),
    'unarchived' => tr(context, 'Back from the archive', 'Lấy lại từ lưu trữ'),
    'trashed' => tr(context, 'Moved to the trash', 'Bỏ vào thùng rác'),
    'restored' => tr(
      context,
      'Restored from the trash',
      'Khôi phục từ thùng rác',
    ),
    'edited' => tr(context, 'Title or note edited', 'Sửa tên hoặc ghi chú'),
    'from template' => tr(
      context,
      'Made from a card template',
      'Tạo từ mẫu thẻ',
    ),
    'field changed' => tr(
      context,
      'Field changed: ${name('name') ?? ''}',
      'Đổi trường: ${name('name') ?? ''}',
    ),
    final other => other,
  };
}

/// What really happened to a card, newest first. Read only; a card from
/// before history began says so instead of inventing its past.
Future<void> showCardHistory(
  BuildContext context,
  BoardsScope scope,
  String card,
) {
  final s = scope.state;
  final events = cardHistory(s, card).reversed.toList();
  final fromStart = historyFromStart(s, card);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      final p = BoardsPalette.of(context);
      final loc = MaterialLocalizations.of(context);
      String when(BoardRecord e) {
        final at = DateTime.parse(e.str('at')).toLocal();
        return '${loc.formatShortDate(at)} · ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        maxChildSize: .92,
        builder: (context, scroll) => ListView(
          key: const Key('history-list'),
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Semantics(
              header: true,
              child: Text(
                tr(context, 'Card history', 'Lịch sử thẻ'),
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                context,
                'What happened to this card, newest first. It is a record of '
                    'changes, not a picture of the board on a past day.',
                'Những gì đã xảy ra với thẻ, mới nhất trước. Đây là nhật ký '
                    'thay đổi, không phải ảnh chụp bảng vào một ngày cũ.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              Padding(
                key: const Key('history-empty'),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  tr(
                    context,
                    'Nothing recorded yet. History is kept from this '
                        'version on; earlier changes were not recorded.',
                    'Chưa có gì được ghi. Lịch sử chỉ ghi từ phiên bản này; '
                        'thay đổi trước đó không được lưu.',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final e in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  eventIcon(e.str('action')),
                  color: p.muted,
                  size: 20,
                ),
                title: Text(eventText(context, e)),
                subtitle: Text(when(e)),
              ),
            if (events.isNotEmpty && !fromStart)
              Padding(
                key: const Key('history-partial'),
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr(
                    context,
                    'History starts here: this card is older than history '
                        'keeping.',
                    'Lịch sử bắt đầu từ đây: thẻ có từ trước khi app ghi '
                        'lịch sử.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                ),
              ),
          ],
        ),
      );
    },
  );
}

IconData eventIcon(String action) => switch (action) {
  'created' => Icons.add_circle_outline,
  'completed' => Icons.check_circle_outline,
  'reopened' => Icons.replay,
  'status changed' => Icons.view_week_outlined,
  'due changed' => Icons.event_outlined,
  'scheduled' => Icons.event_available_outlined,
  'category changed' => Icons.label_outline,
  'subtask' => Icons.checklist,
  'archived' || 'unarchived' => Icons.inventory_2_outlined,
  'trashed' || 'restored' => Icons.delete_outline,
  _ => Icons.edit_outlined,
};

/// Every card still open from before today, oldest first: tick some (or
/// all) and plan them for today in one step, or open one.
Future<void> showBacklog(
  BuildContext context,
  BoardsScope scope,
  String board, {
  bool Function(BoardRecord card)? shows,
  void Function(BoardRecord card)? open,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      _BacklogSheet(scope: scope, board: board, shows: shows, open: open),
);

class _BacklogSheet extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  final bool Function(BoardRecord card)? shows;
  final void Function(BoardRecord card)? open;
  const _BacklogSheet({
    required this.scope,
    required this.board,
    this.shows,
    this.open,
  });
  @override
  State<_BacklogSheet> createState() => _BacklogSheetState();
}

class _BacklogSheetState extends State<_BacklogSheet> {
  final picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final now = widget.scope.clock();
    final items = backlogOf(
      widget.scope.state,
      widget.board,
      now,
      shows: widget.shows,
    );
    picked.removeWhere((id) => !items.any((i) => i.card.id == id));
    Future<void> move(List<String> ids) async {
      final ok = await quickSchedule(
        context,
        widget.scope,
        ids,
        reason: 'move to now',
      );
      if (ok && mounted) setState(picked.clear);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      maxChildSize: .95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    tr(context, 'Still open from before', 'Còn tồn từ trước'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    context,
                    'Cards planned or due before today and not finished. '
                        'Moving them to today changes only the day you plan '
                        'to work on them.',
                    'Thẻ có ngày làm hoặc hạn nộp trước hôm nay mà chưa xong. '
                        'Chuyển về hôm nay chỉ đổi ngày làm.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    key: const Key('backlog-empty'),
                    child: Text(
                      tr(
                        context,
                        'Nothing left behind.',
                        'Không còn việc tồn.',
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                : ListView(
                    key: const Key('backlog-list'),
                    controller: scroll,
                    children: [
                      for (final i in items)
                        CheckboxListTile(
                          key: Key('backlog-${i.card.id}'),
                          value: picked.contains(i.card.id),
                          onChanged: (v) => setState(
                            () => v == true
                                ? picked.add(i.card.id)
                                : picked.remove(i.card.id),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            i.card.str('title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              if (i.planned != null)
                                tr(
                                  context,
                                  'Plan ${shortDay(i.planned!, now)}',
                                  'Ngày làm ${shortDay(i.planned!, now)}',
                                ),
                              if (i.due != null)
                                tr(
                                  context,
                                  'Due ${shortDay(i.due!, now)}',
                                  'Hạn ${shortDay(i.due!, now)}',
                                ),
                              if (i.overdue) tr(context, 'Overdue', 'Quá hạn'),
                            ].join(' · '),
                            style: TextStyle(
                              color: i.overdue ? p.danger : p.muted,
                            ),
                          ),
                          secondary: widget.open == null
                              ? null
                              : IconButton(
                                  tooltip: tr(context, 'Open', 'Mở'),
                                  onPressed: () => widget.open!(i.card),
                                  icon: const Icon(Icons.open_in_new),
                                ),
                        ),
                    ],
                  ),
          ),
          if (items.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const Key('backlog-move'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => move(
                    picked.isEmpty
                        ? [for (final i in items) i.card.id]
                        : picked.toList(),
                  ),
                  icon: const Icon(Icons.today_outlined),
                  label: Text(
                    picked.isEmpty
                        ? tr(
                            context,
                            'Move all ${items.length} to today',
                            'Chuyển cả ${items.length} thẻ về hôm nay',
                          )
                        : tr(
                            context,
                            'Move ${picked.length} to today',
                            'Chuyển ${picked.length} thẻ về hôm nay',
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
