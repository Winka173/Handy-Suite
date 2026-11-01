import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_storage/history_page.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_ui/kit.dart';
import 'studio/media_store.dart';

const mediaTools = {'subtitle-srt', 'subtitle-vtt'};

/// Media settings: the shared page, the export history and the saved
/// copies of the guide library.
class MediaSettingsPage extends StatelessWidget {
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final HandyFiles files;
  final MediaStore store;
  final ExportHistory history;
  const MediaSettingsPage({
    super.key,
    required this.read,
    required this.save,
    required this.files,
    required this.store,
    required this.history,
  });

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
        HandySettingsSection(
          title: tr(context, 'Files', 'Tệp'),
          children: [
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
      onClearInputs: () => save(read().copyWith(drafts: {})),
      onReset: () => save(HandyPreferences()),
    );
  }
}
