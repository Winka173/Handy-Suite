part of '../handy_spend_engine.dart';

/// Something recorded the same way again and again ("cà phê 45k from cash
/// in Food"), found from the entries rather than kept as a list the person
/// has to maintain. [count] is how often it happened in the window.
class UsualEntry {
  final String kind, account, payee;
  final String? category;
  final BigInt amount;
  final int count;
  final String last;
  const UsualEntry({
    required this.kind,
    required this.account,
    required this.payee,
    required this.category,
    required this.amount,
    required this.count,
    required this.last,
  });
}

/// The plain expenses and incomes recorded at least [least] times with the
/// same account, payee, category and amount in the [days] before [today]
/// (four weeks, so a monthly bill paid twice is not taken for a habit),
/// most frequent first, then most recent. Bill payments, imports, splits,
/// refunds, pending entries and archived accounts are left out: those are
/// repeated by their own features, not by hand.
List<UsualEntry> usualEntries(
  SpendState s, {
  required String today,
  int days = 28,
  int least = 2,
  int limit = 4,
}) {
  final from = day(calendar(today).subtract(Duration(days: days)));
  // Entries before local midnight of [from] are skipped without a zone lookup.
  final since = localTimestamp(from, s.zone);
  final open = {
    for (final a in s.accounts)
      if (!a.archived) a.id,
  };
  final groups = <String, List<Entry>>{};
  for (final e in s.entries) {
    if (e.kind != 'expense' && e.kind != 'income') continue;
    if (e.when.compareTo(since) < 0) continue;
    if (e.status != 'posted' || !open.contains(e.account)) continue;
    if (e.occurrence != null ||
        e.batch != null ||
        e.refundOf != null ||
        e.settles != null ||
        e.person != null)
      continue;
    final date = reportDay(e.when, s.zone);
    if (date.compareTo(from) < 0 || date.compareTo(today) > 0) continue;
    final payee = e.payee.trim();
    if (payee.isEmpty && e.category == null) continue;
    final key = [
      e.kind,
      e.account,
      payee.toLowerCase(),
      e.category ?? '',
      e.amount,
    ].join('\u0000');
    (groups[key] ??= []).add(e);
  }
  final usual =
      [
        for (final g in groups.values)
          if (g.length >= least)
            () {
              final latest = g.reduce(
                (a, b) => a.when.compareTo(b.when) >= 0 ? a : b,
              );
              return UsualEntry(
                kind: latest.kind,
                account: latest.account,
                payee: latest.payee.trim(),
                category: latest.category,
                amount: latest.amount.abs(),
                count: g.length,
                last: latest.when,
              );
            }(),
      ]..sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : b.last.compareTo(a.last);
      });
  return usual.take(limit).toList();
}
