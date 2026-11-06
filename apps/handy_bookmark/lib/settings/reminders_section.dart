import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../scope.dart';
import 'settings_parts.dart';

/// Items that still carry a reminder set on them, soonest first. Reminders
/// are no longer set item by item; these stay until they are cancelled.
List<Bookmark> itemsWithReminders(SaveLibrary l) =>
    [
      for (final b in l.bookmarks)
        if (b.reminderAt != null && DateTime.tryParse(b.reminderAt!) != null) b,
    ]..sort(
      (a, b) => DateTime.parse(
        a.reminderAt!,
      ).compareTo(DateTime.parse(b.reminderAt!)),
    );

/// Settings › Reminders › Existing reminders: shown only while an item
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
    final p = scope.c.preferences;
    final shown = all ? items : items.take(_shown).toList();
    return SettingsPanel(
      key: const Key('existing-reminders'),
      title: tr(context, 'Existing reminders', 'Hẹn nhắc đã đặt'),
      note: tr(
        context,
        'Set on items earlier. They still remind you until cancelled.',
        'Đặt trên từng mục trước đây. Vẫn nhắc cho đến khi bạn hủy.',
      ),
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
        if (scope.reminders.supported)
          SettingsSwitch(
            key: const Key('set-reminders'),
            icon: Icons.notifications_active_outlined,
            title: tr(context, 'Notify me when due', 'Báo khi đến hạn'),
            subtitle: tr(
              context,
              'Off: they show only on each item.',
              'Tắt: chỉ hiện trên từng mục.',
            ),
            value: p['notifications'] == true,
            onChanged: (v) => scope.run(context, () async {
              final allowed = !v || await scope.reminders.request();
              await scope.c.update(
                (l) => l,
                prefs: {...scope.c.preferences, 'notifications': v && allowed},
              );
            }),
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
