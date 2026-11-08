import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_menus.dart' show ProBadge;
import '../board/time_actions.dart';
import '../card/card_sheet.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';

/// My Work (Pro): today, left behind and coming up from every board in one
/// list. It is a view, never a board: each line is the card in its own
/// board, and every action changes that card. Without Pro it can be looked
/// at; acting on it asks for Pro.
class MyWorkPage extends StatelessWidget {
  final BoardsScope scope;
  const MyWorkPage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final p = BoardsPalette.of(context);
      final now = scope.clock();
      final s = scope.state;
      final w = myWork(s, now);
      final pro = hasPro(context);

      Future<void> act(List<String> ids, String reason) async {
        if (!await requirePro(context, ProFeature.myWork) || !context.mounted) {
          return;
        }
        await quickSchedule(context, scope, ids, reason: reason);
      }

      Widget item(WorkItem i, {String? reason}) {
        final words = [
          i.board.str('title'),
          if (i.planned != null)
            tr(
              context,
              'plan ${shortDay(i.planned!, now)}',
              'làm ${shortDay(i.planned!, now)}',
            ),
          if (i.due != null)
            tr(
              context,
              'due ${shortDay(i.due!, now)}',
              'hạn ${shortDay(i.due!, now)}',
            ),
          if (i.dueOnly)
            tr(context, 'due today, no plan', 'hạn hôm nay, chưa lên lịch'),
          if (i.overdue) tr(context, 'overdue', 'quá hạn'),
        ];
        return ListTile(
          key: Key('work-${i.card.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            i.card.str('title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            words.join(' · '),
            style: TextStyle(color: i.overdue ? p.danger : p.muted),
          ),
          onTap: () async {
            await Navigator.pushNamed(context, '/board/${i.board.id}');
          },
          onLongPress: () => openCard(context, scope, i.card.id),
          trailing: reason == null
              ? IconButton(
                  tooltip: tr(context, 'Open the card', 'Mở thẻ'),
                  onPressed: () => openCard(context, scope, i.card.id),
                  icon: const Icon(Icons.open_in_new),
                )
              : TextButton(
                  key: Key('work-move-${i.card.id}'),
                  onPressed: () => act([i.card.id], reason),
                  child: Text(
                    reason == 'do early'
                        ? tr(context, 'Do early', 'Làm sớm')
                        : tr(context, 'To today', 'Về hôm nay'),
                  ),
                ),
        );
      }

      Widget section(
        String key,
        String title,
        List<WorkItem> items,
        Widget Function(WorkItem) row, {
        Widget? action,
      }) => Padding(
        key: Key('work-$key'),
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      '$title · ${items.length}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  tr(context, 'Nothing here.', 'Không có gì.'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
              ),
            for (final i in items) row(i),
          ],
        ),
      );

      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'My Work', 'Việc của tôi')),
          actions: [if (!pro) const ProBadge(), const SizedBox(width: 12)],
        ),
        body: ListView(
          key: const Key('my-work'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(
              tr(
                context,
                'Every board in one list. Each card stays in its own board; '
                    'moving it here changes only the day you plan to work.',
                'Mọi bảng trong một danh sách. Thẻ vẫn ở bảng của nó; chuyển '
                    'ở đây chỉ đổi ngày làm.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
            if (!pro)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  key: const Key('work-unlock'),
                  onPressed: () => requirePro(context, ProFeature.myWork),
                  icon: const Icon(Icons.lock_open_outlined),
                  label: Text(
                    tr(
                      context,
                      'A Pro view: look freely; Pro to act from here',
                      'Chế độ Pro: xem thoải mái; cần Pro để thao tác ở đây',
                    ),
                  ),
                ),
              ),
            section('today', tr(context, 'Today', 'Hôm nay'), w.today, item),
            section(
              'behind',
              tr(context, 'Left behind', 'Còn tồn'),
              w.behind,
              (i) => item(i, reason: 'move to now'),
              action: w.behind.isEmpty
                  ? null
                  : TextButton(
                      key: const Key('work-all-today'),
                      onPressed: () => act([
                        for (final i in w.behind) i.card.id,
                      ], 'move to now'),
                      child: Text(
                        tr(context, 'All to today', 'Tất cả về hôm nay'),
                      ),
                    ),
            ),
            section(
              'upcoming',
              tr(context, 'Coming up (2 weeks)', 'Sắp tới (2 tuần)'),
              w.upcoming,
              (i) => item(i, reason: 'do early'),
            ),
          ],
        ),
      );
    },
  );
}

/// Settings › Smart carry-over (Pro): off, ask when a new day starts, or
/// move plans by itself. Turning on the automatic mode first shows what it
/// would move right now.
Future<void> carryOverSettings(BuildContext context, BoardsScope scope) async {
  final pref = object(scope.state.preferences['carryOver'] ?? {});
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: RadioGroup<String>(
        groupValue: (pref['mode'] as String?) ?? 'off',
        onChanged: (v) => Navigator.pop(sheet, v),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, en, vi, enD, viD) in const [
              (
                'off',
                'Off',
                'Tắt',
                'Move cards yourself from Time (always free).',
                'Tự chuyển trong chế độ Thời gian (luôn miễn phí).',
              ),
              (
                'review',
                'Ask each new day',
                'Hỏi mỗi ngày mới',
                'When the app opens on a new day with work left behind, offer to review it.',
                'Khi mở app vào ngày mới mà còn việc tồn, gợi ý xem lại.',
              ),
              (
                'auto',
                'Move by itself',
                'Tự chuyển',
                'Plans from earlier days move to today once a day. Due dates never change; each run can be undone.',
                'Ngày làm cũ tự về hôm nay mỗi ngày một lần. Hạn nộp không đổi; mỗi lần đều hoàn tác được.',
              ),
            ])
              RadioListTile<String>(
                key: Key('carry-$v'),
                value: v,
                title: Text(tr(sheet, en, vi)),
                subtitle: Text(tr(sheet, enD, viD)),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted || picked == (pref['mode'] ?? 'off')) {
    return;
  }
  if (picked != 'off') {
    if (!await requirePro(context, ProFeature.carryOver) || !context.mounted) {
      return;
    }
  }
  if (picked == 'auto') {
    final now = scope.clock();
    final would = carryOverCandidates(scope.state, now);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr(d, 'Move plans by itself?', 'Tự chuyển ngày làm?')),
        content: Text(
          would.isEmpty
              ? tr(
                  d,
                  'Right now nothing would move. From tomorrow, cards planned '
                      'for an earlier day move to today once a day; due dates '
                      'never change.',
                  'Lúc này không có thẻ nào cần chuyển. Từ mai, thẻ có ngày làm '
                      'đã qua sẽ về hôm nay mỗi ngày một lần; hạn nộp không đổi.',
                )
              : tr(
                  d,
                  'Right now this would move ${would.length} cards to today '
                      '(${would.take(3).map((t) => t.str('title')).join(', ')}'
                      '${would.length > 3 ? '…' : ''}). Only their planned '
                      'day changes; due dates, columns and subtasks stay.',
                  'Lúc này sẽ chuyển ${would.length} thẻ về hôm nay '
                      '(${would.take(3).map((t) => t.str('title')).join(', ')}'
                      '${would.length > 3 ? '…' : ''}). Chỉ đổi ngày làm; hạn '
                      'nộp, cột và việc con giữ nguyên.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr(d, 'Cancel', 'Huỷ')),
          ),
          FilledButton(
            key: const Key('carry-confirm'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr(d, 'Turn on', 'Bật')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
  }
  await scope.run(
    context,
    () => scope.controller.change(
      (s) => s.copy(
        preferences: {
          ...s.preferences,
          'carryOver': {
            ...object(s.preferences['carryOver'] ?? {}),
            'mode': picked == 'off' ? null : picked,
          }..removeWhere((_, v) => v == null),
        },
      ),
      history: false,
    ),
  );
}
