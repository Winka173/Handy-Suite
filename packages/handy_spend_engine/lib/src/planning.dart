part of '../handy_spend_engine.dart';

String financialFingerprint(SpendState s) => sha256
    .convert(
      utf8.encode(
        jsonEncode({
          'accounts': s.accounts.map((a) => a.toJson()).toList(),
          'entries': s.entries.map((e) => e.toJson()).toList(),
          'categories': s.categories.map((c) => c.toJson()).toList(),
          'budgets': s.budgets.map((b) => b.toJson()).toList(),
          'bills': s.bills.map((b) => b.toJson()).toList(),
          'goals': s.goals.map((g) => g.toJson()).toList(),
          'currency': s.currency,
          'zone': s.zone,
          'buffer': s.settings['buffer'] ?? '0',
          'eligibleAccounts': s.settings['eligibleAccounts'],
        }),
      ),
    )
    .toString();

Map<String, BigInt> balances(SpendState s, String asOf) {
  calendar(asOf);
  final result = {
    for (final a in s.accounts)
      a.id: a.asOf.compareTo(asOf) <= 0 ? a.opening : BigInt.zero,
  };
  for (final e in s.entries) {
    if (e.status != 'posted' || reportDay(e.when, s.zone).compareTo(asOf) > 0)
      continue;
    result[e.account] = result[e.account]! + e.amount - e.fee;
    if (e.toAccount != null)
      result[e.toAccount!] = result[e.toAccount!]! + e.target!;
  }
  return result;
}

class Occurrence {
  final Bill bill;
  final String date;
  const Occurrence(this.bill, this.date);
  String get id => '${bill.id}@$date';
  Entry post(String zone, {String? when}) => Entry(
    id: newId(),
    account: bill.account,
    kind: bill.toAccount != null
        ? 'transfer'
        : bill.amount.isNegative
        ? 'expense'
        : 'income',
    amount: bill.amount,
    when: when ?? localTimestamp(date, zone),
    payee: bill.name,
    category: bill.category,
    toAccount: bill.toAccount,
    target: bill.target,
    rate: bill.rate,
    occurrence: id,
  );
}

List<Occurrence> upcoming(SpendState s, String start, String end) {
  final first = calendar(start), last = calendar(end);
  if (last.difference(first).inDays > 3660 || last.isBefore(first))
    throw const FormatException('Forecast horizon 0..3660 days');
  final paid = s.entries
          .where((e) => e.occurrence != null)
          .map((e) => e.occurrence)
          .toSet(),
      result = <Occurrence>[];
  for (final b in s.bills.where((b) => b.enabled)) {
    final anchor = calendar(b.due);
    final earliest = first.subtract(const Duration(days: 366));
    var initial = 0;
    if (b.frequency == 'weekly')
      initial = max(0, earliest.difference(anchor).inDays ~/ 7 - 1);
    if (b.frequency == 'monthly')
      initial = max(
        0,
        (earliest.year - anchor.year) * 12 + earliest.month - anchor.month - 1,
      );
    if (b.frequency == 'yearly')
      initial = max(0, earliest.year - anchor.year - 1);
    for (var n = initial, step = 0; step < 24000; n++, step++) {
      DateTime d;
      if (b.frequency == 'once') {
        if (n > 0) break;
        d = anchor;
      } else if (b.frequency == 'weekly') {
        d = anchor.add(Duration(days: 7 * n));
      } else {
        final months = b.frequency == 'yearly' ? 12 * n : n,
            m = DateTime.utc(anchor.year, anchor.month + months, 1);
        d = DateTime.utc(
          m.year,
          m.month,
          min(anchor.day, DateTime.utc(m.year, m.month + 1, 0).day),
        );
      }
      if (d.isAfter(last)) break;
      if (d.isBefore(first.subtract(const Duration(days: 366)))) continue;
      final o = Occurrence(b, day(d));
      if (!paid.contains(o.id)) result.add(o);
    }
  }
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

BigInt _flow(SpendState s, Entry e, Set<String> ids, String currency) {
  final ac = {for (final a in s.accounts) a.id: a};
  var result = BigInt.zero;
  if (ids.contains(e.account) && ac[e.account]!.currency == currency)
    result += e.amount - e.fee;
  if (e.toAccount != null &&
      ids.contains(e.toAccount) &&
      ac[e.toAccount]!.currency == currency)
    result += e.target!;
  return result;
}

class DailyPoint {
  final String date;
  final BigInt balance, inflow, outflow;
  const DailyPoint(this.date, this.balance, this.inflow, this.outflow);
}

class Projection {
  final List<DailyPoint> points;
  final BigInt opening;
  Projection(this.points, this.opening);
  BigInt get ending => points.isEmpty ? opening : points.last.balance;
  BigInt get lowest =>
      points.fold(opening, (n, p) => p.balance < n ? p.balance : n);
  String? get shortfall =>
      points.where((p) => p.balance < BigInt.zero).firstOrNull?.date;
}

Set<String> eligible(SpendState s, String currency) {
  final configured = s.settings['eligibleAccounts'] as List?;
  return s.accounts
      .where(
        (a) =>
            a.currency == currency &&
            !a.archived &&
            !a.liability &&
            (configured != null
                ? configured.contains(a.id)
                : a.liquid && !{'savings', 'other'}.contains(a.type)),
      )
      .map((a) => a.id)
      .toSet();
}

Projection forecast(
  SpendState s,
  String start,
  String end, {
  Set<String>? accounts,
  String? currency,
  bool includeIncome = false,
  List<Entry> staged = const [],
  Set<String> skipBills = const {},
}) {
  final c = currency ?? s.currency,
      ids = accounts ?? eligible(s, c),
      first = calendar(start),
      last = calendar(end);
  if (last.isBefore(first) || last.difference(first).inDays > 3660)
    throw const FormatException('Invalid forecast horizon');
  final funds = balances(s, start),
      opening = ids.fold(
        BigInt.zero,
        (BigInt n, id) =>
            n +
            (s.accounts.any((a) => a.id == id && a.currency == c)
                ? (funds[id] ?? BigInt.zero)
                : BigInt.zero),
      );
  final changes = <String, List<BigInt>>{};
  void add(String date, BigInt amount) {
    if (date.compareTo(end) > 0) return;
    final d = date.compareTo(start) < 0 ? start : date,
        v = changes.putIfAbsent(d, () => [BigInt.zero, BigInt.zero]);
    amount.isNegative ? v[1] -= amount : v[0] += amount;
  }

  for (final o in upcoming(s, start, end)) {
    if (skipBills.contains(o.bill.id) ||
        o.bill.amount > BigInt.zero && !(includeIncome && o.bill.reliable))
      continue;
    final flow = _flow(s, o.post(s.zone), ids, c);
    if (flow > BigInt.zero && !(includeIncome && o.bill.reliable)) continue;
    add(o.date, flow);
  }
  for (final e in s.entries.where(
    (e) =>
        e.status == 'pending' || reportDay(e.when, s.zone).compareTo(start) > 0,
  )) {
    final d = reportDay(e.when, s.zone);
    if (d.compareTo(start) > 0 || e.status == 'pending') {
      final f = _flow(s, e, ids, c);
      if (f.isNegative || includeIncome) add(d, f);
    }
  }
  for (final e in staged) {
    add(reportDay(e.when, s.zone), _flow(s, e, ids, c));
  }
  var running = opening;
  final points = <DailyPoint>[];
  for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
    final date = day(d), v = changes[date] ?? [BigInt.zero, BigInt.zero];
    running += v[0] - v[1];
    points.add(DailyPoint(date, running, v[0], v[1]));
  }
  return Projection(List.unmodifiable(points), opening);
}

class SafeSpend {
  final BigInt liquid, income, committed, reserves, buffer, available, perDay;
  final int days;
  const SafeSpend(
    this.liquid,
    this.income,
    this.committed,
    this.reserves,
    this.buffer,
    this.available,
    this.perDay,
    this.days,
  );
  BigInt get shortfall => available.isNegative ? -available : BigInt.zero;
}

SafeSpend safeToSpend(
  SpendState s,
  String start,
  String end, {
  Set<String>? accounts,
  bool conservative = true,
  BigInt? buffer,
  List<Entry> staged = const [],
  Set<String> skipBills = const {},
}) {
  final ids = accounts ?? eligible(s, s.currency),
      p = forecast(
        s,
        start,
        end,
        accounts: ids,
        includeIncome: !conservative,
        staged: staged,
        skipBills: skipBills,
      );
  final income = p.points.fold(BigInt.zero, (BigInt n, p) => n + p.inflow),
      out = p.points.fold(BigInt.zero, (BigInt n, p) => n + p.outflow),
      reserve = s.goals
          .where(
            (g) =>
                ids.contains(g.account) &&
                s.accounts.any(
                  (a) => a.id == g.account && a.currency == s.currency,
                ),
          )
          .fold(BigInt.zero, (BigInt n, g) => n + g.reserved),
      floor = buffer ?? _big(s.settings['buffer'] ?? '0');
  if (floor < BigInt.zero) throw const FormatException('Negative cash buffer');
  final available = p.opening + income - out - reserve - floor,
      days = p.points.length;
  return SafeSpend(
    p.opening,
    income,
    out,
    reserve,
    floor,
    available,
    available.isNegative ? BigInt.zero : available ~/ BigInt.from(days),
    days,
  );
}

Map<String, BigInt> report(
  SpendState s,
  String start,
  String end, {
  String? currency,
  String? account,
  String? category,
}) {
  calendar(start);
  calendar(end);
  final c = currency ?? s.currency,
      ac = {for (final a in s.accounts) a.id: a},
      result = <String, BigInt>{
        'income': BigInt.zero,
        'expense': BigInt.zero,
        'adjustment': BigInt.zero,
      };
  for (final e in s.entries) {
    final d = reportDay(e.when, s.zone);
    if (e.status != 'posted' ||
        d.compareTo(start) < 0 ||
        d.compareTo(end) >= 0 ||
        ac[e.account]?.currency != c ||
        account != null && e.account != account ||
        category != null && e.category != category)
      continue;
    if (e.kind == 'income') result['income'] = result['income']! + e.amount;
    if (e.kind == 'expense' || e.kind == 'refund') {
      result['expense'] = result['expense']! - e.amount;
      final key = 'category:${e.category ?? 'uncategorized'}';
      result[key] = (result[key] ?? BigInt.zero) - e.amount;
    }
    if (e.kind == 'transfer') result['expense'] = result['expense']! + e.fee;
    if (e.kind == 'adjustment')
      result['adjustment'] = result['adjustment']! + e.amount;
    for (final id in [e.account, if (e.toAccount != null) e.toAccount!]) {
      final key = 'account:$id';
      if (ac[id]!.currency == c)
        result[key] =
            (result[key] ?? BigInt.zero) +
            (id == e.account ? e.amount - e.fee : e.target!);
    }
  }
  return result;
}

BigInt budgetRemaining(SpendState s, Budget b) {
  final spent = report(
    s,
    b.start,
    b.end,
    currency: b.currency,
    account: b.account,
    category: b.category,
  )['expense']!;
  var allowance = b.limit;
  if (b.rollover) {
    final length = calendar(b.end).difference(calendar(b.start)).inDays,
        prev = day(calendar(b.start).subtract(Duration(days: length))),
        unused =
            b.limit -
            report(
              s,
              prev,
              b.start,
              currency: b.currency,
              account: b.account,
              category: b.category,
            )['expense']!;
    if (unused > BigInt.zero) allowance += unused;
  }
  return allowance - spent;
}

List<Entry> purchasePlan({
  required String account,
  required BigInt cost,
  required String date,
  required String zone,
  int installments = 1,
  String? category,
}) {
  if (cost <= BigInt.zero || installments < 1 || installments > 120)
    throw const FormatException('Invalid purchase');
  final anchor = calendar(date),
      each = cost ~/ BigInt.from(installments),
      remainder = cost % BigInt.from(installments),
      entries = <Entry>[];
  for (var i = 0; i < installments; i++) {
    final m = DateTime.utc(anchor.year, anchor.month + i, 1),
        d = day(
          DateTime.utc(
            m.year,
            m.month,
            min(anchor.day, DateTime.utc(m.year, m.month + 1, 0).day),
          ),
        ),
        amount = each + (BigInt.from(i) < remainder ? BigInt.one : BigInt.zero);
    if (amount == BigInt.zero) continue;
    entries.add(
      Entry(
        id: newId(),
        account: account,
        kind: 'expense',
        amount: -amount,
        when: localTimestamp(d, zone),
        category: category,
        payee: 'Purchase simulation',
        status: 'pending',
      ),
    );
  }
  return List.unmodifiable(entries);
}
