import 'dart:convert';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_storage/history_page.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_ui/kit.dart';
import 'capture_library.dart';
import 'studio/media_store.dart';

/// The subtitle tools moved to Handy Tools. Settings saved by older
/// versions may still pin them or hold their inputs, so their ids stay
/// readable here; "Clear saved inputs" removes what is left of them.
const mediaTools = {'subtitle-srt', 'subtitle-vtt'};

/// Whether older settings still hold subtitle inputs or pins.
bool hasLeftoverInputs(HandyPreferences p) =>
    p.drafts.isNotEmpty || p.favorites.isNotEmpty;

/// Media settings: the shared page, the export history and the saved
/// copies of the guide library.
class MediaSettingsPage extends StatelessWidget {
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final HandyFiles files;
  final MediaStore store;
  final ExportHistory history;
  final HandyAutoBackup? autoBackup;
  const MediaSettingsPage({
    super.key,
    required this.read,
    required this.save,
    required this.files,
    required this.store,
    required this.history,
    this.autoBackup,
  });

  /// A library from an automatic backup (plain or password-locked), read
  /// and checked whole before it replaces the guides here.
  Future<void> _restore(BuildContext context) async {
    final file = await files.importBytes(
      extensions: ['json', 'hseal'],
      maxBytes: 40000000,
    );
    if (file == null || !context.mounted) return;
    final bytes = await openSealedBackup(context, file.bytes);
    if (bytes == null || !context.mounted) return;
    final CaptureLibrary library;
    try {
      library = CaptureLibrary.parse(utf8.decode(bytes));
    } catch (e) {
      showHandyMessage(
        context,
        tr(
          context,
          'Not a Handy Media library. Nothing changed.',
          'Không phải thư viện Handy Media. Không có gì thay đổi.',
        ),
      );
      return;
    }
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Replace your guides?', 'Thay các hướng dẫn hiện có?'),
      message: tr(
        context,
        'The backup holds ${library.projects.length} guides. The guides here now are replaced; an earlier copy stays under "Bring back an earlier library".',
        'Bản sao lưu có ${library.projects.length} hướng dẫn. Các hướng dẫn hiện có sẽ bị thay; bản trước vẫn nằm trong "Khôi phục thư viện trước đó".',
      ),
      confirmLabel: tr(context, 'Replace', 'Thay thế'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await store.commit(library);
    if (context.mounted)
      showHandyMessage(
        context,
        tr(context, 'Library restored.', 'Đã khôi phục thư viện.'),
      );
  }

  @override
  Widget build(BuildContext context) {
    final DocumentRepository docs = store.documents;
    return HandySettingsPage(
      appName: 'Handy Media',
      theme: read().theme,
      locale: read().locale,
      onTheme: (v) => save(read().copyWith(theme: v)),
      onLocale: (v) => save(read().copyWith(locale: v)),
      sections: [
        if (autoBackup != null) HandyAutoBackupSection(backup: autoBackup!),
        HandySettingsSection(
          title: tr(context, 'Files', 'Tệp'),
          children: [
            HandyTile(
              key: const Key('restore-library'),
              icon: Icons.unarchive_outlined,
              title: tr(
                context,
                'Restore guides from a backup',
                'Khôi phục hướng dẫn từ bản sao lưu',
              ),
              onTap: () => _restore(context),
            ),
            HandyTile(
              key: const Key('open-export-history'),
              icon: Icons.history,
              title: tr(context, 'Export history', 'Lịch sử xuất file'),
              subtitle: tr(
                context,
                'Files you exported; their contents are not kept',
                'Các tệp đã xuất; không giữ nội dung',
              ),
              navigates: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ExportHistoryPage(history: history, files: files),
                ),
              ),
            ),
            if (docs is RecoverableDocuments)
              HandyTile(
                key: const Key('recover-guides'),
                icon: Icons.restore,
                title: tr(
                  context,
                  'Bring back an earlier library',
                  'Khôi phục thư viện trước đó',
                ),
                navigates: true,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) =>
                          DocumentRecoveryPage(documents: docs, files: files),
                    ),
                  );
                  await store.load();
                },
              ),
          ],
        ),
      ],
      onExportSettings: (context) async {
        final uri = await files.exportText(
          'handy-media-settings.json',
          exportPreferences(
            read(),
            app: 'media',
            includeDrafts: false,
            knownTools: mediaTools,
            workflowSteps: {},
          ),
        );
        if (uri == null || !context.mounted) return null;
        return tr(context, 'Settings exported.', 'Đã xuất cài đặt.');
      },
      onImportSettings: (context) async {
        final file = await files.importText();
        if (file == null || !context.mounted) return null;
        final incoming = importPreferences(
          file.text,
          app: 'media',
          knownTools: mediaTools,
          workflowSteps: {},
        );
        final ok = await confirmHandy(
          context,
          title: tr(
            context,
            'Replace current settings?',
            'Thay cài đặt hiện tại?',
          ),
          message: tr(
            context,
            'Theme and language come from the file. Your guides and saved inputs stay as they are.',
            'Giao diện và ngôn ngữ lấy từ file. Hướng dẫn và nội dung đã lưu giữ nguyên.',
          ),
          confirmLabel: tr(context, 'Replace', 'Thay'),
        );
        if (!ok || !context.mounted) return null;
        await save(incoming.copyWith(drafts: read().drafts));
        return context.mounted
            ? tr(context, 'Settings restored.', 'Đã khôi phục cài đặt.')
            : null;
      },
      onClearInputs: hasLeftoverInputs(read())
          ? () => save(read().copyWith(drafts: {}, favorites: []))
          : null,
      onReset: () => save(HandyPreferences()),
    );
  }
}
