/// Errors owned by Boards. OS/plugin diagnostics retain a localized context in
/// labels.dart; we never replace an unknown failure with a fabricated success.
const boardsErrorVi = <String, String>{
  'Preview cancelled / Đã hủy xem trước. Nothing saved / Chưa lưu thay đổi.':
      'Đã hủy xem trước. Chưa lưu thay đổi.',
  'Another tab changed Boards data; reload':
      'Thẻ trình duyệt khác đã sửa dữ liệu. Hãy tải lại.',
  'Another writer changed Boards; reload':
      'Dữ liệu đã được sửa ở phiên khác. Hãy tải lại.',
  'App-open batch limit 1..500': 'Mỗi lần mở chỉ xử lý từ 1 đến 500 mục.',
  'At most 100 resource calendars': 'Tối đa 100 lịch nguồn lực.',
  'At most 100 tags per task': 'Mỗi công việc tối đa 100 nhãn.',
  'At most 3660 holidays': 'Tối đa 3660 ngày nghỉ.',
  'Automation batch exceeds fifty rules':
      'Mỗi đợt tự động hóa tối đa 50 quy tắc.',
  'Automation scope mismatch': 'Quy tắc không thuộc phạm vi bảng này.',
  'Backup exceeds 10000 entries': 'Sao lưu vượt 10000 tệp.',
  'Backup metadata exceeds 100 MB': 'Dữ liệu mô tả sao lưu vượt 100 MB.',
  'Board exists': 'Bảng đã tồn tại.',
  'Boards data unavailable': 'Chưa truy cập được dữ liệu bảng.',
  'Boards storage unavailable': 'Chưa truy cập được bộ lưu trữ bảng.',
  'Boolean condition required': 'Điều kiện phải là giá trị bật hoặc tắt.',
  'Boolean required': 'Giá trị phải là bật hoặc tắt.',
  'Browser asset quota exceeded; library preserved':
      'Trình duyệt không còn đủ chỗ lưu tệp. Thư viện hiện tại được giữ nguyên.',
  'Browser page read aborted': 'Đã ngắt đọc trang dữ liệu trình duyệt.',
  'Browser quota/transaction failure; previous data preserved':
      'Hết dung lượng hoặc giao dịch trình duyệt thất bại. Dữ liệu trước đó được giữ nguyên.',
  'Browser read aborted': 'Đã ngắt đọc dữ liệu trình duyệt.',
  'Browser search aborted': 'Đã ngắt tìm kiếm trong trình duyệt.',
  'Browser storage unavailable; existing data preserved':
      'Không truy cập được bộ nhớ trình duyệt. Dữ liệu hiện có được giữ nguyên.',
  'CSV exceeds 3 MB': 'CSV vượt 3 MB.',
  'CSV exceeds 50000 rows': 'CSV vượt 50000 dòng.',
  'CSV requires original board dictionaries and nonconflicting task IDs; use full ZIP for another device':
      'CSV này cần danh mục gốc của bảng và ID không trùng. Dùng sao lưu ZIP đầy đủ để chuyển thiết bị.',
  'Category board mismatch': 'Nhóm không thuộc bảng này.',
  'Category priority boost 0..1000': 'Điểm ưu tiên nhóm phải từ 0 đến 1000.',
  'Checkbox default: true or false':
      'Giá trị mặc định của ô chọn phải là true hoặc false.',
  'Choose another category': 'Hãy chọn một nhóm khác.',
  'Clock changed or session over 24h; review duration':
      'Đồng hồ đã thay đổi hoặc phiên vượt 24 giờ. Hãy kiểm tra thời lượng.',
  'Close other Boards tabs and retry':
      'Đóng các thẻ Handy Boards khác rồi thử lại.',
  'Custom field board mismatch': 'Trường tùy chỉnh không thuộc bảng này.',
  'Cycle detected': 'Phát hiện vòng phụ thuộc. Hãy bỏ liên kết tạo vòng.',
  'Data changed during review; import again':
      'Dữ liệu đã đổi trong lúc kiểm tra. Hãy nhập lại.',
  'Days 0..3650': 'Số ngày phải từ 0 đến 3650.',
  'Decimal string required': 'Hãy nhập một số thập phân hợp lệ.',
  'Destination already exists': 'Tệp đích đã tồn tại. Hãy chọn tên khác.',
  'Duplicate Trello IDs': 'Tệp Trello chứa ID trùng.',
  'Duplicate choices': 'Các lựa chọn không được trùng nhau.',
  'Duplicate record ID': 'ID bản ghi bị trùng.',
  'Duplicate template IDs': 'Mẫu chứa ID trùng.',
  'Duration 0..525600 minutes': 'Thời lượng phải từ 0 đến 525600 phút.',
  'Edited display columns conflict with canonical CSV payload; use mapped CSV instead':
      'Cột đã sửa không khớp dữ liệu gốc trong CSV. Hãy dùng nhập CSV có ánh xạ cột.',
  'Empty CSV': 'Tệp CSV không có dữ liệu.',
  'Explicit confirmation required': 'Bạn cần xác nhận rõ trước khi tiếp tục.',
  'Export cancelled; no data changed': 'Đã hủy xuất. Dữ liệu không thay đổi.',
  'Export worker stopped before completion':
      'Tiến trình xuất đã dừng trước khi hoàn tất.',
  'Focus segments exceed saved duration':
      'Các đoạn tập trung vượt thời lượng đã lưu.',
  'HTTP(S) URL required': 'Chỉ chấp nhận liên kết HTTP hoặc HTTPS.',
  'History window 1..366 days': 'Khoảng lịch sử phải từ 1 đến 366 ngày.',
  'IDs must be globally unique across kinds':
      'ID phải duy nhất giữa mọi loại bản ghi.',
  'Immutable SQL snapshot': 'Không thể sửa trực tiếp ảnh chụp dữ liệu SQLite.',
  'Immutable assets': 'Không thể sửa trực tiếp nguồn tệp bất biến.',
  'Immutable changes': 'Không thể sửa trực tiếp tập thay đổi đã chốt.',
  'Immutable import': 'Không thể sửa trực tiếp dữ liệu nhập đã kiểm tra.',
  'Immutable snapshot': 'Không thể sửa trực tiếp ảnh chụp dữ liệu.',
  'Import exceeds 512 MB': 'Tệp nhập vượt 512 MB.',
  'Import worker stopped': 'Tiến trình nhập đã dừng.',
  'Incomplete snapshot': 'Ảnh chụp dữ liệu thiếu bộ sưu tập bắt buộc.',
  'Incomplete task CSV row': 'Dòng công việc CSV thiếu thông tin.',
  'Index migration failed; library preserved':
      'Nâng cấp chỉ mục thất bại. Thư viện được giữ nguyên.',
  'Invalid activity retention': 'Thời hạn giữ lịch sử không hợp lệ.',
  'Invalid category or parent': 'Nhóm hoặc công việc cha không hợp lệ.',
  'Invalid choices': 'Danh sách lựa chọn không hợp lệ.',
  'Invalid class session': 'Buổi học không hợp lệ.',
  'Invalid collapsed category preferences':
      'Cấu hình thu gọn nhóm không hợp lệ.',
  'Invalid deadline': 'Hạn công việc không hợp lệ.',
  'Invalid dependency': 'Liên kết phụ thuộc không hợp lệ.',
  'Invalid display preference': 'Cấu hình hiển thị không hợp lệ.',
  'Invalid extension': 'Phần mở rộng tệp không hợp lệ.',
  'Invalid focus segment': 'Đoạn thời gian tập trung không hợp lệ.',
  'Invalid instant': 'Mốc thời gian không hợp lệ.',
  'Invalid letter threshold': 'Ngưỡng điểm chữ không hợp lệ.',
  'Invalid local day boundary': 'Mốc ngày địa phương không hợp lệ.',
  'Invalid managed asset': 'Tệp được quản lý không hợp lệ.',
  'Invalid preferences': 'Cấu hình ứng dụng không hợp lệ.',
  'Invalid priority': 'Mức ưu tiên không hợp lệ.',
  'Invalid priority/estimate': 'Mức ưu tiên hoặc ước lượng không hợp lệ.',
  'Invalid recurrence': 'Quy tắc lặp không hợp lệ.',
  'Invalid recurrence count': 'Số lần lặp không hợp lệ.',
  'Invalid reorder': 'Thứ tự sắp xếp không hợp lệ.',
  'Invalid revision': 'Phiên bản dữ liệu không hợp lệ.',
  'Invalid smart view': 'Chế độ xem đã lưu không hợp lệ.',
  'Invalid table columns': 'Cấu hình cột bảng không hợp lệ.',
  'Invalid template package': 'Gói mẫu không hợp lệ.',
  'Invalid text': 'Nội dung văn bản không hợp lệ hoặc quá dài.',
  'Invalid weekday': 'Ngày trong tuần không hợp lệ.',
  'Large imports require a ZIP backup': 'Tệp lớn cần dùng bản sao lưu ZIP.',
  'Malformed CSV': 'Cấu trúc CSV không hợp lệ.',
  'Managed assets exceed 300 MB': 'Tổng tệp đính kèm vượt 300 MB.',
  'Manifest entry mismatch': 'Danh sách tệp không khớp bản kê sao lưu.',
  'Map a title column': 'Hãy chọn cột tên công việc.',
  'Missing asset': 'Thiếu tệp đính kèm.',
  'Missing manifest': 'Thiếu bản kê sao lưu.',
  'Missing mapped cell': 'Dòng CSV thiếu ô đã ánh xạ.',
  'Missing recurring template task': 'Thiếu công việc gốc của quy tắc lặp.',
  'Missing template checklist task':
      'Mục kiểm tra của mẫu thiếu công việc cha.',
  'Missing template parent': 'Mẫu thiếu công việc cha.',
  'Move linked dependencies together or remove links first':
      'Hãy chuyển cùng các công việc phụ thuộc hoặc bỏ liên kết trước.',
  'Move to trash first': 'Hãy đưa vào thùng rác trước.',
  'Native staged import unavailable':
      'Nền tảng này chưa hỗ trợ nhập tệp lớn theo luồng.',
  'Native streaming export is unavailable':
      'Nền tảng này chưa hỗ trợ xuất trực tiếp theo luồng.',
  'Newer Boards schema; database preserved':
      'Dữ liệu thuộc phiên bản ứng dụng mới hơn. Database được giữ nguyên.',
  'No Redo': 'Không có thao tác để làm lại.',
  'No Undo': 'Không có thao tác để hoàn tác.',
  'Nonnegative limit required': 'Giới hạn không được âm.',
  'Not a supported Trello board export':
      'Đây không phải tệp xuất bảng Trello được hỗ trợ.',
  'Notification ID collision':
      'ID thông báo bị trùng. Hãy kiểm tra lại lời nhắc.',
  'Notification permission denied; in-app reminders retained':
      'Chưa được cấp quyền thông báo. Lời nhắc trong ứng dụng vẫn được giữ.',
  'Object required': 'Dữ liệu cần có cấu trúc đối tượng JSON.',
  'Operation cancelled; existing data preserved':
      'Đã hủy thao tác. Dữ liệu hiện có được giữ nguyên.',
  'PDF is streamed to disk': 'PDF đang được ghi trực tiếp vào tệp.',
  'PDF limited to 1000 selected tasks':
      'PDF trong trình duyệt giới hạn 1000 công việc đã chọn.',
  'Page revision changed; reload': 'Dữ liệu trang đã đổi. Hãy tải lại.',
  'Page size 1..500': 'Mỗi trang phải từ 1 đến 500 công việc.',
  'Pause current session first': 'Hãy tạm dừng phiên đang chạy trước.',
  'Percentage out of bounds': 'Phần trăm nằm ngoài giới hạn.',
  'Permanent deletion requires confirmation':
      'Xóa vĩnh viễn cần được xác nhận.',
  'Position out of range': 'Vị trí nằm ngoài phạm vi.',
  'Priority 0..3': 'Mức ưu tiên phải từ 0 đến 3.',
  'Reconcile 1..100 rules per batch': 'Mỗi đợt xử lý từ 1 đến 100 quy tắc.',
  'Recurrence end before start':
      'Ngày kết thúc lặp phải sau hoặc bằng ngày bắt đầu.',
  'Recurrence horizon too large':
      'Khoảng tạo lần lặp quá lớn. Hãy thu hẹp khoảng ngày.',
  'Recurrence status mismatch': 'Trạng thái của quy tắc lặp không khớp.',
  'Recurring rule board mismatch': 'Quy tắc lặp không thuộc bảng này.',
  'Reminder must be in future': 'Lời nhắc phải ở tương lai.',
  'Reorder scope mismatch': 'Chỉ sắp xếp lại các mục trong cùng phạm vi.',
  'Retention must be 0..3650 days': 'Thời hạn lưu phải từ 0 đến 3650 ngày.',
  'Review Trello mapping first': 'Hãy kiểm tra ánh xạ Trello trước.',
  'Review an active session with 0..86400 additional seconds':
      'Kiểm tra phiên đang chạy; số giây bổ sung phải từ 0 đến 86400.',
  'Review required': 'Cần kiểm tra dữ liệu trước khi tiếp tục.',
  'Select a destination board first': 'Hãy chọn bảng đích trước.',
  'Select at least one unique working weekday':
      'Hãy chọn ít nhất một ngày làm việc; không chọn trùng.',
  'Share remains queued; saved data preserved':
      'Nội dung chia sẻ vẫn nằm trong hàng chờ. Dữ liệu đã lưu được giữ nguyên.',
  'Smart view scope mismatch': 'Chế độ xem đã lưu không thuộc bảng này.',
  'Status is outside task board': 'Trạng thái không thuộc bảng của công việc.',
  'Status outside board': 'Trạng thái không thuộc bảng này.',
  'Stored file checksum mismatch': 'Mã kiểm tra tệp đã lưu không khớp.',
  'Study PDF limited to 1000 tasks and 100 categories; narrow the board before exporting':
      'PDF học tập giới hạn 1000 công việc và 100 nhóm. Hãy thu hẹp bảng trước khi xuất.',
  'Subtask depth exceeds 32': 'Công việc con vượt 32 cấp.',
  'Suggested status outside board': 'Trạng thái gợi ý không thuộc bảng này.',
  'Tag board mismatch': 'Nhãn không thuộc bảng này.',
  'Task board mismatch': 'Công việc không thuộc bảng này.',
  'Template bounds': 'Mẫu vượt giới hạn số bản ghi.',
  'Template checklist bounds': 'Danh sách kiểm tra của mẫu vượt giới hạn.',
  'Template exceeds 3 MB': 'Mẫu vượt 3 MB.',
  'Template field/recurrence bounds':
      'Trường tùy chỉnh hoặc quy tắc lặp của mẫu vượt giới hạn.',
  'Text exceeds 3 MB': 'Văn bản vượt 3 MB.',
  'Timezone offset required': 'Mốc thời gian cần có độ lệch múi giờ.',
  'Too many occurrences; choose a smaller horizon':
      'Quá nhiều lần lặp. Hãy chọn khoảng ngày ngắn hơn.',
  'Too many tasks': 'Số công việc vượt giới hạn.',
  'Trello board exceeds import bounds': 'Bảng Trello vượt giới hạn nhập.',
  'Trello card references a missing list':
      'Thẻ Trello tham chiếu danh sách bị thiếu.',
  'Trello checklist exceeds bounds': 'Danh sách kiểm tra Trello vượt giới hạn.',
  'Trello checklist references a missing card':
      'Danh sách kiểm tra Trello tham chiếu thẻ bị thiếu.',
  'Unable to read browser asset':
      'Không đọc được tệp đã lưu trong trình duyệt.',
  'Unexpected text after quoted field':
      'CSV có nội dung thừa sau ô đặt trong dấu ngoặc kép.',
  'Unknown choice': 'Lựa chọn không được định nghĩa.',
  'Unknown collection or duplicate ID':
      'Bộ sưu tập không được hỗ trợ hoặc ID bị trùng.',
  'Unknown completed Trello list':
      'Danh sách Trello được chọn hoàn tất không tồn tại.',
  'Unknown format': 'Định dạng không được hỗ trợ.',
  'Unknown template': 'Mẫu không tồn tại.',
  'Unknown template category': 'Nhóm của mẫu không tồn tại.',
  'Unknown trigger': 'Sự kiện kích hoạt không được hỗ trợ.',
  'Unknown/ambiguous status': 'Trạng thái không tồn tại hoặc trùng tên.',
  'Unsafe or duplicate ZIP path': 'ZIP có đường dẫn không an toàn hoặc trùng.',
  'Unsupported Boards schema':
      'Phiên bản dữ liệu Handy Boards không được hỗ trợ.',
  'Unsupported Handy Boards CSV columns':
      'Các cột CSV Handy Boards không được hỗ trợ.',
  'Unsupported action': 'Hành động không được hỗ trợ.',
  'Unsupported custom field': 'Loại trường tùy chỉnh không được hỗ trợ.',
  'Unsupported or oversized ZIP directory':
      'Mục lục ZIP không được hỗ trợ hoặc quá lớn.',
  'Unsupported presentation scale': 'Thang điểm hiển thị không được hỗ trợ.',
  'Unsupported saved view layout':
      'Bố cục chế độ xem đã lưu không được hỗ trợ.',
  'Unsupported task filter': 'Bộ lọc công việc không được hỗ trợ.',
  'Unsupported value': 'Giá trị không được hỗ trợ.',
  'Unterminated CSV quote': 'CSV thiếu dấu ngoặc kép kết thúc.',
  'Use asynchronous readFile for browser assets':
      'Tệp trình duyệt cần được đọc bất đồng bộ.',
  'Use explicit move across boards':
      'Hãy dùng thao tác chuyển bảng để giữ liên kết dữ liệu.',
  'View condition limit': 'Số điều kiện lọc vượt giới hạn.',
  'Working calendar exceeds scheduling horizon':
      'Lịch làm việc vượt khoảng tính toán được hỗ trợ.',
  'Working hours must fit within one day':
      'Giờ bắt đầu và thời lượng làm việc phải nằm trong cùng một ngày.',
  'XLSX exceeds 50000 tasks': 'XLSX vượt 50000 công việc.',
  'ZIP CRC mismatch': 'Tệp trong ZIP bị hỏng; mã CRC không khớp.',
  'ZIP compression ratio exceeds bounds':
      'Tỷ lệ nén ZIP vượt giới hạn an toàn.',
  'ZIP entry size mismatch':
      'Dung lượng thực tế của tệp ZIP không khớp khai báo.',
  'ZIP expanded size exceeds bounds': 'Dung lượng giải nén ZIP vượt giới hạn.',
  'ZIP expansion exceeds declared limit':
      'Tệp giải nén lớn hơn dung lượng đã khai báo.',
  'ZIP source must be 22 bytes..512 MB': 'Tệp ZIP phải từ 22 byte đến 512 MB.',
};
