import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../money.dart';
import '../scope.dart';
import '../ui/figures.dart';

/// Under "Real balance today": the gap with the ledger as it is typed, and
/// what in the ledger might explain it. Facts only; nothing is changed
/// until Set balance.
class ReconcileExplain extends StatelessWidget {
  final SpendScope scope;
  final Account account;
  final BigInt held;
  final String raw;
  const ReconcileExplain({
    super.key,
    required this.scope,
    required this.account,
    required this.held,
    required this.raw,
  });

  @override
  Widget build(BuildContext context) {
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    BigInt? real;
    try {
      if (raw.trim().isNotEmpty) {
        real = parseAmount(raw.trim(), account.currency, vi: vi);
      }
    } on FormatException {
      real = null;
    }
    if (real == null) return const SizedBox.shrink();
    final gap = real - held;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    String money(BigInt v, {bool sign = false}) =>
        moneyText(context, scope, v, account.currency, sign: sign);
    if (gap == BigInt.zero) {
      return Padding(
        padding: const EdgeInsets.only(top: HandySpace.s),
        child: Text(
          tr(
            context,
            'Matches the ledger. Nothing to adjust.',
            'Khớp với sổ. Không cần điều chỉnh.',
          ),
          key: const Key('reconcile-gap'),
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final hints = reconcileHints(scope.state, account.id, gap, scope.today);
    String line(ReconcileHint h) => switch (h.kind) {
      'pending' => tr(
        context,
        '${h.count} pending, not counted yet: ${money(h.amount, sign: true)}',
        '${h.count} khoản đang chờ, chưa tính vào sổ: ${money(h.amount, sign: true)}',
      ),
      'unpaid' => tr(
        context,
        '${h.count} planned payments due but not marked paid (${h.dates.map((d) => dayLabel(context, scope, d)).join(', ')}): ${money(h.amount, sign: true)}',
        '${h.count} khoản định kỳ đã đến hạn nhưng chưa đánh dấu đã trả (${h.dates.map((d) => dayLabel(context, scope, d)).join(', ')}): ${money(h.amount, sign: true)}',
      ),
      'twice' => () {
        final e = scope.state.entries.firstWhere(
          (x) => x.id == h.entries.first,
        );
        final what = e.payee.isNotEmpty
            ? e.payee
            : tr(context, 'an entry', 'một khoản');
        return tr(
          context,
          '$what on ${dayLabel(context, scope, reportDay(e.when, scope.state.zone))} matches the gap: recorded twice, or the wrong way round?',
          '$what ngày ${dayLabel(context, scope, reportDay(e.when, scope.state.zone))} khớp với chênh lệch: ghi hai lần, hay ghi ngược chiều?',
        );
      }(),
      _ => tr(
        context,
        'Nothing recorded here for ${h.days} days: spending may be missing.',
        '${h.days} ngày chưa ghi gì ở đây: có thể còn khoản chưa ghi.',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.s),
      child: Semantics(
        liveRegion: true,
        child: Column(
          key: const Key('reconcile-explain'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                context,
                'Real is ${money(gap, sign: true)} against the ledger.',
                'Thực tế chênh ${money(gap, sign: true)} so với sổ.',
              ),
              key: const Key('reconcile-gap'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: tabular,
              ),
            ),
            if (hints.isNotEmpty) ...[
              const SizedBox(height: HandySpace.xs),
              Text(
                tr(context, 'Worth checking first:', 'Nên xem trước:'),
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
              for (final h in hints)
                Padding(
                  padding: const EdgeInsets.only(top: HandySpace.xs),
                  child: Text(
                    '· ${line(h)}',
                    key: Key('reconcile-hint-${h.kind}'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
