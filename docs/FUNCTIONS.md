# Handy Suite Flutter functions

## Handy Trip

- **Xưởng làm tem** (từ Hộ chiếu, mỗi lượt ghé đã xác nhận): cắt ảnh của lượt ghé hoặc ảnh bìa chuyến thành tem tròn, bầu dục, răng cưa hay nhãn; kéo hoặc dùng phím mũi tên để chỉnh vị trí ảnh, phóng to 1–3×; ảnh chuyển sang hai tông màu mực (5 màu); chữ chạy theo vòng tem (địa điểm, ngày, có thể kèm tên chuyến); nghiêng ±12°, độ mòn mực cố định theo lượt ghé. Xuất PNG nền trong 1200 px hoặc tờ A4 12 tem (PDF). Không chứa vị trí chính xác hay metadata ảnh; mẫu dấu cũ (`exportPersonalStamp`) vẫn giữ.

App độc lập thứ mười: lên lịch, ghi nhận đã ghé và lưu kỷ niệm du lịch offline.
[Trạng thái kiểm chứng](handy_trip/FEATURE_MATRIX.md).

- Chuyến đi có ngày bắt đầu/kết thúc, múi giờ IANA, trạng thái, ảnh bìa, ngân sách.
  Lịch từng ngày: thêm/sửa/xóa, kéo sắp xếp, giờ tùy chọn, qua đêm, cảnh báo trùng giờ.
  Nhân bản lịch và hành lý không sao chép booking, chi tiêu hoặc lượt ghé cũ.
- Địa điểm, wishlist, yêu thích, nhãn địa lý do người dùng xác nhận, link HTTP(S),
  dán clipboard, nhận link/văn bản từ Android/iOS share inbox. Không lấy vị trí
  từ nội dung mạng xã hội hay tự đánh dấu đã ghé. Nhập CSV có chọn cột, GeoJSON,
  GPX/KML chỉ nhận điểm; không tạo đường GPS giả.
- Check-in thủ công không cần GPS; GPS chỉ lấy một lần theo thao tác, xem tọa độ,
  độ chính xác và thời điểm trước khi xác nhận. Quyền bị từ chối có lựa chọn thủ công.
  Lượt ghé lặp lại và số địa điểm duy nhất được tính riêng; giữ múi giờ lịch sử.
- Nhật ký theo chuyến/ngày/địa điểm, ghi chú, ảnh và album; zoom, chuyển ảnh, chú
  thích. Ảnh gốc được sao chép vào app, thumbnail tạo riêng. Gỡ ảnh không xóa thư viện.
- Đặt chỗ có mã riêng được che trong danh sách, ảnh/PDF đính kèm; hành lý theo
  nhóm, số lượng, thứ tự, mẫu địa phương có thể sửa và tiến độ từng chuyến.
- Chi tiêu bằng số nguyên đơn vị nhỏ nhất, người trả, nhóm, hóa đơn; mỗi tiền tệ
  tính riêng. Chi phí booking không tự cộng vào expense. Không tự đồng bộ Handy Spend.
- Nhắc cục bộ tùy chọn Android/iOS; danh sách nhắc trong app và ICS là fallback
  cho Windows/Web. Không hứa OS luôn giao thông báo chính xác khi tắt app.
- JSON/ZIP đầy đủ, manifest/hash/counts, assets tương đối, preview, merge/replace,
  transaction và Undo. Giới hạn bảo vệ: 30 MB/gói, 998 payload entries, có chọn chuyến/ngày.
  CSV riêng tư lossless; CSV/JSON lịch trình có schema; ICS giới hạn trường.
- Bản chia sẻ JSON/Markdown/PDF/ICS bỏ mã booking, ghi chú riêng và GPS chính xác;
  ZIP album tái mã hóa bỏ EXIF/tên tệp riêng. Nhật ký Markdown/JSON riêng tư và backup
  giữ dữ liệu cá nhân, có xác nhận rõ trước khi xuất. Người dùng cần kiểm tra nội dung ảnh.
- SQLite native/IndexedDB Web riêng; Ads + Pro Lifetime dùng adapter chung, ID riêng.
  Chưa có tài khoản store/AdMob thật; không giả giá hoặc quyền Pro.
- Passport có ảnh và thống kê lượt ghé/địa điểm; stamp cá nhân PNG/PDF không phải
  giấy tờ chính thức. Memory Book PDF/HTML ZIP theo ngày hoặc contact sheet;
  ghi chú riêng, caption và chi tiêu chỉ xuất khi chọn. Ảnh xuất bỏ EXIF.
- Gợi ý EXIF đọc cục bộ, hiển thị cảnh báo giờ/GPS, chỉ tạo lượt ghé qua form xác
  nhận hiện có. Replay nối các điểm đã lưu để minh họa, không phải tuyến đã đi.
- So sánh chuyến đã bỏ (2026-11-03): ít người dùng; Hộ chiếu đã cho số lượt ghé
  và địa điểm. Pro thêm kiểu stamp và contact sheet. Recipe lịch trình JSON không chứa lịch sử/chi tiêu.

Các tính năng native iOS là source chưa được build/kiểm thử trên macOS; không coi
build Android/Windows/Web hay ảnh widget là bằng chứng thiết bị thật.

## Handy Habit

- **Nhìn lại tuần**: từ ngày cuối tuần tới hai ngày sau, Hôm nay có một dòng mở trang nhìn lại (Thống kê có nút mở bất cứ lúc nào). Trang nêu số lần giữ được trên số lần đến hạn, so với tuần trước nữa, ngày trong tuần hay bị lỡ nhất (khi lỡ từ 2 lần trở lên), và chuỗi hạt 7 ngày của từng thói quen; thói quen giữ chưa được một nửa có nút "Làm nhỏ lại" mở trình sửa. Không lưu thêm dữ liệu.

Theo dõi hành vi lặp lại và chạy quy trình cá nhân nhiều bước; không thay Recall,
Keep, Spend hoặc timer đa dụng. [Trạng thái kiểm chứng](handy_habit/FEATURE_MATRIX.md).

- Thói quen: tạo/sửa, sắp xếp, tìm/lọc/nhóm, nhân bản, archive/unarchive, xác nhận
  xóa. Binary, count, thời lượng và lượng có đơn vị; mục tiêu, ghi chú, icon/màu/ưu tiên.
- Lịch hằng ngày, chọn thứ, số ngày/tuần, mỗi N ngày; ngày bắt đầu/kết thúc, phiên
  bản lịch có ngày hiệu lực. Đổi lịch không xóa hoặc dời check-in cũ.
- Check-in nhanh, sửa tổng ngày và backfill có giới hạn, ghi chú/bỏ qua, Undo.
  Streak hiện tại/dài nhất theo ngày có lịch hoặc tuần đạt quota; không tính ngày
  bỏ qua thành thành công hoặc coi kỳ còn mở là thất bại. Lịch sử, calendar, xu
  hướng tuần/tháng và ngày có lịch tiếp theo.
- Kỳ nghỉ: khoảng ngày (tối đa 366 ngày, bắt đầu không sớm hơn khoảng ghi bù) với
  lý do tùy chọn, cho mọi thói quen hoặc vài thói quen; thêm từ menu Thêm hoặc menu
  thói quen, sửa/kết thúc sớm/xóa trong Cài đặt. Ngày nghỉ chưa làm không là lỡ,
  không đứt chuỗi, không vào mẫu số; ngày nghỉ vẫn làm thì vẫn tính. Quota tuần =
  làm tròn lên quota × (7 − ngày nghỉ)/7, tuần nghỉ trọn thì bỏ qua. Không nhắc trong
  kỳ nghỉ (kỳ nghỉ cho mọi thói quen tắt cả nhắc quy trình). Hôm nay hiện "Đang nghỉ
  đến …" và Kết thúc sớm; hạt ngày nghỉ là đĩa nhạt.
- Quy trình: template offline có thể sửa, builder kéo/sắp bước, thời lượng/tối
  thiểu/ưu tiên, bước bắt buộc/tùy chọn, liên kết lượng vào habit. Phiên lưu bản
  kế hoạch riêng; sửa template không làm đổi lịch sử.
- Runner: timer tiền cảnh, hoàn thành thủ công, pause/resume, bước trước/sau,
  skip, thêm thời gian, ghi chú, auto-next tùy chọn, kết thúc/dừng và tổng kết.
  Mở lại phiên sẽ khôi phục ở trạng thái tạm dừng; không hứa timer chính xác khi tắt app.
  Android/iOS: rời app khi đang ở màn chạy thì phiên vẫn tạm dừng và một thông báo im
  lặng nói "Bước 3/5 · Đã tạm dừng · còn 2:00" (không đếm ngược); chạm mở `/run/<id>`,
  vào lại/xong/dừng thì gỡ. Chỉ khi công tắc riêng bật, đã có quyền và ngoài giờ yên lặng.
- Hoàn thành bước liên kết ghi tiến độ cùng transaction, không ghi hai lần do
  thao tác cũ. Undo chỉ gỡ event còn nguyên của bước; dừng phiên giữ check-in đã hoàn thành.
- Routine Lite (rút gọn quy trình theo số phút) đã bỏ ngày 2026-11-03: Runner đã
  cho bỏ qua hay hoàn thành từng bước. Biến thể Lite đã lưu là quy trình bình thường.
- Insights: khoảng ngày, habit, nhóm, routine; mẫu số cơ hội hợp lệ, phiên hoàn
  thành và thời gian dự kiến/thực tế, không chấm điểm năng suất tùy tiện.
- Nhắc cục bộ Android/iOS: quyền chỉ xin khi bật, giờ yên lặng, chọn thứ, snooze,
  preview, hủy khi tắt/xóa. Windows/Web dùng danh sách đến hạn trong app.
- SQLite native/IndexedDB Web, integrity check, schema version, bảo vệ ghi đồng
  thời. JSON/ZIP full backup miễn phí, preview merge/replace, đổi ID khi merge,
  checksum và rollback. CSV log nhập/xuất (kèm bảng kỳ nghỉ thứ hai khi có);
  Markdown/PDF báo cáo EN/VI có khoảng ngày, liệt kê kỳ nghỉ. Schema dữ liệu 2.
- EN/VI, sáng/tối, bốn tab mobile/rail màn hình rộng, bàn phím và UI kit dùng chung.
  Ads + Pro Lifetime dùng adapter thật; Pro bỏ ads được hỗ trợ.

Schema/CSV và chính sách dữ liệu: [DATA_SCHEMA](handy_habit/DATA_SCHEMA.md).
Giới hạn nền tảng: [PLATFORM_CAPABILITIES](handy_habit/PLATFORM_CAPABILITIES.md).

Eight independent local-first Flutter apps. Current code/test status: [FEATURE_MATRIX](../FEATURE_MATRIX.md).
Known limits: [KNOWN_ISSUES](../KNOWN_ISSUES.md). Screenshots: [UI_REVIEW](UI_REVIEW.md).

## Handy Spend

- **Ghi bằng một dòng** (Hôm nay): gõ "cà phê 45k", "45.000 bánh mì", "tiền nhà 1tr2" hoặc "+5 triệu lương" rồi Enter. Số có đơn vị (k, tr, triệu, nghìn) hay có dấu nhóm được ưu tiên, nếu không thì lấy số cuối; dấu + là khoản thu. Chữ còn lại thành người nhận; danh mục lấy theo quy tắc rồi theo lần trước cùng chữ đó; tài khoản là tài khoản dùng gần nhất. Dòng xem trước đọc lại cách hiểu trước khi lưu; lưu xong có Hoàn tác.

Theo dõi tài chính offline và thử quyết định trong Financial Sandbox. Trạng thái
kiểm chứng từng nhóm nằm trong [matrix riêng](handy_spend/FEATURE_MATRIX.md).

- Tài khoản tiền mặt, ngân hàng, ví, tiết kiệm, thẻ tín dụng, khoản vay và loại khác;
  số dư đầu kỳ/ngày hiệu lực, đối chiếu bằng giao dịch điều chỉnh, lưu trữ tài khoản.
- Thu, chi, chuyển khoản liên kết nguyên tử, điều chỉnh và hoàn tiền có tham chiếu;
  posted/pending tách biệt, ghi chú, tags, đối tác, sửa/xóa và Undo có audit.
- Tiền dùng BigInt theo đơn vị nhỏ nhất; hỗ trợ VND/JPY không có số lẻ, các loại tiền
  hai hoặc ba số lẻ. Chuyển khác tiền cần tỷ giá nhập tay và quy tắc làm tròn rõ ràng.
- Lịch sử tìm kiếm/lọc theo kỳ, tài khoản, danh mục, loại, trạng thái, nhãn và số tiền;
  chọn nhiều để xóa/xuất. Desktop có bảng kéo đổi độ rộng cột và Ctrl+N/F/I/Z.
  Giao dịch thu/chi/chuyển khoản có thể dùng làm mẫu mới qua menu lịch sử; phải duyệt
  và lưu, không sửa bản gốc hay sao chép liên kết import/lịch định kỳ. Danh mục gần
  đây được đưa lên đầu danh sách chọn.
- Danh mục cha/con, màu/biểu tượng và lưu trữ; ngân sách kỳ tháng/tùy chỉnh,
  tùy chọn chuyển số dư một kỳ; báo cáo thu/chi, danh mục, xu hướng, biến động tài khoản,
  chênh lệch ngân sách và tài sản ròng tách theo tiền tệ.
- Safe to Spend: số dư thanh khoản được chọn, khoản vào/ra dự kiến, khoản dành mục tiêu,
  dự phòng tối thiểu, khoản bạn đang nợ người khác (chia tiền), mức mỗi ngày và thiếu
  hụt; có chế độ thận trọng và bảng giải thích. Tiền người khác nợ bạn không được cộng
  cho tới khi họ trả thật.
- Forecast theo ngày có biểu đồ/bảng chính xác, số dư thấp nhất và ngày thiếu đầu tiên;
  giữ mốc cuối tháng, năm nhuận, múi giờ/DST, tránh cộng lại khoản đã ghi sổ.
  Có mốc 7/30/90 ngày và khoảng tùy chọn 1–3660 ngày; trên 30 ngày cần Pro.
  Home/Kế hoạch nhắc đối chiếu tài khoản chưa có ghi nhận mới ít nhất 30 ngày,
  không khẳng định số dư đã được ngân hàng xác minh.
- "Dự báo nếu…" (sandbox) nằm ngay trên biểu đồ dự báo của Kế hoạch: bật/tắt từng kịch
  bản để vẽ thành một đường riêng (màu nhận diện, chip là chú giải) trên cùng biểu đồ và
  bảng từng ngày, kèm so sánh ngày thấp nhất, cuối kỳ và ngày bắt đầu thiếu với dự báo
  hiện tại. Thử mua tiền mặt/trả góp, thêm thu/chi giả định, đổi một lần đến hạn, đổi
  tên, bỏ kịch bản; ghi vào sổ thật chỉ sau xác nhận, một lần. Dữ liệu gốc bất biến:
  giả định kiểm tra trên bản sao lúc tạo, ảnh hưởng tính trên sổ hôm nay, không ghi gì.
  `/whatif/<id>` vẫn mở trang giả định. Free có một kịch bản; Pro hỗ trợ nhiều kịch
  bản, nhân bản, vẽ nhiều đường cùng lúc để so sánh và forecast dài hơn.
- Sao kê CSV/TXT/XLSX xử lý tại máy: preview, ánh xạ cột, ngày/múi giờ/dấu số,
  quy tắc phân loại, rà trùng/khả năng đảo giao dịch, sửa từng hàng, nhập phần hợp lệ
  có xác nhận, lịch sử và Undo batch khi hàng chưa thay đổi/không có phụ thuộc.
  Có cột số dư để đối chiếu sau nhập; không tự điều chỉnh chênh lệch.
  Rà gần trùng/đảo giao dịch với sai lệch tối đa một ngày lịch, số tiền chính xác
  và tên đối tác chuẩn hóa; luôn để người dùng quyết định.
  Mẫu nhập sao kê: lưu cách ghép cột (cột, dạng ngày, dấu thập phân/hàng nghìn, đảo
  dấu, dấu phân cột, bảng mã) thành mẫu có tên, nhận lại theo chữ ký tiêu đề cột và tự
  áp dụng ở lần nhập sau (vẫn sửa được hoặc bỏ mẫu); quản lý (đổi tên/xóa có Undo) trong
  Cài đặt. Không có mẫu ngân hàng dựng sẵn. Lưu mẫu vẫn cần Pro như hồ sơ cột trước đây.
- Khoản định kỳ, hóa đơn sắp đến/quá hạn, ước tính chi phí tháng/năm; chỉ ghi thanh toán
  khi được duyệt. Local notifications có quyền, giới hạn 50 lịch; Web/Windows dùng
  danh sách trong app.
  Ngày thanh toán gần nhất lấy từ giao dịch liên kết đã ghi sổ, không tính khoản dự
  kiến hoặc tương lai. Xu hướng báo cáo tháng có chi tiết theo danh mục và bộ lọc.
  Gợi ý khoản định kỳ từ lịch sử (Kế hoạch và sau khi nhập sao kê): cùng đối tác chuẩn
  hóa trên cùng tài khoản, ít nhất 3 lần liền cách nhau một tuần (6–8 ngày) hoặc một
  tháng (26–35 ngày), mọi số tiền lệch không quá 10% so với trung vị, lần cuối còn mới,
  chưa có khoản định kỳ cùng tên. Người dùng xác nhận từng gợi ý qua form định kỳ; gợi
  ý đã bỏ qua không hiện lại.
- Hóa đơn đính kèm: một giao dịch giữ tối đa 10 ảnh JPEG/PNG/WebP hoặc PDF, mỗi file
  ≤ 10 MB, tổng ≤ 50 MB và ≤ 1000 file; loại file xác định bằng chữ ký byte, không theo
  tên. Chụp ảnh trên Android/iOS, chọn file ở mọi nền tảng. File lưu riêng tư trong app
  (bảng SQLite `receipts` trên máy, kho IndexedDB `receipts` trên web), thêm vào khi
  Lưu. Dòng sổ có biểu tượng kẹp giấy kèm số lượng; mở xem toàn màn hình, chia sẻ qua OS
  hoặc lưu một bản, xóa có Undo. Xóa giao dịch xóa luôn hóa đơn của nó (Undo trả lại).
- Chia tiền / Ai nợ ai: chia một khoản chi đều, theo phần hoặc theo số cụ thể phải cộng
  đúng tổng tới đơn vị nhỏ nhất (đồng lẻ chia cho các phần đầu); danh sách người lưu trong
  app; ghi khoản người khác trả giúp. Số dư theo từng người (bù trừ hai chiều), thanh toán
  từng phần hoặc hết, người dùng tự chọn tài khoản; khoản họ trả lại là hoàn tiền của
  khoản chi gốc, khoản bạn trả là khoản chi. Hôm nay hiện một dòng "Người khác nợ bạn
  X đ · Bạn nợ Y đ" khi khác 0; Tài khoản có mục Ai nợ ai.
- Mục tiêu và khoản dành riêng; xuất CSV/XLSX/JSON/PDF có lọc, backup ZIP có manifest/
  checksum và mọi file hóa đơn (tối đa 85 MB: sổ ≤ 30 MB + hóa đơn ≤ 50 MB), restore
  kiểm tra từng file rồi mới hỏi hai lần. Backup JSON không chứa hóa đơn. Chưa có
  backup mã hóa.
- EN/VI, theme, tiền báo cáo/múi giờ/dạng ngày, ẩn số tiền, khóa bằng xác thực OS/PIN
  trên nền tảng hỗ trợ và che giao diện khi ra nền. Khóa không mã hóa database.
- Giữ Ads + Pro Lifetime qua adapter thật; ẩn ads trong capture/import/sandbox và
  hộp thoại nhạy cảm. Chưa có publisher IDs/signing/giao dịch store thật.

Không kết nối ngân hàng, đọc SMS/thông báo, cloud sync, tài khoản hay AI. Chưa chứng
nhận iOS, thiết bị vật lý, browser runtime, Windows Hello/Explorer drop và giao dịch
store. P1 planner nâng cao, OCR hóa đơn và mô hình lãi theo ngân hàng được để riêng.
Xem [công thức](handy_spend/FORMULAS_AND_ASSUMPTIONS.md) và
[bằng chứng/giới hạn kiểm thử](handy_spend/QA_MATRIX.md).

## Handy Bookmark

Ứng dụng lưu và tổ chức link, hoạt động offline. Chi tiết trạng thái từng phần:
[Handy Bookmark feature matrix](HANDY_BOOKMARK_FEATURE_MATRIX.md).

- Màn Đã lưu: ô tìm, dải Chưa xếp (mỗi link mới có sẵn các bộ sưu tập hay dùng, một
  chạm là xếp xong), danh sách nơi (Chưa xếp, Tất cả, Yêu thích, Chưa đọc, Lưu trữ,
  bộ sưu tập lồng nhau, bộ thông minh, thẻ) và Tập trung; desktop ba cột (nơi, link,
  chi tiết); dạng dòng/thẻ, tải thêm khi cuộn; lọc theo nguồn, loại, thẻ, ngày lưu và
  thứ tự; lịch sử tìm (bật trong Cài đặt).
- Nhận một/nhiều URL từ văn bản; chuẩn hóa bảo thủ, giữ URL gốc, phát hiện trùng;
  mở bản có sẵn, lưu thêm hoặc xem thông tin để hợp nhất thủ công.
- Android nhận SEND/SEND_MULTIPLE bằng hàng chờ bền vững; iOS có Share Extension
  dùng App Group; Windows nhận text/URL/.url qua kéo thả; Web có POST Share Target.
  Clipboard chỉ được đọc khi người dùng bấm nút.
- Bookmark: tiêu đề, mô tả, ghi chú, tags, bộ sưu tập; favorite, pin, read, archive;
  chỉnh sửa/xóa, Undo, mở/copy URL gốc và đếm lần mở.
  Bấm bookmark mở URL gốc; menu Chi tiết mở thông tin và các thao tác quản lý.
- Bộ sưu tập lồng nhau, màu/icon, quản lý tags độc lập; lọc theo collection, tag,
  nền tảng, loại nội dung, cờ trạng thái và ngày lưu/mở; nhiều kiểu sort, thứ tự thủ công.
- Smart Collections AND/OR và saved searches dùng quyền Pro Lifetime đã xác thực;
  điều kiện văn bản, cờ, ngày tương đối, ngày tuyệt đối và số lần mở. Tìm kiếm đã
  lưu giữ nơi, chữ và bộ lọc; lưu từ danh sách đang lọc (Pro), mở/đổi tên/xóa trong
  nhóm "Tìm kiếm đã lưu" (`#/search/<id>`).
- Thứ tự tự xếp ("Thứ tự tự xếp" trong Lọc và sắp xếp): chế độ Xếp lại có nút Lên/Xuống,
  kéo tay nắm và thao tác cho trình đọc màn hình; link đã ghim vẫn ở trên; Hoàn tác.
  Thứ tự nằm trong thư viện (schema 2) nên đi theo bản sao lưu.
- Bản đọc offline (chỉ khi bấm, từng link hoặc tối đa 200 link/lượt, có tiến trình và
  Dừng): tải trang HTML qua bộ tải an toàn (tối đa 3MB, 20 giây), lấy phần chữ chính
  kiểu readability (tiêu đề, tác giả, đoạn, tiêu đề phụ, danh sách, trích dẫn, mã), bỏ
  script, style, điều hướng, form và mọi ảnh. Mỗi bản tối đa 200.000 ký tự (dài hơn thì
  cắt và ghi rõ), lưu riêng khỏi dòng link. Trình đọc `#/read/<id>`: cột 680px, cỡ chữ
  14–28 (Ctrl/Cmd +/−), nền theo app/sáng/tối. Xóa link là xóa bản đọc.
- Kiểm tra link (chỉ khi bấm: một link, phần đang chọn, hoặc cả danh sách/bộ sưu tập;
  tối đa 500/lượt, từng yêu cầu một, mỗi host cách ≥2 giây, có Dừng và giữ kết quả đã
  có): HEAD rồi GET khi HEAD bị từ chối, không đọc nội dung. Ghi trạng thái và ngày:
  mở được / đã chuyển (redirect 301/308 sang địa chỉ khác hẳn) / không còn (404, 410)
  / không xác định (mạng, timeout, đăng nhập, 429, 5xx, địa chỉ không an toàn). Nơi
  "Link hỏng" hiện khi có; "Dùng địa chỉ mới" từng link, có Hoàn tác, không bao giờ
  tự đổi. Sửa URL thì bỏ kết quả kiểm tra cũ.
- Bản đọc offline và kiểm tra link không có trên Web (trình duyệt không bảo đảm chính
  sách mạng); app nói rõ. Bản đọc khôi phục từ backup vẫn đọc được trên Web.
- Focus theo hàng đợi chưa đọc; mở, đánh dấu, bỏ qua, lưu trữ hoặc chuyển collection.
- Batch move/tag/read/favorite/archive/delete/copy/export; chọn toàn bộ kết quả lọc
  có tiến trình và hủy trước commit; Undo từ chối ghi đè thay đổi mới hơn.
- Metadata tùy chọn, mặc định tắt; native kiểm tra public IP, redirect, MIME, dung
  lượng, timeout/cancel. Không đăng nhập/cookies. Thumbnail raster được xác thực,
  encode lại và cache có giới hạn; có thể nhập thumbnail từ file. Web không fetch
  metadata khi không bảo đảm được chính sách mạng. Lưu link không cần metadata.
- Nhắc xem lại theo preset hoặc ngày/giờ; Android/iOS có tích hợp local notifications,
  Windows/Web có danh sách trong app. Chưa chứng nhận giao thông báo nền/reboot.
- Nhập/xuất JSON, CSV, HTML, Markdown, TXT và ZIP; preview, thống kê lỗi/trùng,
  merge/replace có xác nhận; giữ đầy đủ cấu trúc khi round-trip giữa Handy Bookmark.
  Backup tối đa 30MB, không kèm thumbnail cache. JSON và ZIP kèm bản đọc offline
  trong ngân sách 30MB (mới nhất trước; bản không vừa bị bỏ và app báo số lượng);
  CSV/HTML/Markdown/TXT không kèm bản đọc.
- Nhập từ Pocket (Cài đặt → Nhập từ Pocket): CSV `title,url,time_added,tags,status`
  (thẻ ngăn bằng `|`) hoặc `ril_export.html` (Unread / Read Archive). `archive` →
  lưu trữ và đã đọc, `time_added` → ngày lưu, thẻ giữ nguyên; tất cả vào bộ sưu tập
  mới "Pocket". Xem trước số link, số đã lưu trữ, trùng và lỗi; chỉ Thêm (không thay
  thế), Hủy không đổi gì, có Hoàn tác. Importer CSV/HTML chung vẫn đọc file Pocket
  nhưng không giữ trạng thái đọc, ngày lưu và thẻ `|`.
- SQLite/FTS chạy worker trên native, IndexedDB trên Web; giao dịch nguyên tử,
  kiểm tra integrity, đóng/mở lại, lưu bản phục hồi trước reset và dọn cache.
- EN/VI, theme, lịch sử tìm kiếm tùy chọn mặc định tắt; thông tin quyền riêng tư;
  Ads + Pro Lifetime theo shared adapters, không quảng cáo trong quick-save/share/open.

Không có backend, đồng bộ cloud, tải video hay cloud AI. iOS, thiết bị vật lý,
browser runtime, app mạng xã hội thực và giao dịch store cần kiểm chứng riêng.
Xem [giới hạn](HANDY_BOOKMARK_KNOWN_LIMITATIONS.md) và [test plan](HANDY_BOOKMARK_TEST_PLAN.md).

## Chức năng chung

| Nhóm             | Chức năng hiện có                                                                                                                                                                                                                          | Giới hạn cần giữ rõ                                                                                                                                                |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Giao diện        | Theme sáng/tối/theo hệ thống; ngôn ngữ EN/VI/theo hệ thống; điều hướng riêng từng app, bố cục mobile/desktop                                                                                                                               | Chưa chứng nhận mọi kích thước, accessibility và nền tảng                                                                                                          |
| Dữ liệu          | Xử lý local; shared packages Dart; cấu trúc dữ liệu có version; đọc dữ liệu version 1 bằng import rõ ràng                                                                                                                                  | Flutter không tự đọc sandbox external application storage cũ; URI cũ không tự dereference                                                                          |
| Nhập/xuất        | File picker, giới hạn byte/kích thước; tên file an toàn; xuất bản sao; tiến trình/hủy trong luồng hỗ trợ                                                                                                                                   | Quyền và file provider phụ thuộc OS; không ghi đè file gốc tự động                                                                                                 |
| Camera/share     | Camera ở luồng tài liệu/ảnh; share qua OS ở luồng có nút chia sẻ                                                                                                                                                                           | Camera native Android/iOS; Android emulator đã thử; nhận file ở app đích chưa chứng nhận                                                                           |
| ZIP              | Manifest/assets/checksum, kiểm tra đường dẫn, file lỗi, giới hạn giải nén; roundtrip tests                                                                                                                                                 | Không nhận ZIP tùy ý như thư viện giải nén tổng quát                                                                                                               |
| Khôi phục        | Native snapshot đã kiểm tra, preserve/reset, xuất diagnostic ZIP, undo reset; Web IndexedDB transaction                                                                                                                                    | Xóa bản ghi không phải cam kết secure erase; power loss/multiwriter/browser eviction còn giới hạn                                                                  |
| Cài đặt          | Backup/import cài đặt từng app; từ chối backup khác app; reset preferences, xóa input đã lưu, xóa preview RAM có xác nhận                                                                                                                  | Giữ thư viện, ảnh/hóa đơn, file xuất và quyền mua; không quét/xóa thư mục tùy ý                                                                                    |
| Tự sao lưu       | Keep, Recall, Bookmark, Spend, Habit, Docs (tệp đã giữ), Media ghi bản sao lưu vào thư mục người dùng chọn khi mở/rời app; giữ 3–30 bản; khóa bằng mật khẩu (`.hseal`, X25519 + AES-256-GCM, PBKDF2 600.000 vòng); khôi phục nhận `.hseal` | Android: bộ chọn thư mục hệ thống; iOS: thư mục app trong Tệp; Windows: thư mục bất kỳ; Web: không có. Không chạy khi app đã đóng; quên mật khẩu thì không mở được |
| Widget, liên kết | Widget Android cho Habit (việc còn lại, chạm để đánh dấu), Spend (còn tiêu được, ẩn khi khóa), Recall (thẻ đến hạn); Spend → Keep "Thêm vào Handy Keep", Bookmark → Recall "Tạo thẻ ôn"; "Các app khác" trong Cài đặt                      | Chỉ điền sẵn, người dùng vẫn bấm Lưu; chưa có widget iOS; "Các app khác" ẩn tới khi có `listingUrl`                                                                |
| Text tools       | Pin, lưu/nạp input rõ ràng, Undo/Redo, workflow text allowlist, metadata lịch sử xuất và chia sẻ lại có kiểm tra file                                                                                                                      | Chỉ ở tool được hỗ trợ; không lưu nội dung kết quả/token trong lịch sử; secret không autosave                                                                      |
| Doanh thu        | Free + Ads + Pro Lifetime; native adapters, restore/purchase UI và cấu hình riêng từng store                                                                                                                                               | Chưa có tài khoản/ID/cấu hình thật; không coi test adapter là giao dịch/ads thật                                                                                   |
| Phân phối        | Android, iOS, Windows, Web source targets; PWA cache riêng app và kích hoạt update rõ ràng; MSIX development                                                                                                                               | iOS chưa build trên Windows; MSIX chưa ký; browser runtime và store approval chưa xác nhận                                                                         |

## Handy Docs

- **Tìm chữ trong tệp đã giữ** (bàn làm việc): một ô tìm trên mọi tệp trong Tệp đã giữ (tối đa 50), không phân biệt dấu ("hop dong" ra "Hợp đồng"), từ 2 ký tự. Mỗi kết quả có câu chứa chữ tìm, số chỗ khớp; tên tệp khớp được xếp trước. Chạm để mở tệp đó trong trình đọc.

Source: `apps/handy_docs/lib`, `packages/handy_docs_engine`, `packages/handy_pdf`,
`packages/handy_scan` (OCR).

- **Markdown:** sửa source, preview GFM, tìm/thay thế literal, template, highlight
  code local; xuất Markdown/HTML/text/PDF và ZIP gồm source + các bản xuất.
  Desktop soạn và xem trước cạnh nhau; Ctrl S lưu, Ctrl F tìm, Ctrl P xuất PDF;
  rời trình soạn khi chưa lưu sẽ được hỏi. Recipe md-text dùng workflow chung
  (Cài đặt → Quy trình văn bản). Mermaid chưa có renderer offline được kiểm chứng.
- **Bàn làm việc:** màn chính hiện việc dở (bản quét, bản nháp, PDF đang mở, tài
  liệu đọc chưa lưu) như xấp giấy, bốn lối bắt đầu (Quét, Viết Markdown, PDF, Mở tệp
  văn bản) và "Tệp đã giữ" gần đây.
- **Scanner:** nhập ảnh/camera, crop bốn góc kéo trực tiếp, sửa phối cảnh,
  tương phản, nhiều trang, sắp xếp/xóa trang, ghép PDF, lưu/khôi phục session JSON.
  "PDF tìm được chữ": OCR từng trang rồi đặt lớp chữ ẩn dưới ảnh. Không AI đám mây.
  Scanner giới hạn cạnh 2048 / 4Mpx mỗi trang, session 16MB/16Mpx.
- **Nhận dạng chữ (OCR, trên máy):** từ menu một trang quét hoặc nút trên trang PDF
  (render 2000 px). Android/iOS: Google ML Kit v2, chữ Latin, model đi kèm app (Google
  liệt kê tiếng Việt; chưa kiểm trên thiết bị). Windows: `Windows.Media.Ocr` với gói
  ngôn ngữ đã cài; thiếu tiếng Việt thì báo và cho đọc bằng ngôn ngữ đã có. Web: không
  có. Ảnh vào PNG/JPEG tối đa 20 MB / 40 Mpx, thu nhỏ cho engine (ML Kit 3000 px,
  Windows theo `MaxImageDimension`). Kết quả sửa được, chép, lưu .txt/.md, mở trong
  trình viết. API dùng chung: `package:handy_scan/ocr.dart` (`recognizeText`).
- **PDF:** mở/preview qua PDFium ở nền tảng native hỗ trợ; ghép PDF, chọn/extract
  trang, reorder, duplicate, xoay, render trang ra PNG, chữ đóng dấu (tối đa 100 ký tự,
  font Geist nhúng một lần nên có tiếng Việt; ký tự font không có bị từ chối).
  Bảo toàn source; không hứa sửa mọi cấu trúc hoặc mã hóa PDF.
- **Ký và điền PDF** (`#/pdf/fill`): chữ ký vẽ bằng ngón tay/chuột/bút hoặc nhập PNG
  (tối đa 6 chữ ký lưu trên máy, mỗi cái PNG ≤ 500 KB, xóa được, có bản lưu dự phòng),
  ô chữ một dòng (≤ 120 ký tự) và ngày (`pickHandyDate`); kéo, đổi cỡ, phím mũi tên,
  Delete; xem các trang bản mới rồi lưu `<tên>-signed.pdf`. PDFium vẽ ảnh (giữ nền
  trong suốt) và chữ vào **bản sao**; tối đa 200 món, ảnh tổng 4 Mpx. Cần Android/iOS/
  Windows.
- **Làm nhỏ PDF:** "Nén ảnh" mã hóa lại ảnh thành JPEG 150 dpi (chất lượng 60), giữ chữ
  và link; bỏ qua ảnh dùng chung nhiều trang, ảnh trong suốt/có mặt nạ, ảnh xoay, ảnh
  1-bit, ảnh dưới 64 px hoặc không nhỏ đi ít nhất 10%. "Nén mạnh" biến mỗi trang thành
  JPEG 100 dpi: chữ không còn chọn/tìm được (ghi rõ trên nút). Hiện cỡ trước → sau và %
  giảm; lưu `<tên>-smaller.pdf`; tệp gốc giữ nguyên. Cần Android/iOS/Windows.
- **Mở tệp văn bản (một lối):** Markdown (`.md`, `.markdown`) mở vào trình viết (hỏi
  trước khi thay bản nháp); text/code/HTML mở chỉ-đọc có tìm và "Tạo bản Markdown để
  sửa" (code vào khối rào, HTML thành chữ đọc được). Menu "Mở tệp văn bản" của trình
  viết dùng cùng lối.
- **Tệp đã giữ** (thư viện đọc cũ, `#/read`): nhập một/nhiều file UTF-8, giữ nguyên
  BOM/CRLF/source khi ZIP; tìm, recent, favorite, folder, rename; xuất/restore thư
  viện; tệp Markdown đã giữ mở vào trình viết, bản đã giữ không đổi. Định dạng lưu không
  đổi nên không cần chuyển đổi. HTML đọc như nội dung an toàn, không thực thi script
  hoặc tải remote.
- **Giới hạn text:** source 1MB; render/export rendered Markdown 100KB. Các giới
  hạn bổ sung, native adapter và coverage nằm trong FEATURE_MATRIX.

## Handy Media

- **Nối ảnh chụp màn hình**: 2–20 ảnh cùng chiều rộng, chụp lần lượt từ trên xuống; tự nhận thanh cố định trên và dưới (giữ một lần) và đoạn trùng giữa hai ảnh liền nhau. Ảnh không tìm thấy đoạn trùng được nối thẳng bên dưới và được báo tên. Kéo để đổi thứ tự. Kết quả dưới 16 triệu điểm ảnh, lưu PNG.

Source: `apps/handy_media/lib`, `packages/handy_media_engine`, `packages/handy_capture`.

Màn chính là **Xưởng**: các hướng dẫn (mới nhất trước, mỗi cái một dải phim các bước),
rồi công cụ nhanh Sửa ảnh và (Android/iOS/Windows) Chụp màn hình. Phụ đề SRT/VTT đã
chuyển sang Handy Tools (2026-11-02); engine phụ đề vẫn nằm trong `handy_media_engine`.

### Quick Tools

- Nhập ảnh từ file/camera, batch ảnh; crop kéo/resize trực tiếp, preset tỉ lệ,
  resize, rotate, flip ngang/dọc; convert PNG/JPEG/static WebP.
- Watermark text hoặc logo, vị trí/kích thước và xuất batch bằng engine chung.
- Xem/xóa EXIF/GPS **PNG/JPEG đã kiểm chứng**. JPEG strip bỏ orientation:
  cần preview kết quả. Không tuyên bố mọi metadata/định dạng đều được hỗ trợ.
- WebP input 16Mpx; encode 4Mpx; animated WebP bị từ chối.
- Cài đặt cũ còn ghim/nội dung đã lưu của `subtitle-srt`/`subtitle-vtt` vẫn đọc được;
  "Xóa nội dung đã lưu" (chỉ hiện khi còn sót) xóa cả nội dung lẫn ghim đó.

### Capture & Annotate

- Thư viện project: tạo, mở, tìm, xóa có xác nhận; metadata/tags, các bước có
  title/body, reorder/xóa; import project v1 JSON và portable project ZIP.
- Nhập nhiều screenshot hoặc camera vào cùng editor. Kiểm tra toàn batch trước
  khi thay đổi; ảnh thiếu từ project cũ phải relink rõ ràng.
- 9 loại annotation: arrow, rectangle, ellipse, highlight, opaque redact, text,
  step number, freehand pen, spotlight. Chọn/kéo/resize, style, alignment, thứ tự
  layer, xóa, Undo/Redo, lặp vùng che sang bước khác theo công cụ hiện có.
- Zoom 1–3× và pan riêng chế độ chỉnh layer; edit ảnh rotate90, resize50, crop theo
  vùng chọn qua renderer chung, có xác nhận flatten và Undo.
- Draft riêng từng project, debounce 500ms, restore/discard; write có thứ tự,
  lỗi vẫn giữ project đã lưu. Sau restart không phục hồi Undo stack; phần thay
  đổi trong cửa sổ debounce chưa bảo đảm. Xem [recovery](DEVELOPMENT.md).
- Xuất flattened PNG; preview trước khi share PNG; guide HTML/PDF/Markdown,
  flattened ZIP, long image, change map, **GIF động**. Review captions/masks trước khi xuất.
- **GIF động** (`buildGuideGif`): mỗi bước một khung từ ảnh đã làm phẳng (vùng che đã tô
  kín), tùy chọn thanh chú thích dưới khung (số bước + tên bước, vẽ bằng font kèm app,
  đủ tiếng Việt); lặp vô hạn. Thời gian mỗi khung 0,5–10 giây (UI: 1/2/3/5 giây), chiều
  rộng tối đa 480/640/800/960 px, không phóng to ảnh nhỏ; khung cao tối đa 1600 px. Giới
  hạn: 100 khung, tổng 48 triệu điểm ảnh, tệp 20 MB. Mỗi khung bảng màu 256 màu riêng
  (octree, không dither để chữ sắc). Có tiến độ từng khung và Hủy. Không có MP4: chưa có
  đường mã hóa chuỗi ảnh trong `handy_capture`.
- **Tìm thông tin nhạy cảm** trên một bước: OCR trên thiết bị (`handy_scan`: ML Kit
  Android/iOS, Windows.Media.Ocr Windows; web ẩn nút) rồi `findSensitiveAreas` (Dart
  thuần, có unit test) khớp email, số điện thoại VN (0/+84/0084, di động và cố định) và
  quốc tế (+ và 8–15 chữ số), số thẻ (13–19 chữ số, Luhn), IBAN (mod 97), dãy số kiểu tài
  khoản (9–19 chữ số, bỏ số có dấu chấm như tiền/ngày), mã OTP (4–8 chữ số khi có từ
  khóa OTP/code/mã/xác thực hoặc đứng một mình), token/khóa dài (≥20 ký tự, có chữ và số,
  entropy ≥ 3,5 bit/ký tự) và giá trị sau nhãn mật khẩu/token/API key. Đề xuất vùng che
  đen theo hộp chữ (có lề), bỏ qua chỗ đã bị che ≥ 90%; tối đa 100 đề xuất/ảnh, 2000 dòng
  OCR. Người dùng chọn/bỏ từng chỗ hoặc tất cả rồi mới áp dụng (một bước Hoàn tác);
  không bao giờ tự che. Danh sách chỉ hiện đầu/cuối giá trị. OCR có thể sót chữ.
- ZIP project gồm manifest + assets để chuyển máy, giữ ảnh PNG gốc byte-exact.
  JSON/ZIP editable chứa ảnh gốc; không dùng chúng để giấu pixel nhạy cảm.
- Version 1 PNG tới 32Mpx được giữ nguyên; output flatten tối đa 16Mpx; guide dùng
  giới hạn nhỏ hơn. Tối đa 100 bước, 8MB/PNG, 20MB ảnh active, thư viện serialize 30MB.

### Screen capture/video native

- Android: MediaProjection với hộp thoại đồng ý thật, screenshot PNG, quay H264
  MP4; import video, trim theo keyframe, join clip tương thích, lấy frame, xuất,
  preview play/pause/seek và hủy/cleanup capture do app quản lý.
- Transform tạo bản MP4 H264/AAC: rotate bội 90°, resize không upscale, mute;
  kiểm tra owned URI, giới hạn input 5 phút/output 30MB, hủy và xóa output dở.
  Không phải bộ chuyển mọi codec/container.
- iOS: ReplayKit quay **nội dung trong app**, AVFoundation trim/join/frame/
  transform source. Chưa build/run bằng Xcode; không tuyên bố quay toàn hệ thống.
- Windows: chụp màn hình native (GDI BitBlt + CAPTUREBLT, PNG qua WIC, điểm ảnh vật lý,
  nhiều màn hình): **cả màn hình** dưới con trỏ, hoặc **một vùng** kéo trên lớp phủ ảnh
  đứng yên phủ mọi màn hình (bấm = cả màn hình đó; Esc/chuột phải = hủy). App tạm ẩn
  (tắt hiệu ứng DWM) trong lúc chụp; chờ 0/3/5/10 giây. Ảnh tối đa 16 triệu điểm ảnh và
  8 MB, giữ trong bộ nhớ 4 ảnh gần nhất, không ghi đĩa; "Chú thích ảnh" mở hướng dẫn mới
  với ảnh là bước 1. **Không có quay màn hình trên Windows.**
- Web: chỉ nhập ảnh/video từ tệp.
- Android emulator đã kiểm tra codec/output độc lập. Preview texture còn lỗi viền
  xanh trên emulator; MP4 decode độc lập không có viền. Thiết bị thật chưa xác nhận.

## Handy Tools

- **Sổ tính** (nút trên Băng kết quả): mỗi dòng một phép tính, kết quả thẳng hàng bên phải, chạm để sao chép. Chữ là nhãn; "Tên: số" hay "tên = số" đặt tên để dùng ở dòng dưới; `ans` là dòng ngay trên; "tổng"/"total" cộng các dòng phía trên tới dòng trống; đọc được 45k, 1.2tr, 1.200.000, 10%, 3 x 4. Tối đa 500 dòng, lưu như bản nháp công cụ.

Source: `apps/handy_tools/lib`, `packages/handy_tools_engine`.

- 17 tool đăng ký ở bảng cuối tài liệu; calculator/converter có form chuyên dụng.
  Phép tính dùng quy tắc rõ ràng; không có feed giá trực tuyến.
- Gọn lại (2026-11-03): phần trăm và tỷ lệ nằm trong Sổ tính ("15% của 2tr",
  "2tr - 15%" bớt 15%, "100 - 5% - 2%" bớt lần lượt, "1920 * 9 / 16"); gõ
  "15% của 2.400.000" trên bàn vẫn ra số bằng máy tính. Đổi tiền theo tỷ giá
  nhập tay đã bỏ. Màu (HEX/RGB/HSL, độ tương phản) chuyển sang Handy Dev. Ghim cũ
  của các tool này được bỏ qua, không làm hỏng cài đặt.
- `case` gộp bốn công cụ cũ (viết hoa, viết thường, đầu từ, đầu câu) thành một form
  có 4 chế độ; kết quả từng chế độ giữ nguyên như công cụ cũ. Id cũ vẫn mở được
  (`#/tool/title-case` mở `case` ở chế độ đó), ghim cũ hiện thành `case`, chuỗi xử lý
  văn bản đã lưu vẫn chạy.
- `salary` (thay `tax`): Gross → Net và Net → Gross, làm tròn từng khoản đến đồng (nửa
  lên); tiền ghi "đ" vì font kèm theo thiếu ₫. Bảng quy định có ngày hiệu lực, chọn theo
  ô "Áp dụng quy định ngày"; mọi tham số sửa được trong form (để trống là dùng bảng).
  Kiểm tra ngày 2026-11-02:
  - Từ 2026-07-01 (đang áp dụng): giảm trừ bản thân 15.500.000 đ/tháng, người phụ
    thuộc 6.200.000 đ/tháng (Nghị quyết 110/2025/UBTVQH15 ngày 17/10/2025, áp dụng từ
    kỳ tính thuế 2026); biểu lũy tiến 5 bậc 5% đến 10 triệu, 10% đến 30 triệu, 20% đến
    60 triệu, 30% đến 100 triệu, 35% trên 100 triệu (Luật Thuế TNCN 109/2025/QH15, hiệu
    lực 01/7/2026, phần tiền lương áp dụng từ kỳ tính thuế 2026; Luật 09/2026/QH16 chỉ
    sửa khoản 1 Điều 7 về doanh thu hộ kinh doanh, không đổi biểu thuế tiền lương);
    lương cơ sở 2.530.000 đ (Nghị định 161/2026/NĐ-CP ngày 15/5/2026, từ 01/7/2026),
    trần BHXH/BHYT = 20 × lương cơ sở = 50.600.000 đ; lương tối thiểu vùng I–IV
    5.310.000 / 4.730.000 / 4.140.000 / 3.700.000 đ (Nghị định 293/2025/NĐ-CP, từ
    01/01/2026), trần BHTN = 20 × lương tối thiểu vùng (Luật Việc làm 74/2025/QH15);
    người lao động đóng BHXH 8% (Luật BHXH 41/2024/QH15), BHYT 1,5%, BHTN 1%.
  - Từ 2026-01-01 đến 2026-06-30: như trên nhưng lương cơ sở 2.340.000 đ (Nghị định
    73/2024/NĐ-CP), trần BHXH/BHYT 46.800.000 đ.
  - Từ 2024-07-01 đến 2025-12-31: giảm trừ 11.000.000 / 4.400.000 đ (Nghị quyết
    954/2020/UBTVQH14), biểu 7 bậc 5–35% (5/10/18/32/52/80 triệu), lương cơ sở
    2.340.000 đ, lương tối thiểu vùng 4.960.000 / 4.410.000 / 3.860.000 / 3.450.000 đ
    (Nghị định 74/2024/NĐ-CP). Ngày trước 2024-07-01 bị từ chối.
  - Nguồn kiểm tra: tóm tắt Luật 109/2025/QH15 của EY Việt Nam (12/2025), văn bản hợp
    nhất 112/VBHN-VPQH, bản giới thiệu Luật 09/2026/QH16 (Sở Tư pháp Tuyên Quang),
    Thư viện Pháp luật / LuatVietnam / Tạp chí Công Thương về NQ 110/2025, NĐ 293/2025 và
    NĐ 161/2026. Không tính: phụ cấp miễn thuế, thu nhập không cư trú, quyết toán năm.
- `number-words`: đọc số thành chữ tiếng Việt (linh/lẻ, nghìn/ngàn, mười/mươi, mốt,
  lăm, tư, tỷ lặp lại: nghìn tỷ, tỷ tỷ; âm; thập phân đọc từng chữ số sau "phẩy") và
  tiếng Anh. Chế độ đồng viết hoa chữ đầu và kết thúc "đồng chẵn", không nhận số lẻ
  thập phân. Tối đa 27 chữ số phần nguyên, 12 chữ số thập phân.
- `lunar`: âm lịch Việt Nam theo thuật toán Hồ Ngọc Đức, múi giờ UTC+7, năm 1900–2100;
  tháng nhuận, can chi ngày/tháng/năm, tiết khí (24 tiết, 15°). Tết 2030 là 02/02/2030
  (khác Trung Quốc 03/02 vì múi giờ). Ngày âm không tồn tại hoặc tháng nhuận sai năm
  bị từ chối và nêu tháng nhuận thật của năm.
- Password generator dùng secure random, tùy độ dài/nhóm ký tự và tùy chọn
  tránh ký tự khó phân biệt. Không lưu password vào history.
- QR text/URL, Wi-Fi, contact, calendar event và **Chuyển khoản (VietQR)**; xuất
  PNG/SVG/PDF, preview nội dung an toàn trước khi hành động, history QR tùy chọn và
  xóa history. VietQR: EMVCo merchant-presented, GUID NAPAS `A000000727`, BIN ngân
  hàng + số tài khoản (6–19 chữ/số), dịch vụ `QRIBFTTA`, mã tiền 704, quốc gia VN, số
  tiền tùy chọn (đồng nguyên, tối đa 13 chữ số; có số tiền thì mã động `12`), nội
  dung tùy chọn (tự bỏ dấu, chữ/số/khoảng trắng, tối đa 25 ký tự), CRC16-CCITT. Danh
  sách 76 ngân hàng/ví lấy từ danh sách công khai https://api.vietqr.io/v2/banks ngày
  2026-11-02 và nhúng cố định trong app (không tải lúc chạy, không tải logo). Payload
  được kiểm tra byte-exact với ví dụ công bố của thư viện vietnam-qr-pay và
  vietqr_generator. Dưới mã có dòng đọc lại từ chính payload (ngân hàng · số TK · số
  tiền · nội dung); app không tra tên chủ tài khoản.
- Phụ đề (chế độ của bàn, `#/tool/subtitles`, chuyển từ Handy Media): SRT ↔ WebVTT và
  dời thời gian theo ms, dùng engine phụ đề của `handy_media_engine`. Xem trước 5 câu
  đầu trước/sau; Lưu đọc lại cả tệp, dựng lại, đọc lại kết quả và so từng câu trước
  khi ghi. Tối đa 1 MB và 10.000 câu; câu đầu bị dời trước 0 thì không lưu. Lịch sử
  xuất chỉ giữ metadata, không giữ nội dung.
- QR decoder/camera native; có fallback nhập/paste khi không hỗ trợ. Android đã
  test decode ảnh và quyền bị từ chối; live optical/interoperability chưa đủ bằng chứng.
- Text workflow/pins/drafts/input Undo và export metadata theo các tool allowlist.

## Handy Dev

- **So với lần gửi trước**: khi gửi lại cùng một request trong phiên, phản hồi có nút so sánh: trạng thái trước → sau, chênh thời gian và dung lượng có dấu (+/−), rồi body so từng dòng (JSON được thụt lề và sắp khóa trước khi so). Phản hồi cũ chỉ nằm trong bộ nhớ của phiên.

Source: `apps/handy_dev/lib`, `packages/handy_dev_engine`, `third_party/re2`,
`third_party/json_schema`; 35 tool đăng ký được liệt kê cuối tài liệu.

- JSON tree/table, search/projection; format/minify/diff, JSONPath subset,
  JSON↔YAML/TOML/XML/CSV, JSONL; infer TypeScript/JSON Schema từ mẫu.
- JSON Schema draft-07 local, bounded evaluation, không tải external references;
  898 case conformance pass, 27 remote case bỏ qua theo chính sách offline.
- Regex RE2 native và RE2JS vendored trên Web: không backreference/lookaround;
  input/pattern/match có giới hạn để tránh regex backtracking.
- API client HTTPS: method/query/body/headers, Basic/Bearer/API-key authentication,
  timeout/cancel và response có giới hạn, collections, environments, biến template,
  import/export các dạng cURL phổ biến. Không phải shell cURL đầy đủ.
- Secrets ở session; loại khỏi export/lưu mặc định; không log token. JWT chỉ
  decode, không xác minh chữ ký; redact JSON cần review. Secret tools (cả HMAC)
  không autosave draft/recipe. Tóm tắt HAR và .env mẫu đã bỏ (2026-11-03): file
  HAR mở như JSON, dòng .env như văn bản.
- Gộp tool (2026-11-03): `convert` thay tám tool một chiều (JSON ↔ YAML/TOML/XML/
  CSV, chọn chiều bằng chip; một phía luôn là JSON), `json` gồm cả rút gọn,
  `base64` và `url` có chip Mã hóa/Giải mã, `hash` có chip SHA-256/SHA-512.
  Ghim và nháp theo id cũ tự chuyển sang tool mới; chuỗi đã lưu vẫn chạy.
- Màu (chuyển từ Handy Tools, 2026-11-03): dán `#RRGGBB` để xem HEX/RGB/HSL
  (`colors`); `contrast` cho tỷ lệ WCAG của màu chữ trên nền, AA 4.5 (chữ lớn 3),
  AAA 7. Dán cả cặp ("#111111 on #FFFFFF") hoặc nhập màu nền.
- Mốc thời gian Unix s/ms/µs/ns (tự nhận đơn vị theo độ lớn) ↔ ISO-8601, giờ UTC,
  giờ máy hoặc độ lệch cố định (không có tên múi IANA), kèm "3 ngày trước".
- UUID v4/v7 và ULID từ nguồn ngẫu nhiên an toàn, 1–1000 mỗi lần (lô v7/ULID đã
  sắp thứ tự); đọc UUID/ULID dán vào: phiên bản, variant, thời điểm v1/v6/v7/ULID.
- So sánh văn bản theo dòng (Myers): 20000 dòng mỗi bên, tối đa 2000 dòng khác;
  dạng unified và hai cột.
- Cron 5 trường hoặc 6 trường có giây, khoảng/bước/danh sách/tên, macro `@daily`…;
  giải thích EN/VI và 1–100 lần chạy kế tiếp theo UTC, giờ máy hoặc độ lệch.
- Đổi hệ cơ số 2/8/10/16 và 2–36 bằng BigInt (tối đa 4096 chữ số), bù hai theo
  số bit 1–4096.
- Tách URL: scheme, user (ẩn mật khẩu), host, port, path, bảng query đã giải mã,
  fragment; sửa tham số rồi dựng lại URL. Không tải gì.
- HMAC-SHA256/SHA512, kết quả hex hoặc Base64; khóa dạng text/hex/Base64 chỉ giữ
  trong phiên, không vào nháp, chuỗi hay bản xuất.
- Live endpoint, redirect/provider và browser CORS cần kiểm chứng tiếp.

## Handy Keep

- **Sắp hết**: Keep học từ các ngày mua (ngày mua của món, các lần "Vừa mua thêm", và ngày mua của các món cùng tên), lấy khoảng cách ở giữa làm nhịp mua lại; đồ được mua lại trong vòng 180 ngày mới được đoán. Một tuần trước ngày dự đoán, món đó vào "Cần để ý". Người dùng chỉ chạm "Vừa mua thêm" khi mua, không cần mỗi lần dùng. Dữ liệu lên phiên bản 3 (`restocks`); file phiên bản 1 và 2 vẫn mở được.

Source: `apps/handy_keep/lib`, `packages/handy_inventory`.

- CRUD hồ sơ đồ dùng; tên/vị trí/thông tin mua, ảnh (chụp bằng camera trên
  Android/iOS hoặc chọn file PNG/JPEG ≤4 MB, kiểm tra chữ ký file); tìm không dấu theo
  tên/chỗ để/thùng/người mượn/serial/ghi chú; danh sách xếp theo chỗ ở hiện tại (người
  mượn, thùng, chỗ để); lọc Đang cho mượn/Theo thùng/Chưa vào thùng; cho mượn và trả;
  ngày mua/bảo hành/bảo dưỡng chọn bằng lịch; dải "Cần để ý" (quá hạn và 30 ngày tới)
  và trang Đến hạn.
- Thùng chuyển nhà: tạo/sửa/xóa (xóa thùng giữ lại đồ bên trong), gán đồ vào thùng;
  nhãn QR item/box, xuất ảnh mã QR hoặc cả tấm nhãn có tên (PNG 3×) để in; mở hồ sơ local bằng `handy-keep://item/<id>` hoặc
  `handy-keep://box/<id>`. Không tải URL nhãn qua mạng.
- Hóa đơn ảnh/PDF đính kèm hồ sơ; xuất dossier TXT và review trước share qua OS.
- Backup ZIP dữ liệu + ảnh/hóa đơn, checksum; restore merge/replace có xác nhận,
  staged validation; giữ dữ liệu cũ khi file lỗi/hủy/save thất bại. Version 1 JSON
  không tự đọc absolute image paths không tin cậy.
- Giá mua (schema v2): giá tùy chọn kèm mã tiền tệ ISO 4217 (VND/JPY/KRW không có
  phần lẻ, tiền khác tối đa 2 chữ số lẻ, tối đa 12 chữ số phần nguyên); gõ được
  "4.500.000", "1,299.90", "1.299,90". File v1 vẫn đọc được (món không có giá).
  Tổng giá trị theo chỗ (thùng, người mượn, chỗ để), theo chế độ xem (Tất cả, Đang
  cho mượn, Theo thùng, Chưa vào thùng, một thùng, kết quả tìm) và toàn bộ; cộng
  riêng từng tiền tệ, không cộng chéo; đếm "N món chưa có giá" riêng, giá 0 là 0 thật.
- Xuất CSV danh sách đồ (tất cả từ Cài đặt, hoặc đúng những món đang lọc/tìm từ menu
  ⋯): tên, cất ở, thùng, người mượn, ngày cho mượn, hẹn trả, ngày mua, giá, tiền tệ,
  bảo hành đến, serial, ghi chú. UTF-8 có BOM, CRLF, mọi ô trong ngoặc kép; ô bắt đầu
  bằng `=`, `+`, `-`, `@` (cả full-width), tab, CR được thêm `'`. Đi qua
  `exportBytes` (tối đa 30 MB), không sửa dữ liệu.
- Thêm nhiều món từ ảnh: chọn nhiều ảnh (mọi nền tảng) hoặc chụp liên tục
  (Android/iOS), tối đa 20 ảnh mỗi lần; mỗi ảnh kiểm tra như form (PNG/JPEG theo
  chữ ký, ≤ 4 MB), ảnh hỏng bị liệt kê kèm lý do; đặt tên từng ảnh, chung một chỗ để
  và/hoặc một thùng; lưu tất cả trong một lần ghi (thiếu tên hay lỗi ghi thì không lưu
  món nào, giữ ảnh và tên); hủy không giữ gì.
- Hẹn trả khi cho mượn (tùy chọn, chọn bằng lịch); món quá hẹn hiện trong "Cần để ý"
  và trang Đến hạn; nhắc cục bộ vào ngày hẹn, hủy khi trả lại hoặc xóa món.
- Local notifications cho mốc đến hạn: xin quyền, schedule/cancel và cấu hình
  local. Android đã test deny/grant/schedule/immediate delivery; delayed,
  background, reboot và iOS chưa đủ bằng chứng.

## Handy Recall

- **Dán ghi chú** (menu bộ thẻ): dán văn bản, xem trước từng thẻ rồi thêm một lần. Tự nhận: dòng "câu hỏi – đáp án" (gạch ngang, dấu hai chấm, dấu bằng hoặc tab) thành thẻ hỏi-đáp; câu có chữ đánh dấu bằng [ngoặc vuông], {ngoặc nhọn}, **đậm** hoặc **gạch** thành thẻ điền khuyết (mỗi chữ một ô). Bỏ gạch đầu dòng và số thứ tự; báo số dòng bỏ qua. Thêm qua đúng đường nhập CSV nên được kiểm tra như file.

Source: `apps/handy_recall/lib`, `packages/handy_recall`.

- CRUD deck/card; question/answer; màn Hôm nay: số thẻ đến hạn, thời gian ước tính và
  lịch ôn 14 ngày; buổi ôn toàn màn hình: lật đáp án (phím cách), chấm Quên/Khó/Nhớ/Dễ
  (phím 1–4), mỗi nút ghi khoảng cách tới lần ôn sau theo scheduler thật; "Lưu, thêm
  thẻ khác" để nhập liền tay; scheduler spaced repetition và lịch sử/review state
  được giữ qua backup.
- Import/export CSV question/answer (một dòng mỗi ghi chú; dòng có `{{cN::}}` thành thẻ
  điền khuyết, bộ bật đảo chiều thì thêm thẻ đảo chiều); backup/restore JSON có schedule
  và ảnh embedded bounded; import thẻ cũ một mask sang nhiều mask.
- Backup schema **version 2** (file version 1 vẫn đọc được): bộ thẻ thêm `reverse`,
  `speakFront`, `speakBack` (thẻ BCP 47); thẻ thêm `note` (nhóm anh em), `cloze` (số ô),
  `reversed`; ảnh thêm `side` (`front`/`back`) và có thể không có vùng che (ảnh thường).
  Câu hỏi được trống nếu có ảnh; đáp án được trống nếu có ảnh hoặc là thẻ điền khuyết.
- Nhập Anki `.apkg`/`.colpkg` trên mọi nền tảng, kể cả Web (Dart thuần): ZIP (tối đa
  100 MB, 60.000 mục, từ chối tên có `..`, `/` đầu, `\` hoặc `:`; kiểm CRC-32 từng mục),
  `collection.anki2`/`.anki21` (SQLite schema 11, kiểu ghi chú JSON) và `collection.anki21b`
  (zstd, SQLite schema 18, protobuf; tối đa 128 MB sau giải nén) đọc bằng trình đọc SQLite
  chỉ-đọc viết bằng Dart. Basic, Basic (and reversed), Basic (optional reversed) và Cloze
  (cùng kiểu tùy biến: mặt hỏi là các trường template hỏi hiển thị, mặt đáp là phần còn
  lại; thẻ thứ hai có hai mặt đổi chỗ thành thẻ đảo chiều). HTML thành chữ thường
  (script/style bỏ hẳn, entity giải mã, `<br>`/khối thành xuống dòng); ảnh PNG/JPEG
  ≤500 KB, một ảnh mỗi thẻ (ưu tiên mặt hỏi), tối đa 300 ảnh và 6 MB mỗi lần nhập, kiểm
  SHA-1 khi gói có; âm thanh/video bị bỏ và được đếm; che ảnh của Anki bị bỏ. Xem trước
  đầy đủ (số thẻ, lịch ôn 14 ngày, bộ mới, loại thẻ, phần bị bỏ kèm lý do) và kiểm giới
  hạn thư viện trước khi ghi; một lần ghi. Tùy chọn giữ lịch Anki: thẻ đã ôn giữ
  interval, ease (factor/1000, kẹp 1,3–3,5), số lần ôn/quên và ngày đến hạn (`crt` +
  `due` ngày); thẻ đang học/học lại đến hạn ngay (Recall không có learning step); thẻ bị
  tạm dừng vào như thẻ thường; mỗi bộ Anki thành một bộ mới (`Cha › Con`). Gói không đọc
  được dạng mới thì báo xuất lại với "Support older Anki versions".
- Thẻ điền khuyết `{{c1::đáp án::gợi ý}}`: mỗi số một thẻ, lịch riêng; soạn bằng chọn chữ
  → Tạo ô điền khuyết (nút, menu chọn chữ, Ctrl+Shift+C; Ctrl+Shift+Alt+C cùng số). Không
  hỗ trợ ô lồng nhau. Thẻ đảo chiều: tùy chọn từng thẻ, mặc định theo bộ, lịch riêng; ghi
  chú sửa một lần cập nhật mọi thẻ anh em, tắt đảo chiều/xóa ô thì xóa thẻ đó và lịch ôn
  của nó; xóa thẻ xóa cả ghi chú; anh em không ôn liền nhau trong một buổi.
- Đọc to (`flutter_tts` 4.2.5): ngôn ngữ cho mặt hỏi và mặt đáp theo bộ, chọn từ giọng
  của hệ điều hành; nút loa và phím R; thiếu giọng thì báo. Windows cần `nuget.exe` trên
  PATH khi build (plugin tải C++/WinRT).
- Image occlusion: nhập ảnh, tạo nhiều vùng che trên cùng ảnh, kéo/resize trực
  tiếp, chọn/xóa vùng (xóa hết thì thành ảnh thường, chọn hiện cùng câu hỏi hoặc cùng
  đáp án), lưu và ôn qua editor/state chung. Không OCR/AI.
- Web: chữ Nhật/Trung/Hàn dùng lát font Noto engine tải từ fonts.gstatic.com lần đầu
  cần (phải online), sau đó lấy từ cache `handy_recall-fonts-v1` nên hiện được offline.
- Local notifications nhắc ôn với xin quyền, schedule/cancel; giới hạn kiểm chứng
  delayed/background/reboot/iOS giống Keep.

## Verification limits

Code presence does not establish device or release certification. iOS builds,
physical devices, browser runtime/offline/update, real store transactions and
AdMob setup remain open. Current issues are recorded in [KNOWN_ISSUES](../KNOWN_ISSUES.md).

## Registry công cụ chính xác từ source Flutter

Hai bảng dưới được trích từ registry Dart hiện tại; mô tả gốc bằng tiếng Anh giữ
nguyên để tránh diễn giải sai quy tắc xử lý. Các thao tác ngoài registry đã được
liệt kê theo từng app ở trên.

### Handy Tools

| ID                | Tool                     | Behavior / limits                                                                                                   |
| ----------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| `calculate`       | Máy tính                 | Operators + − * / % ^, parentheses, sqrt/abs/sin/cos/tan/log. Trigonometry uses radians.                            |
| `units`           | Đổi đơn vị               | Compatible units; C/F/K supported.                                                                                  |
| `loan`            | Lịch trả nợ              | Fixed annual rate, monthly installments; excludes fees and taxes.                                                   |
| `compound`        | Lãi kép                  | No additional contributions, tax or fees.                                                                           |
| `dates`           | Khoảng cách ngày         | Calendar days in UTC; end minus start.                                                                              |
| `normalize`       | Chuẩn hóa khoảng trắng   | NFC Unicode, trim each line, collapse spaces and tabs.                                                              |
| `deduplicate`     | Lọc dòng trùng           | Keep first exact occurrence.                                                                                        |
| `sort`            | Sắp xếp dòng             | Unicode code-point order, independent of locale.                                                                    |
| `case`            | Đổi kiểu chữ             | Unicode upper, lower, title (letter groups) or sentence case (after . ! ?).                                         |
| `accents`         | Bỏ dấu                   | Remove combining marks and map Vietnamese đ/Đ.                                                                      |
| `count`           | Đếm văn bản              | Code points, UTF-16 units, whitespace-separated words and lines.                                                    |
| `salary`          | Tính lương               | Vietnamese employee insurance with caps, family deductions and progressive PIT from a dated rule table; whole đồng. |
| `split-bill`      | Chia hóa đơn và tiền tip | Rounded cents are allocated exactly; extra cents go to first shares.                                                |
| `business-days`   | Số ngày làm việc         | Start inclusive, end exclusive. Weekend indices Sun=0, Sat=6.                                                       |
| `literal-replace` | Tìm và thay thế          | Literal replacement, bounded to one million UTF-16 units.                                                           |
| `number-words`    | Đọc số thành chữ         | Vietnamese and English words; đồng amounts end "đồng chẵn". Up to 27 digits, 12 decimals.                           |
| `lunar`           | Âm lịch                  | Vietnamese lunar date at UTC+7 (Hồ Ngọc Đức), leap months, can-chi, solar term; 1900–2100.                          |

### Handy Dev

| ID                  | Tool                 | Behavior / limits                                                                                                                                                                                                                                                              |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `schema`            | Kiểm tra JSON Schema | Local draft-07 validation with RE2 patterns. 20 KB schema; external references and format assertions disabled; bounded evaluation.                                                                                                                                             |
| `regex`             | Biểu thức RE2        | Local RE2; no lookaround/backreferences. 100 KB input / 1000-byte pattern / 1000 matches; bounded capture output.                                                                                                                                                              |
| `json-typescript`   | JSON → TypeScript    | Infer a sample type; missing array fields optional, no runtime validation.                                                                                                                                                                                                     |
| `json-schema-infer` | Suy luận JSON Schema | Draft-07 inference from sample only.                                                                                                                                                                                                                                           |
| `jsonpath`          | JSONPath giới hạn    | Supports $, .name, [index], [*], ["key"]; no scripts or filters.                                                                                                                                                                                                               |
| `json-project`      | Chọn trường JSON     | Object array; options are JSON field-name array.                                                                                                                                                                                                                               |
| `json`              | Định dạng JSON       | Strict JSON: pretty (default) or minified. Options: pretty \| min.                                                                                                                                                                                                             |
| `convert`           | Chuyển đổi dữ liệu   | Between JSON, YAML, TOML, XML and CSV; one side is JSON. Options: from and to, e.g. "json yaml". YAML rejects duplicate keys and alias bombs; TOML rejects null and unsafe integers; XML maps attributes to @_ and text to #text (DTD off); CSV is flat with formulas escaped. |
| `jsonl`             | JSONL → JSON         | Parse nonempty lines as JSON.                                                                                                                                                                                                                                                  |
| `base64`            | Base64               | UTF-8 text. Options: encode (default) \| decode; decoding is strict UTF-8 with canonical unused bits.                                                                                                                                                                          |
| `url`               | Mã hóa URL           | A UTF-8 component. Options: encode (default) \| decode; invalid percent escapes are rejected.                                                                                                                                                                                  |
| `hash`              | Băm                  | Local UTF-8 hash. Options: sha256 (default) \| sha512.                                                                                                                                                                                                                         |
| `jwt`               | Giải mã JWT          | Decode only; signature NEVER verified; no saved drafts.                                                                                                                                                                                                                        |
| `json-diff`         | So sánh JSON         | Before JSON; options after JSON. JSON Pointer paths.                                                                                                                                                                                                                           |
| `redact`            | Ẩn bí mật JSON       | Mask common credential keys recursively; review before sharing.                                                                                                                                                                                                                |
| `timestamp`         | Mốc thời gian Unix   | Unix s/ms/µs/ns (unit by size) or ISO-8601 to UTC, a zone and relative time. Zones: UTC, device local or a fixed offset; no IANA names.                                                                                                                                        |
| `uuid`              | UUID / ULID          | Inspect pasted IDs (version, variant, v1/v6/v7 and ULID time), or with empty input make 1–1000 v4, v7 or ULID from a secure random source.                                                                                                                                     |
| `text-diff`         | So sánh văn bản      | Line diff (Myers), unified output. Before text; options after text. 20000 lines per side, 2000 changed lines.                                                                                                                                                                  |
| `cron`              | Giải thích cron      | 5 fields, or 6 with seconds; ranges, steps, lists, names, @daily-style macros. Explained in EN/VI with the next 1–100 runs in UTC, local or a fixed offset.                                                                                                                    |
| `base-convert`      | Đổi hệ cơ số         | BigInt between bases 2/8/10/16 and any 2–36; two’s complement at a bit width. Up to 4096 digits.                                                                                                                                                                               |
| `url-parse`         | Tách URL             | Scheme, user, host, port, path, decoded query table and fragment; rebuilt after editing. Password hidden; nothing fetched.                                                                                                                                                     |
| `hmac`              | HMAC                 | HMAC-SHA256/SHA512 of UTF-8 text, hex or Base64. The key is session-only: never saved in drafts, chains or exports.                                                                                                                                                            |
| `colors`            | HEX / RGB / HSL      | A #RRGGBB colour as RGB and HSL (degrees and percentages).                                                                                                                                                                                                                     |
| `contrast`          | Độ tương phản màu    | WCAG 2 ratio of a text colour on a background: AA needs 4.5 for normal text, 3 for large; AAA needs 7. Input: text colour; options: background (or both in the input, "#111111 on #FFFFFF").                                                                                   |

## Handy Boards

Independent offline app 11. Category, Status and Tag are separate. One canonical
task UUID across Category Board, Kanban, List/Table, Today and Calendar. Templates
are opt-in; generic boards do not require school/project fields.

- Workspace/board/category creation, editable statuses/WIP; four-category compact
  overview, grid/list, ordering alternatives, contextual capture and task status.
- Task Markdown (external images blocked; links require consent), all-day/timed
  IANA deadlines with DST confirmation, priorities, tags, assignee label, pin,
  checklist/subtasks/dependencies, local comments/history, attachment copies/links.
- Trash/restore/confirmed hard delete, archive, safe duplicate, cross-board subtree
  move, batch edits and bounded Undo/Redo. Search/filter/sort Unicode/VI.
- Today/Upcoming/Radar, month calendar, progress with explicit denominator, local
  reminder records and Android/iOS adapters. Windows/Web in-app fallback.
- Optional Study templates/metadata, weekly sessions, assessments/weight/target,
  normalized personal grade plans and user-owned scale/letter mapping. Focus uses
  saved timestamps and pause/resume; no continuous background execution claim.
- Advanced Pro source: timeline, duration-only dependency path, priority reasons,
  workload/capacity, custom fields/values, saved AND/OR views and bounded local rules.
- Full JSON/ZIP manifest/hash/assets preview/merge/replace/Undo; mapped CSV and
  canonical task CSV, Markdown checklists/plain lines; CSV/MD/PDF/ICS summaries;
  Pro XLSX, timeline/study PDF and safe board template JSON.
- Android durable shared-text inbox commits before ack; user-initiated clipboard.
  iOS App Group/BoardsShare extension source is implemented but not built on Mac.
  Store IDs/signing are not configured.

This list describes implemented scope, not complete parity with the master prompt.
[Boards matrix](HANDY_BOARDS_FEATURE_MATRIX.md) records missing interactions and QA.

Handy Boards continuation: Table columns/cell edits; grouped List; assignee/estimate/
reminder/archive filters and attachment-link search; timed start editor; Calendar
week/day and optional class overlay; month drag reschedule with confirmation/Undo;
Timeline move/resize/milestones; bounded launch/resume recurrence; full rule editor/
preview; template JSON/ZIP with custom defaults/subtasks and explicit recurrence
opt-in. Exact remaining scope stays in the Boards feature matrix.

Boards reports use actual saved focus segments for day/week workload and retained
completion transitions for history. Saved views support repeated-property AND/OR
conditions, ranges, reminder/archive predicates and persisted sort/group choices.
Grade letter mapping accepts readable lines (`A = 90`), not JSON in product UI.

Boards Study adds a dedicated exam editor for date/time/duration/room/materials
on the existing task. It lists exams by deadline with task progress per subject;
Calendar/Kanban/category/task details keep the same UUID. It remains opt-in.

Boards UI: locale-aware board-zone deadline labels (portable dates unchanged),
localized priority explanations/weekdays/common validation errors, named control
semantics, Ctrl/Cmd+Enter save and Cmd+N/Cmd+F capture/search alternatives.

Boards remaining-work batch: optional board/resource calendars and holidays;
advanced Study/exam report + CSV; local Trello JSON subset with mapping preview;
SQLite lazy versioned records/assets and indexed paged List/Table; real IndexedDB
indexed search with asynchronous file bodies; cancellable native streamed ZIP/PDF,
large staged ZIP restore; EN/VI owned error catalog; opt-in Android/iOS home widget
payload and launcher shortcuts (iOS native source unverified without Mac). No extra
production seed data. Exact test/device coverage stays in the Boards matrix.
