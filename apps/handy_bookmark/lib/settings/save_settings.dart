import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../controller.dart';
import '../home/dateline.dart';
import '../sync/sync_section.dart';
import 'data_section.dart';

/// The library's name, shown at the top of the home. Empty restores the
/// app's name.
Future<String?> _askName(BuildContext context, SaveController c) {
  final text = TextEditingController(
    text: c.preferences['libraryName'] as String? ?? '',
  );
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr(context, 'Name your library', 'Đặt tên thư viện')),
      content: TextField(
        key: const Key('library-name-input'),
        controller: text,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(
          labelText: tr(context, 'Name', 'Tên'),
          hintText: tr(context, "Lan's saves", 'Kho của Lan'),
          helperText: tr(
            context,
            'Leave empty to show Handy Bookmark.',
            'Để trống để hiện Handy Bookmark.',
          ),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          key: const Key('library-name-save'),
          onPressed: () => Navigator.pop(context, text.text.trim()),
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
      ],
    ),
  );
}

/// "Sundays at 19:00, only when new saves wait unread. A count, no titles."
String revisitWhen(BuildContext context, int day, int hour) => tr(
  context,
  '${weekdayName(context, day)}s at ${hour.toString().padLeft(2, '0')}:00, only when new saves wait unread. A count, never titles.',
  '${weekdayName(context, day)} lúc ${hour.toString().padLeft(2, '0')}:00, chỉ khi có mục mới lưu chưa xem. Chỉ ghi số lượng, không ghi tiêu đề.',
);

String weekdayName(BuildContext context, int day) => tr(
  context,
  const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][day - 1],
  const [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ][day - 1],
);

/// Where sync folders are picked; tests replace it.
BackupFolders syncFolders = systemBackupFolders();

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
            title: tr(context, 'Your library', 'Thư viện của bạn'),
            children: [
              ListTile(
                key: const Key('set-library-name'),
                title: Text(tr(context, 'Name', 'Tên')),
                subtitle: Text(libraryName(c)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final name = await _askName(context, c);
                  if (name != null) await set('libraryName', name);
                },
              ),
            ],
          ),
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
                ),
              if (scope.reminders.supported)
                SwitchListTile.adaptive(
                  key: const Key('set-revisit'),
                  title: Text(tr(context, 'Weekly nudge', 'Nhắc mỗi tuần')),
                  subtitle: Text(
                    revisitWhen(
                      context,
                      p['revisitDay'] as int? ?? DateTime.sunday,
                      p['revisitHour'] as int? ?? 19,
                    ),
                  ),
                  value: p['revisit'] == true,
                  onChanged: (v) async {
                    final allowed = !v || await scope.reminders.request();
                    await set('revisit', v && allowed);
                  },
                ),
              if (scope.reminders.supported && p['revisit'] == true)
                HandySettingRow(
                  stackBelow: 600,
                  label: tr(context, 'When', 'Lúc nào'),
                  control: Wrap(
                    spacing: HandySpace.s,
                    children: [
                      DropdownButton<int>(
                        key: const Key('set-revisit-day'),
                        value: p['revisitDay'] as int? ?? DateTime.sunday,
                        items: [
                          for (var d = 1; d <= 7; d++)
                            DropdownMenuItem(
                              value: d,
                              child: Text(weekdayName(context, d)),
                            ),
                        ],
                        onChanged: (d) => set('revisitDay', d!),
                      ),
                      DropdownButton<int>(
                        key: const Key('set-revisit-hour'),
                        value: p['revisitHour'] as int? ?? 19,
                        items: [
                          for (var h = 7; h <= 22; h++)
                            DropdownMenuItem(
                              value: h,
                              child: Text('${h.toString().padLeft(2, '0')}:00'),
                            ),
                        ],
                        onChanged: (h) => set('revisitHour', h!),
                      ),
                    ],
                  ),
                ),
              if (!scope.reminders.supported)
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
          HandySettingsSection(
            title: tr(context, 'Help', 'Trợ giúp'),
            children: [
              ListTile(
                key: const Key('set-guide'),
                leading: const Icon(Icons.school_outlined),
                title: Text(tr(context, 'How to save', 'Cách lưu')),
                subtitle: Text(
                  tr(
                    context,
                    'The first-run guide: share, paste or add a picture.',
                    'Hướng dẫn lần đầu: chia sẻ, dán link hoặc thêm ảnh.',
                  ),
                ),
                onTap: () => Navigator.pushNamed(context, '/welcome'),
              ),
            ],
          ),
          if (scope.autoBackup != null)
            HandyAutoBackupSection(backup: scope.autoBackup!),
          SyncSection(scope: scope, folders: syncFolders),
          SaveDataSection(scope: scope),
        ],
        onReset: () => save(HandyPreferences()),
      );
    },
  );
}
