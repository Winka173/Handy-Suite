import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'money.dart';

/// The fully qualified Android widget class.
const spendWidgetClass = 'com.example.handysuite.spend.HandyWidget';

/// The home-screen widget: today's free-to-spend figure, or a plain
/// "open to see" when the app is locked or hides amounts, since the home
/// screen is not behind the lock.
HomeWidgetView spendWidgetView(
  SpendState s,
  SafeSpend safe, {
  required bool vi,
}) {
  final title = vi ? 'Handy Spend · Hôm nay' : 'Handy Spend · Today';
  if (s.settings['deviceLock'] == true || s.settings['hideAmounts'] == true)
    return HomeWidgetView(
      title: title,
      value: vi ? 'Mở để xem' : 'Open to see',
      detail: vi ? 'Số tiền đang được ẩn' : 'Amounts are hidden',
      uri: 'handy-spend://today',
    );
  if (s.accounts.isEmpty)
    return HomeWidgetView(
      title: title,
      value: vi ? 'Chưa có tài khoản' : 'No accounts yet',
      detail: vi ? 'Chạm để bắt đầu' : 'Tap to start',
      uri: 'handy-spend://today',
    );
  String money(BigInt v) {
    final raw = decimalMoney(v.abs(), s.currency);
    final dot = raw.indexOf('.');
    final whole = dot < 0 ? raw : raw.substring(0, dot);
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => vi ? '.' : ',',
    );
    final frac = dot < 0 ? '' : '${vi ? ',' : '.'}${raw.substring(dot + 1)}';
    return '${v.isNegative ? '−' : ''}$grouped$frac ${currencyUnit(s.currency)}';
  }

  if (safe.shortfall > BigInt.zero)
    return HomeWidgetView(
      title: title,
      value: money(-safe.shortfall),
      detail: vi ? 'Đang thiếu · xem kế hoạch' : 'Short · see the plan',
      uri: 'handy-spend://today',
    );
  return HomeWidgetView(
    title: vi ? 'Còn tiêu được' : 'Free to spend',
    value: money(safe.available),
    detail: vi
        ? '${money(safe.perDay)} mỗi ngày · ${safe.days} ngày'
        : '${money(safe.perDay)} a day · ${safe.days} days',
    uri: 'handy-spend://today',
  );
}
