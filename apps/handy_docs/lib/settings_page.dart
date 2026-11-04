import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_storage/history_page.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_ui/kit.dart';
import 'scope.dart';

const docsTools = {'md-html', 'md-text', 'md-source', qrTransferFlag};

/// Kept in the favourites list when "send a file by moving QR codes" is
/// switched on. Experimental and off by default since 2026-11-04: it has
/// not been tried with a real receiving phone.
const qrTransferFlag = 'qr-transfer';

/// Steps a saved recipe may hold. Text workflows left Docs on 2026-11-03
/// (Tools transforms text); recipes saved before then still load and are
/// kept as they are.
const docsWorkflowSteps = {'md-text'};

/// Docs settings: the shared page, plus text workflows, the export history
/// and the saved copies each library keeps.
class DocsSettingsPage extends StatelessWidget {
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final DocsScope scope;
  const DocsSettingsPage({
    super.key,
    required this.read,
    required this.save,
    required this.scope,
  });

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  Widget _recover(
    BuildContext context,
    String key,
    String title,
    DocumentRepository documents,
    Future<void> Function() reload,
  ) {
    if (documents is! RecoverableDocuments) return const SizedBox.shrink();
    return HandyTile(
      key: Key(key),
      icon: Icons.restore,
      title: title,
      navigates: true,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute<bool>(
            builder: (_) =>
                DocumentRecoveryPage(documents: documents, files: scope.files),
          ),
        );
        await reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) => HandySettingsPage(
    appName: 'Handy Docs',
    theme: read().theme,
    locale: read().locale,
    onTheme: (v) => save(read().copyWith(theme: v)),
    onLocale: (v) => save(read().copyWith(locale: v)),
    sections: [
      if (scope.autoBackup != null)
        HandyAutoBackupSection(backup: scope.autoBackup!),
      HandySettingsSection(
        title: tr(context, 'Text and files', 'Văn bản và tệp'),
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
            onTap: () => _push(
              context,
              ExportHistoryPage(
                history: scope.draft.history,
                files: scope.files,
              ),
            ),
          ),
        ],
      ),
      HandySettingsSection(
        title: tr(context, 'Experimental', 'Thử nghiệm'),
        description: tr(
          context,
          'Not tried on real phones yet; may not work in every light or on every camera.',
          'Chưa thử trên điện thoại thật; có thể chưa chạy được với mọi ánh sáng, mọi camera.',
        ),
        children: [
          StatefulBuilder(
            builder: (context, setState) {
              final on = read().favorites.contains(qrTransferFlag);
              return SwitchListTile(
                key: const Key('experimental-qr-transfer'),
                value: on,
                title: Text(
                  tr(
                    context,
                    'Send a file by moving QR codes',
                    'Gửi tệp bằng mã QR chạy',
                  ),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Shows "Send to another device" on the desk',
                    'Hiện "Gửi sang máy khác" trên bàn làm việc',
                  ),
                ),
                onChanged: (v) async {
                  final now = read().favorites.toSet();
                  v ? now.add(qrTransferFlag) : now.remove(qrTransferFlag);
                  await save(read().copyWith(favorites: now));
                  setState(() {});
                },
              );
            },
          ),
        ],
      ),
      HandySettingsSection(
        title: tr(context, 'Saved copies', 'Bản lưu dự phòng'),
        description: tr(
          context,
          'If a library cannot be opened, an earlier copy kept on this device can bring it back.',
          'Nếu một thư viện không mở được, bản lưu trước đó trên máy có thể khôi phục nó.',
        ),
        children: [
          _recover(
            context,
            'recover-scan',
            tr(context, 'Scan pages', 'Các trang quét'),
            scope.scan.documents,
            scope.scan.load,
          ),
          _recover(
            context,
            'recover-draft',
            tr(context, 'Markdown draft', 'Bản nháp Markdown'),
            scope.draft.documents,
            scope.draft.load,
          ),
          _recover(
            context,
            'recover-reader',
            tr(context, 'Kept files', 'Tệp đã giữ'),
            scope.reader.store.documents,
            scope.reader.store.load,
          ),
          _recover(
            context,
            'recover-signatures',
            tr(context, 'Saved signatures', 'Chữ ký đã lưu'),
            scope.signatures.documents,
            scope.signatures.load,
          ),
        ],
      ),
    ],
    onExportSettings: (context) async {
      final uri = await scope.files.exportText(
        'handy-docs-settings.json',
        exportPreferences(
          read(),
          app: 'docs',
          includeDrafts: false,
          knownTools: docsTools,
          workflowSteps: docsWorkflowSteps,
        ),
      );
      if (uri == null || !context.mounted) return null;
      return tr(context, 'Settings exported.', 'Đã xuất cài đặt.');
    },
    onImportSettings: (context) async {
      final file = await scope.files.importText();
      if (file == null || !context.mounted) return null;
      final incoming = importPreferences(
        file.text,
        app: 'docs',
        knownTools: docsTools,
        workflowSteps: docsWorkflowSteps,
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
          'Theme, language and text workflows come from the file. Your documents and saved inputs stay as they are.',
          'Giao diện, ngôn ngữ và quy trình văn bản lấy từ file. Tài liệu và nội dung đã lưu giữ nguyên.',
        ),
        confirmLabel: tr(context, 'Replace', 'Thay'),
      );
      if (!ok || !context.mounted) return null;
      await save(incoming.copyWith(drafts: read().drafts));
      return context.mounted
          ? tr(context, 'Settings restored.', 'Đã khôi phục cài đặt.')
          : null;
    },
    onReset: () => save(HandyPreferences()),
  );
}
