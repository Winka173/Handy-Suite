import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';
import '../reminders.dart';

class HabitNotificationStatus extends StatefulWidget {
  final HabitReminders reminders;
  final int revision;
  const HabitNotificationStatus({
    super.key,
    required this.reminders,
    required this.revision,
  });
  @override
  State<HabitNotificationStatus> createState() =>
      _HabitNotificationStatusState();
}

class _HabitNotificationStatusState extends State<HabitNotificationStatus>
    with WidgetsBindingObserver {
  Future<bool>? status;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void refresh() {
    status = widget.reminders.supported ? widget.reminders.permission() : null;
  }

  @override
  void didUpdateWidget(HabitNotificationStatus old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision) refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) setState(refresh);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: status,
    builder: (context, s) => HandyTile(
      key: const Key('notification-status'),
      title: tr(context, 'Permission status', 'Trạng thái quyền'),
      subtitle: !widget.reminders.supported
          ? tr(
              context,
              'Background notifications are not supported here',
              'Nền tảng này không hỗ trợ thông báo nền',
            )
          : !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? tr(
              context,
              'Windows manages toasts; permission cannot be read here',
              'Windows quản lý thông báo; không đọc được quyền tại đây',
            )
          : s.hasError
          ? tr(
              context,
              'Could not read · tap to retry',
              'Chưa đọc được · chạm để thử lại',
            )
          : s.hasData
          ? (s.data!
                ? tr(context, 'Allowed', 'Đã cho phép')
                : tr(
                    context,
                    'Not allowed · enable in system Settings',
                    'Chưa cho phép · bật trong Cài đặt hệ thống',
                  ))
          : tr(context, 'Checking…', 'Đang kiểm tra…'),
      onTap: widget.reminders.supported ? () => setState(refresh) : null,
    ),
  );
}
