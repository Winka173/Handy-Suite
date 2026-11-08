import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_monetization/handy_monetization.dart';
import '../home/my_work_page.dart';
import '../card/card_templates_ui.dart';
import '../design/theme.dart';
import '../features/portability.dart';
import '../pro/pro.dart';
import '../scope.dart';
import 'data_rows.dart';
import 'help_links.dart';
import 'widgets_page.dart';
import 'notifications_page.dart';
import 'settings_parts.dart';
import '../sync/drive_section.dart';
import '../sync/drive_sync.dart';

/// Settings, as Handy Bookmark and Sticky Wall have them: Pro first, then
/// General (language, light or dark, reminders), Automations, Data (backup
/// and restore, the automatic copy, the archive, Trash, delete everything),
/// Help (How to use) and About (feedback, privacy policy, terms, licenses,
/// the other Handy apps). Every control saves itself.
class SettingsPage extends StatelessWidget {
  final BoardsScope scope;
  const SettingsPage({super.key, required this.scope});

  Future<void> _pref(BuildContext context, String key, Object? value) =>
      scope.run(
        context,
        () => scope.controller.change(
          (s) => s.copy(preferences: {...s.preferences, key: value}),
          history: false,
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.controller.state;
      if (s == null) return const Scaffold(body: HandyLoading());
      final prefs = s.preferences;
      final system = tr(context, 'System', 'Hệ thống');
      final archivedBoards = s
          .rows('boards')
          .where((b) => b.flag('archived'))
          .length;
      final archived = archivedCards(s).length;
      final trashed = s
          .rows('tasks')
          .where((t) => t.flag('trashed') && t.data['parent'] == null)
          .length;
      final reminders = s.rows('reminders').where((r) => r.flag('enabled'));
      final pro = hasPro(context);
      final automation = prefs['automation'] is Map
          ? Map<String, dynamic>.from(prefs['automation'] as Map)
          : <String, dynamic>{};
      Future<void> auto(String key, bool on) async {
        if (on && !await requirePro(context, ProFeature.automation)) return;
        if (!context.mounted) return;
        await _pref(context, 'automation', {...automation, key: on});
      }

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
                    value: prefs['locale'] as String? ?? 'system',
                    options: [
                      ('en', 'English'),
                      ('vi', 'Tiếng Việt'),
                      ('system', system),
                    ],
                    onChanged: (v) => _pref(context, 'locale', v),
                  ),
                  SettingsChoice<String>(
                    controlKey: const Key('settings-theme'),
                    icon: Icons.contrast,
                    title: tr(context, 'Light or dark', 'Sáng hay tối'),
                    value: prefs['theme'] as String? ?? 'system',
                    options: [
                      ('light', tr(context, 'Light', 'Sáng')),
                      ('dark', tr(context, 'Dark', 'Tối')),
                      ('system', system),
                    ],
                    onChanged: (v) => _pref(context, 'theme', v),
                  ),
                  SettingsRow(
                    key: const Key('settings-reminders'),
                    icon: Icons.notifications_none,
                    title: tr(context, 'Notifications', 'Thông báo'),
                    subtitle: [
                      reminders.isEmpty
                          ? tr(
                              context,
                              'None set. Set one on a card.',
                              'Chưa có. Đặt nhắc trên từng thẻ.',
                            )
                          : tr(
                              context,
                              reminders.length == 1
                                  ? '1 reminder set'
                                  : '${reminders.length} reminders set',
                              'Đang có ${reminders.length} lời nhắc',
                            ),
                      if (!scope.reminders.supported)
                        tr(
                          context,
                          'They show inside the app here.',
                          'Ở đây nhắc hiện ngay trong app.',
                        ),
                    ].join(' '),
                    navigates: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => NotificationsPage(scope: scope),
                      ),
                    ),
                  ),
                  SettingsRow(
                    key: const Key('settings-home-widget'),
                    icon: Icons.widgets_outlined,
                    title: tr(
                      context,
                      'Home-screen widgets',
                      'Widget màn hình chính',
                    ),
                    subtitle: tr(
                      context,
                      'Today, progress, left behind; My Work and Week with Pro.',
                      'Hôm nay, tiến độ, còn tồn; Việc của tôi và Tuần với Pro.',
                    ),
                    navigates: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => WidgetsPage(scope: scope),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Automations (Pro).
          SettingsGroup(
            title: tr(context, 'Automations', 'Tự động hoá'),
            note: tr(
              context,
              'Pro. Each one is off until you turn it on; Undo always works.',
              'Pro. Mỗi cái tắt cho tới khi bạn bật; luôn hoàn tác được.',
            ),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsSwitch(
                    key: const Key('auto-subtasks-done'),
                    icon: Icons.task_alt,
                    title: tr(
                      context,
                      'Finish a card when its subtasks are done',
                      'Chuyển thẻ sang cột xong khi đủ việc con',
                    ),
                    subtitle: tr(
                      context,
                      'Moves it to the board’s finished column.',
                      'Chuyển thẻ sang cột “đã xong” của bảng.',
                    ),
                    value: pro && automation['subtasksDone'] == true,
                    onChanged: (v) => auto('subtasksDone', v),
                  ),
                  SettingsSwitch(
                    key: const Key('auto-archive-done'),
                    icon: Icons.archive_outlined,
                    title: tr(
                      context,
                      'Archive finished cards after 14 days',
                      'Lưu trữ thẻ đã xong sau 14 ngày',
                    ),
                    subtitle: tr(
                      context,
                      'They wait in Data › Archived cards.',
                      'Thẻ nằm ở Dữ liệu › Thẻ đã lưu trữ.',
                    ),
                    value: pro && automation['archiveDone'] == true,
                    onChanged: (v) => auto('archiveDone', v),
                  ),
                ],
              ),
            ],
          ),

          // Data.
          SettingsGroup(
            title: tr(context, 'Data', 'Dữ liệu'),
            note: tr(
              context,
              'Kept on this device. It leaves only when you back it up, sync, export or share it.',
              'Lưu trên máy này. Chỉ rời máy khi bạn sao lưu, đồng bộ, xuất hoặc chia sẻ.',
            ),
            children: [
              if (scope.drive case final drive?)
                SettingsPanel(
                  gap: false,
                  rows: [
                    ListenableBuilder(
                      listenable: drive,
                      builder: (context, _) => SettingsRow(
                        key: const Key('settings-sync'),
                        icon: Icons.sync,
                        title: tr(context, 'Sync', 'Đồng bộ'),
                        subtitle: _syncLine(context, drive),
                        navigates: true,
                        onTap: () => pushSettingsView(
                          context,
                          tr(context, 'Sync', 'Đồng bộ'),
                          listenable: drive,
                          (context) => [DriveSyncPanel(drive: drive)],
                        ),
                      ),
                    ),
                  ],
                ),
              SettingsPanel(
                gap: false,
                title: tr(context, 'Backup and restore', 'Sao lưu & khôi phục'),
                rows: [
                  Padding(
                    padding: const EdgeInsets.all(HandySpace.m),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('settings-backup'),
                            onPressed: () => scope.run(
                              context,
                              () => exportBoards(context, scope, null),
                            ),
                            icon: const Icon(Icons.backup_outlined, size: 20),
                            label: Text(tr(context, 'Back up', 'Sao lưu')),
                          ),
                        ),
                        const SizedBox(width: HandySpace.m),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('settings-restore'),
                            onPressed: () => scope.run(
                              context,
                              () => importBoards(context, scope, null),
                            ),
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
                    key: const Key('settings-archived'),
                    icon: Icons.inventory_2_outlined,
                    title: tr(context, 'Archived boards', 'Bảng đã lưu trữ'),
                    subtitle: archivedBoards == 0
                        ? tr(context, 'None', 'Không có')
                        : tr(
                            context,
                            archivedBoards == 1
                                ? '1 board'
                                : '$archivedBoards boards',
                            '$archivedBoards bảng',
                          ),
                    navigates: archivedBoards > 0,
                    onTap: archivedBoards == 0
                        ? null
                        : () => showArchived(context, scope, boards: true),
                  ),
                  SettingsRow(
                    key: const Key('settings-archived-cards'),
                    icon: Icons.archive_outlined,
                    title: tr(context, 'Archived cards', 'Thẻ đã lưu trữ'),
                    subtitle: archived == 0
                        ? tr(context, 'None', 'Không có')
                        : tr(
                            context,
                            archived == 1 ? '1 card' : '$archived cards',
                            '$archived thẻ',
                          ),
                    navigates: archived > 0,
                    onTap: archived == 0
                        ? null
                        : () => showArchived(context, scope, boards: false),
                  ),
                  SettingsRow(
                    key: const Key('settings-trash'),
                    icon: Icons.delete_outline,
                    title: tr(context, 'Trash', 'Thùng rác'),
                    subtitle: trashed == 0
                        ? tr(context, 'Empty', 'Trống')
                        : tr(
                            context,
                            trashed == 1 ? '1 card' : '$trashed cards',
                            '$trashed thẻ',
                          ),
                    navigates: true,
                    onTap: () => Navigator.pushNamed(context, '/trash'),
                  ),
                  SettingsRow(
                    key: const Key('settings-delete-all'),
                    icon: Icons.delete_forever_outlined,
                    destructive: true,
                    title: tr(
                      context,
                      'Delete all data',
                      'Xoá toàn bộ dữ liệu',
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
                    key: const Key('settings-howto'),
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
                  SettingsChoice<String>(
                    controlKey: const Key('settings-purpose'),
                    icon: Icons.recommend_outlined,
                    title: tr(
                      context,
                      'Suggest templates for',
                      'Gợi ý mẫu cho',
                    ),
                    value: prefs['purpose'] as String? ?? 'none',
                    options: [
                      ('study', tr(context, 'Study', 'Học tập')),
                      ('work', tr(context, 'Work', 'Công việc')),
                      ('none', tr(context, 'Neither', 'Không chọn')),
                    ],
                    onChanged: (v) =>
                        _pref(context, 'purpose', v == 'none' ? null : v),
                  ),
                  SettingsRow(
                    key: const Key('settings-carry-over'),
                    icon: Icons.event_repeat_outlined,
                    title: tr(
                      context,
                      'Smart carry-over',
                      'Tự chuyển việc tồn',
                    ),
                    subtitle: switch (object(
                      scope.state.preferences['carryOver'] ?? {},
                    )['mode']) {
                      'auto' => tr(context, 'Moves by itself', 'Tự chuyển'),
                      'review' => tr(
                        context,
                        'Asks each new day',
                        'Hỏi mỗi ngày mới',
                      ),
                      _ => tr(context, 'Off', 'Tắt'),
                    },
                    navigates: true,
                    onTap: () => carryOverSettings(context, scope),
                  ),
                  SettingsRow(
                    key: const Key('settings-card-templates'),
                    icon: Icons.content_copy_outlined,
                    title: tr(context, 'My card templates', 'Mẫu thẻ của tôi'),
                    navigates: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CardTemplatesPage(scope: scope),
                      ),
                    ),
                  ),
                  SettingsRow(
                    key: const Key('settings-plans'),
                    icon: Icons.table_chart_outlined,
                    title: tr(
                      context,
                      'What Free and Pro include',
                      'Free và Pro gồm gì',
                    ),
                    navigates: true,
                    onTap: () => showPlans(context),
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
                    key: const Key('settings-feedback'),
                    icon: Icons.mail_outline,
                    title: tr(context, 'Send feedback', 'Gửi góp ý'),
                    subtitle: feedbackEmail,
                    onTap: () => sendFeedback(context),
                  ),
                  SettingsRow(
                    key: const Key('settings-privacy'),
                    icon: Icons.policy_outlined,
                    title: tr(
                      context,
                      'Privacy policy',
                      'Chính sách quyền riêng tư',
                    ),
                    subtitle: tr(
                      context,
                      'No account, no tracking, no cloud',
                      'Không tài khoản, không theo dõi, không đám mây',
                    ),
                    navigates: true,
                    onTap: () => openLegal(context, privacyPolicyUrl!),
                  ),
                  SettingsRow(
                    key: const Key('settings-terms'),
                    icon: Icons.gavel_outlined,
                    title: tr(
                      context,
                      'Terms of service',
                      'Điều khoản sử dụng',
                    ),
                    navigates: true,
                    onTap: () => openLegal(context, termsUrl!),
                  ),
                  SettingsRow(
                    key: const Key('settings-licenses'),
                    icon: Icons.info_outline,
                    title: tr(context, 'Licenses', 'Giấy phép'),
                    subtitle: tr(
                      context,
                      'Open-source licenses and fonts',
                      'Giấy phép mã nguồn mở và phông chữ',
                    ),
                    navigates: true,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Handy Boards',
                    ),
                  ),
                ],
              ),
              const KitSection(child: HandyMoreApps(app: 'boards')),
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
    final p = BoardsPalette.of(context);
    final pro = hasPro(context);
    final price = LifetimeScope.maybeOf(context)?.snapshot?.price;
    return Material(
      color: p.tint,
      borderRadius: BorderRadius.circular(BoardsRadii.tile),
      child: InkWell(
        key: const Key('settings-pro'),
        borderRadius: BorderRadius.circular(BoardsRadii.tile),
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
                              'Templates, covers, looks, repeating cards, automations, designed exports. One payment${price == null ? '' : ' ($price)'}; buy or restore inside.',
                              'Mẫu, ảnh bìa, giao diện, thẻ lặp lại, tự động hoá, bản xuất đẹp. Trả một lần${price == null ? '' : ' ($price)'}; mua hoặc khôi phục ở trong.',
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

/// Free and Pro side by side, as they really are in this version.
Future<void> showPlans(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheet) {
    final theme = Theme.of(sheet);
    final rows = <(String, String, String)>[
      (
        tr(
          sheet,
          'Boards, columns, categories, cards, subtasks',
          'Bảng, cột, nhóm, thẻ, việc con',
        ),
        tr(sheet, 'Unlimited', 'Không giới hạn'),
        tr(sheet, 'Unlimited', 'Không giới hạn'),
      ),
      (
        tr(
          sheet,
          'Due dates, reminders, key dates, Time view',
          'Hạn, nhắc, ngày quan trọng, chế độ Thời gian',
        ),
        '✓',
        '✓',
      ),
      (
        tr(
          sheet,
          'Search, category focus and filter',
          'Tìm, làm nổi và lọc nhóm',
        ),
        '✓',
        '✓',
      ),
      (
        tr(
          sheet,
          'Backup, restore, auto backup, Trash, archive',
          'Sao lưu, khôi phục, tự sao lưu, thùng rác, lưu trữ',
        ),
        '✓',
        '✓',
      ),
      (
        tr(sheet, 'Templates', 'Mẫu bảng'),
        tr(
          sheet,
          '$freeTemplateCount + blank',
          '$freeTemplateCount + bảng trống',
        ),
        '30 + ${tr(sheet, 'blank', 'bảng trống')}',
      ),
      (tr(sheet, 'Covers', 'Ảnh bìa'), '30', '60'),
      (tr(sheet, 'Board looks', 'Giao diện bảng'), '5', '15'),
      (
        tr(sheet, 'Export', 'Xuất'),
        tr(
          sheet,
          'Plain picture/PDF, CSV, Markdown, ICS',
          'Ảnh/PDF thường, CSV, Markdown, ICS',
        ),
        tr(sheet, '+ Poster and Printable', '+ Poster và Bản in'),
      ),
      (
        tr(
          sheet,
          'Repeating cards, automations, insights',
          'Thẻ lặp lại, tự động hoá, thống kê',
        ),
        '–',
        '✓',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(sheet, 'Free and Pro', 'Free và Pro'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                sheet,
                'Pro is one payment, no subscription, no ads in either. A board you made always stays yours to edit, with or without Pro.',
                'Pro trả một lần, không thuê bao; cả hai đều không quảng cáo. Bảng đã tạo luôn sửa được, dù có Pro hay không.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.6),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    Text(
                      tr(sheet, 'Free', 'Miễn phí'),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text('Pro', style: theme.textTheme.titleSmall),
                  ],
                ),
                for (final (what, free, pro) in rows)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(what, style: theme.textTheme.bodyMedium),
                      ),
                      Text(free, style: theme.textTheme.bodyMedium),
                      Text(pro, style: theme.textTheme.bodyMedium),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

/// "Google Drive · synced 8 Nov 14:20", or what is in the way.
String _syncLine(BuildContext context, BoardsDriveSync d) {
  if (!d.enabled)
    return tr(
      context,
      'Off. Google Drive keeps your devices in step',
      'Đang tắt. Google Drive giữ các máy khớp nhau',
    );
  final at = d.lastSync;
  return switch (d.state) {
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
