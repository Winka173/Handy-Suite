import 'package:handy_storage/handy_storage.dart';
import '../design/looks.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../controller.dart';
import '../home/dateline.dart';
import '../sync/sync_section.dart';
import 'data_section.dart';
import 'help_links.dart';
import 'library_tools.dart';
import 'reminders_section.dart';
import 'settings_parts.dart';

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

/// Settings in nine groups, in the order people look for them:
/// Appearance (theme, language, looks, the library's name), Reminders,
/// Library (Recently deleted, Storage, advanced tools), Backup & restore,
/// Cloud sync, Help & feedback (How to use, the welcome, Send feedback),
/// Pro, About (privacy policy, terms, licenses, other apps) and, last,
/// Reset and delete. Every control saves itself.
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
      return HandyPage(
        title: tr(context, 'Settings', 'Cài đặt'),
        children: [
          // 1. Appearance.
          SettingsGroup(
            first: true,
            title: tr(context, 'Appearance', 'Giao diện'),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsChoice<String>(
                    controlKey: const Key('settings-theme'),
                    icon: Icons.contrast,
                    title: tr(context, 'Theme', 'Màu nền'),
                    value: theme,
                    options: [
                      ('system', system),
                      ('light', tr(context, 'Light', 'Sáng')),
                      ('dark', tr(context, 'Dark', 'Tối')),
                    ],
                    onChanged: (v) => _device(
                      widget.read().copyWith(theme: v),
                      () => theme = v,
                    ),
                  ),
                  SettingsChoice<String>(
                    controlKey: const Key('settings-locale'),
                    icon: Icons.translate,
                    title: tr(context, 'Language', 'Ngôn ngữ'),
                    value: locale,
                    options: [
                      ('system', system),
                      ('en', 'English'),
                      ('vi', 'Tiếng Việt'),
                    ],
                    onChanged: (v) => _device(
                      widget.read().copyWith(locale: v),
                      () => locale = v,
                    ),
                  ),
                  SettingsRow(
                    key: const Key('set-looks'),
                    icon: Icons.palette_outlined,
                    title: tr(context, 'Themes', 'Giao diện'),
                    subtitle: tr(
                      context,
                      lookById(c.preferences['look'] as String?)?.en ??
                          libraryLook.en,
                      lookById(c.preferences['look'] as String?)?.vi ??
                          libraryLook.vi,
                    ),
                    navigates: true,
                    onTap: () => Navigator.pushNamed(context, '/looks'),
                  ),
                  SettingsRow(
                    key: const Key('set-library-name'),
                    icon: Icons.edit_outlined,
                    title: tr(context, 'Library name', 'Tên thư viện'),
                    subtitle: libraryName(c),
                    navigates: true,
                    onTap: () async {
                      final name = await _askName(context, c);
                      if (name != null) await set('libraryName', name);
                    },
                  ),
                ],
              ),
            ],
          ),

          // 2. Reminders.
          SettingsGroup(
            title: tr(context, 'Reminders', 'Nhắc nhở'),
            note: scope.reminders.supported
                ? tr(
                    context,
                    'Off unless you turn it on. A reminder never shows a title on the lock screen.',
                    'Tắt cho đến khi bạn bật. Thông báo không bao giờ hiện tiêu đề trên màn hình khóa.',
                  )
                : null,
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  if (scope.reminders.supported) ...[
                    SettingsSwitch(
                      key: const Key('set-revisit'),
                      icon: Icons.event_repeat_outlined,
                      title: tr(context, 'Weekly nudge', 'Nhắc mỗi tuần'),
                      subtitle: revisitWhen(
                        context,
                        p['revisitDay'] as int? ?? DateTime.sunday,
                        p['revisitHour'] as int? ?? 19,
                      ),
                      value: p['revisit'] == true,
                      onChanged: (v) async {
                        final allowed = !v || await scope.reminders.request();
                        await set('revisit', v && allowed);
                      },
                    ),
                    if (p['revisit'] == true) _RevisitWhen(set: set, p: p),
                  ] else
                    SettingsRow(
                      icon: Icons.notifications_off_outlined,
                      title: tr(context, 'Not available here', 'Chưa có ở đây'),
                      subtitle: tr(
                        context,
                        'This device or browser cannot show notifications.',
                        'Thiết bị hoặc trình duyệt này không hiện được thông báo.',
                      ),
                    ),
                ],
              ),
              ExistingReminders(scope: scope),
            ],
          ),

          // 3. Library.
          SettingsGroup(
            title: tr(context, 'Library', 'Thư viện'),
            children: [
              DataMorePanel(
                scope: scope,
                extra: [
                  SettingsRow(
                    key: const Key('set-library-tools'),
                    icon: Icons.handyman_outlined,
                    title: tr(
                      context,
                      'Advanced library tools',
                      'Công cụ thư viện nâng cao',
                    ),
                    subtitle: tr(
                      context,
                      'How links open, duplicates, link checks, smart collections',
                      'Cách mở link, mục trùng, kiểm tra link, bộ sưu tập thông minh',
                    ),
                    navigates: true,
                    onTap: () => openLibraryTools(context, scope),
                  ),
                ],
              ),
            ],
          ),

          // 4. Backup & restore.
          SettingsGroup(
            title: tr(context, 'Backup & restore', 'Sao lưu & khôi phục'),
            note: tr(
              context,
              'Kept on this device. It leaves only when you back it up, sync it through a folder or share a page.',
              'Lưu trên máy này. Dữ liệu chỉ rời máy khi bạn sao lưu, đồng bộ qua thư mục hoặc chia sẻ một trang.',
            ),
            children: [
              BackupPanel(scope: scope),
              if (scope.autoBackup != null)
                KitSection(
                  child: HandyAutoBackupSection(backup: scope.autoBackup!),
                ),
            ],
          ),

          // 5. Cloud sync.
          SettingsGroup(
            title: tr(context, 'Cloud sync', 'Đồng bộ đám mây'),
            note: tr(
              context,
              'The same library on more than one device.',
              'Dùng chung một thư viện trên nhiều thiết bị.',
            ),
            children: [SyncSection(scope: scope, folders: syncFolders)],
          ),

          // 6. Help & feedback.
          SettingsGroup(
            title: tr(context, 'Help & feedback', 'Trợ giúp & góp ý'),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsRow(
                    key: const Key('set-howto'),
                    icon: Icons.menu_book_outlined,
                    title: tr(context, 'How to use', 'Cách dùng'),
                    subtitle: tr(
                      context,
                      'Save, organize, find, read, keep it safe, Pro',
                      'Lưu, sắp xếp, tìm lại, đọc, giữ an toàn, Pro',
                    ),
                    navigates: true,
                    onTap: () => Navigator.pushNamed(context, '/how-to'),
                  ),
                  SettingsRow(
                    key: const Key('set-guide'),
                    icon: Icons.school_outlined,
                    title: tr(
                      context,
                      'Replay the welcome',
                      'Xem lại phần giới thiệu',
                    ),
                    subtitle: tr(
                      context,
                      'The three screens shown at first start',
                      'Ba màn hình hiện khi mở app lần đầu',
                    ),
                    navigates: true,
                    onTap: () => Navigator.pushNamed(context, '/welcome'),
                  ),
                  SettingsRow(
                    key: const Key('set-feedback'),
                    icon: Icons.mail_outline,
                    title: tr(context, 'Send feedback', 'Gửi góp ý'),
                    subtitle: feedbackEmail,
                    navigates: true,
                    onTap: () => sendFeedback(context),
                  ),
                ],
              ),
            ],
          ),

          // 7. Pro.
          SettingsGroup(
            title: 'Pro',
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsRow(
                    key: const Key('set-pro'),
                    icon: Icons.workspace_premium_outlined,
                    title: tr(context, 'Explore Pro', 'Khám phá Pro'),
                    subtitle: tr(
                      context,
                      'Themes, layouts, highlights, deeper search; one payment. Buy or restore a purchase there.',
                      'Giao diện, kiểu trình bày, đánh dấu, tìm sâu; trả một lần. Mua hoặc khôi phục giao dịch ở đó.',
                    ),
                    navigates: true,
                    onTap: () => Navigator.pushNamed(context, '/pro'),
                  ),
                ],
              ),
              // Not the kit's Pro section: its words are about removing
              // ads, and Bookmark shows none. Explore Pro buys and restores.
            ],
          ),

          // 8. About & legal.
          SettingsGroup(
            title: tr(context, 'About', 'Giới thiệu'),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsRow(
                    key: const Key('save-privacy'),
                    icon: Icons.privacy_tip_outlined,
                    title: tr(
                      context,
                      'Privacy policy',
                      'Chính sách quyền riêng tư',
                    ),
                    subtitle: privacyPolicyUrl == null
                        ? tr(
                            context,
                            'Not published yet. For now: what stays here, and when something leaves',
                            'Chưa công bố. Tạm thời: điều gì ở lại máy, và khi nào dữ liệu rời máy',
                          )
                        : null,
                    navigates: true,
                    onTap: () => privacyPolicyUrl == null
                        ? showPrivacy(context)
                        : openLegal(context, privacyPolicyUrl!),
                  ),
                  SettingsRow(
                    key: const Key('set-terms'),
                    icon: Icons.gavel_outlined,
                    title: tr(
                      context,
                      'Terms of service',
                      'Điều khoản sử dụng',
                    ),
                    subtitle: termsUrl == null
                        ? tr(context, 'Not published yet', 'Chưa công bố')
                        : null,
                    navigates: termsUrl != null,
                    onTap: termsUrl == null
                        ? null
                        : () => openLegal(context, termsUrl!),
                  ),
                  SettingsRow(
                    key: const Key('set-about'),
                    icon: Icons.info_outline,
                    title: tr(context, 'Licenses', 'Giấy phép'),
                    subtitle: tr(
                      context,
                      'Open-source licenses and photo credits',
                      'Giấy phép mã nguồn mở và nguồn ảnh',
                    ),
                    navigates: true,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Handy Bookmark',
                    ),
                  ),
                ],
              ),
              const KitSection(child: HandyMoreApps(app: 'bookmark')),
            ],
          ),

          // 9. What cannot be taken back, last.
          SettingsGroup(
            title: tr(context, 'Reset and delete', 'Đặt lại và xóa'),
            note: tr(
              context,
              'Deleting cannot be undone. Back up first if you may want it back.',
              'Xóa thì không hoàn tác được. Hãy sao lưu trước nếu còn cần.',
            ),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsRow(
                    key: const Key('settings-reset'),
                    icon: Icons.restart_alt,
                    title: tr(context, 'Reset preferences', 'Đặt lại cài đặt'),
                    subtitle: tr(
                      context,
                      'Language and appearance. Your library stays.',
                      'Ngôn ngữ và giao diện. Thư viện vẫn giữ.',
                    ),
                    onTap: _resetPreferences,
                  ),
                  SettingsRow(
                    key: const Key('save-reset'),
                    icon: Icons.delete_forever_outlined,
                    destructive: true,
                    title: tr(
                      context,
                      'Delete all data',
                      'Xóa toàn bộ dữ liệu',
                    ),
                    subtitle: tr(
                      context,
                      'Everything this app keeps on this device',
                      'Mọi thứ app này lưu trên máy này',
                    ),
                    onTap: () => deleteEverything(context, scope),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// The weekly nudge's day and hour, under its switch.
class _RevisitWhen extends StatelessWidget {
  final Future<void> Function(String key, Object value) set;
  final Map<String, dynamic> p;
  const _RevisitWhen({required this.set, required this.p});
  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: Icons.schedule,
    title: tr(context, 'When', 'Lúc nào'),
    trailing: Wrap(
      spacing: HandySpace.s,
      children: [
        DropdownButton<int>(
          key: const Key('set-revisit-day'),
          value: p['revisitDay'] as int? ?? DateTime.sunday,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(16),
          items: [
            for (var d = 1; d <= 7; d++)
              DropdownMenuItem(value: d, child: Text(weekdayName(context, d))),
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
                child: Text('${h.toString().padLeft(2, '0')}:00'),
              ),
          ],
          onChanged: (h) => set('revisitHour', h!),
        ),
      ],
    ),
  );
}
