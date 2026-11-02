part of '../handy_spend_engine.dart';

/// The counterparty as history compares it: lower case, digits and
/// punctuation dropped (so "Lương tháng 9" and "Lương tháng 10" match and
/// a statement's reference numbers do not split one payee), spaces folded.
String counterparty(String payee) => payee
    .toLowerCase()
    .replaceAll(RegExp(r'[0-9]'), ' ')
    .replaceAll(RegExp(r'''[!-/:-@\[-`{-~]'''), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Something in the history that looks like it repeats.
class RecurringSuggestion {
  /// Stable while the pattern lasts; a dismissed key stays dismissed.
  final String key, name, account, kind, frequency, due, last;
  final String? category;

  /// The typical amount, signed as the entries were (median of the run).
  final BigInt amount;
  final int count;

  /// True when the amounts were not all the same (within the tolerance).
  final bool varies;
  const RecurringSuggestion({
    required this.key,
    required this.name,
    required this.account,
    required this.kind,
    required this.frequency,
    required this.due,
    required this.last,
    required this.amount,
    required this.count,
    required this.varies,
    this.category,
  });

  /// The recurring item it would become once the person confirms it.
  Bill bill({String? id}) => Bill(
    id: id ?? newId(),
    name: name,
    account: account,
    amount: amount,
    due: due,
    frequency: frequency,
    category: category,
  );
}

DateTime _addMonths(DateTime d, int months, int dayOfMonth) {
  final m = DateTime.utc(d.year, d.month + months, 1);
  return DateTime.utc(
    m.year,
    m.month,
    min(dayOfMonth, DateTime.utc(m.year, m.month + 1, 0).day),
  );
}

/// Suggests recurring items from posted expenses and income: the same
/// counterparty on the same account, at least three times in a row a week
/// (6–8 days) or a month (26–35 days) apart, every amount within 10 % of
/// the run's median, and the latest one recent (45 days for monthly, 11
/// for weekly). Entries made from a recurring item are skipped, and so is
/// a counterparty an existing recurring item on that account already names.
List<RecurringSuggestion> recurringSuggestions(SpendState s, String today) {
  final now = calendar(today);
  final dismissed = Set<String>.from(
    s.settings['dismissedRecurring'] as List? ?? const [],
  );
  final groups = <String, List<(DateTime, Entry)>>{};
  for (final e in s.entries) {
    if (e.status != 'posted' ||
        e.occurrence != null ||
        e.settles != null ||
        !{'expense', 'income'}.contains(e.kind))
      continue;
    final name = counterparty(e.payee);
    if (name.isEmpty) continue;
    final d = calendar(reportDay(e.when, s.zone));
    if (d.isAfter(now) || now.difference(d).inDays > 400) continue;
    groups.putIfAbsent('${e.account}|$name|${e.kind}', () => []).add((d, e));
  }
  bool known(String account, String name) => s.bills.any((b) {
    final n = counterparty(b.name);
    return b.account == account &&
        n.isNotEmpty &&
        (name.contains(n) || n.contains(name));
  });
  final out = <RecurringSuggestion>[];
  for (final g in groups.entries) {
    final rows = g.value..sort((a, b) => a.$1.compareTo(b.$1));
    final first = rows.last.$2, name = counterparty(first.payee);
    if (rows.length < 3 || known(first.account, name)) continue;
    for (final (frequency, lo, hi, fresh) in const [
      ('monthly', 26, 35, 45),
      ('weekly', 6, 8, 11),
    ]) {
      final run = [rows.last];
      for (var i = rows.length - 2; i >= 0; i--) {
        final gap = run.last.$1.difference(rows[i].$1).inDays;
        if (gap < lo || gap > hi) break;
        run.add(rows[i]);
      }
      if (run.length < 3 || now.difference(run.first.$1).inDays > fresh)
        continue;
      final sorted = [for (final r in run) r.$2.amount]
        ..sort((a, b) => a.compareTo(b));
      final median = sorted[sorted.length ~/ 2];
      if (sorted.any(
        (a) => (a - median).abs() * BigInt.from(10) > median.abs(),
      ))
        continue;
      final key = '${g.key}|$frequency';
      if (dismissed.contains(key)) break;
      final latest = run.first.$1;
      var due = frequency == 'weekly'
          ? latest.add(const Duration(days: 7))
          : _addMonths(latest, 1, latest.day);
      for (var n = 2; due.isBefore(now) && n < 60; n++) {
        due = frequency == 'weekly'
            ? latest.add(Duration(days: 7 * n))
            : _addMonths(latest, n, latest.day);
      }
      out.add(
        RecurringSuggestion(
          key: key,
          name: first.payee.trim(),
          account: first.account,
          kind: first.kind,
          frequency: frequency,
          due: day(due),
          last: day(latest),
          amount: median,
          count: run.length,
          varies: sorted.first != sorted.last,
          category: first.category,
        ),
      );
      break;
    }
  }
  out.sort((a, b) => a.due.compareTo(b.due));
  return out;
}

/// [s] with [key] remembered as dismissed.
SpendState dismissSuggestion(SpendState s, String key) => s.copy({
  'settings': {
    ...s.settings,
    'dismissedRecurring': {
      ...List<String>.from(s.settings['dismissedRecurring'] as List? ?? []),
      key,
    }.toList(),
  },
});
