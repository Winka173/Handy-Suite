import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';
import 'data.dart';

/// Spend's settings: the shared page with money, privacy, reminders,
/// categories and the ledger's data added.
class SpendSettingsPage extends StatelessWidget {
  final SpendScope scope;
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  const SpendSettingsPage({
    super.key,
    required this.scope,
    required this.read,
    required this.save,
  });

  Future<void> _set(
    BuildContext context,
    String label,
    Map<String, dynamic> changes,
  ) => scope.write(
    context,
    () => scope.controller.change(
      (s) => s.copy({
        'settings': {...s.settings, ...changes},
      }),
      label,
    ),
  );

  Future<void> _money(BuildContext context) {
    final s = scope.state;
    return showSpendForm(
      context,
      scope,
      title: tr(context, 'Money and dates', 'Tiền và ngày'),
      fields: [
        SpendField(
          'currency',
          'Report currency',
          'Loại tiền báo cáo',
          kind: FieldKind.choice,
          options: {for (final k in scales.keys) k: k},
          helpEn: 'Plans and totals use it. Nothing is converted.',
          helpVi: 'Kế hoạch và tổng cộng dùng loại này. Không tự quy đổi.',
        ),
        const SpendField(
          'zone',
          'Time zone',
          'Múi giờ',
          helpEn:
              'Decides which day an entry belongs to, e.g. Asia/Ho_Chi_Minh.',
          helpVi:
              'Quyết định giao dịch thuộc ngày nào, ví dụ Asia/Ho_Chi_Minh.',
        ),
        SpendField(
          'dateFormat',
          'Dates',
          'Cách ghi ngày',
          kind: FieldKind.choice,
          options: {
            'locale': tr(context, 'As in my language', 'Theo ngôn ngữ'),
            'iso': 'YYYY-MM-DD',
          },
        ),
        SpendField(
          'buffer',
          'Always keep',
          'Luôn chừa lại',
          kind: FieldKind.money,
          currency: (v) => v['currency'] as String,
          helpEn: 'Kept out of Free to spend, as a floor.',
          helpVi: 'Không tính vào Có thể chi, như một mức sàn.',
        ),
      ],
      initial: {
        'currency': s.currency,
        'zone': s.zone,
        'dateFormat': s.settings['dateFormat'] ?? 'locale',
        'buffer': BigInt.parse(s.settings['buffer'] as String? ?? '0'),
      },
      save: (v) async {
        location(v['zone'] as String);
        await scope.controller.change(
          (s) => s.copy({
            'settings': {
              ...s.settings,
              'currency': v['currency'],
              'zone': v['zone'],
              'dateFormat': v['dateFormat'],
              'buffer': '${v['buffer']}',
            },
          }),
          'financial_settings',
        );
      },
    );
  }

  Future<void> _lock(BuildContext context, bool on) async {
    if (!await scope.privacy.available()) {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Set up a screen lock or fingerprint on this device first.',
            'Hãy cài khóa màn hình hoặc vân tay cho máy trước.',
          ),
        );
      return;
    }
    if (!context.mounted) return;
    final ok = await scope.privacy.unlock(
      tr(context, 'Confirm the Handy Spend lock', 'Xác nhận khóa Handy Spend'),
    );
    if (!ok || !context.mounted) return;
    await _set(context, 'device_lock', {
      'deviceLock': on,
      'lockSeconds': scope.state.settings['lockSeconds'] ?? 60,
    });
  }

  Future<void> _guard(
    BuildContext context,
    Future<String?> Function() task,
  ) async {
    try {
      final message = await task();
      if (message != null && context.mounted)
        showHandyMessage(context, message);
    } catch (e) {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Not done: ${errorText(context, e)}. Nothing changed.',
            'Chưa xong: ${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.state;
      final c = HandyColors.of(context);
      Widget value(String text) => Text(text, style: TextStyle(color: c.muted));
      return HandySettingsPage(
        appName: 'Handy Spend',
        theme: read().theme,
        locale: read().locale,
        onTheme: (v) => save(read().copyWith(theme: v)),
        onLocale: (v) => save(read().copyWith(locale: v)),
        onReset: () => save(HandyPreferences()),
        sections: [
          HandySettingsSection(
            title: tr(context, 'Money and dates', 'Tiền và ngày'),
            children: [
              HandyTile(
                key: const Key('set-currency'),
                title: tr(context, 'Report currency', 'Loại tiền báo cáo'),
                trailing: value(s.currency),
                onTap: () => _money(context),
              ),
              HandyTile(
                title: tr(context, 'Time zone', 'Múi giờ'),
                trailing: value(s.zone),
                onTap: () => _money(context),
              ),
              HandyTile(
                key: const Key('set-buffer'),
                title: tr(context, 'Always keep', 'Luôn chừa lại'),
                trailing: value(
                  moneyText(
                    context,
                    scope,
                    BigInt.parse(s.settings['buffer'] as String? ?? '0'),
                    s.currency,
                  ),
                ),
                onTap: () => _money(context),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Privacy', 'Riêng tư'),
            description: tr(
              context,
              'Everything stays on this device and is not encrypted by the app. No bank login, no SMS reading, no account, no cloud.',
              'Mọi thứ ở trên máy này và app không mã hóa. Không đăng nhập ngân hàng, không đọc SMS, không tài khoản, không cloud.',
            ),
            children: [
              SwitchListTile.adaptive(
                key: const Key('set-hide'),
                title: Text(tr(context, 'Hide amounts', 'Ẩn số tiền')),
                subtitle: Text(
                  tr(
                    context,
                    'Only covers the screen.',
                    'Chỉ che trên màn hình.',
                  ),
                ),
                value: scope.hidden,
                onChanged: (v) =>
                    _set(context, 'privacy_mask', {'hideAmounts': v}),
              ),
              if (scope.privacy.supported) ...[
                SwitchListTile.adaptive(
                  key: const Key('set-lock'),
                  title: Text(
                    tr(context, 'Lock with this device', 'Khóa bằng máy này'),
                  ),
                  subtitle: Text(
                    tr(
                      context,
                      'Fingerprint, face or PIN. It does not encrypt the data or exports.',
                      'Vân tay, khuôn mặt hoặc PIN. Không mã hóa dữ liệu hay file xuất.',
                    ),
                  ),
                  value: s.settings['deviceLock'] == true,
                  onChanged: (v) => _lock(context, v),
                ),
                if (s.settings['deviceLock'] == true)
                  HandySettingRow(
                    label: tr(
                      context,
                      'Lock after leaving',
                      'Khóa sau khi rời app',
                    ),
                    control: DropdownButton<int>(
                      key: const Key('set-lock-seconds'),
                      value: s.settings['lockSeconds'] as int? ?? 60,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final (sec, en, vi) in const [
                          (0, 'At once', 'Ngay'),
                          (30, '30 seconds', '30 giây'),
                          (60, '1 minute', '1 phút'),
                          (300, '5 minutes', '5 phút'),
                        ])
                          DropdownMenuItem(
                            value: sec,
                            child: Text(tr(context, en, vi)),
                          ),
                      ],
                      onChanged: (v) =>
                          _set(context, 'lock_timeout', {'lockSeconds': v}),
                    ),
                  ),
              ],
            ],
          ),
          if (scope.reminders.supported)
            HandySettingsSection(
              title: tr(context, 'Reminders', 'Nhắc'),
              description: tr(
                context,
                'At 9:00 on the day a payment marked "remind" is due. The notice shows no amount or name.',
                'Lúc 9:00 ngày đến hạn của khoản có bật nhắc. Thông báo không có số tiền hay tên.',
              ),
              children: [
                SwitchListTile.adaptive(
                  key: const Key('set-reminders'),
                  title: Text(tr(context, 'Remind me', 'Nhắc tôi')),
                  value: s.settings['notifications'] == true,
                  onChanged: (v) async {
                    if (v && !await scope.reminders.request()) {
                      if (context.mounted)
                        showHandyMessage(
                          context,
                          tr(
                            context,
                            'Notifications are off for Handy Spend in the system settings.',
                            'Thông báo của Handy Spend đang tắt trong cài đặt hệ thống.',
                          ),
                        );
                      return;
                    }
                    if (context.mounted)
                      await _set(
                        context,
                        v ? 'enable_reminders' : 'disable_reminders',
                        {'notifications': v},
                      );
                  },
                ),
              ],
            ),
          HandySettingsSection(
            title: tr(context, 'Categories', 'Danh mục'),
            children: [
              HandyTile(
                key: const Key('set-categories'),
                title: tr(context, 'Categories', 'Danh mục'),
                trailing: value('${s.categories.length}'),
                navigates: true,
                onTap: () =>
                    Navigator.pushNamed(context, '/settings/categories'),
              ),
              HandyTile(
                key: const Key('set-rules'),
                title: tr(context, 'Category rules', 'Quy tắc danh mục'),
                trailing: value('${s.rules.length}'),
                navigates: true,
                onTap: () => Navigator.pushNamed(context, '/settings/rules'),
              ),
            ],
          ),
          if (scope.autoBackup != null)
            HandyAutoBackupSection(backup: scope.autoBackup!),
          HandySettingsSection(
            title: tr(context, 'Your ledger', 'Sổ của bạn'),
            description: tr(
              context,
              'Keep a backup somewhere else, above all on the web, where the browser may clear its storage.',
              'Hãy giữ một bản sao lưu ở nơi khác, nhất là trên web vì trình duyệt có thể xóa dữ liệu.',
            ),
            children: [
              HandyTile(
                key: const Key('spend-backup'),
                icon: Icons.archive_outlined,
                title: tr(context, 'Back up as ZIP', 'Sao lưu ZIP'),
                onTap: () => _guard(context, () => backupZip(context, scope)),
              ),
              HandyTile(
                key: const Key('spend-restore'),
                icon: Icons.unarchive_outlined,
                title: tr(context, 'Restore a backup', 'Khôi phục bản sao lưu'),
                onTap: () =>
                    _guard(context, () => restoreBackup(context, scope)),
              ),
              HandyTile(
                key: const Key('spend-templates'),
                icon: Icons.view_column_outlined,
                title: tr(context, 'Statement templates', 'Mẫu nhập sao kê'),
                trailing: value('${s.profiles.length}'),
                navigates: true,
                onTap: () =>
                    Navigator.pushNamed(context, '/settings/templates'),
              ),
              HandyTile(
                key: const Key('spend-imports'),
                icon: Icons.history,
                title: tr(context, 'Statement imports', 'Các lần nhập sao kê'),
                trailing: value('${s.imports.length}'),
                navigates: true,
                onTap: () => Navigator.pushNamed(context, '/imports'),
              ),
              HandyTile(
                key: const Key('spend-undo'),
                icon: Icons.undo,
                title: tr(
                  context,
                  'Undo the last change',
                  'Hoàn tác thay đổi cuối',
                ),
                onTap: () => _guard(context, () async {
                  await scope.controller.undo();
                  return context.mounted
                      ? tr(context, 'Undone.', 'Đã hoàn tác.')
                      : null;
                }),
              ),
              HandyTile(
                key: const Key('spend-integrity'),
                icon: Icons.verified_outlined,
                title: tr(
                  context,
                  'Check stored data',
                  'Kiểm tra dữ liệu đã lưu',
                ),
                onTap: () => _guard(context, () async {
                  final result = await scope.controller.store!.integrity();
                  if (!context.mounted) return null;
                  return result == 'ok'
                      ? tr(
                          context,
                          'Stored data is intact.',
                          'Dữ liệu đã lưu còn nguyên vẹn.',
                        )
                      : tr(
                          context,
                          'The check failed. Export a backup and keep this data as it is.',
                          'Kiểm tra không đạt. Hãy xuất bản sao lưu và giữ nguyên dữ liệu này.',
                        );
                }),
              ),
            ],
          ),
        ],
      );
    },
  );
}
