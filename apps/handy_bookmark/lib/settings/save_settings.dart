import 'package:handy_storage/handy_storage.dart';
import 'package:flutter/foundation.dart';
import 'auto_backup_row.dart';
import '../data/import_export.dart';
import '../sync/sync_service.dart';
import '../design/theme.dart';
import '../pro/entitlements.dart';
import '../security/app_lock.dart';
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
import '../sync/drive_section.dart';
import '../sync/drive_sync.dart';

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
            'Leave empty to show My library.',
            'Để trống để hiện Thư viện của tôi.',
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

/// Settings, as the suite's other apps have them: Pro first, then General
/// (language, theme, looks, the library's name, the weekly nudge), Privacy
/// (the app lock), Data (sync, backup and restore, import, Recently
/// deleted, the library tools, delete everything), Help (How to use) and
/// About (feedback, privacy policy, terms, licenses). Every control saves
/// itself.
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

  /// Sync goes through a folder a cloud app keeps in step: computers only
  /// for now.
  /// Folder sync: computers with a folder picker.
  bool get _folderSync =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux) &&
      folderSyncSupported('path') &&
      syncFolders.canChoose;

  bool get _syncHere => _folderSync || scope.drive != null;

  /// "Folder · synced 6 Nov 14:20", or "Coming soon" where there is none.
  String _syncState(BuildContext context) {
    final p = scope.c.preferences;
    if (!_syncHere) return tr(context, 'Coming soon', 'Sắp có');
    final drive = scope.drive;
    if (drive != null && (drive.enabled || !_folderSync)) {
      if (!drive.enabled) {
        return tr(
          context,
          'Off. Google Drive keeps your devices in step',
          'Đang tắt. Google Drive giữ các máy khớp nhau',
        );
      }
      final at = drive.lastSync;
      return switch (drive.state) {
        DriveSyncState.syncing => tr(context, 'Syncing…', 'Đang đồng bộ…'),
        DriveSyncState.offline => tr(
          context,
          'Google Drive · will sync when online',
          'Google Drive · sẽ đồng bộ khi có mạng',
        ),
        DriveSyncState.authNeeded => tr(
          context,
          'Google Drive · allow access again',
          'Google Drive · cần cho phép lại',
        ),
        DriveSyncState.quota => tr(
          context,
          'Google Drive is full',
          'Google Drive đã đầy',
        ),
        DriveSyncState.failed => tr(
          context,
          'Google Drive · could not sync',
          'Google Drive · chưa đồng bộ được',
        ),
        _ =>
          'Google Drive · ${at == null ? tr(context, 'not synced yet', 'chưa đồng bộ lần nào') : '${MaterialLocalizations.of(context).formatShortDate(at)} ${TimeOfDay.fromDateTime(at).format(context)}'}',
      };
    }
    final folder = (p['syncFolder'] as Map?)?['name'] as String?;
    if (folder == null)
      return tr(
        context,
        'Off. Choose a synced folder',
        'Đang tắt. Chọn thư mục',
      );
    final at = DateTime.tryParse(p['syncedAt'] as String? ?? '')?.toLocal();
    final when = at == null
        ? tr(context, 'not synced yet', 'chưa đồng bộ lần nào')
        : '${MaterialLocalizations.of(context).formatShortDate(at)} '
              '${TimeOfDay.fromDateTime(at).format(context)}';
    return '$folder · $when';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final c = scope.c;
      final p = c.preferences;
      final system = tr(context, 'System', 'Hệ thống');
      final deleted = scope.library.trash.length;
      Future<void> set(String key, Object value) => scope.run(
        context,
        () => c.update((l) => l, prefs: {...c.preferences, key: value}),
      );
      return HandyPage(
        title: tr(context, 'Settings', 'Cài đặt'),
        children: [
          const SizedBox(height: HandySpace.s),
          const _ProCard(),

          // General.
          SettingsGroup(
            title: tr(context, 'General', 'Chung'),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsChoice<String>(
                    controlKey: const Key('settings-locale'),
                    icon: Icons.translate,
                    title: tr(context, 'Language', 'Ngôn ngữ'),
                    value: locale,
                    options: [
                      ('en', 'English'),
                      ('vi', 'Tiếng Việt'),
                      ('system', system),
                    ],
                    onChanged: (v) => _device(
                      widget.read().copyWith(locale: v),
                      () => locale = v,
                    ),
                  ),
                  SettingsChoice<String>(
                    controlKey: const Key('settings-theme'),
                    icon: Icons.contrast,
                    title: tr(context, 'Light or dark', 'Sáng hay tối'),
                    value: theme,
                    options: [
                      ('light', tr(context, 'Light', 'Sáng')),
                      ('dark', tr(context, 'Dark', 'Tối')),
                      ('system', system),
                    ],
                    onChanged: (v) => _device(
                      widget.read().copyWith(theme: v),
                      () => theme = v,
                    ),
                  ),
                  SettingsRow(
                    key: const Key('set-looks'),
                    icon: Icons.palette_outlined,
                    title: tr(context, 'Themes', 'Chủ đề màu'),
                    subtitle: tr(
                      context,
                      lookById(p['look'] as String?)?.en ?? libraryLook.en,
                      lookById(p['look'] as String?)?.vi ?? libraryLook.vi,
                    ),
                    navigates: true,
                    onTap: () => Navigator.pushNamed(context, '/looks'),
                  ),
                  SettingsRow(
                    key: const Key('set-library-name'),
                    icon: Icons.edit_outlined,
                    title: tr(context, 'Library name', 'Tên thư viện'),
                    subtitle: libraryName(c, context),
                    navigates: true,
                    onTap: () async {
                      final name = await _askName(context, c);
                      if (name != null) await set('libraryName', name);
                    },
                  ),
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
                  ],
                ],
              ),
              ExistingReminders(scope: scope),
            ],
          ),

          // Privacy.
          SettingsGroup(
            title: tr(context, 'Privacy', 'Riêng tư'),
            children: [
              SettingsPanel(gap: false, rows: [AppLockSwitch(scope: scope)]),
            ],
          ),

          // Data.
          SettingsGroup(
            title: tr(context, 'Data', 'Dữ liệu'),
            note: tr(
              context,
              'Kept on this device. It leaves only when you back it up, sync it or share it.',
              'Lưu trên máy này. Chỉ rời máy khi bạn sao lưu, đồng bộ hoặc chia sẻ.',
            ),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsRow(
                    key: const Key('set-sync'),
                    icon: Icons.sync,
                    title: tr(context, 'Sync', 'Đồng bộ'),
                    subtitle: _syncState(context),
                    navigates: _syncHere,
                    onTap: !_syncHere
                        ? null
                        : () => pushSettingsView(
                            context,
                            tr(context, 'Sync', 'Đồng bộ'),
                            listenable: Listenable.merge([
                              scope.c,
                              ?scope.drive,
                            ]),
                            (context) => [
                              if (scope.drive case final drive?)
                                DriveSyncPanel(drive: drive),
                              if (_folderSync)
                                SyncSection(scope: scope, folders: syncFolders),
                            ],
                          ),
                  ),
                ],
              ),
              SettingsPanel(
                title: tr(context, 'Backup and restore', 'Sao lưu & khôi phục'),
                rows: [
                  // A complete automatic copy is said by the switch below;
                  // a manual one, or anything left out, is said here.
                  if (c.lastBackup case final report?
                      when !report.complete ||
                          !report.automatic ||
                          !(scope.autoBackup?.folders.supported ?? false))
                    Padding(
                      padding: const EdgeInsets.all(HandySpace.m),
                      child: BackupReportNote(report),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(HandySpace.m),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('save-backup'),
                            onPressed: () => backUp(context, scope),
                            icon: const Icon(Icons.backup_outlined, size: 20),
                            label: Text(tr(context, 'Back up', 'Sao lưu')),
                          ),
                        ),
                        const SizedBox(width: HandySpace.m),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('save-import'),
                            onPressed: () => scope.importLinks(context),
                            icon: const Icon(
                              Icons.settings_backup_restore,
                              size: 20,
                            ),
                            label: Text(tr(context, 'Restore', 'Khôi phục')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (scope.autoBackup?.folders.supported ?? false)
                    AutoBackupRow(scope: scope),
                ],
              ),
              SettingsPanel(
                rows: [
                  SettingsRow(
                    key: const Key('set-advanced-data'),
                    icon: Icons.swap_vert,
                    title: tr(context, 'Import and export', 'Nhập và xuất'),
                    subtitle: tr(
                      context,
                      'Browser bookmarks, Pocket, Raindrop; CSV, HTML, Markdown',
                      'Dấu trang trình duyệt, Pocket, Raindrop; CSV, HTML, Markdown',
                    ),
                    navigates: true,
                    onTap: () => openAdvancedData(context, scope),
                  ),
                  SettingsRow(
                    key: const Key('save-trash'),
                    icon: Icons.delete_outline,
                    title: tr(context, 'Recently deleted', 'Đã xóa gần đây'),
                    subtitle: deleted == 0
                        ? tr(
                            context,
                            'Empty. Deleted items wait here 30 days.',
                            'Trống. Mục đã xóa chờ ở đây 30 ngày.',
                          )
                        : tr(
                            context,
                            deleted == 1
                                ? '1 item, kept 30 days'
                                : '$deleted items, kept 30 days',
                            '$deleted mục, giữ 30 ngày',
                          ),
                    navigates: true,
                    onTap: () => Navigator.of(context).pushNamed('/trash'),
                  ),
                  SettingsRow(
                    key: const Key('set-library-tools'),
                    icon: Icons.handyman_outlined,
                    title: tr(context, 'Library tools', 'Công cụ thư viện'),
                    subtitle: tr(
                      context,
                      'How links open, duplicates, link checks, storage',
                      'Cách mở link, mục trùng, kiểm tra link, dung lượng',
                    ),
                    navigates: true,
                    onTap: () => openLibraryTools(context, scope),
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
                      'Everything this app keeps on this device. Cannot be undone.',
                      'Mọi thứ app lưu trên máy này. Không hoàn tác được.',
                    ),
                    onTap: () => deleteEverything(context, scope),
                  ),
                ],
              ),
            ],
          ),

          // Help.
          SettingsGroup(
            title: tr(context, 'Help', 'Trợ giúp'),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsRow(
                    key: const Key('set-howto'),
                    icon: Icons.school_outlined,
                    title: tr(context, 'How to use', 'Cách dùng'),
                    subtitle: tr(
                      context,
                      'The welcome again, and each thing step by step',
                      'Xem lại phần giới thiệu và từng việc theo từng bước',
                    ),
                    navigates: true,
                    onTap: () => Navigator.pushNamed(context, '/how-to'),
                  ),
                ],
              ),
            ],
          ),

          // About.
          SettingsGroup(
            title: tr(context, 'About', 'Giới thiệu'),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsRow(
                    key: const Key('set-feedback'),
                    icon: Icons.mail_outline,
                    title: tr(context, 'Send feedback', 'Gửi góp ý'),
                    subtitle: feedbackEmail,
                    onTap: () => sendFeedback(context),
                  ),
                  SettingsRow(
                    key: const Key('save-privacy'),
                    icon: Icons.policy_outlined,
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
        ],
      );
    },
  );
}

/// The first thing in Settings: Pro, on a soft card in the app's hue; a
/// thank-you once it is owned.
class _ProCard extends StatelessWidget {
  const _ProCard();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final pro = hasPro(context);
    return Material(
      color: p.tint,
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      child: InkWell(
        key: const Key('set-pro'),
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
        onTap: () => Navigator.pushNamed(context, '/pro'),
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_outlined, size: 32, color: p.ink),
              const SizedBox(width: HandySpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pro
                          ? tr(context, 'Pro is yours', 'Bạn đã có Pro')
                          : tr(context, 'Upgrade to Pro', 'Nâng cấp Pro'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pro
                          ? tr(
                              context,
                              'Thank you. Everything Pro adds is on.',
                              'Cảm ơn bạn. Mọi thứ của Pro đã mở.',
                            )
                          : tr(
                              context,
                              'Themes, layouts, highlights, deeper search. One payment; buy or restore inside.',
                              'Chủ đề, kiểu trình bày, đánh dấu, tìm sâu. Trả một lần; mua hoặc khôi phục ở trong.',
                            ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: p.ink),
                    ),
                  ],
                ),
              ),
              Icon(
                pro ? Icons.check_circle : Icons.chevron_right,
                color: p.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
