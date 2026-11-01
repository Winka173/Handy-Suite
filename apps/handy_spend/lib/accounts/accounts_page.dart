import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'account_editor.dart';
import 'account_view.dart';

/// What you have and what you owe: net worth per currency, then each
/// account under money to spend, savings or debts. On a wide screen the
/// chosen account opens beside the list.
class AccountsPage extends StatefulWidget {
  final SpendScope scope;
  const AccountsPage({super.key, required this.scope});
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  SpendScope get scope => widget.scope;
  bool wide = false;

  @override
  void initState() {
    super.initState();
    scope.openAccount.addListener(_opened);
    WidgetsBinding.instance.addPostFrameCallback((_) => _opened());
  }

  @override
  void dispose() {
    scope.openAccount.removeListener(_opened);
    super.dispose();
  }

  void _opened() {
    final id = scope.openAccount.value;
    if (!mounted || id == null) return;
    if (wide) {
      setState(() {});
    } else {
      scope.openAccount.value = null;
      Navigator.pushNamed(context, '/account/$id');
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      wide = size.maxWidth >= 1000;
      final selected = wide
          ? scope.state.accounts
                    .where((a) => a.id == scope.openAccount.value)
                    .firstOrNull ??
                scope.openAccounts.firstOrNull
          : null;
      final list = _AccountList(
        scope: scope,
        selected: selected?.id,
        onOpen: (id) {
          if (wide) {
            scope.openAccount.value = id;
            setState(() {});
          } else {
            Navigator.pushNamed(context, '/account/$id');
          }
        },
      );
      if (!wide || selected == null) return list;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 420, child: list),
          const VerticalDivider(width: 1),
          Expanded(
            child: AccountView(
              key: ValueKey(selected.id),
              scope: scope,
              account: selected,
            ),
          ),
        ],
      );
    },
  );
}

class _AccountList extends StatelessWidget {
  final SpendScope scope;
  final String? selected;
  final ValueChanged<String> onOpen;
  const _AccountList({
    required this.scope,
    required this.selected,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final funds = balances(s, scope.today);
    final latest = lastRecordedDays(s, scope.today);
    final currencies = {for (final a in s.accounts) a.currency}.toList()
      ..sort(
        (a, b) => a == s.currency ? -1 : (b == s.currency ? 1 : a.compareTo(b)),
      );
    BigInt worth(String cur) => s.accounts
        .where((a) => a.currency == cur)
        .fold(BigInt.zero, (n, a) => n + funds[a.id]!);
    final groups = <(String, List<Account>)>[
      (
        tr(context, 'Money to spend', 'Tiền tiêu được'),
        [
          for (final a in scope.openAccounts)
            if (!a.liability && a.liquid) a,
        ],
      ),
      (
        tr(context, 'Savings and other', 'Tiết kiệm và khác'),
        [
          for (final a in scope.openAccounts)
            if (!a.liability && !a.liquid) a,
        ],
      ),
      (
        tr(context, 'Debts', 'Nợ'),
        [
          for (final a in scope.openAccounts)
            if (a.liability) a,
        ],
      ),
      (
        tr(context, 'Archived', 'Đã lưu trữ'),
        [
          for (final a in s.accounts)
            if (a.archived) a,
        ],
      ),
    ];
    Widget row(Account a) {
      final days = latest[a.id] == null
          ? null
          : calendar(scope.today).difference(calendar(latest[a.id]!)).inDays;
      return Material(
        color: selected == a.id ? c.select : Colors.transparent,
        child: InkWell(
          key: Key('account-${a.id}'),
          onTap: () => onOpen(a.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HandySpace.l,
              vertical: 10,
            ),
            // Narrow and large text: the balance goes under the name, whole.
            child: LayoutBuilder(
              builder: (context, box) {
                final money = Money(scope, funds[a.id]!, a.currency);
                final name = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: HandyDot(scope.accountHue(a.id), size: 8),
                          ),
                          TextSpan(
                            text: ' ${accountTypeLabel(context, a.type)}',
                          ),
                          if (days != null)
                            TextSpan(
                              text: days >= 30
                                  ? tr(
                                      context,
                                      ' · $days days unchecked',
                                      ' · $days ngày chưa đối chiếu',
                                    )
                                  : tr(
                                      context,
                                      ' · updated ${relativeDays(context, -days)}',
                                      ' · cập nhật ${relativeDays(context, -days)}',
                                    ),
                              style: TextStyle(
                                color: days >= 30 ? c.warning : null,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                  ],
                );
                return box.maxWidth <
                        300 * MediaQuery.textScalerOf(context).scale(1)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          name,
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: money,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: name),
                          const SizedBox(width: HandySpace.m),
                          money,
                        ],
                      );
              },
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        HandySpace.l,
        HandySpace.l,
        48,
      ),
      children: [
        HandyContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  tr(context, 'Net worth', 'Tài sản ròng'),
                  style: theme.textTheme.titleMedium?.copyWith(color: c.muted),
                ),
              ),
              for (final (i, cur) in currencies.indexed)
                Money(
                  scope,
                  worth(cur),
                  cur,
                  key: Key('worth-$cur'),
                  style: i == 0
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.titleLarge,
                ),
              if (currencies.length > 1)
                Text(
                  tr(
                    context,
                    'Each currency on its own; no rate is assumed.',
                    'Mỗi loại tiền tính riêng; không tự giả định tỷ giá.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                ),
              if (s.accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: HandySpace.l),
                  child: Text(
                    tr(
                      context,
                      'No accounts yet. Cash, a bank card or an e-wallet each counts as one.',
                      'Chưa có tài khoản. Tiền mặt, thẻ ngân hàng hay ví điện tử đều là một tài khoản.',
                    ),
                  ),
                ),
              for (final (title, list) in groups)
                if (list.isNotEmpty)
                  HandySection(
                    title: title,
                    children: [for (final a in list) row(a)],
                  ),
              const SizedBox(height: HandySpace.l),
              Wrap(
                spacing: HandySpace.s,
                runSpacing: HandySpace.s,
                children: [
                  FilledButton.icon(
                    key: const Key('account-add'),
                    onPressed: () => openAccountEditor(context, scope),
                    icon: const Icon(Icons.add),
                    label: Text(tr(context, 'Add account', 'Thêm tài khoản')),
                  ),
                  if (s.accounts.isNotEmpty)
                    OutlinedButton.icon(
                      key: const Key('accounts-import'),
                      onPressed: () => Navigator.pushNamed(context, '/import'),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(
                        tr(context, 'Import a statement', 'Nhập sao kê'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
