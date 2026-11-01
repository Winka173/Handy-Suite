import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';

/// One entry: who or what on the first line, its category and account in
/// grey below, the amount on the right edge. The sign is in the text;
/// only money coming in is green.
class EntryRow extends StatelessWidget {
  final SpendScope scope;
  final Entry entry;
  final VoidCallback? onTap, onLongPress;
  final bool selected, selecting, showDate;
  final ValueChanged<bool>? onSelect;
  const EntryRow({
    super.key,
    required this.scope,
    required this.entry,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selecting = false,
    this.showDate = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final e = entry;
    final account = scope.account(e.account);
    final category = scope.category(e.category);
    final pending = e.status == 'pending';
    final meta = [
      if (showDate)
        dayLabel(context, scope, reportDay(e.when, scope.state.zone)),
      if (category != null) category.name,
      if (e.kind == 'transfer' && e.toAccount != null)
        '${account.name} → ${scope.account(e.toAccount!).name}'
      else
        account.name,
      if (e.kind == 'refund' || e.kind == 'adjustment')
        kindLabel(context, e.kind),
      ...e.tags.map((t) => '#$t'),
    ].join(' · ');
    return Semantics(
      selected: selecting ? selected : null,
      child: InkWell(
        key: Key('entry-${e.id}'),
        onTap: selecting ? () => onSelect?.call(!selected) : onTap,
        onLongPress: onLongPress,
        child: Container(
          color: selected ? c.select : null,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(
            horizontal: HandySpace.l,
            vertical: 10,
          ),
          child: Row(
            children: [
              if (selecting) ...[
                Checkbox(
                  value: selected,
                  onChanged: (v) => onSelect?.call(v == true),
                ),
                const SizedBox(width: HandySpace.s),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entryTitle(context, scope, e),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (category != null) ...[
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: HandyDot(
                                scope.categoryHue(category.id),
                                size: 8,
                              ),
                            ),
                            const TextSpan(text: ' '),
                          ],
                          TextSpan(text: meta),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HandySpace.m),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Money(
                    scope,
                    e.kind == 'transfer' ? -e.amount : e.amount,
                    account.currency,
                    sign: e.kind != 'transfer',
                    income: e.kind == 'income' || e.kind == 'refund',
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (pending)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tr(context, 'Not yet paid', 'Chưa trả thật'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.warning,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
