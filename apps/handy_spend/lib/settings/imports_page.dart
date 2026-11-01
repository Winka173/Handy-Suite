import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';

/// Whether an import batch put entries into [account] (or checked it).
bool importTouches(SpendState s, Map<String, dynamic> record, String account) {
  final ids = (record['entries'] as Map? ?? const {}).keys.toSet();
  final rec = record['reconciliation'];
  return rec is Map && rec['account'] == account ||
      s.entries.any((e) => ids.contains(e.id) && e.account == account);
}

/// One statement import: when, how many rows, and Undo while its rows are
/// unchanged.
class ImportRecordTile extends StatelessWidget {
  final SpendScope scope;
  final Map<String, dynamic> record;
  const ImportRecordTile({
    super.key,
    required this.scope,
    required this.record,
  });

  Future<void> undo(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Undo this import?', 'Hoàn tác lần nhập này?'),
      message: tr(
        context,
        'Only works while its rows are unchanged and nothing refunds them.',
        'Chỉ được khi các dòng chưa bị sửa và không có khoản hoàn tiền gắn kèm.',
      ),
      confirmLabel: tr(context, 'Undo import', 'Hoàn tác'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await scope.write(
      context,
      () => scope.controller.change(
        (s) => undoImport(s, record['id'] as String),
        'undo_import',
      ),
      done: (c) => tr(c, 'Import undone.', 'Đã hoàn tác lần nhập.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final at = DateTime.tryParse('${record['at']}');
    final when = at == null
        ? '${record['at']}'
        : dayLabel(
            context,
            scope,
            reportDay(at.toUtc().toIso8601String(), scope.state.zone),
          );
    final undone = record['undone'] == true;
    final rec = record['reconciliation'];
    String? diff;
    if (rec is Map) {
      final a = scope.state.accounts
          .where((a) => a.id == rec['account'])
          .firstOrNull;
      if (a != null)
        diff = tr(
          context,
          'difference at the statement\'s end ${moneyText(context, scope, BigInt.parse('${rec['difference']}'), a.currency, sign: true)}',
          'chênh lệch cuối sao kê ${moneyText(context, scope, BigInt.parse('${rec['difference']}'), a.currency, sign: true)}',
        );
    }
    return ListTile(
      key: Key('import-${record['id']}'),
      title: Text(
        tr(
          context,
          '${record['imported']} of ${record['totalRows']} rows · $when',
          '${record['imported']} / ${record['totalRows']} dòng · $when',
        ),
      ),
      subtitle: Text(
        [
          undone
              ? tr(context, 'undone', 'đã hoàn tác')
              : tr(context, 'in the ledger', 'đã vào sổ'),
          ?diff,
        ].join(' · '),
      ),
      trailing: undone
          ? null
          : TextButton(
              onPressed: () => undo(context),
              child: Text(tr(context, 'Undo', 'Hoàn tác')),
            ),
    );
  }
}

class ImportsPage extends StatelessWidget {
  final SpendScope scope;
  const ImportsPage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) => HandyPage(
      title: tr(context, 'Statement imports', 'Các lần nhập sao kê'),
      children: [
        if (scope.state.imports.isEmpty)
          HandyEmpty(title: tr(context, 'No imports yet', 'Chưa nhập lần nào'))
        else
          HandySection(
            children: [
              for (final r in scope.state.imports.reversed)
                ImportRecordTile(scope: scope, record: r),
            ],
          ),
      ],
    ),
  );
}
