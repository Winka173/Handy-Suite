import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_page.dart' show showUndo;
import '../design/theme.dart';
import '../features/portability.dart';
import '../pro/pro.dart';
import '../scope.dart';
import '../ui/look.dart';
import 'settings_parts.dart';

/// Settings, built like Handy Bookmark's: a few groups, each a title and
/// its panels of rows; every switch keeps itself.
class SettingsPage extends StatelessWidget {
  final BoardsScope scope;
  final VoidCallback onReplayWelcome;
  const SettingsPage({
    super.key,
    required this.scope,
    required this.onReplayWelcome,
  });

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
      final p = BoardsPalette.of(context);
      final archived = s
          .rows('boards')
          .where((b) => b.flag('archived'))
          .toList();
      final trashed = s
          .rows('tasks')
          .where((t) => t.flag('trashed') && t.data['parent'] == null)
          .length;
      final store = LifetimeScope.maybeOf(context);
      final pro = hasPro(context);
      final automation = prefs['automation'] is Map
          ? Map<String, dynamic>.from(prefs['automation'] as Map)
          : <String, dynamic>{};
      Future<void> auto(String key, bool on) async {
        if (on && !await requirePro(context, ProFeature.automation)) return;
        if (!context.mounted) return;
        await _pref(context, 'automation', {...automation, key: on});
      }

      return Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Settings', 'Cài đặt'))),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                SettingsGroup(
                  first: true,
                  title: tr(context, 'Look', 'Giao diện'),
                  note: tr(
                    context,
                    'How the app looks on this device.',
                    'App trông thế nào trên máy này.',
                  ),
                  children: [
                    SettingsPanel(
                      gap: false,
                      rows: [
                        SettingsChoice<String>(
                          icon: Icons.contrast,
                          title: tr(context, 'Theme', 'Chủ đề'),
                          value: prefs['theme'] as String? ?? 'system',
                          controlKey: const Key('settings-theme'),
                          options: [
                            ('system', tr(context, 'System', 'Theo máy')),
                            ('light', tr(context, 'Light', 'Sáng')),
                            ('dark', tr(context, 'Dark', 'Tối')),
                          ],
                          onChanged: (v) => _pref(context, 'theme', v),
                        ),
                        SettingsChoice<String>(
                          icon: Icons.translate,
                          title: tr(context, 'Language', 'Ngôn ngữ'),
                          value: prefs['locale'] as String? ?? 'system',
                          controlKey: const Key('settings-locale'),
                          options: [
                            ('system', tr(context, 'System', 'Theo máy')),
                            ('en', 'English'),
                            ('vi', 'Tiếng Việt'),
                          ],
                          onChanged: (v) => _pref(context, 'locale', v),
                        ),
                      ],
                    ),
                  ],
                ),
                SettingsGroup(
                  title: tr(context, 'Reminders', 'Nhắc việc'),
                  note: tr(
                    context,
                    'Set on a card. Permission is asked the first time you set one.',
                    'Đặt trên từng thẻ. Quyền thông báo chỉ được hỏi khi bạn đặt nhắc lần đầu.',
                  ),
                  children: [
                    SettingsPanel(
                      gap: false,
                      rows: [
                        SettingsRow(
                          icon: Icons.notifications_none,
                          title: scope.reminders.supported
                              ? tr(
                                  context,
                                  'Notifications on this device',
                                  'Thông báo trên máy này',
                                )
                              : tr(
                                  context,
                                  'Reminders show inside the app',
                                  'Nhắc hiện ngay trong app',
                                ),
                          subtitle: tr(
                            context,
                            '${s.rows('reminders').where((r) => r.flag('enabled')).length} reminders set',
                            'Đang có ${s.rows('reminders').where((r) => r.flag('enabled')).length} lời nhắc',
                          ),
                          trailing: scope.reminders.supported
                              ? TextButton(
                                  onPressed: () => scope.reminders.request(),
                                  child: Text(tr(context, 'Allow', 'Cho phép')),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
                SettingsGroup(
                  title: tr(context, 'Pro', 'Pro'),
                  note: pro
                      ? tr(
                          context,
                          'Pro Lifetime is active.',
                          'Pro trọn đời đang dùng.',
                        )
                      : tr(
                          context,
                          'One purchase, yours to keep. Boards stay free.',
                          'Mua một lần, dùng mãi. Bảng vẫn miễn phí.',
                        ),
                  children: [
                    SettingsPanel(
                      gap: false,
                      rows: [
                        SettingsRow(
                          key: const Key('settings-pro'),
                          icon: Icons.workspace_premium_outlined,
                          title: 'Handy Boards Pro',
                          subtitle: pro
                              ? tr(
                                  context,
                                  'Thank you for supporting Handy Boards.',
                                  'Cảm ơn bạn đã ủng hộ Handy Boards.',
                                )
                              : store?.snapshot?.price != null
                              ? tr(
                                  context,
                                  'One-time ${store?.snapshot?.price}',
                                  'Một lần ${store?.snapshot?.price}',
                                )
                              : tr(
                                  context,
                                  'Templates, covers, automations, designed exports',
                                  'Mẫu, bìa, tự động hoá, bản xuất đẹp',
                                ),
                          navigates: true,
                          onTap: () => Navigator.pushNamed(context, '/pro'),
                        ),
                      ],
                    ),
                    SettingsPanel(
                      title: tr(context, 'Automations', 'Tự động hoá'),
                      note: tr(
                        context,
                        'Each one is off until you turn it on. Undo always works.',
                        'Mỗi cái tắt cho tới khi bạn bật. Luôn hoàn tác được.',
                      ),
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
                            'Archived cards can be brought back from Data.',
                            'Thẻ đã lưu trữ khôi phục được ở mục Dữ liệu.',
                          ),
                          value: pro && automation['archiveDone'] == true,
                          onChanged: (v) => auto('archiveDone', v),
                        ),
                      ],
                    ),
                  ],
                ),
                SettingsGroup(
                  title: tr(context, 'Data', 'Dữ liệu'),
                  note: tr(
                    context,
                    'Your boards live only on this device. A backup is the way to move or keep them.',
                    'Bảng chỉ nằm trên máy này. Sao lưu là cách để chuyển hoặc giữ chúng.',
                  ),
                  children: [
                    SettingsPanel(
                      gap: false,
                      rows: [
                        SettingsRow(
                          key: const Key('settings-backup'),
                          icon: Icons.save_alt,
                          title: tr(
                            context,
                            'Back up all boards',
                            'Sao lưu mọi bảng',
                          ),
                          subtitle: tr(
                            context,
                            'A ZIP file with cards, covers and photos.',
                            'Một tệp ZIP gồm thẻ, ảnh bìa và ảnh.',
                          ),
                          navigates: true,
                          onTap: () => scope.run(
                            context,
                            () => exportBoards(context, scope, null),
                          ),
                        ),
                        SettingsRow(
                          key: const Key('settings-restore'),
                          icon: Icons.restore,
                          title: tr(
                            context,
                            'Restore a backup',
                            'Khôi phục bản sao lưu',
                          ),
                          subtitle: tr(
                            context,
                            'Preview first; merge or replace.',
                            'Xem trước; gộp hoặc thay thế.',
                          ),
                          navigates: true,
                          onTap: () => scope.run(
                            context,
                            () => importBoards(context, scope, null),
                          ),
                        ),
                      ],
                    ),
                    SettingsPanel(
                      title: tr(context, 'Put away', 'Đã cất đi'),
                      rows: [
                        SettingsRow(
                          key: const Key('settings-archived'),
                          icon: Icons.inventory_2_outlined,
                          title: tr(
                            context,
                            'Archived boards',
                            'Bảng đã lưu trữ',
                          ),
                          subtitle: archived.isEmpty
                              ? tr(context, 'None', 'Không có')
                              : archived.map((b) => b.str('title')).join(', '),
                          navigates: archived.isNotEmpty,
                          onTap: archived.isEmpty
                              ? null
                              : () => _archived(context, archived),
                        ),
                        SettingsRow(
                          key: const Key('settings-trash'),
                          icon: Icons.delete_outline,
                          title: tr(context, 'Trash', 'Thùng rác'),
                          subtitle: trashed == 0
                              ? tr(context, 'Empty', 'Trống')
                              : tr(context, '$trashed cards', '$trashed thẻ'),
                          navigates: trashed > 0,
                          onTap: trashed == 0
                              ? null
                              : () => Navigator.pushNamed(context, '/trash'),
                        ),
                      ],
                    ),
                  ],
                ),
                SettingsGroup(
                  title: tr(context, 'Help', 'Trợ giúp'),
                  children: [
                    SettingsPanel(
                      gap: false,
                      rows: [
                        SettingsRow(
                          key: const Key('settings-welcome'),
                          icon: Icons.play_circle_outline,
                          title: tr(
                            context,
                            'Replay the 30-second tour',
                            'Xem lại hướng dẫn 30 giây',
                          ),
                          navigates: true,
                          onTap: onReplayWelcome,
                        ),
                        SettingsRow(
                          icon: Icons.keyboard_outlined,
                          title: tr(context, 'Keyboard', 'Bàn phím'),
                          subtitle: tr(
                            context,
                            'Ctrl+F search · Ctrl+Z undo · Alt+arrows move the focused card',
                            'Ctrl+F tìm · Ctrl+Z hoàn tác · Alt+mũi tên chuyển thẻ đang chọn',
                          ),
                        ),
                        SettingsRow(
                          icon: Icons.lock_outline,
                          title: tr(context, 'Privacy', 'Quyền riêng tư'),
                          subtitle: tr(
                            context,
                            'No account, no tracking, no cloud. Boards, covers and photos stay on this device.',
                            'Không tài khoản, không theo dõi, không đám mây. Bảng, ảnh bìa và ảnh nằm trên máy này.',
                          ),
                        ),
                      ],
                    ),
                    const KitSection(child: HandyMoreApps(app: 'boards')),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Handy Boards',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _archived(BuildContext context, List<BoardRecord> boards) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (sheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final b in boards)
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: boardCover(b),
                    ),
                  ),
                  title: Text(b.str('title')),
                  trailing: TextButton(
                    onPressed: () async {
                      Navigator.pop(sheet);
                      await scope.run(
                        context,
                        () => scope.controller.change(
                          (s) => s.put(
                            'boards',
                            s.get('boards', b.id).copy({'archived': false}),
                          ),
                        ),
                      );
                      if (context.mounted)
                        showUndo(
                          context,
                          scope,
                          tr(
                            context,
                            'Board is back on the home',
                            'Bảng đã trở lại Trang chủ',
                          ),
                        );
                    },
                    child: Text(tr(context, 'Restore', 'Khôi phục')),
                  ),
                ),
            ],
          ),
        ),
      );
}
