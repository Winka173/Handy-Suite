part of '../handy_inventory.dart';

/// Compatible with the original printed Handy Keep labels. Only IDs are encoded.
class InventoryLabel {
  final String kind, id;
  InventoryLabel(this.kind, String id) : id = _id(id) {
    if (!{'item', 'box'}.contains(kind))
      throw const FormatException('Invalid label kind');
  }
  factory InventoryLabel.parse(String value) {
    if (value.length > 300) throw const FormatException('Label is too long');
    final match = RegExp(
      r'^handy-keep://(item|box)/([a-zA-Z0-9_-]{1,100})$',
    ).firstMatch(value.trim());
    if (match == null)
      throw const FormatException('This is not a Handy Keep item or box label');
    return InventoryLabel(match[1]!, match[2]!);
  }
  String get url => 'handy-keep://$kind/$id';
  Object resolve(KeepState state) {
    if (kind == 'item') {
      for (final asset in state.assets) {
        if (asset.id == id) return asset;
      }
    } else {
      for (final box in state.boxes) {
        if (box.id == id) return box;
      }
    }
    throw const FormatException(
      'This item or box is not in the inventory on this device',
    );
  }
}

String itemDossier(InventoryAsset asset, KeepState state) {
  String shown(String value) => value.isEmpty ? '—' : value;
  var boxName = '';
  for (final box in state.boxes) {
    if (box.id == asset.boxId) boxName = box.name;
  }
  return [
    'Handy Keep — Item record / Hồ sơ đồ dùng',
    '',
    asset.name,
    'Location / Vị trí: ${shown(asset.location)}',
    'Serial: ${shown(asset.serial)}',
    'Purchased / Ngày mua: ${shown(asset.purchasedOn)}',
    'Warranty / Bảo hành: ${shown(asset.warrantyUntil)}',
    'Maintenance / Bảo dưỡng: ${shown(asset.maintenanceDue)}',
    'Box / Thùng: ${shown(boxName)}',
    'Borrower / Người mượn: ${shown(asset.borrower)}',
    'Lent / Ngày mượn: ${shown(asset.lentOn)}',
    'Return due / Hẹn trả: ${shown(asset.returnDue)}',
    '',
    'Notes / Ghi chú',
    shown(asset.notes),
    '',
    InventoryLabel('item', asset.id).url,
    '',
    'Photos are not included. / Không kèm file ảnh.',
    'Review personal details before sharing. / Kiểm tra thông tin cá nhân trước khi chia sẻ.',
  ].join('\n');
}
