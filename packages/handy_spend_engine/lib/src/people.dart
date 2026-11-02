part of '../handy_spend_engine.dart';

/// Someone you share costs with. Only a name, kept on this device.
class Person {
  final String id, name;
  final bool archived;
  Person({required this.id, required this.name, this.archived = false}) {
    if (id.isEmpty || id == me || name.trim().isEmpty || name.length > 128)
      throw const FormatException('Invalid person');
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'archived': archived,
  };
  factory Person.fromJson(Map<String, dynamic> j) => Person(
    id: _text(j['id']),
    name: _text(j['name']),
    archived: j['archived'] == true,
  );
}

/// The ledger's owner inside a split.
const me = 'me';

/// One person's share of a split: [units] for an equal or shared split,
/// [amount] in minor units in every case.
class SplitPart {
  final String who;
  final BigInt amount;
  final int units;
  SplitPart(this.who, this.amount, {this.units = 1}) {
    if (who.isEmpty || amount.isNegative || units < 0 || units > 1000)
      throw const FormatException('Invalid split share');
  }
  Map<String, dynamic> toJson() => {
    'who': who,
    'amount': '$amount',
    'units': units,
  };
  factory SplitPart.fromJson(Map<String, dynamic> j) => SplitPart(
    _text(j['who']),
    _big(j['amount']),
    units: j['units'] as int? ?? 1,
  );
}

/// Divides [total] by [units] exactly: each share is rounded down, then
/// the minor units left over go one each to the largest remainders, the
/// earlier share first on a tie. The shares always add up to [total].
List<BigInt> allocate(BigInt total, List<int> units) {
  final sum = units.fold(0, (int n, u) => n + u);
  if (total.isNegative || units.isEmpty || units.any((u) => u < 0) || sum == 0)
    throw const FormatException(
      'Give at least one person a share / Chia cho ít nhất một người',
    );
  final d = BigInt.from(sum),
      shares = [for (final u in units) total * BigInt.from(u) ~/ d],
      rest = [for (final u in units) total * BigInt.from(u) % d];
  var left = total - shares.fold(BigInt.zero, (BigInt n, v) => n + v);
  final order = List.generate(units.length, (i) => i)
    ..sort((a, b) {
      final c = rest[b].compareTo(rest[a]);
      return c != 0 ? c : a.compareTo(b);
    });
  for (final i in order) {
    if (left == BigInt.zero) break;
    if (units[i] == 0) continue;
    shares[i] += BigInt.one;
    left -= BigInt.one;
  }
  return shares;
}

/// A cost shared between you and other people. When you paid, [entry] is
/// your expense for the whole [total]; when someone else paid, [payer] is
/// that person and there is no ledger entry until you pay them back.
class CostSplit {
  final String id, payer, currency, date, name, method;
  final String? entry, category;
  final BigInt total;
  final List<SplitPart> parts;
  CostSplit({
    required this.id,
    required this.payer,
    required this.currency,
    required this.date,
    required this.name,
    required this.method,
    required this.total,
    required List<SplitPart> parts,
    this.entry,
    this.category,
  }) : parts = List.unmodifiable(parts) {
    scale(currency);
    calendar(date);
    if (id.isEmpty ||
        name.length > 512 ||
        total <= BigInt.zero ||
        !{'equal', 'shares', 'exact'}.contains(method) ||
        this.parts.isEmpty ||
        this.parts.length > 50 ||
        this.parts.map((p) => p.who).toSet().length != this.parts.length)
      throw const FormatException('Invalid split');
    if (this.parts.fold(BigInt.zero, (BigInt n, p) => n + p.amount) != total)
      throw const FormatException(
        'The shares must add up to the total / Các phần phải cộng đúng bằng tổng',
      );
    if (method != 'exact') {
      final expected = allocate(total, [for (final p in this.parts) p.units]);
      for (var i = 0; i < expected.length; i++) {
        if (expected[i] != this.parts[i].amount)
          throw const FormatException(
            'CostSplit shares do not match their units',
          );
      }
    }
    if (!this.parts.any((p) => p.who != payer && p.amount > BigInt.zero))
      throw const FormatException(
        'Nobody else has a share / Không ai khác có phần',
      );
    if ((payer == me) != (entry != null))
      throw const FormatException('CostSplit payer and entry disagree');
  }

  BigInt share(String who) =>
      parts.where((p) => p.who == who).firstOrNull?.amount ?? BigInt.zero;

  Map<String, dynamic> toJson() => {
    'id': id,
    'payer': payer,
    'currency': currency,
    'date': date,
    'name': name,
    'method': method,
    'total': '$total',
    'parts': parts.map((p) => p.toJson()).toList(),
    'entry': entry,
    'category': category,
  };
  factory CostSplit.fromJson(Map<String, dynamic> j) => CostSplit(
    id: _text(j['id']),
    payer: _text(j['payer']),
    currency: _text(j['currency']),
    date: _text(j['date']),
    name: _text(j['name']),
    method: _text(j['method']),
    total: _big(j['total']),
    parts: _list(j['parts'], SplitPart.fromJson),
    entry: j['entry'] as String?,
    category: j['category'] as String?,
  );
}

/// Builds a split's shares for [method]: units per person for an equal
/// (all 1) or shared split, exact amounts otherwise.
List<SplitPart> splitParts(
  BigInt total,
  String method,
  List<(String who, int units, BigInt? amount)> people,
) {
  if (method == 'exact') {
    final parts = [
      for (final (who, _, amount) in people)
        SplitPart(who, amount ?? BigInt.zero, units: 0),
    ];
    final sum = parts.fold(BigInt.zero, (BigInt n, p) => n + p.amount);
    if (sum != total)
      throw FormatException(
        'The amounts are ${sum > total ? 'over' : 'under'} the total by ${(sum - total).abs()} minor units / Các số tiền ${sum > total ? 'vượt' : 'thiếu'} tổng ${(sum - total).abs()} đơn vị',
      );
    return parts;
  }
  final units = [for (final p in people) method == 'equal' ? 1 : p.$2];
  final shares = allocate(total, units);
  return [
    for (var i = 0; i < people.length; i++)
      SplitPart(people[i].$1, shares[i], units: units[i]),
  ];
}

/// Settled so far between you and [person] in [x]: money they paid you
/// back when you paid, or money you paid them when they did.
BigInt settled(SpendState s, CostSplit x, String person) => s.entries
    .where((e) => e.settles == x.id && e.person == person)
    .fold(BigInt.zero, (BigInt n, e) => n + e.amount.abs());

/// What is still open with [person] in [x], as a positive amount. When
/// you paid it is what they owe you; when they paid it is what you owe.
BigInt outstanding(SpendState s, CostSplit x, String person) {
  if (person == me) return BigInt.zero;
  if (x.payer == me) return x.share(person) - settled(s, x, person);
  if (x.payer == person) return x.share(me) - settled(s, x, person);
  return BigInt.zero;
}

/// Each person's open balance per currency: positive when they owe you,
/// negative when you owe them. Settled-up people are left out.
Map<String, Map<String, BigInt>> owedByPerson(SpendState s) {
  final result = <String, Map<String, BigInt>>{};
  for (final x in s.splits) {
    for (final p in s.people) {
      final open = outstanding(s, x, p.id);
      if (open == BigInt.zero) continue;
      final signed = x.payer == me ? open : -open;
      final m = result.putIfAbsent(p.id, () => {});
      m[x.currency] = (m[x.currency] ?? BigInt.zero) + signed;
    }
  }
  for (final m in result.values) {
    m.removeWhere((_, v) => v == BigInt.zero);
  }
  result.removeWhere((_, m) => m.isEmpty);
  return result;
}

/// Totals in [currency]: (owed to you, you owe), both positive.
(BigInt owedToYou, BigInt youOwe) iouTotals(SpendState s, String currency) {
  var them = BigInt.zero, you = BigInt.zero;
  for (final m in owedByPerson(s).values) {
    final v = m[currency];
    if (v == null) continue;
    v.isNegative ? you -= v : them += v;
  }
  return (them, you);
}

/// The ledger entry for settling [amount] of [x] with [person] through
/// [account]: a refund of your expense when they pay you back (so the
/// month's spending shrinks by their share), an expense when you pay them.
Entry settlement(
  SpendState s,
  CostSplit x,
  String person,
  BigInt amount, {
  required String account,
  required String date,
  String payee = '',
}) {
  final open = outstanding(s, x, person);
  if (amount <= BigInt.zero || amount > open)
    throw const FormatException(
      'Enter an amount up to what is still open / Nhập số không quá phần còn nợ',
    );
  final a = s.accounts.where((a) => a.id == account).firstOrNull;
  if (a == null || a.archived || a.currency != x.currency)
    throw const FormatException(
      'Choose an account in the split\'s currency / Chọn tài khoản cùng loại tiền',
    );
  final theyPay = x.payer == me;
  return Entry(
    id: newId(),
    account: account,
    kind: theyPay ? 'refund' : 'expense',
    amount: theyPay ? amount : -amount,
    when: localTimestamp(date, s.zone),
    payee: payee,
    category: x.category,
    refundOf: theyPay ? x.entry : null,
    settles: x.id,
    person: person,
  );
}

/// [s] without the entries in [ids], their receipts and the splits they
/// carried. A refund or settlement still pointing at a removed entry makes
/// the result invalid, so such a delete is refused as before.
SpendState withoutEntries(SpendState s, Set<String> ids) => s.copy({
  'entries': [
    for (final e in s.entries)
      if (!ids.contains(e.id)) e.toJson(),
  ],
  'receipts': [
    for (final r in s.receipts)
      if (!ids.contains(r.entry)) r.toJson(),
  ],
  'splits': [
    for (final x in s.splits)
      if (x.entry == null || !ids.contains(x.entry)) x.toJson(),
  ],
});
