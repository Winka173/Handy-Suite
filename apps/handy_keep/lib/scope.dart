import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import 'batch/batch_page.dart';
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

  /// Automatic backups to a folder; null in tests that do not need them.
  final HandyAutoBackup? autoBackup;
  const KeepScope({
    required this.store,
    required this.files,
    this.camera,
    this.autoBackup,
  });

  KeepState get state => store.state!;

  /// Adds an item (pre-filled from a search or a box) or edits one.
  Future<void> edit(
    BuildContext context, {
    InventoryAsset? item,
    String name = '',
    String box = '',
    String price = '',
    String currency = '',
    String purchasedOn = '',
    List<String> collections = const [],
    String status = 'owned',
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
        initialPrice: price,
        initialPurchasedOn: purchasedOn,
        currency: currency.isNotEmpty
            ? currency
            : startCurrency(context, state),
        onCommit: store.saveItem,
        collections: state.collections,
        initialCollections: collections,
        initialStatus: status,
      ),
    ),
  );

  /// Adds several items from photos, all saved in one write. [box] puts
  /// them all in that box to start with.
  Future<void> batchAdd(BuildContext context, {String box = ''}) async {
    final saved = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BatchAddPage(
          boxes: state.boxes,
          locations: knownLocations(state),
          files: files,
          camera: camera,
          initialBox: box,
          onCommit: store.saveItems,
        ),
      ),
    );
    if (saved != null && context.mounted) {
      showHandyMessage(
        context,
        tr(
          context,
          saved == 1 ? '1 item added.' : '$saved items added.',
          'Đã thêm $saved món.',
        ),
      );
    }
  }

  /// Saves [items] as a CSV file for a spreadsheet. The inventory is only
  /// read; the file is a copy.
  Future<void> exportCsv(BuildContext context, List<InventoryAsset> items) =>
      _run(
        context,
        () async {
          final csv = keepCsv(
            state,
            items,
            headers: [
              tr(context, 'Name', 'Tên'),
              tr(context, 'Kept at', 'Cất ở'),
              tr(context, 'Box', 'Thùng'),
              tr(context, 'Borrower', 'Người mượn'),
              tr(context, 'Lent on', 'Ngày cho mượn'),
              tr(context, 'Back by', 'Hẹn trả'),
              tr(context, 'Bought on', 'Ngày mua'),
              tr(context, 'Price', 'Giá mua'),
              tr(context, 'Currency', 'Tiền tệ'),
              tr(context, 'Warranty until', 'Bảo hành đến'),
              tr(context, 'Serial', 'Số serial'),
              tr(context, 'Notes', 'Ghi chú'),
            ],
          );
          final uri = await files.exportBytes(
            'handy-keep-items.csv',
            Uint8List.fromList(utf8.encode(csv)),
            mimeType: 'text/csv',
          );
          if (uri == null) throw const _Cancelled();
        },
        (c) => tr(
          c,
          items.length == 1
              ? '1 item saved as CSV.'
              : '${items.length} items saved as CSV.',
          'Đã lưu ${items.length} món ra file CSV.',
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

  Future<void> restock(BuildContext context, InventoryAsset item) => _run(
    context,
    () => store.restock(item.id),
    (c) => tr(
      c,
      'Noted: ${item.name} bought again today.',
      'Đã ghi: hôm nay mua thêm ${item.name}.',
    ),
  );

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
    } on _Cancelled {
      return false;
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

/// The person closed a save dialog: nothing to report.
class _Cancelled implements Exception {
  const _Cancelled();
}
