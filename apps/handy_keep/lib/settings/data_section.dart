import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../library.dart';
import '../inventory/whereabouts.dart';
import '../scope.dart';
import '../ui/words.dart';

/// Backups. A file is read and checked whole before anything is written;
/// cancel or a bad file leaves the inventory as it was.
class DataSection extends StatelessWidget {
  final KeepScope scope;
  const DataSection({super.key, required this.scope});

  Future<void> _do(
    BuildContext context,
    Future<String?> Function() task,
  ) async {
    try {
      final message = await task();
      if (message != null && context.mounted)
        showHandyMessage(context, message);
    } catch (e) {
      if (context.mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            '${errorText(context, e)}. Nothing changed.',
            '${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
      }
    }
  }

  Future<String?> _exportZip(BuildContext context) async {
    final uri = await scope.files.exportBytes(
      'handy-keep-backup.zip',
      scope.store.library!.portable(),
      mimeType: 'application/zip',
    );
    return uri == null || !context.mounted
        ? null
        : tr(context, 'Backup saved.', 'Đã lưu bản sao lưu.');
  }

  Future<String?> _restoreZip(BuildContext context) async {
    final file = await scope.files.importBytes(
      extensions: ['zip', 'hseal'],
      maxBytes: 30000000,
    );
    if (file == null || !context.mounted) return null;
    // A password-locked automatic backup opens to the same ZIP.
    final bytes = await openSealedBackup(context, file.bytes);
    if (bytes == null || !context.mounted) return null;
    final incoming = InventoryLibrary.fromPortable(bytes);
    if (!context.mounted) return null;
    final s = incoming.state;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr(context, 'Restore this backup?', 'Khôi phục bản sao lưu này?'),
        ),
        content: Text(
          tr(
            context,
            'It holds ${itemCount(context, s.assets.length)} and ${s.boxes.length} boxes.\n\nAdd: puts them next to what you have; refused if any is already here.\nReplace: what you have now is swapped for the backup.',
            'File có ${itemCount(context, s.assets.length)} và ${s.boxes.length} thùng.\n\nGộp: thêm vào danh sách hiện có; từ chối nếu có món trùng.\nThay thế: danh sách hiện có được thay bằng bản sao lưu.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          TextButton(
            key: const Key('restore-merge'),
            onPressed: () => Navigator.pop(context, 'merge'),
            child: Text(tr(context, 'Add', 'Gộp')),
          ),
          FilledButton(
            key: const Key('restore-replace'),
            onPressed: () => Navigator.pop(context, 'replace'),
            child: Text(tr(context, 'Replace', 'Thay thế')),
          ),
        ],
      ),
    );
    if (choice == null) return null;
    await (choice == 'merge'
        ? scope.store.merge(incoming)
        : scope.store.replace(incoming));
    return context.mounted
        ? tr(context, 'Backup restored.', 'Đã khôi phục.')
        : null;
  }

  Future<String?> _exportJson(BuildContext context) async {
    final uri = await scope.files.exportBytes(
      'handy-keep-records.json',
      Uint8List.fromList(utf8.encode(exportKeepBackup(scope.state))),
      mimeType: 'application/json',
    );
    return uri == null || !context.mounted
        ? null
        : tr(context, 'List saved.', 'Đã lưu danh sách.');
  }

  Future<String?> _restoreJson(BuildContext context) async {
    final file = await scope.files.importText(maxBytes: 8000000);
    if (file == null || !context.mounted) return null;
    final next = parseKeepBackup(file.text);
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Replace the list?', 'Thay danh sách?'),
      message: tr(
        context,
        'The file holds ${itemCount(context, next.assets.length)}, without photos or receipts.',
        'File có ${itemCount(context, next.assets.length)}, không kèm ảnh và hóa đơn.',
      ),
      confirmLabel: tr(context, 'Replace', 'Thay thế'),
    );
    if (!ok) return null;
    await scope.store.commit(next);
    return context.mounted
        ? tr(context, 'List restored.', 'Đã khôi phục danh sách.')
        : null;
  }

  @override
  Widget build(BuildContext context) => HandySettingsSection(
    title: tr(context, 'Your inventory', 'Dữ liệu đồ dùng'),
    description: tr(
      context,
      'Everything stays on this device. A backup is the only copy anywhere else.',
      'Mọi thứ chỉ nằm trên máy này. Bản sao lưu là bản duy nhất ở nơi khác.',
    ),
    children: [
      HandyTile(
        key: const Key('keep-export-zip'),
        icon: Icons.archive_outlined,
        title: tr(context, 'Save a backup', 'Lưu bản sao lưu'),
        subtitle: tr(
          context,
          'ZIP with photos and receipts',
          'File ZIP kèm ảnh và hóa đơn',
        ),
        onTap: () => _do(context, () => _exportZip(context)),
      ),
      HandyTile(
        key: const Key('keep-restore-zip'),
        icon: Icons.unarchive_outlined,
        title: tr(context, 'Restore a backup', 'Khôi phục bản sao lưu'),
        subtitle: tr(
          context,
          'Add to or replace what is here',
          'Gộp hoặc thay danh sách hiện có',
        ),
        onTap: () => _do(context, () => _restoreZip(context)),
      ),
      HandyTile(
        key: const Key('keep-export-json'),
        icon: Icons.data_object,
        title: tr(context, 'Save the list as JSON', 'Lưu danh sách dạng JSON'),
        subtitle: tr(
          context,
          'Records only, no photos',
          'Chỉ thông tin, không kèm ảnh',
        ),
        onTap: () => _do(context, () => _exportJson(context)),
      ),
      HandyTile(
        key: const Key('keep-export-csv'),
        icon: Icons.table_view_outlined,
        title: tr(
          context,
          'Save the list for a spreadsheet',
          'Lưu danh sách cho bảng tính',
        ),
        subtitle: tr(
          context,
          'CSV for Excel or Sheets: every item, with place, box, price and warranty',
          'File CSV mở bằng Excel, Sheets: mọi món, kèm chỗ để, thùng, giá và bảo hành',
        ),
        onTap: () => scope.exportCsv(context, [
          for (final p in whereabouts(scope.state, scope.state.assets))
            ...p.items,
        ]),
      ),
      HandyTile(
        key: const Key('keep-restore-json'),
        icon: Icons.history,
        title: tr(
          context,
          'Restore an old JSON list',
          'Khôi phục danh sách JSON cũ',
        ),
        onTap: () => _do(context, () => _restoreJson(context)),
      ),
    ],
  );
}
