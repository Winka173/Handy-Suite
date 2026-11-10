import 'package:handy_ui/kit.dart';

/// A concise entry point to the shipped daily jobs; the full help centre is R9.
class HabitHelpPage extends StatelessWidget {
  const HabitHelpPage({super.key});
  @override
  Widget build(BuildContext context) => HandyPage(
    title: tr(context, 'Help', 'Trợ giúp'),
    children: [
      for (final (en, vi, detailEn, detailVi, path) in const [
        (
          'Check in and Undo',
          'Đánh dấu và hoàn tác',
          'Tap today’s large bead. A count adds one; amounts open an entry. Undo appears after saving.',
          'Chạm hạt lớn hôm nay. Số lần cộng một; số lượng mở ô nhập. Hoàn tác xuất hiện sau khi lưu.',
          '/today',
        ),
        (
          'Habits and history',
          'Thói quen và lịch sử',
          'Open a habit’s name to see its calendar and records. Show all opens older entries in place. Missed days stay neutral.',
          'Mở tên thói quen để xem lịch và các lần ghi. Xem tất cả mở bản ghi cũ tại chỗ. Ngày bỏ lỡ giữ màu trung tính.',
          '/habits',
        ),
        (
          'Run a routine',
          'Chạy quy trình',
          'Choose Start on a routine. You can pause and continue an unfinished run.',
          'Chọn Bắt đầu trên quy trình. Bạn có thể tạm dừng và tiếp tục buổi chạy còn dở.',
          '/routines',
        ),
        (
          'Review your progress',
          'Xem tiến bộ',
          'Choose a date range to see completed days and routine sessions. A pause is not a missed day.',
          'Chọn khoảng ngày để xem ngày hoàn thành và các buổi chạy. Ngày nghỉ không phải ngày bỏ lỡ.',
          '/progress',
        ),
        (
          'Protect your data',
          'Bảo vệ dữ liệu',
          'Settings contains backup, restore, recovery and 30-day Trash. Keep a backup outside this device.',
          'Cài đặt có sao lưu, khôi phục, bản phục hồi và Thùng rác 30 ngày. Giữ bản sao ngoài máy này.',
          '/settings',
        ),
      ])
        HandySection(
          title: tr(context, en, vi),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr(context, detailEn, detailVi)),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, path),
                child: Text(tr(context, 'Open', 'Mở')),
              ),
            ),
          ],
        ),
    ],
  );
}
