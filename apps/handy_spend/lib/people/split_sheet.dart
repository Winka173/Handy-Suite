import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../money.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/sheet.dart';
import 'split_logic.dart';

/// What the split editor hands back: a draft, or null to stop splitting.
class SplitResult {
  final SplitDraft? draft;
  const SplitResult(this.draft);
}

/// Divides [total] between you and other people: equally, by shares, or
/// by exact amounts that must add up to the minor unit. Nothing is saved
/// here; the entry's Save keeps it with the entry.
Future<SplitResult?> openSplitSheet(
  BuildContext context,
  SpendScope scope, {
  required BigInt total,
  required String currency,
  SplitDraft? draft,
}) => openSheet<SplitResult>(
  context,
  scope,
  (_) =>
      SplitSheet(scope: scope, total: total, currency: currency, draft: draft),
);

class SplitSheet extends StatefulWidget {
  final SpendScope scope;
  final BigInt total;
  final String currency;
  final SplitDraft? draft;

  /// When true the sheet asks who paid (someone paid for you).
  final bool askPayer;
  const SplitSheet({
    super.key,
    required this.scope,
    required this.total,
    required this.currency,
    this.draft,
    this.askPayer = false,
  });
  @override
  State<SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends State<SplitSheet> {
  SpendScope get scope => widget.scope;
  late SplitDraft draft = _start();
  final name = TextEditingController();
  final amounts = <String, TextEditingController>{};
  String error = '';

  bool get vi => Localizations.localeOf(context).languageCode == 'vi';

  SplitDraft _start() {
    final d = widget.draft ?? const SplitDraft();
    final lines = [...d.lines];
    // Everyone you know is listed, unticked, so adding one is one tap.
    for (final p in scope.state.people.where((p) => !p.archived)) {
      if (!lines.any((l) => l.who == p.id))
        lines.add(SplitLine(p.id, included: false));
    }
    if (!lines.any((l) => l.who == me)) lines.insert(0, const SplitLine(me));
    return d.copyWith(lines: lines);
  }

  @override
  void dispose() {
    name.dispose();
    for (final c in amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  String who(String id) => id == me
      ? tr(context, 'You', 'Bạn')
      : draft.added.where((p) => p.id == id).firstOrNull?.name ??
            scope.person(id)?.name ??
            '?';

  int hue(String id) {
    final i = scope.personHue(id);
    return i >= 0
        ? i
        : scope.state.people.length + draft.added.indexWhere((p) => p.id == id);
  }

  TextEditingController field(SplitLine l) => amounts.putIfAbsent(
    l.who,
    () => TextEditingController(
      text: l.amount == null || l.amount == BigInt.zero
          ? ''
          : editableAmount(l.amount!, widget.currency, vi: vi),
    ),
  );

  void setLine(SplitLine next) => setState(() {
    error = '';
    draft = draft.copyWith(
      lines: [
        for (final l in draft.lines)
          if (l.who == next.who) next else l,
      ],
    );
  });

  void readAmounts() {
    for (final l in draft.lines) {
      final c = amounts[l.who];
      if (c == null) continue;
      BigInt? v;
      try {
        v = c.text.trim().isEmpty
            ? BigInt.zero
            : parseAmount(c.text, widget.currency, vi: vi);
      } catch (_) {
        v = null;
      }
      draft = draft.copyWith(
        lines: [
          for (final x in draft.lines)
            if (x.who == l.who) x.copyWith(amount: v ?? BigInt.from(-1)) else x,
        ],
      );
    }
  }

  void addPerson() {
    final text = name.text.trim();
    if (text.isEmpty) return;
    final existing = [
      ...scope.state.people,
      ...draft.added,
    ].where((p) => p.name.toLowerCase() == text.toLowerCase()).firstOrNull;
    setState(() {
      error = '';
      if (existing != null) {
        draft = draft.copyWith(
          lines: [
            for (final l in draft.lines)
              if (l.who == existing.id) l.copyWith(included: true) else l,
          ],
        );
      } else {
        final p = Person(id: newId(), name: text);
        draft = draft.copyWith(
          added: [...draft.added, p],
          lines: [...draft.lines, SplitLine(p.id)],
        );
      }
      name.clear();
    });
  }

  /// The parts as they stand, or why not.
  (List<SplitPart>?, String) preview() {
    if (widget.askPayer && draft.payer == me)
      return (null, tr(context, 'Choose who paid.', 'Chọn người đã trả.'));
    try {
      final parts = draft.parts(widget.total);
      if (draft.payer != me &&
          !parts.any((p) => p.who == me && p.amount > BigInt.zero))
        return (
          null,
          tr(context, 'Give yourself a share.', 'Bạn cần có một phần.'),
        );
      if (!parts.any((p) => p.who != draft.payer && p.amount > BigInt.zero))
        return (
          null,
          tr(
            context,
            'Tick at least one other person.',
            'Chọn thêm ít nhất một người.',
          ),
        );
      return (parts, '');
    } catch (_) {
      if (draft.method == 'exact') {
        final gap = draft.gap(widget.total);
        if (draft.chosen.any((l) => (l.amount ?? BigInt.zero).isNegative))
          return (null, tr(context, 'Check the amounts.', 'Kiểm tra số tiền.'));
        return (
          null,
          gap.isNegative
              ? tr(
                  context,
                  '${moneyText(context, scope, -gap, widget.currency)} still to place',
                  'Còn thiếu ${moneyText(context, scope, -gap, widget.currency)}',
                )
              : tr(
                  context,
                  '${moneyText(context, scope, gap, widget.currency)} over the total',
                  'Vượt tổng ${moneyText(context, scope, gap, widget.currency)}',
                ),
        );
      }
      return (
        null,
        tr(context, 'Give someone a share.', 'Chia cho ít nhất một người.'),
      );
    }
  }

  void done() {
    readAmounts();
    final (parts, why) = preview();
    if (parts == null) {
      setState(() => error = why);
      return;
    }
    Navigator.pop(context, SplitResult(draft));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    if (draft.method == 'exact') readAmounts();
    final (parts, why) = preview();
    final shareOf = {
      for (final p in parts ?? const <SplitPart>[]) p.who: p.amount,
    };
    final people = draft.lines;
    return SheetFrame(
      title: tr(context, 'Split the cost', 'Chia tiền'),
      error: error,
      actions: [
        if (widget.draft != null)
          TextButton(
            key: const Key('split-remove'),
            onPressed: () => Navigator.pop(context, const SplitResult(null)),
            child: Text(tr(context, 'Don\'t split', 'Không chia')),
          ),
      ],
      primary: FilledButton(
        key: const Key('split-done'),
        onPressed: done,
        child: Text(tr(context, 'Use this split', 'Dùng cách chia này')),
      ),
      children: [
        Text(
          tr(context, 'Total', 'Tổng'),
          style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
        ),
        Money(
          scope,
          widget.total,
          widget.currency,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: HandySpace.l),
        if (widget.askPayer) ...[
          Text(
            tr(context, 'Who paid', 'Ai đã trả'),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final l in people.where((l) => l.who != me))
                ChoiceChip(
                  key: Key('split-payer-${l.who}'),
                  avatar: HandyDot(hue(l.who)),
                  label: Text(who(l.who)),
                  selected: draft.payer == l.who,
                  onSelected: (_) => setState(() {
                    error = '';
                    draft = draft.copyWith(
                      payer: l.who,
                      lines: [
                        for (final x in draft.lines)
                          x.who == l.who ? x.copyWith(included: true) : x,
                      ],
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: HandySpace.l),
        ],
        SegmentedButton<String>(
          key: const Key('split-method'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 'equal',
              label: Text(tr(context, 'Equally', 'Chia đều')),
            ),
            ButtonSegment(
              value: 'shares',
              label: Text(tr(context, 'By shares', 'Theo phần')),
            ),
            ButtonSegment(
              value: 'exact',
              label: Text(tr(context, 'Exact', 'Số cụ thể')),
            ),
          ],
          selected: {draft.method},
          onSelectionChanged: (v) => setState(() {
            error = '';
            // Exact starts from the shares as they were, so it adds up.
            if (v.single == 'exact' && parts != null) {
              for (final p in parts) {
                amounts[p.who]?.dispose();
                amounts[p.who] = TextEditingController(
                  text: editableAmount(p.amount, widget.currency, vi: vi),
                );
              }
            }
            draft = draft.copyWith(method: v.single);
          }),
        ),
        const SizedBox(height: HandySpace.m),
        HandyGroup(
          children: [
            for (final l in people)
              Padding(
                key: Key('split-line-${l.who}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: HandySpace.s,
                  vertical: HandySpace.xs,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      key: Key('split-in-${l.who}'),
                      value: l.included,
                      semanticLabel: who(l.who),
                      onChanged: (v) =>
                          setLine(l.copyWith(included: v == true)),
                    ),
                    // You have no colour; your name lines up with theirs.
                    if (l.who != me)
                      HandyDot(hue(l.who))
                    else
                      const SizedBox(width: 10),
                    const SizedBox(width: HandySpace.s),
                    Expanded(
                      child: Text(
                        who(l.who),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: l.included ? null : c.muted),
                      ),
                    ),
                    if (l.included && draft.method == 'shares') ...[
                      IconButton(
                        tooltip: tr(context, 'One share less', 'Bớt một phần'),
                        onPressed: l.units <= 1
                            ? null
                            : () => setLine(l.copyWith(units: l.units - 1)),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      Text(
                        '${l.units}×',
                        key: Key('split-units-${l.who}'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: tabular,
                        ),
                      ),
                      IconButton(
                        key: Key('split-more-${l.who}'),
                        tooltip: tr(context, 'One share more', 'Thêm một phần'),
                        onPressed: l.units >= 99
                            ? null
                            : () => setLine(l.copyWith(units: l.units + 1)),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                    if (l.included && draft.method == 'exact')
                      SizedBox(
                        width: 132,
                        child: TextField(
                          key: Key('split-amount-${l.who}'),
                          controller: field(l),
                          textAlign: TextAlign.end,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(fontFeatures: tabular),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: currencyUnit(widget.currency),
                          ),
                          onChanged: (_) => setState(() => error = ''),
                        ),
                      )
                    else if (l.included)
                      SizedBox(
                        width: 112,
                        child: Money(
                          scope,
                          shareOf[l.who] ?? BigInt.zero,
                          widget.currency,
                          align: TextAlign.end,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: HandySpace.s),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('split-new-person'),
                controller: name,
                maxLength: 128,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  hintText: tr(context, 'Add a person', 'Thêm người'),
                ),
                onSubmitted: (_) => addPerson(),
              ),
            ),
            const SizedBox(width: HandySpace.s),
            OutlinedButton(
              key: const Key('split-add-person'),
              onPressed: addPerson,
              child: Text(tr(context, 'Add', 'Thêm')),
            ),
          ],
        ),
        const SizedBox(height: HandySpace.m),
        Semantics(
          liveRegion: true,
          child: Text(
            parts != null
                ? tr(
                    context,
                    'Adds up to ${moneyText(context, scope, widget.total, widget.currency)} exactly.',
                    'Cộng lại đúng ${moneyText(context, scope, widget.total, widget.currency)}.',
                  )
                : why,
            key: const Key('split-status'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: parts != null ? c.muted : c.negative,
            ),
          ),
        ),
        if (draft.method != 'exact')
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.xs),
            child: Text(
              tr(
                context,
                'Units left over from rounding go to the first shares, so the parts always add up.',
                'Đồng lẻ còn dư chia cho những phần đầu, không mất đồng nào vì làm tròn.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
          ),
      ],
    );
  }
}
