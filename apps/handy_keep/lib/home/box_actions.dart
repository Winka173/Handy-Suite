import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

/// A box's menu: pack one thing or several (from photos) into it, print its
/// label, rename, delete.
List<HandyMenuItem> boxActions(
  BuildContext context,
  KeepScope scope,
  InventoryBox b, {
  required VoidCallback onDeleted,
}) => [
  HandyMenuItem(
    Icons.add,
    tr(context, 'Add an item to it', 'Thêm đồ vào thùng'),
    () => scope.edit(context, box: b.id),
    key: const Key('box-add-item'),
  ),
  HandyMenuItem(
    Icons.add_photo_alternate_outlined,
    tr(context, 'Pack several from photos', 'Thêm nhiều món từ ảnh'),
    () => scope.batchAdd(context, box: b.id),
    key: const Key('box-batch-add'),
  ),
  HandyMenuItem(
    Icons.qr_code_2,
    tr(context, 'QR label', 'Nhãn QR'),
    () => scope.label(context, InventoryLabel('box', b.id)),
    key: const Key('box-label'),
  ),
  HandyMenuItem(
    Icons.edit_outlined,
    tr(context, 'Edit box', 'Sửa thùng'),
    () => scope.editBox(context, b),
    key: const Key('box-edit'),
  ),
  HandyMenuItem(
    Icons.delete_outline,
    tr(context, 'Delete box', 'Xóa thùng'),
    () async {
      if (await scope.deleteBox(context, b)) onDeleted();
    },
    key: const Key('box-delete'),
    destructive: true,
  ),
];
