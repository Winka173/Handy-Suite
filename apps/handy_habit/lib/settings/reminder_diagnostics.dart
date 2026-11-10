import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:handy_habit_engine/handy_habit_engine.dart';
import '../scope.dart';
import '../reminders.dart';
import '../insights/insight_dates.dart';
import 'system_settings.dart';

class HabitReminderDiagnosticsPage extends StatefulWidget {
  final HabitScope scope;
  const HabitReminderDiagnosticsPage({super.key, required this.scope});
  @override
  State<HabitReminderDiagnosticsPage> createState() =>
      _HabitReminderDiagnosticsPageState();
}

class _HabitReminderDiagnosticsPageState
    extends State<HabitReminderDiagnosticsPage>
    with WidgetsBindingObserver {
  late Future<ReminderDiagnostics?> reading;
  bool busy = false;
  String message = '';
  Future<ReminderDiagnostics?> read() async {
    try {
      return await widget.scope.reminders.diagnostics();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reading = read();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void refresh() => setState(() {
    reading = read();
  });
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> perform(Future<void> Function() task, String success) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await task();
      if (mounted) setState(() => message = success);
    } catch (_) {
      if (mounted)
        setState(
          () => message = tr(
            context,
            'Could not complete this. Retry or open system Settings.',
            'Chưa thực hiện được. Thử lại hoặc mở Cài đặt hệ thống.',
          ),
        );
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String vi) => tr(context, en, vi);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    Widget statusRow({
      Key? key,
      required String title,
      String? subtitle,
      VoidCallback? onTap,
    }) {
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      );
      return onTap == null
          ? Container(key: key, child: content)
          : InkWell(key: key, onTap: onTap, child: content);
    }

    String stamp(DateTime? instant) {
      if (instant == null) return t('Not scheduled yet', 'Chưa từng đặt lịch');
      final d = tz.TZDateTime.from(instant, location(widget.scope.state.zone));
      return '${insightDate(day(d), vi: Localizations.localeOf(context).languageCode == 'vi', year: true)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(title: Text(t('Diagnostics', 'Kiểm tra'))),
      body: ListView(
        key: const Key('diagnostics-scroll'),
        padding: const EdgeInsets.all(16),
        children: [
          HandyContent(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t(
                    'Why didn’t my reminder appear?',
                    'Vì sao không thấy thông báo?',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'Check these before changing your reminder.',
                    'Kiểm tra các mục này trước khi sửa lịch nhắc.',
                  ),
                ),
                FutureBuilder<ReminderDiagnostics?>(
                  future: reading,
                  builder: (c, snap) {
                    if (snap.connectionState != ConnectionState.done)
                      return Padding(
                        key: const Key('diagnostics-loading'),
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          t(
                            'Checking system status…',
                            'Đang kiểm tra hệ thống…',
                          ),
                        ),
                      );
                    if (snap.hasError || !snap.hasData)
                      return Text(
                        t(
                          'Could not read status. Tap Refresh to retry.',
                          'Chưa đọc được trạng thái. Chạm Làm mới để thử lại.',
                        ),
                        key: const Key('diagnostics-error'),
                      );
                    final d = snap.data!;
                    final status = switch (d.permission) {
                      HabitPermission.allowed => t('Allowed', 'Đã cho phép'),
                      HabitPermission.denied => t(
                        'Not allowed · enable in system Settings',
                        'Chưa cho phép · bật trong Cài đặt hệ thống',
                      ),
                      HabitPermission.unreadable => t(
                        'Windows manages toasts; permission cannot be read here',
                        'Windows quản lý thông báo; không đọc được quyền tại đây',
                      ),
                      HabitPermission.unsupported => t(
                        'Background notifications are not supported here',
                        'Nền tảng này không hỗ trợ thông báo nền',
                      ),
                      HabitPermission.error => t(
                        'Could not read permission · refresh to retry',
                        'Chưa đọc được quyền · làm mới để thử lại',
                      ),
                    };
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        statusRow(
                          key: const Key('diagnostics-permission'),
                          title: t(
                            'Notification permission',
                            'Quyền thông báo',
                          ),
                          subtitle: status,
                        ),
                        statusRow(
                          key: const Key('diagnostics-global'),
                          title: t('Send reminders', 'Gửi nhắc'),
                          subtitle:
                              widget.scope.state.settings['notifications'] ==
                                  true
                              ? t(
                                  'On · individual rules must also be enabled',
                                  'Bật · từng lịch nhắc cũng cần bật',
                                )
                              : t(
                                  'Off · turn on in Notifications',
                                  'Tắt · bật trong Thông báo',
                                ),
                        ),
                        if (android) ...[
                          statusRow(
                            key: const Key('diagnostics-exact'),
                            title: t('Exact alarms', 'Báo thức chính xác'),
                            subtitle:
                                '${d.exactAllowed == null
                                    ? t('Could not read status', 'Chưa đọc được trạng thái')
                                    : d.exactAllowed!
                                    ? t('Allowed', 'Đã cho phép')
                                    : t('Not allowed', 'Chưa cho phép')} · ${t('Not required: Habit uses flexible reminders, which Android may delay.', 'Không bắt buộc: Habit dùng lịch nhắc linh hoạt, Android có thể làm chậm.')}',
                          ),
                          statusRow(
                            key: const Key('diagnostics-battery'),
                            title: t('Battery optimisation', 'Tối ưu pin'),
                            subtitle: d.batteryExempt == null
                                ? t(
                                    'Status unavailable · check system Settings',
                                    'Chưa rõ trạng thái · xem Cài đặt hệ thống',
                                  )
                                : d.batteryExempt!
                                ? t(
                                    'Unrestricted · other system limits can still apply',
                                    'Không hạn chế · hệ thống vẫn có thể áp dụng giới hạn khác',
                                  )
                                : t(
                                    'Optimised · Android may delay delivery',
                                    'Đang tối ưu · Android có thể làm chậm',
                                  ),
                            onTap: busy
                                ? null
                                : () => perform(
                                    () =>
                                        openHabitSystemSettings(battery: true),
                                    '',
                                  ),
                          ),
                        ],
                        statusRow(
                          key: const Key('diagnostics-quiet'),
                          title: t('Quiet hours', 'Giờ yên lặng'),
                          subtitle:
                              '${widget.scope.state.settings['quietStart'] ?? '22:00'} – ${widget.scope.state.settings['quietEnd'] ?? '07:00'} · ${t('Reminders move to the end. Paused, archived or deleted targets do not remind.', 'Dời nhắc tới cuối khoảng. Mục đang nghỉ, lưu trữ hoặc đã xóa không nhắc.')}',
                        ),
                        statusRow(
                          key: const Key('diagnostics-last'),
                          title: t(
                            'Last scheduled successfully',
                            'Lần đặt lịch thành công gần nhất',
                          ),
                          subtitle: stamp(d.lastScheduled),
                        ),
                        statusRow(
                          key: const Key('diagnostics-next'),
                          title: t(
                            'Last prepared plan',
                            'Lịch đã chuẩn bị gần nhất',
                          ),
                          subtitle: t(
                            '${d.scheduled} reminders${d.nextScheduled == null ? '' : ' · next: ${stamp(d.nextScheduled)}'}. This is a schedule, not proof of delivery.',
                            '${d.scheduled} lần nhắc${d.nextScheduled == null ? '' : ' · tiếp theo: ${stamp(d.nextScheduled)}'}. Đây là lịch đã đặt, chưa xác nhận đã gửi.',
                          ),
                        ),
                        if (d.failed ||
                            widget.scope.reminderError.value != null)
                          Text(
                            t(
                              'The last refresh failed. Your rules are saved; retry scheduling.',
                              'Lần làm mới gần nhất lỗi. Lịch nhắc đã lưu; hãy thử đặt lại.',
                            ),
                            key: const Key('diagnostics-schedule-error'),
                          ),
                        if (widget.scope.reminders.supported) ...[
                          const SizedBox(height: 12),
                          FilledButton(
                            key: const Key('diagnostics-test'),
                            onPressed:
                                busy ||
                                    ![
                                      HabitPermission.allowed,
                                      HabitPermission.unreadable,
                                    ].contains(d.permission)
                                ? null
                                : () => perform(
                                    () => widget.scope.reminders.test(
                                      widget.scope.state,
                                    ),
                                    t(
                                      'Test sent. Check the notification tray and lock screen.',
                                      'Đã gửi thử. Kiểm tra khay thông báo và màn hình khóa.',
                                    ),
                                  ),
                            child: Text(
                              t('Test notification', 'Thử thông báo'),
                            ),
                          ),
                          TextButton(
                            key: const Key('diagnostics-system'),
                            onPressed: busy
                                ? null
                                : () => perform(openHabitSystemSettings, ''),
                            child: Text(
                              t(
                                'Open notification settings',
                                'Mở cài đặt thông báo',
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('diagnostics-retry'),
                            onPressed: busy
                                ? null
                                : () => perform(
                                    () async {
                                      await widget.scope.reminders.sync(
                                        widget.scope.state,
                                      );
                                      widget.scope.reminderError.value = null;
                                    },
                                    t(
                                      'Upcoming reminders refreshed.',
                                      'Đã làm mới lịch nhắc.',
                                    ),
                                  ),
                            child: Text(
                              t('Retry scheduling', 'Thử đặt lại lịch'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                if (message.isNotEmpty)
                  Semantics(
                    liveRegion: true,
                    child: Text(message, key: const Key('diagnostics-message')),
                  ),
                TextButton(
                  key: const Key('diagnostics-refresh'),
                  onPressed: busy ? null : refresh,
                  child: Text(t('Refresh status', 'Làm mới trạng thái')),
                ),
                TextButton(
                  key: const Key('diagnostics-help'),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/help/reminders'),
                  child: Text(t('How to use reminders', 'Cách dùng nhắc nhở')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
