import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart' show newId;

/// Adds or renames a moving box. The dialog stays until the box is saved.
Future<void> showBoxDialog(
  BuildContext context, {
  InventoryBox? box,
  required Future<void> Function(InventoryBox) onCommit,
}) {
  final name = TextEditingController(text: box?.name ?? '');
  final location = TextEditingController(text: box?.location ?? '');
  final notes = TextEditingController(text: box?.notes ?? '');
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => HandyCommitDialog(
      title: box == null
          ? tr(context, 'New box', 'Thùng mới')
          : tr(context, 'Edit box', 'Sửa thùng'),
      saveLabel: tr(context, 'Save box', 'Lưu thùng'),
      saveKey: const Key('box-save'),
      onCommit: () => onCommit(
        InventoryBox(
          id: box?.id ?? newId(),
          name: name.text,
          location: location.text,
          notes: notes.text,
        ),
      ),
      fields: (context, busy) => [
        HandyField(
          label: tr(context, 'Name on the box', 'Tên ghi trên thùng'),
          child: TextField(
            key: const Key('box-name'),
            controller: name,
            enabled: !busy,
            autofocus: box == null,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: tr(context, 'Box 7, Kitchen', 'Thùng 7, Đồ bếp'),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: HandySpace.l),
        HandyField(
          label: tr(context, 'Where it stands', 'Thùng để ở đâu'),
          child: TextField(
            key: const Key('box-location'),
            controller: location,
            enabled: !busy,
            maxLength: 500,
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
        const SizedBox(height: HandySpace.l),
        HandyField(
          label: tr(context, 'Notes', 'Ghi chú'),
          child: TextField(
            key: const Key('box-notes'),
            controller: notes,
            enabled: !busy,
            maxLines: 3,
            maxLength: 10000,
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
      ],
    ),
  );
}
