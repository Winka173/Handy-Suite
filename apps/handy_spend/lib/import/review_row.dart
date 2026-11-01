import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';

/// Reclassifies one statement row before import: a transfer, a refund of an
/// earlier expense, or a liability credit. Nothing is guessed for you.
/// Calls [onChanged] with the checked entry.
Future<void> reviewStatementRow(
  BuildContext context,
  SpendScope scope,
  StatementRow row,
  Map<String, Entry> references,
  void Function(Entry) onChanged,
) {
  final s = scope.state;
  final e = row.entry!;
  final open = {
    for (final a in scope.openAccounts) a.id: '${a.name} · ${a.currency}',
  };
  return showSpendForm(
    context,
    scope,
    title: tr(context, 'Row ${row.number}', 'Dòng ${row.number}'),
    saveLabel: tr(context, 'Use', 'Dùng'),
    fields: [
      SpendField(
        'kind',
        'It is',
        'Đây là',
        kind: FieldKind.choice,
        options: {
          for (final k in [
            'expense',
            'income',
            'transfer',
            'refund',
            'adjustment',
          ])
            k: kindLabel(context, k),
        },
      ),
      SpendField(
        'account',
        'Account',
        'Tài khoản',
        kind: FieldKind.choice,
        options: open,
      ),
      SpendField(
        'amount',
        'Amount, signed',
        'Số tiền, có dấu',
        kind: FieldKind.money,
        signed: true,
        currency: (v) => scope.account(v['account'] as String).currency,
        helpEn: 'Spending and transfers out are negative.',
        helpVi: 'Khoản chi và tiền chuyển đi là số âm.',
      ),
      const SpendField('date', 'Date', 'Ngày', kind: FieldKind.date),
      const SpendField('payee', 'Payee', 'Đối tác', required: false),
      SpendField(
        'category',
        'Category',
        'Danh mục',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'None', 'Không'),
          for (final c in s.categories) c.id: c.name,
        },
      ),
      SpendField(
        'to',
        'Moves into (transfers)',
        'Chuyển vào (chuyển khoản)',
        kind: FieldKind.choice,
        required: false,
        options: {'': tr(context, 'None', 'Không'), ...open},
      ),
      const SpendField(
        'rate',
        'Rate, if the currencies differ',
        'Tỷ giá, nếu khác loại tiền',
        required: false,
      ),
      SpendField(
        'refund',
        'Refund of (refunds)',
        'Hoàn lại cho (hoàn tiền)',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'None', 'Không'),
          for (final o in references.values.where(
            (r) => r.kind == 'expense' && r.id != e.id,
          ))
            o.id:
                '${dayLabel(context, scope, reportDay(o.when, s.zone))} · ${o.payee} · ${moneyText(context, scope, o.amount, scope.account(o.account).currency)}',
        },
      ),
    ],
    initial: {
      'kind': e.kind,
      'account': e.account,
      'amount': e.amount,
      'date': reportDay(e.when, s.zone),
      'payee': e.payee,
      'category': e.category ?? '',
      'to': e.toAccount ?? '',
      'rate': e.rate ?? '',
      'refund': e.refundOf ?? '',
    },
    save: (v) async {
      final account = scope.account(v['account'] as String);
      final type = v['kind'] as String;
      final amount = v['amount'] as BigInt;
      final to = type == 'transfer' && (v['to'] as String).isNotEmpty
          ? scope.account(v['to'] as String)
          : null;
      if (type == 'transfer' && to == null)
        throw const FormatException(
          'Choose where it moves / Chọn tài khoản nhận',
        );
      final rate = (v['rate'] as String).trim().isEmpty
          ? null
          : (v['rate'] as String).trim();
      final date = v['date'] as String;
      final changed = e.copy({
        'account': account.id,
        'kind': type,
        'amount': '$amount',
        'when': date == reportDay(e.when, s.zone)
            ? e.when
            : localTimestamp(date, s.zone),
        'payee': v['payee'],
        'category': (v['category'] as String).isEmpty || type == 'transfer'
            ? null
            : v['category'],
        'toAccount': to?.id,
        'target': to == null
            ? null
            : (to.currency == account.currency
                      ? -amount
                      : convert(
                          -amount,
                          account.currency,
                          to.currency,
                          rate ?? '',
                        ))
                  .toString(),
        'rate': to == null || to.currency == account.currency ? null : rate,
        'refundOf': type == 'refund' && (v['refund'] as String).isNotEmpty
            ? v['refund']
            : null,
        'fee': '0',
      });
      // Checked on its own (and with what it refunds) before it is used.
      SpendState(
        accounts: s.accounts,
        categories: s.categories,
        settings: s.settings,
        entries: [
          if (changed.refundOf != null)
            references[changed.refundOf] ??
                (throw const FormatException(
                  'Missing refund source / Thiếu khoản chi gốc',
                )),
          changed,
        ],
      ).validate();
      onChanged(changed);
    },
  );
}
