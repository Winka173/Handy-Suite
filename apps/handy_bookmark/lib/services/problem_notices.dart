import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'reminders.dart';

/// One problem that needs the person: a key (`backup`, `sync`, `shares`),
/// what identifies this occurrence (so the same one is not told twice),
/// and its words.
class Problem {
  final String kind, signature, title, body;
  const Problem(this.kind, this.signature, this.title, this.body);
}

/// The problems now, from the app's state. Being offline is not one: it
/// passes by itself.
List<Problem> currentProblems({
  required bool vietnamese,
  String? backupError,
  String? syncState,
  int failedShares = 0,
}) {
  String t(String en, String vi) => vietnamese ? vi : en;
  return [
    if (backupError != null && backupError.isNotEmpty)
      Problem(
        'backup',
        backupError,
        t('Automatic backup did not run', 'Sao lưu tự động chưa chạy được'),
        t(
          'Open Settings › Backup to see why and try again.',
          'Mở Cài đặt › Sao lưu để xem lý do và thử lại.',
        ),
      ),
    if (syncState case 'authNeeded' || 'quota' || 'failed')
      Problem(
        'sync',
        syncState!,
        switch (syncState) {
          'authNeeded' => t(
            'Google Drive sync needs you to sign in again',
            'Đồng bộ Google Drive cần đăng nhập lại',
          ),
          'quota' => t(
            'Google Drive is full, sync has stopped',
            'Google Drive đã đầy, đồng bộ đã dừng',
          ),
          _ => t(
            'Google Drive sync is failing',
            'Đồng bộ Google Drive đang lỗi',
          ),
        },
        t('Open Settings › Sync to fix it.', 'Mở Cài đặt › Đồng bộ để xử lý.'),
      ),
    if (failedShares > 0)
      Problem(
        'shares',
        '$failedShares',
        t(
          failedShares == 1
              ? '1 shared link was not saved'
              : '$failedShares shared links were not saved',
          '$failedShares link chia sẻ chưa lưu được',
        ),
        t(
          'Open Handy Bookmark to save them again or let them go.',
          'Mở Handy Bookmark để lưu lại hoặc bỏ qua.',
        ),
      ),
  ];
}

int problemId(String kind) =>
    ReminderRequest('problem:$kind', tz.TZDateTime.utc(2000)).id;

/// "Needs attention" notifications: one per kind, replaced rather than
/// stacked, withdrawn when the problem is gone, never told twice for the
/// same occurrence (remembered across starts), shown only while the app
/// is not on screen (on screen, the app shows it itself). It never asks
/// for the permission; without it nothing is posted.
class ProblemNotices {
  final SaveReminders reminders;
  ProblemNotices(this.reminders);

  static const _kinds = ['backup', 'sync', 'shares'];
  // 'task' (notifyTaskDone) is told once per run and never withdrawn.
  static String _key(String kind) => 'bookmark.problem.$kind';

  Future<void> update(
    List<Problem> problems, {
    required bool enabled,
    required bool foreground,
    required bool vietnamese,
  }) async {
    if (!reminders.supported) return;
    final prefs = await SharedPreferences.getInstance();
    final plugin = reminders.permissions.plugin;
    final now = {for (final p in problems) p.kind: p};
    for (final kind in _kinds) {
      final told = prefs.getString(_key(kind));
      final p = now[kind];
      if (p == null || !enabled) {
        if (told != null) {
          await prefs.remove(_key(kind));
          await plugin.cancel(id: problemId(kind));
        }
        continue;
      }
      if (told == p.signature || foreground) continue;
      if (!await reminders.allowedNow()) continue;
      await plugin.show(
        id: problemId(kind),
        title: p.title,
        body: p.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'handy-save-problems',
            vietnamese ? 'Cần xử lý' : 'Needs attention',
            channelDescription: vietnamese
                ? 'Sao lưu, đồng bộ hoặc link chưa lưu được'
                : 'Backup, sync or links that could not be saved',
            importance: Importance.defaultImportance,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: false,
          ),
          windows: const WindowsNotificationDetails(),
        ),
        payload: 'problem:$kind',
      );
      await prefs.setString(_key(kind), p.signature);
    }
  }
}

/// "A background job finished" (off by default, Settings › Notifications):
/// a link check or a reading-copy run that ended while the app was away.
/// Stopped runs are not told; nothing asks for the permission here.
Future<void> notifyTaskDone(
  SaveReminders reminders, {
  required bool check,
  required int done,
  required int broken,
  required bool vietnamese,
}) async {
  if (!reminders.supported || !await reminders.allowedNow()) return;
  String t(String en, String vi) => vietnamese ? vi : en;
  await reminders.permissions.plugin.show(
    id: problemId('task'),
    title: check
        ? t('Link check finished', 'Đã kiểm tra xong link')
        : t('Offline copies finished', 'Đã lưu xong bản đọc offline'),
    body: check
        ? t(
            '$done links checked${broken > 0 ? ', $broken need a look' : ', all fine'}.',
            'Đã kiểm tra $done link${broken > 0 ? ', $broken link cần xem lại' : ', tất cả đều ổn'}.',
          )
        : t(
            '$done links saved to read offline.',
            'Đã lưu $done link để đọc offline.',
          ),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'handy-save-tasks',
        vietnamese ? 'Việc chạy nền' : 'Background jobs',
        channelDescription: vietnamese
            ? 'Khi kiểm tra link hoặc lưu bản đọc offline xong'
            : 'When a link check or offline copies finish',
        importance: Importance.low,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: false,
      ),
      windows: const WindowsNotificationDetails(),
    ),
    payload: 'problem:shares',
  );
}
