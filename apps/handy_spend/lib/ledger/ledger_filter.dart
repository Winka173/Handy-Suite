import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart' show foldAccents;

const _keep = Object();

/// What the ledger shows: a period (end excluded) and optional narrowing.
class LedgerFilter {
  final String from, until;
  final String? account, category, kind, status, tag;

  /// Bounds on the size of an amount, in the report currency's minor units.
  final BigInt? min, max;
  final String search;
  const LedgerFilter({
    required this.from,
    required this.until,
    this.account,
    this.category,
    this.kind,
    this.status,
    this.tag,
    this.min,
    this.max,
    this.search = '',
  });

  /// The calendar month holding [date].
  factory LedgerFilter.month(String date) {
    final d = calendar(date);
    return LedgerFilter(
      from: day(DateTime.utc(d.year, d.month, 1)),
      until: day(DateTime.utc(d.year, d.month + 1, 1)),
    );
  }

  bool get isMonth {
    final a = calendar(from);
    return a.day == 1 && until == day(DateTime.utc(a.year, a.month + 1, 1));
  }

  /// The same narrowing over the month [n] months away.
  LedgerFilter shiftMonth(int n) {
    final a = calendar(from);
    final first = DateTime.utc(a.year, a.month + n, 1);
    return copyWith(
      from: day(first),
      until: day(DateTime.utc(first.year, first.month + 1, 1)),
    );
  }

  /// Anything beyond the period is set.
  bool get narrowed =>
      account != null ||
      category != null ||
      kind != null ||
      status != null ||
      tag != null ||
      min != null ||
      max != null ||
      search.trim().isNotEmpty;

  LedgerFilter copyWith({
    String? from,
    String? until,
    Object? account = _keep,
    Object? category = _keep,
    Object? kind = _keep,
    Object? status = _keep,
    Object? tag = _keep,
    Object? min = _keep,
    Object? max = _keep,
    String? search,
  }) => LedgerFilter(
    from: from ?? this.from,
    until: until ?? this.until,
    account: account == _keep ? this.account : account as String?,
    category: category == _keep ? this.category : category as String?,
    kind: kind == _keep ? this.kind : kind as String?,
    status: status == _keep ? this.status : status as String?,
    tag: tag == _keep ? this.tag : tag as String?,
    min: min == _keep ? this.min : min as BigInt?,
    max: max == _keep ? this.max : max as BigInt?,
    search: search ?? this.search,
  );

  LedgerFilter cleared() => LedgerFilter(from: from, until: until);
}

/// The entries the filter keeps, newest first. Amount bounds only match
/// entries in the report currency; currencies are never compared.
List<Entry> applyFilter(SpendState s, LedgerFilter f) {
  final accounts = {for (final a in s.accounts) a.id: a};
  final categories = {for (final c in s.categories) c.id: c};
  final q = foldAccents(f.search.trim());
  final rows = s.entries.where((e) {
    final date = reportDay(e.when, s.zone);
    if (date.compareTo(f.from) < 0 || date.compareTo(f.until) >= 0)
      return false;
    if (f.account != null && e.account != f.account && e.toAccount != f.account)
      return false;
    if (f.category != null &&
        e.category != f.category &&
        categories[e.category]?.parent != f.category)
      return false;
    if (f.kind != null && e.kind != f.kind) return false;
    if (f.status != null && e.status != f.status) return false;
    if (f.tag != null &&
        !e.tags.any((t) => t.toLowerCase() == f.tag!.toLowerCase()))
      return false;
    final sameCurrency = accounts[e.account]?.currency == s.currency;
    if (f.min != null && !(sameCurrency && e.amount.abs() >= f.min!))
      return false;
    if (f.max != null && !(sameCurrency && e.amount.abs() <= f.max!))
      return false;
    if (q.isEmpty) return true;
    final text = foldAccents(
      '${e.payee} ${e.note} ${e.tags.join(' ')} ${accounts[e.account]?.name ?? ''} ${categories[e.category]?.name ?? ''}',
    );
    return text.contains(q);
  }).toList();
  rows.sort((a, b) => b.when.compareTo(a.when));
  return rows;
}
