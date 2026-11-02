import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../pauses/pauses.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/words.dart';
import 'data.dart';

/// Habit's settings: the shared page with the calendar, reminders and the
/// data added. Language and look live in the habit data, as before.
class HabitSettingsPage extends StatelessWidget {
  final HabitScope scope;
  const HabitSettingsPage({super.key, required this.scope});

  Future<void> _set(BuildContext context, Map<String, dynamic> changes) =>
      scope.write(
        context,
        (s) => s.copy({
          'settings': {...s.settings, ...changes},
        }),
        remember: false,
      );

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

  Future<void> _calendar(BuildContext context) {
    final s = scope.state;
    return showHabitForm(
      context,
      title: tr(context, 'Calendar', 'Lịch'),
      fields: [
        const HabitField(
          'zone',
          'Time zone',
          'Múi giờ',
          helpEn:
              'Decides which day a check-in belongs to, e.g. Asia/Ho_Chi_Minh. Past days stay as they are.',
          helpVi:
              'Quyết định lần ghi thuộc ngày nào, ví dụ Asia/Ho_Chi_Minh. Ngày đã qua giữ nguyên.',
        ),
        HabitField(
          'weekStart',
          'Weeks start on',
          'Tuần bắt đầu vào',
          kind: FieldKind.choice,
          options: {'1': weekdayLong(context, 1), '7': weekdayLong(context, 7)},
          helpEn: 'For new days-a-week schedules.',
          helpVi: 'Cho các lịch theo số ngày mỗi tuần tạo sau này.',
        ),
        const HabitField(
          'backfill',
          'Fill in days up to',
          'Cho ghi bù tối đa',
          kind: FieldKind.count,
          helpEn: 'Days back, 1 to 3660.',
          helpVi: 'Số ngày trước, từ 1 đến 3660.',
        ),
      ],
      initial: {
        'zone': s.zone,
        'weekStart': '${s.weekStart}',
        'backfill': '${s.backfill}',
      },
      save: (v) async {
        location(v['zone'] as String);
        final backfill = int.parse('${v['backfill']}');
        if (backfill < 1 || backfill > 3660)
          throw const FormatException('1 to 3660 / Từ 1 đến 3660');
        await scope.controller.change(
          (s) => s.copy({
            'settings': {
              ...s.settings,
              'zone': v['zone'],
              'weekStart': int.parse(v['weekStart'] as String),
              'backfill': backfill,
            },
          }),
          remember: false,
        );
      },
    );
  }

  Future<void> _quiet(BuildContext context) {
    final s = scope.state;
    return showHabitForm(
      context,
      title: tr(context, 'Quiet hours', 'Giờ yên lặng'),
      fields: const [
        HabitField('quietStart', 'From', 'Từ', kind: FieldKind.time),
        HabitField(
          'quietEnd',
          'Until',
          'Đến',
          kind: FieldKind.time,
          helpEn:
              'A reminder that falls inside moves to the end; a paused routine is not shown in notifications. The same time twice turns this off.',
          helpVi:
              'Nhắc rơi vào khoảng này dời tới lúc kết thúc; quy trình đang dở không hiện trong thông báo. Hai giờ giống nhau là tắt.',
        ),
      ],
      initial: {
        'quietStart': s.settings['quietStart'] ?? '22:00',
        'quietEnd': s.settings['quietEnd'] ?? '07:00',
      },
      save: (v) => scope.controller.change(
        (s) => s.copy({
          'settings': {
            ...s.settings,
            'quietStart': v['quietStart'],
            'quietEnd': v['quietEnd'],
          },
        }),
        remember: false,
      ),
    );
  }

  Future<void> _reminder(BuildContext context, [Reminder? old]) {
    final s = scope.state;
    final targets = {
      for (final h in s.habits.where((h) => !h.archived))
        'habit:${h.id}': h.title,
      for (final r in s.routines.where((r) => !r.archived))
        'routine:${r.id}': r.title,
    };
    return showHabitForm(
      context,
      title: tr(context, 'Reminder', 'Lịch nhắc'),
      fields: [
        HabitField(
          'target',
          'For',
          'Cho',
          kind: FieldKind.choice,
          options: targets,
        ),
        const HabitField('time', 'At', 'Lúc', kind: FieldKind.time),
        const HabitField('weekdays', 'On', 'Vào', kind: FieldKind.weekdays),
        const HabitField(
          'enabled',
          'On',
          'Bật',
          kind: FieldKind.toggle,
          helpEn: 'The notice says only that it is time; no names.',
          helpVi: 'Thông báo chỉ báo đến giờ, không ghi tên.',
        ),
      ],
      initial: {
        'target': old == null
            ? targets.keys.first
            : '${old.type}:${old.target}',
        'time': old?.time ?? '08:00',
        'weekdays': old?.weekdays ?? const [1, 2, 3, 4, 5, 6, 7],
        'enabled': old?.enabled ?? true,
      },
      save: (v) async {
        final target = v['target'] as String, colon = target.indexOf(':');
        final r = Reminder(
          id: old?.id ?? uid(),
          target: target.substring(colon + 1),
          type: target.substring(0, colon),
          time: v['time'] as String,
          weekdays: List<int>.from(v['weekdays'] as List),
          enabled: v['enabled'] == true,
        );
        await scope.controller.change(
          (s) => s.copy({
            'settings': {
              ...s.settings,
              'reminders': [
                for (final x in objects(s.settings['reminders'] ?? []))
                  if (x['id'] != r.id) x,
                r.toJson(),
              ],
            },
          }),
        );
      },
    );
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Delete all Habit data?',
        'Xóa toàn bộ dữ liệu Habit?',
      ),
      message: tr(
        context,
        'Habits, records, routines and runs on this device go. Export a backup first if you may need them.',
        'Thói quen, lần ghi, quy trình và phiên trên máy này sẽ mất. Hãy xuất bản sao lưu trước nếu còn cần.',
      ),
      confirmLabel: tr(context, 'Delete all', 'Xóa hết'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await scope.write(
      context,
      (s) => HabitState(
        settings: {
          'onboarded': true,
          'locale': s.settings['locale'] ?? 'system',
          'theme': s.settings['theme'] ?? 'system',
        },
      ),
      done: (c) => tr(c, 'Everything deleted.', 'Đã xóa hết.'),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.state;
      final c = HandyColors.of(context);
      Widget value(String text) => Text(text, style: TextStyle(color: c.muted));
      final rules = objects(
        s.settings['reminders'] ?? [],
      ).map(Reminder.fromJson).toList();
      String targetName(Reminder r) =>
          (r.type == 'habit'
              ? scope.habit(r.target)?.title
              : scope.routine(r.target)?.title) ??
          tr(context, 'deleted', 'đã xóa');
      final next = dueReminders(s, scope.clock()).take(3).toList();
      return HandySettingsPage(
        appName: 'Handy Habit',
        theme: s.settings['theme'] as String? ?? 'system',
        locale: s.settings['locale'] as String? ?? 'system',
        onTheme: (v) => scope.controller.change(
          (s) => s.copy({
            'settings': {...s.settings, 'theme': v},
          }),
          remember: false,
        ),
        onLocale: (v) => scope.controller.change(
          (s) => s.copy({
            'settings': {...s.settings, 'locale': v},
          }),
          remember: false,
        ),
        sections: [
          HandySettingsSection(
            title: tr(context, 'Calendar', 'Lịch'),
            children: [
              HandyTile(
                title: tr(context, 'Time zone', 'Múi giờ'),
                trailing: value(s.zone),
                onTap: () => _calendar(context),
              ),
              HandyTile(
                title: tr(context, 'Weeks start on', 'Tuần bắt đầu vào'),
                trailing: value(weekdayLong(context, s.weekStart)),
                onTap: () => _calendar(context),
              ),
              HandyTile(
                key: const Key('set-backfill'),
                title: tr(context, 'Fill in days up to', 'Cho ghi bù tối đa'),
                trailing: value(
                  tr(
                    context,
                    '${s.backfill} days back',
                    '${s.backfill} ngày trước',
                  ),
                ),
                onTap: () => _calendar(context),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Reminders', 'Nhắc'),
            description: scope.reminders.supported
                ? tr(
                    context,
                    'Permission is asked only when you turn this on. The earliest 50 within 400 days are set; opening the app refreshes them.',
                    'Chỉ hỏi quyền khi bạn bật. Đặt 50 lần nhắc sớm nhất trong 400 ngày; mở app sẽ làm mới.',
                  )
                : tr(
                    context,
                    'This platform cannot remind in the background. Today shows the next reminder instead.',
                    'Nền tảng này không nhắc nền được. Hôm nay sẽ hiện lần nhắc tiếp theo.',
                  ),
            children: [
              if (scope.reminders.supported)
                SwitchListTile.adaptive(
                  key: const Key('set-notifications'),
                  title: Text(tr(context, 'Send reminders', 'Gửi nhắc')),
                  value: s.settings['notifications'] == true,
                  onChanged: (on) async {
                    final allowed = on && await scope.reminders.request();
                    if (on && !allowed && context.mounted)
                      showHandyMessage(
                        context,
                        tr(
                          context,
                          'Notifications are off for Handy Habit in the system settings; tracking still works.',
                          'Thông báo của Handy Habit đang tắt trong cài đặt hệ thống; ghi nhận vẫn dùng bình thường.',
                        ),
                      );
                    if (context.mounted)
                      await _set(context, {'notifications': allowed});
                  },
                ),
              if (scope.reminders.supported)
                SwitchListTile.adaptive(
                  key: const Key('set-run-notice'),
                  title: Text(
                    tr(
                      context,
                      'Show a paused routine in notifications',
                      'Báo quy trình đang dở trong thông báo',
                    ),
                  ),
                  subtitle: Text(
                    tr(
                      context,
                      'When you leave a run, it pauses; the notice says where you stopped and opens it again.',
                      'Rời màn chạy thì phiên tạm dừng; thông báo nói bạn dừng ở đâu và mở lại phiên.',
                    ),
                  ),
                  value: runNoticeOn(s),
                  onChanged: (on) async {
                    final allowed = on && await scope.reminders.request();
                    if (on && !allowed && context.mounted)
                      showHandyMessage(
                        context,
                        tr(
                          context,
                          'Notifications are off for Handy Habit in the system settings; routines still run.',
                          'Thông báo của Handy Habit đang tắt trong cài đặt hệ thống; quy trình vẫn chạy bình thường.',
                        ),
                      );
                    if (context.mounted)
                      await _set(context, {'runNotice': allowed});
                  },
                ),
              HandyTile(
                key: const Key('set-quiet'),
                title: tr(context, 'Quiet hours', 'Giờ yên lặng'),
                trailing: value(
                  '${s.settings['quietStart'] ?? '22:00'} – ${s.settings['quietEnd'] ?? '07:00'}',
                ),
                onTap: () => _quiet(context),
              ),
              for (final r in rules)
                ListTile(
                  key: Key('reminder-${r.id}'),
                  title: Text('${r.time} · ${targetName(r)}'),
                  subtitle: Text(
                    '${weekdaysText(context, r.weekdays)}${r.enabled ? '' : ' · ${tr(context, 'off', 'tắt')}'}${r.snooze == null ? '' : ' · ${tr(context, 'snoozed', 'đã hoãn')}'}',
                  ),
                  onTap: () => _reminder(context, r),
                  trailing: HandyMenuButton(
                    items: [
                      HandyMenuItem(
                        Icons.snooze,
                        tr(
                          context,
                          'Again in 10 minutes',
                          'Nhắc lại sau 10 phút',
                        ),
                        () => _set(context, {
                          'reminders': [
                            for (final x in objects(
                              s.settings['reminders'] ?? [],
                            ))
                              if (x['id'] != r.id) x,
                            {
                              ...r.toJson(),
                              'snooze': scope
                                  .clock()
                                  .add(const Duration(minutes: 10))
                                  .toUtc()
                                  .toIso8601String(),
                            },
                          ],
                        }),
                      ),
                      HandyMenuItem(
                        Icons.delete_outline,
                        tr(context, 'Delete', 'Xóa'),
                        () => _set(context, {
                          'reminders': [
                            for (final x in objects(
                              s.settings['reminders'] ?? [],
                            ))
                              if (x['id'] != r.id) x,
                          ],
                        }),
                        destructive: true,
                      ),
                    ],
                  ),
                ),
              HandyTile(
                key: const Key('reminder-add'),
                icon: Icons.add,
                title: tr(context, 'Add a reminder', 'Thêm lịch nhắc'),
                onTap:
                    s.habits.any((h) => !h.archived) ||
                        s.routines.any((r) => !r.archived)
                    ? () => _reminder(context)
                    : null,
              ),
              if (next.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(HandySpace.l),
                  child: Text(
                    tr(context, 'Next: ', 'Sắp tới: ') +
                        next
                            .map(
                              (d) =>
                                  '${dayText(context, day(d.when), scope.today).toLowerCase()} ${d.when.hour.toString().padLeft(2, '0')}:${d.when.minute.toString().padLeft(2, '0')}',
                            )
                            .join(', '),
                    style: TextStyle(color: c.muted),
                  ),
                ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Pauses', 'Kỳ nghỉ'),
            description: tr(
              context,
              'Days off for every habit or a few. They are not missed, keep your runs and get no reminders.',
              'Những ngày nghỉ cho mọi thói quen hoặc vài thói quen. Không tính là lỡ, không đứt chuỗi, không nhắc.',
            ),
            children: [
              PauseList(scope: scope),
              HandyTile(
                key: const Key('pause-add'),
                icon: Icons.add,
                title: tr(context, 'Add a pause', 'Thêm kỳ nghỉ'),
                onTap: () => openPauseEditor(context, scope),
              ),
            ],
          ),
          if (scope.autoBackup != null)
            HandyAutoBackupSection(backup: scope.autoBackup!),
          HandySettingsSection(
            title: tr(context, 'Your data', 'Dữ liệu của bạn'),
            description: tr(
              context,
              'Everything stays on this device, unencrypted. No account, cloud or tracking; habit names never reach ads. Keep a backup elsewhere, above all on the web.',
              'Mọi thứ ở trên máy này, không mã hóa. Không tài khoản, cloud hay theo dõi; tên thói quen không bao giờ vào quảng cáo. Hãy giữ bản sao lưu ở nơi khác, nhất là trên web.',
            ),
            children: [
              HandyTile(
                key: const Key('habit-backup'),
                icon: Icons.archive_outlined,
                title: tr(context, 'Back up as ZIP', 'Sao lưu ZIP'),
                onTap: () =>
                    _guard(context, () => exportHabits(context, scope, 'zip')),
              ),
              HandyTile(
                key: const Key('habit-backup-json'),
                icon: Icons.data_object,
                title: tr(context, 'Back up as JSON', 'Sao lưu JSON'),
                onTap: () =>
                    _guard(context, () => exportHabits(context, scope, 'json')),
              ),
              HandyTile(
                key: const Key('habit-import'),
                icon: Icons.unarchive_outlined,
                title: tr(
                  context,
                  'Bring in a backup or CSV',
                  'Nhập bản sao lưu hoặc CSV',
                ),
                onTap: () =>
                    _guard(context, () => importHabits(context, scope)),
              ),
              HandyTile(
                key: const Key('habit-integrity'),
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
                          'Dữ liệu còn nguyên vẹn.',
                        )
                      : tr(
                          context,
                          'The check found a problem: $result. Export a backup.',
                          'Kiểm tra thấy lỗi: $result. Hãy xuất bản sao lưu.',
                        );
                }),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Start over', 'Làm lại từ đầu'),
            children: [
              HandyTile(
                key: const Key('habit-clear'),
                icon: Icons.delete_forever_outlined,
                title: tr(
                  context,
                  'Delete all Habit data',
                  'Xóa toàn bộ dữ liệu Habit',
                ),
                destructive: true,
                onTap: () => _clearAll(context),
              ),
            ],
          ),
        ],
      );
    },
  );
}
