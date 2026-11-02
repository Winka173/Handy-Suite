import 'package:handy_spend_engine/handy_spend_engine.dart';

/// One shared cost seen from one person: their share or yours, and what
/// is still open.
class PersonItem {
  final CostSplit split;

  /// True when they owe you (you paid), false when you owe them.
  final bool theyOwe;
  final BigInt share, open;
  const PersonItem(this.split, this.theyOwe, this.share, this.open);
}

/// Every split [person] is in with you, oldest first.
List<PersonItem> personItems(SpendState s, String person) {
  final out = <PersonItem>[];
  for (final x in s.splits) {
    if (x.payer == me && x.share(person) > BigInt.zero) {
      out.add(PersonItem(x, true, x.share(person), outstanding(s, x, person)));
    } else if (x.payer == person) {
      out.add(PersonItem(x, false, x.share(me), outstanding(s, x, person)));
    }
  }
  out.sort((a, b) => a.split.date.compareTo(b.split.date));
  return out;
}

/// The entries that settle [amount] of what is open with [person] in
/// [currency] through [account]: oldest first. When both of you owe each
/// other, only the whole net can be settled at once (each side's items are
/// closed and the account moves by the difference); a part of it is
/// settled item by item instead ([only] names one split).
List<Entry> settleUp(
  SpendState s,
  String person,
  String currency,
  BigInt amount, {
  required String account,
  required String date,
  required String Function(PersonItem item) payee,
  String? only,
}) {
  final open = [
    for (final i in personItems(s, person))
      if (i.open > BigInt.zero &&
          i.split.currency == currency &&
          (only == null || i.split.id == only))
        i,
  ];
  final theirs = open
      .where((i) => i.theyOwe)
      .fold(BigInt.zero, (BigInt n, i) => n + i.open);
  final yours = open
      .where((i) => !i.theyOwe)
      .fold(BigInt.zero, (BigInt n, i) => n + i.open);
  final net = (theirs - yours).abs();
  final both = theirs > BigInt.zero && yours > BigInt.zero;
  // Owing each other the same closes with nothing changing hands.
  if (open.isEmpty ||
      amount.isNegative ||
      amount == BigInt.zero && !(both && net == BigInt.zero))
    throw const FormatException('Nothing to settle / Không còn gì để trả');
  if (both && amount != net)
    throw const FormatException(
      'You both owe each other: settle the whole difference, or one item at a time / Hai bên cùng nợ: trả cả phần chênh, hoặc từng khoản một',
    );
  if (!both && amount > net)
    throw const FormatException('More than is open / Nhiều hơn số còn nợ');
  var state = s, left = amount;
  final made = <Entry>[];
  for (final i in open) {
    final part = both ? i.open : (left < i.open ? left : i.open);
    if (part <= BigInt.zero) continue;
    final e = settlement(
      state,
      i.split,
      person,
      part,
      account: account,
      date: date,
      payee: payee(i),
    );
    made.add(e);
    state = state.copy({
      'entries': [...state.entries.map((x) => x.toJson()), e.toJson()],
    });
    if (!both) left -= part;
  }
  return made;
}
