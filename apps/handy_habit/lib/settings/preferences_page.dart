import 'package:flutter/foundation.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../pauses/pauses.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/words.dart';
import 'settings_parts.dart';

/// Saves preference [changes]; they are not an undo step.
Future<void> habitSetPrefs(
  BuildContext context,
  HabitScope scope,
  Map<String, dynamic> changes,
) => scope.write(
  context,
  (s) => s.copy({
    'settings': {...s.settings, ...changes},
  }),
  remember: false,
);

bool get _haptics =>
    !kIsWeb &&
    [
      TargetPlatform.android,
      TargetPlatform.iOS,
    ].contains(defaultTargetPlatform);

/// Settings › Defaults and calendar: what a new habit starts with, which
/// day a check-in belongs to, and how routines run.
class HabitPreferencesPage extends StatelessWidget {
  final HabitScope scope;
  const HabitPreferencesPage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => HabitSettingsView(
    title: tr(context, 'Defaults and calendar', 'Mặc định và lịch'),
    listenable: scope.controller,
    children: (context) {
      final s = scope.state;
      Future<void> set(Map<String, dynamic> c) =>
          habitSetPrefs(context, scope, c);
      final hh = (s.dayBoundaryMinutes ~/ 60).toString().padLeft(2, '0');
      final mm = (s.dayBoundaryMinutes % 60).toString().padLeft(2, '0');
      return [
        SettingsGroup(
          first: true,
          title: tr(context, 'New habits', 'Thói quen mới'),
          children: [
            SettingsPanel(
              gap: false,
              rows: [
                HabitSettingChoice(
                  id: 'settings-default-schedule',
                  icon: Icons.event_repeat_outlined,
                  title: tr(context, 'Default schedule', 'Lịch mặc định'),
                  value: s.settings['defaultSchedule'] as String? ?? 'daily',
                  options: {
                    'daily': tr(context, 'Every day', 'Mỗi ngày'),
                    'weekdays': tr(context, 'Weekdays', 'Ngày thường'),
                  },
                  onChanged: (v) => set({'defaultSchedule': v}),
                ),
                HabitSettingChoice(
                  id: 'settings-default-goal',
                  icon: Icons.flag_outlined,
                  title: tr(
                    context,
                    'Default goal for counts and amounts',
                    'Mục tiêu mặc định cho số lần và lượng',
                  ),
                  value: '${s.settings['defaultGoal'] ?? 1000}',
                  options: {
                    '1000': '1',
                    '3000': '3',
                    '8000': '8',
                    '10000': '10',
                  },
                  onChanged: (v) => set({'defaultGoal': int.parse(v)}),
                ),
              ],
            ),
          ],
        ),
        SettingsGroup(
          title: tr(context, 'Calendar', 'Lịch'),
          note: tr(
            context,
            'Decides which day a check-in belongs to. Saved days never move.',
            'Quyết định lần ghi thuộc ngày nào. Ngày đã lưu không bao giờ đổi.',
          ),
          children: [
            SettingsPanel(
              gap: false,
              rows: [
                SettingsRow(
                  icon: Icons.public,
                  title: tr(context, 'Time zone', 'Múi giờ'),
                  subtitle: habitZoneLabel(context, s.zone, scope.clock()),
                  navigates: true,
                  onTap: () => habitCalendarForm(context, scope),
                ),
                SettingsRow(
                  icon: Icons.view_week_outlined,
                  title: tr(context, 'Weeks start on', 'Tuần bắt đầu vào'),
                  subtitle: weekdayLong(context, s.weekStart),
                  navigates: true,
                  onTap: () => habitCalendarForm(context, scope),
                ),
                SettingsRow(
                  key: const Key('set-day-boundary'),
                  icon: Icons.nightlight_outlined,
                  title: tr(context, 'Day starts at', 'Ngày bắt đầu lúc'),
                  subtitle: '$hh:$mm',
                  navigates: true,
                  onTap: () => habitCalendarForm(context, scope),
                ),
                SettingsRow(
                  key: const Key('set-backfill'),
                  icon: Icons.history,
                  title: tr(context, 'Fill in days up to', 'Cho ghi bù tối đa'),
                  subtitle: tr(
                    context,
                    '${s.backfill} ${s.backfill == 1 ? 'day' : 'days'} back',
                    '${s.backfill} ngày trước',
                  ),
                  navigates: true,
                  onTap: () => habitCalendarForm(context, scope),
                ),
              ],
            ),
          ],
        ),
        SettingsGroup(
          title: tr(context, 'Routines', 'Quy trình'),
          children: [
            SettingsPanel(
              gap: false,
              rows: [
                HabitSettingToggle(
                  id: 'settings-routine-timer',
                  icon: Icons.timer_outlined,
                  title: tr(
                    context,
                    'Start timers automatically',
                    'Tự bắt đầu bộ đếm giờ',
                  ),
                  value: s.settings['routineAutoTimer'] != false,
                  onChanged: (v) => set({'routineAutoTimer': v}),
                ),
                if (_haptics)
                  HabitSettingToggle(
                    id: 'settings-routine-haptics',
                    icon: Icons.vibration,
                    title: tr(
                      context,
                      'Vibrate when a step is done',
                      'Rung khi xong bước',
                    ),
                    value: s.settings['routineHaptics'] == true,
                    onChanged: (v) => set({'routineHaptics': v}),
                  ),
                HabitSettingToggle(
                  id: 'settings-routine-confirm',
                  icon: Icons.exit_to_app,
                  title: tr(
                    context,
                    'Confirm before leaving a run',
                    'Xác nhận trước khi rời phiên',
                  ),
                  value: s.settings['confirmRoutineExit'] != false,
                  onChanged: (v) => set({'confirmRoutineExit': v}),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: HandySpace.xxl),
      ];
    },
  );
}

/// Settings › Pauses: days off that are not missed.
class HabitPausesPage extends StatelessWidget {
  final HabitScope scope;
  const HabitPausesPage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => HabitSettingsView(
    title: tr(context, 'Pauses', 'Kỳ nghỉ'),
    listenable: scope.controller,
    children: (context) => [
      SettingsGroup(
        first: true,
        title: tr(context, 'Days off', 'Ngày nghỉ'),
        note: tr(
          context,
          'For every habit or a few. They are not missed, keep your runs and get no reminders.',
          'Cho mọi thói quen hoặc vài thói quen. Không tính là lỡ, không đứt chuỗi, không nhắc.',
        ),
        children: [
          SettingsPanel(
            gap: false,
            rows: [
              PauseList(scope: scope),
              SettingsRow(
                key: const Key('pause-add'),
                icon: Icons.add,
                title: tr(context, 'Add a pause', 'Thêm kỳ nghỉ'),
                onTap: () => openPauseEditor(context, scope),
              ),
              SettingsRow(
                key: const Key('pause-help'),
                icon: Icons.help_outline,
                title: tr(
                  context,
                  'What happens when I pause?',
                  'Kỳ nghỉ ảnh hưởng thế nào?',
                ),
                navigates: true,
                onTap: () => Navigator.pushNamed(context, '/help/pause'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> habitCalendarForm(BuildContext context, HabitScope scope) {
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
