import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart' show today;
import 'fields.dart';

/// Who has it, since when, and when it should come back.
Future<void> showLendDialog(
  BuildContext context, {
  required InventoryAsset item,
  required Future<void> Function(String who, String on, String due) onCommit,
}) {
  final who = TextEditingController(text: item.borrower);
  var on = item.lentOn.isEmpty ? today() : item.lentOn;
  var due = item.returnDue;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => HandyCommitDialog(
        title: tr(context, 'Lend ${item.name}', 'Cho mượn ${item.name}'),
        saveLabel: tr(context, 'Lend', 'Cho mượn'),
        saveKey: const Key('lend-save'),
        onCommit: () => onCommit(who.text, on, due),
        fields: (context, busy) => [
          HandyField(
            label: tr(context, 'Who has it', 'Ai mượn'),
            child: TextField(
              key: const Key('lend-who'),
              controller: who,
              enabled: !busy,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          const SizedBox(height: HandySpace.l),
          HandyGroup(
            children: [
              DateRow(
                id: 'lentOn',
                label: tr(context, 'Lent on', 'Ngày cho mượn'),
                value: on,
                enabled: !busy,
                onChanged: (v) => setState(() => on = v),
              ),
              DateRow(
                id: 'returnDue',
                label: tr(context, 'Back by', 'Hẹn trả'),
                value: due,
                enabled: !busy,
                onChanged: (v) => setState(() => due = v),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
