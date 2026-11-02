import 'package:handy_files/handy_files.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'platform/location.dart';
import 'platform/reminders.dart';
import 'platform/media.dart';

class TripScope extends ChangeNotifier {
  final TripController controller;
  final HandyFiles files;
  final ForegroundLocation locationPort;
  final TripReminders reminders;
  final DateTime Function() clock;
  final camera = TripCamera();
  final map = NoBasemap();
  String? selectedTrip;
  String? selectedDay;
  int area = 0, section = 0;
  String search = '';
  int page = 100;
  int _privateActions = 0;
  TripScope({
    required this.controller,
    required this.files,
    required this.locationPort,
    required this.reminders,
    required this.clock,
  });
  TripState get state => controller.state!;
  Trip? get trip => state.trips.where((t) => t.key == selectedTrip).firstOrNull;
  String get today => localDay(
    clock(),
    trip?.zone ?? state.settings['zone'] as String? ?? 'Asia/Ho_Chi_Minh',
  );
  void chooseTrip(String? key) {
    selectedTrip = key;
    selectedDay = null;
    section = 0;
    notifyListeners();
  }

  void update(VoidCallback callback) {
    callback();
    controller.adsVisible.value =
        _privateActions == 0 &&
        section != 4 &&
        state.settings['onboarded'] == true;
    notifyListeners();
  }

  Future<void> run(BuildContext context, Future<void> Function() action) async {
    if (controller.busy) return;
    _privateActions++;
    controller.adsVisible.value = false;
    try {
      await action();
      try {
        await reminders.sync(state);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  context,
                  'Saved. Reminders could not be updated; check notification permission.',
                  'Đã lưu. Chưa cập nhật được nhắc nhở; hãy kiểm tra quyền thông báo.',
                ),
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'Could not complete. Check input, permissions and storage; existing data preserved.',
                'Chưa thực hiện được. Kiểm tra dữ liệu, quyền và bộ nhớ; dữ liệu cũ được giữ nguyên.',
              ),
            ),
          ),
        );
    } finally {
      _privateActions--;
      if (!controller.disposed)
        controller.adsVisible.value =
            _privateActions == 0 &&
            section != 4 &&
            state.settings['onboarded'] == true;
    }
  }

  bool match(String value) =>
      foldAccents(value).contains(foldAccents(search.trim()));
}
