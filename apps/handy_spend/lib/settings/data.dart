import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ledger/export.dart';
import '../scope.dart';

SpendState _restoreBytes(Map<String, dynamic> input) =>
    restore(input['bytes'] as Uint8List, zip: input['zip'] as bool);
Uint8List _backupState(Map<String, dynamic> json) =>
    backup(SpendState.fromJson(json));

/// The whole ledger as a checked ZIP. Returns a message, or null when the
/// person backed out.
Future<String?> backupZip(BuildContext context, SpendScope scope) async {
  if (!await confirmExport(context)) return null;
  final bytes = await compute(_backupState, scope.state.toJson());
  if (bytes.length > 30000000)
    throw const FormatException('Backup exceeds 30MB / Bản sao lưu vượt 30MB');
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

/// Reads a backup in full, says what it holds, asks twice, then replaces
/// the ledger in one change (which Undo can take back).
Future<String?> restoreBackup(BuildContext context, SpendScope scope) async {
  final file = await scope.files.importBytes(
    extensions: ['zip', 'json'],
    maxBytes: 30000000,
  );
  if (file == null || !context.mounted) return null;
  final restored = await compute(_restoreBytes, {
    'bytes': file.bytes,
    'zip': file.name.toLowerCase().endsWith('.zip'),
  });
  if (!context.mounted) return null;
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
      'The backup holds ${restored.accounts.length} accounts and ${restored.entries.length} entries. It replaces everything here; Undo can take it back until the next change.',
      'Bản sao lưu có ${restored.accounts.length} tài khoản và ${restored.entries.length} giao dịch. Nó thay toàn bộ dữ liệu ở đây; có thể Hoàn tác trước thay đổi kế tiếp.',
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
  await scope.controller.change((s) {
    if (s.revision != revision) throw StateError('Data changed during review');
    return dropLock
        ? restored.copy({
            'settings': {...restored.settings, 'deviceLock': false},
          })
        : restored;
  }, 'restore_backup');
  return context.mounted
      ? tr(context, 'Backup restored.', 'Đã khôi phục.')
      : null;
}
