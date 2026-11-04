part of '../handy_spend_engine.dart';

/// One likely reason the real balance differs from the ledger. [amount] is
/// what it would change in the ledger's balance if it explained the gap;
/// [entries] and [dates] say which entries or bill days it is about.
class ReconcileHint {
  /// pending (not yet counted), unpaid (a planned payment not marked
  /// paid), twice (one entry equal to the gap: recorded twice, or the
  /// wrong way round), quiet (nothing recorded for many days).
  final String kind;
  final BigInt amount;
  final int count, days;
  final List<String> entries, dates;
  ReconcileHint(
    this.kind, {
    BigInt? amount,
    this.count = 0,
    this.days = 0,
    this.entries = const [],
    this.dates = const [],
  }) : amount = amount ?? BigInt.zero;
}

/// Why [account] may be [gap] away from the real balance on [today] (gap is
/// real minus ledger). Only facts from the ledger, most likely first;
/// nothing is changed.
List<ReconcileHint> reconcileHints(
  SpendState s,
  String account,
  BigInt gap,
  String today,
) {
  if (gap == BigInt.zero) return const [];
  final out = <ReconcileHint>[];
  final mine = [
    for (final e in s.entries)
      if (e.account == account || e.toAccount == account) e,
  ];
  BigInt effect(Entry e) =>
      e.account == account ? e.amount - e.fee : (e.target ?? BigInt.zero);

  // Pending entries are not in the balance yet.
  final pending = [
    for (final e in mine)
      if (e.status == 'pending') e,
  ];
  if (pending.isNotEmpty) {
    out.add(
      ReconcileHint(
        'pending',
        amount: pending.fold<BigInt>(BigInt.zero, (n, e) => n + effect(e)),
        count: pending.length,
        entries: [for (final e in pending) e.id],
      ),
    );
  }

  // Planned payments from this account that came due and were not marked.
  final from = day(calendar(today).subtract(const Duration(days: 62)));
  final yesterday = day(calendar(today).subtract(const Duration(days: 1)));
  if (from.compareTo(yesterday) <= 0) {
    final unpaid = [
      for (final o in upcoming(s, from, yesterday))
        if (o.bill.account == account) o,
    ];
    if (unpaid.isNotEmpty) {
      out.add(
        ReconcileHint(
          'unpaid',
          amount: unpaid.fold<BigInt>(
            BigInt.zero,
            (n, o) => n + o.post(s.zone).amount,
          ),
          count: unpaid.length,
          dates: [for (final o in unpaid) o.date],
        ),
      );
    }
  }

  // An entry of exactly the gap, recently: recorded twice (the gap is its
  // opposite) or the wrong way round (the gap is twice it).
  final since = day(calendar(today).subtract(const Duration(days: 45)));
  final same = [
    for (final e in mine)
      if (e.status == 'posted' &&
          e.kind != 'adjustment' &&
          reportDay(e.when, s.zone).compareTo(since) >= 0 &&
          (effect(e) == -gap || effect(e) * BigInt.two == -gap))
        e,
  ]..sort((a, b) => b.when.compareTo(a.when));
  if (same.isNotEmpty) {
    out.add(
      ReconcileHint(
        'twice',
        amount: -effect(same.first),
        count: same.length,
        entries: [for (final e in same.take(3)) e.id],
      ),
    );
  }

  // A long silence: spending that was never written down.
  final posted = [
    for (final e in mine)
      if (e.status == 'posted') reportDay(e.when, s.zone),
  ]..sort();
  final last = posted.isEmpty ? null : posted.last;
  if (last != null) {
    final quiet = calendar(today).difference(calendar(last)).inDays;
    if (quiet >= 14) out.add(ReconcileHint('quiet', days: quiet));
  }
  return out;
}
