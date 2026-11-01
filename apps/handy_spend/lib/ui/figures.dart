import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../money.dart';
import '../scope.dart';

/// An amount for reading: grouped, a true minus, an optional plus, the
/// unit after it. Hidden amounts read as dots everywhere.
String moneyText(
  BuildContext context,
  SpendScope scope,
  BigInt value,
  String currency, {
  bool sign = false,
  bool unit = true,
}) {
  if (scope.hidden) return '••••';
  final figure = formatFigure(context, decimalMoney(value.abs(), currency));
  final prefix = value.isNegative
      ? '−'
      : sign && value > BigInt.zero
      ? '+'
      : '';
  return '$prefix$figure${unit ? ' ${currencyUnit(currency)}' : ''}';
}

/// A figure in tabular digits with its unit smaller and grey after it.
class Money extends StatelessWidget {
  final SpendScope scope;
  final BigInt value;
  final String currency;
  final TextStyle? style;
  final bool sign;

  /// Income reads positive (green with its plus); everything else is ink.
  final bool income;
  final TextAlign? align;
  const Money(
    this.scope,
    this.value,
    this.currency, {
    super.key,
    this.style,
    this.sign = false,
    this.income = false,
    this.align,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final base = (style ?? Theme.of(context).textTheme.bodyLarge)!.copyWith(
      fontFeatures: tabular,
      color: income && value > BigInt.zero ? c.positive : null,
    );
    final size = base.fontSize ?? 16;
    final text = moneyText(
      context,
      scope,
      value,
      currency,
      sign: sign,
      unit: false,
    );
    return Semantics(
      label: moneyText(context, scope, value, currency, sign: sign),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: text, style: base),
            if (!scope.hidden)
              TextSpan(
                text: ' ${currencyUnit(currency)}',
                style: base.copyWith(
                  fontSize: size * (size > 20 ? .55 : .85),
                  color: c.muted,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A calendar day as the person chose to read it.
String dayLabel(BuildContext context, SpendScope scope, String iso) =>
    scope.state.settings['dateFormat'] == 'iso' ? iso : formatDay(context, iso);

/// "Today", "in 3 days", "2 days ago", or the date past a week either way.
String whenLabel(BuildContext context, SpendScope scope, String iso) {
  final days = calendar(iso).difference(calendar(scope.today)).inDays;
  if (days.abs() <= 7) {
    final words = relativeDays(context, days);
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
  return dayLabel(context, scope, iso);
}

String kindLabel(BuildContext context, String kind) => switch (kind) {
  'income' => tr(context, 'Income', 'Thu'),
  'transfer' => tr(context, 'Transfer', 'Chuyển khoản'),
  'refund' => tr(context, 'Refund', 'Hoàn tiền'),
  'adjustment' => tr(context, 'Adjustment', 'Điều chỉnh'),
  _ => tr(context, 'Expense', 'Chi'),
};

String accountTypeLabel(BuildContext context, String type) => switch (type) {
  'cash' => tr(context, 'Cash', 'Tiền mặt'),
  'bank' => tr(context, 'Bank', 'Ngân hàng'),
  'wallet' => tr(context, 'E-wallet', 'Ví điện tử'),
  'savings' => tr(context, 'Savings', 'Tiết kiệm'),
  'credit' => tr(context, 'Credit card', 'Thẻ tín dụng'),
  'loan' => tr(context, 'Loan', 'Khoản vay'),
  _ => tr(context, 'Other', 'Khác'),
};

String frequencyLabel(BuildContext context, String f) => switch (f) {
  'weekly' => tr(context, 'Weekly', 'Hàng tuần'),
  'monthly' => tr(context, 'Monthly', 'Hàng tháng'),
  'yearly' => tr(context, 'Yearly', 'Hàng năm'),
  _ => tr(context, 'Once', 'Một lần'),
};

/// What a row is called: its payee, else its category, else its kind.
String entryTitle(BuildContext context, SpendScope scope, Entry e) {
  if (e.payee.isNotEmpty) return e.payee;
  if (e.kind == 'transfer' && e.toAccount != null)
    return tr(
      context,
      'To ${scope.account(e.toAccount!).name}',
      'Sang ${scope.account(e.toAccount!).name}',
    );
  return scope.category(e.category)?.name ?? kindLabel(context, e.kind);
}

/// A flat grey bar where a figure will be, at the figure's size.
class FigurePlaceholder extends StatelessWidget {
  final double width, height;
  const FigurePlaceholder({super.key, this.width = 120, this.height = 24});
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: HandyColors.of(context).raised,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
