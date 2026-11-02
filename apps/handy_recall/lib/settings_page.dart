import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_notifications/controller.dart';
import 'package:handy_notifications/section.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'scope.dart';

/// Recall's settings: the shared page with the daily reminder, backups and,
/// last, deleting all study data.
class RecallSettingsPage extends StatelessWidget {
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final RecallScope scope;
  final ReminderController reminders;
  const RecallSettingsPage({
    super.key,
    required this.read,
    required this.save,
    required this.scope,
    required this.reminders,
  });

  Future<String?> _export(BuildContext context) async {
    final uri = await scope.files.exportBytes(
      'handy-recall-backup.json',
      Uint8List.fromList(utf8.encode(exportRecallBackup(scope.state))),
      mimeType: 'application/json',
    );
    return uri == null || !context.mounted
        ? null
        : tr(context, 'Backup saved.', 'Đã lưu bản sao lưu.');
  }

  Future<String?> _restore(BuildContext context) async {
    final file = await scope.files.importBytes(
      extensions: ['json', 'hseal'],
      maxBytes: recallBackupBytes,
    );
    if (file == null || !context.mounted) return null;
    // A password-locked automatic backup opens to the same JSON.
    final bytes = await openSealedBackup(context, file.bytes);
    if (bytes == null || !context.mounted) return null;
    final next = parseRecallBackup(utf8.decode(bytes));
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Replace your library?', 'Thay thư viện hiện có?'),
      message: tr(
        context,
        'The backup holds ${next.decks.length} decks and ${next.cards.length} cards, with their review history.',
        'Bản sao lưu có ${next.decks.length} bộ và ${next.cards.length} thẻ, kèm lịch sử ôn.',
      ),
      confirmLabel: tr(context, 'Replace', 'Thay thế'),
    );
    if (!ok) return null;
    await scope.store.commit(next);
    return context.mounted
        ? tr(context, 'Library restored.', 'Đã khôi phục thư viện.')
        : null;
  }

  Future<String?> _deleteAll(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete all study data?', 'Xóa toàn bộ dữ liệu học?'),
      message: tr(
        context,
        'Every deck, card and review history on this device. Save a backup first if you may want it back.',
        'Mọi bộ thẻ, thẻ và lịch sử ôn trên máy này. Hãy lưu bản sao lưu trước nếu có thể cần lại.',
      ),
      confirmLabel: tr(context, 'Delete everything', 'Xóa hết'),
      destructive: true,
    );
    if (!ok) return null;
    await scope.store.commit(emptyRecallState());
    return context.mounted
        ? tr(context, 'Study data deleted.', 'Đã xóa dữ liệu học.')
        : null;
  }

  Future<void> _do(
    BuildContext context,
    Future<String?> Function(BuildContext) task,
  ) async {
    try {
      final m = await task(context);
      if (m != null && context.mounted) showHandyMessage(context, m);
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

  @override
  Widget build(BuildContext context) => HandySettingsPage(
    appName: 'Handy Recall',
    theme: read().theme,
    locale: read().locale,
    onTheme: (v) => save(read().copyWith(theme: v)),
    onLocale: (v) => save(read().copyWith(locale: v)),
    sections: [
      RemindersSection(
        reminders: reminders,
        title: (c) => tr(c, 'Daily review', 'Nhắc ôn hằng ngày'),
        description: (c) => tr(
          c,
          'One notification a day at the time you pick. Nothing leaves this device.',
          'Mỗi ngày một thông báo vào giờ bạn chọn. Không có gì rời khỏi máy.',
        ),
      ),
      if (scope.autoBackup != null)
        HandyAutoBackupSection(backup: scope.autoBackup!),
      HandySettingsSection(
        title: tr(context, 'Your library', 'Thư viện học'),
        description: tr(
          context,
          'A backup keeps decks, cards, pictures and every review.',
          'Bản sao lưu giữ bộ thẻ, thẻ, ảnh và toàn bộ lịch sử ôn.',
        ),
        children: [
          HandyTile(
            key: const Key('recall-export'),
            icon: Icons.archive_outlined,
            title: tr(context, 'Save a backup', 'Lưu bản sao lưu'),
            subtitle: 'JSON',
            onTap: () => _do(context, _export),
          ),
          HandyTile(
            key: const Key('recall-restore'),
            icon: Icons.unarchive_outlined,
            title: tr(context, 'Restore a backup', 'Khôi phục bản sao lưu'),
            onTap: () => _do(context, _restore),
          ),
          HandyTile(
            key: const Key('recall-delete-all'),
            icon: Icons.delete_forever_outlined,
            title: tr(
              context,
              'Delete all study data',
              'Xóa toàn bộ dữ liệu học',
            ),
            destructive: true,
            onTap: () => _do(context, _deleteAll),
          ),
        ],
      ),
    ],
    onExportSettings: (context) async {
      final uri = await scope.files.exportText(
        'handy-recall-settings.json',
        exportPreferences(
          read(),
          app: 'recall',
          knownTools: {},
          workflowSteps: {},
        ),
      );
      if (uri == null || !context.mounted) return null;
      return tr(context, 'Settings exported.', 'Đã xuất cài đặt.');
    },
    onImportSettings: (context) async {
      final file = await scope.files.importText();
      if (file == null || !context.mounted) return null;
      await save(
        importPreferences(
          file.text,
          app: 'recall',
          knownTools: {},
          workflowSteps: {},
        ),
      );
      return context.mounted
          ? tr(context, 'Settings restored.', 'Đã khôi phục cài đặt.')
          : null;
    },
    onReset: () => save(HandyPreferences()),
  );
}
