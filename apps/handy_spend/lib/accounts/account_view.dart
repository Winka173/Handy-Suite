import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../entry/entry_sheet.dart';
import '../ledger/entry_row.dart';
import '../scope.dart';
import '../settings/imports_page.dart';
import '../ui/figures.dart';
import 'account_editor.dart';

/// One account as a page of its own (phones and web links).
class AccountPage extends StatelessWidget {
  final SpendScope scope;
  final String id;
  const AccountPage({super.key, required this.scope, required this.id});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final a = scope.state.accounts.where((a) => a.id == id).firstOrNull;
      return Scaffold(
        appBar: AppBar(title: Text(a?.name ?? '')),
        body: a == null
            ? Center(
                child: HandyEmpty(
                  title: tr(
                    context,
                    'This account is gone',
                    'Tài khoản này không còn',
                  ),
                ),
              )
            : AccountView(scope: scope, account: a, showTitle: false),
      );
    },
  );
}

/// The balance today, the one job an account asks for (checking it against
/// the real one), its recent entries and the statements imported into it.
class AccountView extends StatelessWidget {
  final SpendScope scope;
  final Account account;
  final bool showTitle;
  const AccountView({
    super.key,
    required this.scope,
    required this.account,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final s = scope.state;
    final a = account;
    final balance = balances(s, scope.today)[a.id]!;
    final last = lastRecordedDays(s, scope.today)[a.id];
    final entries = [
      for (final e in s.entries)
        if (e.account == a.id || e.toAccount == a.id) e,
    ]..sort((x, y) => y.when.compareTo(x.when));
    final batches = [
      for (final r in s.imports.reversed)
        if (importTouches(s, r, a.id)) r,
    ];
    return ListView(
      padding: const EdgeInsets.all(HandySpace.l),
      children: [
        // One left edge with the list beside it on wide screens.
        Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: HandySpace.content),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showTitle)
                  Semantics(
                    header: true,
                    child: Text(a.name, style: theme.textTheme.titleLarge),
                  ),
                Text(
                  [
                    accountTypeLabel(context, a.type),
                    if (a.currency != scope.currency) a.currency,
                    if (a.archived) tr(context, 'archived', 'đã lưu trữ'),
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                ),
                const SizedBox(height: HandySpace.m),
                Money(
                  scope,
                  balance,
                  a.currency,
                  key: const Key('account-balance'),
                  style: theme.textTheme.displaySmall,
                ),
                Text(
                  last == null
                      ? tr(
                          context,
                          'Started ${dayLabel(context, scope, a.asOf)}; nothing recorded since.',
                          'Bắt đầu ${dayLabel(context, scope, a.asOf)}; chưa ghi gì.',
                        )
                      : tr(
                          context,
                          'Last entry or check ${dayLabel(context, scope, last)}. A local record, not your bank\'s.',
                          'Lần ghi hoặc đối chiếu cuối ${dayLabel(context, scope, last)}. Đây là ghi chép trên máy, không phải số của ngân hàng.',
                        ),
                  style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                ),
                const SizedBox(height: HandySpace.l),
                Wrap(
                  spacing: HandySpace.s,
                  runSpacing: HandySpace.s,
                  children: [
                    FilledButton.icon(
                      key: const Key('account-reconcile'),
                      onPressed: a.archived
                          ? null
                          : () => openReconcile(context, scope, a),
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: Text(tr(context, 'Check balance', 'Đối chiếu')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('account-import'),
                      onPressed: a.archived
                          ? null
                          : () =>
                                Navigator.pushNamed(context, '/import/${a.id}'),
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: Text(
                        tr(context, 'Import statement', 'Nhập sao kê'),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('account-edit'),
                      onPressed: () => openAccountEditor(context, scope, a),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(tr(context, 'Edit', 'Sửa')),
                    ),
                  ],
                ),
                HandySection(
                  title: tr(context, 'Recent', 'Gần đây'),
                  trailing: entries.isEmpty
                      ? null
                      : TextButton(
                          key: const Key('account-ledger'),
                          onPressed: () {
                            scope.ledgerAccount.value = a.id;
                            scope.area.value = 1;
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                          child: Text(
                            tr(context, 'All in ledger', 'Xem trong sổ'),
                          ),
                        ),
                  children: [
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(HandySpace.l),
                        child: Text(
                          tr(context, 'No entries yet.', 'Chưa có giao dịch.'),
                        ),
                      ),
                    for (final e in entries.take(10))
                      EntryRow(
                        scope: scope,
                        entry: e,
                        showDate: true,
                        onTap: () => openEntry(context, scope, entry: e),
                      ),
                  ],
                ),
                if (batches.isNotEmpty)
                  HandySection(
                    title: tr(context, 'Statements imported', 'Sao kê đã nhập'),
                    children: [
                      for (final r in batches)
                        ImportRecordTile(scope: scope, record: r),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
