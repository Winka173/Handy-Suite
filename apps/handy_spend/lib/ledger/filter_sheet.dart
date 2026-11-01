import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';
import 'ledger_filter.dart';

/// Every way to narrow the ledger, in one form. Dates are picked.
Future<void> openFilterSheet(
  BuildContext context,
  SpendScope scope,
  LedgerFilter f,
  ValueChanged<LedgerFilter> onFilter,
) async {
  final s = scope.state;
  String all() => tr(context, 'All', 'Tất cả');
  await showSpendForm(
    context,
    scope,
    title: tr(context, 'Show', 'Hiển thị'),
    saveLabel: tr(context, 'Show', 'Hiển thị'),
    fields: [
      const SpendField('from', 'From', 'Từ ngày', kind: FieldKind.date),
      const SpendField('last', 'To', 'Đến hết ngày', kind: FieldKind.date),
      SpendField(
        'account',
        'Account',
        'Tài khoản',
        kind: FieldKind.choice,
        required: false,
        options: {'': all(), for (final a in s.accounts) a.id: a.name},
      ),
      SpendField(
        'category',
        'Category',
        'Danh mục',
        kind: FieldKind.choice,
        required: false,
        options: {'': all(), for (final c in s.categories) c.id: c.name},
      ),
      SpendField(
        'kind',
        'Type',
        'Loại',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': all(),
          for (final k in [
            'expense',
            'income',
            'transfer',
            'refund',
            'adjustment',
          ])
            k: kindLabel(context, k),
        },
      ),
      SpendField(
        'status',
        'Status',
        'Trạng thái',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': all(),
          'posted': tr(context, 'Paid', 'Đã trả'),
          'pending': tr(context, 'Not yet paid', 'Chưa trả thật'),
        },
      ),
      const SpendField('tag', 'Tag', 'Nhãn', required: false),
      SpendField(
        'min',
        'At least',
        'Từ số tiền',
        kind: FieldKind.money,
        required: false,
        currency: (_) => s.currency,
        helpEn: 'Amounts in ${s.currency} only.',
        helpVi: 'Chỉ so số tiền bằng ${s.currency}.',
      ),
      SpendField(
        'max',
        'At most',
        'Đến số tiền',
        kind: FieldKind.money,
        required: false,
        currency: (_) => s.currency,
      ),
    ],
    initial: {
      'from': f.from,
      'last': day(calendar(f.until).subtract(const Duration(days: 1))),
      'account': f.account ?? '',
      'category': f.category ?? '',
      'kind': f.kind ?? '',
      'status': f.status ?? '',
      'tag': f.tag ?? '',
      'min': f.min,
      'max': f.max,
    },
    save: (v) async {
      final until = day(
        calendar(v['last'] as String).add(const Duration(days: 1)),
      );
      if (until.compareTo(v['from'] as String) <= 0)
        throw const FormatException(
          'The end comes before the start / Ngày cuối trước ngày đầu',
        );
      String? text(String k) =>
          (v[k] as String).isEmpty ? null : v[k] as String;
      BigInt? amount(String k) => v[k] == BigInt.zero ? null : v[k] as BigInt?;
      onFilter(
        LedgerFilter(
          from: v['from'] as String,
          until: until,
          account: text('account'),
          category: text('category'),
          kind: text('kind'),
          status: text('status'),
          tag: text('tag'),
          min: amount('min'),
          max: amount('max'),
          search: f.search,
        ),
      );
    },
  );
}

/// The narrowing in force, each one a chip that removes itself.
class FilterChips extends StatelessWidget {
  final SpendScope scope;
  final LedgerFilter filter;
  final ValueChanged<LedgerFilter> onFilter;
  const FilterChips({
    super.key,
    required this.scope,
    required this.filter,
    required this.onFilter,
  });
  @override
  Widget build(BuildContext context) {
    final f = filter;
    final chips = <(String, LedgerFilter)>[
      if (f.account != null)
        (scope.account(f.account!).name, f.copyWith(account: null)),
      if (f.category != null)
        (scope.category(f.category)?.name ?? '', f.copyWith(category: null)),
      if (f.kind != null) (kindLabel(context, f.kind!), f.copyWith(kind: null)),
      if (f.status != null)
        (
          f.status == 'pending'
              ? tr(context, 'Not yet paid', 'Chưa trả thật')
              : tr(context, 'Paid', 'Đã trả'),
          f.copyWith(status: null),
        ),
      if (f.tag != null) ('#${f.tag}', f.copyWith(tag: null)),
      if (f.min != null)
        (
          '≥ ${moneyText(context, scope, f.min!, scope.currency)}',
          f.copyWith(min: null),
        ),
      if (f.max != null)
        (
          '≤ ${moneyText(context, scope, f.max!, scope.currency)}',
          f.copyWith(max: null),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.s),
      child: Wrap(
        spacing: HandySpace.s,
        runSpacing: HandySpace.s,
        children: [
          for (final (label, next) in chips)
            InputChip(
              label: Text(label),
              onDeleted: () => onFilter(next),
              deleteButtonTooltipMessage: tr(context, 'Remove', 'Bỏ'),
            ),
        ],
      ),
    );
  }
}
