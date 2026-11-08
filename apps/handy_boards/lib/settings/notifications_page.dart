import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_menus.dart' show ProBadge;
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import 'settings_parts.dart';

/// Settings › Notifications: everything on this device, nothing sent
/// anywhere. Card reminders, today's work, due soon, left behind, quiet
/// hours, privacy and boards that stay silent are free; the Monday review
/// is Pro. Permission is asked only when something is turned on.
class NotificationsPage extends StatelessWidget {
  final BoardsScope scope;
  const NotificationsPage({super.key, required this.scope});

  Json _prefs() => notifyPrefs(scope.state);

  Future<void> _set(BuildContext context, Json changes, {bool? master}) =>
      scope.run(
        context,
        () => scope.controller.change(
          (s) => s.copy(
            preferences: {
              ...s.preferences,
              'notifications': ?master,
              'notify': {...notifyPrefs(s), ...changes}
                ..removeWhere((_, v) => v == null),
            },
          ),
          history: false,
        ),
      );

  /// Turning something on asks for the permission first, in context.
  Future<void> _turnOn(BuildContext context, Json changes) async {
    if (scope.reminders.supported && !await scope.reminders.request()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'Notifications are blocked for Handy Boards. Allow them in the '
                    'phone\'s Settings › Apps › Handy Boards › Notifications.',
                'Thông báo của Handy Boards đang bị chặn. Cho phép trong Cài '
                    'đặt của máy › Ứng dụng › Handy Boards › Thông báo.',
              ),
            ),
          ),
        );
      }
      return;
    }
    if (context.mounted) await _set(context, changes, master: true);
  }

  Future<String?> _time(BuildContext context, Object? current) async {
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch('${current ?? '09:00'}');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(m?[1] ?? '9'),
        minute: int.parse(m?[2] ?? '0'),
      ),
    );
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final p = BoardsPalette.of(context);
      final s = scope.state, n = _prefs();
      final on = s.preferences['notifications'] == true;
      final muted = {for (final b in (n['muted'] as List? ?? const [])) '$b'};
      final quiet = n['quietFrom'] != null;
      Future<void> toggle(String key, bool v) =>
          v ? _turnOn(context, {key: true}) : _set(context, {key: null});
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Notifications', 'Thông báo'))),
        body: ListView(
          key: const Key('notifications-page'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            if (!scope.reminders.supported)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  tr(
                    context,
                    'This device cannot get Handy Boards notifications while '
                        'the app is closed. Reminders show inside the app.',
                    'Thiết bị này không nhận thông báo của Handy Boards khi '
                        'app đóng. Lời nhắc hiện ngay trong app.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
              ),
            SettingsPanel(
              gap: false,
              rows: [
                SettingsSwitch(
                  key: const Key('notify-master'),
                  icon: Icons.notifications_none,
                  title: tr(context, 'Notifications', 'Thông báo'),
                  subtitle: tr(
                    context,
                    'Off: nothing rings, card reminders included.',
                    'Tắt: không gì kêu, kể cả lời nhắc trên thẻ.',
                  ),
                  value: on,
                  onChanged: (v) => v
                      ? _turnOn(context, const {})
                      : _set(context, const {}, master: false),
                ),
                SettingsRow(
                  key: const Key('notify-at'),
                  icon: Icons.schedule,
                  title: tr(context, 'Time for summaries', 'Giờ báo tóm tắt'),
                  subtitle: '${n['at'] ?? '09:00'}',
                  navigates: true,
                  onTap: () async {
                    final v = await _time(context, n['at']);
                    if (v != null && context.mounted) _set(context, {'at': v});
                  },
                ),
                SettingsSwitch(
                  key: const Key('notify-daily'),
                  icon: Icons.today_outlined,
                  title: tr(context, 'Today\'s work', 'Việc hôm nay'),
                  subtitle: tr(
                    context,
                    '"You have 3 tasks today", on days that have some.',
                    '"Hôm nay bạn có 3 việc", vào ngày có việc.',
                  ),
                  value: on && n['daily'] == true,
                  onChanged: (v) => toggle('daily', v),
                ),
                SettingsChoice<int>(
                  key: const Key('notify-due'),
                  controlKey: const Key('notify-due-choice'),
                  icon: Icons.event_outlined,
                  title: tr(context, 'Due soon', 'Sắp đến hạn'),
                  value: on && n['dueLead'] is int ? n['dueLead'] as int : -1,
                  options: [
                    (-1, tr(context, 'Off', 'Tắt')),
                    (0, tr(context, 'On the day', 'Đúng ngày')),
                    (1, tr(context, 'A day before', 'Trước 1 ngày')),
                    (3, tr(context, '3 days before', 'Trước 3 ngày')),
                  ],
                  onChanged: (v) => v < 0
                      ? _set(context, {'dueLead': null})
                      : _turnOn(context, {'dueLead': v}),
                ),
                SettingsSwitch(
                  key: const Key('notify-backlog'),
                  icon: Icons.history,
                  title: tr(context, 'Left behind', 'Việc còn tồn'),
                  subtitle: tr(
                    context,
                    'One morning nudge while work from earlier days is open.',
                    'Một lời nhắc buổi sáng khi còn việc từ hôm trước.',
                  ),
                  value: on && n['backlog'] == true,
                  onChanged: (v) => toggle('backlog', v),
                ),
                SettingsSwitch(
                  key: const Key('notify-weekly'),
                  icon: Icons.event_repeat_outlined,
                  title: tr(
                    context,
                    'Monday review · Pro',
                    'Xem lại đầu tuần · Pro',
                  ),
                  subtitle: tr(
                    context,
                    'Monday morning: what is left to look at again.',
                    'Sáng thứ Hai: những việc cần xem lại.',
                  ),
                  value: on && n['weekly'] == true,
                  onChanged: (v) async {
                    if (v && !await requirePro(context, ProFeature.carryOver)) {
                      return;
                    }
                    if (context.mounted) await toggle('weekly', v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsPanel(
              gap: false,
              rows: [
                SettingsSwitch(
                  key: const Key('notify-quiet'),
                  icon: Icons.bedtime_outlined,
                  title: tr(context, 'Quiet hours', 'Giờ yên lặng'),
                  subtitle: quiet
                      ? '${n['quietFrom']} – ${n['quietTo']}. ${tr(context, 'Summaries wait; reminders you set keep their time.', 'Tóm tắt chờ tới sau; lời nhắc bạn đặt giữ đúng giờ.')}'
                      : tr(context, 'Off', 'Tắt'),
                  value: quiet,
                  onChanged: (v) => _set(
                    context,
                    v
                        ? {'quietFrom': '22:00', 'quietTo': '07:00'}
                        : {'quietFrom': null, 'quietTo': null},
                  ),
                ),
                if (quiet)
                  SettingsRow(
                    key: const Key('notify-quiet-times'),
                    icon: Icons.tune,
                    title: tr(
                      context,
                      'Change the quiet hours',
                      'Đổi giờ yên lặng',
                    ),
                    navigates: true,
                    onTap: () async {
                      final from = await _time(context, n['quietFrom']);
                      if (from == null || !context.mounted) return;
                      final to = await _time(context, n['quietTo']);
                      if (to == null || !context.mounted) return;
                      await _set(context, {'quietFrom': from, 'quietTo': to});
                    },
                  ),
                SettingsSwitch(
                  key: const Key('notify-private'),
                  icon: Icons.visibility_off_outlined,
                  title: tr(context, 'Hide card names', 'Ẩn tên thẻ'),
                  subtitle: tr(
                    context,
                    'Notifications say "a card is due", not what it is.',
                    'Thông báo chỉ nói "một thẻ đến hạn", không nói tên.',
                  ),
                  value: n['private'] == true,
                  onChanged: (v) => _set(context, {'private': v ? true : null}),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tr(context, 'Boards that notify', 'Bảng được báo'),
              style: theme.textTheme.titleMedium,
            ),
            for (final b in homeBoards(s))
              CheckboxListTile(
                key: Key('notify-board-${b.id}'),
                contentPadding: EdgeInsets.zero,
                value: !muted.contains(b.id),
                title: Text(b.str('title')),
                onChanged: (v) => _set(context, {
                  'muted': v == true
                      ? [
                          for (final m in muted)
                            if (m != b.id) m,
                        ]
                      : [...muted, b.id],
                }),
              ),
            if (!hasPro(context)) ...[
              const SizedBox(height: 8),
              const Align(alignment: Alignment.centerLeft, child: ProBadge()),
            ],
          ],
        ),
      );
    },
  );
}
