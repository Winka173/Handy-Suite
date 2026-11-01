import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'native.dart' show supportsLocalReminders;

/// On-device reminders for return dates, warranty ends and services.
class RemindersSection extends StatelessWidget {
  final ReminderController reminders;

  /// Null asks the platform; tests pass a value.
  final bool? supported;

  /// The app's words for the section: Keep's due dates, Recall's reviews.
  final String Function(BuildContext)? title, description;
  const RemindersSection({
    super.key,
    required this.reminders,
    this.supported,
    this.title,
    this.description,
  });
  @override
  Widget build(BuildContext context) => HandySettingsSection(
    title: title?.call(context) ?? tr(context, 'Reminders', 'Nhắc việc'),
    description:
        description?.call(context) ??
        tr(
          context,
          'A notification on the day something is due. Nothing leaves this device.',
          'Báo vào ngày đến hạn. Không có gì rời khỏi máy.',
        ),
    children: [
      if (!(supported ?? supportsLocalReminders))
        Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Text(
            tr(
              context,
              'Notifications are not available here yet. The Dates list in Keep still shows everything due.',
              'Nền tảng này chưa có thông báo. Danh sách Đến hạn trong Keep vẫn hiện đủ các mốc.',
            ),
          ),
        )
      else
        ListenableBuilder(
          listenable: reminders,
          builder: (context, _) {
            final r = reminders;
            final time =
                '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
            final idle = !r.busy && r.enabled != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  key: const Key('reminders-switch'),
                  title: Text(tr(context, 'Remind me', 'Nhắc tôi')),
                  subtitle: r.enabled == true
                      ? Text(
                          tr(
                            context,
                            '${r.registered} upcoming',
                            '${r.registered} lần nhắc sắp tới',
                          ),
                        )
                      : null,
                  value: r.enabled ?? false,
                  onChanged: idle ? r.setEnabled : null,
                ),
                const Divider(indent: HandySpace.l),
                ListTile(
                  key: const Key('reminders-time'),
                  enabled: idle,
                  title: Text(tr(context, 'At', 'Lúc')),
                  trailing: Text(
                    time,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
                    );
                    if (t != null) await r.setTime(t.hour, t.minute);
                  },
                ),
                if (r.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(HandySpace.l),
                    child: HandyNotice(
                      errorText(context, r.message),
                      tone: HandyTone.error,
                    ),
                  ),
              ],
            );
          },
        ),
    ],
  );
}
