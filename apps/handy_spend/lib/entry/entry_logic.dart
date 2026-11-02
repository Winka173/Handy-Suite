import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart' show foldAccents;

/// Categories used most recently for [kind], newest first.
List<String> recentCategories(SpendState s, String kind, {int count = 6}) {
  final seen = <String>{};
  for (final e in s.entries.reversed) {
    final id = e.category;
    if (e.kind != kind || id == null || seen.contains(id)) continue;
    if (s.categories.any((c) => c.id == id && !c.archived)) seen.add(id);
    if (seen.length == count) break;
  }
  return seen.toList();
}

/// Payees typed before for [kind], newest first, matching [query]
/// without minding accents.
List<String> payeeSuggestions(
  SpendState s,
  String kind,
  String query, {
  int count = 5,
}) {
  final q = foldAccents(query.trim());
  final out = <String>[];
  for (final e in s.entries.reversed) {
    final p = e.payee.trim();
    if (p.isEmpty || e.kind != kind || out.contains(p)) continue;
    if (q.isNotEmpty && (!foldAccents(p).contains(q) || foldAccents(p) == q))
      continue;
    out.add(p);
    if (out.length == count) break;
  }
  return out;
}

/// The category a payee usually gets: the first text rule that matches,
/// else what it had last time for this kind.
String? categoryForPayee(SpendState s, String kind, String payee) {
  final p = foldAccents(payee.trim());
  if (p.isEmpty) return null;
  for (final rule in s.rules) {
    final text = foldAccents('${rule['contains'] ?? ''}'.trim());
    final id = rule['category'] as String?;
    if (text.isNotEmpty &&
        p.contains(text) &&
        s.categories.any((c) => c.id == id && c.kind == _kindOf(kind)))
      return id;
  }
  for (final e in s.entries.reversed) {
    if (e.kind == kind &&
        e.category != null &&
        foldAccents(e.payee.trim()) == p)
      return e.category;
  }
  return null;
}

/// Refunds go back into expense categories.
String _kindOf(String kind) => kind == 'income' ? 'income' : 'expense';

/// The account a new entry starts on: the one used last for [kind].
String defaultAccount(SpendState s, String kind) {
  final open = {for (final a in s.accounts.where((a) => !a.archived)) a.id};
  for (final e in s.entries.reversed) {
    if (e.kind == kind && open.contains(e.account)) return e.account;
  }
  return s.accounts.firstWhere((a) => !a.archived).id;
}

/// What the entry sheet holds, turned into a ledger entry. [entered] is
/// the amount as typed (a magnitude; an adjustment may carry its sign).
Entry buildEntry({
  required SpendState s,
  String? id,
  Entry? existing,
  Entry? refundOf,
  required String kind,
  required String account,
  required BigInt entered,
  required String date,
  required bool pending,
  String? category,
  String payee = '',
  String note = '',
  String tags = '',
  String? toAccount,
  String? rate,
  BigInt? fee,
}) {
  if (kind != 'adjustment' && entered.isNegative)
    throw const FormatException(
      'Enter a positive amount; the type sets the direction / Nhập số dương; loại giao dịch quyết định chiều',
    );
  if (kind != 'adjustment' && entered == BigInt.zero)
    throw const FormatException('Enter an amount / Nhập số tiền');
  final from = s.accounts.firstWhere((a) => a.id == account);
  final transfer = kind == 'transfer';
  final amount = kind == 'expense' || transfer ? -entered : entered;
  final dest = transfer
      ? s.accounts.where((a) => a.id == toAccount).firstOrNull ??
            (throw const FormatException(
              'Choose where the money goes / Chọn tài khoản nhận',
            ))
      : null;
  if (dest?.id == from.id)
    throw const FormatException(
      'Choose a different account / Chọn tài khoản khác',
    );
  final cleanRate = (rate ?? '').trim().isEmpty ? null : rate!.trim();
  return Entry(
    id: existing?.id ?? id ?? newId(),
    account: from.id,
    kind: kind,
    amount: amount,
    when: existing != null && reportDay(existing.when, s.zone) == date
        ? existing.when
        : localTimestamp(date, s.zone),
    created: existing?.created,
    payee: payee.trim(),
    note: note.trim(),
    tags: tags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList(),
    status: pending ? 'pending' : 'posted',
    category: transfer ? null : category,
    toAccount: dest?.id,
    target: dest == null
        ? null
        : dest.currency == from.currency
        ? -amount
        : convert(-amount, from.currency, dest.currency, cleanRate ?? ''),
    rate: dest == null || dest.currency == from.currency ? null : cleanRate,
    fee: transfer ? (fee ?? BigInt.zero) : BigInt.zero,
    refundOf: kind == 'refund' ? (existing?.refundOf ?? refundOf?.id) : null,
    batch: existing?.batch,
    occurrence: existing?.occurrence,
    settles: existing?.settles,
    person: existing?.person,
  );
}

/// A past entry as the start of a new one: new ID, today, no import batch
/// or schedule occurrence. Saving it never changes the original.
Entry presetFrom(Entry e, String today, String zone) => e.copy({
  'id': newId(),
  'when': localTimestamp(today, zone),
  'created': DateTime.now().toUtc().toIso8601String(),
  'batch': null,
  'occurrence': null,
  'settles': null,
  'person': null,
});
