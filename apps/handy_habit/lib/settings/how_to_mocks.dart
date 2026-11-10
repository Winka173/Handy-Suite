import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../mood/mood_faces.dart';
import '../today/beads.dart';
import '../welcome/scenes.dart';

/// Decorative screen fragments; instructions carry the full-size semantics.
class HabitHelpMock extends StatelessWidget {
  final String topic;
  final int step;
  final bool compact;
  const HabitHelpMock({
    super.key,
    required this.topic,
    this.step = 0,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    String words(String en, String vi) => tr(context, en, vi);
    if (compact)
      return ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 280, child: HabitHelpMock(topic: topic)),
        ),
      );
    // Each step rings the relevant control, in the same order as its instructions.
    final rows = switch (topic) {
      'start' || 'templates' => [
        (Icons.add, words('New habit', 'Thói quen mới'), ''),
        (
          Icons.menu_book_outlined,
          words('Read a little', 'Đọc một chút'),
          words('10 pages · Every day', '10 trang · Mỗi ngày'),
        ),
        (Icons.edit_outlined, words('Edit', 'Sửa'), words('Save', 'Lưu')),
      ],
      'mood' => [
        (
          Icons.face_outlined,
          words('How’s today?', 'Hôm nay bạn thấy sao?'),
          '',
        ),
        (
          Icons.notes_outlined,
          words('Note (optional)', 'Ghi chú (tùy chọn)'),
          '',
        ),
        (Icons.undo, words('Undo', 'Hoàn tác'), ''),
      ],
      'routines' || 'timers' => [
        (
          Icons.format_list_numbered,
          words('A small morning', 'Buổi sáng nhỏ'),
          words('1 / 3 · Drink water', '1 / 3 · Uống nước'),
        ),
        (Icons.check, words('Done step', 'Xong bước'), '0:30'),
        (Icons.pause, words('Pause and exit', 'Tạm dừng và thoát'), ''),
      ],
      'backup' || 'migration' || 'new-phone' => [
        (
          Icons.file_upload_outlined,
          words('Back up as ZIP', 'Sao lưu ZIP'),
          '',
        ),
        (
          Icons.file_download_outlined,
          words('Bring in a backup or CSV', 'Nhập bản sao lưu hoặc CSV'),
          '',
        ),
        (
          Icons.merge,
          words('Merge', 'Gộp'),
          words('Keep both sets of records', 'Giữ cả hai bộ bản ghi'),
        ),
      ],
      'trash' => [
        (
          Icons.delete_outline,
          words('Trash', 'Thùng rác'),
          words('Kept for 30 days', 'Giữ trong 30 ngày'),
        ),
        (
          Icons.restore,
          words('Restore', 'Khôi phục'),
          words('29 days left', 'còn 29 ngày'),
        ),
        (
          Icons.delete_forever_outlined,
          words('Delete for good', 'Xóa vĩnh viễn'),
          '',
        ),
      ],
      'pause' => [
        (Icons.date_range, words('From', 'Từ ngày'), '10/11'),
        (Icons.event, words('Until the end of', 'Đến hết ngày'), '14/11'),
        (Icons.pause_circle_outline, words('Save pause', 'Lưu kỳ nghỉ'), ''),
      ],
      'reminders' => [
        (
          Icons.notifications_outlined,
          words('Send reminders', 'Gửi nhắc'),
          words('On', 'Bật'),
        ),
        (
          Icons.nights_stay_outlined,
          words('Quiet hours', 'Giờ yên lặng'),
          '22:00 – 07:00',
        ),
        (
          Icons.notifications_active_outlined,
          words('Test notification', 'Thử thông báo'),
          '',
        ),
      ],
      'appearance' => [
        (
          Icons.contrast,
          words('Theme', 'Giao diện'),
          words('System', 'Hệ thống'),
        ),
        (
          Icons.language,
          words('Language', 'Ngôn ngữ'),
          words('English', 'Tiếng Việt'),
        ),
        (
          Icons.motion_photos_off_outlined,
          words('Reduce motion', 'Giảm chuyển động'),
          words('On', 'Bật'),
        ),
      ],
      'privacy' || 'sync' => [
        (
          Icons.phone_android,
          words('On this device', 'Trên máy này'),
          words('Your habits stay here', 'Thói quen vẫn ở đây'),
        ),
        (
          topic == 'sync' ? Icons.sync : Icons.lock_outline,
          topic == 'sync'
              ? words('Sync', 'Đồng bộ')
              : words('Privacy policy', 'Chính sách riêng tư'),
          '',
        ),
      ],
      'negative' => [
        (
          Icons.local_drink_outlined,
          words('Sugary drinks', 'Nước ngọt'),
          words('2 of 3 allowed today', '2/3 lần cho phép hôm nay'),
        ),
        (Icons.add, words('+1 incident', '+1 lần'), ''),
        (Icons.check, words('None today', 'Hôm nay không có'), ''),
      ],
      _ => [
        (
          Icons.water_drop_outlined,
          words('Drink water', 'Uống nước'),
          words('1 / 8 times', '1 / 8 lần'),
        ),
        (Icons.undo, words('Undo', 'Hoàn tác'), ''),
        (Icons.expand_more, words('Show all 12', 'Xem tất cả 12'), ''),
      ],
    };
    final picture = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: i == step ? p.ochreField : null,
                border: Border.all(
                  color: i == step ? p.anchor : p.line,
                  width: i == step ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(rows[i].$1, size: 22, color: p.anchor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$2),
                        if (rows[i].$3.isNotEmpty)
                          Text(
                            rows[i].$3,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
            if (i == 0 && topic == 'mood')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [for (var n = 1; n <= 5; n++) MoodFace(value: n)],
                ),
              ),
            if (i == 0 &&
                [
                  'check-in',
                  'streaks',
                  'progress',
                  'widgets',
                ].contains(topic)) ...[
              const SizedBox(height: 12),
              BeadWeek(completed: 5, color: p.ochre),
              Align(
                alignment: Alignment.centerRight,
                child: Bead(
                  status: 'progress',
                  fill: 1 / 8,
                  size: 48,
                  color: p.ochre,
                ),
              ),
            ],
            if (i == 0 && ['routines', 'timers'].contains(topic))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(value: .5),
              ),
            if (i == 0 && topic == 'negative')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final status in ['withinLimit', 'overLimit', 'unknown'])
                    Bead(status: status, fill: 0, size: 28, color: p.ochre),
                ],
              ),
          ],
        ],
      ),
    );
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: LayoutBuilder(
          builder: (context, box) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: box.maxWidth.clamp(280, 440),
              child: picture,
            ),
          ),
        ),
      ),
    );
  }
}
