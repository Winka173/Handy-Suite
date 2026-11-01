import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import 'box/box_dialog.dart';
import 'inventory/keep_store.dart';
import 'inventory/whereabouts.dart';
import 'item/asset_editor.dart';
import 'item/lend_dialog.dart';
import 'labels.dart';
import 'ui/words.dart';

/// What every Keep screen shares: the store, the file and camera adapters,
/// and the actions that open editors and dialogs.
class KeepScope {
  final KeepStore store;
  final HandyFiles files;
  final ScanCamera? camera;
  const KeepScope({required this.store, required this.files, this.camera});

  KeepState get state => store.state!;

  /// Adds an item (pre-filled from a search or a box) or edits one.
  Future<void> edit(
    BuildContext context, {
    InventoryAsset? item,
    String name = '',
    String box = '',
  }) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      fullscreenDialog: item == null,
      builder: (_) => AssetEditor(
        asset: item,
        boxes: state.boxes,
        locations: knownLocations(state),
        files: files,
        camera: camera,
        blobs: store.library!.blobs,
        initialName: name,
        initialBox: box,
        onCommit: store.saveItem,
      ),
    ),
  );

  Future<void> editBox(BuildContext context, [InventoryBox? box]) =>
      showBoxDialog(context, box: box, onCommit: store.saveBoxRecord);

  Future<void> lend(BuildContext context, InventoryAsset item) =>
      showLendDialog(
        context,
        item: item,
        onCommit: (who, on, due) => store.lend(item.id, who, on, due),
      );

  Future<void> giveBack(BuildContext context, InventoryAsset item) =>
      _run(context, () => store.giveBack(item.id), (c) {
        return tr(c, '${item.name} is back.', 'Đã nhận lại ${item.name}.');
      });

  Future<void> label(BuildContext context, InventoryLabel target) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              InventoryLabelPage(label: target, inventory: state, files: files),
        ),
      );

  /// Deletes after a confirmation that names the item. True when deleted.
  Future<bool> delete(BuildContext context, InventoryAsset item) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete ${item.name}?', 'Xóa ${item.name}?'),
      message: tr(
        context,
        'Its photo and receipts go with it. Export a backup first if you may need them.',
        'Ảnh và hóa đơn của món này cũng bị xóa. Hãy xuất bản sao lưu trước nếu còn cần.',
      ),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    return _run(context, () => store.removeItem(item.id), null);
  }

  Future<bool> deleteBox(BuildContext context, InventoryBox box) async {
    final count = assetsInBox(state, box.id).length;
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete ${box.name}?', 'Xóa ${box.name}?'),
      message: count == 0
          ? null
          : tr(
              context,
              'The ${itemCount(context, count)} inside stay in Keep, out of any box.',
              '${itemCount(context, count)} bên trong vẫn còn, chỉ không còn trong thùng.',
            ),
      confirmLabel: tr(context, 'Delete box', 'Xóa thùng'),
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    return _run(context, () => store.removeBoxRecord(box.id), null);
  }

  /// Runs a write; says what happened, or that nothing changed.
  Future<bool> _run(
    BuildContext context,
    Future<void> Function() task,
    String Function(BuildContext)? done,
  ) async {
    try {
      await task();
      if (done != null && context.mounted) {
        showHandyMessage(context, done(context));
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            'Not saved: ${errorText(context, e)}. Nothing changed.',
            'Chưa lưu được: ${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
      }
      return false;
    }
  }
}
