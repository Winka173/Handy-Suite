import 'package:handy_ui/kit.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'controller.dart';
import 'sync/drive_sync.dart';
import 'platform/reminders.dart';
import 'ui/labels.dart';

class BoardsScope {
  final BoardsReminders reminders;
  final BoardsController controller;
  final HandyFiles files;
  final DateTime Function() clock;

  /// Daily copies in the app's own storage; none on the web and in tests.
  final HandyAutoBackup? autoBackup;

  /// Google Drive sync, where this build and device offer it.
  final BoardsDriveSync? drive;
  bool adsAllowed = false;
  BoardsScope(
    this.controller, {
    this.files = const SystemHandyFiles(),
    this.autoBackup,
    this.drive,
    DateTime Function()? clock,
    BoardsReminders? reminders,
  }) : clock = clock ?? DateTime.now,
       reminders = reminders ?? BoardsReminders();
  BoardsState get state => controller.state!;
  Future<void> run(BuildContext context, Future<void> Function() action) async {
    controller.adsVisible.value = false;
    try {
      await action();
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Shown long enough to act on, then it goes (with an action
            // Flutter would keep it until dismissed).
            persist: false,
            content: Text(
              '${tr(context, 'Action failed; previous data kept', 'Thao tác lỗi; dữ liệu trước được giữ')}: ${boardsError(context, e)}',
            ),
          ),
        );
    } finally {
      if (context.mounted)
        controller.adsVisible.value =
            adsAllowed && ModalRoute.of(context)?.isCurrent == true;
    }
  }
}
