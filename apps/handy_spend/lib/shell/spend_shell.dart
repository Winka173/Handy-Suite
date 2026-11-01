import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import '../accounts/accounts_page.dart';
import '../capabilities.dart';
import '../entry/entry_sheet.dart';
import '../import/import_page.dart';
import '../import/statement_io.dart';
import '../ledger/ledger_page.dart';
import '../plan/plan_page.dart';
import '../scope.dart';
import '../today/today_page.dart';

/// The four areas: a bottom bar on phones, a switch in the top bar on wide
/// screens. Recording spending is one tap (Ctrl N) from Today and the
/// ledger; a statement dropped on the window opens the import.
class SpendShell extends StatefulWidget {
  final SpendScope scope;
  final bool enableDrop;
  const SpendShell({super.key, required this.scope, this.enableDrop = true});
  @override
  State<SpendShell> createState() => _SpendShellState();
}

class _SpendShellState extends State<SpendShell> {
  SpendScope get scope => widget.scope;
  final searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    scope.area.addListener(_changed);
  }

  @override
  void dispose() {
    scope.area.removeListener(_changed);
    searchFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void go(int area) => scope.area.value = area;

  Future<void> record() async {
    if (scope.openAccounts.isEmpty) return;
    await openEntry(context, scope);
  }

  Future<void> undo() => scope.write(
    context,
    scope.controller.undo,
    done: (c) => tr(c, 'Undone.', 'Đã hoàn tác.'),
  );

  Future<void> dropped(DropDoneDetails details) async {
    try {
      if (details.files.length != 1)
        throw const FormatException(
          'Drop one statement at a time / Mỗi lần thả một file sao kê',
        );
      if (scope.openAccounts.isEmpty)
        throw const FormatException(
          'Add an account first / Hãy thêm tài khoản trước',
        );
      final file = await readDroppedStatement(details.files.single);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/import'),
          builder: (_) => ImportPage(scope: scope, initialFile: file),
        ),
      );
    } catch (e) {
      if (mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Not opened: ${errorText(context, e)}.',
            'Chưa mở được: ${errorText(context, e)}.',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= HandySpace.wide;
    final area = scope.area.value;
    final ready = scope.openAccounts.isNotEmpty;
    final areas = [
      (Icons.today_outlined, Icons.today, tr(context, 'Today', 'Hôm nay')),
      (
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        tr(context, 'Ledger', 'Sổ'),
      ),
      (
        Icons.timeline_outlined,
        Icons.timeline,
        tr(context, 'Plan', 'Kế hoạch'),
      ),
      (
        Icons.account_balance_outlined,
        Icons.account_balance,
        tr(context, 'Accounts', 'Tài khoản'),
      ),
    ];
    final scaffold = Scaffold(
      appBar: HandyTopBar(
        mark: Icons.account_balance_wallet,
        name: 'Handy Spend',
        nameIsTitle: false,
        areas: wide
            ? SegmentedButton<int>(
                key: const Key('spend-areas'),
                showSelectedIcon: false,
                segments: [
                  for (final (i, a) in areas.indexed)
                    ButtonSegment(
                      value: i,
                      label: Text(a.$3, key: Key('area-$i')),
                    ),
                ],
                selected: {area},
                onSelectionChanged: (v) => go(v.single),
              )
            : null,
        actions: [
          IconButton(
            key: const Key('spend-hide'),
            tooltip: scope.hidden
                ? tr(context, 'Show amounts', 'Hiện số tiền')
                : tr(context, 'Hide amounts', 'Ẩn số tiền'),
            onPressed: () => scope.write(
              context,
              () => scope.controller.change(
                (s) => s.copy({
                  'settings': {...s.settings, 'hideAmounts': !scope.hidden},
                }),
                'privacy_mask',
              ),
            ),
            icon: Icon(
              scope.hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          if (wide && ready)
            Padding(
              padding: const EdgeInsets.only(right: HandySpace.s),
              child: FilledButton.icon(
                key: const Key('spend-add'),
                onPressed: record,
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr(context, 'Record spending', 'Ghi khoản chi')),
              ),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: area,
          children: [
            TodayPage(scope: scope),
            LedgerPage(scope: scope, searchFocus: searchFocus),
            PlanPage(scope: scope),
            AccountsPage(scope: scope),
          ],
        ),
      ),
      floatingActionButton: !wide && ready && area <= 1
          ? FloatingActionButton.extended(
              key: const Key('spend-add'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              onPressed: record,
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'Record', 'Ghi khoản chi')),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              key: const Key('spend-nav'),
              selectedIndex: area,
              onDestinationSelected: go,
              destinations: [
                for (final (i, a) in areas.indexed)
                  NavigationDestination(
                    key: Key('nav-$i'),
                    icon: Icon(a.$1),
                    selectedIcon: Icon(a.$2),
                    label: a.$3,
                  ),
              ],
            ),
    );
    final keyed = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): record,
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
          if (ready) Navigator.pushNamed(context, '/import');
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): undo,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          go(1);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) searchFocus.requestFocus();
          });
        },
        for (var i = 0; i < 4; i++)
          SingleActivator(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
            ][i],
            control: true,
          ): () =>
              go(i),
      },
      child: Focus(autofocus: true, child: scaffold),
    );
    return widget.enableDrop && SpendCapabilities.current.dragDrop
        ? DropTarget(onDragDone: (d) => unawaited(dropped(d)), child: keyed)
        : keyed;
  }
}
