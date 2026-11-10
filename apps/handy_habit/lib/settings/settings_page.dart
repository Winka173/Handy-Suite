import 'package:flutter/foundation.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../pauses/pauses.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/words.dart';
import 'data.dart';
import 'settings_parts.dart';
import 'about.dart';
import 'notification_status.dart';
import '../pro/entitlements.dart';
import '../pro/purchase.dart';

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

  Future<bool> _allowNotifications(BuildContext context) async {
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
          'dayBoundary',
          'Day starts at',
          'Ngày bắt đầu lúc',
          kind: FieldKind.time,
          helpEn:
              'Applies to future check-ins only. Saved history days never move.',
          helpVi: 'Chỉ áp dụng cho lần ghi mới. Ngày trong lịch sử không đổi.',
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
        'dayBoundary':
            '${(s.dayBoundaryMinutes ~/ 60).toString().padLeft(2, '0')}:${(s.dayBoundaryMinutes % 60).toString().padLeft(2, '0')}',
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
              'dayBoundaryMinutes': minuteOfDay(v['dayBoundary'] as String),
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([scope.controller, scope.reminderError]),
    builder: (context, _) {
      final s = scope.state;
      final c = HandyColors.of(context);
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
      return HandyPage(
        title: tr(context, 'Settings', 'Cài đặt'),
        children: [
          HandySettingsSection(
            title: tr(context, 'Appearance', 'Giao diện'),
            children: [
              HandyTile(
                key: const Key('settings-studio'),
                title: tr(context, 'Personalization studio', 'Xưởng giao diện'),
                trailing: scope.pro(context)
                    ? null
                    : const HabitProBadge(feature: HabitProFeature.studio),
                subtitle: tr(
                  context,
                  'Preview palettes, cards, icons and runner looks',
                  'Xem thử bảng màu, thẻ, biểu tượng và màn chạy',
                ),
                onTap: () => Navigator.pushNamed(context, '/settings/studio'),
              ),
              HabitSettingChoice(
                id: 'settings-theme',
                title: tr(context, 'Theme', 'Sáng hay tối'),
                value: s.settings['theme'] as String? ?? 'system',
                options: {
                  'system': tr(context, 'System', 'Hệ thống'),
                  'light': tr(context, 'Light', 'Sáng'),
                  'dark': tr(context, 'Dark', 'Tối'),
                },
                onChanged: (v) => _set(context, {'theme': v}),
              ),
              HabitSettingChoice(
                id: 'settings-locale',
                title: tr(context, 'Language', 'Ngôn ngữ'),
                value: s.settings['locale'] as String? ?? 'system',
                options: {
                  'system': tr(context, 'System', 'Hệ thống'),
                  'en': 'English',
                  'vi': 'Tiếng Việt',
                },
                onChanged: (v) => _set(context, {'locale': v}),
              ),
              HabitSettingChoice(
                id: 'settings-density',
                title: tr(context, 'Density', 'Độ gọn'),
                value: s.settings['density'] as String? ?? 'comfortable',
                options: {
                  'comfortable': tr(context, 'Comfortable', 'Thoải mái'),
                  'compact': tr(context, 'Compact', 'Gọn'),
                },
                onChanged: (v) => _set(context, {'density': v}),
              ),

              SwitchListTile.adaptive(
                key: const Key('set-reduced-motion'),
                title: Text(tr(context, 'Reduce motion', 'Giảm chuyển động')),
                subtitle: Text(
                  tr(
                    context,
                    'Keep changes immediate. The system preference is also respected.',
                    'Hiện thay đổi ngay. Luôn tôn trọng tùy chọn giảm chuyển động của máy.',
                  ),
                ),
                value: s.settings['reducedMotion'] == true,
                onChanged: (v) => _set(context, {'reducedMotion': v}),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Habit preferences', 'Tùy chọn thói quen'),
            children: [
              HabitSettingChoice(
                id: 'settings-default-schedule',
                title: tr(context, 'Default schedule', 'Lịch mặc định'),
                value: s.settings['defaultSchedule'] as String? ?? 'daily',
                options: {
                  'daily': tr(context, 'Every day', 'Mỗi ngày'),
                  'weekdays': tr(context, 'Weekdays', 'Ngày thường'),
                },
                onChanged: (v) => _set(context, {'defaultSchedule': v}),
              ),
              HabitSettingChoice(
                id: 'settings-default-goal',
                title: tr(
                  context,
                  'Default goal for counts and amounts',
                  'Mục tiêu mặc định cho số lần và lượng',
                ),
                value: '${s.settings['defaultGoal'] ?? 1000}',
                options: {'1000': '1', '3000': '3', '8000': '8', '10000': '10'},
                onChanged: (v) => _set(context, {'defaultGoal': int.parse(v)}),
              ),
              HandyTile(
                title: tr(context, 'Time zone', 'Múi giờ'),
                subtitle: habitZoneLabel(context, s.zone, scope.clock()),
                onTap: () => _calendar(context),
              ),
              HandyTile(
                title: tr(context, 'Weeks start on', 'Tuần bắt đầu vào'),
                subtitle: weekdayLong(context, s.weekStart),
                onTap: () => _calendar(context),
              ),
              HandyTile(
                key: const Key('set-day-boundary'),
                title: tr(context, 'Day starts at', 'Ngày bắt đầu lúc'),
                subtitle:
                    '${(s.dayBoundaryMinutes ~/ 60).toString().padLeft(2, '0')}:${(s.dayBoundaryMinutes % 60).toString().padLeft(2, '0')}',
                onTap: () => _calendar(context),
              ),
              HandyTile(
                key: const Key('set-backfill'),
                title: tr(context, 'Fill in days up to', 'Cho ghi bù tối đa'),
                subtitle: tr(
                  context,
                  '${s.backfill} ${s.backfill == 1 ? 'day' : 'days'} back',
                  '${s.backfill} ngày trước',
                ),
                onTap: () => _calendar(context),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Routines', 'Quy trình'),
            children: [
              HabitSettingToggle(
                id: 'settings-routine-timer',
                title: tr(
                  context,
                  'Start timers automatically',
                  'Tự bắt đầu bộ đếm giờ',
                ),
                value: s.settings['routineAutoTimer'] != false,
                onChanged: (v) => _set(context, {'routineAutoTimer': v}),
              ),
              if (!kIsWeb &&
                  [
                    TargetPlatform.android,
                    TargetPlatform.iOS,
                  ].contains(defaultTargetPlatform))
                HabitSettingToggle(
                  id: 'settings-routine-haptics',
                  title: tr(
                    context,
                    'Haptic feedback on completed steps',
                    'Rung khi xong bước',
                  ),
                  value: s.settings['routineHaptics'] == true,
                  onChanged: (v) => _set(context, {'routineHaptics': v}),
                ),
              if (kIsWeb ||
                  ![
                    TargetPlatform.android,
                    TargetPlatform.iOS,
                  ].contains(defaultTargetPlatform))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr(
                      context,
                      'Haptic feedback is available on supported Android and iOS phones.',
                      'Rung phản hồi có trên điện thoại Android và iOS hỗ trợ.',
                    ),
                  ),
                ),
              HabitSettingToggle(
                id: 'settings-routine-confirm',
                title: tr(
                  context,
                  'Confirm before leaving a run',
                  'Xác nhận trước khi rời phiên',
                ),
                value: s.settings['confirmRoutineExit'] != false,
                onChanged: (v) => _set(context, {'confirmRoutineExit': v}),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Mood', 'Tâm trạng'),
            description: tr(
              context,
              'Optional reflections. Notes stay local and in backups you export.',
              'Cảm nhận tùy chọn. Ghi chú ở cục bộ và bản sao lưu bạn xuất.',
            ),
            children: [
              HabitSettingToggle(
                id: 'settings-show-mood',
                title: tr(
                  context,
                  'Show mood on Today',
                  'Hiện tâm trạng ở Hôm nay',
                ),
                value: s.settings['showMoodToday'] != false,
                onChanged: (v) => _set(context, {'showMoodToday': v}),
              ),
              HandyTile(
                title: tr(context, 'How to use mood', 'Cách ghi tâm trạng'),
                onTap: () => Navigator.pushNamed(context, '/help/mood'),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Notifications', 'Thông báo'),
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
              if (scope.reminderError.value != null)
                Padding(
                  padding: const EdgeInsets.all(16),
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
              HabitNotificationStatus(
                reminders: scope.reminders,
                revision: s.revision,
              ),
              HandyTile(
                key: const Key('reminder-help'),
                title: tr(
                  context,
                  'Why didn’t my reminder appear?',
                  'Vì sao không thấy thông báo?',
                ),
                onTap: () => Navigator.pushNamed(context, '/help/reminders'),
              ),
              if (scope.reminders.supported)
                HabitSettingToggle(
                  id: 'settings-private-notifications',
                  title: tr(
                    context,
                    'Private lock-screen text',
                    'Ẩn tên trên màn hình khóa',
                  ),
                  value: s.settings['privateNotifications'] != false,
                  onChanged: (v) => _set(context, {'privateNotifications': v}),
                ),
              if (scope.reminders.supported)
                HandyTile(
                  key: const Key('notification-test'),
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
              if (scope.reminders.supported)
                SwitchListTile.adaptive(
                  key: const Key('set-notifications'),
                  title: Text(tr(context, 'Send reminders', 'Gửi nhắc')),
                  subtitle: Text(
                    s.settings['notifications'] == true
                        ? tr(context, 'On', 'Bật')
                        : tr(context, 'Off', 'Tắt'),
                  ),
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
              HandyTile(
                key: const Key('set-quiet'),
                title: tr(context, 'Quiet hours', 'Giờ yên lặng'),
                subtitle:
                    '${s.settings['quietStart'] ?? '22:00'} – ${s.settings['quietEnd'] ?? '07:00'}',
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
              HandyTile(
                key: const Key('reminder-add'),
                icon: Icons.add,
                title: tr(context, 'Add a reminder', 'Thêm lịch nhắc'),
                onTap:
                    s.liveHabits.any((h) => !h.archived) ||
                        s.liveRoutines.any((r) => !r.archived)
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
              HandyTile(
                key: const Key('pause-help'),
                title: tr(
                  context,
                  'What happens when I pause?',
                  'Kỳ nghỉ ảnh hưởng thế nào?',
                ),
                onTap: () => Navigator.pushNamed(context, '/help/pause'),
              ),
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
            title: tr(context, 'Data', 'Dữ liệu'),
            description: tr(
              context,
              'Your data is saved on this device, unencrypted. Habit names never reach ads. Keep a separate backup. Use backup to move data between platforms.',
              'Dữ liệu được lưu trên máy này, không mã hóa. Tên thói quen không vào quảng cáo. Hãy giữ bản sao lưu riêng. Dùng sao lưu để chuyển dữ liệu giữa các nền tảng.',
            ),
            children: [
              if (scope.drive != null)
                HandyTile(
                  key: const Key('habit-sync'),
                  icon: Icons.sync,
                  title: tr(context, 'Sync', 'Đồng bộ'),
                  subtitle: 'Google Drive · Android',
                  onTap: () => Navigator.pushNamed(context, '/settings/sync'),
                ),
              HandyTile(
                key: const Key('backup-help'),
                title: tr(
                  context,
                  'Backup and device migration help',
                  'Cách sao lưu và chuyển máy',
                ),
                onTap: () => Navigator.pushNamed(context, '/help/backup'),
              ),
              HandyTile(
                key: const Key('habit-trash'),
                icon: Icons.delete_outline,
                title: tr(context, 'Trash', 'Thùng rác'),
                subtitle: tr(
                  context,
                  s.trash.length == 1 ? '1 item' : '${s.trash.length} items',
                  '${s.trash.length} mục',
                ),
                onTap: () => Navigator.of(context).pushNamed('/settings/trash'),
              ),
              if (scope.controller.hasRecovery)
                HandyTile(
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
            title: tr(context, 'Reset', 'Đặt lại'),
            children: [
              HandyTile(
                key: const Key('settings-reset'),
                title: tr(context, 'Reset preferences', 'Đặt lại cài đặt'),
                subtitle: tr(
                  context,
                  'Keeps habits, history, routines, reminders and purchases',
                  'Giữ thói quen, lịch sử, quy trình, lịch nhắc và quyền mua',
                ),
                onTap: () => _reset(context),
              ),
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
          HandySettingsSection(
            title: 'Pro',
            children: [
              HandyTile(
                key: const Key('settings-pro'),
                title: 'Pro Lifetime',
                subtitle: tr(
                  context,
                  'Advanced routines · pay once',
                  'Quy trình, phân tích và giao diện riêng · trả một lần',
                ),
                onTap: () => openHabitPro(context),
              ),
              const HabitProPurchase(),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Help & Learning', 'Trợ giúp & Hướng dẫn'),
            children: [
              HandyTile(
                key: const Key('settings-help'),
                title: tr(context, 'How to use', 'Cách dùng'),
                onTap: () => Navigator.pushNamed(context, '/help'),
              ),
              HandyTile(
                key: const Key('settings-replay'),
                title: tr(context, 'Replay guide', 'Xem lại hướng dẫn'),
                onTap: () => Navigator.pushNamed(context, '/welcome'),
              ),
              HandyTile(
                key: const Key('settings-whats-new'),
                title: tr(context, 'What’s New', 'Có gì mới'),
                subtitle: tr(
                  context,
                  'Guided practice, searchable help and personal preferences',
                  'Bản tập, tìm cách dùng và tùy chọn cá nhân',
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  animationStyle: AnimationStyle(
                    duration: HandyMotion.of(context),
                    reverseDuration: HandyMotion.of(context),
                  ),
                  builder: (context) => AlertDialog(
                    title: Text(tr(context, 'What’s New', 'Có gì mới')),
                    content: Text(
                      tr(
                        context,
                        'Try the three-stage guide without changing your library. Search help with or without accents. Customize your daily defaults in Settings.',
                        'Thử hướng dẫn ba giai đoạn, không đổi thư viện. Tìm cách dùng có dấu hoặc không dấu. Đổi mặc định hằng ngày trong Cài đặt.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(tr(context, 'Done', 'Xong')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          HandySettingsSection(
            title: tr(context, 'Privacy & About', 'Riêng tư & Giới thiệu'),
            description: tr(
              context,
              'Saved on this device. No account needed. Exported backups contain your personal data.',
              'Dữ liệu trên máy, không cần tài khoản. File sao lưu chứa dữ liệu cá nhân.',
            ),
            children: const [HabitAboutRows()],
          ),
          const HandyMoreApps(app: 'habit'),
        ],
      );
    },
  );
}
