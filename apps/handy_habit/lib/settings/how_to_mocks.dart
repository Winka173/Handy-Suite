import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../welcome/scenes.dart';
import '../today/beads.dart';

/// Drawn fragments reuse real beads and labels. Instructions carry semantics.
class HabitHelpMock extends StatelessWidget {
  final String topic;
  const HabitHelpMock({super.key, required this.topic});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    final rows = switch (topic) {
      'negative' => [
        ('Break a habit · Sugary drinks', 'Giảm thói quen · Nước ngọt'),
        ('2 of 3 allowed today', '2/3 lần cho phép hôm nay'),
        (
          '+1 incident · None today · Undo',
          '+1 lần · Hôm nay không có · Hoàn tác',
        ),
      ],
      'backup' || 'migration' => [
        ('Back up as ZIP', 'Sao lưu ZIP'),
        ('Bring in a backup or CSV', 'Nhập bản sao lưu hoặc CSV'),
        ('Merge · Replace', 'Gộp · Thay thế'),
      ],
      'trash' => [
        ('Trash · 30 days', 'Thùng rác · 30 ngày'),
        ('Restore', 'Khôi phục'),
        ('Delete for good', 'Xóa vĩnh viễn'),
      ],
      'reminders' => [
        ('Send reminders', 'Gửi nhắc'),
        ('Quiet hours · 22:00 – 07:00', 'Giờ yên lặng · 22:00 – 07:00'),
        ('Test notification', 'Thử thông báo'),
      ],
      'pause' => [
        ('From · 10 Nov', 'Từ ngày · 10/11'),
        ('Until the end of · 14 Nov', 'Đến hết ngày · 14/11'),
        ('Save pause', 'Lưu kỳ nghỉ'),
      ],
      'routines' || 'timers' => [
        ('A small morning', 'Buổi sáng nhỏ'),
        ('Drink water · 0:30', 'Uống nước · 0:30'),
        ('Done step · Pause and exit', 'Xong bước · Tạm dừng và thoát'),
      ],
      'appearance' => [
        ('Theme · System', 'Giao diện · Hệ thống'),
        ('Language · English', 'Ngôn ngữ · Tiếng Việt'),
        ('Reduce motion · On', 'Giảm chuyển động · Bật'),
      ],
      'start' || 'templates' => [
        ('Name · Read a little', 'Tên · Đọc một chút'),
        ('Each day, at least · 10 pages', 'Mỗi ngày tối thiểu · 10 trang'),
        ('How often · Every day', 'Bao lâu một lần · Mỗi ngày'),
      ],
      'privacy' => [
        ('Everything stays on this device', 'Mọi thứ ở trên máy này'),
        ('Privacy policy', 'Chính sách riêng tư'),
      ],
      _ => [('Drink water', 'Uống nước'), ('1 / 8 times', '1 / 8 lần')],
    };
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr(context, r.$1, r.$2)),
              ),
            if (topic == 'negative')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    for (final status in [
                      'withinLimit',
                      'overLimit',
                      'unknown',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Bead(
                          status: status,
                          fill: 0,
                          size: 24,
                          color: p.ochre,
                        ),
                      ),
                  ],
                ),
              ),
            if ([
              'check-in',
              'streaks',
              'progress',
              'widgets',
            ].contains(topic)) ...[
              const SizedBox(height: 12),
              BeadWeek(completed: 5, color: p.ochre),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Bead(
                  status: 'progress',
                  fill: 1 / 8,
                  size: 48,
                  color: p.ochre,
                ),
              ),
              Text(
                tr(context, 'Undo', 'Hoàn tác'),
                style: TextStyle(color: p.anchor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
