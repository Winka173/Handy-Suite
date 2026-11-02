import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ledger/export.dart';
import '../scope.dart';

RestoredBackup _restoreBytes(Map<String, dynamic> input) =>
    readBackup(input['bytes'] as Uint8List, zip: input['zip'] as bool);
Uint8List _backupState(Map<String, dynamic> input) => backup(
  SpendState.fromJson(Map<String, dynamic>.from(input['state'] as Map)),
  receipts: Map<String, Uint8List>.from(input['receipts'] as Map),
);

/// The whole ledger as a checked ZIP, every receipt file inside it.
/// Returns a message, or null when the person backed out.
Future<String?> backupZip(BuildContext context, SpendScope scope) async {
  if (!await confirmExport(context)) return null;
  final bytes = await spendBackupBytes(scope);
  final result = await scope.files.exportBytes(
    'handy-spend-${DateTime.now().millisecondsSinceEpoch}.zip',
    bytes,
    mimeType: 'application/zip',
  );
  if (result == null || !context.mounted) return null;
  return kIsWeb
      ? tr(
          context,
          'Download requested; check the saved file.',
          'Đã yêu cầu tải; hãy kiểm tra file đã lưu.',
        )
      : tr(context, 'Backup saved.', 'Đã lưu bản sao lưu.');
}

/// The backup ZIP's bytes; also what automatic backups write.
Future<Uint8List> spendBackupBytes(SpendScope scope) async {
  final state = scope.state, receipts = <String, Uint8List>{};
  for (final r in state.receipts) {
    final bytes = await scope.controller.receiptBytes(r.id);
    if (bytes == null)
      throw FormatException(
        'The file for receipt ${r.name} is missing; nothing was exported / Thiếu file hóa đơn ${r.name}; chưa xuất gì',
      );
    receipts[r.id] = bytes;
  }
  final bytes = await compute(_backupState, {
    'state': state.toJson(),
    'receipts': receipts,
  });
  if (bytes.length > backupLimit)
    throw const FormatException('Backup exceeds 85MB / Bản sao lưu vượt 85MB');
  return bytes;
}

/// Reads a backup in full, says what it holds, asks twice, then replaces
/// the ledger in one change (which Undo can take back).
Future<String?> restoreBackup(BuildContext context, SpendScope scope) async {
  final file = await scope.files.importBytes(
    extensions: ['zip', 'json', 'hseal'],
    maxBytes: backupLimit,
  );
  if (file == null || !context.mounted) return null;
  // A password-locked automatic backup opens to the same ZIP.
  final bytes = await openSealedBackup(context, file.bytes);
  if (bytes == null || !context.mounted) return null;
  final name = file.name.toLowerCase();
  final backup = await compute(_restoreBytes, {
    'bytes': bytes,
    'zip': name.endsWith('.zip') || name.endsWith('.zip.hseal'),
  });
  if (!context.mounted) return null;
  final restored = backup.state;
  final revision = scope.state.revision;
  final dropLock =
      !scope.privacy.supported && restored.settings['deviceLock'] == true;
  if (dropLock &&
      !await confirmHandy(
        context,
        title: tr(
          context,
          'No device lock here',
          'Không có khóa thiết bị ở đây',
        ),
        message: tr(
          context,
          'This platform cannot lock the app, so the restored lock setting is turned off here. The file itself is not encrypted.',
          'Nền tảng này không khóa được app nên cài đặt khóa sẽ tắt ở đây. File không được mã hóa.',
        ),
        confirmLabel: tr(context, 'Continue', 'Tiếp tục'),
      ))
    return null;
  if (!context.mounted) return null;
  if (!await confirmHandy(
    context,
    title: tr(context, 'Replace your ledger?', 'Thay sổ hiện tại?'),
    message: tr(
      context,
      'The backup holds ${restored.accounts.length} accounts, ${restored.entries.length} entries and ${restored.receipts.length} receipts. It replaces everything here; Undo can take it back until the next change.',
      'Bản sao lưu có ${restored.accounts.length} tài khoản, ${restored.entries.length} giao dịch và ${restored.receipts.length} hóa đơn. Nó thay toàn bộ dữ liệu ở đây; có thể Hoàn tác trước thay đổi kế tiếp.',
    ),
    confirmLabel: tr(context, 'Replace', 'Thay'),
    destructive: true,
  ))
    return null;
  if (!context.mounted) return null;
  if (!await confirmHandy(
    context,
    title: tr(context, 'Sure?', 'Chắc chắn?'),
    message: tr(
      context,
      'Keep the backup file you are restoring from.',
      'Hãy giữ lại file sao lưu bạn đang dùng.',
    ),
    confirmLabel: tr(context, 'Replace now', 'Thay ngay'),
    destructive: true,
  ))
    return null;
  // Receipt files first; the ledger that lists them replaces this one in
  // one change, so a failure leaves the ledger here as it was.
  await scope.controller.changeWithFiles(
    (s) {
      if (s.revision != revision)
        throw StateError('Data changed during review');
      return dropLock
          ? restored.copy({
              'settings': {...restored.settings, 'deviceLock': false},
            })
          : restored;
    },
    'restore_backup',
    files: backup.receipts,
  );
  return context.mounted
      ? tr(context, 'Backup restored.', 'Đã khôi phục.')
      : null;
}
