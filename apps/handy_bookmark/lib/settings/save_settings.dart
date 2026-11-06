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

//// Where sync folders are picked; tests replace it.
BackupFolders syncFolders = systemBackupFolders();

/// Settings in four groups, in the order people look for them: how the
/// app looks and behaves, reminders, their data, then help and the rarer
/// tools. What cannot be undone sits apart at the very bottom. Every
/// control saves itself.
class SaveSettingsPage extends StatefulWidget {
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
  State<SaveSettingsPage> createState() => _SaveSettingsPageState();
}

class _SaveSettingsPageState extends State<SaveSettingsPage> {
  // Kept here as well, so a choice shows at once even before the
  // device's preferences report back.
  late String theme = widget.read().theme, locale = widget.read().locale;
  SaveScope get scope => widget.scope;

  Future<void> _device(HandyPreferences next, VoidCallback local) async {
    try {
      await widget.save(next);
      if (mounted) setState(local);
    } catch (_) {
      if (mounted)
        showHandyMessage(
          context,
          tr(context, 'Could not save.', 'Chưa lưu được.'),
        );
    }
  }

  Future<void> _resetPreferences() async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Reset preferences?', 'Đặt lại cài đặt?'),
      message: tr(
        context,
        'Language and appearance go back to how they started. Your links, pictures and collections are kept.',
        'Ngôn ngữ và giao diện trở về như ban đầu. Link, ảnh và bộ sưu tập vẫn được giữ.',
      ),
      confirmLabel: tr(context, 'Reset preferences', 'Đặt lại cài đặt'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _device(HandyPreferences(), () {
      theme = 'system';
      locale = 'system';
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final c = scope.c;
      final p = c.preferences;
      final system = tr(context, 'System', 'Hệ thống');
      Future<void> set(String key, Object value) => scope.run(
        context,
        () => c.update((l) => l, prefs: {...c.preferences, key: value}),
      );
      Widget segmented(
        Key key,
        String value,
        List<(String, String)> options,
        ValueChanged<String> onChanged,
      ) => SegmentedButton<String>(
        key: key,
        showSelectedIcon: false,
        segments: [
          for (final o in options)
            ButtonSegment(value: o.$1, label: Text(o.$2)),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      );
      return HandyPage(
        title: tr(context, 'Settings', 'Cài đặt'),
        children: [
          // Personalise.
          _GroupHead(tr(context, 'Personalise', 'Cá nhân hóa'), first: true),
          HandySettingsSection(
            title: tr(context, 'Look and language', 'Giao diện và ngôn ngữ'),
            children: [
              HandySettingRow(
                stackBelow: 600,
                label: tr(context, 'Appearance', 'Giao diện'),
                control: segmented(
                  const Key('settings-theme'),
                  theme,
                  [
                    ('system', system),
                    ('light', tr(context, 'Light', 'Sáng')),
                    ('dark', tr(context, 'Dark', 'Tối')),
                  ],
                  (v) => _device(
                    widget.read().copyWith(theme: v),
                    () => theme = v,
                  ),
                ),
              ),
              HandySettingRow(
                stackBelow: 600,
                label: tr(context, 'Language', 'Ngôn ngữ'),
                control: segmented(
                  const Key('settings-locale'),
                  locale,
                  [('system', system), ('en', 'English'), ('vi', 'Tiếng Việt')],
                  (v) => _device(
                    widget.read().copyWith(locale: v),
                    () => locale = v,
                  ),
                ),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Your library', 'Thư viện của bạn'),
            children: [
              HandyTile(
                key: const Key('set-library-name'),
                icon: Icons.edit_outlined,
                title: libraryName(c),
                subtitle: tr(
                  context,
                  'The name at the top of the home',
                  'Tên hiện ở đầu trang chính',
                ),
                navigates: true,
                onTap: () async {
                  final name = await _askName(context, c);
                  if (name != null) await set('libraryName', name);
                },
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Opening and finding', 'Mở và tìm'),
            children: [
              HandySettingRow(
                stackBelow: 600,
                label: tr(context, 'Open links with', 'Mở link bằng'),
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
                  tr(context, 'Show lists as cards', 'Hiện danh sách dạng thẻ'),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Bigger pictures, fewer items per screen',
                    'Ảnh to hơn, ít mục hơn mỗi màn hình',
                  ),
                ),
                value: p['cards'] == true,
                onChanged: (v) => set('cards', v),
              ),
              SwitchListTile.adaptive(
                key: const Key('set-history'),
                title: Text(
                  tr(context, 'Remember searches', 'Nhớ các lần tìm'),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Turning it off forgets them',
                    'Tắt đi sẽ xóa các lần tìm đã nhớ',
                  ),
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
            title: tr(context, 'Page details', 'Thông tin trang'),
            description: tr(
              context,
              'Off: only what was shared is kept, and no website is contacted. On: after you save, the app reads the public page for its title and picture.',
              'Tắt: chỉ giữ những gì được chia sẻ, không liên hệ website nào. Bật: sau khi lưu, app đọc trang công khai để lấy tiêu đề và ảnh.',
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

          // Reminders.
          _GroupHead(tr(context, 'Reminders', 'Nhắc nhở')),
          HandySettingsSection(
            title: tr(context, 'Notifications', 'Thông báo'),
            description: scope.reminders.supported
                ? tr(
                    context,
                    'Reminders never show a link\'s title on the lock screen.',
                    'Thông báo không bao giờ hiện tiêu đề link trên màn hình khóa.',
                  )
                : null,
            children: [
              if (scope.reminders.supported) ...[
                SwitchListTile.adaptive(
                  key: const Key('set-reminders'),
                  title: Text(tr(context, 'Remind me', 'Nhắc tôi')),
                  subtitle: Text(
                    tr(
                      context,
                      'For reminders you set on an item. The next 50 are scheduled.',
                      'Cho các hẹn nhắc bạn đặt trên từng mục. Lên lịch 50 hẹn gần nhất.',
                    ),
                  ),
                  value: p['notifications'] == true,
                  onChanged: (v) async {
                    final allowed = !v || await scope.reminders.request();
                    await set('notifications', v && allowed);
                  },
                ),
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
                if (p['revisit'] == true)
                  HandySettingRow(
                    stackBelow: 360,
                    label: tr(context, 'When', 'Lúc nào'),
                    control: Wrap(
                      spacing: HandySpace.m,
                      children: [
                        DropdownButton<int>(
                          key: const Key('set-revisit-day'),
                          value: p['revisitDay'] as int? ?? DateTime.sunday,
                          underline: const SizedBox.shrink(),
                          borderRadius: BorderRadius.circular(16),
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
                          underline: const SizedBox.shrink(),
                          borderRadius: BorderRadius.circular(16),
                          items: [
                            for (var h = 7; h <= 22; h++)
                              DropdownMenuItem(
                                value: h,
                                child: Text(
                                  '${h.toString().padLeft(2, '0')}:00',
                                ),
                              ),
                          ],
                          onChanged: (h) => set('revisitHour', h!),
                        ),
                      ],
                    ),
                  ),
              ] else
                HandyTile(
                  icon: Icons.notifications_off_outlined,
                  title: tr(context, 'Not available here', 'Chưa có ở đây'),
                  subtitle: tr(
                    context,
                    'This device or browser cannot show notifications. Reminders still show on each item and in the home.',
                    'Thiết bị hoặc trình duyệt này không hiện được thông báo. Hẹn nhắc vẫn hiện trên từng mục và ở trang chính.',
                  ),
                  subtitleLines: 4,
                ),
            ],
          ),

          // Your data.
          _GroupHead(
            tr(context, 'Your data', 'Dữ liệu của bạn'),
            note: tr(
              context,
              'Kept on this device. It leaves only when you export it, sync it through a folder or share a page.',
              'Lưu trên máy này. Dữ liệu chỉ rời máy khi bạn xuất file, đồng bộ qua thư mục hoặc chia sẻ một trang.',
            ),
          ),
          SaveStorageSection(scope: scope),
          SaveBackupSection(scope: scope),
          if (scope.autoBackup != null)
            HandyAutoBackupSection(backup: scope.autoBackup!),
          SyncSection(scope: scope, folders: syncFolders),

          // About & advanced.
          _GroupHead(tr(context, 'Help and advanced', 'Trợ giúp và nâng cao')),
          HandySettingsSection(
            title: tr(context, 'Help', 'Trợ giúp'),
            children: [
              HandyTile(
                key: const Key('set-guide'),
                icon: Icons.school_outlined,
                title: tr(context, 'How to save', 'Cách lưu'),
                subtitle: tr(
                  context,
                  'The short guide: share, paste or add a picture.',
                  'Hướng dẫn ngắn: chia sẻ, dán link hoặc thêm ảnh.',
                ),
                navigates: true,
                onTap: () => Navigator.pushNamed(context, '/welcome'),
              ),
              HandyTile(
                key: const Key('save-privacy'),
                icon: Icons.privacy_tip_outlined,
                title: tr(context, 'Privacy', 'Quyền riêng tư'),
                subtitle: tr(
                  context,
                  'What stays here, and when something leaves',
                  'Điều gì ở lại máy, và khi nào dữ liệu rời máy',
                ),
                navigates: true,
                onTap: () => showPrivacy(context),
              ),
            ],
          ),
          SaveLibraryTools(scope: scope),
          const HandyProSection(),
          const HandyMoreApps(app: 'bookmark'),
          HandySettingsSection(
            title: tr(context, 'About', 'Giới thiệu'),
            children: [
              HandyTile(
                icon: Icons.description_outlined,
                title: tr(
                  context,
                  'Open-source licenses',
                  'Giấy phép mã nguồn mở',
                ),
                navigates: true,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Handy Bookmark',
                ),
              ),
            ],
          ),

          // Apart, last: what cannot be taken back.
          const SizedBox(height: HandySpace.xl),
          HandySettingsSection(
            title: tr(context, 'Reset and delete', 'Đặt lại và xóa'),
            description: tr(
              context,
              'Deleting cannot be undone. Export a backup first if you may want it back.',
              'Xóa thì không hoàn tác được. Hãy xuất bản sao lưu trước nếu còn cần.',
            ),
            children: [
              HandyTile(
                key: const Key('settings-reset'),
                icon: Icons.settings_backup_restore,
                title: tr(context, 'Reset preferences', 'Đặt lại cài đặt'),
                subtitle: tr(
                  context,
                  'Language and appearance. Your library stays.',
                  'Ngôn ngữ và giao diện. Thư viện vẫn giữ.',
                ),
                onTap: _resetPreferences,
              ),
              HandyTile(
                key: const Key('save-reset'),
                icon: Icons.delete_forever_outlined,
                destructive: true,
                title: tr(
                  context,
                  'Delete all links and collections',
                  'Xóa mọi link và bộ sưu tập',
                ),
                onTap: () => deleteEverything(context, scope),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// A group's name over its sections: larger than the sections' own
/// titles, with an optional sentence that sums the group up.
class _GroupHead extends StatelessWidget {
  final String title;
  final String? note;
  final bool first;
  const _GroupHead(this.title, {this.note, this.first = false});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: first ? HandySpace.s : 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: HandySpace.xs),
            Text(
              note!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: HandyColors.of(context).muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
