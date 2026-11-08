import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../scope.dart';
import '../services/reminders.dart';
import 'settings_parts.dart';

/// Items that carry a read-later reminder, soonest first.
List<Bookmark> itemsWithReminders(SaveLibrary l) =>
    [
      for (final b in l.bookmarks)
        if (b.reminderAt != null && DateTime.tryParse(b.reminderAt!) != null) b,
    ]..sort(
      (a, b) => DateTime.parse(
        a.reminderAt!,
      ).compareTo(DateTime.parse(b.reminderAt!)),
    );

/// Settings › Notifications › Reminders set: shown only while an item
/// still has one. Each can be cancelled, or all at once. Cancelling
/// clears the item's reminder; the app then withdraws its scheduled
/// notification with the next sync, so nothing is left to fire.
class ExistingReminders extends StatefulWidget {
  final SaveScope scope;
  const ExistingReminders({super.key, required this.scope});
  @override
  State<ExistingReminders> createState() => _ExistingRemindersState();
}

class _ExistingRemindersState extends State<ExistingReminders> {
  bool all = false;
  SaveScope get scope => widget.scope;

  static const _shown = 5;

  String _when(BuildContext context, DateTime at) {
    final local = at.toLocal();
    final day = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = TimeOfDay.fromDateTime(local).format(context);
    return local.isBefore(DateTime.now())
        ? tr(context, 'Was due $day, $time', 'Đã đến hạn $day, $time')
        : tr(context, '$day, $time', '$day, $time');
  }

  Future<void> _cancel(Bookmark b) async {
    final ok = await scope.run(
      context,
      () => scope.put(b.copyWith(reminderAt: null)),
    );
    if (ok && mounted)
      scope.undoMessage(
        context,
        tr(context, 'Reminder cancelled.', 'Đã hủy hẹn nhắc.'),
      );
  }

  Future<void> _cancelAll(int count) async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        count == 1 ? 'Cancel 1 reminder?' : 'Cancel $count reminders?',
        'Hủy $count hẹn nhắc?',
      ),
      message: tr(
        context,
        'The items stay. Only their reminders go, with any notification still waiting.',
        'Các mục vẫn giữ nguyên. Chỉ bỏ hẹn nhắc, cùng thông báo còn chờ.',
      ),
      confirmLabel: tr(context, 'Cancel all', 'Hủy tất cả'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await scope.run(
      context,
      () => scope.view.change(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              b.reminderAt == null
                  ? b
                  : b.copyWith(reminderAt: null, updatedAt: saveTime()),
          ],
        ),
      ),
    );
    if (done && mounted)
      scope.undoMessage(
        context,
        tr(context, 'Reminders cancelled.', 'Đã hủy các hẹn nhắc.'),
      );
  }

  @override
  Widget build(BuildContext context) {
    final items = itemsWithReminders(scope.library);
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = all ? items : items.take(_shown).toList();
    return SettingsPanel(
      key: const Key('existing-reminders'),
      title: tr(context, 'Reminders set', 'Hẹn nhắc đã đặt'),
      rows: [
        for (final b in shown)
          SettingsRow(
            key: Key('reminder-${b.id}'),
            icon: Icons.notifications_outlined,
            title: b.title.isNotEmpty
                ? b.title
                : (b.hasUrl ? b.sourceDomain : tr(context, 'Picture', 'Ảnh')),
            subtitle: _when(context, DateTime.parse(b.reminderAt!)),
            subtitleLines: 2,
            onTap: () => Navigator.of(context).pushNamed('/bookmark/${b.id}'),
            trailing: TextButton(
              key: Key('reminder-cancel-${b.id}'),
              onPressed: () => _cancel(b),
              child: Text(tr(context, 'Cancel', 'Hủy')),
            ),
          ),
        if (items.length > _shown)
          SettingsRow(
            key: const Key('reminders-more'),
            icon: all ? Icons.expand_less : Icons.expand_more,
            title: all
                ? tr(context, 'Show fewer', 'Thu gọn')
                : tr(
                    context,
                    'Show all ${items.length}',
                    'Xem cả ${items.length}',
                  ),
            onTap: () => setState(() => all = !all),
          ),
        SettingsRow(
          key: const Key('reminders-cancel-all'),
          icon: Icons.notifications_off_outlined,
          destructive: true,
          title: tr(
            context,
            items.length == 1 ? 'Cancel it' : 'Cancel all ${items.length}',
            items.length == 1 ? 'Hủy hẹn này' : 'Hủy cả ${items.length}',
          ),
          onTap: () => _cancelAll(items.length),
        ),
      ],
    );
  }
}

/// Settings › Notifications: read-later reminders (off until the person
/// sets one), "needs attention" (on, but it never asks for the permission
/// by itself), ringing on time, and the reminders set.
class NotificationsSection extends StatelessWidget {
  final SaveScope scope;
  const NotificationsSection({super.key, required this.scope});

  static Future<(bool, bool)> _states(SaveReminders r) async =>
      (await r.allowedNow(), await r.exactAllowed());

  Future<void> _set(BuildContext context, String key, bool v) => scope.run(
    context,
    () => scope.c.update((l) => l, prefs: {...scope.c.preferences, key: v}),
  );

  @override
  Widget build(BuildContext context) {
    final p = scope.c.preferences;
    final r = scope.reminders;
    return FutureBuilder<(bool, bool)>(
      // Asked again on every rebuild, so coming back from the phone's
      // settings shows the new state.
      future: _states(r),
      builder: (context, snap) {
        final allowed = snap.data?.$1 ?? true;
        final exact = snap.data?.$2 ?? true;
        final remindersOn = p['notifications'] == true;
        final problemsOn = p['problemNotices'] != false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPanel(
              gap: false,
              rows: [
                SettingsSwitch(
                  key: const Key('set-reminders'),
                  icon: Icons.notifications_active_outlined,
                  title: tr(context, 'Read-later reminders', 'Nhắc đọc sau'),
                  subtitle: tr(
                    context,
                    'Rings at the time you pick in "Remind me" on an item. '
                        'Nothing else, and never on its own.',
                    'Kêu đúng giờ bạn chọn ở "Nhắc tôi" trên từng mục. '
                        'Không gì khác, không tự nhắc.',
                  ),
                  value: remindersOn,
                  onChanged: (v) => scope.run(context, () async {
                    final ok = !v || await r.request();
                    await scope.c.update(
                      (l) => l,
                      prefs: {...scope.c.preferences, 'notifications': v && ok},
                    );
                  }),
                ),
                SettingsSwitch(
                  key: const Key('set-problems'),
                  icon: Icons.report_gmailerrorred_outlined,
                  title: tr(context, 'Needs attention', 'Báo khi cần xử lý'),
                  subtitle: problemsOn && !allowed
                      ? tr(
                          context,
                          'Notifications are not allowed yet. Turn this off '
                              'and on to allow them.',
                          'Máy chưa cho phép thông báo. Tắt rồi bật lại để '
                              'cho phép.',
                        )
                      : tr(
                          context,
                          'Only when a backup, a sync or shared links fail '
                              'and need you, while the app is closed.',
                          'Chỉ khi sao lưu, đồng bộ hoặc link chia sẻ bị lỗi '
                              'cần bạn xử lý, lúc app đang đóng.',
                        ),
                  value: problemsOn,
                  onChanged: (v) async {
                    if (v && !allowed) await r.request();
                    if (context.mounted)
                      await _set(context, 'problemNotices', v);
                  },
                ),
                SettingsSwitch(
                  key: const Key('set-task-notices'),
                  icon: Icons.task_alt_outlined,
                  title: tr(
                    context,
                    'When a background job finishes',
                    'Báo khi việc chạy nền xong',
                  ),
                  subtitle: tr(
                    context,
                    'A link check or offline copies that end while the app '
                        'is closed. Off by default.',
                    'Kiểm tra link hoặc lưu bản đọc offline xong lúc app '
                        'đang đóng. Mặc định tắt.',
                  ),
                  value: p['taskNotices'] == true,
                  onChanged: (v) async {
                    if (v && !allowed) await r.request();
                    if (context.mounted) await _set(context, 'taskNotices', v);
                  },
                ),
                if (remindersOn && !exact)
                  SettingsRow(
                    key: const Key('set-exact'),
                    icon: Icons.alarm_outlined,
                    title: tr(
                      context,
                      'Reminders may come late',
                      'Lời nhắc có thể đến muộn',
                    ),
                    subtitle: tr(
                      context,
                      'This phone may delay them. To ring on time, allow '
                          '"Alarms & reminders" for Handy Bookmark.',
                      'Máy có thể dời lời nhắc. Để kêu đúng giờ, cho phép '
                          '"Báo thức và lời nhắc" cho Handy Bookmark.',
                    ),
                    navigates: true,
                    onTap: r.askExact,
                  ),
              ],
            ),
            ExistingReminders(scope: scope),
          ],
        );
      },
    );
  }
}
