import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'app.dart';

/// Dev settings: the shared page. Backups never carry drafts; restoring
/// drops any sensitive tool's draft again.
class DevSettingsPage extends StatelessWidget {
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final HandyFiles files;
  const DevSettingsPage({
    super.key,
    required this.read,
    required this.save,
    required this.files,
  });

  @override
  Widget build(BuildContext context) => HandySettingsPage(
    appName: 'Handy Dev',
    theme: read().theme,
    locale: read().locale,
    onTheme: (v) => save(read().copyWith(theme: v)),
    onLocale: (v) => save(read().copyWith(locale: v)),
    onExportSettings: (context) async {
      final uri = await files.exportText(
        'handy-dev-settings.json',
        exportPreferences(
          read(),
          app: 'dev',
          includeDrafts: false,
          knownTools: devPreferenceIds,
          workflowSteps: devWorkflowIds,
        ),
      );
      if (uri == null || !context.mounted) return null;
      return tr(context, 'Settings exported.', 'Đã xuất cài đặt.');
    },
    onImportSettings: (context) async {
      final file = await files.importText();
      if (file == null || !context.mounted) return null;
      final incoming = safeDevPreferences(
        importPreferences(
          file.text,
          app: 'dev',
          // Files exported before the 2026-11-03 merge name old tool ids.
          knownTools: devStoredIds,
          workflowSteps: devWorkflowIds,
        ),
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
          'Theme, language, pins and chains come from the file. Saved drafts and requests stay as they are.',
          'Giao diện, ngôn ngữ, ghim và chuỗi lấy từ file. Nháp và request đã lưu giữ nguyên.',
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
