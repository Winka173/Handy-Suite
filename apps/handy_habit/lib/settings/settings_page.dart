import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/words.dart';
import 'data.dart';
import '../sync/folder_sync.dart';
import 'settings_parts.dart';
import 'about.dart';
import 'data_rows.dart';
import 'notification_status.dart';
import 'preferences_page.dart';
import '../pro/entitlements.dart';

/// Habit's settings: the shared page with the calendar, reminders and the
/// data added. Language and look live in the habit data, as before.
class HabitSettingsPage extends StatelessWidget {
  final HabitScope scope;
  const HabitSettingsPage({super.key, required this.scope});

  Future<void> _set(BuildContext context, Map<String, dynamic> changes) =>
      habitSetPrefs(context, scope, changes);

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

  Future<bool> _allowNotifications(BuildContext context) =>
      habitAllowNotifications(context, scope);

  Future<void> _reset(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Reset preferences?', 'Đặt lại cài đặt?'),
      message: tr(
        context,
        'Appearance, calendar defaults and routine preferences return to defaults. Habits, history, routines, reminders, pauses and purchases are kept.',
        'Giao diện, lịch mặc định và tùy chọn quy trình về mặc định. Giữ thói quen, lịch sử, quy trình, lịch nhắc, kỳ nghỉ và quyền mua.',
      ),
      confirmLabel: tr(context, 'Reset preferences', 'Đặt lại cài đặt'),
    );
    if (!ok || !context.mounted) return;
    await scope.write(
      context,
      (s) => s.copy({
        'settings': {
          for (final e in s.settings.entries)
            if (!habitPreferenceKeys.contains(e.key)) e.key: e.value,
        },
      }),
      remember: false,
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
      for (final h in s.liveHabits.where((h) => !h.archived))
        'habit:${h.id}': h.title,
      for (final r in s.liveRoutines.where((r) => !r.archived))
        'routine:${r.id}': r.title,
    };
    return showHabitForm(
      context,
      title: tr(context, 'Reminder', 'Lịch nhắc'),
      helpTopic: 'reminders',
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
        final notify = r.enabled && s.settings['notifications'] != true
            ? await _allowNotifications(context)
            : s.settings['notifications'] == true;
        await scope.controller.change(
          (s) => s.copy({
            'settings': {
              ...s.settings,
              'notifications': notify,
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

  /// Notifications: whether Habit may remind, the reminders, quiet hours.
  List<Widget> notifications(BuildContext context) {
    final s = scope.state;
    final rules = objects(s.settings['reminders'] ?? [])
        .map(Reminder.fromJson)
        .where((r) => !s.isTrashed(r.type, r.target))
        .toList();
    String targetName(Reminder r) =>
        (r.type == 'habit'
            ? scope.habit(r.target)?.title
            : scope.routine(r.target)?.title) ??
        tr(context, 'deleted', 'đã xóa');
    final next = dueReminders(s, scope.clock()).take(3).toList();
    final supported = scope.reminders.supported;
    return [
      SettingsGroup(
        first: true,
        title: tr(context, 'Notifications', 'Thông báo'),
        note: supported
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
          if (scope.reminderError.value != null)
            Padding(
              padding: const EdgeInsets.only(bottom: HandySpace.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HandyNotice(
                    tr(
                      context,
                      'Could not update scheduled reminders. Your rules are saved. Try again or check notification settings.',
                      'Chưa cập nhật được lịch thông báo. Lịch nhắc đã lưu. Hãy thử lại hoặc kiểm tra cài đặt thông báo.',
                    ),
                    tone: HandyTone.error,
                  ),
                  TextButton(
                    key: const Key('reminder-retry'),
                    onPressed: () async {
                      try {
                        await scope.reminders.sync(scope.state);
                        scope.reminderError.value = null;
                      } catch (e) {
                        scope.reminderError.value = e;
                      }
                    },
                    child: Text(tr(context, 'Retry', 'Thử lại')),
                  ),
                ],
              ),
            ),
          SettingsPanel(
            gap: false,
            rows: [
              if (supported)
                SettingsSwitch(
                  key: const Key('set-notifications'),
                  icon: Icons.notifications_none,
                  title: tr(context, 'Send reminders', 'Gửi nhắc'),
                  subtitle: s.settings['notifications'] == true
                      ? tr(context, 'On', 'Bật')
                      : tr(context, 'Off', 'Tắt'),
                  value: s.settings['notifications'] == true,
                  onChanged: (on) async {
                    final allowed = on && await _allowNotifications(context);
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
                      await _set(context, {
                        'notifications': allowed,
                        if (!allowed) 'runNotice': false,
                      });
                  },
                ),
              HabitNotificationStatus(
                reminders: scope.reminders,
                revision: s.revision,
              ),
              SettingsRow(
                key: const Key('reminder-help'),
                icon: Icons.help_outline,
                title: tr(
                  context,
                  'Why didn’t my reminder appear?',
                  'Vì sao không thấy thông báo?',
                ),
                navigates: true,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/settings/notifications/diagnostics',
                ),
              ),
              if (supported)
                SettingsRow(
                  key: const Key('notification-test'),
                  icon: Icons.notification_add_outlined,
                  title: tr(context, 'Test notification', 'Thử thông báo'),
                  onTap: () => _guard(context, () async {
                    await scope.reminders.test(s);
                    return context.mounted
                        ? tr(
                            context,
                            'Test sent. If it is hidden, check system notification settings.',
                            'Đã gửi thử. Nếu chưa thấy, kiểm tra thông báo trong cài đặt hệ thống.',
                          )
                        : null;
                  }),
                ),
            ],
          ),
          SettingsPanel(
            title: tr(context, 'Reminders', 'Lịch nhắc'),
            rows: [
              for (final r in rules)
                SettingsRow(
                  key: Key('reminder-${r.id}'),
                  icon: Icons.alarm,
                  title: '${r.time} · ${targetName(r)}',
                  subtitle:
                      '${weekdaysText(context, r.weekdays)}${r.enabled ? '' : ' · ${tr(context, 'off', 'tắt')}'}${r.snooze == null ? '' : ' · ${tr(context, 'snoozed', 'đã hoãn')}'}',
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
                        () async {
                          if (!await confirmHandy(
                                context,
                                title: tr(
                                  context,
                                  'Delete this reminder?',
                                  'Xóa lịch nhắc này?',
                                ),
                                message: tr(
                                  context,
                                  'The habit and its history are kept.',
                                  'Giữ nguyên thói quen và lịch sử.',
                                ),
                                confirmLabel: tr(context, 'Delete', 'Xóa'),
                              ) ||
                              !context.mounted)
                            return;
                          await _set(context, {
                            'reminders': [
                              for (final x in objects(
                                s.settings['reminders'] ?? [],
                              ))
                                if (x['id'] != r.id) x,
                            ],
                          });
                        },
                        destructive: true,
                      ),
                    ],
                  ),
                ),
              SettingsRow(
                key: const Key('reminder-add'),
                icon: Icons.add,
                title: tr(context, 'Add a reminder', 'Thêm lịch nhắc'),
                subtitle: next.isEmpty
                    ? null
                    : tr(context, 'Next: ', 'Sắp tới: ') +
                          next
                              .map(
                                (d) =>
                                    '${dayText(context, day(d.when), scope.today).toLowerCase()} ${d.when.hour.toString().padLeft(2, '0')}:${d.when.minute.toString().padLeft(2, '0')}',
                              )
                              .join(', '),
                onTap:
                    s.liveHabits.any((h) => !h.archived) ||
                        s.liveRoutines.any((r) => !r.archived)
                    ? () => _reminder(context)
                    : null,
              ),
            ],
          ),
          SettingsPanel(
            title: tr(context, 'How they arrive', 'Cách nhắc hiện ra'),
            rows: [
              SettingsRow(
                key: const Key('set-quiet'),
                icon: Icons.bedtime_outlined,
                title: tr(context, 'Quiet hours', 'Giờ yên lặng'),
                subtitle:
                    '${s.settings['quietStart'] ?? '22:00'} – ${s.settings['quietEnd'] ?? '07:00'}',
                navigates: true,
                onTap: () => _quiet(context),
              ),
              if (supported)
                HabitSettingToggle(
                  id: 'settings-private-notifications',
                  icon: Icons.lock_outline,
                  title: tr(
                    context,
                    'Private lock-screen text',
                    'Ẩn tên trên màn hình khóa',
                  ),
                  subtitle: tr(
                    context,
                    'The notice says only that it is time.',
                    'Thông báo chỉ báo đến giờ, không ghi tên.',
                  ),
                  value: s.settings['privateNotifications'] != false,
                  onChanged: (v) => _set(context, {'privateNotifications': v}),
                ),
              if (supported)
                SettingsSwitch(
                  key: const Key('set-run-notice'),
                  icon: Icons.pause_circle_outline,
                  title: tr(
                    context,
                    'Show a paused routine in notifications',
                    'Báo quy trình đang dở trong thông báo',
                  ),
                  subtitle: tr(
                    context,
                    'When you leave a run, it pauses; the notice says where you stopped and opens it again.',
                    'Rời màn chạy thì phiên tạm dừng; thông báo nói bạn dừng ở đâu và mở lại phiên.',
                  ),
                  value: runNoticeOn(s),
                  onChanged: (on) async {
                    final allowed = on && await _allowNotifications(context);
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
                      await _set(context, {
                        'runNotice': allowed,
                        if (allowed) 'notifications': true,
                      });
                  },
                ),
            ],
          ),
        ],
      ),
    ];
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
    await scope.drive?.disable();
    if (!context.mounted) return;
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

  /// Settings › Data › Data tools: the rarely needed ones, out of the way.
  List<Widget> dataTools(BuildContext context) {
    return [
      SettingsGroup(
        first: true,
        title: tr(context, 'Data tools', 'Công cụ dữ liệu'),
        note: tr(
          context,
          'Rarely needed. Each one says what it changes before it does.',
          'Ít khi cần. Mỗi mục nói rõ sẽ đổi gì trước khi làm.',
        ),
        children: [
          SettingsPanel(
            gap: false,
            rows: [
              SettingsRow(
                key: const Key('habit-backup-json'),
                icon: Icons.data_object,
                title: tr(context, 'Back up as JSON', 'Sao lưu dạng JSON'),
                subtitle: tr(
                  context,
                  'One readable file. Restore also takes CSV.',
                  'Một tệp đọc được. Khôi phục nhận cả CSV.',
                ),
                onTap: () =>
                    _guard(context, () => exportHabits(context, scope, 'json')),
              ),
              if (scope.controller.hasRecovery)
                SettingsRow(
                  key: const Key('habit-recovery'),
                  icon: Icons.restore,
                  title: tr(
                    context,
                    'Recover before last replace',
                    'Khôi phục trước lần thay thế cuối',
                  ),
                  onTap: () => _guard(context, () async {
                    final ok = await confirmHandy(
                      context,
                      title: tr(
                        context,
                        'Recover before last replace?',
                        'Khôi phục trước lần thay thế cuối?',
                      ),
                      message: tr(
                        context,
                        'This replaces current data with the recovery copy kept on this device. Export current data first if needed.',
                        'Thay dữ liệu hiện tại bằng bản khôi phục trên máy này. Hãy xuất dữ liệu hiện tại trước nếu cần.',
                      ),
                      confirmLabel: tr(context, 'Recover', 'Khôi phục'),
                    );
                    if (!ok) return null;
                    await scope.controller.recoverBeforeReplace();
                    return context.mounted
                        ? tr(context, 'Recovery restored.', 'Đã khôi phục.')
                        : null;
                  }),
                ),
              SettingsRow(
                key: const Key('habit-integrity'),
                icon: Icons.verified_outlined,
                title: tr(context, 'Check stored data', 'Kiểm tra dữ liệu'),
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
              SettingsRow(
                key: const Key('settings-reset'),
                icon: Icons.settings_backup_restore,
                title: tr(context, 'Reset preferences', 'Đặt lại cài đặt'),
                subtitle: tr(
                  context,
                  'Keeps habits, history, routines, reminders and purchases',
                  'Giữ thói quen, lịch sử, quy trình, lịch nhắc và quyền mua',
                ),
                onTap: () => _reset(context),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([scope.controller, scope.reminderError]),
    builder: (context, _) {
      final s = scope.state;
      final pro = LifetimeScope.maybeOf(context)?.pro == true;
      final reminders = objects(s.settings['reminders'] ?? [])
          .map(Reminder.fromJson)
          .where((r) => r.enabled && !s.isTrashed(r.type, r.target))
          .length;
      final pauses = s.pauses.length;
      final system = tr(context, 'System', 'Hệ thống');
      final schedule = s.settings['defaultSchedule'] == 'weekdays'
          ? tr(context, 'Weekdays', 'Ngày thường')
          : tr(context, 'Every day', 'Mỗi ngày');
      return HandyPage(
        title: tr(context, 'Settings', 'Cài đặt'),
        children: [
          const SizedBox(height: HandySpace.s),
          const HabitProCard(),

          // General.
          SettingsGroup(
            title: tr(context, 'General', 'Chung'),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsChoice(
                    id: 'settings-locale',
                    icon: Icons.translate,
                    title: tr(context, 'Language', 'Ngôn ngữ'),
                    value: s.settings['locale'] as String? ?? 'system',
                    options: [
                      ('en', 'English'),
                      ('vi', 'Tiếng Việt'),
                      ('system', system),
                    ],
                    onChanged: (v) => _set(context, {'locale': v}),
                  ),
                  SettingsChoice(
                    id: 'settings-theme',
                    icon: Icons.contrast,
                    title: tr(context, 'Light or dark', 'Sáng hay tối'),
                    value: s.settings['theme'] as String? ?? 'system',
                    options: [
                      ('light', tr(context, 'Light', 'Sáng')),
                      ('dark', tr(context, 'Dark', 'Tối')),
                      ('system', system),
                    ],
                    onChanged: (v) => _set(context, {'theme': v}),
                  ),
                  SettingsRow(
                    key: const Key('settings-notifications'),
                    icon: Icons.notifications_none,
                    title: tr(context, 'Notifications', 'Thông báo'),
                    subtitle: s.settings['notifications'] != true
                        ? tr(
                            context,
                            'Off. Set a reminder on a habit or routine.',
                            'Đang tắt. Đặt nhắc trên từng thói quen hay quy trình.',
                          )
                        : tr(
                            context,
                            reminders == 1
                                ? '1 reminder on'
                                : '$reminders reminders on',
                            'Đang bật $reminders lịch nhắc',
                          ),
                    navigates: true,
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings/notifications'),
                  ),
                  SettingsRow(
                    key: const Key('settings-widgets'),
                    icon: Icons.widgets_outlined,
                    title: tr(
                      context,
                      'Home-screen widgets',
                      'Widget màn hình chính',
                    ),
                    subtitle: tr(
                      context,
                      'Check in from the home screen; Week and Year with Pro.',
                      'Ghi nhận ngay ngoài màn hình chính; Tuần và Năm với Pro.',
                    ),
                    navigates: true,
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings/widgets'),
                  ),
                ],
              ),
            ],
          ),

          // Habits.
          SettingsGroup(
            title: tr(context, 'Habits', 'Thói quen'),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsRow(
                    key: const Key('settings-preferences'),
                    icon: Icons.tune,
                    title: tr(
                      context,
                      'Defaults and calendar',
                      'Mặc định và lịch',
                    ),
                    subtitle:
                        '$schedule · ${tr(context, 'week starts', 'tuần bắt đầu')} ${weekdayLong(context, s.weekStart).toLowerCase()}',
                    navigates: true,
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings/preferences'),
                  ),
                  SettingsRow(
                    key: const Key('settings-pauses'),
                    icon: Icons.beach_access_outlined,
                    title: tr(context, 'Pauses', 'Kỳ nghỉ'),
                    subtitle: pauses == 0
                        ? tr(
                            context,
                            'Days off that are not missed',
                            'Ngày nghỉ không tính là lỡ',
                          )
                        : tr(
                            context,
                            pauses == 1 ? '1 pause' : '$pauses pauses',
                            '$pauses kỳ nghỉ',
                          ),
                    navigates: true,
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings/pauses'),
                  ),
                  HabitSettingToggle(
                    id: 'settings-show-mood',
                    icon: Icons.sentiment_satisfied_outlined,
                    title: tr(
                      context,
                      'Ask how the day felt',
                      'Hỏi hôm nay thấy thế nào',
                    ),
                    subtitle: tr(
                      context,
                      'A mood line on Today; skip it any day.',
                      'Một dòng tâm trạng ở Hôm nay; bỏ qua lúc nào cũng được.',
                    ),
                    value: s.settings['showMoodToday'] != false,
                    onChanged: (v) => _set(context, {'showMoodToday': v}),
                  ),
                ],
              ),
            ],
          ),

          // Pro tools.
          SettingsGroup(
            title: tr(context, 'Make it yours', 'Theo ý bạn'),
            badge: pro ? null : const HabitProPill(),
            note: tr(
              context,
              'Pro. Each one changes only what you choose; Undo always works.',
              'Pro. Mỗi mục chỉ đổi đúng thứ bạn chọn; luôn hoàn tác được.',
            ),
            children: [
              SettingsPanel(
                gap: false,
                rows: [
                  SettingsRow(
                    key: const Key('settings-studio'),
                    icon: Icons.palette_outlined,
                    title: tr(
                      context,
                      'Personalization studio',
                      'Xưởng giao diện',
                    ),
                    subtitle: tr(
                      context,
                      'Palettes, Today layouts, icons and runner looks',
                      'Bảng màu, bố cục Hôm nay, biểu tượng và màn chạy',
                    ),
                    navigates: true,
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings/studio'),
                  ),
                  SettingsRow(
                    key: const Key('settings-rules'),
                    icon: Icons.auto_mode,
                    title: tr(context, 'Local rules', 'Quy tắc tự động'),
                    subtitle: tr(
                      context,
                      'When one thing happens, do the next',
                      'Khi một việc xảy ra, tự làm việc kế',
                    ),
                    navigates: true,
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings/rules'),
                  ),
                  SettingsRow(
                    key: const Key('settings-batch'),
                    icon: Icons.checklist,
                    title: tr(context, 'Batch changes', 'Thay đổi hàng loạt'),
                    subtitle: tr(
                      context,
                      'Select, preview and apply once',
                      'Chọn, xem trước và áp dụng một lần',
                    ),
                    navigates: true,
                    onTap: () => Navigator.pushNamed(context, '/habits/batch'),
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
              'Kept on this device. It leaves only when you back it up, sync or export it.',
              'Lưu trên máy này. Chỉ rời máy khi bạn sao lưu, đồng bộ hay xuất.',
            ),
            children: [
              if (scope.drive != null || folderSyncOffered)
                SettingsPanel(
                  gap: false,
                  rows: [
                    if (scope.drive != null)
                      SettingsRow(
                        key: const Key('habit-sync'),
                        icon: Icons.sync,
                        title: tr(context, 'Sync', 'Đồng bộ'),
                        subtitle: 'Google Drive',
                        navigates: true,
                        onTap: () =>
                            Navigator.pushNamed(context, '/settings/sync'),
                      ),
                    if (folderSyncOffered)
                      SettingsRow(
                        icon: Icons.folder_shared_outlined,
                        title: tr(
                          context,
                          'Sync through a folder',
                          'Đồng bộ qua thư mục',
                        ),
                        subtitle: tr(
                          context,
                          'Free · separate from backups',
                          'Miễn phí · tách biệt với sao lưu',
                        ),
                        navigates: true,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/settings/folder-sync',
                        ),
                      ),
                  ],
                ),
              SettingsPanel(
                gap: scope.drive != null || folderSyncOffered,
                title: tr(context, 'Backup and restore', 'Sao lưu & khôi phục'),
                rows: [
                  Padding(
                    padding: const EdgeInsets.all(HandySpace.m),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('habit-backup'),
                            onPressed: () => _guard(
                              context,
                              () => exportHabits(context, scope, 'zip'),
                            ),
                            icon: const Icon(Icons.backup_outlined, size: 20),
                            label: Text(tr(context, 'Back up', 'Sao lưu')),
                          ),
                        ),
                        const SizedBox(width: HandySpace.m),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('habit-import'),
                            onPressed: () => _guard(
                              context,
                              () => importHabits(context, scope),
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
                    HabitAutoBackupRow(scope: scope),
                ],
              ),
              SettingsPanel(
                rows: [
                  SettingsRow(
                    key: const Key('habit-trash'),
                    icon: Icons.delete_outline,
                    title: tr(context, 'Trash', 'Thùng rác'),
                    subtitle: s.trash.isEmpty
                        ? tr(context, 'Empty', 'Trống')
                        : tr(
                            context,
                            s.trash.length == 1
                                ? '1 item, kept 30 days'
                                : '${s.trash.length} items, kept 30 days',
                            '${s.trash.length} mục, giữ 30 ngày',
                          ),
                    navigates: true,
                    onTap: () =>
                        Navigator.of(context).pushNamed('/settings/trash'),
                  ),
                  SettingsRow(
                    key: const Key('settings-data-tools'),
                    icon: Icons.build_outlined,
                    title: tr(context, 'Data tools', 'Công cụ dữ liệu'),
                    subtitle: tr(
                      context,
                      'JSON backup, check, reset preferences',
                      'Sao lưu JSON, kiểm tra, đặt lại cài đặt',
                    ),
                    navigates: true,
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings/data-tools'),
                  ),
                  SettingsRow(
                    key: const Key('habit-clear'),
                    icon: Icons.delete_forever_outlined,
                    destructive: true,
                    title: tr(
                      context,
                      'Delete all data',
                      'Xóa toàn bộ dữ liệu',
                    ),
                    subtitle: tr(
                      context,
                      'Everything this app keeps on this device. Cannot be undone.',
                      'Mọi thứ app này lưu trên máy. Không hoàn tác được.',
                    ),
                    onTap: () => _clearAll(context),
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
                    key: const Key('settings-help'),
                    icon: Icons.school_outlined,
                    title: tr(context, 'How to use', 'Cách dùng'),
                    subtitle: tr(
                      context,
                      'The welcome again, and each thing step by step',
                      'Xem lại phần giới thiệu, và từng việc một',
                    ),
                    navigates: true,
                    onTap: () => Navigator.pushNamed(context, '/help'),
                  ),
                ],
              ),
            ],
          ),

          // About.
          SettingsGroup(
            title: tr(context, 'About', 'Giới thiệu'),
            children: [
              SettingsPanel(gap: false, rows: habitAboutRows(context)),
            ],
          ),
          const SizedBox(height: HandySpace.xxl),
        ],
      );
    },
  );
}

/// Data tools, under Settings › Data.
class HabitDataToolsPage extends StatelessWidget {
  final HabitScope scope;
  const HabitDataToolsPage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => HabitSettingsView(
    title: tr(context, 'Data tools', 'Công cụ dữ liệu'),
    listenable: scope.controller,
    children: (context) => HabitSettingsPage(scope: scope).dataTools(context),
  );
}

/// Asks for notification permission after saying why; false when the
/// platform cannot remind or the person declines.
Future<bool> habitAllowNotifications(
  BuildContext context,
  HabitScope scope,
) async {
  if (!scope.reminders.supported) return false;
  final ok = await confirmHandy(
    context,
    title: tr(context, 'Allow reminders?', 'Cho phép nhắc?'),
    message: tr(
      context,
      'Habit uses notifications to remind you at the times you choose. Names are hidden by default. Tracking works without permission.',
      'Habit dùng thông báo để nhắc vào giờ bạn chọn. Mặc định ẩn tên. Không cấp quyền vẫn ghi nhận được.',
    ),
    confirmLabel: tr(context, 'Continue', 'Tiếp tục'),
  );
  if (!ok) return false;
  try {
    return await scope.reminders.request();
  } catch (_) {
    if (context.mounted)
      showHandyMessage(
        context,
        tr(
          context,
          'Could not check notification permission. Try again.',
          'Chưa kiểm tra được quyền thông báo. Hãy thử lại.',
        ),
      );
    return false;
  }
}

/// Notifications, under Settings.
class HabitNotificationSettingsPage extends StatelessWidget {
  final HabitScope scope;
  const HabitNotificationSettingsPage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => HabitSettingsView(
    key: const Key('notifications-scroll'),
    title: tr(context, 'Notifications', 'Thông báo'),
    listenable: Listenable.merge([scope.controller, scope.reminderError]),
    children: (context) =>
        HabitSettingsPage(scope: scope).notifications(context),
  );
}

/// The first thing in Settings: Pro on a soft card in the app's tint; a
/// thank-you once it is owned.
class HabitProCard extends StatelessWidget {
  const HabitProCard({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    final pro = LifetimeScope.maybeOf(context)?.pro == true;
    return Material(
      color: p.tint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('settings-pro'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => openHabitPro(context),
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_outlined, size: 32, color: p.anchor),
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
                        color: p.anchor,
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
                              'Advanced routines, smart insights, looks and rules. One payment; buy or restore inside.',
                              'Quy trình nâng cao, phân tích chuyên sâu, giao diện và quy tắc. Trả một lần; mua hoặc khôi phục ở trong.',
                            ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: p.ink),
                    ),
                  ],
                ),
              ),
              Icon(
                pro ? Icons.check_circle : Icons.chevron_right,
                color: p.anchor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
