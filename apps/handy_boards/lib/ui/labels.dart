import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:timezone/timezone.dart' as tz;
import 'error_catalog.dart';

String deadlineLabel(BuildContext context, Json deadline, String boardZone) {
  final localizations = MaterialLocalizations.of(context),
      date = DateTime.parse(deadlineDay(deadline, boardZone)),
      label = localizations.formatCompactDate(date);
  if (deadline['kind'] == 'day') return label;
  final local = tz.TZDateTime.from(
    DateTime.parse(deadline['at']),
    zone(boardZone),
  );
  return '$label · ${localizations.formatTimeOfDay(
    TimeOfDay(hour: local.hour, minute: local.minute),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  )} · $boardZone';
}

String priorityName(BuildContext context, int value) => [
  tr(context, 'Low', 'Thấp'),
  tr(context, 'Normal', 'Thường'),
  tr(context, 'High', 'Cao'),
  tr(context, 'Urgent', 'Khẩn'),
][value.clamp(0, 3)];

String priorityReason(BuildContext context, String reason) {
  if (reason.startsWith('priority:'))
    return '${tr(context, 'Priority', 'Ưu tiên')}: ${priorityName(context, int.tryParse(reason.substring(9)) ?? 1)}';
  if (reason.startsWith('category weight:'))
    return '${tr(context, 'Category boost', 'Điểm nhóm')}: ${reason.substring(16)}';
  if (reason.startsWith('due:')) {
    final days = int.tryParse(reason.substring(4).split(' ').first);
    if (days == 0) return tr(context, 'Due today', 'Đến hạn hôm nay');
    if (days != null)
      return tr(
        context,
        'Due in $days ${days == 1 ? 'day' : 'days'}',
        'Đến hạn sau $days ngày',
      );
  }
  return switch (reason) {
    'planned today' => tr(context, 'Planned today', 'Dự kiến hôm nay'),
    'pinned' => tr(context, 'Pinned', 'Đã ghim'),
    'blocked' => tr(
      context,
      'Blocked by unfinished work',
      'Bị chặn bởi việc chưa hoàn tất',
    ),
    'overdue' => tr(context, 'Overdue', 'Quá hạn'),
    'estimate<=30m' => tr(
      context,
      'Estimate at most 30 minutes',
      'Ước lượng tối đa 30 phút',
    ),
    _ => reason,
  };
}

String weekdayName(BuildContext context, int weekday) => [
  tr(context, 'Monday', 'Thứ Hai'),
  tr(context, 'Tuesday', 'Thứ Ba'),
  tr(context, 'Wednesday', 'Thứ Tư'),
  tr(context, 'Thursday', 'Thứ Năm'),
  tr(context, 'Friday', 'Thứ Sáu'),
  tr(context, 'Saturday', 'Thứ Bảy'),
  tr(context, 'Sunday', 'Chủ nhật'),
][(weekday - 1).clamp(0, 6)];

String boardsError(BuildContext context, Object error) {
  final raw = error is FormatException
      ? error.message
      : error.toString().replaceFirst(
          RegExp(r'^(FormatException|Bad state|StateError):\s*'),
          '',
        );
  final translated = <String, String>{
    ...boardsErrorVi,
    'Time falls in a DST gap':
        'Giờ này không tồn tại do đổi giờ mùa hè. Hãy chọn giờ khác.',
    'Ambiguous time: choose earlier or later':
        'Giờ này xuất hiện hai lần. Hãy chọn lần sớm hoặc lần muộn.',
    'Invalid time': 'Giờ không hợp lệ. Nhập HH:mm.',
    'HH:mm required': 'Nhập giờ theo dạng HH:mm.',
    'Invalid date': 'Ngày không hợp lệ.',
    'Choose due date first': 'Hãy chọn ngày hạn trước.',
    'Choose start date first': 'Hãy chọn ngày bắt đầu trước.',
    'Start follows due': 'Ngày bắt đầu phải trước hoặc bằng hạn.',
    'Invalid date range': 'Khoảng ngày không hợp lệ.',
    'Reversed date range':
        'Ngày bắt đầu khoảng phải trước hoặc bằng ngày kết thúc.',
    'Invalid estimate range': 'Khoảng ước lượng không hợp lệ.',
    'Reversed estimate range':
        'Ước lượng tối thiểu phải nhỏ hơn hoặc bằng tối đa.',
    'Estimate 0..525600': 'Ước lượng phải từ 0 đến 525600 phút.',
    'Preview 0..3': 'Số task xem trước phải từ 0 đến 3.',
    'Priority boost 0..1000': 'Điểm ưu tiên nhóm phải từ 0 đến 1000.',
    'Invalid priority weight': 'Trọng số phải là số từ 0 đến 1000.',
    'Invalid score weight': 'Trọng số phải là số từ 0 đến 1000.',
    'Capacity positive': 'Năng lực mỗi ngày phải lớn hơn 0.',
    'Capacity must be positive': 'Năng lực mỗi ngày phải lớn hơn 0.',
    'Exam duration 1..1440 minutes': 'Thời lượng thi phải từ 1 đến 1440 phút.',
    'Invalid target/credits':
        'Mục tiêu phải từ 0 đến 100; số tín chỉ không được âm.',
    'Use one grade per line: A = 90':
        'Nhập mỗi ngưỡng điểm trên một dòng, ví dụ A = 90.',
    'Unique labels/thresholds between 0 and 100 required':
        'Nhãn và ngưỡng điểm không được trùng; ngưỡng phải từ 0 đến 100.',
    'Define your own letter thresholds':
        'Hãy nhập bảng ngưỡng điểm chữ của bạn.',
    'Cannot decode image': 'Không đọc được ảnh. Hãy chọn ảnh khác.',
    'Static JPEG/PNG/WebP up to 16 MP required':
        'Chọn ảnh tĩnh JPEG, PNG hoặc WebP tối đa 16 megapixel.',
    'Image exceeds 12 MB': 'Ảnh không được vượt quá 12 MB.',
    'Backup exceeds 30 MB':
        'Bản sao lưu vượt 30 MB. Hãy giảm số tệp trước khi xuất.',
    'Backup exceeds portable bounds':
        'Bản sao lưu vượt giới hạn dung lượng hoặc số tệp.',
    'Backup checksum mismatch':
        'Bản sao lưu bị hỏng hoặc đã thay đổi; mã kiểm tra không khớp.',
    'Attachment checksum mismatch':
        'Tệp đính kèm bị thiếu hoặc không khớp mã kiểm tra.',
    'Template checksum/size mismatch': 'Gói mẫu bị hỏng hoặc sai dung lượng.',
    'Unsupported template': 'Phiên bản mẫu không được hỗ trợ.',
    'Incomplete backup': 'Bản sao lưu thiếu tệp bắt buộc.',
    'Unsupported manifest': 'Phiên bản bản sao lưu không được hỗ trợ.',
    'Restore requires confirmation': 'Cần xác nhận trước khi khôi phục.',
    'Review template first': 'Hãy kiểm tra mẫu trước khi nhập.',
    'Set at least one bound': 'Hãy nhập ít nhất một giới hạn.',
    'Set both dates first': 'Hãy đặt cả ngày bắt đầu và hạn trước.',
    'Move at most 366 days': 'Mỗi lần chỉ được dời tối đa 366 ngày.',
    'Data changed during preview':
        'Dữ liệu đã thay đổi khi xem trước. Hãy kiểm tra lại.',
    'Data changed during preview. Review again.':
        'Dữ liệu đã thay đổi khi xem trước. Hãy kiểm tra lại.',
    'At most ten automation actions': 'Mỗi quy tắc tối đa 10 hành động.',
    'Reminder offset 1..525600 minutes':
        'Khoảng nhắc phải từ 1 đến 525600 phút.',
    'Another session is running': 'Đang có một phiên tập trung khác chạy.',
    'Invalid work duration': 'Thời lượng làm việc không hợp lệ.',
    'Invalid assessment weight/score':
        'Trọng số phải từ 0 đến 100; điểm tối đa phải lớn hơn 0; điểm đạt phải nằm trong thang điểm.',
    'Weights must total 100; explicit normalization required otherwise':
        'Tổng trọng số phải bằng 100%. Hoặc bật chuẩn hóa trọng số trong thông tin môn.',
    'Target must be 0..100': 'Mục tiêu phần trăm phải từ 0 đến 100.',
    'Configure a matching workflow status first':
        'Hãy cấu hình trạng thái hoàn tất hoặc chưa hoàn tất phù hợp trước.',
  };
  String? dynamicTranslation;
  if (raw.startsWith('Invalid integer field: '))
    dynamicTranslation = 'Trường số nguyên không hợp lệ: ${raw.substring(23)}';
  if (raw.startsWith('Invalid boolean field: '))
    dynamicTranslation = 'Trường bật/tắt không hợp lệ: ${raw.substring(23)}';
  if (raw.startsWith('Missing ') && raw.endsWith(' record')) {
    final kind = raw.substring(8, raw.length - 7);
    dynamicTranslation =
        'Thiếu bản ghi liên kết ($kind). Hãy kiểm tra tệp nhập hoặc khôi phục sao lưu.';
  }
  return tr(context, raw, translated[raw] ?? dynamicTranslation ?? raw);
}
