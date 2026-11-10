import 'package:handy_ui/kit.dart';

class HabitHelpTopic {
  final String id, en, vi;
  final List<(String, String)> steps;
  const HabitHelpTopic(this.id, this.en, this.vi, this.steps);
  String title(BuildContext c) => tr(c, en, vi);
  String searchText() =>
      '$en $vi ${steps.map((s) => '${s.$1} ${s.$2}').join(' ')}';
}

const habitHelpTopics = [
  HabitHelpTopic('start', 'Getting started: create a habit', 'Bắt đầu: tạo thói quen', [
    (
      'On Today, choose New habit, or pick an optional goal chip on an empty day. Templates pre-fill the editor; nothing is saved yet.',
      'Ở Hôm nay, chọn Thói quen mới hoặc mục tiêu tùy chọn khi chưa có thói quen. Mẫu điền sẵn trình sửa, chưa lưu gì.',
    ),
    (
      'Give it a concrete name. Choose Done or not, A number of times, Minutes or An amount. Set the goal and schedule, then Save.',
      'Đặt tên cụ thể. Chọn Có hoặc chưa, Số lần, Số phút hoặc Số lượng. Đặt mục tiêu, lịch rồi Lưu.',
    ),
    (
      'Open the habit’s name, then Edit to change it. A new schedule applies from the selected day; past days keep their old goal. Advanced contains the less common options.',
      'Mở tên thói quen, chọn Sửa. Lịch mới áp dụng từ ngày đã chọn; ngày cũ giữ mục tiêu cũ. Nâng cao chứa tùy chọn ít dùng.',
    ),
  ]),
  HabitHelpTopic(
    'check-in',
    'Check in, Undo and history',
    'Ghi nhận, hoàn tác và lịch sử',
    [
      (
        'Tap today’s large bead. Done or not completes the day; a count adds one. Minutes and amounts open an entry.',
        'Chạm hạt lớn hôm nay. Có hoặc chưa hoàn thành ngày; số lần cộng một. Phút và số lượng mở ô nhập.',
      ),
      (
        'Tap Undo in the message after saving. For older days, open the habit and choose a calendar day to add, correct or skip a record. The backfill limit is in Settings.',
        'Bấm Hoàn tác trong thông báo sau khi lưu. Ngày cũ: mở thói quen, chọn ngày trên lịch để thêm, sửa hoặc bỏ qua. Giới hạn ghi bù ở Cài đặt.',
      ),
      (
        'Show all opens older records in place. Editing an old day does not move it when you change your time zone or day boundary.',
        'Xem tất cả mở bản ghi cũ tại chỗ. Đổi múi giờ hay giờ bắt đầu ngày không dời bản ghi đã lưu.',
      ),
    ],
  ),
  HabitHelpTopic('streaks', 'Streaks and missed days', 'Chuỗi ngày và ngày bỏ lỡ', [
    (
      'A filled bead means its goal was reached. A partial ring shows progress. A hollow bead is a missed day, with no red warning.',
      'Hạt đầy là đã đạt mục tiêu. Vòng một phần là tiến độ. Hạt rỗng là ngày bỏ lỡ, không cảnh báo đỏ.',
    ),
    (
      'Current streak counts consecutive completed scheduled days; a missed day restarts it. Your longest streak and completed days remain. A weekly quota is measured by weeks.',
      'Chuỗi hiện tại đếm các ngày theo lịch hoàn thành liên tiếp; ngày lỡ bắt đầu lại chuỗi. Chuỗi dài nhất và ngày đã làm còn nguyên. Chỉ tiêu tuần được tính theo tuần.',
    ),
    (
      'Consistency compares completed days with due days in the chosen period. Paused and unscheduled days are not missed days.',
      'Độ đều đặn so ngày hoàn thành với ngày đến lịch trong khoảng chọn. Ngày nghỉ và không đến lịch không phải ngày bỏ lỡ.',
    ),
  ]),
  HabitHelpTopic('pause', 'Pause and vacation', 'Tạm nghỉ và kỳ nghỉ', [
    (
      'Choose + then Pause, or pause from a habit’s menu. Pick the first and last day, then all habits or selected habits.',
      'Chọn + rồi Kỳ nghỉ, hoặc nghỉ từ menu thói quen. Chọn ngày đầu và cuối, rồi mọi thói quen hoặc vài thói quen.',
    ),
    (
      'Both dates are included. Paused days preserve a streak and get no reminders. If you still check in, that completed day counts.',
      'Gồm cả hai ngày đầu cuối. Ngày nghỉ giữ chuỗi, không nhắc. Nếu vẫn ghi nhận, ngày hoàn thành ấy vẫn tính.',
    ),
    (
      'Settings shows your pauses. Edit or end a pause there; the screen previews which dates and habits it affects.',
      'Cài đặt hiện các kỳ nghỉ. Sửa hoặc kết thúc tại đó; màn hình cho xem ngày và thói quen bị ảnh hưởng.',
    ),
  ]),
  HabitHelpTopic('routines', 'Routines and the runner', 'Quy trình và màn chạy', [
    (
      'In Routines, create a routine and add ordered steps. Basic shows name, time and an optional linked habit. Advanced adds required, skippable and timing details.',
      'Trong Quy trình, tạo quy trình và thêm các bước có thứ tự. Cơ bản hiện tên, giờ và thói quen liên kết tùy chọn. Nâng cao thêm bắt buộc, cho bỏ qua và chi tiết thời gian.',
    ),
    (
      'Choose Start. Done step records its linked habit once. Previous and Next navigate without completing. Skip is available only for skippable steps; Undo reverses the current completed step.',
      'Chọn Bắt đầu. Xong bước ghi thói quen liên kết một lần. Trước và Tiếp chỉ chuyển bước. Chỉ bước cho phép mới Bỏ qua được; Hoàn tác gỡ bước hiện tại đã xong.',
    ),
    (
      'Pause and exit saves your place. Resume from Today or Routines. Finish opens a summary and saved session; changing the routine later does not rewrite that session.',
      'Tạm dừng và thoát lưu chỗ đang làm. Tiếp tục từ Hôm nay hoặc Quy trình. Kết thúc mở tổng kết và phiên đã lưu; sửa quy trình sau đó không đổi phiên cũ.',
    ),
  ]),
  HabitHelpTopic(
    'timers',
    'Timers and routine recovery',
    'Bộ đếm giờ và phục hồi phiên',
    [
      (
        'The runner shows planned and elapsed time. Pause stops the timer; add a minute when needed. An untimed step finishes when you say so.',
        'Màn chạy hiện thời gian dự kiến và đã dùng. Tạm dừng dừng bộ đếm; thêm một phút khi cần. Bước không tính giờ xong khi bạn bấm.',
      ),
      (
        'Leaving the app pauses the timer. After an interruption, the saved run resumes paused. Timers do not keep running after the app is terminated. Paused-run notifications depend on permission and platform support.',
        'Rời app tạm dừng bộ đếm. Sau gián đoạn, phiên lưu mở lại ở trạng thái dừng. Bộ đếm không tiếp tục khi app bị đóng hẳn. Thông báo phiên dở tùy quyền và nền tảng.',
      ),
    ],
  ),
  HabitHelpTopic(
    'templates',
    'Habit and routine templates',
    'Mẫu thói quen và quy trình',
    [
      (
        'Choose New habit to explore the existing starter groups, or use a routine template in Routines. Preview and customize before saving.',
        'Chọn Thói quen mới để xem nhóm mẫu có sẵn, hoặc dùng mẫu trong Quy trình. Xem và tùy chỉnh trước khi lưu.',
      ),
      (
        'Templates create new items. Changing a template-based habit never changes your other habits or saved sessions.',
        'Mẫu tạo mục mới. Sửa thói quen tạo từ mẫu không đổi thói quen khác hay phiên đã lưu.',
      ),
    ],
  ),
  HabitHelpTopic(
    'appearance',
    'Appearance and accessibility',
    'Giao diện và khả năng tiếp cận',
    [
      (
        'Settings → Appearance changes theme, language, density and reduced motion. System follows the device; reduced motion also respects the operating system.',
        'Cài đặt → Giao diện đổi sáng tối, ngôn ngữ, độ gọn và giảm chuyển động. Hệ thống theo thiết bị; giảm chuyển động cũng tôn trọng hệ điều hành.',
      ),
      (
        'Edit a habit’s colour and icon in its appearance controls. Missed days stay neutral. Larger system text wraps; keyboard users can press Ctrl/Cmd+, for Settings and Esc to go back.',
        'Sửa màu và biểu tượng ở giao diện của thói quen. Ngày lỡ giữ màu trung tính. Chữ hệ thống lớn tự xuống dòng; bàn phím dùng Ctrl/Cmd+, mở Cài đặt, Esc quay lại.',
      ),
    ],
  ),
  HabitHelpTopic(
    'reminders',
    'Reminders: why didn’t mine appear?',
    'Nhắc nhở: vì sao không thấy thông báo?',
    [
      (
        'Settings → Notifications explains the permission, then Send reminders asks only when you turn it on. Add a reminder for a habit or routine, choose time and weekdays, and save.',
        'Cài đặt → Thông báo giải thích quyền, rồi Gửi nhắc chỉ hỏi khi bạn bật. Thêm lịch nhắc cho thói quen hoặc quy trình, chọn giờ, thứ và lưu.',
      ),
      (
        'Check global reminders, the rule’s On switch, system notification permission, quiet hours and pauses. Quiet hours move a reminder to the end. Archived or trashed items do not remind.',
        'Kiểm tra Gửi nhắc, nút Bật của lịch, quyền thông báo hệ thống, giờ yên lặng và kỳ nghỉ. Giờ yên lặng dời nhắc tới cuối khoảng. Mục lưu trữ hoặc trong thùng rác không nhắc.',
      ),
      (
        'Use Test notification after permission is granted. On Android, battery restrictions can delay delivery; allow Handy Habit in system notification settings. Windows cannot report whether you disabled toasts. Web has no background reminders. Opening the app refreshes upcoming notices; delivery after termination has not been device verified.',
        'Dùng Thử thông báo sau khi cấp quyền. Android có thể chậm do hạn chế pin; cho phép Handy Habit trong cài đặt thông báo hệ thống. Windows không đọc được việc bạn tắt thông báo. Web không nhắc nền. Mở app làm mới lịch nhắc; chưa kiểm tra trên thiết bị khi app bị đóng hẳn.',
      ),
    ],
  ),
  HabitHelpTopic(
    'backup',
    'Backup, restore and recovery',
    'Sao lưu, khôi phục và phục hồi',
    [
      (
        'Settings → Data offers ZIP and JSON backups. Keep a copy outside this device. Exports contain private habit data; local storage is not encrypted.',
        'Cài đặt → Dữ liệu có sao lưu ZIP và JSON. Giữ một bản ngoài máy. File xuất chứa dữ liệu thói quen riêng tư; dữ liệu trên máy không mã hóa.',
      ),
      (
        'Bring in a backup or CSV validates before writing. A backup preview shows its contents: Merge keeps both libraries; Replace needs a second confirmation and keeps a recovery copy. A sealed .hseal backup needs its password.',
        'Nhập bản sao lưu hoặc CSV kiểm tra trước khi ghi. Xem trước bản sao hiện nội dung: Gộp giữ cả hai; Thay thế cần xác nhận lần nữa và giữ bản phục hồi. Bản .hseal cần mật khẩu.',
      ),
      (
        'Recover before last replace restores that device copy after confirmation. Automatic folder backups use the shared backup controls where supported; they run when the app opens or backgrounds, never promise a closed-app schedule. Web uses manual download/upload.',
        'Khôi phục trước lần thay thế cuối lấy lại bản trên máy sau xác nhận. Sao lưu thư mục tự động dùng điều khiển chung nơi hỗ trợ; chạy khi mở hoặc đưa app về nền, không hứa lịch khi đóng app. Web dùng tải xuống/tải lên thủ công.',
      ),
    ],
  ),
  HabitHelpTopic(
    'trash',
    'Trash and archived habits',
    'Thùng rác và thói quen lưu trữ',
    [
      (
        'Archive hides an item from Today without deleting its history. Use the archive filter in Habits or Routines to bring it back.',
        'Lưu trữ ẩn mục khỏi Hôm nay, không xóa lịch sử. Dùng bộ lọc lưu trữ trong Thói quen hoặc Quy trình để đưa lại.',
      ),
      (
        'Deleted habits and routines stay in Settings → Trash for 30 days. Restore keeps their history. Delete for good needs confirmation and cannot be undone. End an active linked run before deletion.',
        'Thói quen và quy trình đã xóa ở Cài đặt → Thùng rác 30 ngày. Khôi phục giữ lịch sử. Xóa vĩnh viễn cần xác nhận, không hoàn tác được. Kết thúc phiên liên kết đang chạy trước khi xóa.',
      ),
    ],
  ),
  HabitHelpTopic('migration', 'Move to another device', 'Chuyển sang thiết bị mới', [
    (
      'Export a ZIP backup on the old device. Transfer it using your own files or sharing service. On the new device choose Settings → Bring in a backup or CSV, then preview and Merge or Replace.',
      'Xuất sao lưu ZIP trên máy cũ. Chuyển file bằng dịch vụ của bạn. Máy mới chọn Cài đặt → Nhập bản sao lưu hoặc CSV, xem trước rồi Gộp hoặc Thay thế.',
    ),
    (
      'Verify habits, history and routines on the new device before removing the old app. Notification permissions and folder destinations must be set on each device. Automatic cloud sync is not available in this build.',
      'Kiểm tra thói quen, lịch sử và quy trình trên máy mới trước khi gỡ app cũ. Quyền thông báo và thư mục sao lưu phải đặt trên từng máy. Bản này chưa có đồng bộ cloud tự động.',
    ),
  ]),
  HabitHelpTopic('progress', 'Progress and weekly review', 'Tiến bộ và nhìn lại tuần', [
    (
      'Progress shows the existing date-range summaries and saved routine sessions. Today offers a weekly review when one is due; choose a week to inspect its completed and due counts.',
      'Tiến bộ hiện tổng kết theo khoảng ngày và phiên quy trình đã lưu. Hôm nay có nhìn lại tuần khi đến lịch; chọn tuần để xem số đã làm và đến lịch.',
    ),
    (
      'Use a habit’s calendar for a particular day. These are records of your practice, not medical advice or a prediction.',
      'Dùng lịch của thói quen để xem ngày cụ thể. Đây là ghi chép việc bạn làm, không phải tư vấn y tế hay dự đoán.',
    ),
  ]),
  HabitHelpTopic('widgets', 'Home-screen widget', 'Tiện ích màn hình chính', [
    (
      'Android has the existing Today widget with habit links and quick check-in. Add it using the launcher’s widget picker, then open Habit to refresh its data.',
      'Android có tiện ích Hôm nay với liên kết thói quen và ghi nhận nhanh. Thêm qua bộ chọn tiện ích của màn hình chính, rồi mở Habit để làm mới dữ liệu.',
    ),
    (
      'Widget support is not provided here for iOS, Windows or Web. Launcher behavior and refresh need device checks.',
      'Ở đây chưa có tiện ích cho iOS, Windows hoặc Web. Cách launcher hoạt động và làm mới cần kiểm tra trên thiết bị.',
    ),
  ]),
  HabitHelpTopic(
    'privacy',
    'Privacy and local data',
    'Quyền riêng tư và dữ liệu trên máy',
    [
      (
        'Habit works without an account or developer server. Your library stays on your device. Reminder text is private by default; you can choose to show names in Settings.',
        'Habit dùng không cần tài khoản hoặc máy chủ nhà phát triển. Thư viện ở trên máy. Mặc định nhắc ẩn tên; bạn có thể hiện tên trong Cài đặt.',
      ),
      (
        'Backups you export contain personal data. Store them somewhere you trust. Reset preferences keeps habits, history and reminders; Delete all Habit data is a separate confirmed action. Privacy policy and support are in Settings.',
        'Bản sao bạn xuất chứa dữ liệu cá nhân. Cất ở nơi tin cậy. Đặt lại cài đặt giữ thói quen, lịch sử và lịch nhắc; Xóa toàn bộ dữ liệu Habit là thao tác riêng cần xác nhận. Chính sách và hỗ trợ ở Cài đặt.',
      ),
    ],
  ),
];

String foldHabitHelp(String value) {
  var out = value.toLowerCase();
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final g in groups.entries) {
    for (final c in g.value.split('')) {
      out = out.replaceAll(c, g.key);
    }
  }
  return out.replaceAll(RegExp(r'[\u0300-\u036f]'), '').trim();
}
