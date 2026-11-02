import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../sharing/export_panel.dart';

Future<void> showTripSettings(
  BuildContext context,
  TripScope scope,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Settings and privacy', 'Cài đặt và riêng tư')),
      ),
      body: ListenableBuilder(
        listenable: scope.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(
                  context,
                  'Language, appearance, default timezone',
                  'Ngôn ngữ, giao diện, múi giờ mặc định',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => scope.run(context, () async {
                await tripForm(
                  context,
                  tr(context, 'Preferences', 'Tùy chọn'),
                  [
                    TripField(
                      'locale',
                      'Language',
                      'Ngôn ngữ',
                      kind: 'choice',
                      choices: {
                        'system': tr(context, 'System', 'Hệ thống'),
                        'en': 'English',
                        'vi': 'Tiếng Việt',
                      },
                    ),
                    TripField(
                      'theme',
                      'Appearance',
                      'Giao diện',
                      kind: 'choice',
                      choices: {
                        'system': tr(context, 'System', 'Hệ thống'),
                        'light': tr(context, 'Light', 'Sáng'),
                        'dark': tr(context, 'Dark', 'Tối'),
                      },
                    ),
                    const TripField(
                      'zone',
                      'Default IANA timezone for new trips',
                      'Múi giờ IANA mặc định cho chuyến mới',
                    ),
                  ],
                  {
                    'locale': scope.state.settings['locale'] ?? 'system',
                    'theme': scope.state.settings['theme'] ?? 'system',
                    'zone': scope.state.settings['zone'] ?? 'Asia/Ho_Chi_Minh',
                  },
                  (v) async {
                    location(v['zone']);
                    await scope.controller.change(
                      (s) => s.copy({
                        'settings': {...s.settings, ...v},
                      }),
                    );
                  },
                );
              }),
            ),
            HandyLabel(tr(context, 'Local reminders', 'Nhắc cục bộ')),
            Text(
              scope.reminders.supported
                  ? tr(
                      context,
                      'Optional permission, requested only here. At most 50 future reminders; OS timing is not guaranteed. No remote push.',
                      'Quyền tùy chọn, chỉ hỏi tại đây. Tối đa 50 nhắc tương lai; OS không bảo đảm giờ chính xác. Không push từ xa.',
                    )
                  : tr(
                      context,
                      'Durable background reminders are unavailable here. Upcoming reminders remain in the trip overview; use calendar ICS as another option.',
                      'Nền tảng này chưa có nhắc nền bền vững. Nhắc sắp tới vẫn ở tổng quan chuyến; có thể dùng lịch ICS.',
                    ),
            ),
            if (scope.reminders.supported)
              TextButton(
                onPressed: () => scope.run(context, () async {
                  final allowed = await scope.reminders.request();
                  await scope.controller.change(
                    (s) => s.copy({
                      'settings': {...s.settings, 'notifications': allowed},
                    }),
                  );
                  if (!allowed && context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(
                            context,
                            'Permission denied. Planning and manual check-in still work.',
                            'Quyền bị từ chối. Lên lịch và ghi nhận thủ công vẫn hoạt động.',
                          ),
                        ),
                      ),
                    );
                }),
                child: Text(
                  tr(
                    context,
                    'Enable / request notification permission',
                    'Bật / yêu cầu quyền thông báo',
                  ),
                ),
              ),
            TextButton(
              onPressed: () => scope.run(
                context,
                () => scope.controller.change(
                  (s) => s.copy({
                    'settings': {...s.settings, 'notifications': false},
                  }),
                ),
              ),
              child: Text(
                tr(
                  context,
                  'Disable notifications and cancel schedules',
                  'Tắt thông báo và hủy lịch nhắc',
                ),
              ),
            ),
            HandyLabel(tr(context, 'Your data', 'Dữ liệu của bạn')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(
                  context,
                  'Full backup, reports, import/restore',
                  'Backup đầy đủ, báo cáo, nhập/khôi phục',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  scope.run(context, () => showTripData(context, scope)),
            ),
            TextButton(
              onPressed: () => scope.run(context, () async {
                final result = await scope.controller.store!.integrity();
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result == 'ok'
                            ? tr(
                                context,
                                'Database integrity: OK',
                                'Toàn vẹn dữ liệu: OK',
                              )
                            : tr(
                                context,
                                'Integrity check reported an issue; preserve a backup.',
                                'Phát hiện vấn đề toàn vẹn; hãy giữ backup.',
                              ),
                      ),
                    ),
                  );
              }),
              child: Text(
                tr(
                  context,
                  'Check database integrity',
                  'Kiểm tra toàn vẹn dữ liệu',
                ),
              ),
            ),
            TextButton(
              onPressed: () => scope.run(context, () async {
                final unused =
                    scope.state.assets.length -
                    referencedAssets(scope.state).length;
                if (await tripConfirm(
                  context,
                  tr(
                    context,
                    'Remove $unused unreferenced managed copies? Device gallery originals are never touched.',
                    'Gỡ $unused bản sao không còn liên kết? Không đụng tới bản gốc trong thư viện thiết bị.',
                  ),
                ))
                  await scope.controller.change(pruneManagedCopies);
              }),
              child: Text(
                tr(
                  context,
                  'Clean unreferenced app copies',
                  'Dọn bản sao trong app không còn liên kết',
                ),
              ),
            ),
            HandyLabel(tr(context, 'Ads + Pro Lifetime', 'Ads + Pro trọn đời')),
            Text(
              tr(
                context,
                'Core planning, photos, manual/GPS check-in and full backup are free. Pro removes supported ads. Purchases belong to their store; no subscription or invented Web payment.',
                'Lên lịch, ảnh, ghi nhận thủ công/GPS và backup đầy đủ đều miễn phí. Pro bỏ quảng cáo được hỗ trợ. Quyền mua thuộc store; không thuê bao hay thanh toán Web giả.',
              ),
            ),
            const LifetimeSettings(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(context, 'Open-source licenses', 'Giấy phép mã nguồn mở'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Handy Trip',
                applicationVersion: '0.1.0',
              ),
            ),
            HandyLabel(tr(context, 'Local privacy', 'Riêng tư cục bộ')),
            Text(
              tr(
                context,
                'No backend, account, cloud sync, AI or background tracking. GPS only on explicit request, with preview and confirmation. Trip names, booking codes, photos and coordinates never enter ads. Local database/backups are not encrypted. Browser storage can be evicted; keep private backups. Public reports redact metadata, but visible image contents need your review.',
                'Không backend, tài khoản, cloud sync, AI hay theo dõi nền. Chỉ lấy GPS khi bạn yêu cầu, có xem trước và xác nhận. Tên chuyến, mã đặt chỗ, ảnh và tọa độ không được gửi vào ads. Dữ liệu/backup cục bộ không mã hóa. Trình duyệt có thể xóa bộ nhớ; hãy giữ backup. Bản công khai bỏ metadata nhưng nội dung trên ảnh cần bạn kiểm tra.',
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => scope.run(context, () async {
                if (await tripConfirm(
                  context,
                  tr(
                    context,
                    'Clear all Trip data on this device? Make a private backup first. Other Handy apps and gallery originals are not changed.',
                    'Xóa mọi dữ liệu Trip trên thiết bị? Hãy backup riêng trước. Không đổi app Handy khác hay ảnh gốc trong thư viện.',
                  ),
                ))
                  await scope.controller.change(
                    (s) => TripState(
                      settings: {...s.settings, 'notifications': false},
                    ),
                  );
              }),
              child: Text(
                tr(context, 'Clear this app data', 'Xóa dữ liệu app này'),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> editAlarm(
  BuildContext context,
  TripScope scope,
  String type,
  String target,
  String tripId,
) async {
  final trip = scope.state.trip(tripId);
  await tripForm(
    context,
    tr(context, 'Local travel reminder', 'Nhắc chuyến đi cục bộ'),
    [
      const TripField('day', 'Reminder date', 'Ngày nhắc', kind: 'date'),
      const TripField('time', 'Reminder time', 'Giờ nhắc', kind: 'time'),
      const TripField('zone', 'IANA timezone', 'Múi giờ IANA'),
      const TripField('enabled', 'Enabled', 'Đã bật', kind: 'toggle'),
    ],
    {
      'day': scope.selectedDay ?? trip.start,
      'time': '09:00',
      'zone': trip.zone,
      'enabled': true,
    },
    (v) async {
      final alarm = TripAlarm({
        'id': newId(),
        'trip': tripId,
        'target': target,
        'type': type,
        'at': localInstant(
          v['day'],
          v['time'],
          v['zone'],
          lateFold: false,
        ).toIso8601String(),
        'zone': v['zone'],
        'enabled': v['enabled'] == true,
      });
      await scope.controller.change((s) => s.put('alarms', alarm));
    },
  );
}
