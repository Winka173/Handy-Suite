import 'package:handy_spend_engine/handy_spend_engine.dart';

/// One payment already promised (or one sum expected) inside the plan.
class PromisedPart {
  final String name, date;

  /// A positive magnitude in the report currency.
  final BigInt amount;
  const PromisedPart(this.name, this.date, this.amount);
}

/// The Safe to Spend estimate taken apart: what is held, what will come
/// in, each payment already promised, reserves and the buffer. The parts
/// add up to the engine's figures; [others] closes any gap.
class Promised {
  final SafeSpend safe;
  final List<PromisedPart> outs, ins;
  const Promised(this.safe, this.outs, this.ins);

  /// Outflows the engine counted that are not listed by name.
  BigInt get others =>
      safe.committed - outs.fold(BigInt.zero, (n, p) => n + p.amount);
  BigInt get held => safe.liquid + safe.income;
  BigInt get promised =>
      safe.committed + safe.reserves + safe.buffer + safe.owe;
}

/// Mirrors `forecast` and `safeToSpend` item by item, so every payment in
/// the window has its own name and date.
Promised promisedMoney(
  SpendState s,
  String start,
  String end, {
  required Set<String> accounts,
  required bool conservative,
}) {
  final safe = safeToSpend(
    s,
    start,
    end,
    accounts: accounts,
    conservative: conservative,
  );
  final byId = {for (final a in s.accounts) a.id: a};
  BigInt flow(String account, BigInt amount, String? to, BigInt? target) {
    var f = BigInt.zero;
    if (accounts.contains(account) && byId[account]?.currency == s.currency)
      f += amount;
    if (to != null && accounts.contains(to) && byId[to]?.currency == s.currency)
      f += target!;
    return f;
  }

  final outs = <PromisedPart>[], ins = <PromisedPart>[];
  void add(String name, String date, BigInt f) {
    final d = date.compareTo(start) < 0 ? start : date;
    if (f.isNegative) outs.add(PromisedPart(name, d, -f));
    if (f > BigInt.zero) ins.add(PromisedPart(name, d, f));
  }

  for (final o in upcoming(s, start, end)) {
    final income = !conservative && o.bill.reliable;
    if (o.bill.amount > BigInt.zero && !income) continue;
    final f = flow(
      o.bill.account,
      o.bill.amount,
      o.bill.toAccount,
      o.bill.target,
    );
    if (f > BigInt.zero && !income) continue;
    add(o.bill.name, o.date, f);
  }
  for (final e in s.entries) {
    final d = reportDay(e.when, s.zone);
    if (d.compareTo(end) > 0) continue;
    if (e.status != 'pending' && d.compareTo(start) <= 0) continue;
    final f = flow(e.account, e.amount - e.fee, e.toAccount, e.target);
    if (f.isNegative || !conservative)
      add(e.payee.isEmpty ? e.kind : e.payee, d, f);
  }
  outs.sort((a, b) => a.date.compareTo(b.date));
  return Promised(safe, outs, ins);
}
