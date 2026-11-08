import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../ui/look.dart';

/// One card on a column: a thin cover when it has one, the title, then one
/// line of facts (category, subtasks, due). Detailed cards also list their
/// first subtasks, tickable in place.
class CardTile extends StatelessWidget {
  final BoardsState state;
  final BoardRecord card;
  final bool detailed, done;
  final DateTime now;
  final VoidCallback? onOpen;
  final void Function(String subtask, bool done)? onTick;

  /// The card's own menu (Move to…, Duplicate, Archive, Delete).
  final VoidCallback? onMenu;
  const CardTile({
    super.key,
    required this.state,
    required this.card,
    required this.now,
    this.detailed = false,
    this.done = false,
    this.onOpen,
    this.onTick,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final theme = Theme.of(context);
    final category = state.maybe(
      'categories',
      card.data['category'] as String?,
    );
    final progress = subtaskProgress(state, card.id);
    final due = dueDay(card);
    final today = DateTime(now.year, now.month, now.day);
    final overdue = !done && due != null && due.isBefore(today);
    final planned = scheduledDay(card);
    final behind = !done && planned != null && planned.isBefore(today);
    final cover = cardCover(context, state, card);
    final subtasks = detailed
        ? subtasksOf(state, card.id).take(3).toList()
        : const <BoardRecord>[];
    final facts = <Widget>[
      if (category != null) Flexible(child: CategoryChip(category)),
      if (progress.total > 0)
        _Fact(
          icon: progress.done == progress.total
              ? Icons.check_circle
              : Icons.check_circle_outline,
          text: '${progress.done}/${progress.total}',
          color: progress.done == progress.total ? p.positive : p.muted,
        ),
      // The day it is planned for and its deadline, always named, so the
      // two are never mistaken for each other.
      if (planned != null && !done)
        _Fact(
          icon: Icons.event_available_outlined,
          text: tr(
            context,
            'Do: ${dueLabel(context, planned, now)}',
            'Làm: ${dueLabel(context, planned, now)}',
          ),
          color: behind ? p.warning : p.muted,
        ),
      if (due != null && !done)
        _Fact(
          icon: Icons.event_outlined,
          text:
              tr(
                context,
                'Due: ${dueLabel(context, due, now)}',
                'Hạn: ${dueLabel(context, due, now)}',
              ) +
              (overdue ? tr(context, ' · late', ' · trễ') : ''),
          color: overdue ? p.danger : p.muted,
        ),
      // Custom fields chosen for the card front, as "Name value".
      for (final f in fieldsOf(state, card.str('board')))
        if (f.flag('onCard') &&
            object(card.data['custom'] ?? {}).containsKey(f.id))
          _Fact(
            icon: Icons.tune,
            text:
                '${f.str('title')} ${fieldText(f, object(card.data['custom'])[f.id], vi: Localizations.localeOf(context).languageCode == 'vi')}',
            color: p.muted,
          ),
    ];
    final label = [
      card.str('title'),
      if (category != null)
        tr(
          context,
          'category ${category.str('title')}',
          'nhóm ${category.str('title')}',
        ),
      if (progress.total > 0)
        tr(
          context,
          '${progress.done} of ${progress.total} subtasks',
          '${progress.done} trên ${progress.total} việc con',
        ),
      if (planned != null && !done)
        tr(context, 'do ', 'làm ') + dueLabel(context, planned, now),
      if (due != null && !done)
        (overdue
                ? tr(context, 'late, due ', 'trễ, hạn ')
                : tr(context, 'due ', 'hạn ')) +
            dueLabel(context, due, now),
    ].join(', ');
    return Semantics(
      button: onOpen != null,
      label: label,
      excludeSemantics: !detailed,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(BoardsRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          onLongPress: null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cover != null)
                SizedBox(height: detailed ? 96 : 52, child: cover),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              card.str('title'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                color: done ? p.muted : p.ink,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: p.muted,
                              ),
                            ),
                          ),
                          if (facts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                for (final f in facts)
                                  f is Flexible ? f.child : f,
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onMenu != null)
                      // A full 48 pt target, the icon kept small.
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          key: Key('card-menu-${card.id}'),
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          tooltip: tr(context, 'Card options', 'Tuỳ chọn thẻ'),
                          onPressed: onMenu,
                          icon: Icon(Icons.more_horiz, color: p.muted),
                        ),
                      ),
                  ],
                ),
              ),
              if (subtasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 8, 6),
                  child: Column(
                    children: [
                      for (final c in subtasks)
                        _SubtaskLine(
                          item: c,
                          onTick: onTick == null
                              ? null
                              : (v) => onTick!(c.id, v),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Fact({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  );
}

class _SubtaskLine extends StatelessWidget {
  final BoardRecord item;
  final ValueChanged<bool>? onTick;
  const _SubtaskLine({required this.item, this.onTick});
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final done = item.flag('done');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTick == null ? null : () => onTick!(!done),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            Checkbox(
              value: done,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onTick == null ? null : (v) => onTick!(v ?? false),
            ),
            Expanded(
              child: Text(
                item.str('title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: done ? p.muted : p.ink,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: p.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
