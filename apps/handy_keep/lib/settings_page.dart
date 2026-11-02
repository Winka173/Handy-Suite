import 'package:handy_notifications/controller.dart';
import 'package:handy_notifications/section.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'scope.dart';
import 'settings/data_section.dart';

/// Keep's settings: the shared page with reminders and backups added.
class KeepSettingsPage extends StatelessWidget {
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final KeepScope scope;
  final ReminderController reminders;
  const KeepSettingsPage({
    super.key,
    required this.read,
    required this.save,
    required this.scope,
    required this.reminders,
  });

  @override
  Widget build(BuildContext context) => HandySettingsPage(
    appName: 'Handy Keep',
    theme: read().theme,
    locale: read().locale,
    onTheme: (v) => save(read().copyWith(theme: v)),
    onLocale: (v) => save(read().copyWith(locale: v)),
    sections: [
      RemindersSection(reminders: reminders),
      if (scope.autoBackup != null)
        HandyAutoBackupSection(backup: scope.autoBackup!),
      DataSection(scope: scope),
    ],
    onExportSettings: (context) async {
      final uri = await scope.files.exportText(
        'handy-keep-settings.json',
        exportPreferences(
          read(),
          app: 'keep',
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
      final incoming = importPreferences(
        file.text,
        app: 'keep',
        knownTools: {},
        workflowSteps: {},
      );
      await save(incoming);
      return context.mounted
          ? tr(context, 'Settings restored.', 'Đã khôi phục cài đặt.')
          : null;
    },
    onReset: () => save(HandyPreferences()),
  );
}
