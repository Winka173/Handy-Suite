import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_storage/history_page.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_ui/kit.dart';

HandyPlatform get _platform => kIsWeb
    ? HandyPlatform.web
    : switch (defaultTargetPlatform) {
        TargetPlatform.windows => HandyPlatform.windows,
        TargetPlatform.iOS => HandyPlatform.ios,
        _ => HandyPlatform.android,
      };

/// Tools settings: the shared page plus saved files and device support.
class ToolsSettingsPage extends StatelessWidget {
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final HandyFiles files;
  const ToolsSettingsPage({
    super.key,
    required this.read,
    required this.save,
    required this.files,
  });

  @override
  Widget build(BuildContext context) => HandySettingsPage(
    appName: 'Handy Tools',
    theme: read().theme,
    locale: read().locale,
    onTheme: (v) => save(read().copyWith(theme: v)),
    onLocale: (v) => save(read().copyWith(locale: v)),
    sections: [
      HandySettingsSection(
        title: tr(context, 'Files', 'File'),
        description: tr(
          context,
          'A record of results you saved as files. Their contents are not kept.',
          'Danh sách kết quả bạn đã lưu thành file. Không giữ nội dung file.',
        ),
        children: [
          HandyTile(
            key: const Key('open-export-history'),
            icon: Icons.history,
            title: tr(context, 'Export history', 'Lịch sử xuất file'),
            navigates: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ExportHistoryPage(
                  history: ExportHistory('tools'),
                  files: files,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
    onExportSettings: (context) async {
      final uri = await files.exportText(
        'handy-tools-settings.json',
        exportPreferences(read(), includeDrafts: false),
      );
      if (uri == null || !context.mounted) return null;
      return tr(context, 'Settings exported.', 'Đã xuất cài đặt.');
    },
    onImportSettings: (context) async {
      final file = await files.importText();
      if (file == null || !context.mounted) return null;
      final incoming = importPreferences(file.text);
      final ok = await confirmHandy(
        context,
        title: tr(
          context,
          'Replace current settings?',
          'Thay cài đặt hiện tại?',
        ),
        message: tr(
          context,
          'Theme, language, pins and workflows come from the file. Saved inputs and purchases stay as they are.',
          'Giao diện, ngôn ngữ, ghim và quy trình lấy từ file. Nội dung đã lưu và quyền mua giữ nguyên.',
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
    about: [
      HandyTile(
        icon: Icons.devices_outlined,
        title: tr(
          context,
          'What works on this device',
          'Tính năng trên thiết bị này',
        ),
        navigates: true,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const _DeviceSupportPage()),
        ),
      ),
    ],
  );
}

class _DeviceSupportPage extends StatelessWidget {
  const _DeviceSupportPage();
  @override
  Widget build(BuildContext context) {
    final caps = Capabilities(_platform);
    final names = {
      'files': tr(context, 'Open and save files', 'Mở và lưu file'),
      'preferences': tr(context, 'Saved settings', 'Lưu cài đặt'),
      'capture': tr(context, 'Camera', 'Camera'),
      'notifications': tr(context, 'Reminders', 'Nhắc nhở'),
      'purchase': tr(context, 'Purchases', 'Mua hàng'),
      'ads': tr(context, 'Ads', 'Quảng cáo'),
    };
    return HandyPage(
      title: tr(context, 'This device', 'Thiết bị này'),
      children: [
        const SizedBox(height: HandySpace.l),
        HandyGroup(
          children: [
            for (final e in names.entries)
              ListTile(
                title: Text(e.value),
                subtitle: Text(caps.get(e.key).reason),
              ),
          ],
        ),
      ],
    );
  }
}
