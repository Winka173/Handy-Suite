import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';
import 'reconcile_hints.dart';

const _types = ['cash', 'bank', 'wallet', 'savings', 'credit', 'loan', 'other'];

/// Adds an account (with today's balance) or edits one. Debts are entered
/// as what is owed; the ledger keeps them negative.
Future<bool> openAccountEditor(
  BuildContext context,
  SpendScope scope, [
  Account? a,
]) {
  final s = scope.state;
  final debt = a != null && {'credit', 'loan'}.contains(a.type);
  return showSpendForm(
    context,
    scope,
    title: a == null
        ? tr(context, 'New account', 'Tài khoản mới')
        : tr(context, 'Edit ${a.name}', 'Sửa ${a.name}'),
    fields: [
      SpendField(
        'name',
        'Name',
        'Tên',
        helpEn: 'As you call it: Cash, Vietcombank, MoMo.',
        helpVi: 'Tên bạn quen gọi: Tiền mặt, Vietcombank, MoMo.',
      ),
      SpendField(
        'type',
        'Kind',
        'Loại',
        kind: FieldKind.choice,
        options: {for (final t in _types) t: accountTypeLabel(context, t)},
      ),
      if (a == null)
        SpendField(
          'currency',
          'Currency',
          'Loại tiền',
          kind: FieldKind.choice,
          options: {for (final k in scales.keys) k: k},
          helpEn: 'Fixed once created. Currencies are never mixed.',
          helpVi:
              'Không đổi được sau khi tạo. Không bao giờ cộng lẫn loại tiền.',
        ),
      SpendField(
        'opening',
        'Balance on the start date',
        'Số dư vào ngày bắt đầu',
        kind: FieldKind.money,
        signed: true,
        currency: (v) => v['currency'] as String? ?? a!.currency,
        helpEn: 'For a card or loan, enter what you owe as a positive amount.',
        helpVi: 'Thẻ tín dụng hoặc khoản vay: nhập số đang nợ, số dương.',
      ),
      const SpendField(
        'asOf',
        'Start date',
        'Ngày bắt đầu',
        kind: FieldKind.date,
      ),
      const SpendField(
        'liquid',
        'Count as money to spend',
        'Tính là tiền tiêu được',
        kind: FieldKind.toggle,
        helpEn: 'Used by Free to spend. Savings and debts are usually off.',
        helpVi: 'Dùng cho Có thể chi. Tiết kiệm và nợ thường tắt.',
      ),
      if (a != null)
        const SpendField(
          'archived',
          'Archive',
          'Lưu trữ',
          kind: FieldKind.toggle,
          helpEn: 'Hidden from new entries; its history stays.',
          helpVi: 'Ẩn khỏi lần ghi mới; lịch sử vẫn giữ.',
        ),
    ],
    initial: {
      'name': a?.name ?? '',
      'type': a?.type ?? 'cash',
      'currency': a?.currency ?? s.currency,
      'opening': debt ? -a.opening : (a?.opening ?? BigInt.zero),
      'asOf': a?.asOf ?? scope.today,
      'liquid': a?.liquid ?? true,
      'archived': a?.archived ?? false,
    },
    save: (v) async {
      final type = v['type'] as String;
      final owed = {'credit', 'loan'}.contains(type);
      final opening = v['opening'] as BigInt;
      final next = Account(
        id: a?.id ?? newId(),
        name: v['name'] as String,
        currency: a?.currency ?? v['currency'] as String,
        type: type,
        opening: owed ? -opening : opening,
        asOf: v['asOf'] as String,
        // A new debt is never money to spend unless asked.
        liquid: a == null && owed ? false : v['liquid'] == true,
        archived: v['archived'] == true,
      );
      await scope.controller.change(
        (s) => s.copy({
          'accounts': [
            for (final x in s.accounts)
              if (x.id != next.id) x.toJson(),
            next.toJson(),
          ],
        }),
        'save_account',
      );
    },
  );
}

/// Sets the ledger to the real balance today with one adjustment entry.
Future<bool> openReconcile(BuildContext context, SpendScope scope, Account a) {
  final held = balances(scope.state, scope.today)[a.id]!;
  return showSpendForm(
    context,
    scope,
    title: tr(context, 'Check ${a.name}', 'Đối chiếu ${a.name}'),
    saveLabel: tr(context, 'Set balance', 'Cập nhật số dư'),
    fields: [
      SpendField(
        'balance',
        'Real balance today',
        'Số dư thật hôm nay',
        kind: FieldKind.money,
        signed: true,
        currency: (_) => a.currency,
        helpEn:
            'Ledger says ${moneyText(context, scope, held, a.currency)}. The difference is recorded as an adjustment, not income or spending.',
        helpVi:
            'Sổ đang ghi ${moneyText(context, scope, held, a.currency)}. Chênh lệch được ghi là điều chỉnh, không tính là thu hay chi.',
        live: (context, raw) =>
            ReconcileExplain(scope: scope, account: a, held: held, raw: raw),
      ),
      const SpendField('note', 'Reason', 'Lý do', required: false),
    ],
    initial: {'balance': held, 'note': ''},
    save: (v) async {
      final delta = (v['balance'] as BigInt) - held;
      if (delta == BigInt.zero) return;
      await scope.controller.putEntry(
        Entry(
          id: newId(),
          account: a.id,
          kind: 'adjustment',
          amount: delta,
          when: localTimestamp(scope.today, scope.state.zone),
          note: v['note'] as String,
        ),
      );
    },
  );
}
