# Handy Suite — làm lại UI/UX

## Vòng 7: Docs gợi ý mép giấy có duyệt

Nhận ảnh → xem gợi ý bốn góc → chủ động Dùng gợi ý hoặc kéo tay → Lưu trang.
Xử lý local trên lưới nhỏ có giới hạn, không gọi camera/cloud/OCR mới, không tự
cắt hay ghi file. Chỉ gợi ý tờ giấy sáng nổi bật trên nền tối đủ tương phản;
ảnh mờ, kín khung hoặc nhiều vùng lớn không chắc chắn chuyển sang kéo tay.
Gợi ý đến muộn không được thay góc đã kéo; áp dụng/reset là thao tác rõ ràng.
Giữ ảnh gốc, preset/contrast, rectify, cancel/retry và session/page ID hiện hữu.
Không claim máy đọc đúng mọi mép hoặc đã kiểm camera thật từ fixture tổng hợp.

## Vòng 6: Spend xác nhận số dư từ dữ liệu hiện tại

Từ Today xem phạm vi tài khoản đã xác nhận → chọn tài khoản → nhập/xác nhận số
dư thật. Ghi mốc cả khi chênh lệch bằng 0, không tạo giao dịch 0 đồng. Khi có
chênh lệch, tính lại từ state mới nhất trong transaction queue; lưu adjustment
và mốc xác nhận cùng một commit. Lỗi giữ nguyên ledger/mốc và nội dung form,
Undo trả cả hai về trước; backup/reload giữ metadata. Không sửa BigInt, pending,
refund/transfer, schema/database hoặc suy ngày mở tài khoản thành ngày đối chiếu.
Chỉ thống kê tài khoản thực sự tham gia Safe to Spend; không giả kết nối bank hay
xác nhận tất cả từ một tài khoản. Thông tin ngày xác nhận không thay lời nhắc rằng
số dư chỉ dựa trên bản ghi; không lộ số tiền khi đang ẩn. Màn 320px/200% cuộn được.

## Docs: giữ nhiều tệp văn bản mà không xoá bản cũ

Reader retains a 1 MB per-text-file bound and 500 documents, with a bounded
24 MB serialized library instead of the former 8 MB. Scan/PDF/writer keep their
own type-specific limits. A larger reader library/ZIP is explicitly version 3;
small v1/v2 archives retain their format and continue loading. Reject mislabeled
legacy oversized archives, corruption and quota failures without partial writes.
Keep namespace, IDs, metadata, source bytes and recovery/reset behavior. No
automatic eviction of owned documents and no unbounded JSON/ZIP loading.

## Tiếp tục: Keep xuất catalog bộ sưu tập

Card image-export continuation: PNG/JPEG must await actual asset retrieval and
image decoding before painting. A slow photo must not silently become an empty
box. Coalesce loads shared by the canvas/export; keep an actionable export error
for undecodable files, allow retry and dispose codecs/images if the studio closes.
Do not change scene IDs, stored image bytes or crop transforms.
PDF must use the same bundled Medium/SemiBold faces as the canvas when supplied,
rather than mapping both to Regular/Bold. Existing caller font maps with only
400/700 retain their fallback behavior; imported scene weights remain unchanged.

Card template-quality continuation: the real-font audit found no clipped default
text but many initial captions/contact values below 8 pt. Raise text size to at
least 8 pt only while constructing bundled starter scenes; do not rewrite saved
designs, user templates, imported documents or the text-layout engine. Re-render
all 144, inspect the priority twenty first, and retain small-text/overflow review
for user-authored layouts. Reject global font scaling or auto-fitting saved work.

Forms template-quality continuation: preserve all 22 schemas, IDs, published
versions and validation. While filling, explain Required/Optional in the input
helper and accessibility hint, using the evaluated requirement rather than only
the schema flag. Authored hints/errors wrap instead of disappearing on large
text. Display-only blocks/calculations are not announced as optional questions.
At 320px/200% show the complete question above decorated controls instead of a
single-line floating label. Keep screen-reader field naming, typed values and
validation. An unanswered calculation asks for its source numbers, without a
technical exception. Do not change formula semantics or submission snapshots.

- Câu hỏi: Tôi sẽ gửi những món nào và file sẽ trông ra sao? Từ bộ sưu tập,
  mở Catalog → xem trang → lưu PNG trang đang xem hoặc PDF tất cả trang.
- Mặc định chỉ các món đã sở hữu. Bật thêm mong muốn/đang đặt nếu cần; status
  luôn có chữ. Giá chỉ xuất khi chủ động bật. Không xuất serial, vị trí, người
  mượn, hoá đơn, ghi chú riêng hoặc đường dẫn file nội bộ.
- Sáu món một trang A4; preview lấy đúng ảnh/name/status đang xuất; ảnh thiếu
  có nhãn rõ. PNG/PDF là bản trình bày raster, không thay backup editable.
- Bộ rỗng hướng dẫn quay lại thêm món; đang dựng có tiến độ; lỗi giữ lựa chọn,
  Hủy file picker không báo đã lưu. Không ghi inventory khi preview/export.
- 320px/chữ 200% cuộn được; tên dài không bị cắt khỏi file, nút có 48dp mục tiêu;
  màn rộng tách preview và điều khiển. Từ chối một ảnh siêu dài, giá tổng nhiều
  tiền tệ, tự chia sẻ ra ngoài hoặc dùng ảnh stock thay ảnh của người dùng.

## Phần tiếp tục sau vòng 3: hợp đồng luồng ngắn

- Recall: thêm nhiều cặp hỏi/đáp bằng dán văn bản, xem trước rồi lưu một lần;
  giữ note/reverse/cloze và lịch cũ. Sheet đơn vẫn nhanh; màn dán cuộn 320–1440,
  lỗi giữ nguyên nội dung, sửa text vô hiệu bản preview cũ. Không tự đọc clipboard.
- Trip: chọn lịch khung 1 ngày/cuối tuần/city break rồi xem trước; tên/địa điểm
  thật do người dùng sửa. Không tạo lượt ghé, booking hay expense từ preset;
  lưu atomic cùng chuyến, vẫn giữ mọi tem cũ. Timeline là trục chính.
- Bookmark: tác vụ mạng mặc định một lượt nhỏ có Hủy/tiến độ, batch lớn nằm sau
  Advanced; trạng thái lấy bài rõ, không giả tải được bài đăng nhập/video.
- Tools/Dev: công việc phổ biến luôn ở bench; tool hiếm vẫn tìm được bằng search,
  pins/deep links cũ còn hiệu lực. Disclosure không sửa dữ liệu persisted.

Tiếp tục áp dụng app-screen rules của design-taste-frontend và
frontend-ui-engineering bằng Flutter; giữ hướng riêng đã chốt, không bốc style
web chung để áp lại cả suite. Kiểm chứng bằng màn thật và test trước khi chốt.

## Hợp đồng Codex 05/11/2026

Yêu cầu mới của chủ repo ưu tiên 14 sản phẩm độc lập; các quy định cũ bắt buộc cùng
khung Handy, cấm icon/màu riêng của thói quen hoặc áp một kiểu dashboard không còn
chi phối những thay đổi mới. [14 hợp đồng thiết kế](product-review/DESIGN_IDENTITIES.md)
ghi persona, câu hỏi chính, signature, wireflow, trạng thái và acceptance trước code.
Cấu hình đã chuyển về từng app tại `lib/design/identity.dart`; giữ API renderer cũ
để tương thích, không nhận việc di chuyển cấu hình là đã xong redesign.

Lát triển khai đầu: Habit có editor diện mạo độc lập (không đổi lịch); Forms giữ
không gian dữ liệu bằng nhãn phạm vi ngay tại footer, không thêm card thống kê;
Media phân biệt file gộp để chia sẻ với project chứa ảnh gốc, duyệt trước xuất.
Empty/loading/error và quyền sở hữu dữ liệu được giữ. Xác nhận destructive/import
vẫn cần preview; không thêm xác nhận cho check-in hoặc đổi màu chưa lưu.

Capture trước/sau dùng Flutter widget render thật, lưu tách ở
`docs/product-review/evidence/before` và `after`; không phải ảnh thiết bị. Kiểm
tra 320/390, tablet/desktop, VI/EN và dark theo độ phủ thực tế từng suite; chưa
khẳng định tất cả tổ hợp đã được kiểm chứng.

Toàn bộ UI, UX và flow được **làm lại từ đầu**. UI cũ chỉ là danh sách chức năng cần
giữ (cùng [FUNCTIONS](FUNCTIONS.md)), không bao giờ là mẫu bố cục hay flow. Engine,
storage, files, ZIP, adapter native và store giữ nguyên vì đã có test và quy tắc an
toàn dữ liệu.

## Quy trình bắt buộc

Mỗi app phải đi qua hai skill trước khi có code (xem `CLAUDE.md`, mục UI/UX rule):

1. `design-taste-frontend` → `references/app-screens.md`: kê dữ liệu và việc người
   dùng làm, câu hỏi chính của từng màn hình, phát hiện cần thấy đầu tiên, "gương
   mặt" của app, **một yếu tố đặc trưng chỉ app này có**, rồi soát ảnh chụp theo
   §2.7.
2. `frontend-ui-engineering`: hợp đồng thiết kế (việc chính, hành động chính, trạng
   thái, quy tắc responsive, mẫu bị loại bỏ), a11y, kiểm tra ở 320, 768, 1024 và
   1440px.

Hợp đồng của từng app được viết ở cuối file này trước khi code.

## Hướng thiết kế chung: "Màu theo app"

Style `accent-ladder` của design-taste-frontend (`.taste-skill/tools/direction.json`),
giữ bảng màu và font của bộ:

- **Mỗi app sở hữu một màu.** Màu đậm (đủ 4.5:1 với chữ trắng) dùng cho nút chính
  và dấu chọn; màu nhạt dùng cho vùng chọn và panel trả lời. Nền và khung trung
  tính, không dùng nền kem.

  | App    | Màu       | App      | Màu       |
  | ------ | --------- | -------- | --------- |
  | Tools  | `#E8590C` | Bookmark | `#0E7490` |
  | Keep   | `#B7791F` | Docs     | `#1D5FBF` |
  | Recall | `#4D7C0F` | Media    | `#C2255C` |
  | Dev    | `#0F8A5F` | Spend    | `#2E7D32` |
  | Habit  | `#B42318` |          |           |

  Không dùng tím hoặc chàm.

- **Màu cho dữ liệu** (thêm 2026-11-01, theo yêu cầu "mỗi app một màu làm màu sắc bị hạn
  chế"): màu riêng của app chỉ ở nút chính, dấu đang chọn và logo. Thêm **bảng 8 màu nhận
  diện dùng chung cả bộ** (`HandyPalette`, `kit/palette.dart`) cho chính đồ vật của người
  dùng: bộ sưu tập (Save), nơi để đồ (Keep), bộ thẻ (Recall), thư mục đọc (Docs), hướng dẫn
  (Media), phương thức HTTP (Dev). Nhóm công cụ của Tools **không** có màu: đó là danh mục
  của app, không phải đồ của người dùng (soát lại 2026-11-01).
  - Mỗi màu có hai vai: **chấm** đậm (8–14 px) cạnh tên, và **nền nhạt** cho vùng nhỏ (chữ
    cái đầu của món đồ, nhãn phương thức). Chữ luôn là mực trung tính nên luôn đủ 4.5:1; màu
    không bao giờ là cách duy nhất để phân biệt (luôn đi kèm tên). **Không tô màu icon theo
    nhóm** (dấu hiệu giao diện máy tạo): icon luôn xám, màu nằm ở chấm.
  - Thứ tự 8 màu, hai vị trí liền nhau cách nhau khoảng 60° trở lên: lam 220°, hổ phách 42°,
    lá 128°, hồng 338°, mòng két 173°, cà chua 8°, da trời 202°, ô liu 68°. Lam đứng đầu,
    cà chua xếp sau vì nhóm đầu màu đỏ dễ bị đọc thành "quá hạn". Không tím, không chàm.
  - Trong mỗi app, bỏ mọi màu cách màu của app dưới 25° (luôn bỏ ít nhất màu gần nhất), để
    màu của đồ vật không lẫn với màu hành động; còn 6–7 màu dùng theo vòng.
  - Một đồ vật **giữ một màu ở mọi màn và mọi bộ lọc**. Gán theo thứ tự ổn định: bộ sưu
    tập theo vị trí gốc, bộ thẻ và thư mục theo tên, nơi để đồ theo thứ tự toàn bộ nơi của
    nhà (không theo nhóm đang hiện), hướng dẫn theo thứ tự tạo, phương thức HTTP theo nghĩa
    (GET lá, POST lam, PUT hổ phách, PATCH da trời, DELETE cà chua). Thư mục con dùng màu
    của thư mục cha. Món đồ trong Keep mang nền nhạt của nơi nó đang ở.
  - Tối: chấm sáng thêm 18% về phía trắng, nền nhạt là nền tối trộn 22% màu.
  - Loại bỏ: chữ màu, nền màu đậm diện lớn, cầu vồng không mang nghĩa, màu trên chrome.
- **Chữ:** Bricolage Grotesque cho tiêu đề và con số trả lời, Geist cho chữ thường.
  Cả hai đều OFL, được đóng gói sẵn, có đủ tiếng Việt và tabular figures. Số hiển
  thị dùng `formatFigure` (vi `1.385.000,5`); sao chép và xuất giữ giá trị gốc.
- **Logo:** mỗi app cùng một khung, khác biểu tượng và màu, dùng cho icon app,
  splash và thanh trên.
- **Hình khối:** bo góc 12 cho thẻ và 8 cho control; viền 1px; không bóng đổ trên
  vật đứng yên.
- **Chuyển động:** là phản hồi và sự liền mạch, không phải màn trình diễn (kit
  `motion.dart`): đổi trạng thái thì mờ dần sang (`HandySwap`), khối to ra thì lớn dần
  (`HandyReveal`), ảnh món đồ bay từ dòng sang trang chi tiết (Hero), chuyển trang
  theo nền tảng. 150–320 ms, easeOutCubic. Tắt hẳn khi hệ điều hành bật giảm chuyển
  động.
- **Cài đặt:** mở từ thanh trên, không bao giờ là tab. Desktop dùng hai cột, điện
  thoại xếp chồng; mọi điều khiển tự lưu; nhóm Đặt lại nằm cuối.

## Hành vi theo nền tảng (mọi app)

| Nền tảng | Quy tắc                                                                                                                                                                   |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Android  | Predictive back; tràn viền (edge-to-edge); bottom sheet kéo được; rung nhẹ khi sao chép; icon đơn sắc theo theme.                                                         |
| iOS      | Vuốt từ mép để quay lại; công tắc, hộp thoại và bộ chọn ngày giờ kiểu iOS (`.adaptive`, Cupertino picker); rung nhẹ; theo cỡ chữ hệ thống; tôn trọng safe area.           |
| Windows  | Bố cục rộng nhiều cột; phím tắt (`Ctrl+K` mở bảng công cụ, `Ctrl+L` về ô nhập, `Enter` ghi, `Ctrl+Shift+C` chép, `Ctrl+S` lưu, `Esc` thoát); hover; thanh cuộn luôn hiện. |
| Web      | URL theo màn hình (`/tool/<id>`, `/settings`), nút back của trình duyệt dùng được; viền focus rõ; cài được như ứng dụng (PWA) và chạy offline.                            |

## Hợp đồng: phần dùng chung thêm vào kit (2026-11-02)

Chạy skill: `draw.mjs --app --kind workspace` (`.taste-skill/kit-more`). Skill đưa ra
achromatic-ledger và editorial-greeting, nhưng không dùng: đây là các mục nằm trong màn
Cài đặt và thanh trên có sẵn của từng app, nên giữ accent-ladder của bộ app (skill:
"một component thì theo thiết kế xung quanh").

**Tự sao lưu** (`HandyAutoBackupSection`, mục trong Cài đặt)

- Việc: dữ liệu không mất khi máy hỏng hay mất, mà không cần tài khoản hay máy chủ.
- Câu hỏi của mục: "Lần sao lưu gần nhất là khi nào, và nằm ở đâu?". Câu trả lời là
  dòng đầu, chữ lớn nhất của mục, ví dụ "Hôm nay 09:30 · Google Drive › Handy".
- Hành động chính: "Sao lưu ngay". Công tắc bật/tắt nằm ở dòng tiêu đề.
- Điều khiển đều tự lưu:
  - Chọn thư mục (tên thư mục hiện bên cạnh).
  - Tần suất: mỗi ngày hoặc mỗi tuần.
  - Số bản giữ lại: 3, 7, 14 hoặc 30.
  - Mã hóa bằng mật khẩu.
- Mã hóa:
  - Đặt mật khẩu gồm ô mật khẩu, ô nhập lại, và một câu cảnh báo luôn hiện: "Quên mật
    khẩu thì không mở được bản sao lưu".
  - Có "Đổi mật khẩu" và "Tắt mã hóa".
  - App không lưu mật khẩu; xem `handy_core/sealed.dart`.
- Trạng thái:
  - Chưa bật: một câu nói lợi ích, kèm nút "Chọn thư mục".
  - Đang chạy: chỉ báo tiến trình trên dòng trạng thái, nút "Sao lưu ngay" tạm khóa.
  - Lỗi: một câu nói cái gì hỏng (mất quyền thư mục, ghi lỗi) kèm "Thử lại" hoặc "Chọn
    lại thư mục". Màu báo lỗi chỉ ở icon nhỏ.
  - Không hỗ trợ (Web): một câu "Trình duyệt không cho app ghi vào thư mục; dùng Sao lưu
    thủ công", không có điều khiển chết.
- Theo nền tảng:

  | Nền tảng | Nơi lưu                                                                                  |
  | -------- | ---------------------------------------------------------------------------------------- |
  | Android  | Thư mục chọn qua bộ chọn của hệ thống (máy, Google Drive, OneDrive…), giữ quyền lâu dài. |
  | iOS      | Thư mục của app trong ứng dụng Tệp; iCloud Backup của máy mang theo. Không chọn thư mục. |
  | Windows  | Thư mục bất kỳ, kể cả thư mục OneDrive hay Google Drive đã đồng bộ.                      |
  | Web      | Không có.                                                                                |

- Khi nào chạy: lúc mở app và lúc app ra nền, nếu đã đến hạn và dữ liệu có thay đổi.
  Không chạy ngầm khi app đóng, và trong mục nói rõ điều này.
- Rộng 320–1440: một cột; từ 840 thì nhãn bên trái, điều khiển bên phải, theo trang
  Cài đặt hiện có.
- Loại bỏ: thanh tiến trình giả, đếm ngược, màu thương hiệu trên công tắc, icon trong ô
  màu.

**Mở bản sao lưu đã mã hóa** (`openSealedBackup`): khi nhập một tệp `.hseal`, app hỏi
mật khẩu trong hộp thoại:

- Một ô mật khẩu có nút hiện/ẩn, "Mở" và "Hủy".
- Sai mật khẩu: báo ngay dưới ô và giữ hộp thoại để nhập lại.
- Đang giải mã: nút "Mở" thành chỉ báo tiến trình; thường mất 1–4 giây.
- Hủy: không thay đổi gì.

**Các app khác trong Handy** (`HandyMoreApps`, cuối Cài đặt, trên mục Giới thiệu):

- Mỗi app là một dòng: chấm màu của app, tên, một câu nói app làm gì.
- Chạm để mở trang store (Android, iOS) hoặc trang web của app (Web, Windows), chỉ khi
  người dùng chạm.
- Không hiện app đang mở. Không ảnh quảng cáo, không huy hiệu "Mới".

**Widget màn hình chính** (Android trước; iOS cần Xcode nên chưa làm):

- Habit: tên thói quen và hạt hôm nay; chạm vào hạt là đánh dấu thói quen dạng có hoặc
  chưa, còn loại khác thì mở app ở thói quen đó.
- Spend: "Còn tiêu được hôm nay" với một con số lớn.
- Recall: số thẻ đến hạn, kèm nút "Ôn".
- Nền trắng hoặc tối theo hệ thống, một chấm màu của app, chữ Geist. Khi trống thì nói
  thật ("Hôm nay không còn việc"). Số được cập nhật mỗi khi dữ liệu trong app đổi.

## Hợp đồng: Handy Tools

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: phép tính, số tiền VND (10⁵–10⁹), phần trăm, kỳ hạn 1–360 tháng,
  giá trị kèm đơn vị, ngày, đoạn văn bản (1–5.000 dòng), mã màu, nội dung QR (link,
  Wi-Fi, liên hệ, sự kiện), mật khẩu, chuỗi bước xử lý văn bản đã lưu.
- Người dùng: một người, chủ yếu trên điện thoại, mỗi lần 10–60 giây; đôi khi dùng
  desktop để xử lý văn bản. Ưu tiên tiếng Việt.
- Việc thường gặp nhất: **gõ ra một con số rồi chép đi**. Tiếp theo là đổi đơn vị,
  chia tiền, dọn văn bản rồi chép, tạo QR Wi-Fi, tạo mật khẩu.

**Câu hỏi của màn hình** (skill §2.2): "Cái mình vừa gõ ra kết quả bao nhiêu?"
Khối lớn nhất là đáp án. Phát hiện đọc đầu tiên là dòng "Hiểu là…" cho biết app
đã hiểu ý gì.

**Flow mới** (không còn danh sách công cụ và trang con cho từng công cụ):

1. Mở app thì ô nhập đã được focus sẵn: **Bàn làm việc** là màn hình duy nhất.
2. Gõ hoặc dán bất cứ thứ gì: `1.385.000 / 3`, `5 km sang mi`, `15% của 2.400.000`,
   `#E8590C`, `2026-12-31 đến hôm nay`, một đoạn văn bản, một link. Đáp án hiện
   ngay bằng chữ lớn màu cam, kèm dòng "Hiểu là: Đổi đơn vị" và các cách hiểu khác
   dưới dạng chip.
3. `Enter` hoặc nút Sao chép thì đáp án vào **băng kết quả**.
4. Muốn nhập có cấu trúc (lịch trả nợ, chia hóa đơn, thuế…): chạm chip "Hiểu là"
   hoặc mở **bảng công cụ** (`Ctrl+K`, bottom sheet trên điện thoại). Form của công
   cụ thay chỗ ô nhập ngay tại bàn (`/tool/<id>`), chip `✕` để quay về ô nhập tự do.
5. Văn bản: chip công cụ văn bản áp dụng nối tiếp và tạo thành một **chuỗi** ngay
   tại chỗ (`Bỏ dấu → Viết thường → Lọc trùng`); "Lưu chuỗi" biến nó thành quy trình
   dùng lại được. Không còn trang tạo quy trình riêng.
6. QR và mật khẩu là các chế độ của bàn: xem trước trực tiếp, nút chính Lưu ảnh hoặc
   Sao chép.

**Yếu tố đặc trưng:** **băng kết quả**, như cuộn giấy của máy cộng tiền. Mỗi dòng
gồm thứ đã gõ (chữ xám) và đáp án (chữ đậm, số tabular, căn phải). Dòng mới nhất
nằm trên cùng, chạm vào để dùng lại. Cuối băng có **tổng các đáp án là số**. Băng
chỉ lưu trong phiên, không ghi ra đĩa (có thể chứa dữ liệu riêng tư).

**Bố cục:** shell "No sidebar" (skill §3.1, dành cho sản phẩm ít điểm đến). Thanh
trên 56px gồm logo, tên app, ô "Tìm công cụ · Ctrl K" và nút cài đặt.

- Desktop từ 900px: cột ở giữa rộng 1100px, chia bàn làm việc 640px và băng 380px.
- Điện thoại: bàn ở trên, băng ở dưới; bảng công cụ là bottom sheet; nút chính ở
  thanh dưới trong tầm ngón cái.

**Trạng thái:**

- Rỗng: các ví dụ chạm vào để điền thử, và các công cụ đã ghim.
- Đang gõ dở: không báo lỗi.
- Lỗi: một dòng nằm dưới ô nhập.
- Văn bản lớn hơn 20.000 ký tự: chờ người dùng nhấn Chạy.
- Băng rỗng: một câu hướng dẫn.

**Loại bỏ:** danh sách công cụ dạng hàng dài, tab dưới "Công cụ / Quy trình",
sidebar, mỗi công cụ một trang con, trang tạo quy trình riêng.

**Ghi chú triển khai** (`apps/handy_tools/lib/bench/`): `intent.dart` hiểu ý câu
gõ tự do (thuần Dart, có test); `free_bench.dart` là ô nhập tự do; `tool_panel.dart`
là form công cụ; `tape.dart` và `tape_view.dart` là băng kết quả; `catalog.dart` là
bảng công cụ; `shelf.dart` là kệ công cụ trên desktop; `bench_page.dart` gồm shell,
phím tắt và bố cục. Route: `/`, `/tool/<id>`, `/settings`.

### Bổ sung 2026-11: kiểu chữ, lương, đọc số, âm lịch, VietQR, phụ đề

Chạy lại skill (app-screens, `accent-ladder` giữ palette/type của suite, seed 1976563080,
`.taste-skill/tools-more`). Không thêm màn hình hay shell mới: mọi thứ là form trên **bàn**,
đáp án vào **băng**. Dữ liệu: lương 5–200 triệu đ/tháng, 0–4 người phụ thuộc, 4 vùng; số
tiền tới hàng nghìn tỷ; ngày 1900–2100; tài khoản ngân hàng 6–19 ký tự; tệp phụ đề ≤ 1 MB,
≤ 10.000 câu. Người dùng: nhân viên xem offer, chủ shop nhỏ tính lương, kế toán ghi hóa đơn,
người bán hàng in mã chuyển khoản, người xem phim lệch phụ đề.

| Công cụ                | Câu hỏi của form                                               | Khối lớn nhất / phát hiện                                           | Hành động chính |
| ---------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------- | --------------- |
| `case` (gộp 4 công cụ) | "Văn bản này viết lại kiểu chữ nào?"                           | Văn bản đã đổi                                                      | Sao chép        |
| `salary`               | "Mình thực nhận bao nhiêu?" (hoặc "phải trả gross bao nhiêu?") | Dòng Thực nhận (hay Lương gộp) màu cam; dưới là phiếu lương trừ dần | Sao chép        |
| `number-words`         | "Dòng 'Bằng chữ' ghi gì?"                                      | Câu tiếng Việt viết hoa đầu, kèm "đã hiểu số là …"                  | Sao chép        |
| `lunar`                | "Hôm đó là ngày mấy âm / dương?"                               | Ngày âm (hay dương), rồi can chi, tiết khí                          | Sao chép        |
| QR "Chuyển khoản"      | "Mã này chuyển đúng tài khoản chưa?"                           | Mã QR kèm dòng đọc lại: ngân hàng · số TK · số tiền · nội dung      | Lưu ảnh         |
| Phụ đề                 | "Thời gian khớp chưa?"                                         | 5 câu đầu: giờ mới, giờ cũ màu xám                                  | Lưu .srt/.vtt   |

**Yếu tố đặc trưng giữ nguyên là băng.** Phiếu lương là băng thu nhỏ, hai khối: trên là
lương gộp trừ BHXH, BHYT, BHTN, thuế TNCN (dấu trừ) ra đúng số thực nhận; dưới là cách
tính thuế (giảm trừ, thu nhập tính thuế, thuế từng bậc "Bậc 2 · 10% × 8.575.000"). Tất
cả là số thật từ engine và cộng lại khớp; chạm dòng nào chép số đó. Tên công cụ là "Tính
lương" (tên dài "Lương Gross / Net" bị cắt ở 320 px). Dưới phiếu là một dòng xám nêu bộ quy định đang
dùng ("Quy định từ 2026-07-01 · NĐ 161/2026, NQ 110/2025, Luật 109/2025") và trần đóng.

**Quy định có ngày hiệu lực.** Form lương có ô "Áp dụng quy định ngày" (mặc định hôm nay,
chọn bằng `pickHandyDate`). Mọi tham số (lương đóng BH, giảm trừ bản thân/người phụ thuộc,
lương cơ sở, lương tối thiểu vùng, tỷ lệ BHXH/BHYT/BHTN, biểu thuế) nằm trong nút "Quy định
đang dùng · sửa": bấm ra các ô trống có gợi ý là giá trị của bảng; ô nào điền thì ghi đè, xóa
trắng là về bảng. Có ô ghi đè thì dòng xám ghi "Đã sửa N tham số".

**Đọc số:** chọn đơn vị (đồng / không đơn vị) và giọng (Bắc: linh, nghìn / Nam: lẻ, ngàn).
Câu tiếng Anh nằm dưới, chữ xám, có nút chép riêng. **Âm lịch:** một nút đổi chiều
(Dương → Âm / Âm → Dương); chiều Âm → Dương hiện ô ngày, tháng, năm và "tháng nhuận".
**Kiểu chữ:** một ô văn bản và 4 nút liền (HOA / thường / Đầu Từ / Đầu câu); dưới
352 px (nút hẹp hơn 88 px) 4 nút thành một hàng chip để chữ không bị bẻ. Chuỗi xử lý
văn bản vẫn có 4 chip cũ (chuỗi đã lưu vẫn chạy).

**VietQR** là kiểu thứ sáu trong QR: chọn ngân hàng (ô gõ để lọc, danh sách cố định trong
app), số tài khoản, số tiền và nội dung (không bắt buộc; nội dung tự bỏ dấu, ≤ 25 ký tự).
Dưới mã là dòng đọc lại và cảnh báo "Kiểm tra tên chủ tài khoản trong app ngân hàng trước
khi chuyển". Lưu PNG/SVG/PDF, chia sẻ, lịch sử như các kiểu khác.

**Phụ đề là một chế độ của bàn, không phải công cụ registry** (`/tool/subtitles`, nhóm "Tạo
mới" cạnh QR và Mật khẩu). Lý do: nó làm việc với một tệp (mở, xem trước, kiểm tra cả tệp, lưu
tệp) chứ không phải chuỗi vào → chuỗi ra; code nằm ở `handy_media_engine` và registry engine
Tools không phụ thuộc Media. Bố cục: ô nguồn (dán hoặc "Mở tệp"), nút SRT/WebVTT, ô dời (ms)
với nút −0,5 s / +0,5 s, xem trước 5 câu đầu trước/sau, nút Lưu. Lưu đọc lại cả tệp, dựng
lại, đọc lại kết quả và so số câu trước khi ghi; lỗi ở bất kỳ câu nào thì không ghi gì.

**Trạng thái:** rỗng: một câu nói cần điền gì (lương: "Nhập lương gộp hoặc thực nhận");
đang gõ: không báo lỗi; lỗi: một dòng đỏ dưới form, nói giá trị nào sai; không có quy định cho
ngày đã chọn (trước 2024-07-01): lỗi nói rõ ngày sớm nhất; năm âm không có tháng nhuận đó: lỗi
nói tháng nhuận thật của năm; phụ đề rỗng: hướng dẫn dán/mở, giới hạn 1 MB và 10.000 câu;
phụ đề lệch về trước 0: cảnh báo và nút Lưu tắt. Không có trạng thái tải (tính tại chỗ).

**Bề rộng 320–1440:** form một cột; ở 320 px các nút liền 4 lựa chọn vẫn một hàng (nhãn
ngắn); phiếu lương nhãn trái 2 phần, số phải 3 phần, số không bao giờ xuống dòng; từ 900 px
form nằm cột trái, băng cột phải như cũ. Phụ đề: điện thoại ô nguồn cao 220 px rồi bảng điều
khiển; desktop vẫn trong cột bàn (không tách khung riêng).

**Nền tảng:** Android/iOS: bàn phím số cho tiền và số TK, nút Back đóng form về ô nhập; chia
sẻ qua sheet hệ thống. Windows/Web: Esc đóng form, Ctrl K tìm công cụ, URL `#/tool/salary`,
`#/tool/number-words`, `#/tool/lunar`, `#/tool/case`, `#/tool/subtitles`, `#/tool/qr`.
Ô nhập tự do còn hiểu `1.250.000 bằng chữ`, `lương 25.000.000`, `net 20.000.000`,
`2026-09-25 âm lịch`.

**Loại bỏ:** bảng tham số dài luôn hiện, mỗi kiểu chữ một công cụ, trang phụ đề riêng có
AppBar, danh sách ngân hàng dạng lưới logo (không tải logo từ mạng).

## Hợp đồng: Handy Dev

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: dữ liệu dán vào (JSON phản hồi API 1–500 KB, YAML/TOML/XML/CSV cấu
  hình, JSONL, JWT, chuỗi Base64, URL đã mã hóa, file `.env`, HAR), biểu thức RE2,
  JSON Schema; request HTTPS (method, URL có `{{biến}}`, header, xác thực, body),
  phản hồi (mã trạng thái, thời gian, dung lượng, body), collection, environment.
- Người dùng: lập trình viên, chủ yếu trên desktop (Windows, web), đôi khi dùng điện
  thoại để giải mã nhanh một JWT hay một chuỗi Base64. Mỗi lần vài phút.
- Việc thường gặp nhất: **dán một thứ vào rồi xem bên trong có gì**: định dạng JSON,
  giải mã JWT/Base64/URL. Tiếp theo: đổi định dạng, gửi một request rồi đọc phản hồi,
  thử regex trên dữ liệu mẫu.

**Câu hỏi của màn hình** (skill §2.2)

- Soi dữ liệu: "Thứ mình vừa dán là gì và bên trong có gì?" Khối lớn nhất là kết quả
  có cấu trúc (cây JSON, bảng, văn bản đã đổi). Phát hiện đọc đầu tiên là thanh
  trạng thái.
- Request: "Gọi có thành công không, nhận về gì?" Khối lớn nhất là phản hồi. Phát
  hiện là `200 OK · 182 ms · 4,1 KB`.

**Flow mới** (không còn tab "Data tools / API requests", danh sách 28 công cụ hay
trang riêng cho từng công cụ):

1. Mở app vào **Soi dữ liệu**. Dán hoặc mở file thì app tự nhận dạng (JSON, JSONL,
   YAML, TOML, XML, CSV, JWT, Base64, URL mã hóa, `.env`, HAR, lệnh cURL) và hiện
   "Hiểu là: JWT" kèm các cách hiểu khác.
2. Kết quả hiện ngay theo **lăng kính** mặc định của loại đó (JSON hiện dạng cây,
   JWT hiện header và payload). Các lăng kính khác cùng loại là chip: Định dạng, Rút
   gọn, → YAML, → TypeScript, JSONPath…, Kiểm tra Schema…; lăng kính cần tham số mở
   một ô ngay bên dưới.
3. Văn bản thường có các lăng kính mã hóa (Base64, URL, SHA) và **Regex**. Các lăng
   kính an toàn nối được thành chuỗi và lưu thành quy trình.
4. Dán một lệnh cURL thì nhận dạng thành request và có nút "Mở trong Request".
5. **Request**: danh sách collection ở bên trái trên desktop (trên điện thoại là
   màn hình riêng). Chọn một request thì trình soạn hiện ở bên phải: method, URL,
   Gửi; header, xác thực và body nằm trong các tab gọn. Phản hồi hiện ngay bên dưới
   và dùng lại cây JSON của phần Soi dữ liệu.

**Yếu tố đặc trưng:** **thanh trạng thái**, như thanh dưới cùng của trình soạn code.
Khi soi dữ liệu, nó ghi `JSON · 2,4 KB · 38 khóa · hợp lệ` cộng đường dẫn JSONPath
của nút đang chọn (`$.items[3].price`), chạm vào để chép. Khi gọi API, nó ghi
`200 OK · 182 ms · 4,1 KB`. Phần màu của app đánh dấu trạng thái tốt; lỗi dùng màu
đỏ.

**Bố cục:** thanh trên chứa logo, tên app, nút chuyển hai khu vực `Soi dữ liệu |
Request` (có 2 điểm đến thì dùng segmented, không dùng sidebar hay tab dưới), Ctrl K
và cài đặt.

- Desktop từ 900px: Soi dữ liệu chia hai cột (nguồn | kết quả); Request chia hai
  cột (danh sách | trình soạn và phản hồi).
- Điện thoại: mỗi lúc một vùng; nguồn ở trên, kết quả ở dưới; danh sách request rồi
  chạm vào để mở trình soạn.

**An toàn (giữ từ bản cũ):** bí mật xác thực chỉ giữ trong phiên và bị loại khỏi
mọi lần lưu hay xuất; lưu request qua `sanitizeRequest` (bỏ token trong URL); công cụ
nhạy cảm (JWT, `.env`, HAR, ẩn bí mật) không lưu nháp và không vào chuỗi; chỉ gọi
HTTPS, phản hồi tối đa 1 MB, có hủy và hết giờ; lưu collection lỗi thì giữ nguyên
form để thử lại.

**Trạng thái:**

- Rỗng: các ví dụ chạm vào để thử.
- Không nhận dạng được: hiện như văn bản thường.
- Lỗi phân tích: một dòng có vị trí lỗi.
- Đang gửi request: thanh tiến trình kèm nút Hủy.
- Phản hồi không phải JSON: hiện dạng văn bản.
- Chưa có request: một câu kèm nút "Request mới".

**Loại bỏ:** tab dưới, danh sách công cụ dài, trang riêng cho từng công cụ, form API
dài một cột, trang tạo quy trình riêng.

**Ghi chú triển khai** (`apps/handy_dev/lib/`): `inspect/detect.dart` nhận dạng dữ
liệu, `inspect/lenses.dart` liệt kê lăng kính theo loại và nhóm, `inspect/inspection.dart`
là phần lõi (thuần Dart, có test), `inspect/json_view.dart` vẽ cây JSON và đổi JSON
Pointer sang JSONPath, `inspect/status_line.dart` là thanh trạng thái;
`requests/workspace.dart` lưu bản đã ẩn bí mật và giữ bản đầy đủ trong phiên. Lăng kính
_phân tích_ (JWT, regex, schema, so sánh, JSONPath, chọn trường, HAR) hiện dạng cây;
lăng kính _chuyển đổi_ hiện văn bản. Thanh trên, bảng `Ctrl+K` và thanh chuỗi dùng
chung với Tools qua kit (`HandyTopBar`, `showHandyCatalog`, `HandyChainBar`).

### Bổ sung: bảy lăng kính tiện ích (thời gian, ID, so sánh, cron, hệ cơ số, URL, HMAC)

**Dữ liệu và việc:** mốc Unix 10 hoặc 13 chữ số (đôi khi µs/ns), chuỗi ISO-8601; UUID và
ULID (một cái, hoặc một cột trong log); hai bản văn bản (cấu hình trước và sau, 10–2.000
dòng); một dòng cron; số nguyên (mặt nạ `0xff`, quyền `0o755`, giá trị 64 bit âm); URL có
query (UTM, callback OAuth); body webhook cùng khóa bí mật. Việc thường gặp: "mốc này là
lúc nào?", "cho mình 5 UUID v7", "hai bản khác nhau ở đâu?", "cron này chạy khi nào?",
"−1 ở 32 bit là gì?", "URL này chứa gì, đổi một tham số", "tính HMAC để so với header".

**Câu hỏi và phát hiện:** mỗi lăng kính trả lời một câu, khối lớn nhất là câu trả lời,
thanh trạng thái (yếu tố đặc trưng) ghi phát hiện:

- Mốc thời gian: "Đây là lúc nào?" Giờ trong múi đã chọn, cỡ lớn, màu app; dưới là "3 ngày
  trước". Thanh trạng thái: `giây` / `mili giây`.
- UUID/ULID: "ID này loại gì, tạo lúc nào?" `UUID v7` cỡ lớn, thời điểm bên dưới; danh
  sách nhiều ID thì mỗi dòng một ID kèm phiên bản. Hàng **Tạo**: loại, số lượng (1–1000),
  nút Tạo, thay nguồn bằng ID mới để xem lại ngay.
- So sánh văn bản: "Khác ở đâu?" `+3 −1 dòng` trên thanh trạng thái; dòng bỏ nền đỏ nhạt
  có dấu `−`, dòng thêm nền màu app nhạt có dấu `+` (không chỉ dựa vào màu). Hai cột khi
  khung kết quả rộng từ 600 px, gộp (unified) khi hẹp hơn; có nút đổi. Sao chép lấy bản
  unified.
- Cron: "Khi nào chạy?" Câu giải thích (EN/VI theo ngôn ngữ app) cỡ lớn, rồi các lần chạy
  kế tiếp (giờ trong múi đã chọn + "5 phút nữa"), rồi bảng trường. Thanh trạng thái: lần
  chạy gần nhất.
- Hệ cơ số: số thập phân là dòng dẫn; hex, octal, nhị phân (nhóm 4 chữ số khi hiển thị,
  chép bản gốc), hệ tùy chọn, bù hai theo số bit.
- URL: host là dòng dẫn; scheme, user (mật khẩu chỉ ghi "đã ẩn"), port, path, fragment;
  bảng tham số query đã giải mã, sửa, xóa, thêm được; URL dựng lại ngay bên dưới với nút
  **Chép URL** và **Dùng làm nguồn**.
- HMAC: chữ ký ở dạng văn bản để chép, như các lăng kính mã hóa.

**Flow:** không có trang mới. Dán vào Soi dữ liệu thì app nhận thêm các loại `Mốc thời
gian`, `Số nguyên`, `UUID/ULID`, `Cron`, `URL`; mơ hồ thì "Hiểu là" cho chọn (10 chữ số:
Mốc thời gian | Số nguyên). Văn bản bất kỳ có thêm lăng kính **So sánh văn bản** (ô "So
với" nhiều dòng) và **HMAC** (ô khóa che ký tự, có nút hiện). Tùy chọn của lăng kính là
hàng chip ngay dưới hàng lăng kính, cùng kiểu "Hiểu là": Múi giờ (Giờ máy | UTC) và ô "Độ
lệch khác" (`+07:00`); Số lần chạy (5 | 10 | 20); Số bit (Không | 8 | 16 | 32 | 64) và ô
"Thêm hệ cơ số"; Hàm băm (SHA-256 | SHA-512), Kết quả (hex | Base64), Khóa là (Văn bản |
hex | Base64). Màn hình trống có thêm nhóm **Tạo mới**: UUID v4, UUID v7, ULID, Bây giờ.
Chọn UUID hay Mốc thời gian từ Ctrl K khi nguồn trống thì app tạo sẵn một giá trị.

**Trạng thái:** trống: chip Tạo mới và mẫu Cron, URL; lỗi: một dòng nói trường nào sai
("Phút: 60 nằm ngoài 0–59", "Không vừa 8 bit"); hai bản giống nhau: "Hai bản giống nhau";
quá giới hạn so sánh: một dòng lỗi; cron không bao giờ chạy: "Không có lần chạy nào trong
8 năm tới"; HMAC chưa có khóa: "Điền khóa ở trên"; ID sai trong danh sách: dòng đó báo
lỗi, các dòng khác vẫn hiện. Không có trạng thái tải: mọi thứ tính tại chỗ.

**Độ rộng 320–1440:** kết quả vẫn là cột phải từ 900 px, ở dưới nguồn khi hẹp hơn. Hàng
giá trị chạm để chép, cao tối thiểu 48 px, giá trị dài xuống dòng chứ không cắt. Bảng
query: tên và giá trị cạnh nhau từ 400 px, chồng lên nhau khi hẹp hơn. Hàng Tạo xuống
dòng trên điện thoại. So sánh hai cột chỉ khi đủ chỗ.

**Nền tảng:** Windows/Web: Ctrl K tìm được từng lăng kính, Tab đi qua chip, ô và nút theo
thứ tự đọc; không đổi URL (như Soi dữ liệu). Android/iOS: chép có rung nhẹ (kit); nút Quay
lại như trước. Ô khóa HMAC tắt gợi ý bàn phím và tự sửa.

**An toàn:** HMAC là lăng kính nhạy cảm: khóa chỉ nằm trong ô của phiên, bị xóa khi đổi
lăng kính hay loại dữ liệu, không vào nháp, chuỗi, cài đặt xuất ra hay thông báo lỗi.
Tách URL không hiện mật khẩu.

**Gọn lại 2026-11-03:** tóm tắt HAR và `.env` mẫu đã bỏ (HAR mở như JSON, `.env` như văn
bản). Một lăng kính cho mỗi việc, chiều là chip: "Đổi sang" YAML/TOML/XML/CSV từ JSON,
"Sang JSON" cho YAML/TOML/XML/CSV, JSON thụt lề/một dòng, Base64 và URL mã hóa/giải mã,
băm SHA-256/SHA-512. Dán `#RRGGBB` (chuyển từ Tools) ra HEX/RGB/HSL và độ tương phản
WCAG. Chuỗi đã lưu giữ tên bước cũ nên vẫn chạy. Thêm: "Lọc JSON" một ô nhận đường
dẫn hoặc tên trường; "Suy ra kiểu" chọn TypeScript/JSON Schema bằng chip.

**Loại bỏ:** trang riêng cho mỗi tiện ích, form nhiều bước để tạo UUID, màu theo loại
trường, bảng diff có lưới kẻ.

## Hợp đồng: Handy Keep

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: đồ dùng (tên, chỗ để ghi tự do như "Tủ bếp", "Gác xép", số serial,
  ghi chú, ngày mua, bảo hành đến, bảo dưỡng, người mượn, ngày cho mượn, hẹn trả,
  thùng, một ảnh, tối đa 20 hóa đơn PNG/JPEG/PDF); thùng (tên, chỗ để, ghi chú, nhãn
  QR `handy-keep://box/<id>`). Giới hạn 5.000 đồ, 500 thùng.
- Quy mô thật: một gia đình ghi 20–300 món, 0–30 thùng khi chuyển nhà, 0–5 món đang
  cho mượn, 10–40 món có ngày bảo hành; mỗi tháng thường chỉ vài mốc đến hạn.
- Người dùng: một người, chủ yếu trên điện thoại, đứng giữa nhà hoặc cạnh thùng.
  Desktop dùng khi nhập nhiều đồ một lúc hay in nhãn. Mỗi lần mở vài chục giây.
- Việc, theo thứ tự hay gặp: **tìm xem món đồ đang ở đâu**; thêm nhanh một món kèm
  chỗ để; quét nhãn trên thùng để xem trong thùng có gì; cho mượn và ghi đã trả; xem
  món nào sắp hết bảo hành hay quá hẹn trả; tìm hóa đơn khi cần bảo hành; in nhãn;
  sao lưu.

**Câu hỏi của màn hình** (skill §2.2)

- Màn hình chính: "Món đồ đó đang ở đâu?" Khối lớn nhất là ô tìm kiếm và danh sách
  đồ **xếp theo chỗ ở hiện tại**. Phát hiện đọc đầu tiên là dải "Cần để ý" ngay dưới ô
  tìm kiếm, chỉ hiện khi có việc: "Lan giữ máy khoan, quá hẹn 5 ngày", "Tủ lạnh hết
  bảo hành sau 12 ngày".
- Hồ sơ một món: "Nó đang ở đâu, và còn bảo hành không?" Khối lớn nhất là dòng chỗ ở,
  số liệu ngày đi kèm khoảng cách tính từ hôm nay.

**Flow mới** (không còn bốn tab Đồ dùng / Đến hạn / Thùng / Cài đặt, danh sách theo
bảng chữ cái hay form 11 ô YYYY-MM-DD):

1. Mở app vào **Đồ trong nhà**: ô tìm kiếm ở trên cùng, dải "Cần để ý" (tối đa 3
   dòng, "Xem tất cả"), rồi danh sách đồ chia nhóm theo chỗ ở hiện tại.
2. Gõ là lọc ngay theo tên, chỗ để, thùng, người mượn, serial, ghi chú, không cần dấu.
   Không thấy gì thì có nút "Thêm 'máy khoan'" điền sẵn tên.
3. Chạm một món: desktop từ 900px mở hồ sơ ở cột phải, điện thoại mở trang riêng.
   Desktop chưa chọn món thì cột phải không để trống: nó liệt kê mọi mốc **Cần để ý**
   (Quá hạn, Trong 30 ngày, Sau đó), nên danh sách bên trái bỏ dải "Cần để ý". Đang
   xem một món thì có nút "← Cần để ý" quay về (soát lại 2026-11-01).
   Hồ sơ có một hành động chính theo ngữ cảnh: **Cho mượn** hoặc **Đã trả lại**; sau
   đó là Sửa, Nhãn QR, Hồ sơ để chia sẻ (xem lại trước khi chia sẻ), Xóa.
4. **Thêm đồ** (hành động chính): tên và chỗ để trước, chỗ để có gợi ý từ những chỗ
   đã dùng và các thùng; ảnh, hóa đơn, ngày (chọn bằng lịch, không gõ YYYY-MM-DD),
   serial, ghi chú nằm bên dưới. Lưu lỗi thì giữ nguyên form.
5. Chip lọc: Tất cả · Đang cho mượn · Theo thùng · Chưa vào thùng. "Theo thùng" hiện
   cả thùng trống và nút "Thêm thùng". Đầu nhóm của một thùng có menu Nhãn QR, Sửa,
   Xóa. Quét nhãn thùng thì lọc đúng thùng đó, có chip "Thùng 7 ×" để bỏ lọc.
6. **Quét nhãn** ở thanh trên: camera trên Android/iOS, dán liên kết ở mọi nền tảng.
7. **Đến hạn** (từ "Xem tất cả"): Quá hạn, Trong 30 ngày, Sau đó; mỗi dòng ghi món,
   loại mốc (hẹn trả, hết bảo hành, bảo dưỡng) và khoảng cách ngày.
8. Cài đặt: giao diện, ngôn ngữ, nhắc việc (bật, giờ nhắc), dữ liệu (xuất ZIP kèm ảnh
   và hóa đơn, khôi phục ZIP gộp hoặc thay thế, xuất JSON, khôi phục JSON cũ).

**Yếu tố đặc trưng:** **chỗ ở hiện tại**. Mỗi món thuộc đúng một chỗ, theo thứ tự ưu
tiên: đang ở chỗ người mượn, trong thùng (kèm chỗ để của thùng), chỗ để ghi tay, chưa
ghi chỗ. Danh sách chia nhóm theo chỗ đó; đầu nhóm là tên chỗ bằng Bricolage kèm số
món. Trong hồ sơ, dòng này là con số lớn nhất: "Ở chỗ Lan · từ 12/10, hẹn trả 20/10".

**Khuôn mặt:** đồ vật của chính người dùng. Mỗi dòng có ảnh 40px của món đó, hoặc ô
chữ cái đầu trên nền nhạt của màu nơi nó đang ở khi chưa có ảnh (chấm màu ở đầu nhóm
cùng màu đó, giữ nguyên dù đổi bộ lọc). Màu app (#B7791F) chỉ ở nút
chính, nhóm đang chọn, ô ảnh trống và dải "Cần để ý".

**Bố cục:** thanh trên (logo, tên app, Quét nhãn, cài đặt), không sidebar, không tab
dưới.

- Desktop từ 900px: danh sách bên trái (tối đa 520px), hồ sơ bên phải; nút "Thêm đồ"
  ở dòng tiêu đề.
- Điện thoại: một vùng mỗi lúc; thanh dưới có "Thêm đồ" (nút chính) và "Quét nhãn".

**An toàn (giữ từ bản cũ):** dữ liệu hỏng không bao giờ bị ghi đè, có trang khôi phục
bản sao; lưu thất bại giữ form; đang lưu thì chặn lưu lần hai và chặn Back; có thay
đổi chưa lưu thì Back hỏi "Bỏ thay đổi?"; đang chọn ảnh thì chặn thoát; ảnh và hóa đơn
kiểm tra chữ ký file, tối đa 4 MB; nhãn chỉ mở bản ghi trên máy, không tải URL; chia
sẻ hồ sơ phải xem lại trước; khôi phục ZIP kiểm tra toàn bộ rồi mới ghi, gộp từ chối
ID trùng.

**Trạng thái:**

- Chưa có đồ: một câu "Ghi lại món đầu tiên và chỗ cất nó" kèm nút Thêm đồ.
- Tìm không thấy: câu kèm nút thêm món với tên đã gõ.
- Đang tải: khung danh sách giữ chỗ.
- Lỗi đọc dữ liệu: một câu, Thử lại, Khôi phục bản sao.
- Lưu lỗi: dòng lỗi trong form, form giữ nguyên.
- Nhắc việc chưa hỗ trợ (Windows, Web): một câu, danh sách Đến hạn vẫn dùng được.

**Nền tảng:** Back trên Android và vuốt trên iOS đóng hồ sơ hoặc hỏi trước khi bỏ
thay đổi; Ctrl F tìm, Ctrl N thêm đồ, Esc đóng hồ sơ (desktop); chọn ngày bằng bánh
xe Cupertino trên iOS, lịch Material ở nơi khác; quét camera chỉ trên Android/iOS;
URL web `#/item/<id>`, `#/box/<id>`, `#/due`, `#/settings`.

**Loại bỏ:** tab dưới, danh sách theo bảng chữ cái, trang Đến hạn làm tab, form ngày
gõ tay, nút xuất/nhập nằm giữa trang Thùng.

**Bổ sung 2026-11-02: giá trị, CSV, thêm từ ảnh, hẹn trả** (chạy lại
`design-taste-frontend` app-screens với `draw.mjs --app --kind workspace --keep
palette,type --style accent-ladder --out .taste-skill/keep-more`, seed 409778925;
`frontend-ui-engineering`). Khuôn mặt vẫn là **chỗ ở hiện tại**; yếu tố mới là **giá
trị theo chỗ**: dưới tên mỗi chỗ (thùng, người mượn, chỗ để) có tổng tiền của các món
trong đó.

- **Giá trị.** Việc: biết đồ trong một thùng hay cả nhà đáng bao nhiêu khi chuyển nhà
  hoặc khai bảo hiểm. Không có hành động chính mới; câu trả lời đặt ở nơi người dùng
  đang xem. Mỗi món có thể có giá mua và tiền tệ (VND, USD, EUR, JPY, KRW, CNY, SGD,
  THB, AUD, GBP), gõ kiểu "4.500.000" hay "1,299.90". Tổng cộng **theo từng tiền
  tệ**, không bao giờ cộng chéo: "18.520.000 đ · 89,99 USD". Món chưa có giá được
  đếm riêng ("3 món chưa có giá"), không tính là 0; giá 0 là số 0 thật.
  - Tất cả: một dòng nhỏ dưới chip lọc ("Tổng giá trị …"), vì câu hỏi của màn hình
    vẫn là "ở đâu". Theo thùng, Đang cho mượn, một thùng: số lớn kèm nhãn của chế độ
    xem ("Trong 3 thùng · 4 món"); đây là danh sách để chuyển nhà và khai bảo hiểm.
    Mọi con số tính lại theo bộ lọc và ô tìm.
  - Đầu nhóm: chế độ Theo thùng luôn ghi giá trị từng thùng (kể cả "1 món chưa có
    giá"); ở chế độ khác chỉ chỗ nào có giá mới ghi.
  - Chưa món nào có giá: không hiện gì, không nhắc nhở.
  - Hồ sơ món: dòng "Giá mua" trong Thông tin. Form: ô giá kèm hộp chọn tiền tệ, mặc
    định là tiền tệ hay dùng nhất, chưa có thì VND (tiếng Việt) hoặc USD.
- **Xuất CSV.** Việc: đưa danh sách cho công ty chuyển nhà, bảo hiểm, hay bảng tính.
  Menu ⋯ cạnh tiêu đề "Đồ trong nhà": "Lưu danh sách ra CSV", hoặc "Lưu N món này ra
  CSV" khi đang lọc hay tìm (đúng những món trên màn hình, đúng thứ tự). Cài đặt → Dữ
  liệu: lưu mọi món. Cột: tên, cất ở, thùng, người mượn, ngày cho mượn, hẹn trả, ngày
  mua, giá, tiền tệ, bảo hành đến, serial, ghi chú; tiêu đề cột theo ngôn ngữ app.
  UTF-8 có BOM (Excel đọc được tiếng Việt), CRLF, mọi ô trong ngoặc kép, ô bắt đầu
  bằng = + - @ (cả dạng full-width) được thêm dấu ' phía trước. Đi qua `exportBytes`
  như các bản xuất khác; hủy thì không báo gì, lỗi thì báo và dữ liệu không đổi.
- **Thêm từ ảnh** (trang toàn màn hình). Việc: ghi nhanh nhiều món khi xếp thùng.
  Hành động chính: "Lưu N món". Vào từ menu ⋯ ("Thêm từ ảnh") hoặc menu của một thùng
  ("Thêm nhiều món từ ảnh", điền sẵn thùng đó). Android/iOS: "Chụp ảnh" chụp liên tục,
  đóng camera là dừng; mọi nền tảng: "Chọn ảnh" chọn nhiều file một lúc. Mỗi ảnh hợp
  lệ (PNG/JPEG theo chữ ký, ≤ 4 MB, cùng kiểm tra với form) thành một dòng: ảnh 64px,
  ô tên, nút bỏ. Ảnh bị từ chối được liệt kê kèm lý do ngay dưới danh sách. Dưới cùng
  là "Chung cho tất cả": một chỗ để và một thùng. Tối đa 20 ảnh mỗi lần (thư viện 16
  MB). Lưu là một lần ghi: tất cả hoặc không món nào.
  - Trạng thái: chưa có ảnh (một câu, hai nút, nút Lưu bị khóa); đang chờ ảnh; có
    ảnh; thiếu tên (dòng đó báo "Đặt tên hoặc bỏ ảnh", không ghi gì); lưu lỗi (báo
    lỗi, giữ mọi ảnh và tên để thử lại); đủ 20 ảnh (một câu thay cho hai nút).
  - Đóng hoặc Back khi đã có ảnh: hỏi "Bỏ N ảnh này?"; bỏ thì không giữ gì.
- **Hẹn trả và nhắc quá hạn.** Đã có sẵn từ trước: "Hẹn trả" là ngày tùy chọn trong
  hộp Cho mượn (chọn bằng lịch); món quá hẹn hiện trong "Cần để ý" và trang Đến hạn;
  nhắc cục bộ đặt vào ngày hẹn qua `ReminderController` (chỉ xin quyền khi bật nhắc
  trong Cài đặt), bị hủy khi trả lại hoặc xóa món. Windows/Web dùng danh sách trong
  app.
- **Bề rộng 320–1440.** 320: tổng giá trị xuống dòng nguyên cụm ("3 món chưa có giá"
  không bị cắt), lỗi tên xuống hai dòng; 900 trở lên: trang Thêm từ ảnh nằm trong cột
  giữa `HandyContent`, nút Lưu ở thanh dưới.
- **Nền tảng.** Back trên Android, vuốt trên iOS, Esc trên desktop đều đi qua câu hỏi
  bỏ ảnh; web giữ URL của trang đang mở (trang Thêm từ ảnh là hộp thoại toàn màn
  hình, không có URL riêng); camera chỉ có trên Android/iOS.
- **Loại bỏ:** cộng các tiền tệ khác nhau thành một số; coi món chưa có giá là 0;
  bảng nhập nhiều ô cho từng món; lưu từng món một trong lúc thêm hàng loạt.

**Ghi chú triển khai** (`apps/handy_keep/lib/`): `inventory/whereabouts.dart` là phần
lõi thuần Dart (chỗ ở hiện tại, tìm không dấu, mốc đến hạn, có test);
`inventory/keep_store.dart` ghi trước rồi mới hiện, lưu lỗi thì giữ nguyên;
`scope.dart` gom các hành động mở editor, dialog, nhãn. Ảnh chụp thẳng bằng camera
trên Android/iOS (`handy_files/camera.dart`). Trang nhãn lưu được cả mã QR lẫn **cả
tấm nhãn có tên** (PNG 3×) để in. Nhắc việc dùng `ReminderController` mới của
`handy_notifications`; `RemindersPanel` cũ chỉ còn cho Recall đến khi Recall làm lại.

## Hợp đồng: Handy Recall

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: bộ thẻ (tên); thẻ (câu hỏi, đáp án, có thể kèm ảnh PNG/JPEG ≤500 KB với
  1–32 vùng che); lịch của từng thẻ (đến hạn lúc nào, khoảng cách hiện tại, độ dễ, số
  lần ôn, số lần quên). Giới hạn 500 bộ, 20.000 thẻ.
- Quy mô thật: một người học có 1–10 bộ, 20–2.000 thẻ; mỗi ngày 0–150 thẻ đến hạn; một
  buổi ôn 5–20 phút, khoảng 10 giây mỗi thẻ.
- Người dùng: học sinh, sinh viên, người học ngoại ngữ; ôn trên điện thoại mỗi ngày (trên
  xe buýt, giờ nghỉ). Desktop dùng khi soạn nhiều thẻ hoặc nhập CSV.
- Việc, theo thứ tự hay gặp: **ôn các thẻ đến hạn hôm nay**; thêm thẻ liên tục; xem và sửa
  thẻ của một bộ; nhập CSV; làm thẻ che ảnh; bật nhắc ôn; sao lưu.

**Câu hỏi của màn hình** (skill §2.2)

- Màn hình chính: "Hôm nay cần ôn bao nhiêu, và bắt đầu được ngay không?" Khối lớn nhất
  là số thẻ đến hạn kèm nút **Bắt đầu ôn**. Phát hiện: "38 thẻ · khoảng 6 phút", hoặc khi
  đã xong: "Xong cho hôm nay · ngày mai 12 thẻ".
- Buổi ôn: "Mình có nhớ thẻ này không?" Khối lớn nhất là thẻ. Bốn nút chấm ghi luôn lần
  tới sẽ gặp lại: Quên · 10 phút, Khó · 1 ngày, Nhớ · 3 ngày, Dễ · 8 ngày.
- Một bộ thẻ: "Bộ này có gì, cần ôn bao nhiêu?" Danh sách thẻ kèm hạn của từng thẻ.

**Flow mới** (không còn ba tab Bộ thẻ / Ôn tập / Cài đặt, không chọn bộ qua dropdown):

1. Mở app vào **Hôm nay**: khối dẫn (số đến hạn, thời gian ước tính, Bắt đầu ôn), dải
   lịch ôn 14 ngày, rồi danh sách bộ thẻ (mỗi bộ ghi số cần ôn và tổng số thẻ, có nút Ôn
   riêng khi có thẻ đến hạn).
2. **Buổi ôn** toàn màn hình: thanh tiến độ, thẻ ở giữa; chạm "Hiện đáp án" (phím cách),
   đáp án mở ra; chấm bằng một trong bốn nút (phím 1–4). Lưu xong mới sang thẻ tiếp; lưu
   lỗi thì giữ nguyên thẻ và lịch cũ. Hết thẻ: tổng kết (số thẻ, số lần quên) và lần ôn
   tới.
3. **Bộ thẻ**: Ôn bộ này (nút chính), Thêm thẻ, tìm thẻ; menu có Đổi tên, Nhập CSV, Xuất
   CSV, Xóa bộ. Mỗi dòng thẻ: câu hỏi, đáp án mờ, hạn ("mới", "đến hạn", "còn 3 ngày").
4. **Soạn thẻ**: câu hỏi, đáp án, ảnh để che (vẽ vùng che ngay trên ảnh). Nút **Lưu và
   thêm thẻ khác** giữ nguyên bộ và xóa trống ô để nhập liền tay; Lưu thường thì đóng.
5. Cài đặt: giao diện, ngôn ngữ, nhắc ôn hằng ngày (giờ nhắc), sao lưu/khôi phục JSON,
   xóa toàn bộ dữ liệu (ở cuối, xác nhận).

**Yếu tố đặc trưng:** **lịch ôn 14 ngày**: mỗi ngày một cột theo số thẻ đến hạn, hôm nay
là cột màu app (thẻ quá hạn dồn vào hôm nay), các ngày sau màu xám; có trục số tròn và
nhãn ngày. Người học thấy ngay khối lượng sắp tới và vì sao nên ôn hôm nay.

**Khuôn mặt:** con số đến hạn bằng Bricolage cỡ lớn trong khối dẫn, cùng các khoảng cách
ôn tiếp theo ghi trên nút chấm. Màu app (#4D7C0F) ở nút chính, cột hôm nay, thanh tiến độ.

**Bố cục:** thanh trên (logo, tên app, cài đặt), không tab.

- Desktop từ 900px: cột trái là khối dẫn và lịch ôn, cột phải là danh sách bộ thẻ.
- Điện thoại: xếp chồng; buổi ôn chiếm toàn màn hình, nút chấm nằm ở đáy, trong tầm ngón
  cái.

**An toàn (giữ từ bản cũ):** chấm thẻ dùng đúng bộ lập lịch và lưu trước khi sang thẻ;
lưu lỗi giữ câu hỏi và lịch cũ; dữ liệu hỏng không bị ghi đè; soạn thẻ lưu lỗi thì giữ
form, đang lưu chặn lưu lần hai và Back, có thay đổi thì Back hỏi trước, đang chọn file
thì chặn thoát; ảnh kiểm tra chữ ký và kích thước; nhập CSV kiểm tra hết rồi mới thêm.

**Trạng thái:**

- Chưa có bộ nào: một câu kèm nút "Bộ thẻ đầu tiên".
- Bộ trống: một câu kèm "Thêm thẻ" và "Nhập CSV".
- Không có gì đến hạn: lần ôn tới và số thẻ của ngày mai.
- Đang tải: khung giữ chỗ. Lỗi đọc dữ liệu: một câu, Thử lại, Khôi phục bản sao.
- Nhắc ôn chưa hỗ trợ (Windows, Web): một câu.

**Nền tảng:** phím cách hiện đáp án, 1–4 chấm, Esc thoát buổi ôn (desktop, web); Back trên
Android và vuốt trên iOS thoát buổi ôn (tiến độ đã lưu theo từng thẻ); rung nhẹ khi chấm
trên điện thoại; URL web `#/review`, `#/deck/<id>`, `#/settings`.

**Chuyển động:** đáp án mở ra như lật thẻ (mờ và trượt nhẹ), thẻ tiếp theo trượt vào từ
phải, thanh tiến độ chạy mượt, cột lịch ôn lớn lên khi số liệu đổi. Tắt khi hệ điều hành
giảm chuyển động.

**Loại bỏ:** tab dưới, dropdown chọn bộ, nút chấm chỉ có chữ "again/good", màn ôn nằm
chung với danh sách.

**Ghi chú triển khai** (`apps/handy_recall/lib/`): `study/schedule.dart` là phần lõi
thuần Dart (lịch ôn 14 ngày, khoảng cách lần sau cho từng nút chấm, trạng thái hạn của
thẻ, có test); `study/recall_store.dart` ghi trước rồi mới hiện; `review/` là buổi ôn
(thẻ trượt sang, đáp án mở ra, tiến độ chạy theo màu app); `occlusion_editor.dart` giữ
phần hình học vùng che đã có test, chỉ đổi giao diện, và giải mã ảnh một lần cho mỗi
ảnh (trước đây giải mã lại mỗi lần vẽ lại nên ảnh có thể nhấp nháy). Nhắc ôn dùng
`ReminderController` và `RemindersSection` chung trong `handy_notifications`.

### Recall: nhập Anki, thẻ điền khuyết, thẻ đảo chiều, đọc to

Chạy lại skill cho bốn việc mới (`draw.mjs --app --kind workspace --keep palette,type`,
ra `achromatic-ledger`; giữ hướng "colour per app" của kit, chỉ lấy luật màu: màu app
chỉ trên dữ liệu chính).

- **Nhập từ Anki** (`/import`, mở từ "Từ Anki" cạnh "Bộ thẻ mới" và từ trạng thái chưa
  có bộ nào). Việc: đưa một bộ Anki sang mà biết trước cái gì vào, cái gì không. Câu hỏi
  của màn: "Sẽ thêm những gì, và mất gì?" Khối lớn nhất: số thẻ (Bricolage) và lịch ôn 14
  ngày của chính các thẻ đó (yếu tố đặc trưng của app, cột hôm nay màu app). Hành động
  chính: **Thêm N thẻ** ở thanh đáy; phụ: File khác. Một lựa chọn: Giữ lịch ôn của Anki
  (chỉ hiện khi file có lịch sử ôn). Rồi bộ thẻ mới (chấm màu nhận diện), loại thẻ
  (thường, đảo chiều, điền khuyết, ảnh), **Không được thêm** kèm lý do (thẻ trống, che ảnh
  của Anki, ảnh sai định dạng/quá 500 KB/hỏng, âm thanh), vài thẻ đầu. Trạng thái: chọn
  file; đang đọc (khung giữ chỗ, "chưa thêm gì"); lỗi trong khối (một câu nói rõ lỗi, gói
  định dạng mới không đọc được thì hướng dẫn xuất lại với "Support older Anki versions",
  nút Chọn file khác); vượt giới hạn thư viện (thông báo đỏ, nút Thêm tắt); ghi lỗi (giữ
  nguyên bản xem trước, "Không có gì thay đổi"). Bề rộng: dưới 900px một cột; từ 900px
  hai cột như Hôm nay (trái: số thẻ, lịch ôn, lựa chọn; phải: chi tiết) để mọi khối nằm
  trên màn đầu; 320px không tràn. Nền tảng: có trên Android, iOS, Windows và Web (đọc
  bằng Dart thuần, không cần SQLite native); mở từ danh sách thì vào thẳng hộp chọn file,
  hủy thì quay lại; Back/Esc thoát, đang ghi thì chặn Back; URL web `#/import`.
- **Thẻ điền khuyết** (`{{c1::đáp án::gợi ý}}`): soạn bằng cách chọn chữ rồi bấm **Tạo ô
  điền khuyết** (nút dưới ô câu hỏi, mục "Điền khuyết" trong menu chọn chữ, Ctrl+Shift+C;
  Ctrl+Shift+Alt+C thêm ô cùng số). Dòng cạnh nút nói ra kết quả ("Tạo 2 thẻ, mỗi ô một
  thẻ"). Ô đáp án đổi tên thành "Ghi chú thêm (không bắt buộc)". Khi ôn: ô trống mang
  gợi ý trên nền màu app nhạt, các ô khác hiện chữ; lật ra thì ô được điền, gạch chân màu
  app. Mỗi số một thẻ, lịch riêng.
- **Thẻ đảo chiều**: công tắc "Tạo thêm thẻ đảo chiều" trong soạn thẻ (mặc định theo bộ
  thẻ), tắt và ghi lý do với thẻ điền khuyết hoặc ảnh có vùng che; tắt trên thẻ đã có
  thì cảnh báo trước khi lưu rằng thẻ đảo chiều và lịch ôn của nó sẽ bị xóa. Khi ôn, thẻ
  đảo chiều có dòng nhỏ "Thẻ đảo chiều"; anh em cùng ghi chú không hiện liền nhau trong
  một buổi. Xóa một thẻ xóa cả ghi chú, hộp xác nhận nói số thẻ liên quan.
- **Đọc to**: "Cài đặt bộ thẻ" (thay "Đổi tên") có tên, mặc định thẻ đảo chiều và ngôn ngữ
  đọc cho câu hỏi và đáp án, chọn từ giọng máy đang có. Không có giọng: một câu hướng dẫn
  thêm giọng trong cài đặt hệ thống. Khi ôn: nút loa cạnh câu hỏi và cạnh đáp án chỉ khi
  mặt đó có ngôn ngữ; phím R đọc mặt đang nhìn; thiếu giọng cho ngôn ngữ đó thì báo rõ,
  không im lặng. Ngoại tuyến khi giọng hệ thống ngoại tuyến (trình duyệt có thể dùng
  giọng trực tuyến).
- **Chữ Nhật/Trung/Hàn trên Web**: `web/flutter_bootstrap.js` của Recall giữ các lát font
  Noto mà engine tải từ fonts.gstatic.com lần đầu cần, trong cache riêng
  `handy_recall-fonts-v1`; lần đầu phải có mạng, sau đó hiện được khi ngoại tuyến.

**Loại bỏ:** bước nhập không có xem trước, thông báo "định dạng không hỗ trợ" mơ hồ, nút
loa luôn hiện mà không đọc được, ô đáp án bắt buộc cho thẻ điền khuyết, cú pháp
`{{c1::}}` chỉ gõ tay.

## Hợp đồng: Handy Bookmark

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: link đã lưu (URL gốc và đã chuẩn hóa, tiêu đề, mô tả, ghi chú, nguồn như
  YouTube/TikTok/Facebook/Shopee, domain, ảnh thu nhỏ, bộ sưu tập, thẻ, yêu thích,
  ghim, đã đọc, lưu trữ, số lần mở, hẹn nhắc); bộ sưu tập lồng nhau; thẻ; bộ sưu tập
  thông minh (Pro, 1–12 điều kiện); tìm kiếm đã lưu (Pro).
- Quy mô thật: 50–3.000 link; mỗi ngày lưu 1–10 link, chủ yếu qua nút Chia sẻ của app
  khác; 5–30 bộ sưu tập; phần lớn link mới nằm trong "Chưa xếp".
- Người dùng: một người, chủ yếu điện thoại. Lưu từ app khác (không mở Handy Bookmark), rồi
  lúc rảnh mở app để xếp, tìm lại, mở lại. Desktop để dọn dẹp hàng loạt, nhập/xuất.
- Việc, theo thứ tự hay gặp: **tìm lại một link và mở nó trong app gốc**; **xếp link mới
  vào bộ sưu tập**; dán link để lưu; đọc lần lượt những link chưa đọc (Tập trung); dọn
  hàng loạt; hẹn nhắc; nhập/xuất.

**Câu hỏi của màn hình** (skill §2.2)

- Màn hình chính: "Mình đã lưu gì, và link mới lưu nên để đâu?" Khối lớn nhất là ô tìm
  kiếm cùng dải **Chưa xếp**. Phát hiện: "7 link chưa xếp · mới nhất 10 phút trước".
- Danh sách (bộ sưu tập, kết quả tìm): "Link mình cần ở đâu?" Dòng có ảnh, tiêu đề,
  nguồn · domain, thẻ; chạm để mở bản gốc.
- Chi tiết: "Link này là gì, mở nó ở đâu?" Nút chính là **Mở bản gốc**.

**Flow mới** (không còn bốn tab Inbox/Library/Collections/Focus):

1. Mở app vào **Đã lưu**: thanh trên (logo, tên, Dán link, cài đặt), ô tìm kiếm, dải
   **Chưa xếp** (yếu tố đặc trưng), danh sách bộ sưu tập, rồi "Mới lưu gần đây".
2. **Chưa xếp**: mỗi link mới là một thẻ có ảnh, tiêu đề, nguồn và một hàng chip bộ sưu
   tập hay dùng; chạm chip là xếp xong, thẻ trượt đi. "Khác…" mở danh sách đầy đủ.
3. **Tìm**: gõ là lọc ngay (tiêu đề, mô tả, ghi chú, URL, domain, nguồn, thẻ, bộ sưu
   tập); `#thẻ` gợi ý thẻ. Nút **Lọc** mở một sheet: xem (tất cả, yêu thích, chưa đọc,
   lưu trữ), nguồn, loại, thẻ, bộ sưu tập, khoảng ngày, sắp xếp. Bộ lọc đang bật hiện
   thành chip có nút bỏ.
4. **Danh sách**: dạng dòng hoặc thẻ; chạm là mở bản gốc, nhấn giữ (hoặc nút chọn) để
   chọn nhiều; thanh hàng loạt ở đáy: chuyển, thêm/bỏ thẻ, đã đọc, yêu thích, lưu trữ,
   sao chép URL, xuất, xóa.
5. **Chi tiết**: ảnh lớn, tiêu đề, nguồn, URL chọn được, mô tả, ghi chú, thẻ; Mở bản
   gốc (nút chính) và "Mở bằng trình duyệt"; yêu thích, ghim, đã đọc, lưu trữ; hẹn nhắc
   (hôm nay, ngày mai 9:00, cuối tuần, tự chọn); lấy thông tin từ trang (chỉ khi bấm);
   sửa, xóa.
6. **Tập trung**: từng link chưa đọc, cũ nhất trước: Mở, Đã đọc, Để sau, Lưu trữ.
7. **Thêm link**: Dán link (Ctrl V) hoặc nút Thêm; trùng link thì hỏi: Mở link cũ / Gộp
   chi tiết / Vẫn thêm.
8. Cài đặt: mở bằng (hệ thống, app, trình duyệt), dạng thẻ, tự lấy thông tin trang
   (mặc định tắt), nhắc hẹn, lịch sử tìm, bộ nhớ ảnh, kiểm tra dữ liệu, nhập/xuất (xem
   trước số link hợp lệ/trùng/lỗi, gộp hoặc thay thế), hoàn tác, xóa hết.

**Yếu tố đặc trưng:** **dải Chưa xếp**: link vừa lưu từ app khác xếp thành chồng thẻ ở
đầu màn hình, mỗi thẻ có sẵn các bộ sưu tập hay dùng; một chạm là link có nhà và thẻ
trượt khỏi dải. Đó là nhịp riêng của Save: Lưu ở app khác → mở Save → xếp trong vài giây.

**Khuôn mặt:** đồ vật của chính người dùng: ảnh thu nhỏ của link, tên nguồn (YouTube,
TikTok, Shopee…) viết bằng chữ, không logo màu. Màu app (#0E7490) ở nút chính, chip đang
chọn, dải Chưa xếp.

**Bố cục:**

- Desktop từ 1100px: sidebar có nhãn bên trái (Chưa xếp, Tất cả, Yêu thích, Chưa đọc,
  Tập trung, Lưu trữ, các bộ sưu tập lồng nhau, bộ sưu tập thông minh), danh sách ở
  giữa, chi tiết ở cột phải. Sidebar có lý do ở đây: có hàng chục nơi để đi.
- 700–1100px: sidebar và danh sách; chi tiết mở trang riêng.
- Điện thoại: màn Đã lưu; bộ sưu tập, danh sách, chi tiết là các trang đẩy vào; nút
  **Dán link** ở thanh dưới.

**An toàn (giữ từ bản cũ):** chỉ ghi nhận share sau khi lưu xong; lưu lỗi giữ nguyên dữ
liệu; không tự gọi mạng khi lưu; clipboard chỉ đọc khi người dùng bấm Dán; không lưu
URL có thông tin đăng nhập; lấy thông tin trang không bao giờ ghi đè tiêu đề/mô tả người
dùng sửa; thông báo nhắc không chứa tiêu đề; nhập xem trước rồi mới ghi, thay thế cần
xác nhận lần hai và hủy nếu thư viện đổi; xóa có xác nhận và hoàn tác một bước.

**Trạng thái:**

- Chưa có link: một câu, Dán link, và cách lưu từ nút Chia sẻ của app khác.
- Không còn link chưa xếp: dải thu lại thành một dòng "Đã xếp hết".
- Tìm không thấy: câu kèm "Xóa bộ lọc".
- Đang tải: khung giữ chỗ. Lỗi kho dữ liệu: Thử lại, Giữ bản sao và khôi phục.
- Share lỗi: một dòng kèm Xem lại / Bỏ.

**Nền tảng:** Android/iOS nhận link qua nút Chia sẻ; Ctrl/Cmd V dán, Ctrl/Cmd N thêm,
Ctrl/Cmd F tìm, Esc bỏ chọn (desktop, web); Back trên Android thoát chế độ chọn trước;
chạm nhanh trên điện thoại rung nhẹ khi xếp xong; URL web `#/collection/<id>`,
`#/bookmark/<id>`, `#/focus`, `#/settings`.

**Chuyển động:** thẻ Chưa xếp trượt khỏi dải khi được xếp, danh sách mờ dần khi đổi bộ
lọc, chi tiết mờ sang khi chọn link khác, thanh hàng loạt trượt lên khi bắt đầu chọn.

**Loại bỏ:** bốn tab dưới, NavigationRail chép từ bản cũ, banner "Saved to Inbox",
phân trang prev/next với 100 dòng (thay bằng tải thêm khi cuộn), menu ba chấm trên mọi
dòng.

**Ghi chú triển khai:** `view/library_view.dart` giữ truy vấn, trang, chọn nhiều và
hoàn tác một bước (có test); `scope.dart` gom các thao tác; `controller.dart`,
`platform/` và `services/` giữ nguyên từ bản cũ. Tìm kiếm đã lưu (Pro) và thứ tự tự
xếp đã có lại (xem phần bổ sung dưới).

**Kế hoạch triển khai** (`apps/handy_bookmark/lib/`, giữ `controller.dart`, `platform/`,
`services/`, `SaveController` và `BookmarkStore` như cũ):

- `view/library_view.dart`: trạng thái truy vấn (SearchQuery, phạm vi đang xem, trang,
  chọn nhiều, revision bỏ kết quả cũ), không có widget.
- `shell/`: `save_shell.dart` (bố cục theo bề rộng), `sidebar.dart`.
- `home/`: `home_page.dart`, `triage_strip.dart` (đặc trưng), `collection_list.dart`.
- `library/`: `results_view.dart`, `bookmark_tile.dart`, `filter_sheet.dart`,
  `batch_bar.dart`.
- `bookmark/`: `detail_view.dart`, `reminder_sheet.dart`, `add_link.dart` (dán, trùng).
- `focus/focus_page.dart`; `data/import_export.dart`; `settings_page.dart`;
  `editors/` (bookmark, collection, smart: giữ logic kiểm tra và key cũ, giao diện mới).

**Bổ sung 2026-11-02: Pocket, bản đọc offline, kiểm tra link, tìm kiếm đã lưu, thứ tự
tự xếp** (chạy lại `design-taste-frontend` app-screens, sheet accent-ladder giữ màu và
chữ của Save, `.taste-skill/save-more/`; hợp đồng theo `frontend-ui-engineering`).

- Dữ liệu và việc: bản đọc (tiêu đề, tác giả, trang, các đoạn chữ, ngày lưu, bị cắt hay
  không; vài trăm đến 200.000 ký tự); kết quả kiểm tra (ổn / đã chuyển kèm địa chỉ mới /
  không còn / không xác định, mã HTTP, ngày); file Pocket (100–5.000 link, phần lớn đã
  lưu trữ); tìm kiếm đã lưu (tên, truy vấn, nơi); thứ tự tự xếp. Việc: đọc lại bài khi
  không có mạng; dọn link chết một hai lần mỗi tháng (thường trên desktop); chuyển từ
  Pocket một lần; gọi lại một tìm kiếm hay dùng; xếp link theo ý mình (lịch trình chuyến
  đi trong một bộ sưu tập).
- **Đọc offline** (`/read/<id>`): câu hỏi "Trang này viết gì?". Khối lớn nhất là chữ, cột
  tối đa 680px, Geist 18px (chỉnh 14–28px), dòng 1,6; tiêu đề Bricolage; dòng phụ: trang ·
  tác giả · "Lưu offline ngày …" · số phút đọc. Không ảnh, không link, không màu ngoài
  chữ. Thanh trên: Cỡ chữ (A−/A+), Nền (theo app / sáng / tối), Mở bản gốc. Bản bị cắt
  nói rõ ở cuối. Trạng thái: đang mở (khung giữ chỗ), không có bản (một câu + Lưu bản
  đọc), bản hỏng (một câu, link vẫn nguyên).
- **Lưu bản đọc offline**: trong Chi tiết, nhóm "Bản đọc offline": chưa có → nút "Lưu
  bản đọc offline"; đang lưu → vòng tiến trình + "Dừng"; có rồi → "Đọc offline" (nút
  chính của nhóm), "Lưu lại", "Xóa bản đọc". Hàng loạt: menu chọn nhiều → "Lưu bản đọc
  offline" (tối đa 200 link một lượt).
- **Kiểm tra link**: chỉ khi bấm. Menu chọn nhiều → "Kiểm tra link"; tiêu đề danh sách
  có menu "Kiểm tra link trong danh sách này" (một bộ sưu tập, Tất cả…; tối đa 500 một
  lượt). Một việc chạy một lúc: **dải công việc** ở đầu danh sách: "Đang kiểm tra 12/80",
  thanh tiến trình đúng tỉ lệ, "Dừng"; xong thì một câu tổng kết ("80 link: 71 ổn, 3 đã
  chuyển, 2 không còn, 4 không xác định") + "Xem link hỏng" + đóng. Dừng giữa chừng giữ
  kết quả đã có.
- **Link hỏng** (nơi mới, chỉ hiện khi có): câu hỏi "Link nào không còn mở được, và làm
  gì với nó?". Dòng có chữ trạng thái ở dòng phụ ("Không còn · 404 · 2/11"); chỉ "Không
  còn" mang màu cảnh báo, một dấu mỗi dòng. Chi tiết của link "Đã chuyển" có "Dùng địa
  chỉ mới" kèm Hoàn tác; không bao giờ tự đổi.
- **Nhập từ Pocket**: Cài đặt → "Nhập từ Pocket" (CSV hoặc `ril_export.html`). Xem trước:
  "Nhập N link từ Pocket?" · "M đã lưu trữ · D đã có sẵn · L không đọc được" · vài tiêu
  đề mẫu · "Vào bộ sưu tập mới tên Pocket". Chỉ có Thêm (không có Thay toàn bộ); Hủy
  không đổi gì; xong có Hoàn tác.
- **Tìm kiếm đã lưu** (Pro): khi có chữ tìm hoặc bộ lọc, tiêu đề danh sách có nút "Lưu
  tìm kiếm này" (không Pro → hộp giải thích như bộ thông minh). Danh sách nơi có nhóm
  "Tìm kiếm đã lưu"; chạm là mở lại đúng nơi, chữ và bộ lọc; menu: đổi tên, xóa.
- **Thứ tự tự xếp**: thứ tự mới "Thứ tự tự xếp" trong Lọc và sắp xếp. Khi bật, tiêu đề
  có "Xếp lại": các dòng thành dạng gọn có nút Lên/Xuống và tay nắm kéo (kéo được trên
  mọi nền tảng, nút cho bàn phím và trình đọc màn hình); "Xong" hoặc Esc để thoát. Mỗi
  lần dời có Hoàn tác. Link đã ghim luôn ở trên.
- Bề rộng 320–1440: dải công việc một dòng chữ + thanh, nút Dừng xuống dòng dưới 360px;
  trình đọc giữ lề 16px ở điện thoại, cột 680px ở giữa trên desktop; trang Xếp lại không
  ảnh để tiêu đề còn chỗ ở 320px.
- Nền tảng: Android/iOS/Windows lưu bản đọc và kiểm tra link qua bộ tải an toàn (IP công
  khai được ghim, kiểm tra từng redirect, giới hạn MIME/dung lượng/thời gian, hủy được).
  **Web nói rõ không có** hai việc này (trình duyệt không bảo đảm được chính sách mạng);
  bản đọc khôi phục từ backup vẫn đọc được trên web. URL web `#/read/<id>`,
  `#/search/<id>`, `#/place/broken`. Phím: Ctrl/Cmd +/− đổi cỡ chữ trong trình đọc, Esc
  thoát Xếp lại; Back Android thoát Xếp lại trước.
- Loại bỏ: icon màu theo trạng thái trên mọi dòng, banner đỏ toàn màn hình, tự kiểm tra
  nền, tự sửa địa chỉ, ảnh trong bản đọc, nút "Lưu offline" trên từng dòng danh sách.

## Hợp đồng: Handy Docs

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: bản nháp Markdown (một bản, tối đa 1 MB, lưu khi bấm); phiên quét (tối đa
  20 trang PNG đã nắn, sao lưu JSON); các PDF đang mở (tối đa 20 file, 30 MB, không lưu
  lại); thư viện đọc (tối đa 50 tệp UTF-8: text, Markdown, HTML, code; thư mục, yêu
  thích, mở gần đây; sao lưu ZIP).
- Quy mô thật: một lần quét 1–6 trang (hóa đơn, giấy tờ, bài tập); một bản nháp vài
  trăm đến vài nghìn chữ; ghép 2–5 PDF; thư viện đọc 5–30 tệp.
- Người dùng: một người; quét bằng điện thoại, viết và sửa PDF trên máy tính.
- Việc, theo thứ tự hay gặp: **quét giấy tờ thành PDF**; viết Markdown rồi xuất
  PDF/HTML; ghép, cắt, xoay PDF; mở một tệp để đọc; sao lưu và khôi phục.

**Câu hỏi của màn hình** (skill §2.2)

- Màn hình chính: "Mình đang làm dở gì, và bắt đầu việc mới thế nào?" Khối lớn nhất
  là **Bàn làm việc**: các việc đang dở, mỗi việc hiện như một xấp giấy (trang quét
  đầu tiên, trang đầu của bản nháp, PDF đang mở) kèm số trang/số chữ. Bốn lối bắt đầu
  nằm ngay dưới: Quét giấy tờ, Viết Markdown, Ghép và sửa PDF, Mở tệp để đọc.
- Quét: "Đủ trang chưa, trang nào cần sửa?" Dải trang là khối lớn nhất; nút chính là
  **Xuất PDF**.
- Markdown: "Viết gì và nó sẽ trông thế nào?" Desktop: soạn và xem trước cạnh nhau.
- PDF: "Tệp ra sẽ gồm những trang nào?" Xem trước trang và ô chọn trang.
- Đọc: "Tệp này nói gì?" Nội dung là khối lớn nhất.

**Flow mới** (không còn ba tab Scanner/Markdown/PDF với Cài đặt là tab thứ tư):

1. Mở app vào **Bàn làm việc**: việc đang dở (nếu có) và bốn lối bắt đầu; thư viện
   đọc hiện các tệp mở gần đây.
2. **Quét** (`#/scan`): dải trang dạng tờ giấy; chạm một trang để sửa góc và độ tương
   phản; giữ để kéo đổi thứ tự (và nút lên/xuống cho bàn phím); thanh dưới: Chụp
   (Android/iOS), Thêm ảnh, Xuất PDF; menu: sao lưu, khôi phục phiên.
3. **Markdown** (`#/write`): desktop hai cột (soạn | xem trước), điện thoại chuyển
   Soạn/Xem; thanh trên: Lưu nháp (có chấm "chưa lưu"), Xuất (MD, HTML, TXT, PDF, ZIP);
   Tìm và thay (Ctrl F) mở thành một hàng; mẫu (tiêu đề, danh sách việc, bảng) trong
   menu.
4. **PDF** (`#/pdf`): các tệp đã thêm là một hàng chip; xem trước trang với trước/sau;
   một khối "Tạo PDF mới" gồm chọn trang, xoay, chữ chìm, rồi Tạo; Ghép tất cả khi có
   từ hai tệp.
5. **Đọc** (`#/read`): danh sách thư viện (gần đây, yêu thích, thư mục) bên trái trên
   desktop, nội dung bên phải; điện thoại đẩy trang.
6. Cài đặt: giao diện, ngôn ngữ, quy trình văn bản, lịch sử xuất, khôi phục bản sao.

**Yếu tố đặc trưng:** **tờ giấy**: mọi tài liệu hiện như tờ giấy thật (tỉ lệ A4, nền
trắng, viền mảnh, bóng rất nhẹ vì nó "nằm trên bàn"): trang quét, trang PDF, trang đầu
bản nháp. Trên Bàn làm việc, việc nhiều trang là một xấp lệch nhẹ có số trang.

**Khuôn mặt:** nội dung thật của người dùng trên tờ giấy (ảnh trang quét, dòng đầu bản
nháp), màu app (#1D5FBF) ở nút chính và trang đang chọn.

**Nền tảng:** camera chỉ trên Android/iOS; chữ chìm PDF chỉ trên Android/iOS/Windows
(web giải thích); Ctrl S lưu nháp, Ctrl F tìm, Ctrl P xuất PDF trong Markdown; Back
không thoát khi đang xử lý hay còn thay đổi chưa lưu (hỏi trước); URL web như trên.

**An toàn (giữ từ bản cũ):** mọi điều trong mục 6 của bản kiểm kê: ảnh hỏng không mở
trình sửa; lưu trang lỗi giữ góc; phiên quét sai định dạng bị từ chối; nháp hỏng không
bị ghi đè; xem trước chặn ảnh và không mở link; thay thế theo chữ, không regex; nhập
nhiều tệp kiểm tra hết rồi mới ghi; không ghi đè tệp gốc; hủy được khi xuất PDF.

**Trạng thái:** bàn trống: chỉ bốn lối bắt đầu và một câu; đang xử lý: tiến độ và Hủy;
lỗi: một câu, dữ liệu giữ nguyên.

**Chuyển động:** trang mới trượt vào dải, xóa trang thu lại, xấp giấy dịch nhẹ khi mở,
xem trước mờ sang khi đổi trang.

**Loại bỏ:** ba tab dưới + tab Cài đặt, các ExpansionTile chứa tính năng chính, hàng
nút xuất xếp chồng.

**Tiến độ:** xong. `desk/` (bàn làm việc: việc dở thành xấp giấy, bốn lối bắt đầu, đọc
gần đây), `scan/` (`ScanStore`, lưới trang dạng tờ giấy, trang mới nổi lên, sửa góc),
`write/` (`DraftController`; hai cột từ 900 px, Soạn/Xem trên điện thoại, bảng xuất,
hàng tìm và thay, Ctrl S/F/P, hỏi trước khi rời khi chưa lưu), `pdf/` (`PdfDesk` giữ
tệp đang mở ở cấp app; trang trên tờ giấy bên cạnh khối "Tạo PDF mới"), `read/`
(`ReaderStore` + `ReaderActions`; hai cột trên desktop, đẩy trang trên điện thoại, lọc
theo sao/thư mục), `settings_page.dart` (quy trình văn bản, lịch sử xuất, bản lưu dự
phòng của ba thư viện). Bỏ bộ tìm công cụ (Ctrl K) và ô "đầu vào đã lưu" của Markdown:
Docs chỉ có bốn nơi và bản nháp đã tự là đầu vào được lưu. Quy trình văn bản vẫn dùng
`SharedWorkflowPage` cũ cho tới bước 8.

### Thêm 2026-11-02: nhận dạng chữ, ký và điền, nén PDF, một lối mở tệp văn bản

Chạy skill: `draw.mjs --app --kind builder --keep palette,type`
(`.taste-skill/docs-more`, seed 131926455). Skill đưa achromatic-ledger và framed-sheet;
giữ accent-ladder của bộ app vì đây là màn con của Docs. Lấy từ sheet: "Builder canvas"
cho Ký và điền (thanh trên 44 px: thoát, tên tệp, nút chính; bảng công cụ 232 px bên
trái, trang trên nền tối hơn một bậc; trên điện thoại công cụ thành bottom sheet).

**Nhận dạng chữ** (`#/ocr`, mở từ menu một trang quét hoặc nút trên trang PDF)

- Việc: lấy chữ từ một trang giấy để chép, sửa, lưu. Câu hỏi: "Trang này viết gì?".
- Khối lớn nhất: chữ đọc được, sửa được ngay. Bên cạnh (desktop) là tờ giấy với các
  dòng đã đọc tô nền nhạt màu app: yếu tố đặc trưng của màn này, cho thấy máy đọc dòng
  nào.
- Hành động chính: **Chép chữ**. Phụ: Lưu .txt, Lưu .md, Mở trong trình viết (hỏi trước
  khi thay bản nháp chưa lưu).
- Trạng thái:
  - Đang đọc: tiến trình và Hủy.
  - Không thấy chữ: một câu, gợi ý chụp thẳng và rõ hơn.
  - Windows thiếu tiếng Việt: một câu nói thiếu gói nào, liệt kê ngôn ngữ đã cài, nút
    "Đọc bằng <ngôn ngữ đã có>" và cách cài (Cài đặt › Thời gian và ngôn ngữ).
  - Web: một câu "Nhận dạng chữ chạy trong ứng dụng Android, iOS và Windows", không có
    nút chết.
  - Lỗi: một câu, ảnh gốc giữ nguyên.
- Quét nhiều trang: menu "PDF tìm được chữ" làm PDF có lớp chữ ẩn dưới ảnh (PDFium), tìm
  và chép được trong trình đọc PDF.

**Ký và điền** (`#/pdf/fill`, từ màn PDF)

- Việc: ký tên, điền chữ, ghi ngày lên một PDF rồi lưu **bản mới**. Câu hỏi: "Ký và
  điền đúng chỗ chưa?". Khối lớn nhất là trang.
- Bảng công cụ: chữ ký đã lưu (nét mực thật trên nền trắng, xóa được), Ký mới (vẽ bằng
  ngón tay, chuột, bút), Nhập ảnh PNG, Ô chữ, Ngày (`pickHandyDate`).
- Trên trang: kéo để dời, góc phải dưới để đổi cỡ; món đang chọn có viền màu app và nút
  xóa. Bàn phím: mũi tên dời 1%, Shift + mũi tên 5%, Delete xóa.
- Hành động chính: **Xem bản mới** → các trang của bản mới (đã gộp nét) → **Lưu PDF**.
  Tệp gốc không bao giờ bị sửa.
- Trạng thái: chưa có gì trên trang (một câu chỉ vào bảng công cụ), đang tạo (tiến trình,
  Hủy), lỗi (một câu, vị trí các món giữ nguyên), web (giải thích, không có nút chết).

**Làm nhỏ PDF** (khối trong màn PDF)

- Hai nút: **Nén ảnh** (giữ chữ, link; ảnh JPEG 150 dpi) và **Nén mạnh** (mỗi trang
  thành ảnh; ghi rõ: chữ không còn chọn hay tìm được).
- Kết quả: "2,4 MB → 610 KB", phần trăm giảm, Lưu PDF; tệp gốc giữ nguyên. Không nhỏ đi
  được thì nói thẳng và gợi ý Nén mạnh.

**Một lối mở tệp văn bản**

- Bàn làm việc chỉ còn một lối "Mở tệp văn bản": Markdown mở vào trình viết (hỏi trước
  khi thay bản nháp chưa lưu); tệp khác (text, code, HTML) mở chỉ-đọc với tìm và nút
  "Tạo bản Markdown để sửa". Menu "Mở tệp văn bản" của trình viết dùng cùng lối này.
- Thư viện đọc cũ thành "Tệp đã giữ" (`#/read`): thư mục, gắn sao, gần đây, ZIP sao lưu
  và khôi phục giữ nguyên; dữ liệu không đổi định dạng nên không cần chuyển đổi. Trên Bàn
  làm việc là mục "Tệp đã giữ" (ba tệp gần nhất và "Xem tất cả").

**Rộng 320–1440:** dưới 900 px một cột (OCR: chuyển Chữ/Trang; Ký: bảng công cụ thành
sheet dưới), từ 900 px hai cột. **Nền tảng:** OCR Android/iOS (ML Kit) và Windows
(Windows.Media.Ocr); Ký, nén ảnh, chữ đóng dấu cần PDFium native (Android, iOS,
Windows); Web giải thích. Back không rời khi đang xử lý hay còn món chưa lưu (hỏi
trước). **Loại bỏ:** thanh công cụ nổi kiểu Acrobat, icon màu theo loại, chữ ký mẫu giả.

## Hợp đồng: Handy Media

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: **hướng dẫn** (dự án chụp màn hình: tiêu đề, loại hướng dẫn/lỗi/so sánh,
  thẻ, tối đa 100 bước; mỗi bước một ảnh PNG, tiêu đề, lời dặn và tối đa 100 lớp chú
  thích thuộc 9 loại); thư viện tối đa 100 dự án, 30 MB, bản nháp riêng từng dự án;
  ảnh để sửa nhanh (tối đa 50 ảnh, 60 MB); một tệp phụ đề (SRT/VTT, 1 MB); bản chụp
  và video gốc trên Android/iOS.
- Quy mô thật: một hướng dẫn 3–12 bước, mỗi bước 1–4 chú thích (mũi tên, số bước,
  che thông tin); thư viện 2–20 dự án; sửa nhanh 1–10 ảnh một lần.
- Người dùng: một người viết hướng dẫn cho đồng nghiệp hoặc người nhà ("cách nộp
  đơn", "báo lỗi app"); chụp trên điện thoại, chú thích và xuất trên máy tính.
- Việc, theo thứ tự hay gặp: **làm một hướng dẫn từ ảnh chụp màn hình** (thêm ảnh →
  chú thích → che chỗ nhạy cảm → xuất PDF/HTML/ảnh dài); sửa nhanh ảnh (cắt, đổi cỡ,
  đổi định dạng, đóng dấu, xóa EXIF); dời và đổi phụ đề; chụp/quay màn hình.

**Câu hỏi của màn hình** (skill §2.2)

- Màn hình chính ("Xưởng"): "Mình đang làm hướng dẫn nào, và bắt đầu cái mới thế
  nào?" Khối lớn nhất là danh sách hướng dẫn, mỗi cái là **một dải phim** các bước
  (ảnh thu nhỏ đánh số); nút chính **Hướng dẫn mới** mở luôn bộ chọn ảnh. Bên dưới:
  công cụ nhanh Sửa ảnh và, trên Android/iOS/Windows, Chụp màn hình. (Phụ đề đã
  chuyển sang Handy Tools, 2026-11-02.)
- Trình soạn: "Bước này cần chỉ vào đâu và che gì?" Ảnh bước là khối lớn nhất; dải
  bước bên trái (desktop) hoặc dưới (điện thoại); thanh công cụ 9 loại chú thích; bảng
  thuộc tính lớp đang chọn. Nút chính **Xuất hướng dẫn**.
- Sửa ảnh: "Ảnh ra sẽ trông thế nào?" Xem trước là khối lớn nhất; một hàng chọn việc
  (Cắt, Cỡ, Định dạng, Đóng dấu, EXIF); nút chính **Lưu ảnh** (một ảnh) hoặc **Lưu ZIP**.
- Phụ đề: đã chuyển sang Handy Tools (2026-11-02).

**Flow mới** (bỏ ba tab Công cụ nhanh/Chụp/Cài đặt và Ctrl K):

1. Mở app vào **Xưởng**: hướng dẫn gần nhất ở đầu; tìm theo tên/thẻ khi có từ 6 dự án.
2. **Hướng dẫn mới**: chọn nhiều ảnh (hoặc chụp) → mỗi ảnh thành một bước → vào trình
   soạn. Dự án chỉ vào thư viện khi bấm Lưu (bản cũ ghi ngay khi tạo, để lại dự án
   rỗng); bản nháp tự lưu 500 ms vẫn giữ mọi thay đổi.
3. **Trình soạn** (`#/guide/<id>`): chạm một công cụ rồi kéo trên ảnh để vẽ lớp (bút
   vẽ tự do); chọn lớp để di chuyển, đổi cỡ, đổi màu, sửa chữ, căn, đưa lên/xuống, xóa;
   Hoàn tác/Làm lại (Ctrl Z/Ctrl Shift Z), Lưu (Ctrl S), Delete xóa lớp; thu phóng và
   chế độ kéo ảnh không đụng tới lớp. Lời dặn của bước nằm dưới ảnh. Menu: chi tiết dự
   án (loại, thẻ, trường báo lỗi), sửa ảnh (xoay, giảm nửa, cắt theo khung), lặp vùng
   che sang các bước khác, chia sẻ PNG đã làm phẳng, sao lưu JSON/ZIP.
4. **Xuất hướng dẫn**: một bảng chọn định dạng (PDF, HTML, Markdown, ZIP, ảnh dài, bản
   đồ thay đổi) → luôn qua bước soát lại (đếm email/số điện thoại/mã bí mật) → tiến độ
   và Hủy.
5. **Sửa ảnh** (`#/image`), **Chụp màn hình**
   (`#/capture`, chỉ Android/iOS; nơi khác ẩn khỏi Xưởng), **Cài đặt** (`#/settings`).

**Yếu tố đặc trưng:** **dải phim các bước**: mỗi hướng dẫn hiện như một dải ảnh bước
thu nhỏ có số thứ tự trong vòng tròn màu app, đúng như con số bước trong hướng dẫn
xuất ra. Dải này là danh sách ở Xưởng và là thanh bước trong trình soạn.

**Khuôn mặt:** chính ảnh chụp màn hình của người dùng trong dải phim; màu app
(#C2255C) chỉ ở số bước, nút chính và lớp đang chọn.

**Nền tảng:** chụp/quay màn hình chỉ Android (toàn màn hình) và iOS (trong app, tối đa
60 giây); camera chỉ Android/iOS; xem video chỉ native. Desktop: trình soạn ba vùng
(dải bước | ảnh | thuộc tính) từ 1100 px, phím tắt như trên. Điện thoại: ảnh chiếm
màn hình, công cụ ở thanh dưới, thuộc tính lớp mở thành bottom sheet. Back hỏi trước
khi rời trình soạn còn thay đổi chưa lưu; không thoát khi đang xử lý.

**An toàn (giữ từ bản cũ):** nhập lô kiểm tra hết rồi mới thêm; lưu lỗi giữ trình
soạn và bản nháp; nháp debounce 500 ms, ghi tuần tự, lưu vào thư viện trước rồi mới
xóa nháp; kéo ảnh không bao giờ sửa lớp; chia sẻ dùng PNG đã làm phẳng và đã soát,
không bao giờ ZIP; xuất luôn qua bước soát; xóa dự án cũng xóa bản nháp của nó; nguồn
không bao giờ bị ghi đè; video phải thuộc app mới được mở.

**Trạng thái:** Xưởng trống: một câu và nút Hướng dẫn mới; dự án hỏng ảnh: lời nhắc
gắn lại ảnh đúng cỡ; đang xử lý: tiến độ "Đang dựng bước 3/8" và Hủy; lỗi: một câu,
dữ liệu giữ nguyên.

**Chuyển động:** bước mới trượt vào dải, chọn lớp thì khung chọn mờ vào, đổi bước thì
ảnh mờ sang, bảng xuất trượt lên.

**Loại bỏ:** ba tab dưới, các ExpansionTile chứa tính năng chính, dropdown chọn bước
và chọn lớp (thay bằng dải bước và chạm lên ảnh), "Ghim công cụ và đầu vào đã lưu" của
phụ đề.

**Tiến độ:** xong. `studio/` (Xưởng: hướng dẫn mới nhất ở đầu, mỗi cái một dải phim;
`MediaStore`; `openGuide` hỏi lấy lại bản nháp và bỏ hướng dẫn mới chưa từng lưu khi
đóng), `guide/` (`EditorController` giữ mọi chỉnh sửa và lịch sử; ba vùng từ 1100 px,
ảnh trước trên điện thoại; công cụ cầm trên tay rồi kéo để vẽ, chạm để đặt; bảng lớp:
màu, chữ tại chỗ, căn, lên/xuống, che cùng chỗ ở bước khác; Ctrl Z/Y/S, Delete, Esc;
bảng xuất và bước soát), `image/` (`ImageDesk`; ảnh lớn bên cạnh việc cần làm, kết quả
ngay dưới), `subtitles/` (đã bỏ 2026-11-02; Phụ đề nay ở Handy Tools),
`capture/` + `native_capture_page.dart` (giữ nguyên logic; bố cục mới: chụp, bản vừa
chụp, tạo bản mới của video). Xóa hướng dẫn giờ xóa cả bản nháp. Bỏ Ctrl K, ghim và
"đầu vào đã lưu" của phụ đề.

**Bổ sung 2026-11-02: GIF, chụp màn hình Windows, tìm thông tin nhạy cảm, bỏ Phụ đề**

Chạy lại hai skill (`draw.mjs --app --kind builder --keep palette,type --out
.taste-skill/media-more`, style "achromatic ledger": chrome không màu, màu app chỉ ở dữ
liệu chính và một hành động). Ảnh soát: `.taste-skill/media-more/shots/`.

- **Bỏ Phụ đề khỏi Media.** Không còn ô ở Xưởng, không còn `#/subtitles`, thư mục
  `subtitles/` đã xóa. Engine phụ đề trong `handy_media_engine` giữ nguyên cho Handy
  Tools. Cài đặt cũ có ghim/nội dung `subtitle-srt`/`subtitle-vtt` vẫn đọc được; "Xóa
  nội dung đã lưu" (chỉ hiện khi còn sót) xóa cả hai.
- **Xuất GIF** (bảng xuất → "Ảnh động GIF" → bảng tùy chọn). Câu hỏi: "GIF sẽ trông và
  chạy thế nào?" Khối lớn nhất là **khung đầu tiên đúng như sẽ xuất** (ảnh đã vẽ chú
  thích và vùng che, thanh chú thích đen có số bước trong vòng tròn màu app, đúng yếu
  tố đặc trưng dải phim). Dưới: thời gian mỗi bước (1/2/3/5 giây), chiều rộng tối đa
  (480/640/800/960; ảnh nhỏ hơn không bị phóng to và có câu nói rõ), công tắc thanh
  chú thích, giới hạn (100 bước, 48 triệu điểm ảnh, 20 MB). Hành động chính **Tạo GIF**
  → bước soát như mọi định dạng → tiến độ hai pha ("Đang dựng bước 2/5", "Đang tạo khung
  2/5") và Hủy ở chân màn hình. Trạng thái: vượt giới hạn thì báo lỗi ngay trong bảng
  và khóa nút; đóng bảng không tạo gì. MP4 không làm vì `handy_capture` không có đường
  mã hóa chuỗi ảnh.
- **Chụp màn hình Windows** (`#/capture`). Câu hỏi: "Chụp phần nào?" Chọn **Một vùng**
  (mặc định) hoặc **Cả màn hình** (màn hình đang có con trỏ), chờ 0/3/5/10 giây để kịp
  mở menu, nút **Chụp**. App tạm ẩn (tắt hiệu ứng mờ của DWM), màn hình được chụp bằng
  GDI BitBlt ở điểm ảnh vật lý (runner Per-Monitor V2), rồi một lớp phủ trên mọi màn
  hình hiện ảnh đứng yên làm tối; kéo để chọn (viền màu app), bấm một cái để lấy cả màn
  hình dưới con trỏ, Esc hoặc chuột phải để hủy; dòng hướng dẫn EN/VI ở đầu màn hình có
  con trỏ. Kết quả: ảnh xem trước bên cạnh hành động **Chú thích ảnh** (mở hướng dẫn mới,
  ảnh là bước 1, cùng luồng với Android) và **Lưu một bản**. Lỗi: quá 16 triệu điểm ảnh
  hoặc 8 MB thì nói rõ, đã hủy thì nói đã hủy; ảnh chỉ giữ trong bộ nhớ (4 ảnh gần nhất),
  không ghi đĩa. Windows **không có quay màn hình**; trang nói thẳng như vậy.
- **Tìm thông tin nhạy cảm** (bảng chú thích của bước → nút "Tìm thông tin nhạy cảm",
  chỉ hiện khi máy đọc được chữ: Android/iOS bằng ML Kit, Windows bằng Windows.Media.Ocr
  qua `handy_scan`; web ẩn). Câu hỏi: "Che những chỗ nào?" Đang đọc: tiến độ + Hủy. Khi
  có kết quả, bảng bên phải (điện thoại: dưới ảnh) liệt kê từng chỗ: loại (Email, Số điện
  thoại, Số thẻ, IBAN, Số tài khoản, Mã OTP, Khóa hoặc token, Mật khẩu hoặc khóa) và gợi
  ý chỉ lộ đầu/cuối ("ma…om"), mỗi dòng một ô chọn; "Chọn hết/Bỏ chọn hết". Trên ảnh,
  chỗ được chọn hiện khối đen, chỗ bỏ chọn là khung viền màu app; trình soạn bị khóa
  (không vẽ, không đổi bước, không xuất). Chân màn hình: "Đã chọn 3/4", **Hủy**, **Che 3
  chỗ**. Không có gì được áp dụng tới khi bấm Che; áp dụng là một bước Hoàn tác. Không
  thấy gì: một câu nhắc việc đọc có thể sót chữ. Chỗ đã bị vùng che phủ thì không đề xuất
  lại. Windows thiếu gói ngôn ngữ OCR: câu hướng dẫn thêm ngôn ngữ.
- **Rộng 320–1440:** bảng GIF cuộn trong bottom sheet (điện thoại) và giới hạn 640 px
  (desktop); bảng soát nằm cột phải từ 1100 px, dưới ảnh ở hẹp hơn; trang chụp Windows
  dồn một cột dưới 640 px, ảnh xem trước cạnh hành động từ 640 px.
- **Nền tảng:** GIF mọi nền tảng (web cũng chạy, trên luồng chính); chụp vùng chỉ
  Windows; tìm thông tin nhạy cảm Android/iOS/Windows; phím Esc thoát bảng soát và lớp
  phủ chụp.
- **Loại bỏ:** áp dụng che tự động; hiện nguyên giá trị nhạy cảm trong danh sách soát;
  bảng chọn chiều rộng giả vờ phóng to ảnh nhỏ; ghi ảnh chụp Windows ra thư mục tạm.

## Hợp đồng: Handy Spend

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: **tài khoản** (tiền mặt, ngân hàng, ví điện tử, tiết kiệm, thẻ tín dụng,
  khoản vay; loại tiền; số dư đầu kỳ và ngày; có tính là tiền tiêu được không), **giao
  dịch** (chi, thu, chuyển khoản, hoàn tiền, điều chỉnh; đã ghi sổ hoặc dự kiến; đối tác,
  danh mục, nhãn, ghi chú; số tiền nguyên theo đơn vị nhỏ nhất, không làm tròn), danh mục
  (chi/thu, có cha), **khoản định kỳ** (tiền nhà, điện, mạng, lương; tần suất; chắc chắn
  hay không; nhắc), **mục tiêu để dành**, ngân sách, **thử trước** (kịch bản trên bản chụp
  sổ, không đụng sổ thật), quy tắc phân loại, lịch sử nhập sao kê.
- Quy mô thật (VND): lương 15–25 triệu/tháng; tiêu mỗi ngày 30.000–300.000; 2–6 tài
  khoản; 3–12 khoản định kỳ; 60–150 giao dịch/tháng; một sao kê 30–300 dòng (tối đa
  100.000).
- Người dùng: một người, ưu tiên tiếng Việt. Mỗi ngày mở điện thoại vài lần, mỗi lần
  5–20 giây (ghi một ly cà phê, xem còn tiêu được bao nhiêu); mỗi tháng một buổi trên
  Windows hoặc web để nhập sao kê, đối chiếu, xem tiền đi đâu.
- Việc, theo thứ tự hay gặp: **ghi một khoản chi**; xem **còn tiêu được bao nhiêu đến
  cuối kỳ**; ghi một hóa đơn đã trả khi đến hạn; xem tháng này tiền đi đâu; nhập sao kê
  và đối chiếu số dư; thử một khoản mua ("trả góp 6 tháng có ổn không"); thiết lập tài
  khoản, khoản định kỳ, mục tiêu, ngân sách; sao lưu, xuất file.

**Câu hỏi của màn hình** (skill §2.2)

- **Hôm nay** (`/`): "Từ giờ đến cuối kỳ mình còn tiêu được bao nhiêu, và sắp phải trả
  gì?" Số lớn nhất là **Có thể chi** (kèm mỗi ngày bao nhiêu). Phát hiện đọc đầu tiên là
  dòng dưới con số: khoản sắp đến hạn gần nhất, hoặc **thiếu bao nhiêu** khi âm (không
  bao giờ che bằng số 0). Nút chính **Ghi khoản chi**.
- **Sổ** (`/ledger`): "Tháng này tiền đi đâu?" Khối lớn nhất là danh sách giao dịch theo
  ngày; bên cạnh (desktop) hoặc phía trên (điện thoại): thu, chi, còn lại của tháng; cột 6
  tháng (cũng là bộ chọn tháng); chi theo danh mục (chạm để lọc); ngân sách. Báo cáo cũ
  gộp vào đây.
- **Kế hoạch** (`/plan`): "Tiền có đủ đến cuối kỳ không, và đã hứa trả những gì?" Khối
  lớn nhất là đường số dư dự báo với **điểm thấp nhất** được ghi chú. Rồi: khoản định kỳ,
  mục tiêu để dành, thử trước.
- **Tài khoản** (`/accounts`): "Mình có gì và nợ gì?" Số lớn nhất là tài sản ròng theo
  từng loại tiền (không tự quy đổi). Tài khoản xếp thành Tiền tiêu được, Tiết kiệm, Nợ.
  Mở một tài khoản (`/account/<id>`): số dư, Đối chiếu, Nhập sao kê, giao dịch gần đây,
  các lần nhập (hoàn tác).

**Flow mới**

1. Mở app vào **Hôm nay**. Chưa có tài khoản: khung vẫn giữ, chỗ con số là câu "Bắt đầu
   bằng số tiền bạn đang có" và nút **Thêm tài khoản**. Có tài khoản nhưng chưa có khoản
   định kỳ: một dòng gợi ý thêm lương và tiền nhà để ước tính sát hơn.
2. **Ghi khoản chi** (Ctrl N, ở mọi khu): một tờ nhập riêng thay cho form 11 ô cũ. Ô số
   tiền to được focus sẵn, gõ kiểu Việt (`45.000`, `45k`); Chi | Thu | Chuyển; chip danh
   mục (dùng gần đây trước); đối tác có gợi ý, chọn đối tác thì điền sẵn danh mục theo
   quy tắc hoặc lần trước; chip tài khoản, **ngày chọn bằng lịch** (không gõ), "Dự kiến";
   chuyển khoản thêm tài khoản nhận, tỷ giá khi khác tiền, phí. Ghi chú và nhãn nằm trong
   "Thêm chi tiết". Lưu xong báo "Đã ghi" kèm **Hoàn tác**.
3. Chạm một giao dịch thì mở lại tờ đó để sửa; menu của tờ: Ghi hoàn tiền, Ghi lại như
   khoản mới, Xóa. Giữ lâu (điện thoại) hoặc ô chọn (desktop) để chọn nhiều: Xuất, Xóa.
4. Hóa đơn đến hạn: ngay trên Hôm nay, mỗi dòng có **Đã trả** (ghi thành giao dịch hôm
   nay, có Hoàn tác).
5. **Nhập sao kê** từ một tài khoản hoặc kéo thả file (Windows/web): bốn bước Chọn file →
   Ghép cột → Soát dòng → Xong (đối chiếu số dư cuối, Hoàn tác lần nhập).
6. **Thử trước**: Thử một khoản mua hoặc Kịch bản mới → trang kịch bản (`/whatif/<id>`):
   gốc và giả định cạnh nhau, ảnh hưởng ngân sách, giả định chạm để sửa; "Ghi thành giao
   dịch thật" chỉ một lần.
7. **Cài đặt** (`/settings`): tiền và ngày, riêng tư (ẩn số tiền, khóa thiết bị), nhắc,
   danh mục, quy tắc, dữ liệu (sao lưu, khôi phục, lịch sử nhập, kiểm tra, hoàn tác), Pro.
   Nút ẩn số tiền còn có ở thanh trên để dùng nhanh nơi đông người.

**Yếu tố đặc trưng:** **thanh tiền đã hứa**. Một thanh dài bằng số tiền đang có (cộng
thu nhập chắc chắn khi bật). Thanh chia thành từng hóa đơn sắp tới (xám, có tên khi đủ
chỗ), tiền để dành mục tiêu, dự phòng, và phần còn lại **màu xanh của app**: chính là
"Có thể chi". Thiếu tiền thì phần vượt ra ngoài cuối thanh màu đỏ. Ngay dưới là bảng
cộng trừ khớp từng đoạn của thanh: đó là bằng chứng nằm cạnh đáp án.

**Khuôn mặt:** màu của app chỉ nằm trên phần tiền còn tiêu được (thanh, đường dự báo
tháng này, cột tháng đang xem) và nút chính. Mọi con số khác là mực đen, dấu +/− nằm
trong chữ chứ không ở màu. Chỉ khoản thu mới có màu xanh dương tính kèm dấu "+".

**Màu:** Spend nhận `#2E7D32` (xanh lá tiền, 123°). Màu tím cũ `#7C3AED` bị loại vì bộ
cấm tím và chàm. Khoảng màu còn trống duy nhất đủ xa các app khác: cách Recall 39°, cách
Dev 34°. Tài khoản và danh mục là đồ của người dùng nên mang chấm `HandyPalette` theo thứ
tự tạo. Trường màu cũ của danh mục được giữ trong dữ liệu nhưng không dùng để vẽ.

**Bố cục và nền tảng**

- Điện thoại (< 840 px): thanh dưới 4 khu Hôm nay, Sổ, Kế hoạch, Tài khoản. Nút **Ghi**
  nổi ở Hôm nay và Sổ, không che dòng nào. Tờ nhập mở toàn màn hình. Back đóng tờ, rồi
  về khu trước.
- Desktop/tablet (≥ 840 px): công tắc 4 khu đặt trên thanh trên (như Dev), nút chính ở
  thanh trên. Hôm nay hai cột (con số, thanh và bảng cộng trừ | sắp tới và gần đây). Sổ
  hai cột (tháng 360 px | danh sách). Kế hoạch hai cột. Tài khoản: danh sách | chi tiết.
  Tờ nhập là hộp thoại 560 px.
- Phím tắt: Ctrl N ghi, Ctrl I nhập sao kê, Ctrl F tìm trong sổ, Ctrl Z hoàn tác, Ctrl 1–4
  đổi khu, Esc đóng.
- Web: `/account/<id>`, `/whatif/<id>`, `/import`, `/import/<tài khoản>`, `/settings`,
  `/settings/categories`, `/settings/rules`, `/imports`; bốn khu nằm trong `/` (đổi khu
  không đổi URL, như công tắc của Dev); kéo thả sao kê.
- Android/iOS: khóa sinh trắc hoặc PIN (Windows Hello); nhắc hóa đơn qua thông báo không
  có số tiền hay đối tác; che màn hình khi app chạy nền.

**Trạng thái:** tải: khung cuối cùng, con số thay bằng thanh xám đúng cỡ. Lỗi mở dữ
liệu: một câu, Thử lại, không đặt lại gì. Tháng trống: khung giữ nguyên, một câu và nút
ghi. Số 0 in là 0; thiếu dữ liệu in là "—". Ẩn số tiền: mọi con số là "••••" (thanh vẫn
đúng tỷ lệ nhưng không có nhãn số). Lưu lỗi: tờ nhập giữ nguyên, một câu dưới nút Lưu.
Kịch bản cũ hơn sổ hiện tại: một thông báo "Sổ đã đổi, kịch bản vẫn dùng bản gốc".

**An toàn (giữ từ bản cũ):** mọi thay đổi qua `SpendController.change` (kiểm tra
revision, ghi nguyên tử, nhật ký); hủy tờ nhập không đổi sổ; "ghi lại như khoản mới" tạo
ID mới và bỏ dấu lô nhập, dấu kỳ định kỳ. Xuất file hỏi trước vì chứa dữ liệu riêng tư.
Khôi phục kiểm tra toàn bộ rồi hỏi hai lần. Nhập sao kê: soát xong mới ghi, dòng trùng
bỏ chọn sẵn, không tự xóa, chênh lệch đối chiếu không tự sửa, hoàn tác từ chối dòng đã
sửa. Thử trước không bao giờ ghi vào sổ trừ khi bấm ghi thật. Kỳ dự báo trên 30 ngày,
kịch bản thứ hai, so sánh, nhân bản và lưu hồ sơ ghép cột cần Pro.

**Loại bỏ:** bốn tab cũ kèm icon tài khoản và menu 8 mục; tab Báo cáo riêng; form chung
11 ô với ngày gõ tay `YYYY-MM-DD` và màu `#RRGGBB` gõ tay; thẻ bọc mọi khối; ExpansionTile
chứa tính năng chính; chữ hoa "ƯỚC TÍNH", "MÔ PHỎNG", "QUÁ HẠN"; màu đỏ trên mọi khoản
chi; icon màu theo danh mục.

**Tiến độ:** xong. `today/` (con số, `promised_logic.dart` tách từng khoản đã hứa theo
đúng cách engine tính, thanh và bảng cộng trừ, sắp tới với Đã trả), `entry/` (tờ ghi:
`entry_logic.dart` thuần Dart, `parseAmount` đọc `45.000`/`45k`/`1,5tr`), `ledger/` (bộ
lọc thuần Dart, tháng, cột 6 tháng, danh mục, ngân sách, xuất), `plan/` (dự báo nét đứt
có điểm thấp nhất, khoản định kỳ, để dành, thử trước), `accounts/`, `import/` (bốn bước),
`settings/`, `shell/`. Quảng cáo chỉ hiện ở trang gốc, không ở Kế hoạch, form hay trang
con (`NavigatorObserver`). Đồng ghi là "đ" vì Geist và Bricolage không có ký tự ₫.

**Bổ sung 2026-11-02: hóa đơn, chia tiền, gợi ý định kỳ, mẫu sao kê, "Dự báo nếu…"**

Chạy lại skill (app-screens, `draw.mjs --app --keep palette,type`, kiểu achromatic-ledger,
seed 1425736859): giữ nguyên màu `#2E7D32`, Bricolage + Geist; màu chỉ trên dữ liệu (đường
dự báo, đường kịch bản theo `HandyPalette`), mọi con số khác là mực.

- **Hóa đơn trong tờ ghi.** Việc: giữ bằng chứng của một khoản. Hành động chính vẫn là
  **Lưu** (hóa đơn chỉ vào sổ khi Lưu; Hủy bỏ hết). Khối "Hóa đơn · n" cuối tờ: ảnh thu nhỏ
  72 px, nút ✕ đánh dấu bỏ (hiện "Giữ lại" để đổi ý), nút **Thêm** (điện thoại: menu Chụp
  ảnh / Chọn file; desktop, web: chọn nhiều file). Giới hạn ghi ngay dưới khối. Trạng thái:
  trống (chỉ nút Thêm), đang chờ lưu ("Mới"), file sai loại hoặc quá cỡ (một câu dưới nút
  Lưu, không thêm gì), đủ 10 file (ẩn Thêm). Dòng sổ có biểu tượng kẹp giấy kèm số, không
  chỉ là màu.
- **Xem hóa đơn** (`/receipt/<id>`): ảnh to hết khung, chụm để phóng; PDF là một khung
  tên + hướng dẫn mở bằng app khác. Thanh dưới: Lưu một bản | Chia sẻ (ẩn nơi OS không
  có). Xóa ở thanh trên, xóa ngay kèm Hoàn tác. File thiếu/hỏng: một thông báo đỏ, không
  hiện ảnh sai.
- **Chia tiền** (chip "Chia tiền" trong tờ ghi khoản chi): một câu hỏi, "mỗi người bao
  nhiêu?". Tổng to ở đầu; Chia đều | Theo phần | Số cụ thể; danh sách người (bạn luôn có,
  người quen hiện sẵn không chọn), thêm người ngay tại chỗ; dòng trạng thái sống "Cộng lại
  đúng X đ" hoặc "Còn thiếu / Vượt tổng X đ" (đỏ). Nút chính **Dùng cách chia này** bị từ
  chối kèm lý do khi chưa khớp. Lưu cùng khoản chi trong một thay đổi.
- **Ai nợ ai** (`/people`, `/person/<id>`): hai con số "Người khác nợ bạn" | "Bạn nợ",
  câu giải thích cách tính vào Có thể chi, danh sách người (chấm màu nhận diện, "Nợ bạn
  …" / "Bạn nợ …" / "Hết nợ"). Nút chính: **Người khác trả giúp bạn**. Trang một người:
  số dư là tiêu đề, khoản còn mở và đã xong; nút chính **Thanh toán** mở form số tiền
  (mặc định cả phần còn nợ, ít hơn là trả một phần), tài khoản **không chọn sẵn** (người
  dùng xác nhận tiền đi qua đâu), ngày bằng `pickHandyDate`. Hôm nay chỉ thêm một dòng
  nhỏ dưới bảng cộng trừ khi khác 0; Tài khoản có mục "Chia tiền · Ai nợ ai".
- **Gợi ý định kỳ** ("Có vẻ lặp lại"): đầu cột phải của Kế hoạch và cuối bước Xong khi
  nhập sao kê. Mỗi gợi ý: tên, số tiền, "Hàng tháng · 3 lần, gần nhất …"; **Thêm định
  kỳ** mở form định kỳ điền sẵn (chưa lưu gì), **Không định kỳ** ẩn vĩnh viễn kèm Hoàn
  tác. Không có gợi ý: khối không hiện.
- **Mẫu nhập sao kê**: bước Ghép cột hiện thông báo xanh "Đã đọc theo mẫu …" với **Không
  dùng**; bước Soát có ô "Lưu cách ghép cột thành mẫu (Pro)" và tên mẫu. Cài đặt → Mẫu nhập
  sao kê (`/settings/templates`): tên, tóm tắt cột và định dạng; đổi tên, xóa có Hoàn tác.
- **"Dự báo nếu…"** thay khối Thử trước riêng: ngay dưới biểu đồ dự báo, mỗi kịch bản là
  một chip có chấm màu (chính là chú giải của đường), chạm để vẽ/ẩn; "Thử một khoản mua",
  "Thay đổi khác". Khi có đường bật: khối so sánh ba cột thẳng hàng (Thấp nhất, Cuối kỳ,
  Thiếu từ) cho "Như hiện tại" rồi từng "Nếu …", kèm chênh lệch ngày thấp nhất; "Giả
  định" mở `/whatif/<id>` (trang giờ vẽ cùng biểu đồ trên sổ hôm nay). Bảng Từng ngày thêm
  dòng "Nếu …" cho mỗi đường. Free: một kịch bản; bật hai đường cùng lúc cần Pro.

**Bề rộng 320–1440.** 320: tờ chia tiền một cột, số tiền mỗi người canh phải; số trong
"Sắp tới" không bao giờ bị cắt (tên nhường chỗ); dòng nợ trên Hôm nay giữ "đ" liền số.
390: ba cột so sánh vừa một hàng. ≥ 840: tờ ghi và tờ chia là hộp thoại 560 px, Kế hoạch
hai cột (dự báo + so sánh | gợi ý, định kỳ, để dành).

**Nền tảng.** Android/iOS: chụp hóa đơn qua camera của OS (iOS cần
`NSCameraUsageDescription`), chia sẻ qua sheet OS, Back đóng tờ con trước. Windows: chọn
nhiều file, chia sẻ qua sheet Windows, Lưu một bản. Web: chọn file, lưu trong IndexedDB,
"Lưu một bản" là tải xuống; URL `/people`, `/person/<id>`, `/receipt/<id>`,
`/settings/templates`, `/whatif/<id>` mở trực tiếp.

**Loại bỏ:** khối "Thử trước" tách khỏi dự báo và trang So sánh riêng; mẫu ngân hàng
dựng sẵn; màu là dấu hiệu duy nhất của hóa đơn/chia tiền trên dòng sổ.

**Tiến độ:** xong trên host (widget/engine test, ảnh review). Chưa chạy camera, chia sẻ
OS hay trình duyệt thật.

## Lộ trình

| Bước | Phạm vi                                              | Trạng thái |
| ---- | ---------------------------------------------------- | ---------- |
| 1    | Kit chung + Tools (bàn làm việc, băng, QR, mật khẩu) | Xong       |
| 2    | Dev                                                  | Xong       |
| 3    | Keep                                                 | Xong       |
| 4    | Recall                                               | Xong       |
| 5    | Bookmark                                             | Xong       |
| 6    | Docs                                                 | Xong       |
| 7    | Media                                                | Xong       |
| 8    | Xóa widget UI cũ trong `handy_ui`, ảnh review mới    | Xong       |
| 9    | Spend                                                | Xong       |
| 10   | Habit                                                | Xong       |

Bước 8 giữ lại `handy_ui.dart` + `local_app.dart` (khi đó Spend còn dùng; nay vẫn dùng trong `handy_pdf`, `handy_scan` và vài integration test) và `workflows.dart` (quy trình văn bản của Docs); các widget cũ khác đã xóa, khung ảnh chung chuyển vào kit (`HandyPictureFrame`).

Ảnh review của mọi app đã làm lại (kèm GIF chuyển động) gom vào `review-shots/`
(không commit): `python tooling/review-shots.py [app…]`, mở `review-shots/index.html`.

Icon của cả 7 app (Android, iOS, Web/PWA, Windows) sinh từ một nguồn:
`python tooling/app-icons.py [app…]`. Màu và glyph khai báo ở đầu script.

Mỗi bước: hợp đồng → dựng → widget test theo flow mới (giữ mọi kiểm tra an toàn dữ
liệu) → `melos analyze` + `melos test` xanh → chụp ảnh và soát theo skill.

## Hợp đồng: Handy Habit

Làm lại từ đầu ngày 2026-11-02, thay cho bản dựng trước (teal `#0D9488`, hợp đồng tiếng
Anh; ảnh soát cũ trong `docs/qa/evidence/habit-ui-review.pdf` thuộc bản đó).

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: **thói quen** (có/chưa, số lần, phút, số lượng có đơn vị; mục tiêu tới 3 số
  lẻ; lịch hằng ngày, các thứ đã chọn, N ngày mỗi tuần, mỗi N ngày; lịch có lịch sử hiệu
  lực; nhóm; ưu tiên; lưu trữ theo kỳ), **lần ghi** (tổng theo ngày, bỏ qua có lý do, ghi
  bù trong khoảng cho phép, nguồn tay hoặc từ quy trình), **quy trình** (các bước có thứ tự,
  giây dự kiến và tối thiểu, bắt buộc, được bỏ, liên kết thói quen; thứ trong tuần, giờ gợi
  ý), **phiên chạy** (bản chụp các bước, thời gian thực, ghi chú bước, kết thúc hoặc hủy),
  nhắc (giờ, thứ, giờ yên lặng, nhắc lại sau 10 phút).
- Quy mô thật: 3–12 thói quen, 1–5 quy trình 3–8 bước (5–40 phút); vài lần ghi mỗi ngày;
  lịch sử 1–3 năm.
- Người dùng: một người, mở điện thoại vài lần mỗi ngày, mỗi lần dưới 10 giây (đánh dấu
  một việc), sáng và tối chạy một quy trình 10–30 phút với màn hình mở; thỉnh thoảng xem
  lại tuần trên máy tính.
- Việc, theo thứ tự hay gặp: **đánh dấu việc hôm nay** (một chạm; số lượng thì cộng
  nhanh); **chạy quy trình** và đi từng bước; xem chuỗi ngày của một thói quen; sửa ngày
  quên ghi; tạo hoặc sửa thói quen, quy trình; xem lại tuần, tháng; đặt nhắc; sao lưu.

**Câu hỏi của màn hình** (skill §2.2)

- **Hôm nay** (`/`): "Hôm nay còn việc gì, và bắt đầu quy trình nào?" Tiêu đề là lời chào
  kèm sự thật của ngày ("Chào buổi sáng. Còn 3 việc, Buổi sáng lúc 6:30"). Khối lớn nhất
  là danh sách việc hôm nay, mỗi việc một **tràng hạt**. Phát hiện đọc đầu tiên: phiên
  quy trình còn dở (nếu có) với nút Tiếp tục, đặt trên cùng.
- **Thói quen**: "Mình đang theo những thói quen nào, và cái nào đều nhất?" Danh sách theo
  nhóm, mỗi dòng kèm chuỗi hiện tại. Mở một thói quen: lưới tháng (chạm ngày để sửa trong
  khoảng cho phép), chuỗi hiện tại/dài nhất, hoàn thành trên số kỳ hợp lệ, lịch sử lịch.
- **Quy trình**: "Quy trình nào, dài bao lâu, gồm bước gì?" Mở một quy trình: các bước
  thành một **dải thời lượng** (mỗi bước dài theo số phút), nút chính **Bắt đầu**, bản
  rút gọn (chọn số phút, thấy bước nào rút, bước nào bỏ).
- **Chạy quy trình**: "Bước này là gì, còn bao lâu?" Tên bước và đồng hồ là khối lớn
  nhất; nút chính **Xong bước**.
- **Thống kê**: "Thực tế mình đã làm được bao nhiêu?" Không chấm điểm: mỗi thói quen là
  "hoàn thành trên số ngày (tuần) hợp lệ"; cột số ngày có ghi mỗi tuần; phiên quy trình
  dự kiến và thực tế. Xuất CSV, Markdown, PDF.

Bốn khu Hôm nay, Thói quen, Quy trình, Thống kê được giữ vì bản mô tả sản phẩm yêu cầu,
và vì mỗi khu trả lời một câu hỏi khác nhau. Nội dung và luồng bên trong làm lại hết.

**Flow mới**

1. Lần đầu: một màn ngắn với ba lựa chọn: **Tạo thói quen đầu tiên** (nút chính), thêm ví
   dụ có thể sửa, bắt đầu trống. Không quảng cáo cho tới khi xong.
2. **Đánh dấu**: chạm hạt hôm nay. Có/chưa thì xong ngay; số lần thì mỗi chạm cộng 1;
   phút và số lượng thì mở một tờ cộng nhanh (bằng mục tiêu, nửa mục tiêu, số tự nhập).
   Chạm hạt đã đầy, hoặc giữ lâu, thì mở **Sửa ngày** (tổng của ngày, bỏ qua có lý do, ghi
   chú). Mỗi lần ghi có **Hoàn tác**.
3. **Ghi bù**: trong lưới tháng của thói quen, chạm một ngày trong khoảng cho phép.
4. **Chạy quy trình**: Bắt đầu thì vào màn chạy toàn màn hình; ra nền thì tạm dừng; mở lại
   thì khôi phục và báo; bước có liên kết thì ghi vào thói quen đúng một lần, hoàn tác bước
   gỡ đúng lần ghi đó nếu chưa bị sửa. Kết thúc thì xem tổng kết phiên.
5. **Bản rút gọn**: kéo số phút (5–90), thấy ngay kết quả; chạy một lần, hoặc lưu thành
   quy trình riêng (Pro).
6. **Thêm** (Ctrl N): menu Thói quen mới / Quy trình mới. Giờ chọn bằng đồng hồ, ngày bằng
   lịch, thứ trong tuần bằng 7 chip; không gõ `HH:mm`, `1,2,3` hay `YYYY-MM-DD`.
7. **Cài đặt** (`/settings`): ngôn ngữ, giao diện; lịch (múi giờ, đầu tuần, khoảng ghi bù);
   nhắc (bật, giờ yên lặng, từng lịch nhắc, nhắc tiếp theo); dữ liệu (xuất, nhập hợp nhất
   hoặc thay thế, kiểm tra); Pro; xóa toàn bộ ở cuối.

**Yếu tố đặc trưng:** **tràng hạt**, vật đếm của việc tu tập lặp lại. Mỗi thói quen là một
chuỗi hạt cho 6 ngày có lịch gần nhất và một hạt lớn cho hôm nay ở cuối. Hạt đặc là xong,
hạt nửa là làm dở, vòng rỗng xám là ngày có lịch chưa làm, gạch ngang là bỏ qua có lý do;
ngày không có lịch thì không có hạt. Hạt hôm nay vừa là trạng thái vừa là nút đánh dấu,
đầy dần theo phần trăm mục tiêu.

**Khuôn mặt:** lời chào là tiêu đề, kèm sự thật của ngày lấy từ dữ liệu. Màu của app chỉ
nằm trên hạt hôm nay, bước đang chạy và nút chính. Hạt các ngày trước màu mực.

**Màu:** Habit nhận **đỏ son `#B42318`** (4°), màu duy nhất khác hẳn tám app còn lại; teal
cũ trùng Dev và Bookmark. Vì đỏ là màu của app, Habit **không bao giờ tô đỏ ngày lỡ**: ngày lỡ
là vòng rỗng xám có chữ. Thói quen và quy trình mang chấm `HandyPalette` theo thứ tự tạo;
trường màu và icon cũ vẫn giữ trong dữ liệu nhưng không còn sửa trong app.

**Bố cục và nền tảng**

- Điện thoại (< 840 px): thanh dưới 4 khu; nút Thêm ở thanh trên. Màn chạy toàn màn hình,
  nút Xong bước trong tầm ngón cái.
- Desktop/tablet (≥ 840 px): công tắc 4 khu ở thanh trên (như Spend, Dev), nút Thêm; Hôm
  nay hai cột (việc | quy trình và nhắc); Thói quen và Quy trình: danh sách | chi tiết từ
  1000 px.
- Phím: Ctrl N thêm, Ctrl 1–4 đổi khu, Space tạm dừng hoặc tiếp tục khi chạy, Enter xong
  bước, Esc đóng.
- Web: `/settings`, `/habit/<id>`, `/routine/<id>`, `/run/<phiên>`; bốn khu trong `/`.
- Android/iOS: thông báo nhắc nội dung chung, không tên việc; Windows/Web: không có nhắc
  nền, Hôm nay hiện nhắc tiếp theo trong app.

**Trạng thái:** tải: khung cuối cùng. Lỗi mở dữ liệu: một câu, Thử lại, không đặt lại gì.
Hôm nay không có lịch: một câu và lối sang Thói quen. Chưa có quy trình: một câu và mẫu.
Lưu lỗi: tờ giữ nguyên, một câu dưới nút. Phiên khôi phục: thông báo rằng thời gian chỉ là
ước tính.

**An toàn (giữ từ bản cũ):** mọi thay đổi qua `HabitController.change` (revision, ghi
nguyên tử); hủy tờ không đổi gì; đánh dấu ghi đúng một lần (không vượt mục tiêu nếu chưa
chọn cộng thêm); sửa lịch chỉ có hiệu lực từ ngày tới, không viết lại quá khứ; loại ghi
nhận và đơn vị đã có lịch sử thì không đổi; xóa thói quen gỡ liên kết ở quy trình và nhắc;
xóa quy trình giữ lịch sử phiên; ra nền thì tạm dừng phiên; hoàn tác bước không gỡ lần ghi
đã bị sửa; nhập kiểm tra toàn bộ rồi hỏi, hợp nhất đổi ID, nhắc nhập vào không tự bật.

**Tiến độ:** xong. `today/` (lời chào và sự thật của ngày; `beads.dart` là tràng hạt;
`check_in.dart` đánh dấu một chạm, cộng nhanh, sửa ngày), `habits/` (danh sách theo
nhóm, chi tiết có lưới tháng, trình sửa lịch có hiệu lực từ ngày tới), `routines/` (dải
thời lượng, các bước kéo hoặc lên/xuống, bản rút gọn, tổng kết phiên), `runner.dart` giữ
nguyên logic thời gian, `runner_view.dart` là giao diện mới; xong một bước thì bước kế
chạy luôn. `insights/`, `settings/`, `shell/`. Quảng cáo chỉ ở trang gốc sau màn mở đầu.

**Loại bỏ:** tiêu đề "Handy Habit · tab"; danh sách nút viền xếp chồng; form chung gõ
`HH:mm`, thứ `1,2,3`, màu hex; thanh tiến độ dưới mỗi dòng; lưới 35 nút số ngày; menu ba
chấm cho việc chính; chữ dài giải thích quy tắc trên mọi màn.

**Bổ sung 2026-11-02: kỳ nghỉ và thông báo phiên chạy.** Chạy lại skill (`draw.mjs --app
--kind workspace --keep palette,type --out .taste-skill/habit-more`, kiểu
`editorial-greeting`, seed 973037815; giữ màu và chữ của suite). Dữ liệu: **kỳ nghỉ** (từ
ngày, đến hết ngày, lý do tùy chọn, cho tất cả hoặc vài thói quen); thực tế 0–10 kỳ mỗi
năm, 3–14 ngày mỗi kỳ. Việc: đặt kỳ nghỉ trước chuyến đi (vài giây), biết bao giờ hết,
về sớm thì kết thúc sớm, thỉnh thoảng sửa hoặc xóa.

- **Câu hỏi:** Hôm nay khi đang nghỉ: "Mình có phải làm gì không?" Trả lời ngay ở dòng sự
  thật dưới lời chào ("Đang nghỉ đến Thứ Năm, 12/11. Không có gì phải làm."), kèm lý do
  và nút chữ **Kết thúc sớm** (việc chính khi về). Danh sách việc vẫn hiện, hạt hôm nay
  vẫn chạm được (làm thì vẫn tính), nhưng không đếm là "còn việc".
- **Yếu tố đặc trưng:** hạt **nghỉ** là một đĩa nhạt đặc, không viền (như ô "nghỉ phép"
  của dòng thời gian theo loại, không phải vòng rỗng của ngày lỡ, không có màu app). Một
  chuỗi ngày nghỉ trong lưới tháng thành một dải hạt nhạt liền nhau. Hạt hôm nay khi nghỉ:
  đĩa nhạt có hai vạch tạm dừng màu xám.
- **Tạo:** menu Thêm (Ctrl N) → **Kỳ nghỉ**; menu của một thói quen → **Nghỉ thói quen
  này**. Tờ: Từ ngày, Đến hết ngày (lịch `pickHandyDate`), Cho (Tất cả / Chọn thói quen
  bằng chip), Lý do (tùy chọn). Nút chính **Lưu kỳ nghỉ**. Không lùi quá khoảng ghi bù;
  tối đa 366 ngày.
- **Danh sách:** Cài đặt → mục **Kỳ nghỉ** (đang nghỉ, sắp tới, đã qua; chạm để sửa; menu
  Kết thúc sớm, Xóa có Hoàn tác). Chi tiết thói quen có mục Kỳ nghỉ khi thói quen có kỳ.
- **Trạng thái:** chưa có kỳ nào: một câu và nút Thêm; lưu lỗi: tờ giữ nguyên, một câu
  dưới nút; đang nghỉ một phần: dòng thói quen ghi "Nghỉ đến 12/11" thay cho chuỗi.
- **Thông báo phiên chạy (Android/iOS):** khi màn chạy đang mở và app ra nền, phiên vẫn
  **tạm dừng** như trước (không đổi logic thời gian), nên thông báo nói thật: tiêu đề
  "Buổi sáng · Bước 3/5", nội dung "Đã tạm dừng · còn 2:00. Chạm để tiếp tục." Không đồng
  hồ đếm ngược, không thông báo lúc hết bước, vì đồng hồ không chạy. Im lặng, ẩn nội dung
  trên màn khóa (Android `private`, iOS `passive`). Chạm mở `/run/<id>`; vào lại app, xong
  hoặc dừng phiên thì gỡ. Chỉ hiện khi đã bật "Gửi nhắc" (xin quyền ở công tắc đó, chỉ khi
  người dùng bật), công tắc riêng "Báo phiên đang dở" bật, và ngoài giờ yên lặng.
  Windows/Web: không có, như nhắc.
- **Rộng 320–1440:** tờ kỳ nghỉ là trang đầy trên điện thoại, hộp 560 px từ 840 px; dòng
  "Đang nghỉ" xuống dòng tự nhiên ở 320 px, nút Kết thúc sớm ở dòng riêng dưới nó.
- **Loại bỏ:** biểu tượng máy bay, màu đỏ cho ngày nghỉ, hộp cảnh báo vàng, đếm ngược giả.

## Handy Trip design contract - 2026-11-02

Achromatic-ledger, seed 1189929496. Face: travel daybook, actual user photos only.
Signature: a date spine separates planned stops from explicit confirmed visits; cyan
#0284C7 marks confirmed progress, never assumed geography. Trips asks what is next;
Explore what is saved vs visited; Journal what happened when; Passport only real unique
confirmed places/known geography until richer P1 passes its gate. Primary trip action:
add a stop/check in. No fake KPI, map backdrop, stock travel photos or sample visits.
Mobile four bottom destinations per brief; within-trip seven scrollable sections.
At >=1024: sidebar and 300px trip list + 1px divider + remaining detail column, 24px
outer margins, no horizontal page scrolling. At 768 use one content column with inline
section selector; 320 mobile keeps labels and contextual add. Desktop reorder supports
mouse/keyboard; file drop only on an explicit import surface. Web named areas and back.
Use kit fonts/neutral light/dark, labels above inputs, native date picker, >=48px targets,
clear empty/load/error/permission/unsupported/offline states. No permission at onboarding.
Screenshot critique uses app-screens 2.7; widget/emulator evidence distinguished from
browser/physical runtime. Never clone another app's UI or whole UI framework.

### Trip signature features contract

P0 host/native journey and real deny/cancel flows passed before P1 code. Passport adds
photo covers and personal, clearly unofficial stamp exports; its question remains what
the user confirmed visiting. Memory Book asks what to keep/share: one deterministic
daybook with redacted defaults, optional private text and spending, original files intact.
Compare asks how selected trips differ, with currencies on separate rows. Replay is
an explicitly illustrative sequence of saved pins, never a route, basemap or GPS track.
EXIF is a proposal with camera-clock/accuracy caveats and explicit place/date confirmation.
All actions use existing editor, file ports and shared commit/error patterns. No automatic
playback, fake map background, invented geography or prefilled visits. At 320px use one
scrolling column; wider reports expand within the content area; large text remains usable.
Advanced layout controls require real Pro entitlement; never substitute a local flag.

### Trip screenshot critique (app-screens §2.7)

Inspected 70 actual widget captures across 320/390/768/1024/1440 widths, EN/VI,
light/dark, plus native Android Passport/EXIF/comparison/replay and decoded PDF pages.
QA photos are synthetic metadata fixtures, never production examples.

Round 1: removed repeated trip title in the mobile app bar, grouped overview money
figures and selected the current itinerary day when inside the trip dates. Main
actions now answer the page's job; titles and ledger rows share consistent edges.
Round 2: 320px/200% text exposed header/time collisions; bounded the trip title and
moved stop time into the title at large text. Layout test passes. Coincident replay
pins shared overlapping labels; grouped their numbers and suppressed dense labels
above twenty points while preserving the full list. Unconfigured Pro copy removed.

Final review: date/visit counts agree across overview/Passport; unknown geography
has explicit empty labels, not zero coverage. Cyan denotes action/confirmed state;
no decorative map or statistics. Mobile keeps four destinations, seven trip sections
scroll within their own selector, no whole-page horizontal overflow. 320px book
review scrolls while its footer remains reachable. Wider trip views keep a 300px
list/divider/detail. Sparse libraries intentionally retain whitespace. CustomPainter
text uses the platform fallback in widget screenshots; native screenshots are the
reference for those glyphs. Browser/physical accessibility still requires runtime QA.
The supplied frontend lint does not support Dart; its unsupported-extension result
is logged, not represented as a lint pass.

## Mỗi app một phong cách (2026-11-02)

Cả bộ từng được bốc một phong cách chung (accent-ladder) và chỉ khác màu, nên chín
app đặt cạnh nhau đọc như một bộ giao diện mẫu. Nay mỗi app được bốc riêng bằng
`draw.mjs --app` theo loại và brief của chính nó; kit chỉ giữ phần dùng chung
(hành vi, khoảng cách, khả năng tiếp cận, trạng thái trống/tải/lỗi, sao lưu).

| App      | Phong cách         | Chữ                          | Gương mặt                                                              |
| -------- | ------------------ | ---------------------------- | ---------------------------------------------------------------------- |
| Tools    | achromatic-ledger  | IBM Plex Sans                | Không ô logo, khung đen trắng, màu chỉ ở kết quả                       |
| Dev      | data-terminal      | Space Grotesk (+ Geist Mono) | Mở tối; ô tối hơn nền; góc vuông                                       |
| Docs     | framed-sheet       | Literata cho tiêu đề         | Khung xám, tờ giấy trắng bo 16                                         |
| Media    | true-black-flat    | Bricolage                    | Mở tối trên đen tuyền, không viền; ảnh mang màu                        |
| Keep     | framed-sheet       | Be Vietnam Pro               | Nền bìa các-tông, thùng trắng có nhãn                                  |
| Recall   | accent-ladder      | Lexend                       | Màu app leo từ nền nhạt tới nút chính                                  |
| Bookmark | warm modern library | Geist; Newsreader cho tên thư viện và collection | Nền ngà ấm, mặt trắng tách bằng tông, góc 12–26, ảnh là chính (2026-11-06) |
| Spend    | pastel-consumer    | Geist                        | Con số "còn được tiêu" trên ô xanh nhạt bo 24, không viền              |
| Habit    | editorial-greeting | Nunito                       | Lời chào là tiêu đề; mảng một bậc tông, số ở độ đậm thường             |
| Trip     | achromatic-ledger  | Archivo                      | Tiêu đề chữ hoa nhỏ kiểu bảng giờ tàu; màu chỉ ở việc đã xác nhận      |
| Boards   | editorial-greeting | Plus Jakarta Sans            | "Hôm nay" là tiêu đề, một câu tóm tắt; màu magenta `#A61C8E` thay chàm |

Nền tảng: Dev và Media mở tối; phần Giao diện trong cài đặt của hai app chỉ có
Tối (mặc định) và Sáng, vì "theo hệ thống" không còn là mặc định ở đó. Mọi app
vẫn giữ cùng cách back, phím tắt, URL web và hộp thoại theo nền tảng.

## Chức năng đặc trưng đợt 2 (2026-11-02)

Mỗi chức năng theo app-screen run của design-taste-frontend và hợp đồng của
frontend-ui-engineering: một câu hỏi, một hành động chính, đủ trạng thái, 320–1440.

| App                  | Câu hỏi của màn                            | Hành động chính                | Trạng thái                                                   | Nền tảng                                                                           |
| -------------------- | ------------------------------------------ | ------------------------------ | ------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| Trip, xưởng làm tem  | Tem của nơi này trông ra sao?              | Lưu tem (PNG); phụ: tờ in A4   | Không ảnh / có ảnh, đang xuất, lỗi                           | ≥840: xem trước trái, chỉnh phải; điện thoại: xem trước trên; phím mũi tên dời ảnh |
| Spend, ghi một dòng  | Khoản này là gì, bao nhiêu?                | Enter để ghi, có Hoàn tác      | Trống, đang hiểu (dòng xem trước), thiếu số tiền             | Nằm dưới số "có thể chi" ở mọi bề rộng                                             |
| Docs, tìm chữ        | Tôi để chữ này ở tệp nào?                  | Mở tệp khớp                    | Ẩn khi chưa có tệp; dưới 2 ký tự không tìm; không có kết quả | Đầu bàn làm việc                                                                   |
| Recall, dán ghi chú  | Đoạn này thành bao nhiêu thẻ?              | Thêm N thẻ                     | Trống, chưa dòng nào hợp lệ, xem trước 50 thẻ                | Trang toàn màn hình; nút chính ghim dưới                                           |
| Habit, nhìn lại tuần | Tuần qua giữ được bao nhiêu?               | Làm nhỏ lại thói quen đang rơi | Không có gì đến hạn                                          | Hiện ở Hôm nay từ cuối tuần tới hai ngày sau                                       |
| Tools, sổ tính       | Cả trang này cộng lại bao nhiêu?           | Gõ; chạm kết quả để sao chép   | Trống (ví dụ trong ô), dòng lỗi hiện "?"                     | Kết quả thẳng hàng phải; điện thoại cột 112 px                                     |
| Dev, so phản hồi     | Lần này khác lần trước ở đâu?              | So với lần gửi trước           | Giống nhau, quá dài để so                                    | Dấu +/− cho số, vạch 1px cho lựa chọn                                              |
| Media, nối ảnh       | Các ảnh này ghép thành một trang dài chưa? | Nối N ảnh → Lưu ảnh dài        | Trống, 1 ảnh, đang khớp, không thấy đoạn trùng, lỗi          | Dải ảnh kéo để đổi thứ tự                                                          |
| Keep, sắp hết        | Món nào sắp phải mua?                      | Vừa mua thêm                   | Chưa đủ lần mua, đã đoán, có lẽ đã hết                       | Vào "Cần để ý" một tuần trước                                                      |

## Handy Boards design contract - 2026-11-02 (thay bằng "Hợp đồng: Handy Boards · Kanban" ngày 2026-11-07)

Draw: editorial-greeting, seed 1051914986; no redraw. Hue magenta #A61C8E, face
Plus Jakarta Sans (`HandyBrand.boards`); the indigo #6366F1 and Geist/Bricolage of
the first draft were replaced on 2026-11-02 and indigo is banned. Face: workspace/
board name as a working heading, figures regular weight, tonal panels. Signature:
category blocks with a persistent identity strip, progress fraction and independent
status marks. Identity colors are data, never decorative rainbow chrome.

Jobs/questions: Boards: what belongs where? Category overview: which group needs
attention? Kanban: what is moving? Today: what must happen next? Calendar: when?
Insights: what progress is actually measurable? Detail: what does this task need?
Primary action: contextual fast add. Empty app offers blank/template explicitly;
no seed data on startup. Errors preserve form input; commit blocks duplicate taps.

320px one readable column, 375/430px optional compact 2x2 four-category overview;
large text uses single column. 768px two/three blocks; >=1024 labelled 228px
workspace/board sidebar and fluid content, max1100px with 16px gaps. Category
count determines columns (up to four), not four permanent unreadable phone lanes.
Kanban scrolls its own columns; no whole-page sideways overflow. Context menus,
keyboard move alternatives, Ctrl+N capture/Ctrl+F search, explicit back/browser
routes. iOS/Android use native date controls via kit, Windows mouse/focus, Web
named screens and in-app reminders. Touch targets >=48px, semantic labels and
text accompany colors. Loading/error/retry/empty/offline/unsupported states.
Reject KPI vanity tiles, fake team avatars/maps/AI, Trello branding, tiny four
phone columns, school labels in generic forms, gesture-only actions and dead Pro
buttons. Inspect screenshots at all widths against app-screens 2.7 before report.

### Handy Boards — kiểm tra ảnh §2.7

Đã xem 49 ảnh Flutter thật của bộ fixture kiểm thử qua bảy contact sheet và ảnh
gốc: điện thoại 375/430, VI 320, VI 200%, tablet 768, desktop 1440, dark 1024.
Fixture chỉ nằm trong test; bản cài mới không tạo task hay quyền Pro giả.

1. Nhóm là câu trả lời chính của màn Category; bốn khối Mathematics/Java/English/
   Physics cùng hiện ở 375/430. Today nêu việc cần chú ý, Insights nêu mẫu số thật.
2. Mép nội dung thẳng hàng; không ép 4 cột trên điện thoại. Khi chỉ có một task,
   vùng trống là mặt làm việc, không kéo giãn card để lấp màn hình. Table cuộn
   ngang trong vùng riêng; desktop sidebar rộng 228px.
3. Màu đặt trên danh tính nhóm, trạng thái và lựa chọn chính. Không tô màu trang
   trí lên KPI. Mặt chữ Geist/Bricolage giữ diện mạo editorial-greeting đã chọn.
4. Fixture có một task cấp đầu, chưa hoàn tất, 30 phút ước lượng: Category,
   Kanban, List, Table và Insights đều dùng cùng UUID; 0/1 và 0/30 khớp nhau.
5. Nhóm trống là 0/0 và phần trăm là dấu gạch, không tạo 0% giả. Hạn thiếu có
   câu giải thích. Bộ đếm Today ghi rõ hàng đợi nào, không giả số thông báo.
6. Màu nhóm trên task trùng khối tương ứng; nhãn trạng thái độc lập. Calendar đã
   tăng chiều cao ô theo text scale để không đè số lượng task lên ngày.
7. Điện thoại dùng bốn đích điều hướng có tên; 320/200% chuyển một cột, cho cuộn.
   Nhãn app và trường dài được rút gọn có chủ ý, không cắt nút thao tác chính.

Ba lỗi đã sửa từ vòng ảnh đầu: ngưỡng 375px làm mất bố cục 2×2; Kanban ban đầu
hiện cột Backlog rỗng thay vì cột có task; Calendar tràn ở 200%. Vòng mới phát
hiện Table cần tăng chiều cao hàng theo chữ lớn; đã sửa và chụp lại. Bảy contact
sheet và ảnh gốc nằm trong `review-shots/boards`. Chưa xem đủ mọi editor/nội dung
50k task hay screen reader trên thiết bị thật. Công cụ lint/inspect HTML của skill
không xác minh bố cục Flutter Dart; kết quả widget/ảnh không được đổi tên thành
kiểm thử trình duyệt hoặc thiết bị thật.

### Soát ảnh theo §2.7 (2026-11-02)

Mỗi app được chụp lại và soát theo bảy câu hỏi của app-screens §2.7; đã sửa:
Bookmark (tên link trong mục lục và dải chưa xếp dùng mặt chữ báo; bốn công tắc
trạng thái trên một hàng), Docs (hai việc dở trên một hàng ở điện thoại, không
chừa nửa bàn trống), Media (nút xuất dạng tô đặc mất biểu tượng), Habit (bỏ mũi
tên Nunito không có), Keep (nhãn xám nhỏ trên giá trị mực), Trip (ngân sách và chi
tiêu thành hàng nhãn-số căn phải, "còn lại" là câu trả lời; màu Trip trên dấu đã
xác nhận), Tools (sổ tính: tên dòng có số, kết quả hiện hai số lẻ). Tools, Dev,
Recall, Spend đạt không cần sửa. Chưa có ảnh review cho so sánh phản hồi của Dev.

Handy Boards follow-up: review expanded to 94 widget captures, including task/rule/
saved-view editors, export, Study, Focus, Calendar week and advanced day/week tools.
Large-text Timeline now keeps readable bar text and collapses lengthy assumptions;
Focus scrolls for long titles; empty Study metadata no longer renders a lone dot.
Test-owned Pro channel fixtures exist only in tests; release uses real store adapters.
No browser inspector result or physical-device certification is inferred.

Boards final follow-up: 97 widget images now include exam editing, with 320px VI
200% checks. Saved-view dropdowns were changed to expand within the dialog after
the image test caught a 19px overflow; the rerun passed. Three detail contact sheets
(phone, large-text, desktop) were inspected. No physical/store/browser claim.

Boards localization/accessibility batch: boolean controls now carry their actual
property name instead of repeated Enabled labels. Dates use the display locale
after board-timezone conversion. Screen-reader labels distinguish task completion,
selection, dates and dropdowns. Ctrl/Cmd+Enter submits the current dialog; native
text-input and screen-reader review remains unverified. All 97 widget captures
were regenerated; desktop/phone/large-text checks did not report layout overflow.

Boards image review correction: at 200% text, long switch labels were squeezed
beside their controls despite no RenderFlex exception. Boolean labels now use
the full width at large text size, with controls below. Export recurrence options
appear only for template formats. Regenerated the 97 captures and review sheets.

Handy Boards remaining-scope contract: see docs/HANDY_BOARDS_REMAINING_WORK.md. Reuse the existing style/seed. Reports, working-calendar controls, reviewed imports, cancellable progress and opt-in widget previews extend current canonical workflows; test 320-1440 and large text before claiming completion.

# Handy Forms — design contract

Framed sheet, seed 1472575188; no redraw. Face: blue-grey paper frame, teal
#1B6C80 data/action hue; IBM Plex Sans (reuse bundled licensed Tools font).
Signature: version spine beside the form, making Draft versus Published vN visible.
Objects: forms, pages, stable fields, immutable versions, answer drafts, records,
repeatable rows, attachments, report definitions and workflow events. Production
starts empty; practical templates are schemas, never fabricated submissions.
Home asks “Which form do I need to collect from?”; primary action New form, with
published forms offering New entry. Studio asks “What will people fill in?”;
primary action Preview/Publish, field palette/canvas/properties at >=1100, two
panes tablet, stepped editor phone with explicit reorder actions. Entry asks
“What remains before submitting?”; field errors and autosave state visible.
Records asks “Which responses need attention?”; search/filter and bounded pages.
Report asks “What will I export?”; preview before export, real selectable PDF.
320–1440 widths, VI expansion/200% text, labelled controls and keyboard save;
empty/loading/error/cancel and denied permissions preserve data. Back confirms
discard where needed; Web routes identify form/version/record, shortcuts never
bypass validation. No gradients, generic KPI tiles, dead Pro controls or seeded
production totals. Native capabilities have upload/manual alternatives; kiosk
is an app screen, never presented as OS lockdown. Review screenshots against
design-taste §2.7 before declaring UI verified.

## Handy Card design contract - 2026-11-02

Style dealt by design-taste-frontend (`draw.mjs --app --kind builder`, seed
191118814): **achromatic ledger**. The chrome holds no colour; the card being
designed is the only colour on screen. Face: a blue-grey pasteboard `#F2F4F7`
like a cutting mat, Hanken Grotesk for the chrome, hue `#1450F5` only on the
active selection (frame, handles, snap guides). Signature element: the card on
the mat with its trim, a dashed bleed line and a dotted safe margin, never
part of the exported art.

| Screen   | Its one question                                 | Primary action | States                                                                                                     |
| -------- | ------------------------------------------------ | -------------- | ---------------------------------------------------------------------------------------------------------- |
| Home     | Which design am I on, or what do I start from?   | New design     | Empty (templates strip + New), loading, load error with retry; designs as real thumbnails, newest first    |
| New      | What am I making, at what size?                  | Create         | Kind, size preset or custom, orientation, one or two sides, template or blank                              |
| Studio   | Is this card right?                              | Export         | Nothing selected (card inspector), one, many, inside a group, text editing, pan mode, unsaved/saved        |
| Profiles | Which identity does this card speak for?         | Save profile   | Empty, invalid links listed beside their field, private values marked                                      |
| Export   | What do I hand over, and will it print and scan? | Save file      | Format, side, size/DPI, bleed and crop marks, warnings (missing faces/pictures, QR too dense), busy, error |

Studio layout: at 1100 px and wider, layers and the add palette on the left
(248 px), the canvas well in the middle, the inspector on the right (288 px).
From 720 to 1100 px the inspector stays and layers open in a sheet. Under 720
px the canvas takes the screen, a bottom bar holds Add, Layers, Edit, Arrange,
Undo and Redo, and the inspector and layers open as bottom sheets; handles grow
to 44 px touch targets. Works from 320 px.

Platform behaviour: designs autosave 600 ms after the last edit; Back (system
back, Android predictive back, Esc on desktop) leaves the studio after the save
finishes. Desktop and web shortcuts: Ctrl/⌘ Z, Shift Z or Y, C, V, X, D, A, G,
Shift G, S, E, Delete, arrows (Shift for 10), +/−/0 for zoom, Space to pan.
Touch: tap selects, drag moves, two fingers pan and zoom, long-press adds to
the selection. Web URLs: `/` and `/design/<id>`. Ads never appear in the
studio, the export sheet or anything that shares.

Patterns rejected: a tutorial wall, coloured chrome or tinted tool tiles, a
form that edits a static preview (the canvas is the editor), fake buttons for
NFC or Wallet (not built; marked not started in the matrix).

Handy Forms P1 automation contract: the editor answers "what happens after this
local event?" Primary action saves a draft rule; publication binds it to future
responses. Show trigger, readable condition and real bounded actions, never a
script editor. Mobile uses scrollable dialogs; desktop retains the version spine.
Execution history answers "did it run and can I retry?" Empty/pending/error/done
are distinct; no success before durable commit. Labels and explanations EN/VI,
320-1440px, keyboard/touch alternatives, no ads in editing/execution dialogs.
Generated reports stay local until explicit export. Automation never chains its
own transitions or bypasses workflow requirements. In-app reminders remain honest
when system notification adapters are unavailable.

## Feature round 3 contracts - 2026-11-03

Ideas filtered from a community survey (J2TEAM posts with the most interest in
tools people built or asked for); each lives inside its app's existing face,
hue and signature, adds no tab, and works offline. Skill runs:
design-taste-frontend app-screen run (§2.1 inventory, §2.2 one question, §2.7
check on widget shots at 320/390/768/1440) and frontend-ui-engineering (job,
primary action, states, accessibility, patterns to reject).

### Tools: Bốc thăm (draw lots)

- Question: "who (or what) did chance pick?" The result is the largest thing
  on the panel, in the ledger face, with the list it came from beside it.
- Data: a list typed or pasted one per line (2-500 entries, duplicates kept as
  written), a count to pick (1..n), a team count (2..n), coin, dice `NdM`
  (1-20 dice, 2-100 sides). Randomness from `Random.secure`.
- Modes as one chip row: Pick, Teams, Coin, Dice. Primary action: Draw again
  (also Ctrl Enter). Earlier draws stay listed under the result while the
  panel is open, so a draw is shown as made, not redone quietly; nothing is
  stored. Results longer than 60 characters drop a size so teams fit a phone.
- States: empty list (the chip row still works for coin and dice), fewer
  entries than asked (inline message, button disabled), result.
- Teams are balanced by count (sizes differ by at most one); order inside a
  team is the draw order.
- Reject: wheel spin animation, confetti, sounds, emoji dice.

### Tools and Keep: Đo bằng ảnh (measure from a photo)

- Question: "how long is this, in mm/cm?" The answer label sits on the line
  that was measured; the list of measurements is the second block.
- Flow: choose a photo (camera on phones, file elsewhere), drag the two
  reference handles onto a known edge (bank card long edge 85.60 mm by
  default; card short edge 53.98 mm, A4 297/210 mm, or typed mm), then tap two
  points per measurement. Handles drag; Undo removes the last measurement.
- Honesty: one line under the picture says the result holds only when the
  object and the reference lie flat in the same plane, photographed square on;
  results are rounded to 1 mm and shown as estimates ("≈ 42 mm").
- Keep: from an item, "Measure from photo" uses the item's photo when it has
  one; "Add to notes" appends "Đo: 42 × 18 cm" to the item's notes after a
  confirm; nothing else changes.
- States: no photo, reference not set (measuring disabled, the reference line
  pulses once), reference shorter than 20 px on screen (warn: too small to be
  accurate), result.
- Keyboard: arrow keys nudge the selected handle by 1 px (Shift 10 px).
- Reject: AR or depth claims, automatic edge detection presented as exact.

### Media: Khung ảnh chụp màn hình (screenshot frame)

- Question: "does this screenshot look ready to share?" The framed preview is
  the whole first block, true black around it as Media's face.
- Controls under the preview, one row each: background (6 flat swatches, the
  photo's own average colour, transparent), padding (0-25% of the short side),
  corner radius (0-48 px at export scale), shadow (off/soft), frame (none,
  phone, browser bar drawn flat). Save PNG at the source resolution; the
  preview frames a 900 px copy the same way, so what is seen is what is saved.
- States: no image (pick or paste), working (the preview stays, export
  disabled), export error. Limits as the image tools: 16 Mpx output.
- Reject: gradient backgrounds, glass, mock devices with brand marks.
- 2026-11-03: framing and joining share one studio tile, "Screenshots", which
  opens the picker at once; one picture goes to the frame, several to the
  join, and a joined picture can be framed next. No mode to choose first.

### Docs: Word từ chữ nhận dạng (OCR to DOCX) and in hai mặt (manual duplex)

- OCR result sheet gets "Save as Word (.docx)": paragraphs as recognised,
  one page break between scanned pages, the document title from the scan's
  name. A minimal Office Open XML package written by Docs, no layout claims.
- PDF actions get "Print both sides by hand": two PDFs (odd pages; even pages
  last first) and the three steps with the page numbers in each file; with
  an odd count the steps say to take the last sheet out, since PDFium here
  cannot add a blank page. File names follow the reader's language. And "Number the pages":
  position (bottom centre/right), start number, skip first page; written as a
  new PDF, the source kept.
- States: no OCR text (action hidden), PDF without pages, a one-page PDF
  (duplex not offered).
- Reject: a print preview mock, claims about printer driver behaviour.

### Recall: Chép chính tả (dictation)

- Question: "did I write it right?" The comparison (correct words in ink,
  wrong in the hue's error tone with the expected word beside it) is the
  largest block after answering.
- From a deck: "Dictation" plays the answer side with the deck's voice
  (existing TTS), the learner types, Check shows the word-level diff; Play
  again and slower (0.6x) stay available. Grading stays on the existing
  review buttons; "All right" is said plainly above the words. The card
  shrinks to 28% of the height in dictation so the field and the check
  stay in view; review shortcuts pause while typing.
- Accents and case ignored by a toggle (default: case ignored, accents
  counted, since Vietnamese marks matter). Punctuation ignored.
- States: no voice for the deck's language (explain, offer the typed prompt
  instead), empty answer, all correct.
- Reject: a score percentage as the headline, streak confetti.

### Card: thiệp mời, A4 and CV

- New sizes: A4 portrait (210 × 297 mm) and A5 (148 × 210 mm) in the size
  presets, kind "invitation" and "document".
- New original templates: wedding invitation (two sides, QR to the venue map
  link, RSVP line), birthday or housewarming invitation (A5), one-page CV
  (A4: name, role, contact block bound to the profile, experience, skills).
  Every text uses the existing bindings, so a profile fills the CV.
- Same editor; no new screen. The template strip shows them with the rest.
- Reject: stock photos, ornament clip art, script faces not bundled.

### Forms P0/P1 editor and reporting completion contract (2026-11-03)

- Job: arrange a draft form, collect it clearly, and export only reviewed data.
- Primary actions: select/reorder a field; undo a draft edit; submit; choose a report.
- Keep the framed-sheet face, IBM Plex Sans and teal version spine. No new app shell.
- Layout: half-width fields pair only at >=700px and normal text scale. At 320px
  or large text every answer uses full width. Sections remain labeled; no hidden required answers.
- Drag has up/down menu alternatives; Ctrl+Z/Y work on the draft and never mutate
  published schemas. Conflicting external edits refuse undo instead of overwriting.
- Report templates use real answer bindings and vector PDF output. Logos are
  explicitly imported sanitized small PNGs; charts expose missing values and units.
- Empty/loading/error remain explicit. Native notification prompts occur in Settings,
  answer contents never appear on the lock screen, and the in-app center always works.

## Tap audit - 2026-11-03

Each app's most frequent job, counted in taps from its home screen (typing
not counted; system camera and pickers count as one). Target: two or fewer.
Read from the flows the widget tests drive.

| App      | Job                       | Taps | Note                                                                |
| -------- | ------------------------- | ---- | ------------------------------------------------------------------- |
| Tools    | Work out a sum or convert | 0    | Type on the bench                                                   |
| Dev      | Look inside pasted data   | 0    | Paste; the lens is detected                                         |
| Spend    | Log a spend               | 1    | One line on Today, then Enter                                       |
| Habit    | Check in today            | 1    | Today's bead                                                        |
| Bookmark | Save a copied link        | 1    | Clipboard button in the top bar                                     |
| Recall   | Review a card             | 2    | Show answer, grade                                                  |
| Keep     | Add a thing               | 2    | Add, type the name, save                                            |
| Boards   | Add a task                | 2    | Quick add, type, save                                               |
| Card     | Start a design            | 2    | New, Create (defaults filled)                                       |
| Media    | First picture of a guide  | 2    | New guide, add a picture                                            |
| Trip     | Mark a visit              | 1    | Was 3+ (long form and a confirm switch); now Visited / I'm here now |
| Docs     | Photograph the first page | 1    | Was 2; Scan now opens the camera when there is one                  |

## Docs: Gửi tệp qua QR (send a file by moving QR codes) - 2026-11-03

Run: design-taste-frontend app-screens + frontend-ui-engineering. Lives in
Docs because it moves a file, the thing Docs holds; Tools works on text.

- Job: move one small file to a phone or tablet in the same room when there
  is no cable, no network and no account (a contract PDF from the Windows
  laptop to a phone, a note between two phones). The screen's one question:
  "is it arriving?"; its finding: "12 of 40 frames".
- Data: the file's name, size and SHA-256; frames of 480 bytes, one header
  frame; 100 KB at most (about 35 seconds a loop at 6 frames a second).
- Entry: one quiet tile under the start grid, "Send to another device / Gửi
  sang máy khác", route `/transfer` (web URL `#/transfer`). Not a fifth start
  card: it is not a way to begin work, and the four-across grid stays whole.
- One screen, two sides, chosen by a segmented control: Send and Receive.
  Receive is the side shown first on a phone with a camera (the phone is
  usually the receiver); Send elsewhere. No mode beyond that.
- Send: Choose file (primary) → the code plays at once on a white sheet
  (white in dark mode too, with a quiet zone), as large as the width allows
  up to 420 px; under it the name, size and "frame 3 of 40". Pause/Resume
  and Choose another file. Playing is the content, not decoration, so it
  runs with reduced motion on; Pause holds one frame. Signature: the code
  sits on Docs' paper sheet, the same sheet the desk's work cards use.
- Receive: the camera fills the top; under it the file name once the header
  is read, a bar and "12 of 40", then "Save file" (primary) and "Receive
  another". Frames come in any order; a missed one comes round next loop.
  The checksum decides: a damaged file is never offered to save.
- States: no file yet (one line on what fits: up to 100 KB); file too large
  or empty (notice, nothing plays); camera missing (web, Windows: "Receiving
  needs the camera of an Android or iOS device; send from here"); camera
  denied (retry); waiting for the header (frames still counted); damaged
  (notice, start over); saved (the name, Receive another).
- Platforms: Send on all four; Receive on Android and iOS. Back leaves and
  stops the camera; Space pauses on Windows and web; nothing touches the
  network.
- Reject: a progress ring, a fake "connecting" step, a transfer history,
  sending folders or several files, compressing behind the user's back.

## Handy Widget design contract (2026-11-03)

Style: editorial-greeting, seed 725218380, `.taste-skill/widget/direction.json`.
Chosen because this is a personal art library with a short creation ritual, not
an operations dashboard. Face: original art on a white editorial canvas, with
Manrope controls and Lora for one editorial headline. The dealt Instrument
Sans/Serif pair was replaced after real glyph validation found missing Vietnamese
letters; the replacement original font files pass the full U+1EA0..U+1EF9 range.
Signature: **Theme spread** -- a real wallpaper with several actual rendered
widget compositions, reused from pack detail to install preview. Never represent
this composition preview as a capture from an installed native widget.

Data/jobs inventory: theme packs; unique compositions; three size variants;
wallpapers; decorative assets; font/license entries; saved user instances;
managed personal photos/crops; favorites; confirmed native installations.
Counts come from validated manifests, not promotional counters. User jobs are
choose a look, adjust photos/text, save, install/export, and recover their data.

Theme-sheet export contract: answer "What will this coordinated look contain?"
with an actual canonical-renderer composition, pack title and a permanent
composition-preview label. Open a review dialog before PNG export; preserve a
cancel action, bound raster output to 1080x1920, and exclude private projects.
Use the same theme face, no decorative export chrome. Fit the review to 320px
and desktop, keep actions keyboard accessible, show loading/error states, and
do not report cancelled file dialogs as successful exports. This is a static
image, not an installation flow or an updating clock.

Static-text controls extend the existing advanced inspector: choose left/center/
right, enter a validated six-digit color, or clear it to follow the palette.
Invalid intermediate input stays in the field and never corrupts a saved project.
Show an explicitly palette-only contrast ratio; photo/layer backgrounds can vary,
so this ratio must not claim universal accessibility. Preserve undo/autosave and
respect locked layers. Dynamic native clock styling remains separately limited.

Background editor contract: answer "What sits behind my widget?" in a compact
basic inspector section, keeping the canonical preview visible. Offer Template,
Solid, Gradient, Photo and Texture with only relevant controls shown. Gradients
belong inside the widget artwork, never studio chrome. Photo selection must finish
validation/normalization and persistence before switching mode; cancellation and
errors preserve the previous design. Reuse existing crop and undo/autosave rules,
portable managed media and privacy warnings. Existing projects without background
settings render identically. Use EN/VI labels, wrapping choices at 320px, labelled
sliders, inline invalid-color errors, and explicit image replacement/reset actions.

Photo-preset extension: Polaroid, three-frame film and taped scrapbook remain
ordinary templates in the existing gallery/editor. They share photo slots,
portable media, crop and native rendering. Editable captions use the existing
words field with localized defaults; long captions ellipsize at actual available
line height. Review all three sizes with real fonts; never use a launcher mockup
as proof that these presets were installed on the OS.

Wallpaper crop contract: answer "Which part will I save?" with the actual raster
crop as the preview. Keep original dimensions by default; explicitly select
portrait aspect, focal position, zoom and quarter-turn rotation. Preview and PNG/
JPEG exports share the engine operation. Debounce preview work, discard stale
results and bound concurrency; never export a loading placeholder. Preserve
source art, keep reset/cancel/error/retry reachable, and do not imply automatic
OS wallpaper setting. Controls wrap at 320px and sit beside art where width
permits. Label sliders for keyboard/accessibility; ads remain outside this flow.

Saved-widget favorites: reuse the project favorite field, independent of theme
favorites. A labelled heart in the editor toggles via normal undo/autosave; My
Widgets uses the same favorites filter as Discover, scoped to saved designs.
Do not force a theme favorite to mark every user project. Preserve the flag on
reset and ZIP restore. Empty filtered results must offer clearing the filter.

Screens/questions and primary actions:

- Discover: Which look fits my screen? Actual art dominates; open a theme.
- Theme detail: How does this set work together? Theme spread; Use theme.
- Editor: Does this widget look right with my content? Preview leads; Save.
- My Widgets: Which saved design should I edit or install? Real saved renders;
  Edit/Add to Home Screen where a supported native path exists.
- Wallpapers: Which background should I save? Real portrait art; Export.
- Settings/backup: Can I recover this library? Counts and reviewed ZIP restore.

Layout: centered 1100px desktop canvas (12x77 +11x16), 16px gaps and variable
8/4 or 6/6 spans for theme spreads. The gallery uses actual peer art tiles, no KPI
row. Tablet uses two readable columns; 320px/large text uses one column and
stacked actions. Editor controls are a sheet on phones, inspector beside preview
on desktop. Touch >=44px; keyboard editing has explicit alternatives to dragging.

States: bundled library is available without a network. My Widgets starts empty
with a choose-theme action. Missing/corrupt media offers Replace and retains the
project. Native installation distinguishes requested/confirmed/unavailable;
never fake success. Import has preview, cancel, duplicate handling and rollback.
No user photos leave the device except explicit share/export. Ads are absent
from installation and the native widget. Loading keeps geometry; errors stay
beside the action that failed. Reduced motion disables nonessential transitions.

The subject's requested glass/neon/gradient aesthetics are allowed inside the
original theme artwork, not app chrome. No fake popularity, vanity counts,
empty gallery cards or recolor-only padding. Each pack starts with owned artwork;
its preview uses the same renderer and real clock/calendar data as its instance.

Handy Widget follow-up: literal captions in older photo templates use a free
labelled Photo caption field, autosave and the same undo stack as other edits.
The single scene remains the truth; no second editor or duplicate project is
created. The controlled draft observes undo without replacing keyboard focus
on each keystroke. Empty text is allowed; invalid/overlong content cannot reach
the model. Existing records retain their original appearance until edited;
project-v2 migration happens only on save. Canonical art uses bundled shared
GeistMono for mono scenes rather than relying on a generic OS font. App chrome
keeps Manrope/Lora, and the theme spread remains the one visual signature.

Layer keyboard contract: editable scenes expose layers as focusable controls
with localized type/order labels and a selected border. Tab selects a layer;
arrows move it in 0.5% steps; Shift+arrows resize through the same bounded model
callbacks. Each key is one undoable transform. Locked layers remain selectable
for unlocking but cannot move/resize. Preview/export scenes add no interactive
focus targets. Pointer selection and keyboard selection use the same canonical
layer; hidden layers do not enter the focus order. The existing position/size
sliders remain the equivalent alternative. Instructions appear beside the
editable preview, without adding a toolbar or a second editor.

## Refactor 2026-11 · lát S1: ẩn và bỏ (hợp đồng)

Quyết định: [PRODUCT_DECISIONS_2026_11](PRODUCT_DECISIONS_2026_11.md).

- Docs "Gửi sang máy khác": chỉ hiện dòng dưới lưới bắt đầu khi bật công tắc
  "Thử nghiệm: gửi tệp bằng QR chạy" trong Cài đặt (mặc định tắt). Bàn làm việc
  mặc định chỉ còn bốn lối bắt đầu và tệp đã giữ. `#/transfer` vẫn mở trang để
  link cũ không gãy. Trạng thái: tắt (không dòng), bật (dòng như trước).
- Keep: menu của một món không còn "Đo bằng ảnh"; đo bằng ảnh là việc của Tools.
  Ghi chú đo đã có vẫn là văn bản thường trong ghi chú.
- Reject: hộp thoại "tính năng đã bỏ", nút mờ không bấm được, tự xoá ghi chú đo cũ.

## Refactor 2026-11 · lát S2b: Keep Collections (hợp đồng)

Run: design-taste-frontend app-screens (giữ `HandyBrand.keep`: tấm giấy trên nền
các-tông, Be Vietnam Pro) + frontend-ui-engineering.

- Dữ liệu: món là bản ghi duy nhất; bộ sưu tập chỉ tham chiếu (một món ở nhiều
  bộ). Số lượng thật: vài bộ, mỗi bộ 5–200 món; mục tiêu do người dùng đặt.
- Lối vào trên màn chính (một cơ sở dữ liệu): Đồ trong nhà (như cũ), Kệ bộ sưu tập,
  Thùng (bộ lọc cũ), Muốn có (bìa đầu kệ khi có món muốn có).
- Màn chính: kệ chỉ hiện khi không tìm, không lọc, không xem một thùng. Chưa có bộ
  nào: một nhóm hai dòng ("Sưu tầm thứ gì?", "Thử một kệ mẫu"), không lấn danh sách
  đồ. Có bộ: các bìa 104 px đứng trên một tấm ván kệ màu viền (chi tiết riêng của
  Keep), nhãn ngắn "6/24" hoặc "4 món". Món muốn có/đang đặt không nằm dưới chỗ để
  nào và không vào tổng giá trị.
- Trang bộ (câu hỏi: "có gì rồi, còn thiếu gì?"): con số lớn nhất là "6/24" (hoặc
  số món), dòng dưới "6 đã có · 1 đang đặt · 2 muốn có · còn thiếu 18", thanh tiến
  độ theo màu bộ khi có mục tiêu. Lưới bìa (cột theo bề rộng, tối thiểu 2), món đã
  có trước theo thứ tự riêng, "Còn muốn có" sau, bìa mờ. Thanh dưới: "Muốn có" và
  "Thêm món" (chính). Menu ⋯: bỏ bộ (món vẫn còn), gỡ bộ mẫu.
- Muốn có: danh sách theo ưu tiên, mỗi dòng có "Đã có"; trang món muốn có thay ô
  chỗ để bằng ghi chú + nút "Đã có rồi". Đã có = cùng bản ghi, ngày mua hôm nay.
- Form món: chỉ khi người dùng có bộ sưu tập (hoặc món không phải đã có) mới hiện
  chọn bộ, trạng thái Đã có/Đang đặt/Muốn có, rồi dòng và số; phiên bản, lần phát
  hành, tình trạng, trường riêng của loại bộ gập sau "Thêm thông tin sưu tầm". Món
  gia dụng lưu y như cũ (test kiểm khoá JSON không đổi).
- Ô không ảnh: nền nhạt màu bộ, chữ cái 22% cạnh theo màu nhận diện; không chữ đen
  khổng lồ.
- Bộ mẫu: id tiền tố `sample-`, 4 board game chung chung, có ghi chú "Bộ mẫu" và gỡ
  một chạm; không trộn vào dữ liệu thật.
- Nền tảng: route `#/collection/<id>`, `#/wishlist`; Back về màn chính; desktop dùng
  cột nội dung của kit.
- Reject: giá thị trường tự động, danh mục "chính thức", huy hiệu/điểm, độ hiếm tự
  đoán, bìa là món chưa có, nhân bản món vào từng bộ.

## Refactor 2026-11 · lát S3: Xưởng làm tem (hợp đồng)

Ngoại lệ bắt buộc của quyết định 2026-11: giữ và nâng cấp. Run: design-taste-frontend
app-screens (giữ `HandyBrand.trip`) + frontend-ui-engineering.

- Câu hỏi của Xưởng: "tem của lượt ghé này trông thế nào?"; lớn nhất là bản xem trước.
  Dưới nó: Ảnh, Kiểu tem (chip nhóm + dải hình thu nhỏ vẽ bằng chính bộ vẽ, chữ là địa
  điểm thật), Màu mực, Chữ, Nghiêng, Độ mòn. Thanh dưới: Tờ A4, PNG, "Giữ tem" (chính).
- 40 kiểu, 7 nhóm; không có hai kiểu chỉ khác màu mực (test kiểm
  `shape/edge/decor/weight`). Vẽ hoàn toàn bằng code (vector), không ảnh tải về, không
  phông ngoài.
- Giữ tem: lưu thiết kế vào lượt ghé đã xác nhận (`visit.stamp`), mở lại đúng kiểu,
  màu, ảnh, vị trí; chỉ ảnh của chính lượt ghé hoặc ảnh bìa chuyến.
- Hộ chiếu: mục "Tem của bạn · N" ngay dưới số lượt ghé, nhóm theo chuyến, ô 112 px
  vẽ tem thật, chạm để sửa, "In tờ A4" gom mọi tem (12/trang). Chưa có tem: một dòng
  chỉ cách làm. Biểu tượng con dấu cạnh mỗi địa điểm mở Xưởng.
- Trang địa điểm: "Làm tem" / "Sửa tem" cho lượt ghé mới nhất.
- Không bao giờ: tự tạo lượt ghé, tem cho lượt chưa xác nhận, nhãn "chính thức".

## Refactor 2026-11 · lát S4: Thư viện mẫu Card (hợp đồng)

Run: design-taste-frontend app-screens (giữ `HandyBrand.handyCard`: màu của Card
chỉ ở chọn/tay nắm; màu thuộc về thiết kế của người dùng) + frontend-ui-engineering.

- Màn chính: "Bắt đầu từ mẫu" chỉ còn một mẫu mỗi dịp (7) và "Xem cả N mẫu".
- Thư viện mẫu (`/templates`): câu hỏi "mẫu nào hợp dịp này?"; dòng đầu "N mẫu · đổi
  được mọi chữ, màu và ảnh", chip dịp (Danh thiếp, Mạng xã hội, Thiệp mời, Sự kiện/tờ
  rơi, Cửa hàng/thẻ giá, CV, Portfolio), lưới bản xem trước dựng lười (2–6 cột theo bề
  rộng), chạm là tạo thiết kế và mở xưởng.
- Mẫu: 44 bố cục mới × 2–3 phong cách (Giấy trắng, Giấy kraft, Đêm, Xanh xô thơm, San
  hô), mỗi phong cách đổi màu, cặp phông và hoạ tiết hình học (gạch, vòng, thanh, lục
  giác, chấm); không hai mẫu nào trùng hình học mặt trước (test). Mọi phần tử là phần
  tử thật của scene graph, trường liên hệ gắn hồ sơ.
- Ô ảnh là chỗ để ảnh của người dùng (khung gạch chéo đến khi có ảnh), không phải
  ảnh minh hoạ giả.
- Reject: đếm bản đổi màu là mẫu mới, ảnh/logo/phông tải ngoài, dải ngang 140 mẫu.

## Refactor 2026-11 · lát S5: khung ảnh chụp màn hình của Media (hợp đồng)

Run: design-taste-frontend app-screens (giữ `HandyBrand.media`) + frontend-ui-engineering.

- Câu hỏi: "ảnh này đã đẹp để gửi chưa?"; bản xem trước luôn trong tầm mắt (điện
  thoại: 42% trên cùng, điều khiển cuộn bên dưới; màn rộng: xem trước bên trái, cột
  điều khiển 420 px bên phải có tiêu đề trang).
- Thứ tự điều khiển: Kiểu nhanh (12, một chạm) → Tiêu đề (tuỳ chọn) → Khổ ảnh (Vừa
  ảnh, 1:1, 4:5, Story 9:16, Slide 16:9) → Nền (8 màu phẳng, theo màu ảnh, trong suốt,
  6 nền chuyển hai màu) → Khoảng trống, Bo góc, Khung (không/điện thoại/trình duyệt),
  Đổ bóng.
- Tiêu đề do app vẽ bằng phông Bricolage của Media thành PNG (đủ dấu tiếng Việt),
  sáng hay tối theo nền; engine đặt trên ảnh, trong khoảng trống.
- Kiểu nhanh khác nhau ở khổ, khung, nền và bo góc, không chỉ đổi màu; mọi giá trị
  sửa được sau khi chọn.
- Reject: ảnh nền tải từ mạng, logo thương hiệu thiết bị, nền tím/chàm.

## Refactor 2026-11 · lát S6: Tools theo tình huống (hợp đồng)

- Bàn trống: "Thử gõ" là tình huống thật (VAT, giảm hai lần, % thay đổi, tip và chia,
  lương, đổi đơn vị, khoảng ngày, đọc số), rồi "Gần đây" (5 công cụ mở gần nhất,
  chỉ lưu id), rồi Đã ghim + Tất cả công cụ.
- Kệ (màn rộng) theo tình huống: Hằng ngày, Tiền, Văn bản, Thêm (mật khẩu, bốc thăm,
  đo bằng ảnh, phụ đề, âm lịch). Biến đổi văn bản không có ô riêng: bàn làm trên chữ
  dán vào.
- Bàn hiểu "a + VAT p%", "a - p% - q%", "a lên b", "a tip p% chia n", "a chia n" (dấu %
  của máy tính là phép dư, nên các câu này trước đây ra lỗi hoặc số sai).

## Refactor 2026-11 · lát S7a: gợi ý thói quen của Habit (hợp đồng)

- "Thêm thói quen" mở một tấm: "Tự đặt từ đầu" ở trên, rồi 32 gợi ý trong 8 nhóm
  (Buổi sáng, Buổi tối, Vận động, Học tập, Giấc ngủ, Chăm da, Màn hình, Việc nhà).
  Chạm một gợi ý chỉ điền sẵn trình sửa (tên, kiểu ghi nhận, đơn vị, mức tối thiểu,
  lịch, nhóm); không lưu gì cho tới khi người dùng bấm Lưu. Gợi ý trùng tên với thói
  quen đã có thì ẩn. Mẫu quy trình từ 6 lên 8 (thêm Chăm da tối, Nghỉ màn hình).
- Reject: điểm, thú ảo, huy hiệu, "AI coach", tự thêm thói quen.

## Refactor 2026-11 · lát S7b: bộ thẻ mẫu của Recall (hợp đồng)

- Màn trống của Bộ thẻ có thêm một hành động hạng ba "Thử bộ mẫu (20 thẻ)" dưới hai nút
  "Bộ thẻ đầu tiên" / "Nhập từ Anki": 20 từ du lịch tiếng Anh (có giọng đọc en-US), đến
  hạn ngay để ôn thử luôn.
- Bộ mẫu có id `sample-` và chữ "(mẫu)" trong tên; trong bộ có một thông báo "Đây là bộ
  mẫu" với "Gỡ bộ mẫu" (một chạm, gỡ cả thẻ). Lịch sử ôn nằm trong thẻ nên gỡ bộ là gỡ
  luôn số liệu của nó, không lẫn vào thống kê thật.
- Reject: tự thêm bộ mẫu khi mở app, bộ mẫu không gỡ được, số liệu giả.

## Refactor 2026-11 · lát S7c: Spend ghi lại một chạm (hợp đồng)

- Dưới dòng ghi nhanh của Hôm nay, khi dòng còn trống: "Ghi lại:" và tối đa 4 chip
  "Tên · số tiền" cho các khoản chi/thu đã ghi y hệt (cùng tài khoản, nơi, danh mục, số
  tiền) từ 2 lần trở lên trong 4 tuần. Chạm một chip là ghi lại hôm nay, báo "Đã ghi …"
  kèm Hoàn tác. Đang gõ thì chip ẩn.
- "Yêu thích" được suy ra, không phải danh sách người dùng tự giữ. Hoá đơn định kỳ, dòng
  nhập sao kê, chia tiền, hoàn tiền, khoản chờ và tài khoản đã lưu trữ không tính; khoản
  tháng (Netflix, Internet) không lọt vào vì cửa sổ là 28 ngày.
- Chế độ ẩn số: chip hiện "••••". Mỗi chip có nhãn đọc "Ghi lại hôm nay: …".
- Reject: nút sao để ghim yêu thích, chip hiện khi đang gõ, ghi mà không có Hoàn tác.

## Refactor 2026-11 · lát S8: Dev chỉ chỗ lỗi JSON, JSON Pointer, lịch sử gửi (hợp đồng)

- JSON hỏng (bắt đầu bằng `{` hoặc `[`, không phải JSONL/TOML) vẫn mở là JSON trước tiên;
  thông báo lỗi nói "Dòng 4, cột 1: bỏ dấu phẩy thừa ngay trước: }" (dấu phẩy thừa, nháy
  đơn, khóa không nháy, chú thích, thiếu dấu phẩy, hết sớm) và có "Chỉ chỗ lỗi" chọn đúng
  ký tự đó trong ô Nguồn.
- Nhấn giữ hoặc chuột phải một dòng của cây JSON: Chép JSONPath, Chép JSON Pointer (RFC
  6901, `~1` cho `/`), Chép giá trị. Chạm vẫn chọn dòng và đưa JSONPath lên dòng trạng thái.
- "Đã gửi" dưới các collection: công tắc, mặc định tắt; khi tắt có một câu nói rõ sẽ giữ
  gì (method, địa chỉ bỏ giá trị query, mã, thời gian, kích thước; không header, body,
  bí mật; tối đa 50, trên máy). Mỗi dòng: tên request, đường dẫn mono, rồi kết quả; lỗi
  và "không có phản hồi" bằng chữ đỏ, không chỉ bằng màu. Chạm mở request gốc nếu còn.
  Tắt có xác nhận "Tắt và xoá N lần gửi?" và xoá hết.
- URL lưu là mẫu của request qua `sanitizeRequest` (biến `{{env}}` giữ nguyên, không
  thay giá trị environment). Tệp lịch sử hỏng thì bắt đầu lại, tắt.
- Reject: bật sẵn lịch sử, lưu header/body, phát lại request từ lịch sử (dễ gửi lại dữ
  liệu nhạy cảm), đồng bộ.

## Refactor 2026-11 · lát S9: Boards bỏ "người phụ trách" và "bình luận" khỏi màn cá nhân (hợp đồng)

- Boards là bảng cá nhân. Trình sửa việc không còn ô "Nhãn người phụ trách" trừ khi việc
  đó đã có nhãn; bộ lọc và điều kiện của chế độ xem đã lưu chỉ có "Nhãn phụ trách" khi
  bảng có việc mang nhãn (hoặc chế độ xem đang dùng nó). Dữ liệu, chỉ mục, sao lưu, xuất
  giữ nguyên.
- "Bình luận" thành "Ghi chú" có ngày: nút Ghi chú trong chi tiết việc ghi một mục vào
  lịch sử cục bộ như trước (action `comment` giữ nguyên trong dữ liệu, hiện là "Ghi
  chú"). Không có luồng trả lời, không có người.
- Reject: xoá dữ liệu người phụ trách cũ, đổi tên action trong dữ liệu, ẩn nhãn đã có.

## Refactor 2026-11 · lát S7d: Recall luyện thẻ vừa quên và thẻ khó (hợp đồng)

- Cuối buổi ôn có thẻ "Quên": nút phụ "Ôn lại N thẻ vừa quên" trên nút về Hôm nay; mở
  một vòng luyện các thẻ đó ngay.
- Trong bộ thẻ, sau dòng số liệu ("… · quên 6 lần"): liên kết "Luyện N thẻ khó" khi có
  thẻ quên từ 2 lần trở lên (nhiều nhất 30, quên nhiều trước). Không đẩy nút "Thêm thẻ"
  xuống dòng.
- Luyện thêm không đổi lịch: hai nút "Chưa nhớ" (thẻ quay lại cuối vòng) và "Nhớ rồi";
  phím 1 là Chưa nhớ, 2–4 là Nhớ rồi; không ghi gì vào dữ liệu. Màn kết thúc nói rõ
  "Luyện thêm không đổi lịch ôn của thẻ".
- Reject: luyện thêm đổi khoảng cách ôn, tự mở vòng luyện, đếm điểm.

## Refactor 2026-11 · Bookmark gộp link trùng có duyệt (hợp đồng)

- Việc: link đã lưu hơn một lần (cùng quy tắc nhập dùng để bỏ trùng) được gom thành nhóm;
  người dùng chọn bản giữ lại rồi bấm "Gộp N". Không gộp tự động.
- Lối vào: Cài đặt › Dữ liệu link, ô "N link lưu trùng" chỉ hiện khi có trùng. Route
  `/duplicates` (web có URL riêng).
- Mỗi nhóm: tiêu đề Newsreader trên đường kẻ, nút "Gộp N" bên phải; từng bản là một radio
  với ngày lưu, bộ sưu tập, "có ghi chú", "có bản đọc", "đã lưu trữ". Mặc định giữ bản cũ
  nhất.
- Gộp: nhãn hợp lại, ghi chú nối nhau, bộ sưu tập/tiêu đề trống lấy từ bản kia, yêu thích/
  ghim/đã đọc giữ nếu bản nào có, lưu trữ chỉ khi mọi bản đều lưu trữ, số lần mở cộng dồn,
  ngày lưu và lời nhắc lấy sớm nhất; vị trí trong thứ tự tay là vị trí của bản đầu tiên.
  Nếu bản đọc offline thuộc bản bị gỡ, thông báo nói rõ để lưu lại.
- Trạng thái: không còn trùng ("Mỗi link chỉ lưu một lần."), lỗi ghi (thông báo, dữ liệu
  không đổi). Một cột, tối đa 720px.
- Reject: gộp tự động khi lưu, xoá bản trùng không hỏi, coi `www.`/dấu `/` cuối là cùng
  trang (khác quy tắc nhập).

## Refactor 2026-11 · Card đổi bảng màu một chạm (hợp đồng)

- Nút bảng màu trên thanh studio mở một tấm thấp: một hàng 10 bảng màu (5 phong cách của
  mẫu + Biển, Mực đen, Rừng đêm, Nắng, Hồng đất; không tím/chàm). Lớp phủ gần như trong
  suốt để thẻ vẫn thấy rõ; mỗi chạm đổi cả thẻ và là một bước Hoàn tác.
- Engine nhận ra bảng màu đang dùng (≥ 3 màu khớp) và đổi theo vai trò (nền, chữ, chữ phụ,
  nhấn, chữ trên nhấn) tuỳ chỗ màu nằm; màu người dùng tự chọn giữ nguyên.
- Thiết kế dùng màu riêng: tấm nói rõ "Thiết kế này dùng màu riêng…" và các ô bị mờ.
- Ô đang dùng viền màu chọn của Card (#1450F5, chỉ dùng cho lựa chọn).
- Reject: đổi màu từng phần tử tự động, bảng màu ngẫu nhiên, tấm che kín thẻ.

## Refactor 2026-11 · Docs kiểu giấy khi quét (hợp đồng)

- Trong "Sửa bốn góc", dưới ảnh: "Đây là gì?" với bốn chip Giữ màu gốc / Giấy tờ / Hóa
  đơn / Bảng trắng. Chọn một chip đặt sắc độ (màu, xám, làm trắng nền) và độ tương phản
  khởi đầu (1 / 1,4 / 2 / 1,3); thanh tương phản vẫn chỉnh được. Một dòng dưới chip nói
  kiểu đó làm gì. Đặt lại về Giữ màu gốc.
- Reject: tự đoán loại giấy, đổi màu ảnh gốc, bộ lọc nghệ thuật.

## Refactor 2026-11 · Spend giải thích chênh lệch khi đối chiếu (hợp đồng)

- Trong "Đối chiếu <tài khoản>", sau dòng "Sổ đang ghi …": khi gõ số dư thật, hiện ngay
  "Thực tế chênh ±X so với sổ." rồi "Nên xem trước:" với các dữ kiện trong sổ có thể giải
  thích: khoản đang chờ chưa tính; khoản định kỳ đã đến hạn chưa đánh dấu đã trả (kèm
  ngày); một khoản 45 ngày gần đây đúng bằng chênh lệch (ghi hai lần hay ngược chiều?);
  14 ngày trở lên chưa ghi gì. Khớp thì "Khớp với sổ. Không cần điều chỉnh."
- Chỉ là gợi ý để xem; Cập nhật số dư vẫn ghi đúng phần chênh là điều chỉnh. Vùng này là
  live region cho trình đọc màn hình.
- Reject: tự sửa khoản nghi ngờ, đoán số tiền chưa ghi, chữ đỏ báo lỗi người dùng.

## Refactor 2026-11 · Card mẫu đã thích (hợp đồng)

- Mỗi ô trong thư viện mẫu có ngôi sao cạnh tên (Thích / Bỏ thích). Khi có ít nhất một
  mẫu đã thích, chip "Đã thích N" đứng ngay sau "Tất cả", mới thích trước. Bỏ thích mẫu
  cuối thì quay về Tất cả. Danh sách lưu trong cài đặt của app (chỉ id).
- Reject: đếm lượt thích, gợi ý theo thích, đồng bộ.


## Implementation continuation ? 2026-11-05

Forms: choose a published form and collect one response. A paper tray shows title, version and actual response count; new entry precedes editing. Basic exposes collection and records, Advanced exposes schema power tools, Operations exposes kiosk and insights. Modes change presentation only; existing formulas, workflow and responses remain intact. On phone the mode picker folds; the collection list starts within the first 60% of the screen.

Boards: capture one task in the current board without configuring a project. An inline composer sits immediately above category/kanban/list content; Table is disclosed under Advanced views. Saved rules, WIP and assignees are never reset by disclosure.

Spend: record an expense before studying the financial plan. A receipt-like capture panel precedes the projection on Today; exact ledger and assumption explanations remain unchanged. No duplicate balance state.

Keep: find a physical item or browse a collection. Items and Collections are explicit destinations; only Items carries place filters and totals. Collection covers belong to the collection area, with an opt-in sample. Switching areas never mutates inventory.

Card: choose an editable design visually, personalize and export. Gallery is first; existing projects have their own section; print-production controls are Advanced. Artwork is a removable image layer, never baked text.

All: scrolling large text, native Back, focus and labelled 48px controls; error retains content, empty states offer the actual first action. No repeated universal home shell is introduced.

Round 4 continuation: Habit keeps daily/weekday capture short; interval/quota schedules stay searchable/selectable in Advanced, and an existing uncommon selection stays visible without conversion. Dates/grouping/priority/notes collapse without clearing their controllers. Widget placement presents numbered OS-specific instructions and separately reports a pin request versus actual installed instances. Media frame presets must differ in geometry, remain editable, and export actual PNGs; increasing a color list does not count as new designs. Dev reviews invalid resolved JSON before network use and never silently discards malformed header lines.

## Hợp đồng: Handy Bookmark · hướng dẫn lần đầu (2026-11-06)

Hợp đồng đầy đủ (bản tiếng Anh): `docs/bookmark-redesign/ONBOARDING_FLOW.md`.

- Câu hỏi: "Lưu đồ ở đây thế nào, và nó đi đâu?" Phát hiện ở bước cuối: "Món đầu tiên
  của bạn đang chờ ở Chưa xếp."
- Khuôn mặt: **mẩu báo**: mỗi thứ đã lưu là một mẩu cắt báo (tiêu đề Newsreader, gạch
  mực, dòng nguồn bằng chữ). Đặc trưng: món lưu **thật** đầu tiên rơi vào dải Chưa xếp,
  xếp chỗ thì trượt xuống dưới tên bộ sưu tập.
- Bốn bước, Bỏ qua ở mọi bước: (1) Lưu một lần, tìm lại được ngay: bốn mẩu từ TikTok,
  Shopee, YouTube, ảnh chụp màn hình xếp vào một cột; (2) Lưu từ bất kỳ app nào: hàng
  Chia sẻ vẽ lại (máy tính: Ctrl V); (3) Lưu món đầu tiên: ô link, Dán link, Chọn ảnh, hoặc
  chia sẻ từ app khác và trang tự nhận ra; (4) Đã lưu, đang ở Chưa xếp: chip bộ sưu tập
  của người dùng hoặc bốn gợi ý (tạo khi chọn).
- Chỉ tự mở khi thư viện trống và chưa từng xong; Cài đặt → Trợ giúp → Cách lưu mở lại.
  `guideDone` nằm trong tuỳ chọn của thư viện. Route `/welcome`.
- Bỏ: mascot, viền sticker, gạch highlight, carousel có chấm, paywall, xin quyền thông
  báo, bài tập giả bị xoá sau đó, bàn tay demo, giấu Bỏ qua, nút chờ animation.
- Sửa 2026-11-07: bản tập theo đúng khung lưu mới. Bấm Handy Bookmark → khung của app (đã lưu vào
  Chưa xếp, thẻ xem trước, "Cho vào bộ sưu tập", các bộ, không liệt kê chỗ đang ở) → ô sáng ở một bộ
  sưu tập "Chạm một bộ sưu tập" → "Đã lưu vào …". Bấm bộ sưu tập ở hàng đầu → khung mở với bộ đó
  rồi, ô sáng ở ✕. Cảnh Tìm vẽ như màn Tìm thật: thanh "← Tìm", ô tròn viền teal có ✕, "Tất cả
  mục · N kết quả", các dòng trong một thẻ (ảnh, tiêu đề, chấm bộ sưu tập · trang, ⋯).

## Hợp đồng: Handy Bookmark · tạo và sửa bộ sưu tập (2026-11-07)

- Việc: đặt một chỗ mới cho đồ đã lưu và làm nó nhận ra được ngay trên Trang chủ, mà
  không rời màn đang xem. Hành động chính: Tạo (sửa: Lưu), nút rộng ở cuối khung.
- Hình thức: **khung trượt từ dưới lên** (không mở trang mới), cao vừa nội dung, kéo
  xuống hoặc Back để huỷ. Điện thoại rộng hết; từ 600 px khung rộng tối đa 560 px.
- Đặc trưng: **huy hiệu xem trước** 52 px cạnh ô Tên: màu và biểu tượng đổi ngay khi
  chọn, đúng như sẽ hiện cạnh tên trên Trang chủ.
- Thứ tự: Tiêu đề → [huy hiệu | Tên] → Mẫu (chỉ khi tạo mới, một hàng chip vuốt ngang)
  → Biểu tượng (một hàng vuốt ngang, ô cuối là emoji) → Màu (Tự động + 6 màu, một hàng)
  → "Thêm tùy chọn" (Nằm trong, Ghi chú; tự mở khi bộ đang sửa đã có) → Tạo/Lưu.
- Mẫu: Công thức nấu ăn, Du lịch, Cần mua, Đọc sau, Xem sau, Công việc, Ý tưởng, Quà tặng.
  Điền tên (khi tên trống hoặc đang là tên mẫu), biểu tượng, màu. Mẫu trùng tên bộ đã có
  thì ẩn.
- Màu: "Tự động" (theo vị trí) và các màu nhận diện của `HandyPalette` mà app dùng được.
  Chỉ hiện ở chấm hoặc nền nhạt cạnh tên, không tô biểu tượng. Lưu `hue:N` trong `color`;
  giá trị cũ (hex) nghĩa là Tự động và được giữ nguyên khi lưu. Bộ con theo màu bộ cha.
- Biểu tượng: "Không có", 16 biểu tượng nét mảnh màu mực, hoặc một emoji (một ký tự).
  Lưu trong `icon` (`emoji:X` hoặc tên biểu tượng); `folder` cũ nghĩa là không có.
- Trạng thái: tên trống báo ngay dưới ô; bộ cha tạo vòng lặp báo khi Lưu; bàn phím mở thì
  khung cuộn, nút Tạo vẫn tới được.
- Ô chọn 44 px, có nhãn đọc màn hình (tên màu, tên biểu tượng, đang chọn).
- Bỏ: trang toàn màn hình cho một cái tên, 32 màu cầu vồng, biểu tượng tô màu theo loại,
  bảng emoji tự làm, gradient, wizard nhiều bước, lưới 16 biểu tượng chiếm nửa màn.

## Hợp đồng: Handy Bookmark · chia sẻ từ app khác (2026-11-07, thay khung "Cho vào đâu?")

- Việc: lưu thứ đang xem mà không rời app đang xem. Chọn Handy Bookmark (hoặc một bộ sưu tập ở
  hàng đầu khung chia sẻ Android) → mục được ghi vào hàng chờ riêng của app trên máy → hiện
  thông báo ngắn "Đã lưu vào Handy Bookmark" / "Đã lưu vào <bộ sưu tập>" → người dùng vẫn ở
  Facebook, TikTok… Không mở app, không hiện màn nào.
- Android: `ShareActivity` trong suốt, không vào Gần đây, tự đóng ngay. Lần sau mở app, hàng
  chờ được đưa vào thư viện (ghi xong mới xác nhận hàng chờ, như trước). Mục không có bộ sưu
  tập nằm ở Chưa xếp; xếp chỗ bằng nút "Cho vào" ở Mới lưu.
- Bỏ: khung "Đã lưu. Cho vào đâu?" tự bật khi mở app (đã thấy "Đã lưu" ở app kia thì không hỏi
  lại); mở app chính khi chia sẻ.

## Hợp đồng: Handy Bookmark · Tìm, trước khi gõ (2026-11-07)

- Câu hỏi: "Thư viện của tôi có gì, bắt đầu tìm từ đâu?" Trước đây màn Tìm mở ra là cả danh
  sách với tiêu đề "Tất cả mục" và hàng biểu tượng không chữ.
- Khi ô tìm trống và chưa có bộ lọc: ô tìm → một khối chia bốn số (Bộ sưu tập, Đã lưu, Yêu
  thích, Chưa xem; mỗi số mở đúng chỗ của nó) → Thẻ (chip "#thẻ số lượng", mở trang thẻ) →
  Mới lưu (lưới mẩu báo như onboarding: ảnh 4:3, nhãn nguồn, tiêu đề Newsreader; 2 cột ở
  điện thoại, tới 5 cột ở màn rộng, hai hàng). Gõ một chữ hoặc chọn chip thì ra kết quả như cũ.
- Thư viện trống: các số là 0, và một câu nói Tìm sẽ tìm theo tiêu đề, trang, thẻ, ghi chú.
- Bỏ: con số "phù phiếm", biểu đồ, ô tìm kiếm có minh hoạ, đám mây thẻ nhiều màu.

## Hợp đồng: Handy Bookmark · Cài đặt và Cách dùng (2026-11-07)

- Mẫu: app Sticky-Wall (cùng studio) và khung "Save links faster" của Tuckii. Cài đặt chỉ giữ
  những gì người dùng tìm tới; công cụ ít dùng nằm trong một trang con.
- Cài đặt, theo thứ tự: thẻ **Pro** (Nâng cấp / Bạn đã có Pro) → **Chung** (Ngôn ngữ, Sáng hay
  tối, Chủ đề màu, Tên thư viện, Nhắc mỗi tuần) → **Riêng tư** (Khóa app) → **Dữ liệu** (Đồng
  bộ có trạng thái; Sao lưu & Khôi phục là hai nút cạnh nhau; Tự sao lưu; Nhập và xuất; Đã xóa
  gần đây có số; Công cụ thư viện gồm cách mở link, mục trùng, kiểm tra link, dung lượng; Xóa
  toàn bộ dữ liệu ở cuối, chữ đỏ) → **Trợ giúp** (Cách dùng) → **Giới thiệu** (Góp ý, Chính
  sách, Điều khoản, Giấy phép, App khác).
- Bỏ: "Đặt lại cài đặt", dòng "Xem lại phần giới thiệu" riêng (đã vào Cách dùng), Dung lượng
  đứng riêng, nhóm Pro ở giữa trang.
- Khóa app: dùng khóa màn hình, vân tay hay khuôn mặt của chính máy (`local_auth`); app không
  giữ mật khẩu. Bật thì phải xác nhận trước; máy chưa có khóa thì báo và để tắt. Khóa khi mở app
  và khi quay lại sau hơn một phút; che cả khung và hộp thoại. Không có trên web.
- Cách dùng: thẻ lớn "Xem lại phần giới thiệu" → danh sách chủ đề (Lưu link nhanh hơn, Lưu
  ngay trong app, Chuyển link từ app khác, Sắp xếp gọn gàng, Ảnh và ảnh chụp màn hình, Tìm lại,
  Đọc và xem lại, Chia sẻ cho người khác, Dọn dẹp, Giữ an toàn, Pro). Mỗi chủ đề mở khung
  các thẻ bước đánh số, mỗi bước có hình một mảnh màn hình (vẽ bằng màu của app, khoanh đúng
  chỗ bấm). "Lưu link nhanh hơn": bước 1 có nút mở khung chia sẻ thật; Android hướng dẫn nhấn
  giữ rồi Ghim, iOS hướng dẫn Sửa rồi thêm vào Mục ưa thích. Trước/Tiếp và Xong cố định ở đáy.

## Hợp đồng: Handy Bookmark · khung lưu khi chia sẻ (2026-11-07, thay thông báo "Đã lưu" khi chọn app)

- Việc: thấy đúng thứ mình đang lưu (hình, tiêu đề, trang) và cho nó vào đúng chỗ, ngay trong
  app đang xem. Câu hỏi của khung: "Cho vào đâu?". Hành động chính: chạm vào một chỗ (một chạm,
  không có nút Lưu riêng: mục đã lưu sẵn). Chạm xong, khung thu lại thành thẻ "✓ Đã lưu · vào
  <chỗ>" kèm hình nhỏ của mục (~1,2 giây, chạm để đóng ngay). Nếu hình còn đang tải, thẻ chờ tối
  đa 4 giây để mục giữ đúng hình vừa thấy.
- Lưu không bao giờ thất bại: link vào hàng chờ riêng ngay khi tới (như trước), trước khi khung
  hiện. Khung chỉ ghi thêm lựa chọn vào mục đang chờ. Đóng (X, Back, chạm ngoài) = giữ ở Chưa xếp,
  cũng là lựa chọn mặc định đang chọn. "Không lưu" là lối riêng, nhỏ, để bỏ mục vừa tới.
- Bố cục (khung đáy, tối đa 560px, cao tối đa 88%): đầu khung là dấu app + "Handy Bookmark" +
  "Đã lưu vào <chỗ hiện tại>" + nút đóng. Thẻ xem trước: hình 88px bên trái, tiêu đề 2 dòng, trang,
  một dòng mô tả. Khi đang đọc trang: ô hình tối lại với vòng xoay (như thẻ trong app), tiêu đề tạm
  là tiêu đề app gửi hoặc tên trang. Không đọc được: mặt chữ cái của trang, không báo lỗi (app tự
  thử lại sau). Ảnh được chia sẻ: ảnh đó, tiêu đề "1 ảnh" / "N ảnh".
- Danh sách "Cho vào bộ sưu tập": mọi bộ sưu tập, bộ vừa có mục vào gần nhất ở trên cùng
  (không theo cây; bộ con ghi tên bộ cha trước số link), mỗi dòng là dấu bộ sưu tập (màu nhạt +
  biểu tượng/emoji của nó) + tên + số link; chỗ mục đang nằm không liệt kê. "Bộ sưu tập mới" mở
  một ô nhập ngay đầu danh sách (không mở hộp thoại); Thêm là cho vào bộ mới và đóng. App tạo bộ
  đó khi nhận mục (trùng tên thì dùng bộ đã có). Bộ tạo ở lần chia sẻ trước mà app chưa mở để
  nhận vẫn hiện (đọc từ hàng chờ, sửa 2026-11-07: trước đó lần chia sẻ sau không thấy bộ mới).
- Khoá app bật: không liệt kê bộ sưu tập; chỉ xem trước + "Đã lưu vào Chưa xếp. Mở khoá app để
  xếp." Tắt tự đọc trang: không đọc, xem trước chỉ có tên trang.
- Bộ sưu tập ở hàng đầu khung chia sẻ Android (lối tắt) cũng mở khung này, với bộ đó đã chọn
  sẵn và mục đã nằm trong bộ đó; đóng là giữ ở đó, vẫn đổi được hoặc tạo bộ mới (sửa 2026-11-07:
  trước đó lối tắt chỉ hiện "Đã lưu", người dùng không thấy hình và chỗ thêm bộ sưu tập).
- Nền tảng: Android (Flutter vẽ trong `ShareSheetActivity` trong suốt, không vào Gần đây; Back =
  đóng, giữ ở Chưa xếp). iOS dùng Share Extension gốc riêng, chưa có khung này. Web/Windows không
  có Share vào app.
- Trạng thái: đang đọc, đã đọc, không đọc được, tắt đọc, khoá app, không có bộ sưu tập nào, đang
  nhập tên mới, tên trống (Xong bị tắt). Bàn phím đẩy khung lên. 320–1440: hẹp thì hình 72px.
- Truy cập: nút chọn là radio có nhãn "tên, N link"; thẻ xem trước đọc thành một câu; "Đang đọc
  trang" là vùng thông báo; mọi nút ≥ 48px.
- Bỏ: viền đen dày và bóng lệch kiểu Tuckii (đó là thương hiệu của họ); hộp thoại riêng để tạo bộ
  sưu tập; tự đóng theo giờ; nút Lưu riêng sau khi đã chọn chỗ (thêm một bước).

## Hợp đồng: Handy Bookmark · đồng bộ Google Drive (2026-11-07)

- Việc: các máy Android của cùng một người có cùng thư viện, không phải nhớ bấm gì. Câu hỏi của
  màn: "Thư viện đang khớp chưa?". Hành động chính: bật một lần.
- Cài đặt › Đồng bộ: phần "Google Drive" (Android, bản build có HANDY_DRIVE_SYNC) đặt trên phần
  "Qua một thư mục" (máy tính). Ghi chú nói thẳng: thư mục ẩn trong Drive của chính người dùng, chỉ
  app thấy; tới các máy Android khác; đồng bộ khi app mở; không mã hoá đầu-cuối; không thay sao lưu.
- Tắt: một dòng "Bật đồng bộ Google Drive" (Google hỏi quyền chỉ cho thư mục của app). Bật: một dòng
  trạng thái (Đã đồng bộ lúc… · gửi/nhận N ảnh · chạm để đồng bộ ngay / Đang đồng bộ / Sẽ đồng bộ
  khi có mạng / Cho phép truy cập lại / Google Drive đã đầy / Chưa đồng bộ được; thư viện không đổi)
  và "Tắt đồng bộ" (không xoá gì; nói cách xoá bản trên Drive).
- Tự chạy: 30 giây sau thay đổi cuối của thư viện (đổi cài đặt không tính), khi app trở lại, khi app
  xuống nền còn thay đổi chờ, lúc mở app. Không chạy khi app đóng; không hứa điều đó.
- Bỏ: bắt bật ở lần đầu, gắn với Pro, đồng bộ cài đặt máy, công tắc hiện ra mà không kết nối được.

## Hợp đồng: Handy Boards · Kanban (2026-11-07, thay hợp đồng 2026-11-02)

Bản đề bài của chủ: `docs/HANDY_BOARDS_KANBAN_SPEC.md`. Phong cách: editorial-greeting (seed
1904133732, `--keep palette,type`), giữ hue `#A61C8E`, Plus Jakarta Sans, cấm indigo. Học theo
Handy Bookmark về độ chỉn chu (thứ bậc, ảnh bìa, màn chào diễn tập luồng thật, Cài đặt chia khu,
xem trước trước khi mua), không chép nền ngà/teal và không gọi là "bộ sưu tập".

- Dữ liệu và việc: một người, vài bảng (1–10), mỗi bảng 3–5 cột, 0–6 nhóm, 5–80 thẻ; thẻ có 0–8
  việc con, đôi khi có hạn và bìa. Mở app vài lần mỗi ngày trên điện thoại, đôi khi trên máy tính.
  Việc hay làm nhất: thêm thẻ, kéo thẻ sang cột bên, tick việc con.
- Mặt (face): nền là "mặt bảng ghim" đá ấm hơi hồng (`#F3EFEE`, tối `#1A1619`), tấm trắng tách bằng
  tông; mỗi bảng có ảnh bìa riêng ở đầu bảng và trên thẻ bảng ở Trang chủ.
- Yếu tố đặc trưng: **dải nhóm**. Mỗi nhóm là một khối (chấm màu + tên + "3/7" + vạch tiến độ mảnh
  theo màu nhóm), vừa là Tổng quan nhóm vừa là bộ lọc. Thẻ mang màu nhóm ở gờ trái và chip tên
  nhóm; màu không bao giờ đứng một mình (luôn có tên).

### Trang chủ · Bảng của tôi
- Câu hỏi: "Bảng nào cần mình hôm nay?". h1 "Bảng của bạn"; dòng xám dưới là phát hiện từ dữ liệu
  ("2 thẻ đến hạn hôm nay · Học kỳ 1"), không chào kiểu "Welcome back".
- Thẻ bảng: bìa (3:2 trên điện thoại, cắt an toàn), tên, "4 nhóm · 12 thẻ · 5 xong", sửa lần cuối;
  ghim lên đầu khi người dùng ghim. Lưới 1 cột (<600), 2 (600–1023), 3 (≥1024, cột giữa 1100px).
- Hành động chính: "Bảng mới" (nút đặc, góc phải trên; điện thoại: nút nổi không che thẻ cuối).
- Trống: hình bảng vẽ bằng chính bìa + "Tạo bảng đầu tiên" với hai nút Bảng trống / Xem mẫu.
- Đang tải: khung thẻ xám đúng kích thước. Lỗi đọc dữ liệu: trong khung, một câu + Thử lại.
- Thanh trên: dấu app + tên, tìm (thẻ trên mọi bảng), Cài đặt. Không thanh dưới, không tab Pro.

### Tạo bảng · Thư viện mẫu
- Hai lối: Bảng trống (Cần làm / Đang làm / Xong) và Mẫu. Mẫu chia nhóm (Tất cả, Học tập, Công
  việc, Cá nhân, Mua sắm, Sự kiện, Sáng tạo), ô mẫu có bìa, tên, một câu, nhãn Pro nếu Pro.
- Xem trước dùng đúng widget Kanban thật với dữ liệu mẫu (không phải ảnh chụp). Chạm "Dùng mẫu này"
  → ô tên (điền sẵn) → Tạo. Mẫu Pro xem trước đầy đủ; nút tạo thành "Mở khoá Pro" khi chưa có Pro.
- Dữ liệu mẫu là dữ liệu của người dùng sau khi tạo (sửa, xoá được), ID mới, không liên kết chéo.

### Bảng (Kanban)
- Câu hỏi: "Việc gì đang ở đâu?". h1 là tên bảng (24px), dòng xám "12 thẻ · 4 xong".
- Thanh công cụ: Nhóm (mở dải nhóm), Tìm/Lọc (nhóm, cột, sắp đến hạn), Thêm (đổi bìa bảng, cách
  hiện thẻ gọn/chi tiết, cột, nhân bản, lưu trữ, xoá, xuất).
- Cột: điện thoại một cột gần đủ rộng (rộng màn − 48px, nhìn thấy mép cột bên) cuộn ngang có hút
  cột; ≥600px nhiều cột 300px. Đầu cột: tên, số thẻ, menu (đổi tên, thu gọn, chuyển vị trí, xoá
  với lựa chọn chuyển thẻ). "Thêm thẻ" ở cuối cột: gõ tên, Enter là lưu, ô vẫn mở để thêm tiếp.
- Thẻ: bìa mảnh (nếu có), tiêu đề tối đa 3 dòng, chip nhóm, "2/5" việc con, hạn chỉ khi có (đỏ chỉ
  khi quá hạn). Chi tiết: hiện thêm tối đa 3 việc con tick được ngay.
- Kéo thả: giữ để nhấc (rung nhẹ), kéo trong cột và sang cột; cột đích sáng nền; thả xong có
  SnackBar "Đã chuyển sang Xong · Hoàn tác". Lối không kéo: menu thẻ "Chuyển tới…" (cột + vị trí),
  bàn phím: Alt+←/→ chuyển cột, Alt+↑/↓ đổi chỗ.
- Nhóm độc lập với cột: chuyển cột không đổi nhóm. Không tự chuyển sang Xong khi đủ việc con trừ
  khi bật tự động hoá Pro tương ứng.
- Dải nhóm: điện thoại 2×2 khi ≤4 nhóm (cuộn ngang khi nhiều hơn), chạm lọc bảng theo nhóm, chạm
  lại hoặc "Tất cả" để bỏ lọc; "Sửa nhóm" mở trang nhẹ: thêm, đổi tên, đổi màu/biểu tượng, sắp
  xếp, xoá (thẻ chuyển sang "Chưa phân nhóm" hoặc nhóm khác do người dùng chọn; không bao giờ xoá
  thẻ). Bảng không có nhóm: dải hiện một ô "Thêm nhóm" nhỏ, không chiếm chỗ.
- Trống: cột trống giữ khung + "Thêm thẻ"; bảng lọc không ra thẻ: một câu + "Bỏ lọc".

### Thẻ (chi tiết) · Thêm nhanh · Chọn bìa
- Trang đáy kéo lên (điện thoại) / hộp thoại 640px (≥900px). Thứ tự: bìa, tiêu đề (sửa tại chỗ),
  hàng chip Cột · Nhóm · Hạn · Nhắc, việc con (thêm, sửa, kéo xếp, tick, xoá; "2/5" và vạch), ghi
  chú (link bấm được), ảnh đính kèm nếu có, menu Thêm (nhân bản, lưu trữ, xoá, chuyển bảng).
- Lưu ngay từng thay đổi (Hoàn tác có ở SnackBar); đóng bằng Back/vuốt không mất gì.
- Chọn bìa: Gợi ý (theo nhóm/mẫu), Tất cả, từng họ bìa, Ảnh của bạn, Màu. Chạm là xem trước ngay
  trên thẻ ở đầu trang; Áp dụng / Huỷ (huỷ trả lại bìa cũ). Bìa Pro: xem trước được, Áp dụng thành
  "Mở khoá Pro".

### Màn chào (lần đầu, xem lại từ Trợ giúp)
- Ba bước diễn tập trên bảng tạm (không ghi dữ liệu): 1) chào + chọn Bảng trống / Học tập / Bỏ qua;
  2) thêm một thẻ rồi kéo nó sang "Đang làm" (có nút "Chuyển" cho ai không kéo được); 3) chạm nhóm
  Toán để lọc, tick một việc con, thấy nhóm vẫn giữ khi thẻ sang Xong → Xong. Không xin quyền, không
  tài khoản, không dùng thử.

### Cài đặt (theo khung Cài đặt của Bookmark)
- Các khu: Giao diện (sáng/tối/hệ thống, ngôn ngữ, cách hiện thẻ mặc định), Thông báo (nhắc hạn,
  xin quyền chỉ khi bật), Dữ liệu (sao lưu/khôi phục, tự sao lưu, xuất, thùng rác, đã lưu trữ),
  Pro, Trợ giúp (xem lại màn chào, cách dùng), Giới thiệu (phiên bản, quyền riêng tư), Các app Handy
  khác. Mỗi khu một trang trên điện thoại; ≥1024 hai cột nhãn/tấm.

### Pro (mua một lần)
- Free đủ dùng: không giới hạn bảng/thẻ/nhóm/việc con, kéo thả, hạn, tìm, sao lưu, xuất cơ bản,
  ≥30 bìa. Không quảng cáo.
- Pro: mẫu cao cấp, họ bìa cao cấp, giao diện bảng, tự động hoá có sẵn (đủ việc con → Xong; sắp
  hạn → nổi bật; lưu trữ thẻ Xong sau N ngày, khôi phục được), kiểu xuất đẹp, Thống kê nhẹ.
- Xem trước trên dữ liệu thật, không lưu; trang mua chỉ mở khi bấm Mở khoá/Áp dụng/Xuất. Giá và
  trạng thái mua/khôi phục thật từ cửa hàng; chưa có mã sản phẩm thì nút mua ghi "Chưa mở bán trên
  bản này" thay vì giá giả.

### Nền tảng
- Android/iOS: Back đóng trang/trang đáy trước, rồi về Trang chủ; giữ-để-kéo; rung nhẹ khi nhấc
  và thả. Windows: chuột kéo ngay (không cần giữ), Ctrl+N thẻ mới ở cột đầu, Ctrl+F tìm, Ctrl+Z/Y,
  phím Alt như trên. Web: URL `/`, `/board/<id>`, `/templates`, `/settings`; Back của trình duyệt
  như Back.
- 320–1440: 320px chữ ×2 vẫn một cột thẻ đọc được; dải nhóm chuyển một cột; không cuộn ngang trang
  (chỉ vùng cột cuộn ngang).
- Truy cập: mọi nút biểu tượng có nhãn; thẻ đọc thành "Tiêu đề, nhóm Toán, cột Đang làm, 2 trên 5
  việc con, hạn thứ Sáu"; mục tiêu chạm ≥48px; giảm chuyển động thì bỏ hiệu ứng nhấc/trượt.
- Bỏ: thanh dưới nhiều mô-đun, tab Pro, bảng dữ liệu/lịch/timeline/học tập/tập trung riêng, trình
  dựng quy tắc, ba cột tí hon trên điện thoại, cầu vồng màu thẻ, gradient, kính mờ, emoji, khoá
  Pro chỉ bằng ảnh chụp, tự xoá hay tự chuyển thẻ không báo.

### Handy Boards · Pro: thẻ lặp lại, giao diện bảng, bản xuất đẹp (2026-11-07)
- Thẻ lặp lại: chip "Lặp lại" trong chi tiết thẻ (Không / Hằng ngày / Hằng tuần / Hằng tháng,
  nhãn Pro). Khi thẻ vào cột "đã xong", app tạo thẻ kế tiếp ở đầu cột đầu tiên: cùng tên, nhóm,
  ghi chú, bìa, việc con (bỏ tick), hạn dời đúng một chu kỳ; SnackBar "Đã tạo lần tiếp theo ·
  Hoàn tác". Thẻ cũ chỉ sinh lần sau một lần (kéo qua lại không nhân bản). Mất Pro thì thẻ đã
  đặt vẫn lặp; đặt mới cần Pro.
- Giao diện bảng: menu bảng › "Giao diện bảng" mở dải lựa chọn ở đáy, bảng phía trên đổi ngay
  khi chạm (xem trước trên chính dữ liệu của mình); Áp dụng / Huỷ. "Mặc định" miễn phí; các gói
  khác (Vải lanh, Bản vẽ, Đồng cỏ, Phấn hồng, Đêm) là Pro: Áp dụng thành "Dùng với Pro". Mỗi gói
  có biến thể sáng và tối, chữ vẫn đạt tương phản 4.5:1; chỉ đổi nền trang và nền cột, thẻ luôn
  trắng/tối như cũ để đọc. Mất Pro: giao diện đã chọn vẫn giữ.
- Bản xuất: menu bảng › "Xuất bảng" mở trang xem trước: ảnh bảng đúng như sẽ lưu, chọn kiểu
  (Đơn giản: miễn phí; Poster, Bản in: Pro), nút "Lưu ảnh PNG" và "Lưu PDF"; kiểu Pro xem
  trước được, lưu cần Pro. Liên kết "Định dạng khác (CSV, Markdown, lịch ICS, sao lưu)" mở hộp
  xuất dữ liệu cũ (miễn phí). Ảnh không có dữ liệu ngoài bảng, không có ảnh riêng tư ngoài bìa
  thẻ đang hiện.
- Bỏ: trình dựng quy tắc lặp phức tạp (ngày trong tuần, ngoại lệ), theme đổi màu chữ hay màu
  thẻ, ảnh xuất có watermark quảng cáo.

### Handy Boards · màn chào làm lại + "mỗi bảng một màu" (2026-11-08, thay mục Màn chào ở trên)
- Màn chào theo đúng khung của Handy Bookmark và Sticky Wall (chủ yêu cầu): thanh trên có Quay
  lại, thanh tiến độ ba khúc, Bỏ qua; tiêu đề lớn có vệt highlight vẽ dưới chữ khoá; chữ, hình,
  nút hiện lần lượt theo nhịp của chặng; Back/Esc lùi một bước, Enter bấm nút chính; giảm chuyển
  động thì mọi thứ đứng yên ở trạng thái cuối. Rộng ≥ 700: chữ và nút bên trái, hình bên phải
  (phần tập thử trong khung điện thoại); điện thoại: chữ trên, hình lớn, nút ở chân.
  1. Câu chuyện, hai nhịp: "Việc nằm khắp nơi. Rồi rơi mất." (mẩu việc trong app ghi chú, tin
     nhắn, giấy dán, nhắc lịch; ngả xám) → "Một bảng cho tất cả." (các mẩu bay vào ba cột, thành
     thẻ có nhóm màu). Nút "Gom về một bảng", rồi "Chỉ tôi cách dùng".
  2. Tập thử trên bảng giả (không lưu gì): mọi thứ tối đi trừ đúng chỗ cần làm, khung sáng có
     viền thở và nhãn chỉ dẫn: (a) "Giữ thẻ rồi kéo sang Đang làm" (có nút chữ "Chuyển giúp tôi"
     cho ai không kéo được); (b) "Chạm Toán để chỉ xem việc Toán"; (c) "Tick một việc con" (thẻ
     mở hai việc con, 2/5 thành 3/5; thêm 2026-11-08 vì việc con là tính năng chính); (d) "Kéo
     sang Xong". Xong thì
     dấu tick nảy lên: "Vẫn thuộc Toán, dù đã xong."
  3. Bắt đầu: ba lựa chọn lớn (Bảng học tập, Bảng trống, Xem các mẫu), nút "Bắt đầu". Mở lại
     từ Cài đặt thì không có lựa chọn và không đổi gì.
- Mỗi bảng một màu (chủ chọn): nền trang của bảng lấy từ tông của ảnh bìa (sáng: pha nhạt;
  tối: pha đậm), cột là tấm trắng trong (sáng) / tối trong (tối) đặt trên nền đó, thẻ vẫn trắng
  để đọc. Đầu bảng là dải ảnh bìa (điện thoại 96px, rộng 140px) với tên bảng chữ lớn ngay dưới.
  Trang chủ là các tấm poster bảng: bìa chiếm phần trên, chân tấm mang tông màu của bảng đó.
  Gói giao diện Pro (Vải lanh…) thay tông bìa khi được chọn; "Mặc định" nay là "Theo ảnh bìa".
  Chữ trên nền màu luôn đạt 4.5:1 (tông được ép về độ sáng an toàn).
