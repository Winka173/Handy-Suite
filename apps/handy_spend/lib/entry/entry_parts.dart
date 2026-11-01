import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'entry_logic.dart';

/// Spending, income or a move between accounts.
class KindSwitch extends StatelessWidget {
  final String kind;
  final bool canTransfer;
  final ValueChanged<String>? onChanged;
  const KindSwitch({
    super.key,
    required this.kind,
    required this.canTransfer,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SegmentedButton<String>(
    showSelectedIcon: false,
    segments: [
      ButtonSegment(
        value: 'expense',
        label: Text(
          tr(context, 'Spent', 'Chi'),
          key: const Key('kind-expense'),
        ),
      ),
      ButtonSegment(
        value: 'income',
        label: Text(
          tr(context, 'Received', 'Thu'),
          key: const Key('kind-income'),
        ),
      ),
      if (canTransfer)
        ButtonSegment(
          value: 'transfer',
          label: Text(
            tr(context, 'Move', 'Chuyển'),
            key: const Key('kind-transfer'),
          ),
        ),
    ],
    selected: {kind},
    onSelectionChanged: onChanged == null ? null : (v) => onChanged!(v.single),
  );
}

/// The expense a refund gives back to.
class RefundOrigin extends StatelessWidget {
  final SpendScope scope;
  final Entry entry;
  const RefundOrigin({super.key, required this.scope, required this.entry});
  @override
  Widget build(BuildContext context) => HandyNotice(
    tr(
      context,
      'Back from ${entryTitle(context, scope, entry)}, ${moneyText(context, scope, entry.amount, scope.account(entry.account).currency)} on ${dayLabel(context, scope, reportDay(entry.when, scope.state.zone))}',
      'Hoàn lại từ ${entryTitle(context, scope, entry)}, ${moneyText(context, scope, entry.amount, scope.account(entry.account).currency)} ngày ${dayLabel(context, scope, reportDay(entry.when, scope.state.zone))}',
    ),
  );
}

/// The amount, large, typed the local way (`45.000`, `45k`).
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String unit;
  final bool autofocus, signed, enabled;
  final VoidCallback onSubmitted;
  const AmountField({
    super.key,
    required this.controller,
    required this.unit,
    required this.autofocus,
    required this.signed,
    required this.enabled,
    required this.onSubmitted,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = TextField(
      key: const Key('field-amount'),
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: signed,
      ),
      textInputAction: TextInputAction.next,
      style: theme.textTheme.headlineMedium?.copyWith(fontFeatures: tabular),
      decoration: InputDecoration(hintText: '0', suffixText: unit),
      onSubmitted: (_) => onSubmitted(),
    );
    // The label stays above the field once something is typed.
    return HandyField(
      label: tr(context, 'Amount', 'Số tiền'),
      help: signed
          ? tr(
              context,
              'A minus lowers the balance.',
              'Dấu trừ làm giảm số dư.',
            )
          : tr(context, '45.000 or 45k', '45.000 hoặc 45k'),
      child: field,
    );
  }
}

/// Recent categories as chips, the rest one tap away.
class CategoryChips extends StatelessWidget {
  final SpendScope scope;
  final String kind;
  final List<String> recent;
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  const CategoryChips({
    super.key,
    required this.scope,
    required this.kind,
    required this.recent,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final all = scope.state.categories
        .where((c) => c.kind == kind && (!c.archived || c.id == selected))
        .toList();
    final shown = <String>{
      ...recent.where((id) => all.any((c) => c.id == id)),
      if (selected != null && all.any((c) => c.id == selected)) selected!,
    };
    for (final c in all) {
      if (shown.length >= 6) break;
      shown.add(c.id);
    }
    Widget chip(String id) {
      final c = scope.category(id)!;
      return ChoiceChip(
        key: Key('category-$id'),
        avatar: HandyDot(scope.categoryHue(id), size: 10),
        label: Text(c.name),
        selected: selected == id,
        onSelected: enabled ? (v) => onChanged(v ? id : null) : null,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'Category', 'Danh mục'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final id in shown) chip(id),
              if (all.length > shown.length)
                ActionChip(
                  key: const Key('category-more'),
                  label: Text(tr(context, 'More…', 'Khác…')),
                  onPressed: enabled
                      ? () async {
                          final id = await _pick(context, all);
                          if (id != null) onChanged(id.isEmpty ? null : id);
                        }
                      : null,
                ),
              if (all.isEmpty)
                Text(
                  tr(
                    context,
                    'No categories yet. Add them in Settings.',
                    'Chưa có danh mục. Thêm trong Cài đặt.',
                  ),
                  style: TextStyle(color: HandyColors.of(context).muted),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _pick(BuildContext context, List<Category> all) =>
      showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(tr(context, 'Category', 'Danh mục')),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(tr(context, 'No category', 'Không phân loại')),
            ),
            for (final c in all)
              SimpleDialogOption(
                key: Key('pick-category-${c.id}'),
                onPressed: () => Navigator.pop(context, c.id),
                child: Row(
                  children: [
                    if (c.parent != null) const SizedBox(width: HandySpace.l),
                    HandyDot(scope.categoryHue(c.id), size: 10),
                    const SizedBox(width: HandySpace.m),
                    Expanded(child: Text(c.name)),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// Who was paid or who paid, with names used before.
class PayeeField extends StatefulWidget {
  final SpendScope scope;
  final String kind;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const PayeeField({
    super.key,
    required this.scope,
    required this.kind,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });
  @override
  State<PayeeField> createState() => _PayeeFieldState();
}

class _PayeeFieldState extends State<PayeeField> {
  @override
  Widget build(BuildContext context) {
    final names = payeeSuggestions(
      widget.scope.state,
      widget.kind,
      widget.controller.text,
    );
    final label = switch (widget.kind) {
      'expense' => tr(context, 'Paid to', 'Chi cho'),
      'income' => tr(context, 'Received from', 'Nhận từ'),
      _ => tr(context, 'Description', 'Mô tả'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: HandySpace.s),
        TextField(
          key: const Key('field-payee'),
          controller: widget.controller,
          enabled: widget.enabled,
          maxLength: 1024,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(counterText: ''),
          onChanged: (v) {
            setState(() {});
            widget.onChanged(v);
          },
        ),
        if (names.isNotEmpty && widget.enabled)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.s),
            child: Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.xs,
              children: [
                for (final n in names)
                  ActionChip(
                    label: Text(n),
                    onPressed: () {
                      widget.controller.text = n;
                      setState(() {});
                      widget.onChanged(n);
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Which account; opens a short list.
class AccountChip extends StatelessWidget {
  final SpendScope scope;
  final String value;
  final bool enabled;
  final String? prefix;
  final ValueChanged<String> onChanged;
  final Set<String> except;
  const AccountChip({
    super.key,
    required this.scope,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.prefix,
    this.except = const {},
  });
  @override
  Widget build(BuildContext context) {
    final a = scope.state.accounts.where((a) => a.id == value).firstOrNull;
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: tr(context, 'Account', 'Tài khoản'),
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final x in scope.openAccounts.where((x) => !except.contains(x.id)))
          PopupMenuItem(
            key: Key('pick-account-${x.id}'),
            value: x.id,
            child: Row(
              children: [
                HandyDot(scope.accountHue(x.id), size: 10),
                const SizedBox(width: HandySpace.m),
                Flexible(child: Text(x.name, overflow: TextOverflow.ellipsis)),
                if (x.currency != scope.currency)
                  Text(
                    '  ${x.currency}',
                    style: TextStyle(color: HandyColors.of(context).muted),
                  ),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: a == null
            ? const Icon(Icons.account_balance_wallet_outlined, size: 16)
            : HandyDot(scope.accountHue(a.id), size: 10),
        label: Text(
          '${prefix ?? ''}${a?.name ?? tr(context, 'Choose', 'Chọn')}',
        ),
      ),
    );
  }
}

/// From, to, and what crossing currencies costs.
class TransferParts extends StatelessWidget {
  final SpendScope scope;
  final String from;
  final String? to;
  final TextEditingController rate, fee;
  final bool enabled;
  final ValueChanged<String> onFrom, onTo;
  const TransferParts({
    super.key,
    required this.scope,
    required this.from,
    required this.to,
    required this.rate,
    required this.fee,
    required this.enabled,
    required this.onFrom,
    required this.onTo,
  });
  @override
  Widget build(BuildContext context) {
    final a = scope.account(from);
    final b = to == null ? null : scope.account(to!);
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AccountChip(
                key: const Key('transfer-from'),
                scope: scope,
                value: from,
                enabled: enabled,
                prefix: tr(context, 'From ', 'Từ '),
                onChanged: onFrom,
              ),
              const Icon(Icons.arrow_forward, size: 18),
              AccountChip(
                key: const Key('transfer-to'),
                scope: scope,
                value: to ?? '',
                enabled: enabled,
                prefix: tr(context, 'To ', 'Đến '),
                except: {from},
                onChanged: onTo,
              ),
            ],
          ),
          if (b != null && b.currency != a.currency) ...[
            const SizedBox(height: HandySpace.m),
            HandyField(
              label: tr(
                context,
                '${b.currency} for 1 ${a.currency}',
                '${b.currency} cho 1 ${a.currency}',
              ),
              help: tr(
                context,
                'The rate you actually got; nothing is looked up.',
                'Tỷ giá bạn thực nhận; app không tự tra.',
              ),
              child: TextField(
                key: const Key('field-rate'),
                controller: rate,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
          const SizedBox(height: HandySpace.m),
          HandyField(
            label: tr(context, 'Fee, if any', 'Phí, nếu có'),
            child: TextField(
              key: const Key('field-fee'),
              controller: fee,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(suffixText: a.currency),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailFields extends StatelessWidget {
  final TextEditingController note, tags;
  final bool enabled;
  const DetailFields({
    super.key,
    required this.note,
    required this.tags,
    required this.enabled,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: HandySpace.s),
      HandyField(
        label: tr(context, 'Note', 'Ghi chú'),
        child: TextField(
          key: const Key('field-note'),
          controller: note,
          enabled: enabled,
          maxLines: 3,
          minLines: 1,
          maxLength: 8192,
          decoration: const InputDecoration(counterText: ''),
        ),
      ),
      HandyField(
        label: tr(context, 'Tags', 'Nhãn'),
        help: tr(context, 'Separate with commas', 'Cách nhau bằng dấu phẩy'),
        child: TextField(
          key: const Key('field-tags'),
          controller: tags,
          enabled: enabled,
        ),
      ),
    ],
  );
}
