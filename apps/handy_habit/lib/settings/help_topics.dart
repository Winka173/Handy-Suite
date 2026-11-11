import 'package:handy_ui/kit.dart';

class HabitHelpTopic {
  final String id, en, vi;
  final List<(String, String)> steps;
  const HabitHelpTopic(this.id, this.en, this.vi, this.steps);
  String title(BuildContext c) => tr(c, en, vi);
  IconData get icon => switch (id) {
    'start' => Icons.add_circle_outline,
    'check-in' => Icons.check_circle_outline,
    'streaks' => Icons.grain,
    'pause' => Icons.pause_circle_outline,
    'routines' => Icons.format_list_numbered,
    'timers' => Icons.timer_outlined,
    'templates' => Icons.dashboard_customize_outlined,
    'appearance' => Icons.palette_outlined,
    'reminders' => Icons.notifications_outlined,
    'sync' => Icons.sync,
    'new-phone' || 'migration' => Icons.phone_android,
    'backup' => Icons.archive_outlined,
    'trash' => Icons.delete_outline,
    'progress' => Icons.insights_outlined,
    'widgets' => Icons.widgets_outlined,
    'privacy' => Icons.shield_outlined,
    'negative' => Icons.remove_circle_outline,
    _ => Icons.mood_outlined,
  };
  String summary(BuildContext c) {
    final (en, vi) = switch (id) {
      'start' => (
        'Choose a habit, a goal and its rhythm.',
        'Chọn thói quen, mục tiêu và lịch thực hiện.',
      ),
      'check-in' => (
        'Tap today’s bead; correct a day in history.',
        'Chạm hạt hôm nay; sửa một ngày trong lịch sử.',
      ),
      'streaks' => (
        'Read filled, partial and quiet missed beads.',
        'Đọc hạt đầy, một phần và ngày bỏ lỡ.',
      ),
      'pause' => (
        'Take a break without losing your history.',
        'Nghỉ một thời gian, vẫn giữ lịch sử.',
      ),
      'routines' => (
        'Put steps in order and run them one at a time.',
        'Xếp các bước rồi thực hiện từng bước.',
      ),
      'timers' => (
        'Pause, return and finish at your own pace.',
        'Tạm dừng, quay lại và hoàn thành theo nhịp riêng.',
      ),
      'templates' => (
        'Preview a starting point before making it yours.',
        'Xem trước một mẫu rồi chỉnh theo ý bạn.',
      ),
      'appearance' => (
        'Theme, language, text and reduced motion.',
        'Giao diện, ngôn ngữ, chữ và giảm chuyển động.',
      ),
      'reminders' => (
        'Check permission, times and quiet hours.',
        'Kiểm tra quyền, giờ nhắc và giờ yên lặng.',
      ),
      'sync' => (
        'Keep devices in step with Google Drive.',
        'Đồng bộ các máy bằng Google Drive.',
      ),
      'new-phone' => (
        'Move your habits with a backup or sync.',
        'Chuyển thói quen bằng sao lưu hoặc đồng bộ.',
      ),
      'backup' => (
        'Save a copy, preview a restore and recover.',
        'Lưu bản sao, xem trước khôi phục và phục hồi.',
      ),
      'trash' => (
        'Bring deleted items back within 30 days.',
        'Lấy lại mục đã xóa trong 30 ngày.',
      ),
      'migration' => (
        'Check your data after moving to a new device.',
        'Kiểm tra dữ liệu sau khi chuyển sang máy mới.',
      ),
      'progress' => (
        'See your rhythm by week, month and year.',
        'Xem nhịp thực hiện theo tuần, tháng và năm.',
      ),
      'widgets' => (
        'See today’s habits on your home screen.',
        'Xem thói quen hôm nay trên màn hình chính.',
      ),
      'privacy' => (
        'Understand local data, backups and permissions.',
        'Hiểu dữ liệu trên máy, sao lưu và các quyền.',
      ),
      'negative' => (
        'Record incidents and days with none.',
        'Ghi lần xảy ra và ngày không có lần nào.',
      ),
      _ => (
        'Record how you feel, with an optional note.',
        'Ghi cảm nhận, có thể thêm ghi chú.',
      ),
    };
    return tr(c, en, vi);
  }

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
        'Choose New habit or New routine to open Templates. Search in English or Vietnamese, choose a collection, then preview the goal, schedule or steps. Customise opens a draft; only Save creates it.',
        'Chọn Thói quen mới hoặc Quy trình mới để mở Mẫu gợi ý. Tìm tiếng Anh hoặc tiếng Việt, chọn nhóm rồi xem mục tiêu, lịch hoặc các bước. Tùy chỉnh mở bản nháp; chỉ Lưu mới tạo.',
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
        'Settings → General changes language and light or dark; System follows the device. Density is under Settings → Defaults and calendar. Motion follows the device’s own reduce-motion setting.',
        'Cài đặt → Chung đổi ngôn ngữ và sáng hay tối; Hệ thống theo thiết bị. Độ gọn nằm ở Cài đặt → Mặc định và lịch. Chuyển động theo cài đặt giảm chuyển động của máy.',
      ),
      (
        'Pro is one payment, no subscription: routines that adapt, deeper Progress, the personalization studio, rules and batch changes. Settings → Upgrade to Pro shows each part playing before you buy, and Restore brings it back on a new phone.',
        'Pro trả một lần, không thuê bao: quy trình linh hoạt, Tiến bộ sâu hơn, xưởng giao diện, quy tắc và thay đổi hàng loạt. Cài đặt → Nâng cấp Pro cho xem từng phần trước khi mua, và Khôi phục để lấy lại trên máy mới.',
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
        'Open Settings → Notifications → Why didn’t my reminder appear? Diagnostics shows permission, Android exact alarms and battery optimisation, last successful scheduling, and Test notification. Flexible reminders do not require exact alarms; Android can delay them. Battery and notification links open system Settings. Windows uses local toasts but cannot read whether they are disabled; iOS uses local notices. Web has no background reminders. Reopen Habit to refresh the earliest 50 reminders within 400 days; delivery after termination needs device checks.',
        'Mở Cài đặt → Thông báo → Vì sao không thấy thông báo? Trang kiểm tra có quyền, báo thức chính xác và tối ưu pin Android, lần đặt lịch thành công, và Thử thông báo. Lịch nhắc linh hoạt không cần báo thức chính xác; Android vẫn có thể làm chậm. Liên kết pin và thông báo mở Cài đặt hệ thống. Windows dùng thông báo cục bộ nhưng không đọc được bạn đã tắt chưa; iOS dùng thông báo cục bộ. Web không nhắc nền. Mở Habit để làm mới 50 lần nhắc sớm nhất trong 400 ngày; gửi khi đóng hẳn cần kiểm tra trên thiết bị.',
      ),
    ],
  ),
  HabitHelpTopic('sync', 'Sync vs backup', 'Đồng bộ và sao lưu', [
    (
      'Sync keeps edits, check-ins, incidents, mood and deletions in step between Android devices. It is optional and free. Open Settings → Data → Sync → Turn on sync and choose the same Google account on each phone. The row appears only in Android builds configured for Drive.',
      'Đồng bộ giữ các sửa đổi, lần ghi, sự cố, tâm trạng và xóa nhất quán giữa các máy Android. Tùy chọn và miễn phí. Mở Cài đặt → Dữ liệu → Đồng bộ → Bật đồng bộ rồi chọn cùng tài khoản Google trên từng máy. Mục này chỉ có ở bản Android được cấu hình Drive.',
    ),
    (
      'Sync runs on app open, on return and after changes while open. Offline changes wait here. Sync now, pending changes, last successful sync, activity and errors are on the Sync screen.',
      'Đồng bộ khi mở app, quay lại và sau thay đổi lúc đang mở. Thay đổi ngoại tuyến chờ trên máy. Màn Đồng bộ có Đồng bộ ngay, thay đổi chờ, lần thành công gần nhất, hoạt động và lỗi.',
    ),
    (
      'A backup is a separate copy you can restore later. Sync carries deletions too, so keep backups. Turning off or disconnecting deletes neither copy. Data goes to your own hidden Drive app folder without developer servers or end-to-end encryption.',
      'Sao lưu là bản riêng có thể khôi phục sau. Đồng bộ cũng chuyển thao tác xóa, nên hãy giữ bản sao lưu. Tắt hay ngắt kết nối không xóa bản nào. Dữ liệu vào thư mục ẩn riêng của app trên Drive của bạn, không qua máy chủ nhà phát triển và không mã hóa đầu-cuối.',
    ),
    (
      'Needs review keeps conflicting totals, skips and mood versions on the Sync screen. Choose what to use. Unresolved days are excluded from progress. Newer remote data stops sync until you update this app.',
      'Cần xem lại giữ các tổng, lựa chọn bỏ qua và phiên bản tâm trạng xung đột ở màn Đồng bộ. Chọn bản muốn dùng. Ngày chưa giải quyết không tính tiến trình. Dữ liệu từ app mới hơn dừng đồng bộ đến khi cập nhật app.',
    ),
  ]),
  HabitHelpTopic('new-phone', 'Move to a new phone', 'Chuyển sang điện thoại mới', [
    (
      'On two Android phones with Drive sync: sync the old phone, turn on sync with the same Google account on the new phone, then Sync now on both. Check habits and history before retiring the old phone. Keep a separate backup.',
      'Trên hai máy Android có đồng bộ Drive: đồng bộ máy cũ, bật đồng bộ cùng tài khoản Google ở máy mới, rồi Đồng bộ ngay trên cả hai. Kiểm tra thói quen và lịch sử trước khi bỏ máy cũ. Giữ bản sao lưu riêng.',
    ),
    (
      'On iOS, Windows, web or an Android build without Sync: use backup to move data. Export ZIP, transfer it privately, then Bring in a backup on the new device. There is no Android ↔ iOS automatic sync. Recheck reminders and permissions.',
      'Trên iOS, Windows, web hoặc bản Android không có Đồng bộ: dùng sao lưu để chuyển dữ liệu. Xuất ZIP, chuyển riêng tư, rồi Nhập bản sao lưu ở máy mới. Không có đồng bộ tự động Android ↔ iOS. Kiểm tra lại lịch nhắc và quyền.',
    ),
  ]),
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
      'Choose Week, Month or Year in Progress. The calendar shows each day; Year has a heatmap for all habits or one habit. Current and best streaks sit beside each habit. Pauses and unknown daily days are excluded from consistency. Look back at the week stays available.',
      'Chọn Tuần, Tháng hoặc Năm trong Tiến bộ. Lịch hiện từng ngày; Năm có bản đồ màu tổng hoặc riêng từng thói quen. Mỗi thói quen có chuỗi hiện tại và dài nhất. Độ đều đặn không tính ngày nghỉ và ngày chưa rõ. Bạn vẫn có thể Nhìn lại tuần.',
    ),
    (
      'Use a habit’s calendar for a particular day. These are records of your practice, not medical advice or a prediction.',
      'Dùng lịch của thói quen để xem ngày cụ thể. Đây là ghi chép việc bạn làm, không phải tư vấn y tế hay dự đoán.',
    ),
  ]),
  HabitHelpTopic('widgets', 'Home-screen widgets', 'Widget màn hình chính', [
    (
      'Settings → Home-screen widgets shows each widget as it will look: Today, One habit and Routine are free; This week and 16 weeks come with Pro. Add to home screen puts one there; or touch and hold an empty spot on the home screen → Widgets → Handy Habit.',
      'Cài đặt → Widget màn hình chính cho xem từng widget trông thế nào: Hôm nay, Một thói quen và Quy trình miễn phí; Tuần này và 16 tuần đi kèm Pro. Thêm vào màn hình chính để đặt ra ngoài; hoặc giữ chỗ trống trên màn hình chính → Widget → Handy Habit.',
    ),
    (
      'Tap a bead on the widget to check in without opening Habit: it fills at once and the day is saved a moment later. Counted habits add one per tap; minutes and amounts, a full day or a skipped day open Habit instead. Undo it in Habit if a tap was a mistake.',
      'Chạm một hạt trên widget để ghi nhận mà không cần mở Habit: hạt lấp ngay, ngày được lưu ngay sau đó. Thói quen đếm cộng một mỗi chạm; số phút và lượng, ngày đã đủ hay đã bỏ qua thì mở Habit. Chạm nhầm thì Hoàn tác trong Habit.',
    ),
    (
      'Widgets start a new day on their own after midnight. Choose the habit for One habit and 16 weeks, the routine, and whether names show, on the same Settings page. Mood and notes never appear on a widget. iOS, Windows and Web show previews only.',
      'Widget tự sang ngày mới sau nửa đêm. Chọn thói quen cho Một thói quen và 16 tuần, quy trình, và có hiện tên hay không ở cùng trang Cài đặt. Tâm trạng và ghi chú không bao giờ hiện trên widget. iOS, Windows và Web chỉ xem trước.',
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
  HabitHelpTopic('negative', 'Positive vs negative habits', 'Thói quen xây dựng và giảm bớt', [
    (
      'Choose Build a habit to reach a minimum, or Break a habit to count incidents against an upper limit. For example: at most 3 sugary drinks per day, or no smoking at all.',
      'Chọn Xây dựng thói quen để đạt tối thiểu, hoặc Giảm thói quen để ghi số lần so với giới hạn tối đa. Ví dụ: tối đa 3 lần uống nước ngọt mỗi ngày, hoặc không hút thuốc.',
    ),
    (
      'For a negative habit, tap today’s bead to log one incident, even beyond the limit. Undo retracts that entry. None today records an explicit zero; no record means unknown, never success.',
      'Với thói quen giảm bớt, chạm hạt hôm nay để ghi một lần, kể cả khi vượt giới hạn. Hoàn tác gỡ lần đó. Hôm nay không có ghi rõ số 0; không ghi là chưa rõ, không tự tính đạt.',
    ),
    (
      'A coloured bead means a recorded day within the limit; a neutral filled-outline mark means over the limit, and a hollow bead means unknown. Today stays provisional until the next habit day. Tomorrow is a fresh start.',
      'Hạt màu là ngày đã ghi trong giới hạn; dấu đầy có viền trung tính là vượt giới hạn, hạt rỗng là chưa rõ. Hôm nay chỉ tạm tính đến khi sang ngày thói quen tiếp theo. Mai là khởi đầu mới.',
    ),
    (
      'Weekly limits count incidents you recorded. When the week ends, blank days count as no incident; you do not need to log every day. Daily blank days stay unknown and are left out of consistency. Paused or skipped weeks earn no streak. Change a weekly limit from next week.',
      'Giới hạn tuần tính những lần bạn đã ghi. Khi hết tuần, ngày để trống được hiểu là không có lần nào; bạn không cần ghi mỗi ngày. Với giới hạn ngày, ngày để trống vẫn chưa rõ và không tính vào độ đều đặn. Tuần nghỉ hoặc bỏ qua không cộng chuỗi. Đổi giới hạn tuần từ tuần sau.',
    ),
    (
      'Open a date in history to correct the incident total, add a note, confirm none or return it to unknown. Negative habits cannot be linked to routine steps.',
      'Mở ngày trong lịch sử để sửa số lần, thêm ghi chú, xác nhận không có hoặc đưa về chưa rõ. Không liên kết thói quen giảm bớt với bước quy trình.',
    ),
  ]),
  HabitHelpTopic('mood', 'Mood', 'Tâm trạng', [
    (
      'After your habits on Today, tap How’s today?, then tap one of five feelings. That is all: no note or energy is required. Skip or Back saves nothing.',
      'Sau thói quen ở Hôm nay, chạm Hôm nay bạn thấy sao?, rồi chọn một trong năm cảm nhận. Vậy là xong: không cần ghi chú hay năng lượng. Bỏ qua hoặc Quay lại không lưu gì.',
    ),
    (
      'Add or edit details lets you choose optional energy (1–5), a note and up to 8 tags. Save commits the whole draft. Cancel keeps the old entry.',
      'Thêm hoặc sửa chi tiết cho phép chọn năng lượng tùy chọn (1–5), ghi chú và tối đa 8 nhãn. Lưu ghi toàn bộ bản nháp. Hủy giữ bản ghi cũ.',
    ),
    (
      'In Progress, mood history follows the selected week, month or year. Tap a dated entry to edit or delete. Undo reverses the last change; Deleted entries lets you restore later. Missing days are never filled in.',
      'Ở Tiến trình, lịch sử tâm trạng theo tuần, tháng hoặc năm đã chọn. Chạm bản ghi để sửa hoặc xóa. Hoàn tác đảo thay đổi cuối; Bản ghi đã xóa cho khôi phục sau. Không tự điền ngày trống.',
    ),
    (
      'Settings → Show mood on Today hides the prompt without deleting history. Notes stay in local data and backups/exports you choose. Mood never appears in notifications or home-screen widgets. This is a personal record, with no health claims or correlations.',
      'Cài đặt → Hiện tâm trạng ở Hôm nay ẩn lời nhắc mà không xóa lịch sử. Ghi chú nằm trong dữ liệu cục bộ và bản sao lưu/xuất bạn chọn. Tâm trạng không xuất hiện ở thông báo hay tiện ích màn hình chính. Đây là ghi chép cá nhân, không có khẳng định sức khỏe hay tương quan.',
    ),
  ]),
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
