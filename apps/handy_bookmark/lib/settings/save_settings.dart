import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'data_section.dart';

/// Save's settings: the shared page with how links open, what is fetched,
/// reminders, and the data tools.
class SaveSettingsPage extends StatelessWidget {
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final SaveScope scope;
  const SaveSettingsPage({
    super.key,
    required this.read,
    required this.save,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final c = scope.c;
      final p = c.preferences;
      Future<void> set(String key, Object value) => scope.run(
        context,
        () => c.update((l) => l, prefs: {...c.preferences, key: value}),
      );
      return HandySettingsPage(
        appName: 'Handy Bookmark',
        theme: read().theme,
        locale: read().locale,
        onTheme: (v) => save(read().copyWith(theme: v)),
        onLocale: (v) => save(read().copyWith(locale: v)),
        sections: [
          HandySettingsSection(
            title: tr(context, 'Opening links', 'Mở link'),
            description: tr(
              context,
              'Where a saved link opens when you tap it.',
              'Link đã lưu mở ở đâu khi bạn chạm vào.',
            ),
            children: [
              HandySettingRow(
                stackBelow: 600,
                label: tr(context, 'Open with', 'Mở bằng'),
                control: SegmentedButton<String>(
                  key: const Key('set-open'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 'system',
                      label: Text(tr(context, 'Device', 'Mặc định')),
                    ),
                    ButtonSegment(
                      value: 'app',
                      label: Text(tr(context, 'Its app', 'App gốc')),
                    ),
                    ButtonSegment(
                      value: 'external',
                      label: Text(tr(context, 'Browser', 'Trình duyệt')),
                    ),
                  ],
                  selected: {p['openingMode'] as String? ?? 'system'},
                  onSelectionChanged: (s) => set('openingMode', s.first),
                ),
              ),
              SwitchListTile.adaptive(
                key: const Key('set-cards'),
                title: Text(
                  tr(context, 'Show links as cards', 'Hiện link dạng thẻ'),
                ),
                value: p['cards'] == true,
                onChanged: (v) => set('cards', v),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Page details', 'Thông tin trang'),
            description: tr(
              context,
              'Off: Save keeps only what was shared, and contacts no website. On: it reads the public page for a title and picture after you save.',
              'Tắt: Save chỉ giữ những gì được chia sẻ, không liên hệ website nào. Bật: Save đọc trang công khai để lấy tiêu đề và ảnh sau khi lưu.',
            ),
            children: [
              SwitchListTile.adaptive(
                key: const Key('set-metadata'),
                title: Text(
                  tr(
                    context,
                    'Read pages after saving',
                    'Đọc trang sau khi lưu',
                  ),
                ),
                value: p['automaticMetadata'] == true,
                onChanged: (v) => set('automaticMetadata', v),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Reminders and search', 'Hẹn nhắc và tìm kiếm'),
            children: [
              if (scope.reminders.supported)
                SwitchListTile.adaptive(
                  key: const Key('set-reminders'),
                  title: Text(tr(context, 'Notify me', 'Thông báo cho tôi')),
                  subtitle: Text(
                    tr(
                      context,
                      'The next 50 reminders, without link titles.',
                      '50 hẹn nhắc gần nhất, không kèm tiêu đề link.',
                    ),
                  ),
                  value: p['notifications'] == true,
                  onChanged: (v) async {
                    final allowed = !v || await scope.reminders.request();
                    await set('notifications', v && allowed);
                  },
                )
              else
                ListTile(
                  title: Text(
                    tr(
                      context,
                      'Notifications are not available here; reminders show on each link.',
                      'Nền tảng này chưa có thông báo; hẹn nhắc vẫn hiện trên từng link.',
                    ),
                  ),
                ),
              SwitchListTile.adaptive(
                key: const Key('set-history'),
                title: Text(
                  tr(context, 'Remember searches', 'Nhớ các lần tìm'),
                ),
                value: p['recentSearchesEnabled'] == true,
                onChanged: (v) => scope.run(
                  context,
                  () => c.update(
                    (l) => l,
                    prefs: {
                      ...c.preferences,
                      'recentSearchesEnabled': v,
                      if (!v) 'recentSearches': [],
                    },
                  ),
                ),
              ),
            ],
          ),
          if (scope.autoBackup != null)
            HandyAutoBackupSection(backup: scope.autoBackup!),
          SaveDataSection(scope: scope),
        ],
        onReset: () => save(HandyPreferences()),
      );
    },
  );
}
