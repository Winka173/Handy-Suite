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
    // Receipts and a split are marked by an icon and a word or count, not
    // by colour.
    final receipts = scope.receiptsOf(e.id).length;
    final split = scope.splitOf(e.id);
    final settled = e.person == null ? null : scope.person(e.person!);
    final marks = <InlineSpan>[
      if (receipts > 0) ...[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            Icons.attach_file,
            size: 13,
            color: c.muted,
            semanticLabel: tr(context, 'receipts', 'hóa đơn'),
          ),
        ),
        TextSpan(text: '$receipts  '),
      ],
      if (split != null) ...[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.groups_outlined, size: 14, color: c.muted),
        ),
        TextSpan(
          text: tr(
            context,
            ' split ${split.parts.length}  ',
            ' chia ${split.parts.length}  ',
          ),
        ),
      ],
      if (settled != null)
        TextSpan(
          text: e.kind == 'refund'
              ? tr(
                  context,
                  'paid back by ${settled.name} · ',
                  '${settled.name} trả lại · ',
                )
              : tr(
                  context,
                  'paid to ${settled.name} · ',
                  'trả ${settled.name} · ',
                ),
        ),
    ];
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
                          ...marks,
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
