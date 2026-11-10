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
     viền thở và nhãn chỉ dẫn: (0) "Chạm Thêm thẻ" ở cột Cần làm, thẻ "Ôn chương 3" hiện ra (thêm
     2026-11-08 theo chủ); (a) "Giữ thẻ rồi kéo sang Đang làm" (có nút chữ "Chuyển giúp tôi"
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

### Handy Boards · chế độ "Tuần" (2026-11-08, theo feedback tester + chủ chọn)
- Vì sao: tester hỏi "To Do là hôm nay hay tuần này?" và "thiếu timeline". Cột chỉ nói trạng
  thái; chế độ Tuần trả lời "việc nào vào ngày nào" mà không thành Gantt (đề bài vẫn loại Gantt).
- Mỗi bảng có nút chuyển "Bảng | Tuần" ngay cạnh tên bảng; nhớ lựa chọn theo từng bảng.
- Tuần: đầu là "‹ 10–16 Th11 ›" và "Hôm nay"; bảy ngày Thứ Hai–Chủ nhật. Rộng ≥ 600: bảy cột ngày
  cạnh nhau (cuộn ngang trong vùng của nó); điện thoại: các ngày xếp dọc, mỗi ngày một mục có tiêu
  đề ngày, hôm nay nổi bằng nền nhạt màu nhấn và chữ "Hôm nay". Thẻ nằm đúng ngày hạn (cùng thẻ
  như ở Bảng: nhóm, việc con, bìa; thẻ đã xong gạch ngang). "Quá hạn" đứng đầu khi xem tuần này;
  "Chưa có hạn" là khay cuối (điện thoại) / cột đầu (rộng).
- Kéo một thẻ sang ngày khác (hoặc từ khay vào một ngày) là đặt hạn ngày đó; SnackBar "Hạn: Thứ
  Năm 13/11 · Hoàn tác". Lối không kéo: chip Hạn trong chi tiết thẻ. Kéo vào khay = bỏ hạn.
- Lọc nhóm, tìm vẫn áp dụng như ở Bảng (thẻ không khớp ẩn hẳn). Ngày trống giữ khung và một dòng
  "Trống". Bàn phím: ←/→ đổi tuần khi đang ở Tuần.
- Bỏ: thanh kéo dài nhiều ngày, đường găng, giờ trong ngày, lịch tháng.
- Sửa cùng ngày (chủ): không cố định một tuần mà là chế độ "Thời gian" với khoảng tuỳ chọn: Hôm
  nay, 3 ngày, Tuần, 2 tuần, Tháng, 3 tháng, Tuỳ chỉnh (1–12 ngày/tuần/tháng). Khoảng ≤ 14 ngày:
  mỗi ngày một cột/mục; dài hơn: gom theo tuần ("Tuần 10–16/11"), kéo thẻ vào một tuần là đặt hạn
  ngày đầu tuần đó (Thứ Hai) trừ khi thẻ đã có hạn trong tuần ấy. ‹ › nhảy đúng một khoảng; nút
  chuyển ghi "Bảng | Thời gian"; mỗi bảng nhớ chế độ và khoảng (trường `view`, `span`).

### Handy Boards · Cài đặt và "Cách dùng" như Bookmark/Sticky Wall (2026-11-08, chủ yêu cầu)
- Việc của màn: đổi cách app chạy trên máy này và tìm lại cách làm một việc; không màn nào ở đây
  sửa thẻ. Một câu hỏi: "chỉnh gì, hay học gì?". Hành động chính: mở Pro (thẻ đầu trang).
- Thứ tự nhóm (giống Bookmark, Sticky Wall): thẻ Pro (nền `tint`, "Nâng cấp Pro" / "Bạn đã có
  Pro") → Chung (ngôn ngữ, sáng/tối, nhắc việc) → Tự động hoá (Pro, có khoá trên công tắc) → Dữ liệu
  (Sao lưu | Khôi phục là hai nút; Tự sao lưu mỗi ngày khi có thay đổi, giữ 7 bản trong bộ nhớ của
  app, có Khôi phục/Chia sẻ bản gần nhất; Bảng đã lưu trữ; Thẻ đã lưu trữ (mới, trước đây ghi chú
  hứa "khôi phục ở mục Dữ liệu" mà không có chỗ); Thùng rác; Xoá toàn bộ dữ liệu, đỏ, hỏi lại) →
  Trợ giúp (Cách dùng) → Giới thiệu (Gửi góp ý, Chính sách quyền riêng tư, Điều khoản sử dụng,
  Giấy phép, Các app Handy khác).
- Cách dùng (`/how-to`): thẻ lớn "Xem lại phần giới thiệu" (mở lại màn chào, không lưu gì) rồi
  danh sách chủ đề; mỗi chủ đề mở thành sheet các bước đánh số, Trước/Tiếp/Xong ghim ở chân. Hình
  của bước là mảnh màn hình vẽ bằng code theo màu của app (cột Kanban, dải nhóm, thanh thời gian,
  hàng cài đặt), chỗ cần bấm được khoanh viền màu nhấn; không ảnh chụp. Chủ đề: bắt đầu một bảng,
  thêm và chuyển thẻ, nhóm, việc con và chi tiết thẻ, xem theo thời gian, bìa và giao diện, lặp lại
  và tự động hoá, tìm, xuất và chia sẻ, giữ an toàn, phím tắt (chỉ máy tính), Pro.
- Trạng thái: chưa có bản tự sao lưu → "Chưa có bản nào", không hiện Khôi phục/Chia sẻ; lỗi ghi →
  "Lần gần nhất chưa ghi được"; không có lưu trữ/thùng rác → hàng ghi "Không có"/"Trống" và không
  điều hướng. Web: không có Tự sao lưu (không có thư mục riêng). Chính sách/điều khoản mở trang
  GitHub; không mở được → báo một dòng.
- Đáp ứng: 320–1440, nội dung tối đa 720 px giữa màn; sheet chủ đề tối đa 640 px; chữ ×2 không
  tràn. Quay lại: nút Back/Esc đóng sheet rồi trang. Web URL `/settings`, `/how-to`.
- Từ chối: trang trợ giúp dạng FAQ dài, video, ảnh chụp màn hình thật, biểu tượng trong ô màu.

## (Đã thay) Hợp đồng: Handy Boards · bốn loại bảng (2026-11-08) — bị thay bởi "một Kanban, 30 mẫu" bên dưới
Nguồn: prompt review của chủ (bốn loại bảng, mỗi loại một module riêng) và `review-shots/handy-boards-review.html`
(baseline 1506528). Vẫn một app Kanban; không thêm view chung, không trường tuỳ biến.

### Kiểm kê (dữ liệu và việc)
- Bảng → Cột (trạng thái) → Nhóm (chủ đề) → Thẻ → Việc con một tầng. Thêm `board.type` = standard | study |
  shopping | content (thiếu = standard, không tự đổi bảng cũ).
- Học tập: môn = nhóm của bảng + bản ghi `subjects` (mã môn, tín chỉ); giờ học `classes` (thứ, giờ bắt đầu/kết
  thúc, phòng) lặp hằng tuần trong học kỳ (`board.term`); bài thi = thẻ có `exam` (ngày, giờ, phòng) khác hẳn hạn
  của thẻ. 4 môn, ~6 giờ học/tuần, 2–6 bài thi/kỳ, 20–40 thẻ.
- Mua sắm (Pro): thẻ có `product` (đơn giá số nguyên theo đơn vị nhỏ nhất, tiền tệ, số lượng, cửa hàng, link,
  quy cách để so giá/đơn vị); bảng có ngân sách; cột có giai đoạn want / ordered / received / cancelled. Đã chi =
  thẻ ở cột ordered + received; huỷ không tính; thiếu giá không cộng và ghi "chưa có giá". 5–30 món, 50.000–
  20.000.000 đ.
- Nội dung (Pro): thẻ có `post` (định dạng, nền tảng, giờ đăng dự kiến, lịch sử đã đăng: nền tảng, lúc, link
  do người dùng nhập); cột có giai đoạn idea / making / ready / published. 4–20 bài/tháng.
- Người dùng: sinh viên mở hằng ngày trên điện thoại (lịch học hôm nay, hạn, bài thi); người mua sắm mở khi cân
  nhắc (còn bao nhiêu tiền); người làm nội dung mở mỗi ngày (hôm nay đăng gì).

### Câu hỏi của từng màn
- Trang chủ: "Bảng nào cần tôi hôm nay?" Mỗi ô bảng có huy hiệu loại và một dòng đúng loại: Kanban "12 thẻ ·
  4 xong"; Học tập "Tiết sau: Mạng máy tính 13:30 · Thi CSDL còn 5 ngày"; Mua sắm "Còn 1.250.000 đ trong ngân
  sách"; Nội dung "Đăng tiếp: T5 19:00 · TikTok".
- Bảng (mọi loại): "Việc nào đang ở đâu?" Cột lớn nhất. Chuyển chế độ ngay dưới tên: Bảng | Thời gian, thêm
  "Lịch học" (Học tập) hoặc "Lịch đăng" (Nội dung). Một dòng giải thích cột ≠ ngày, tắt được.
- Lịch học: "Hôm nay học gì, sắp thi gì?" Lớn nhất là thẻ "Tiết tiếp theo"; dưới là tuần T2–CN theo giờ; rồi
  danh sách bài thi sắp tới. Thêm giờ học / thêm bài thi là hai nút ở đầu.
- Mua sắm: dải ngân sách trên các cột: Dự kiến · Đã chi · Còn lại (số lớn là "Còn lại"). Bấm mở sheet ngân sách
  và "So sánh" (chọn 2–4 món, bảng giá, giá/đơn vị). Không lấy giá từ mạng.
- Lịch đăng: "Hôm nay/tuần này đăng gì?" Danh sách sắp đăng theo ngày, rồi "Đã đăng gần đây" (link do người dùng
  ghi). Kéo thẻ vào cột "Đã đăng" → sheet ghi ngày giờ thật + link (bỏ qua được, không bịa link).
- Chi tiết thẻ: một khung chung; phần riêng đúng loại ở trên việc con (thi / sản phẩm / bài đăng), chỉ trường cần
  thiết, phần nâng cao gập lại.
- Nhóm: chạm = làm nổi (viền màu trên thẻ khớp, thẻ khác vẫn hiện); nút riêng "Chỉ hiện nhóm này" để ẩn; "Bỏ
  chọn" luôn thấy khi đang chọn.
- Tạo bảng: bốn loại, mỗi loại một dòng lợi ích + "Chỉ loại này có …" + xem trước thật; trong loại mới chọn mẫu
  (Kanban: Trống, Cá nhân, Dự án); "Có dữ liệu mẫu" hoặc "Bảng trống". Pro chỉ hỏi khi bấm Tạo.
- Màn chào: câu đầu tiên là "Bạn dùng Boards để làm gì?" (Học tập / Việc & dự án / Mua sắm / Làm nội dung),
  rồi câu chuyện + bảng tập riêng cho lựa chọn đó (tập làm đúng việc riêng của loại: thêm giờ học, nhập giá, ghi
  link đã đăng), kết thúc bằng tạo đúng loại bảng đó (Pro: xem thử đầy đủ, tạo thì hỏi Pro hoặc chọn Kanban).

### Trạng thái, đáp ứng, từ chối
- Rỗng: Lịch học chưa có giờ → "Thêm giờ học đầu tiên"; mua sắm chưa ngân sách → "Đặt ngân sách"; chưa có bài
  hẹn đăng → "Chưa hẹn bài nào". Lỗi lưu → SnackBar, dữ liệu giữ nguyên. Pro mất tạm thời: bảng đã có vẫn dùng
  đầy đủ.
- 320–1440 px, chữ ×2, tối/sáng, đọc màn hình, giảm chuyển động. Web URL giữ nguyên `/board/<id>`; chế độ là
  trường của bảng.
- Từ chối: trình tạo trường tuỳ biến, công thức, Gantt/lịch tháng lớn, tự đăng mạng xã hội, lấy giá tự động,
  thêm loại bảng mới, thư viện mẫu toàn bảng giống nhau.

## Hợp đồng: Handy Boards · một Kanban, 30 mẫu + Bảng trống, màn chào hai nhánh (2026-11-08, thay hợp đồng bốn loại bảng)
Nguồn: prompt cuối của chủ (FINAL MASTER IMPLEMENTATION PROMPT). Mọi bảng chạy chung một engine; mẫu chỉ là bản thiết kế ban
đầu (tên, cột có cột hoàn tất rõ ràng, nhóm, ngày quan trọng, cách mở Thời gian, giao diện, bìa, thẻ ví dụ khi người dùng bật).
Chủ chốt 14 mẫu Free (29 Chuyển nhà chuyển sang Free) và 16 Pro.

### Việc và câu hỏi của từng màn
- Thư viện mẫu (`/templates`): "Mẫu nào hợp việc của tôi?" Đầu trang: ô tìm; chip nhóm Tất cả · Học tập · Công việc · Cá nhân ·
  Sáng tạo · Kế hoạch; chip Free/Pro. Không lọc/tìm: mục "Nổi bật" 6 mẫu Free trước, rồi theo nhóm. Ô mẫu: bìa, tên, một dòng
  mục đích, dòng cột "A → B → C", huy hiệu Free/Pro. Lưới dựng lười (builder). Bảng trống luôn là ô đầu.
- Xem trước mẫu: "Bảng này trông thế nào?" Lớn nhất là Kanban thật dựng từ câu trả lời mặc định + thẻ ví dụ (bảng tạm, không lưu,
  ghi rõ "Xem trước · không lưu"). Trên: bìa, mục đích, cột, nhóm, Thời gian mặc định. Nút chính "Dùng mẫu này" (Pro cũng xem
  được).
- Smart Setup: "Bảng của tôi khác mẫu ở đâu?" 2–5 câu, mỗi câu có nhãn, một dòng giải thích nó đổi gì trên bảng, mặc định hợp lý;
  chip nhập từng dòng (thêm, sửa, kéo sắp, xoá), ngày qua lịch, chọn bằng nút phân đoạn, bật/tắt. Công tắc "Thêm vài thẻ ví dụ"
  (tắt sẵn). Lỗi hiện ngay dưới câu. Nút "Xem trước" → bảng sinh từ câu trả lời; "Tạo bảng" (Pro hỏi ở đây nếu mẫu Pro), "Sửa"
  quay lại giữ nguyên câu trả lời. Tạo một lần dù bấm nhiều lần.
- Bảng trống: tên + (tuỳ chọn) đổi tên ba cột; tạo ngay.
- Bảng: ngày quan trọng (nếu có) là chip "Kết thúc học kỳ · 15/01 · còn 68 ngày" dưới tên; sửa ở menu "Ngày quan trọng". Công tắc
  Bảng | Thời gian nằm cạnh tên khi được ghim, nếu không thì ở nút trên thanh đầu; ghim/bỏ ghim trong menu bảng.
- Nhóm: chạm = làm nổi (thẻ khớp có viền màu + dấu ✓ cạnh tên nhóm, thẻ khác vẫn hiện, nhạt đi); thanh "Đang làm nổi: Toán ·
  Chỉ hiện nhóm này · Bỏ chọn"; "Chỉ hiện nhóm này" mới ẩn thẻ khác, có nhãn "Đang lọc" và nút bỏ lọc. Nhóm trống vẫn hiện.
- Màn chào: "Bạn chủ yếu muốn sắp xếp gì?" Học tập / Công việc, kèm "Xem tất cả mẫu" và Bỏ qua. Bài tập trên bảng tạm, chung cơ
  chế, khác ví dụ (Học tập: môn học; Công việc: mảng việc): 1) nhóm vs cột vs thẻ + thêm thẻ, 2) kéo sang cột khác, 3) chạm nhóm
  để làm nổi (không ẩn), 4) tích việc con (thẻ không đổi cột), kéo vào cột hoàn tất. Cuối: 3 mẫu gợi ý (Học tập: Kế hoạch học kỳ,
  Bài tập nhóm, Ôn thi; Công việc: Dự án Kanban, Kế hoạch tuần, Ý tưởng) + Tất cả mẫu + Bảng trống → vào Smart Setup của mẫu đó.
  Bỏ qua → Trang chủ trống. Người dùng cũ không bị hiện lại; xem lại ở Cài đặt › Trợ giúp.

### Trạng thái, đáp ứng, từ chối
- Rỗng: tìm không ra → "Không có mẫu nào khớp" + bỏ lọc; bảng không ngày quan trọng → không hiện chip. Lỗi tạo → SnackBar, không
  có bảng nửa vời.
- 320–1440 px, chữ ×2, tối/sáng, đọc màn hình (nhãn cho ô mẫu, chip, nút), giảm chuyển động, bàn phím.
- Từ chối: module riêng theo loại bảng, lịch học/giá/hẹn đăng riêng, 30 màn viết tay, trình tạo form chung, thẻ ví dụ tự thêm.

### Handy Boards · màn thấp và màn ngang (2026-11-08, theo lỗi chủ gặp trên BlueStacks)
- Lỗi: trên màn ngang mật độ cao (BlueStacks 960×540 pt) phần đầu trang bảng (ảnh bìa, tên, Bảng | Thời gian, dải nhóm)
  chiếm gần hết chiều cao; cột chỉ còn ~200 pt, tràn 18 px và không cuộn được.
- Quy tắc: màn cao dưới 720 pt hoặc chữ lớn hơn ×1,3 → trang bảng cuộn: ảnh bìa thu thành thanh nút ghim (quay lại, tìm,
  nhóm, tuỳ chọn), tên và dải nhóm cuộn đi, bảng luôn cao bằng màn trừ thanh nút. Vuốt trong cột đến đầu/cuối thì phần dư
  cuộn cả trang, nên phần đầu quay lại bằng cùng một cú vuốt. Màn cao giữ phần đầu cố định; bảng không bao giờ thấp hơn
  260 pt (bàn phím, thanh chọn giao diện) mà cuộn thay vì tràn. Quyết định theo kích thước màn, không theo chỗ còn lại,
  nên bàn phím không đổi bố cục.
- Cột thấp hơn 200 pt (ô xem trước mẫu) cuộn cả cột, kể cả tiêu đề và ô thêm thẻ. Sheet "Bảng mới" cuộn; chip Free/Pro
  xuống dòng; thanh "Đang làm nổi" đưa nút xuống dưới tên khi chật; tiêu đề "Việc con" co lại.
- Kiểm tra: `test/layout_sweep_test.dart` mở mọi màn (màn chào, trang chủ, sheet tạo bảng, mẫu, thiết lập, xem trước,
  bảng, tìm, menu, thẻ, ô thêm thẻ, Thời gian, Cài đặt, Cách dùng, Pro, Tìm, Thùng rác, Thống kê, Xuất) ở 11 kích thước
  (320×568 → 1440×900, ngang 640×360, BlueStacks 1000×562 và 1280×720, chữ ×2); lỗi tràn, ngoại lệ, bảng thấp hơn 300 pt
  hoặc vuốt cột không đưa phần đầu về đều làm test hỏng. Đã chạy trên BlueStacks android 11-2 (đặt tạm mật độ 320).

### Handy Boards · mẫu Pro hỏi Pro trước câu hỏi; trang xem trước cuộn được (2026-11-08, chủ yêu cầu)
- Việc: "Mẫu này có phải bảng tôi cần, và tôi dùng được không?" Câu hỏi đó phải được trả lời trước khi người dùng bỏ công
  điền thiết lập. Trước đây mẫu Pro cho điền hết rồi mới chặn ở "Tạo với Pro"; giờ nút trên trang xem trước của mẫu Pro
  là "Mở khoá với Pro" (biểu tượng ổ khoá mở), kèm dòng "Mẫu Pro · xem miễn phí, cần Pro để dùng. Mở khoá trước, rồi mới
  trả lời câu hỏi." Bấm vào thì mở trang Pro; mua xong đi thẳng vào câu hỏi; quay lại thì không có gì được tạo. Đã có Pro
  thì nút là "Dùng mẫu này". Xem trước luôn miễn phí. Bước Tạo vẫn kiểm tra Pro lần nữa làm lưới an toàn.
- Trang xem trước mẫu và trang "bảng của bạn" dùng `PreviewBody`: màn cao giữ đầu trang cố định; màn thấp (< 720 pt) hoặc chữ
  > ×1,3 cuộn phần đầu đi, bảng xem trước cao ít nhất 580 pt, vuốt trong cột đến đầu/cuối thì cuộn cả trang.
- Từ chối: chặn Pro ở bước cuối sau khi đã điền; ẩn mẫu Pro khỏi danh sách; khoá cả việc xem trước.
- Kiểm tra: `kanban_app_test` (mẫu Pro: trang Pro xuất hiện trước câu hỏi, không tạo gì; có Pro: đi thẳng vào câu hỏi rồi
  tạo), `layout_sweep_test` đo bảng ở hai trang xem trước và việc cuộn ở 11 kích thước. Đã xem trên BlueStacks 11-2 (mật độ 320).

### Handy Boards · Time Navigator, ngày làm, chuyển nhanh, lịch sử thẻ (2026-11-08, bổ sung của chủ)
- Một chế độ Thời gian chung cho mọi bảng (mẫu nào cũng vậy), xem chính các thẻ của bảng. Ba ngày độc lập: `due` (hạn
  nộp), `scheduled` (ngày làm, 'YYYY-MM-DD', chỉ là kế hoạch) và `completedAt` (lúc thật sự vào cột xong). Thẻ nằm ở ngày
  làm, không có thì ở hạn nộp; nếu hạn nộp rơi vào ngày khác trong khoảng đang xem thì có dòng "Hạn nộp: …" trỏ về đúng
  thẻ đó, không nhân đôi thẻ, không đếm hai lần.
- Khoảng: 1/2/3 ngày, 1/2 tuần, 1/2/3 tháng (tháng lịch thật), Tuỳ chỉnh (độ dài 1–12 ngày/tuần/tháng như cũ, hoặc từ
  ngày – đến ngày, tối đa 366 ngày, có dòng tóm tắt sống và báo lỗi). Tuần bắt đầu thứ Hai ở cả hai ngôn ngữ (ISO, khớp
  "đầu tuần" của mẫu). Trước/Sau đi đúng một khoảng, không chồng, không hở; nhãn là ngày thật ("2/11 – 8/11").
- Mốc: tối đa hai kỳ trước gần nhất còn việc ("… · 2 còn tồn, 1 quá hạn", đỏ chỉ khi quá hạn thật), các kỳ cũ hơn gộp
  thành "N kỳ trước còn việc", "Xem tất cả tồn đọng (N)" mở danh sách, và kỳ sắp tới có việc ("Sắp tới: …", trung tính).
  Mỗi thẻ đếm một lần mỗi kỳ; mốc trỏ về kỳ gốc của ngày làm/hạn nộp, không lặp sang mọi tuần sau.
- Chuyển nhanh ngay trên thẻ (không chôn trong menu): quá khứ → "Về hôm nay", tương lai → "Làm sớm", chưa có ngày →
  "Lên lịch", xong → "Lịch sử". Chọn nhiều (nút danh sách) và "Tất cả về hôm nay" ở ô Còn tồn. Chỉ đổi ngày làm; thẻ chỉ
  có hạn nộp thì hỏi: "Lên lịch làm hôm nay · giữ hạn DD/MM" (mặc định) / "Đổi hạn nộp" / Huỷ. Thanh báo "Đã lên lịch N thẻ
  cho hôm nay · Hoàn tác"; Hoàn tác trả ngày làm cũ và ghi một sự kiện hoàn tác. Kéo thả vào ngày vẫn đổi hạn nộp như trước.
- Lịch sử thẻ (chỉ đọc, trong chi tiết thẻ): tạo, chuyển cột, hoàn thành/mở lại, đổi hạn, đổi ngày làm (lý do), đổi nhóm,
  việc con tick/bỏ tick (không chép chữ), lưu trữ, thùng rác. Thẻ có trước phiên bản này nói rõ "Lịch sử chỉ ghi từ phiên
  bản này", không bịa quá khứ. Không phải ảnh chụp bảng theo thời gian.
- Mặc định theo mẫu là gợi ý (bảng 30 mẫu + Bảng trống trong yêu cầu); "ghim nếu có ngày" ghim khi người dùng nhập ngày.
  Lựa chọn trong Thiết lập nhanh và sau khi tạo luôn thắng; bảng cũ giữ nguyên cài đặt.
- Miễn phí toàn bộ. Màn chào chỉ thêm một câu gợi ý, không thêm bước.
- Kiểm tra: `packages/handy_boards_engine/test/time_nav_test.dart` (17: ngày tháng, nhuận, qua năm, DST, tuỳ chỉnh, mốc
  không đếm trùng, kịch bản A/B/C/F/G, thẻ lặp, mặc định mẫu), `apps/handy_boards/test/time_nav_app_test.dart` (8: A, B, C,
  D, tồn đọng, lịch sử, thẻ cũ, kéo thả đổi hạn), `layout_sweep_test` (11 kích thước).

### Handy Boards · Pro Lifetime: công cụ, thông báo, widget, luật tự động, báo cáo (2026-11-08, theo yêu cầu Pro của chủ)
Chung cho mọi màn dưới đây. Xem luôn miễn phí; chỉ hỏi Pro ở hành động tạo, bật hoặc lưu (`requirePro`). Mất Pro thì dữ liệu
vẫn đọc được và vẫn nằm trong sao lưu; kiểu Pro tự lùi về mặc định mà vẫn giữ lựa chọn. Bố cục là một cột ListView đã đo ở
320–1440 px trong `layout_sweep_test`. Màn rộng không bày thêm cột, vì đây là các trang cài đặt hoặc danh sách để đọc. Nút
Back của Android và cử chỉ vuốt về của iOS đều đóng trang. Web và Windows không có thông báo nền hay widget, và trang nói
rõ điều đó. Không có trạng thái "đang tải" riêng vì mọi thứ tính từ dữ liệu trên máy. Lỗi hiện thanh báo "Thao tác lỗi; dữ
liệu trước được giữ" qua `scope.run`. Nhãn của ô chọn luôn hiện (`floatingLabelBehavior.always`), vì kit ẩn nhãn nổi và trên
BlueStacks từng chỉ thấy "Any, Any, Any".

- **Luật tự động** (Bảng ⋮ › Luật tự động).
  - Câu hỏi của màn: "Bảng này tự làm giúp tôi những gì, và nó đã làm gì?"
  - Mỗi luật viết thành một câu, ví dụ "Khi thẻ chuyển vào Review: thêm việc con …", kèm công tắc bật/tắt. Bên dưới là
    "Lần chạy gần đây" trên máy này; bước bị bỏ qua ghi lý do (đã có sẵn, luật khác đã đặt, mẫu đã xoá).
  - Chưa có luật: hiện ba ví dụ bấm vào là mở trình tạo, không có trang trống.
  - Trình tạo là trang đầy đủ chứ không phải hộp thoại, theo thứ tự Khi › Chỉ khi › Thì › Xem trước.
    - Phần Xem trước viết lại luật bằng câu thường. Luật "sắp đến hạn" kể tên những thẻ hôm nay sẽ bị tác động; luật theo sự
      kiện nói số thẻ đang khớp điều kiện.
    - Nút chính ở chân trang là "Lưu luật", hoặc "Lưu luật với Pro" khi chưa có Pro.
  - Từ chối:
    - luật kích hoạt luật khác;
    - chạy ngầm mà không ghi nhật ký;
    - khoá cả việc xem trước;
    - kéo-thả khối kiểu lập trình;
    - hứa chạy đúng giờ khi app đóng (chỉ "Báo cho tôi" là kêu khi app đóng).
- **Tóm tắt các bảng** (Cài đặt › Thông báo).
  - Câu hỏi: "Hôm nay hoặc tuần này các bảng của tôi còn gì?"
  - Chọn Tắt / Hằng ngày / Hằng tuần (chọn thứ), và chọn bảng nào được tóm tắt.
  - Mỗi bảng có việc chiếm một dòng; bảng trống bị bỏ qua, ngày không có việc thì không báo. Áp dụng giờ yên lặng. Khi bật
    "Ẩn tên thẻ" thì chỉ hiện tổng.
  - Không đổi tên "Việc hôm nay" (miễn phí) thành tính năng Pro.
- **Kêu đúng giờ**. Từ Android 13 máy có thể chặn báo thức chính xác. Khi đó trang Thông báo có thêm dòng "Lời nhắc có thể
  đến muộn" giải thích lý do và mở "Báo thức và lời nhắc". Không hỏi quyền này khi máy không cần.
- **Kiểu widget** (Cài đặt › Widget).
  - Câu hỏi: "Widget trên màn hình chính sẽ trông thế nào?"
  - Miễn phí: Theo máy, Sáng, Tối. Pro: Vải lanh, Đồng cỏ, Gạch nung, Bến cảng, Hoàng hôn tím, Trời đêm.
  - Chạm vào một kiểu Pro thì năm bản xem trước đổi theo ngay, kèm dòng "Đang xem trước" và nút "Dùng với Pro".
  - Chữ đạt 7:1, chữ phụ đạt 4,5:1 trên mọi nền; đã đo, thấp nhất là 12,9:1 và 5,6:1.
  - Chấm màu widget trước đây là indigo, đã đổi về màu Boards.
- **Báo cáo xuất bảng** (Xuất › Báo cáo, Pro). Câu hỏi: "Bảng này đang ở đâu?"
  - Nội dung gồm:
    - bốn con số (đang mở, đã xong, hạn hôm nay, quá hạn);
    - số thẻ hoàn thành mỗi tuần trong 8 tuần, tính từ thời điểm hoàn thành thật;
    - tiến độ theo nhóm (bỏ nhóm không có thẻ);
    - bảng các thẻ đang mở xếp theo hạn, tối đa 80 dòng, rồi chỉ sang CSV.
  - Tuỳ chọn "Trường tuỳ chỉnh" (Pro) thêm giá trị trường lên thẻ và thành cột trong báo cáo.
  - Bản xem trước vừa khít bề ngang và chụm để phóng to; ảnh lưu ra giữ kích thước gốc.
- **Đã soát ảnh §2.7** trên BlueStacks android 11 (1080×1920, mật độ 320) ngày 2026-11-08.
  - Đã sửa:
    - nhãn ô chọn bị ẩn;
    - các ô dính nhau;
    - "1 days";
    - biểu tượng lấp lánh kiểu AI (đổi thành tia sét như ở menu);
    - báo cáo tràn ngang.
  - Chưa soát được widget đặt thật, vì launcher của BlueStacks không hỗ trợ widget.
- **Kiểm tra**:
  - engine `rules_test.dart` (9);
  - app `rules_app_test.dart` (6: luật, luật sắp hạn, kiểu widget, báo cáo và trường tuỳ chỉnh, tóm tắt).

### Handy Boards · các phần Pro làm trước đó (ghi bù hợp đồng, 2026-11-08)
Quy tắc chung giống mục trên.

- **Việc của tôi** (Trang chủ › Việc của tôi).
  - Câu hỏi: "Hôm nay tôi làm gì, ở mọi bảng?"
  - Ba nhóm: Hôm nay, Còn tồn, Sắp tới (2 tuần). Mỗi thẻ chỉ xuất hiện một lần và ghi bảng của nó. Nút "Tất cả về hôm nay"
    nằm ở nhóm Còn tồn.
  - Xem miễn phí; chuyển thẻ thì hỏi Pro.
  - Trống: "Không có gì cho hôm nay", kèm lối đi Bảng.
  - Từ chối: một danh sách trộn không chia nhóm.
- **Chuyển tiếp thông minh** (Cài đặt › Tự động hoá).
  - Ba chế độ: Tắt / Hỏi mỗi ngày mới / Tự chuyển.
  - "Tự chuyển" cho xem trước danh sách trước khi bật, mỗi ngày chạy một lần, có Hoàn tác, và không bao giờ đổi hạn nộp.
- **Mẫu thẻ**.
  - Lưu từ Thẻ ⋮ › Lưu làm mẫu thẻ. Dùng từ chân cột › Từ mẫu của tôi. Quản lý ở Cài đặt › Mẫu thẻ của tôi.
  - Mẫu chỉ giữ khuôn: không giữ id, ngày cụ thể, trạng thái hay lịch sử.
- **Trường tuỳ chỉnh** (Bảng ⋮).
  - Sáu kiểu: chữ, số, ngày, có/không, một lựa chọn, liên kết.
  - Không xoá hẳn mà cất đi.
  - Giá trị hiện trên thẻ và đọc được khi không có Pro.
  - Từ chối: công thức, liên kết bản ghi, giao diện bảng tính.
- **Bộ lọc đã lưu** (chip Bộ lọc trên bảng).
  - Một tên, chọn "tất cả" hoặc "bất kỳ" điều kiện, rồi các điều kiện: cột, nhóm, ưu tiên, khoảng hạn, có lời nhắc.
  - Nhóm, tìm kiếm và "Hạn trong 3 ngày" vẫn miễn phí.
- **Lịch sử bảng** (Bảng ⋮, Pro).
  - Chỉ đọc, mới nhất trước, gom theo ngày, xem 7 ngày / 30 ngày / Tất cả.
  - Chỉ từ sự kiện thật của thẻ, không dùng ảnh chụp bảng, không dựng lại quá khứ (theo yêu cầu của chủ).
- **Lặp tuỳ chỉnh** (Thẻ › Lặp lại › Tuỳ chỉnh).
  - Mỗi N ngày, tuần hoặc tháng; chọn thứ trong tuần; kết thúc vào một ngày hoặc sau N lần.
  - Thẻ kế tiếp chỉ được tạo khi thẻ này xong, không tạo sẵn hàng loạt.
- **Thông báo** (Cài đặt › Thông báo).
  - Công tắc chính, giờ báo tóm tắt, Việc hôm nay, Sắp đến hạn, Còn tồn, giờ yên lặng, ẩn tên thẻ, chọn bảng nào được báo.
  - Chỉ xin quyền khi người dùng bật một thứ cần quyền, không xin lúc mở app lần đầu. Bị từ chối thì chỉ đường vào Cài đặt
    của máy.
- **Widget** (Cài đặt › Widget).
  - Năm bản xem trước dựng từ đúng dữ liệu widget nhận được.
  - Tên thẻ mặc định tắt, để màn hình chính không lộ việc riêng.
  - Có hướng dẫn cách thêm widget, vì launcher đặt widget chứ không phải app.
  - Hai widget Pro hiện "Mở khoá trong app" thay vì dữ liệu giả.
- **Kiểm tra**:
  - `pro_tools_test`;
  - `settings_test` (widget, thông báo);
  - `my_work_test`, `custom_fields_test`, `saved_filters_test`, `repeat_test`, `board_history_test`, `notify_plan_test`.

## Hợp đồng: Handy Bookmark · nhắc đọc sau, thông báo cần xử lý, widget (2026-11-08, chủ yêu cầu)
Triết lý chủ chốt: **"Save quietly, rediscover naturally"**. Lưu nhanh, không thông báo thúc giục; khám phá lại ở Trang
chủ và widget khi người dùng muốn. Giữ kiểu Bookmark hiện có (Geist, Newsreader cho tên thư viện, bảng màu và hình khối
trong `lib/design/theme.dart`), không bốc thăm kiểu mới.

Bỏ:
- thông báo "Nhắc mỗi tuần" (revisit);
- mọi tóm tắt đọc định kỳ, thông báo khám phá lại thông minh, nhắc đọc tự động.

Ô "chờ bạn xem lại" ở Trang chủ vẫn giữ, vì nó nằm trong app.

**Quyền thông báo.** Không xin khi mở app lần đầu. Chỉ xin khi người dùng:
- đặt một lời nhắc, hoặc
- bật một công tắc thật sự cần quyền.

Bị từ chối thì lời nhắc vẫn lưu và hiện trên mục, kèm một câu chỉ đường vào Cài đặt của máy.

**Nhắc đọc sau** (Free, mặc định tắt).
- Câu hỏi: "Khi nào tôi muốn đọc lại cái này?"
- Chỗ đặt nhắc:
  - khung lưu khi chia sẻ, ngay dưới "Đã lưu vào …";
  - trang chi tiết mục, dòng "Nhắc tôi".
- Lựa chọn, mỗi dòng ghi rõ ngày giờ thật:
  - Không nhắc (mặc định, được chọn sẵn);
  - Tối nay 20:00 (ẩn sau 19:30);
  - Ngày mai 09:00;
  - Cuối tuần, tức thứ Bảy tới 09:00;
  - Chọn ngày và giờ (`pickHandyDate` rồi chọn giờ, không gõ tay).
- Một chạm là áp dụng và đóng. Dòng ghi chú: "Chỉ bookmark này được nhắc. Các bookmark khác không bị ảnh hưởng."
- Không bao giờ tự chọn "Ngày mai" sau khi lưu.
- Khung chia sẻ tự đóng sau khoảng 2,5 giây như cũ. Chạm vào phần "Nhắc tôi" thì khung giữ lại; chọn xong hiện "Sẽ nhắc
  lúc …" rồi đóng.
- Thông báo:
  - tiêu đề là tên mục; nội dung bị ẩn trên màn hình khoá (`visibility: private`);
  - chạm vào thì mở mục và xoá lời nhắc;
  - hai nút "Đã đọc" và "Nhắc lại sau 1 giờ" chạy ngầm, không mở app; app áp kết quả vào thư viện ở lần mở sau, trước
    khi lên lịch lại;
  - báo thức chính xác khi máy cho phép, nếu không thì loại không chính xác.
- Từ chối: hệ thống báo lại nhiều lần, lặp lại, luật thông minh.

**Thông báo cần xử lý** (Free, Cài đặt › Thông báo › "Báo khi cần xử lý", mặc định bật). Chỉ khi:
- sao lưu tự động lỗi;
- đồng bộ Drive cần đăng nhập lại, Drive đầy, hoặc lỗi không tự hết;
- link chia sẻ không lưu được.

Cách báo:
- mỗi loại một thông báo, được thay thế chứ không chồng lên nhau;
- tự gỡ khi lỗi đã hết;
- không báo lại cùng một lỗi ở lần mở sau;
- chỉ báo khi app không ở màn hình trước (khi đang mở app, lỗi đã hiện ngay trong app);
- không bao giờ tự xin quyền cho loại này; nếu máy chưa cho phép, dòng cài đặt nói "Cần cho phép thông báo" và chạm vào
  mới xin;
- chạm vào thông báo thì mở đúng chỗ sửa (Cài đặt › Sao lưu, Đồng bộ, hoặc Trang chủ với danh sách link lỗi).

Mất mạng tạm thời không báo.

**Widget** (Android; trang Cài đặt › Widget màn hình chính có bản xem trước dựng từ đúng dữ liệu widget nhận).
- Miễn phí:
  - Lưu nhanh: một nút mở khung dán link;
  - Hàng chờ đọc: 3 mục chưa đọc mới nhất;
  - Bộ sưu tập yêu thích: chọn một bộ, xem số mục và 3 mục mới nhất.
- Pro:
  - Gợi ý đọc: 4 dòng có nhãn: mới lưu chưa đọc, lưu lâu chưa mở, một mục yêu thích, một mục từ bộ đã chọn; đổi mỗi ngày,
    không ngẫu nhiên mỗi lần vẽ;
  - Thư viện ảnh: 4 ảnh thumbnail thật của các mục gần đây;
  - Kiểu widget Pro cho mọi widget.
- Không có widget nào gửi thông báo.
- Tên mục mặc định hiện, vì đây là app lưu trữ cá nhân. Công tắc "Ẩn tên trên widget" chỉ còn hiện số đếm.
- Xem trước kiểu Pro không cần mua; chỉ hỏi Pro khi bấm Dùng. Hai widget Pro khi không có Pro hiện "Mở khoá trong app",
  không có dữ liệu giả.

**Trạng thái và kích thước.**
- Thư viện trống: widget nói "Chưa có gì để đọc" và nút Lưu nhanh vẫn chạy.
- Bộ sưu tập yêu thích bị xoá: widget quay về "Chưa xếp".
- Lỗi vẽ widget không bao giờ làm hỏng app.
- Trang cài đặt là một cột, đo ở 320–1440 px.
- iOS, Windows và web: trang nói rõ widget chỉ có trên Android.

**Kiểm tra:**
- engine/app: test cho các lựa chọn giờ, các nút trên thông báo, thông báo cần xử lý (không lặp, tự gỡ), dữ liệu widget;
- soát ảnh §2.7 trên BlueStacks.

### Handy Boards · một cách xem, thanh tuần, lọc theo nhóm, menu gọn (2026-11-08, danh sách bug của chủ)
- **Bỏ chế độ Thời gian, gộp vào Bảng.** Một bảng chỉ còn một cách xem. Phía trên các cột có thanh "‹ 2/11 – 8/11 ›" (key `week-bar`):
  - ‹ › đi đúng một khoảng; "Tuần này" để quay về; nút lịch chọn khoảng (ngày, tuần, 2 tuần, tháng, 3 tháng, tự chọn); "Tất cả" xem mọi thẻ.
  - Trên điện thoại vẫn một hàng: "Tuần này" và khoảng thành icon, "Mọi thẻ" nằm trong menu khoảng.
  - Mỗi khoảng hiện thẻ có ngày làm, hạn nộp hoặc lúc hoàn thành rơi vào khoảng đó.
  - Khoảng chứa hôm nay hiện thêm thẻ chưa có ngày và việc chưa xong từ trước.
  - Bảng có thẻ mang ngày thì mở sẵn ở tuần này; bảng không có thẻ nào mang ngày thì không có thanh.
- **Việc chưa xong từ trước:** một dòng phía trên bảng, "N việc chưa xong từ trước ›" (chạm để xem) cùng nút "Về hôm nay", có Hoàn tác. Dòng tự ẩn khi không còn việc.
- **Ngày trên thẻ luôn có tên:** "Làm: Thứ Ba" và "Hạn: Thứ Ba", kèm "· trễ" khi quá hạn.
- **Lên lịch:** ⋯ trên thẻ có "Làm hôm nay", "Lên lịch… / Đổi ngày làm…" và "Bỏ ngày làm". Hạn nộp không bao giờ tự đổi; thẻ chỉ có hạn nộp thì hỏi trước. Mở ⋯ từ trong chi tiết thẻ thì không có "Chuyển tới…", vì chi tiết thẻ đã có ô chọn cột.
- **Chọn một nhóm là lọc ngay.** Thanh dưới ghi "Đang lọc: chỉ X" kèm ✕. Bỏ cách làm mờ thẻ khác và nút "Chỉ hiện nhóm này".
- **Menu ⋮ của bảng** chia 4 nhóm: Bảng · Hiển thị và cấu trúc · Công cụ Pro · Chia sẻ, rồi Lưu trữ và Xoá ở cuối.
  - Bỏ "Sửa nhóm" (đã có nút Sửa trên bảng) và "Ghim nút Thời gian".
  - "Giao diện và ảnh bìa" là một mục; thanh giao diện có nút "Ảnh bìa…".
  - Sheet cao tối đa 85% màn, để chạm ra ngoài vẫn đóng được.
  - Dấu Pro chỉ hiện khi chưa có Pro, và giống nhau ở mọi dòng.
- **Pro hỏi ngay khi bấm**, mở thẳng trang Pro, không vào trang chi tiết trước: Luật tự động, Trường tuỳ chỉnh, Bộ lọc đã lưu, Việc của tôi, Mẫu thẻ (Cài đặt và chân cột), mẫu bảng Pro. Nền bảng, ảnh bìa, kiểu xuất và kiểu widget vẫn cho xem thử tại chỗ.
- **Căn lề:** nút ⋯ ở đầu cột và nút mẫu thẻ ở chân cột luôn sát mép phải. Nút ⋯ trên thẻ có vùng chạm 48 pt.
- **Kiểm tra:** `week_bar_app_test` (8), `kanban_app_test`, `pro_tools_test`, `rules_app_test`, `settings_test`, `layout_sweep_test` (11 kích thước).

## Hợp đồng: trang Pro của Handy Boards và Handy Bookmark (2026-11-08, mục 8 trong danh sách bug của chủ)
Chạy theo `design-taste-frontend` (app-screens) và `frontend-ui-engineering`. Thay trang Pro cũ của Boards (một danh sách thẻ
icon + chữ) và trang Explore Pro của Bookmark (ba khối chữ). Trang này cũng thay sheet "Free và Pro có gì" đã bỏ khỏi Cài đặt.

- **Việc và câu hỏi.** Người tới đây vì vừa chạm một thứ Pro (hoặc mở từ Cài đặt). Câu hỏi: "Thứ tôi vừa chạm làm gì, Pro
  còn gì nữa, và giá bao nhiêu?" Phát hiện chính đặt đầu trang: chính tính năng vừa chạm, đang chạy.
- **Mặt của trang (signature): "sân khấu".** Ô trên cùng diễn tính năng bằng giao diện thật của app thu nhỏ, chạy vòng lặp
  (Boards: thẻ, cột, bìa và nền thật vẽ bằng `CoverArt`/`boardLooks`; Bookmark: thẻ link, giao diện và kiểu bày thật). Không
  dùng ảnh GIF hay video: hình vẽ bằng widget nên luôn đúng giao diện hiện tại, đúng sáng/tối, đúng tiếng Việt, không tăng
  dung lượng app. Chạm một dòng ở danh sách bên dưới thì sân khấu đổi sang tính năng đó và cuộn lên.
- **Thứ tự:** sân khấu (hình lớn, tên, một câu giải thích) → "Pro còn có" chia nhóm (Boards: Lên kế hoạch / Tự động / Giao
  diện / Xuất và xem lại; Bookmark: Giao diện / Sắp xếp / Đọc và tìm), mỗi dòng một hình nhỏ đứng yên + tên + một dòng → bảng
  "Miễn phí và Pro" (mỗi mục: miễn phí có gì, Pro thêm gì; số lấy từ dữ liệu thật như số mẫu, số nền) → dòng "Luôn miễn phí"
  và "Mất Pro không mất dữ liệu".
- **Hành động chính duy nhất:** thanh mua dính đáy: "Mua một lần · <giá cửa hàng>" + "Khôi phục". Không có giá giả.
- **Trạng thái:** chưa thiết lập cửa hàng (nút tắt, nói rõ), đang mua (vòng xoay), chờ xác nhận, huỷ (không trừ tiền), lỗi
  hoặc không kết nối (thử lại sau), đã có Pro (cảm ơn; mở từ một tính năng thì nút thành "Tiếp tục" quay về đúng chỗ).
- **Chuyển động:** vòng lặp 3–4 giây, dừng ở khung cuối 1 giây. Hệ điều hành bật giảm chuyển động thì chỉ hiện khung cuối.
  Hình nhỏ trong danh sách luôn đứng yên (không chạy chục bộ hẹn giờ cùng lúc). Vòng lặp dùng `HandyDemoLoop` trong kit.
- **Trợ năng:** hình có nhãn mô tả việc nó diễn; dòng danh sách là nút có tên, có trạng thái "đang xem"; thanh mua có
  `liveRegion` cho trạng thái; chữ đạt 4,5:1.
- **Đáp ứng 320–1440:** một cột tối đa 720 px; sân khấu cao 180 (≤360 px) đến 240; bảng so sánh xếp hai ô Miễn phí | Pro dưới
  tên mục để không bị ép ở 320 px; chữ ×2 vẫn không tràn (hình nằm trong `FittedBox`).
- **Nền tảng:** Android Back và vuốt về iOS đóng trang; web URL `/pro`; Windows/web không có cửa hàng thì báo "chưa mở bán".
- **Từ chối:** icon trong ô màu; thẻ tính năng giống hệt nhau xếp lưới; gradient, ảnh minh hoạ chung chung; đếm ngược hay
  "giảm giá" giả; khoá việc xem; nói tính năng chưa có.

### Handy Boards · dòng thời gian cố định theo bảng, lọc nhiều nhóm (2026-11-08, mục 11–12 của chủ; thay thanh tuần ở trên)
- **Một chỗ bật:** chip "Thời gian" (hoặc "Theo tuần"…) ngay hàng bộ lọc của bảng. Chạm vào thì chọn Theo ngày / Theo tuần /
  Theo tháng / Tắt, áp dụng ngay. Khi bật, việc chưa xong từ các kỳ trước được đem về hôm nay (một Hoàn tác).
- **Thẻ thuộc kỳ nào:** ngày làm của thẻ, chưa có thì ngày tạo. Hạn nộp không quyết định chỗ của thẻ. Thẻ đã xong ở lại kỳ của nó.
- **Thanh ‹ kỳ ›:** ghi ngày thật và "Tuần này" / "Đã qua · chỉ xem" / "Sắp tới". Không còn nút đổi khoảng hay "Tất cả".
  - Kỳ hiện tại: thêm, sửa, kéo thả như thường. Có dòng "N việc chưa xong từ những tuần trước · Đem qua tuần này".
  - Kỳ sau: thêm thẻ thì ngày làm là ngày đầu kỳ đó.
  - Kỳ đã qua: chỉ xem. Không thêm thẻ, không kéo thả, không menu thẻ. Mở thẻ để đọc, với hai nút "Đánh dấu xong" và
    "Đem qua tuần này". Tick việc con vẫn được. Thẻ chưa xong có dải "Chưa xong" và nút đem qua; đầu kỳ có "Đem tất cả".
- **Đổi đơn vị:** chỉ sang kỳ dài hơn (ngày → tuần → tháng). Kỳ ngắn hơn hiện ra nhưng bị khoá, kèm lý do; bảng nhớ kỳ dài
  nhất đã dùng (`timelineFloor`).
- **Tắt:** không thẻ nào đổi. Có hộp xác nhận đếm sẵn số thẻ, kèm lựa chọn lưu trữ thẻ đã xong ở các kỳ trước. Bật lại thì thẻ nào
  về kỳ nấy.
- **Thẻ lặp lại:** bản kế tiếp được xếp cho kỳ của ngày lặp tiếp theo, ví dụ họp mỗi thứ Hai sang thứ Hai tuần sau.
- **Mẫu bảng:** mẫu sống theo thời gian thì bật sẵn. Mẫu có câu hỏi "Xếp theo" cho chọn Theo tuần / Theo tháng / Không theo thời
  gian.
- **Lọc nhóm:** chạm để bật hoặc tắt từng nhóm, chọn được nhiều nhóm cùng lúc. Dòng lọc ghi "Đang lọc: chỉ A, B". Thẻ thêm khi
  đang lọc vào nhóm chọn đầu tiên. Bộ lọc đã lưu cũng chọn nhiều nhóm (`categories`).
- **Từ chối:** khoá việc xem kỳ cũ; tự đổi hạn nộp; đoán ngày khi đổi sang kỳ ngắn hơn.

## Hợp đồng: Handy Bookmark · thư mục trong bộ sưu tập, một cấp, Pro (2026-11-09, chủ yêu cầu)

- **Việc người dùng làm:** một bộ sưu tập lớn (Công thức nấu ăn, 40 mục) cần chia vài ngăn (Món canh, Bánh) mà không thành cây
  nhiều tầng khó tìm. Dữ liệu: bộ sưu tập (tên, màu, biểu tượng, `parentId`), mục đã lưu (`collectionId`).
- **Quyết định của chủ:** "bộ sưu tập con" có sẵn trở thành **thư mục** (EN *folder*). Tối đa một cấp: thư mục không chứa thư
  mục. Tạo thư mục mới, hoặc đưa một bộ vào trong bộ khác, cần Pro. Dữ liệu cũ giữ nguyên và dùng được khi không có Pro (mở,
  đổi tên, đổi màu, xếp mục vào, xoá, đưa ra ngoài thành bộ thường). Bộ lồng từ hai cấp trở lên được gắn lại thành thư mục của
  bộ gốc trên cùng; không mục nào đổi chỗ chứa.
- **Câu hỏi của màn bộ sưu tập:** "trong bộ này có gì, nằm ở ngăn nào?" Dải thư mục (chip có chấm màu) ngay dưới tên bộ, như
  dải bộ con cũ; đếm ghi "12 mục · 2 thư mục". Mở thư mục là trang bộ sưu tập của nó.
- **Hành động chính:** menu bộ sưu tập › **Thư mục mới** (chỉ có ở bộ cấp trên cùng; thư mục không có dòng này). Chưa có Pro
  thì dòng ghi thêm "Pro", chạm mở trang Pro ở phần Thư mục.
- **Sửa bộ sưu tập:** trường "Nằm trong" thành **"Thư mục của"**, chỉ liệt kê bộ cấp trên cùng (không liệt kê thư mục, không
  liệt kê chính nó). Bộ đang có thư mục thì không đặt vào bộ khác được: trường bị khoá, ghi "Bộ này đã có thư mục, nên ở cấp
  trên cùng". Chọn "Không" luôn miễn phí; chọn một bộ cha mới thì hỏi Pro khi bấm Lưu.
- **Trạng thái:** không có thư mục → không hiện dải; thư mục rỗng → trang thư mục trống như bộ rỗng; chưa Pro → mọi thư mục cũ
  vẫn đủ chức năng trừ tạo mới / đưa vào.
- **Trang Pro:** phần "Thư mục trong bộ sưu tập" ở nhóm "Bớt xếp bằng tay", có minh hoạ chạy: bộ Công thức chia ra hai thư mục,
  các mục trượt vào đúng ngăn, khung cuối là bộ có hai chip thư mục. Bảng Miễn phí / Pro: dòng Bộ sưu tập, cột Pro ghi
  "+ thư mục, bộ sưu tập thông minh".
- **Nền tảng:** Android, iOS, Windows, Web như nhau; không có phím tắt riêng. Trình đọc màn hình đọc chip "Thư mục Món canh,
  5 mục".
- **Kiểm:** 320 px và chữ ×2 (dải chip cuộn ngang, menu không tràn), sáng và tối.
- **Từ chối:** cây nhiều cấp; biểu tượng thư mục to màu sắc cho từng bộ; xoá hay làm phẳng dữ liệu cũ khi mất Pro.

## Hợp đồng: Bookmark và Boards · pastel sáng + pastel tối (2026-11-09, thay bản thử cùng ngày)

Chạy `design-taste-frontend` (app screens) với bản phác HTML dùng chung dữ liệu: Bookmark rút `pastel-consumer`, `editorial-greeting`, `achromatic-ledger`; Boards rút `pastel-consumer`, `framed-sheet`, `editorial-greeting`. Chủ chọn **pastel** cho cả hai; trong bốn biến thể pastel (sáng, khối neo đậm, ấm mềm Nunito, nền tối) chủ lấy **sáng làm giao diện sáng** và **nền tối làm giao diện tối**. Quy tắc mới của chủ: mỗi app độc lập, bảng màu riêng đầy đủ.

**Handy Bookmark**
- Câu hỏi của Trang chủ: "Có gì đang chờ mình, và thứ mình lưu nằm đâu?" Phát hiện đọc đầu tiên: dòng dưới tiêu đề "N mục · N chưa xếp".
- Mặt (face): màu của từng bộ sưu tập thành ô nhạt với chữ là màu đậm của chính hue đó (`hueField`); ảnh của mục lưu là vật thật trên màn.
- Dấu ấn: dải ruy băng vàng (`ReadLaterRibbon`) trên ảnh của mục có hẹn đọc còn phía trước.
- Token sáng: nền `#F3F5F7`, khung trắng, raised `#EEF1F4`, chữ `#1B1D1F`/`#5C6064`, hành động teal `#0E7490`. Tối: nền `#141516`, khung `#1E2022`, raised `#26292B`, chữ `#F2F2F2`/`#A9ADB1`, hành động `#7CC8D8`; ô hue = hue trộn 26% vào khung, chữ = hue trộn 62% về trắng. Font Manrope (400–700, cắt tĩnh từ Google Fonts, đủ tiếng Việt, OFL đi kèm); Newsreader chỉ còn ở màn chào và vài giao diện Pro. Bo: khung 20, ô bộ sưu tập 20, bên trong 10–14, nút/ô nhập 12.
- Trang chủ điện thoại, theo thứ tự: tiêu đề + dòng đếm; ô dán link + nút; **Hẹn đọc** (khung trắng, nhóm theo Tối nay/Hôm nay, Ngày mai, Cuối tuần, ngày; tối đa 3 mục, ẩn khi không có); **Chưa xếp** (4 mục mới nhất, mỗi mục có 2 bộ sưu tập hay dùng làm chip một chạm + "Khác…", "Xem tất cả" mở Chưa xếp); thẻ Tập trung; **Bộ sưu tập** dạng ô pastel (2 ảnh, hoặc tên mục trên giấy mờ, hoặc dấu + "Chưa có gì"); **Mới lưu** trong khung trắng, 2 cột × 2 hàng, ảnh bo 10.
- Trạng thái: thư viện trống giữ màn trống cũ; ghi lỗi khi xếp thì mục nằm lại (chip không đổi); chip 32pt trong vùng chạm 48pt; 320px với chữ 200% không tràn (tiêu đề khung co, nút "Xem tất cả" co).
- Máy tính bảng/desktop: giữ khung thanh bên hiện có (lượt sau đưa trang tổng quan vào khung rộng); token và ô bộ sưu tập áp dụng chung.

**Handy Boards**
- Câu hỏi của màn bảng: "Tuần này còn gì phải làm và đang ở cột nào?"
- Mặt: ô nhóm ở dải nhóm là màu nhạt của chính nhóm, chữ màu đậm của nhóm, thanh tiến độ màu nhóm trên nền trắng mờ.
- Dấu ấn: nhóm của thẻ là miếng băng keo màu nhóm, lệch nhẹ, hai đầu xé răng cưa (`CategoryTape`), đè lên ảnh bìa khi có.
- Token sáng: nền `#F2F2F0`, cột `#E9E8E6`, thẻ trắng, hành động magenta `#A61C8E`, Plus Jakarta Sans. Tối: nền than `#141516`, cột `#1B1D1F`, thẻ `#25282A`, ô nhóm sậm, hành động hồng sáng `#E07CCB`, chữ trễ hạn `#FF9B8C`.
- Điện thoại: một cột một lần, hai cột kề lộ 28px hai bên làm chỗ thả khi kéo thẻ, hàng chip tên cột (chạm để nhảy cột).

**Sửa sau rà soát (2026-11-09, chủ báo lệch lề và khung Chưa xếp quá to)**
- Bookmark: khung Chưa xếp bỏ; Chưa xếp gộp vào thẻ hàng chờ cùng Tập trung ("N mục chưa xếp · Xếp nhanh, từng mục một" và "N mục chờ bạn xem lại"). Xếp nhanh mở khung dưới: một mục một lần, chip 4 bộ sưu tập hay dùng + "Khác…", "Bỏ qua"; xếp xong mục cuối thì tự đóng; ghi lỗi thì mục vẫn nằm đó. Bộ sưu tập vào khung trắng như các khối khác, nên mọi tiêu đề khối cùng một mép; tên bộ sưu tập tối đa 2 dòng. Nút "Xem tất cả" luôn sát mép phải (chỉ co khi thiếu chỗ).
- Boards: cột trên điện thoại nằm đúng lề 16 của trang, cột kề lộ mép ở phần 11pt ngoài lề; "Sửa" lên cùng hàng với "Nhóm" ở bên phải, nút lọc nhanh xuống hàng riêng từ lề 16 (cuộn ngang); mũi tên tuần thẳng lề 16; trên màn rộng tiêu đề Nhóm thẳng lề 24 với các ô.

**Loại bỏ**: khối neo đậm, Nunito ấm mềm, lời chào serif làm tiêu đề, khung viền, mảng màu loang, linh vật, thanh chuyển app, thẻ chuỗi ngày.

## Hợp đồng: dựng lại Bookmark và Boards đúng bản phác pastel (2026-11-09, chủ yêu cầu)

Lần trước chỉ áp màu và vài chi tiết lên màn cũ nên khác bản phác (chủ đã so và chỉ ra). Lần này dựng lại bố cục theo bản phác đã chọn (`pastel` biến thể 1 sáng, 4 tối), kiểm tra bằng ảnh BlueStacks đặt cạnh bản phác, từng màn một.

**Bookmark (điện thoại)**
- Thanh trên: ô logo + "Handy Bookmark", Tìm, Cài đặt. Tiêu đề "Thư viện" (h1) + dòng "**87** mục · **4** chưa xếp · **3** hẹn đọc".
- Ô dán link + nút chữ "Lưu" (ô trống: Lưu mở khung thêm: ảnh, nhiều link, cách lưu từ app khác).
- **Không khung bao khối** (chủ chốt thêm): mỗi khối là tiêu đề trên nền (lề 16) + các mục, mỗi mục một thẻ/dòng nền trắng riêng.
- Hẹn đọc: nhóm Tối nay / Ngày mai / Cuối tuần (giờ bên cạnh), mỗi mục một dòng trắng với ảnh 56 có ruy băng vàng; "Xem lịch" mở danh sách hẹn nhắc.
- Chưa xếp: tối đa 4 dòng, mỗi dòng ảnh 52 + tên + 2 chip bộ sưu tập hay dùng trên một hàng; "Xếp từng mục" mở Xếp nhanh.
- Bộ sưu tập: ô pastel 2 cột (ảnh hoặc tên mục), "Bộ mới". Mới lưu: thẻ ảnh 2 cột, mỗi thẻ nền trắng riêng, ruy băng khi có hẹn.
- Tập trung (không có trong bản phác, giữ tính năng): một dòng nhỏ dưới Chưa xếp.

**Boards (điện thoại, màn bảng)**
- Thanh trên: ←, Tìm, Lọc (mở khung: chế độ thời gian, bộ lọc đã lưu, hạn trong 3 ngày, ẩn/hiện nhóm, sửa nhóm), Tuỳ chọn. Không còn dải ảnh bìa trên màn bảng (bìa vẫn ở Trang chủ).
- Tiêu đề bảng (h1) + dòng "**7** việc đang mở · **1** trễ · kết thúc học kỳ 15/1, còn 67 ngày" (ngày quan trọng gần nhất, chạm để sửa).
- Ô nhóm 2×2: tên trên (mực đậm cùng tông), số "1/3 xong" lớn, thanh tiến độ; không chấm màu, không tiêu đề "Nhóm". Ô đang chọn: nền đậm hơn + dấu tick, ô khác mờ.
- Hàng tuần một dòng: ‹ "9/11 – 15/11 Tuần này" ›, nút về tuần này ngay sau. Đổi tuần: các cột trượt theo hướng.
- Chip cột cao 36, cách cột 12; cột kề lộ khoảng 22pt hai bên làm chỗ thả.
- Nền: bảng mặc định dùng nền trung tính của bản phác; bảng đã chọn "giao diện bảng" (Pro) giữ màu của giao diện đó.

**Desktop (cả hai app)**: thanh bên như ảnh chủ gửi (logo + tên app; mục chính có số đếm; nhóm "Bộ sưu tập"/"Bảng" có chấm/ô màu và số; chân: Thùng rác, Cài đặt); Bookmark "Thư viện" mở trang tổng quan theo lưới bản phác; Boards màn bảng 4 cột đều nhau, "Lọc" + "Thẻ mới" bên phải tiêu đề.


## Hợp đồng: Bookmark và Boards · tương phản mạnh 3a, chữ to (2026-11-09, chủ chọn)

**Vì sao.** Người dùng góp ý: app ít màu và chữ nhỏ, khó đọc với người mắt yếu. Chủ xem 5 hướng tương phản mạnh (3a–3e) và chọn **3a cho cả hai app**. Riêng Boards, màu hồng phải sáng hơn mận đậm nhưng chưa rực bằng 3c.

**Việc của màn.** Không đổi. Chỉ đổi màu và cỡ chữ để mắt tìm ra ngay tên trang và việc chính.

**Dải đầu trang** (một mảng đậm duy nhất trên trang)

| | Bookmark | Boards |
|---|---|---|
| Nền dải sáng / tối | xanh mực `#0F4B54` / `#145A64` | mận `#7A1A69` / `#6E1F61` |
| Trên dải, điện thoại | tên thư viện, dòng số, ô dán link + nút **Lưu** vàng `#E0A93B` | tên bảng, dòng số; ngày quan trọng xuống dòng riêng, không để dấu "·" lửng cuối dòng |
| Trên dải, màn rộng | như điện thoại, nằm ngang | thêm nút **Lọc** (trong suốt, có chấm khi đang lọc) và nút vàng **Thẻ mới**, đặt thẻ vào cuối cột đầu; ẩn khi xem kỳ đã qua |

- Chữ trên dải: tên màu trắng 700. Dòng phụ dùng `bandSub` (`#CFE5E6` / `#F3DDEE`). Số in đậm màu trắng.
- Màn rộng: nút lọc chuyển từ thanh trên xuống dải, nên thanh trên chỉ còn Tìm và Thêm.
- Mục đang chọn ở thanh bên: nền màu dải, chữ trắng, số đếm `bandSub`.
- Bookmark, thẻ hàng chờ: **Chưa xếp** và **Chờ xem lại** cùng nền tint xanh nhạt, mũi tên màu link (chủ chọn, thay bản thẻ Chưa xếp màu dải và nền đất nung ở bản tối). Điện thoại: hai thẻ tách rời, cách 8pt, ngay dưới dải, rồi mới tới Hẹn đọc (đúng mock).
- Pro looks của Bookmark: dải lấy chính màu của look, làm đậm tới mức chữ trắng đọc được.

**Màu nền và chữ**
- Bookmark sáng: nền `#EEF3F3`, chữ `#0B1213`, chữ phụ `#38423F`, link `#0F4B54`.
- Boards sáng: nền `#F3EFF2`, cột `#E9E4E7`, chữ `#0F0B0E`, chữ phụ `#3B3439`.
- Bản tối: chữ phụ nâng lên `#BCC1C4`.
- Ô bộ sưu tập và ô nhóm đậm hơn:
  - Bookmark: nền ô pha 22% màu, chữ pha 60% đen.
  - Boards: ô nhóm pha thêm 10% màu, chữ pha 60% đen (bản tối 70% trắng).

**Cỡ chữ** (cả hai app)

| Vai trò | Cỡ |
|---|---|
| Chữ đọc (bodyMedium / bodyLarge) | 15.5 / 16.5 |
| Chữ phụ (bodySmall, labelMedium) | 13.5, không nhỏ hơn |
| Tiêu đề mục (titleLarge) | 21, 700 |
| Tên trang trên dải | Bookmark 30, Boards 28 (điện thoại) / 32 (rộng) |
| Nút | 16 |

**Tương phản.** Đo lại sau khi đổi:
- Chữ trên dải: 9.6–10:1.
- Chữ phụ trên dải: 7.4–8:1.
- Nút vàng so với dải: 4.55:1.
- Chữ trên ô màu: ít nhất 9.4:1 (bản tối 6.7:1).
- Chấm màu và thanh tiến độ: ít nhất 3.1:1.

Kit sửa chung (`HandyPalette`): ở bản sáng, màu nhận diện được làm đậm tới 3.45:1 so với nền trắng (WCAG 1.4.11). Chỉ hổ phách và ô liu đổi. Ba lỗi trước đây hết:
- chấm hổ phách 2.36:1;
- chấm ô liu 2.87:1;
- thanh tiến độ hổ phách 2.49:1.

**Bố cục chịu chữ to**
- Thẻ link trong lưới Bookmark dành 82pt cho chữ (trước là 74).
- Bảng xem trước của Boards trên điện thoại hẹp (dưới 360pt) cao tối thiểu 744pt.

**Bác bỏ**
- Dải đậm ở nhiều chỗ.
- Thanh bên đậm (3d/3e không được chọn).
- Đổi màu hành động chính ở các màn khác: nút vàng chỉ nằm trên dải.

### Handy Boards · màu cam đất và icon khung bảng (2026-11-09, chủ chọn)

- **Màu chủ đạo:** đổi từ hồng magenta sang **cam đất** (chủ chọn phương án A trong 4 phương án).
  - Bản sáng: màu nhấn `#B53C0A` (4.7:1 trên cột), dải đầu trang `#7C2D12`, chữ dải phụ `#FCDCC8`, nền `#F5F1EE`, cột `#ECE6E1`, tint `#FBE5D8`.
  - Bản tối: màu nhấn `#F0936A`, dải `#6E2A12`.
  - Nút vàng trên dải giữ nguyên.
  - Màn chào, widget, báo cáo và theme web đổi theo.
- **Hệ quả cho màu nhóm:** `HandyPalette` bỏ các màu nhóm gần màu chủ đạo (cà chua, hổ phách) và dùng lại hồng. Màu nhóm trên bảng cũ vì vậy đổi theo vị trí; tên nhóm và dữ liệu không đổi.
- **Icon:** khung bảng màu kem chia ba cột, có một thẻ vàng, trên nền cam đất (chủ chọn phương án C).
  - Nguồn: `apps/handy_boards/assets/icon.svg`.
  - `tool/icon/render.py` giờ hỗ trợ path even-odd, để icon đơn sắc của Android vẫn giữ lỗ khung, và đọc màu nền icon từ SVG.
  - `tooling/app-icons.py` tạo icon cho mọi nền tảng.

## Hợp đồng: Handy Bookmark · gửi và nhận bộ sưu tập (2026-11-09, chủ yêu cầu)

**Việc của màn.** Gửi một hoặc nhiều bộ sưu tập cho bạn bè thành **một tệp**. Bạn bè mở tệp bằng trình duyệt như một trang đọc được, hoặc thêm vào Handy Bookmark của họ. Gửi và nhận đều miễn phí. Ảnh luôn đi kèm, đã thu nhỏ và bỏ dữ liệu máy ảnh.

**Màn gửi** (sheet, rộng tối đa 560)
- Lối vào:
  - điện thoại: Thư viện (Bộ sưu tập › Xem tất cả) › nút Gửi trên thanh trên;
  - màn rộng: "Tất cả bộ sưu tập" › "Gửi bộ sưu tập";
  - menu "…" của một bộ sưu tập › "Gửi cho bạn bè" (mở sẵn với bộ đó; một thư mục thì chọn bộ cha của nó).
- Nội dung:
  - tiêu đề "Gửi bộ sưu tập", một câu nói rõ tệp dùng để làm gì;
  - "Đã chọn n/N" kèm nút Chọn tất cả / Bỏ chọn;
  - danh sách bộ sưu tập cấp trên: ô chọn, chấm màu, tên, "12 mục · 2 thư mục";
  - hai dòng: thứ đi kèm (✓) và thứ ở lại máy (–);
  - công tắc "Kèm ghi chú của tôi", mặc định tắt;
  - nhắc "Ai nhận được tệp đều thấy mọi link…".
- Hành động chính: nút dưới cùng "Gửi 2 bộ sưu tập · 37 mục". Nút tắt và đổi thành "Chọn một bộ sưu tập" khi chưa chọn gì.
- Trạng thái: không có bộ sưu tập thì không hiện nút Gửi; lỗi khi tạo tệp đi qua `run` như mọi thao tác khác.

**Tệp gửi đi**
- Một trang HTML tự chứa. Nếu nhiều bộ: h1 là "N bộ sưu tập", mỗi bộ là h2, thư mục là h3.
- Dữ liệu cho app nằm trong một comment `HANDY_BOOKMARK_SHARE_V1`. Ảnh chỉ nằm một lần trong trang, đánh dấu bằng `data-item`.
- Cuối trang có dòng chỉ cách thêm vào app.

**Màn nhận** (sheet)
- Lối vào:
  - Thư viện / Tất cả bộ sưu tập › "Thêm bộ sưu tập được gửi cho bạn";
  - Cài đặt › Dữ liệu › Khôi phục. App tự nhận ra tệp được gửi và **không bao giờ** coi nó là bản sao lưu.
- Nội dung:
  - "Thêm N bộ sưu tập được gửi";
  - "42 mục · 5 đã có sẵn";
  - mỗi bộ với tên khi đến nơi và số mục;
  - lời nhắc khi thư mục bị gộp: "…tên thư mục thành thẻ. Cần Pro để giữ nguyên thư mục";
  - lời nhắc khi trùng tên ("(từ bạn)").
- Nút: Hủy và "Thêm n mục". Nút tắt và đổi thành "Đã có hết" khi không còn gì mới.
- Sau khi thêm hiện thông báo kèm Hoàn tác.

**Thư mục**
- Người gửi có Pro, người nhận có Pro: nhận đủ thư mục.
- Người nhận không có Pro: mục trong thư mục vào bộ cha, tên thư mục thành thẻ.
- Người gửi không có Pro thì vốn không có thư mục.

**Dữ liệu**
- Kiểm tra cả tệp trước khi ghi.
- Ảnh được ghi trước mục.
- Mục đến nơi ở trạng thái chưa đọc, giờ lưu là lúc nhận.
- Không bao giờ gửi đi: thẻ, hẹn nhắc, trạng thái đã đọc hay yêu thích, kết quả kiểm tra link, các bộ sưu tập khác.

**Nền tảng**
- Android/iOS: chia sẻ qua bảng chia sẻ của máy.
- Windows/web: tải tệp xuống.
- Chưa nhận được tệp qua nút "chia sẻ vào app" trên Android: phải lưu tệp rồi chọn trong app.

**Bác bỏ**
- Tách hai nút "trang để đọc" và "tệp để nhập": một tệp làm cả hai.
- Hỏi trước về ảnh: ảnh luôn đi kèm.

**Cách dùng**
- Chủ đề "Chia sẻ" có thêm các bước gửi, nhận và giữ/gộp thư mục.
- Rà lại các phần lỗi thời:
  - Xếp nhanh;
  - "Thư mục mới" (Pro), thay cho "Bộ sưu tập con mới";
  - widget màn hình chính;
  - thẻ ôn Handy Recall;
  - danh sách Pro.

### Handy Bookmark · nhấn giữ bộ sưu tập, chi tiết hai cột, lề màn rộng (2026-11-09, chủ yêu cầu)

- **Nhấn giữ một ô bộ sưu tập** (hoặc bấm chuột phải trên máy tính): mở bảng nhỏ với "Gửi cho bạn bè", trong đó bộ đó đã được chọn sẵn, và "Sửa bộ sưu tập". Menu "⋯" của bộ sưu tập ở thanh bên cũng có thêm "Gửi cho bạn bè".
- **Gửi bằng link** (dữ liệu nằm sau `#`, trang ở winka.top): chủ quyết định tạm bỏ. Chưa làm.
- **Trang chi tiết một mục trên màn rộng** (từ 840pt, khung tối đa 1200), hai cột:
  - trái: ảnh, tiêu đề, nguồn, Mở bản gốc, Đọc;
  - phải: các nút thao tác, hẹn nhắc, thẻ, ghi chú, chi tiết và công cụ, rồi "Cũng trong <bộ sưu tập>". Nếu mục chưa xếp thì là "Thêm từ <trang>": tối đa 6 mục, bấm để mở thay chỗ.
  - Khung hẹp hơn và khung chi tiết bên cạnh danh sách vẫn là một cột.
- **Lề màn rộng:** dải đầu trang, danh sách và khung chi tiết cùng lề 24 ở cả hai bên.

### Handy Bookmark · bản đọc offline giữ ảnh của bài (2026-11-09, chủ đồng ý)

- **Khi bấm "Lưu bản offline"**, cả từ trình đọc lẫn từ việc lưu nhiều bài một lượt: app tải tối đa 20 ảnh trong thân bài, mỗi ảnh thu nhỏ còn tối đa 1280 px, tổng 10 MB, trong tối đa 45 giây. Ảnh lỗi thì bỏ qua, chữ vẫn được lưu.
- **Trình đọc:** hiện ảnh đúng chỗ trong bài, bo góc như thẻ, có mô tả cho trình đọc màn hình. Khi đọc trực tuyến thì không hiện ảnh.
- **Dòng chữ** ở phần Bản đọc offline đổi thành "Giữ chữ và ảnh của bài (tối đa 20 ảnh)…".
- **Ảnh nằm trong bản đọc:** xoá bài thì bản đọc vào Thùng rác cùng bài, và bị xoá hẳn cùng bài, ảnh đi theo. Không có tệp ảnh nào sót lại.

### Handy Boards · đợt sửa theo danh sách của chủ (2026-11-10)

- **Việc con:** menu "⋯" của thẻ có "Thêm việc con", mở thẻ ở đúng ô và bật sẵn bàn phím. Chi tiết thẻ có nút "Việc con n/m" cạnh Hạn, Lặp lại, Ảnh bìa. Chủ chọn giữ việc con, không làm thẻ con lồng nhau.
- **Kéo thẻ:** cột sẽ nhận thẻ có nền pha 14% màu cam đất và viền 2pt, có chuyển động. Cột của chính thẻ đó không sáng.
- **Kéo cả cột:** nhấn giữ đầu cột, cột đích sáng lên giống khi kéo thẻ, thả xuống là dời cột tới chỗ đó. Gần mép màn thì bảng tự cuộn.
- **Thùng rác:** tự xoá sau 30 ngày như Bookmark. Mỗi thẻ ghi "còn N ngày"; mở app là dọn thẻ đã hết hạn.
- **Công tắc "Thẻ ở đây là đã xong":** giữ lại (chủ chọn), có thêm dòng giải thích bên dưới.
- **Nhãn Pro** trước khi bấm, chỉ hiện với người chưa có Pro:
  - Boards: Bộ lọc, Mẫu thẻ của tôi, nhóm Tự động hoá;
  - Bookmark: Thiết kế bản xuất, Chép chữ trong ảnh, Đánh dấu.
- **Ngày quan trọng có giờ** (không bắt buộc, lưu dạng `HH:MM`). Dòng dưới tên bảng ghi "Thi 3/12 lúc 8:30, còn 3 ngày"; đúng ngày thì đếm giờ. Trong bảng sửa, mỗi mốc nằm trên 2 dòng (tên rồi đến ngày và giờ).
- **Bảng đã lưu trữ có trang riêng:** ảnh bìa, số thẻ xong và đang mở, các nhóm, mốc gần nhất, ngày lưu trữ (từ nay app ghi lại) và lần sửa cuối, kèm Khôi phục và Xoá vĩnh viễn (hỏi lại trước khi xoá).
- **Thiết lập mẫu:** mọi ô của 30 mẫu có khung "Trên bảng: …" với câu trả lời hiện tại. Câu này sinh theo vai trò của ô: tên, nhóm, ngày quan trọng, cột tuỳ chọn, bộ cột, cách hiện thẻ, khoảng thời gian, thẻ ví dụ.
- **Lỗi:** lưu ngày quan trọng không còn ra màn đỏ (bảng tự quản lý các ô của nó).
- **Cách dùng** của cả hai app cập nhật theo các mục trên. Màn chào giữ nguyên, vì phần luyện kéo thẻ đã có hiệu ứng sáng cột.

### Handy Bookmark · danh sách dài có giới hạn, kiểm tra link mỗi ngày (2026-11-10, chủ yêu cầu)

**Việc của màn.** Khi có rất nhiều bộ sưu tập hay thẻ, những thứ nằm sau danh sách (Thẻ, Nâng cao, nút Bộ sưu tập mới, nút Gửi) vẫn phải ở gần. Link không còn mở được phải nhìn ra ngay mà không bị xoá.

- **Giới hạn hiển thị**, phần còn lại mở tại chỗ bằng "Xem tất cả N" (và "Thu gọn"), có chuyển động co giãn:
  - thanh bên: 8 bộ sưu tập, 12 thẻ. Bộ hay thẻ đang mở nằm sâu hơn thì danh sách tự mở hết;
  - trang Thư viện trên điện thoại: 6 ô bộ sưu tập, ô "Bộ sưu tập mới" ngay sau;
  - bảng chia sẻ vào app: 6 bộ vừa nhận đồ gần nhất; hàng "Chưa xếp" (bỏ ra khỏi bộ) lên đầu;
  - hộp "Chuyển vào": 8 bộ;
  - danh sách dài hơn giới hạn đúng 1 mục thì hiện hết, không có nút "xem thêm 1".
  - "Tất cả bộ sưu tập" trên màn rộng: Gửi và Nhận nằm trên lưới.
- **Kiểm tra link mỗi ngày:** chạy ngầm 1 lần/ngày, 20 giây sau khi mở app, rồi xem lại mỗi giờ. Mỗi lần tối đa 60 link: link chưa từng kiểm tra trước, rồi link kiểm tra lâu nhất; bỏ qua link đã kiểm tra trong 7 ngày. Không có thanh tiến độ. Chỉ báo khi tìm ra link hỏng ("Xem link hỏng"). Người dùng tự bắt đầu một việc khác thì lượt ngầm nhường ngay.
  - **Mất mạng:** chưa trang nào trả lời thì không ghi "không mở được"; 5 lần liền không ai trả lời thì dừng, giờ sau thử lại.
  - **Công tắc** ở Cài đặt › Công cụ thư viện nâng cao. Mặc định theo "Đọc trang sau khi lưu" (tắt cái đó là không liên hệ website nào); không có trên web.
- **Kiểu riêng của link hỏng**, không bao giờ tự xoá:
  - ảnh xám, mờ 50% ở mọi nơi hiện ảnh (thẻ, hàng, bố cục Pro);
  - góc ảnh có nhãn chữ kèm biểu tượng: "Không còn" (biểu tượng màu cảnh báo), "Không mở được", "Đã chuyển" (trang chuyển chỗ vẫn mở được nên không bị xám);
  - dòng danh sách vẫn ghi trạng thái ở đầu dòng như trước.

### Handy Boards và Handy Bookmark · onboarding (2026-11-10, chủ yêu cầu)

- **Boards, trang đầu là câu chuyện** (khôi phục cảnh cũ đã bị bỏ khi làm hai nhánh Học tập/Công việc), không hỏi gì:
  - nhịp 1 "Việc nằm khắp nơi. Rồi rơi mất.": ghi chú, tin nhắn nhóm lớp, giấy nhớ, lịch nằm lung tung; nút "Gom về một bảng";
  - nhịp 2 "Một bảng cho tất cả.": các mẩu bay về một bảng thành thẻ có nhóm; nút "Chỉ tôi cách dùng". Nút Quay lại (và phím back/Esc) đưa về nhịp 1 trên cùng trang.
- **Bỏ trang chọn Học tập/Công việc.** Bảng luyện tập luôn dùng ví dụ môn học; câu chữ nói nhóm là "thẻ thuộc về gì (một môn, một mảng việc)".
- **Trang cuối là "thời gian"** (chủ chọn hướng A, thay cho trang chọn mẫu): "Việc chưa xong không bị bỏ quên." Cảnh động: dải 7 ngày, ô sáng trượt từ T2 sang T3; thẻ "Ôn chương 3 Toán" chưa xong bay từ cột Hôm qua sang Hôm nay, kèm nhãn "Đem sang hôm nay"; thẻ đã xong ở lại; cuối cùng mốc "Thi Toán · còn 3 ngày" hiện dưới tên bảng. Chỉ một nút "Bắt đầu" (xem lại từ Cài đặt thì là "Xong"), dẫn về Trang chủ, nơi khối "Tạo bảng đầu tiên" có Mẫu và Bảng trống. Mục đích Học tập/Công việc chỉ còn trong Cài đặt.
- **Bookmark, bước tìm app trong bảng chia sẻ của máy:** trên hàng app có ngón tay vuốt từ phải sang trái kèm vệt và mũi tên ‹ (4 lần rồi nghỉ; giảm chuyển động thì đứng yên giữa đường). Cuối hàng có vùng mờ dần và nút › màu mực: bấm để dời hàng (chuột không vuốt được), tự ẩn khi đã tới cuối.


## Handy Habit · run 3b visual contract · 2026-11-10

This refines R5/R6 presentation before code. Jobs, routing, persistence and tracking stay as specified below.
- Data/jobs: daily personal check-ins on phone/desktop; six due habits, one completed, five remaining, two routines in the existing fixture. Each habit owns saved icon/colour, target/unit and recent day states. All totals use the engine, never demo constants.
- Today question: What have I kept today, and what can I do next? Finding: completed / due beside the editorial greeting. Signature: larger habit-coloured bead strings ending in the 48px one-tap today bead; filled done, partial progress ring, quiet hollow missed, neutral paused mark. Unknown/default completion glyphs are identity dots, never leading completion ticks. Explicit recognised appearance icons retain their saved colour; no data migration.
- Face/palette: Nunito throughout, warm oxblood anchor and vermilion progress, ochre secondary accent on the date/progress caption. No copied header band. Light: canvas #FAF7F2, surface #FFFFFF, raised #F1E9DF, ink #291C19, muted #66534C, anchor #54261F, vermilion #B42318, tint #F9E4DC, ochre #805500, ochre field #F5EBCF. Dark independently tuned: canvas #151312, surface #211D1B, raised #302824, ink #FFF5ED, muted #CCB9AC, anchor #F1C5AF on #54261F, vermilion #F07755 on #32150D, tint #42271F, ochre #E6BE70 on #382D18. Primary actions use anchor; selected editor options use vermilion tint/ink. All normal text pairs >=4.5:1; large text/nontext >=3:1, tested. Habit colour ink adjusts for contrast without changing saved values; filled beads choose contrasting check ink.
- Type scale: greeting 30/700 (28 on phones; 24 base only below240px effective width at enlarged text, still36px at150%), section titles 21/700, habit titles 17/700, body 15.5, secondary 14, labels 15/600, buttons 16/700. Bundle Nunito 400/500/600/700 with Vietnamese; theme and component text styles explicitly inherit it.
- Responsive: 320/390 one scroll column, greeting/ring inline only when text fits, otherwise progress below; first today bead in top60% of phone. At 1440, habits left (about600px max) and routines/review/next reminder right; sidebar still folds. Large text wraps controls and preserves 48px targets; editor remains scrollable, keyboard-safe and capped560px. No fixed-height text containers.
- States/accessibility: preserve empty/create, paused/end early, loading, save failure/retry, conflict, dirty editor guard and disabled/busy behavior. Ring semantics state completed/due; paused/skipped never count as kept. Bead semantics and hold-to-edit remain. Focus/keyboard/Back routes and reduced-motion kit feedback remain.
- Reject: default teal ticks, black dots for history, pink dark brand hue, red missed days, black Save/Start, low-contrast helper text, 900px habit rows, generic KPI cards, saturated navigation, gradients, decorative icon boxes. Brief-authorized exceptions to app-screens defaults: editorial greeting and habit-coloured appearance/beads are the product identity; primary anchor and coloured selected form controls follow the owner's explicit request.
- Finish gate: render EN/VI x light/dark x320/390/1440 x1/1.5 using tool/screens_test.dart, inspect actual Nunito screenshots against app-screens §2.7, fix and re-render; host evidence only.

## Handy Habit · R5/R6 implementation contract · 2026-11-10

This extends the Habit contracts below before implementation; other apps are unchanged.
References inspected: Bookmark `shell/save_shell.dart`, `shell/sidebar.dart`, `ui/capped.dart`;
Boards `shell/boards_frame.dart`, `card/card_sheet.dart`; both required UI skills and app-screens §2.7.
Retain editorial-greeting, Nunito and vermilion; the single signature remains today's actionable bead.
Real fixtures: 6 due habits, 1 completed, 5 remaining, 2 routines; counts come from the engine.

- **Shell question:** Where do I check in, run a routine, or review progress? Three destinations
  Today/Routines/Progress, with all habits one tap from Today. Phone <600 bottom navigation;
  600–839 stays one pane with the same navigation; ≥840 sidebar224 folding to rail64 using
  HandySidePanel/HandySideRail. Fold at sidebar top, reopen » at rail top, remembered setting;
  Settings/Help at foot. Neutral selected navigation, product name/mark, contextual Add.
  Named hash routes and existing detail routes coexist; unknown route/ID offers its parent.
  Back/Esc closes one level; Ctrl/Cmd N/F/comma/1–3 do not intercept typing.
- **Today question/finding:** What remains today? Greeting/date and real remaining count, then
  a compact active-run line, then beads beginning in the first60% at320/390, including text×1.5.
  Habit group is inferred from its reminder or linked routine time (morning<12, afternoon<18,
  evening otherwise); explicit Advanced override wins, and untimed habits remain ungrouped.
  Cap6 habits and2 routines, Show all N expands in place and can fold. Routine Start remains on
  the row; weekly review follows habits, never before them. Wide: habits left, routines/review
  right, aligned gutters16/24. No forced dashboard tiles, red missed days, or greeting over32px.
  Empty/no-due/paused/all-done remain distinct; load and durable-save failures keep existing data.
- **Editor question/finding:** What, how much, how often, and from when? Basic first; existing
  Advanced values/options and appearance remain editable and preserved. Explicit day-part
  override is Advanced. Save is primary, fixed above keyboard; Cancel/Back/Esc/barrier exit
  asks about unsaved changes only after values actually differ. Busy blocks exit/double save;
  failure retains draft. Effective schedule date and history-preservation explanation stay visible
  on edits; historical targets are read from the schedule effective on each historical day.
- **History question/finding:** Which days were recorded and against what target? Calendar,
  current/best and schedule history retain the engine's dated targets. Recorded entries start
  at30 then Show all N in place, reversible, with full notes/provenance and historical goal.
  Empty records have a sentence; archived/deleted/missing dates remain neutral and truthful.
  At narrow widths or large text, metrics become aligned label/value rows; the month offers
  a day-list view with48px rows and dated targets, capped7 with in-place Show all. Calendar
  remains available; the list is the default when seven48px columns cannot fit or text is enlarged.
- **Clock policy:** Existing v3 midnight policy gains validated boundaries0–1439minutes. New
  versions are effective at an instant; choose policy by instant then compare local wall-clock
  minutes, including DST. Events retain their stored local dates forever. A settings change
  records a new policy rather than re-bucketing old history. Existing v1/v2/v3 backups roundtrip.
- **States/motion/accessibility:** Existing load recovery and write-error paths remain. Stable
  keyed rows, HandyAppear for arrivals, HandySwap for changed status/areas, HandyReveal for
  disclosures. No commit waits for animation; OS/app reduced motion gives zero durations.
  Labels, state words/shapes and ≥48px bead controls accompany colour; text wraps at320,
  EN/VI/light/dark/text×1.5. Keyboard focus follows route/guard. No new permission prompts.

Visual gate: render real Flutter screenshots at320/390/1440 in EN/VI/light/dark/text×1.5;
inspect §2.7 hierarchy, shared edges, colour, arithmetic, neutral missing values, legends and
phone navigation; fix the three largest issues and re-render. Host screenshots/widget routes
are evidence, not browser URL/back-forward, device, screen-reader or store verification.

**R5/R6 visual critique, app-screens §2.7:** inspected the full24-configuration matrix
(5 screens each), the existing screenshots/16-frame film and fold/history/dirty extras.
The largest issues were the first bead pushed down by secondary content, ragged history
figures/oversized calendar rows, and wide trailing Progress durations/clipped chart labels.
Fixed: habits first and compact greeting/run/header; aligned metric rows and48px calendar/day
list; wrapping duration labels and fewer, unclipped axis labels. Footer aligns with editor fields.
The phone shell keeps the full product name and three destinations; wide edges and section
headers align, with no stretched companion panel. Vermilion marks today's bead/current week;
missed/paused days remain neutral. Remaining5 is6due−1done; review23/32 is engine-derived.
Zero and missing states stay distinct; labels/shapes and semantic day/value/target supplement
colour. Nunito is loaded in every capture; no stock art, invented figures or shared-brand restyle.
Final renders:63 harness cases pass, and27 final matrix/extra cases pass after the compact
calendar adjustment. Native Flutter renders replace the HTML-only DOM inspector here.

## Handy Habit · run 11 · consistency contract · 2026-11-10

Reference: Bookmark/Boards source and host screenshots; this section changes Habit only.
Inventory remains habits/check-ins, routines/sessions, optional mood, local settings and backups.
Nunito, editorial greeting, vermilion/oxblood/ochre and today's bead as the check-in remain the face and signature.

| Screen/job and one question | Primary action/finding | Required behaviour and states |
| --- | --- | --- |
| Shell: where am I, what next? | Today's bead / Start routine | Three phone destinations; add before gear; wide sidebar224/rail64, fold/reopen at top, persist preference. Gutters16 phone/24 wide. |
| Lists/detail: what can I do to this habit/routine? | Check in / Start; name opens detail | Visible 48px More, same menu on row long-press/right-click; destructive confirmation; in-place caps; preserve selection and scroll. |
| Help: how do I do this? | Select numbered topic, read illustrated steps | Drawn real-control fragments in list and detail; search EN/VI without accents, result count/no-match/Clear; article Back/Esc returns to index before leaving; Previous/Next; replay remains available. |
| Mood: how do I feel today? | Tap face to save immediately | Five drawn faces differentiated by expression and label, never colour alone. Two taps from Today, no required note/keyboard; selected state, busy/error/retry, optional details and confirmed delete with Undo. |
| Pushed pages: how do I return? | Visible Back, one level | Sync explicitly renders Back; editors preserve dirty guard; guide and runner retain their specific back semantics. Every pushed route covered by widget navigation checks. |
| Feedback/data: did that save? | Undo after successful commit | Non-persistent snackbars use HandyMotion duration including zero under reduced motion; latest message replaces previous, no Undo for irreversible deletes. Trash says 1 day / N days; reset/replace/delete still confirm. |

Responsive320–1440 and text100/150/200%: scroll instead of clipping; actions wrap, drawings can scale but instructional text stays full size. AA text contrast, labelled face buttons/More controls, logical traversal and Enter/Space activation. Motion uses kit Swap/Reveal/Appear and zero-duration reduced motion. Reject text-only faux pictures, colour-only moods, inaccessible row-only gestures, unconfirmed deletes, indefinite Undo, and browser/device/store verification claims from host renders. Existing empty/loading/error/recovery states remain usable. Pro purchase/live demos are next-run work; existing advanced feature title-right badges remain non-Pro only.

Run11 audit outcome: 22 Habit gaps fixed; see `docs/handy_habit/CONSISTENCY_AUDIT.md`.
Settings order ends Data → Reset → Help → About → HandyMoreApps; Trash counts live below
their label. Search keeps topic numbers. Deleting a row leaves its list open; deleting a
detail returns to that list after commit. Latest feedback replaces queued messages.
Habit-owned menus/dialogs/sheets use HandyMotion, including the pretend practice dialog.
Month day targets and year cells are at least48px; enlarged calendars scroll horizontally
instead of squeezing text. The year view consequently shows fewer weeks at once.
At narrow/enlarged widths bead/More and routine heading/actions stack; today's first bead
still meets its existing visibility check. Shared HandyPage gutters, HandyLabel wrapping,
HandyMenuButton sizing and shared confirm/message motion remain supervisor follow-ups.

## Handy Habit · run 13 · R19/R20 and Pro contract · 2026-11-10

- Inventory: civil habit days, dated daily/weekly goals, pauses, unknown/conflicted
  records, collections, inferred/explicit day parts, optional mood, verified store
  ownership, Nunito, vermilion, bead strings. No external inference service.
- Pro question: what changes in my daily use? Large pay-once headline and one plain
  sentence, selected disposable live demo first, Replay, drawn row thumbnails under
  Routines / Understand / Make it yours. Footer pins Restore + Get Pro with live
  store price, status/retry and honest unsupported/unconfigured text. Preserve every
  run12 billing state. Sibling evidence: Boards Pro structure and run12 sibling PNGs.
- Insights question: what small adjustment does my history support? Finding first,
  month/quarter comparisons with explicit elapsed windows and denominators; groups
  by day part/collection; explained difficulty and weekday slips; accept/dismiss
  suggestions effective tomorrow; mood co-occurrence with paired-day counts, minimum
  14 paired days, never causal language. Empty/insufficient data say why. Free core
  Progress stays intact; short pretend preview and Pro badge lead to real upgrade.
  Advanced heatmap filters compose habit/collection/day-part/direction/weekday/status.
  Designed PDF preview shares the same engine figures and explains exclusions.
- Studio question: how will Today feel? Disposable live preview of Habit palettes,
  Today spacing/layout, Material icon extras and runner look. Free previews; verified
  Pro checked again at apply. Cancel/Back writes nothing. Persisted choices survive
  entitlement loss, with default rendering until verified Pro returns. Existing free
  light/dark, density, colours/icons remain free. Widget appearance only if native
  adapter supports it; otherwise explain its current fixed system appearance.
- Responsive: 320/390 single scrolling column, wrap controls and footer actions;
  1440 centred max920 content, optional side-by-side preview/details. Text1/1.5 never
  clips; 48px targets, labelled replay/filter controls, keyboard Tab/Enter/Esc,
  native Back and named /pro, /progress/smart, /settings/studio routes on all targets.
  Reduced motion shows final demo immediately; no endless timers. Light/dark text
  contrast >=4.5:1. Signature remains the bead string, never a second chart gimmick.
- Reject: top Buy interrupting demo, text-only benefit list, causal/medical claims,
  invented real-user figures, unknown-as-miss, changing historical targets, themed
  identity colours rewriting habits, locked backup/export/core Progress, fake price.
- Evidence gate: host EN/VI × light/dark ×320/390/1440 ×text1/1.5; critique, fix and
  re-render against sibling Pro images; separate host/build from device/store QA.

## Handy Habit · run 12 · R21 contract · 2026-11-10

Contract before code. References: run11 sheets 01/02, Boards home/how-to/pro and
Bookmark pro source. Inventory: 19 help topics, habits/check-ins, saved routines,
nine shipped Advanced routine capabilities, verified store ownership and local price.
Keep Nunito, vermilion/oxblood/ochre, editorial greeting and the today-bead signature.

- Help asks “How do I do this?” Replay introduction card first (icon/title/one-line
  practice description), search, Topics, then soft-square icon/title/summary/chevron.
  No numbering, including filtered results. Drawn previews stay in articles. Search
  empty/no-match, article/back/replay all retain existing mechanics. The explicit
  sibling-matching icon-square requirement overrides the skill's general icon-box ban.
- Shell asks “What can I do today?” Mark + app name on phone, destination name beside
  the wide sidebar (whose identity uses the same real mark). Today and Routines have
  labelled New habit / New routine floating actions; secondary Add menu retains other
  creation and pause actions. Progress stays a reading destination. Settings and pushed
  pages keep their title, back and responsive content heading; no duplicate identity.
- Pro asks “What does this purchase add?” A live, replayable Advanced routine demo
  leads, feature selection changes the stage, then Free/Pro comparison and purchase.
  Existing rules/choices/dependencies/stacking/durations/blocks/presets only are sold.
  R19 insights/R20 looks remain open and explicitly coming later, outside purchase claims.
  Tracking, negative habits, routines/runner, templates, core progress/heatmap, mood,
  exports and backup/restore/sync remain free. Existing Advanced routines run without Pro.
- Purchase states: price loading/absent, ready with store price, pending, purchased,
  restoring/no purchase found, cancellation, error, offline (cached verified owner kept),
  unconfigured Android and unsupported Web/Windows/iOS. Buy requires a live store price;
  Restore and Retry are explicit; busy/pending prevent duplicate requests. No static price,
  fake checkout or entitlement in user backups. Settings includes Pro status/Buy/Restore.
- Responsive: 320/390 single scroll column; 1440 centered max720 Pro, max960 Help with
  article beside index. Text1/1.5 wraps titles/status/actions without truncating prices;
  purchase panel stays in scroll content to remain reachable on short/enlarged screens.
  Help index centers at max720; only a selected article opens the max960 two-pane layout.
  FAB reserves list-bottom room. All controls ≥48px, semantic headings/live status,
  keyboard focus/Enter and Back/Esc; named /pro?feature= routes survive deep links.
- Motion: kit swap/reveal and finite demo transitions, explicit Play again, no auto-loop;
  reduced motion shows the explanatory final frame. Demo writes only local pretend state.
- Verify EN/VI × light/dark ×320/390/1440 ×text1/1.5, all purchase states and sibling
  equivalents in sheets; critique, fix and re-render. Raster evidence is host-only.

## Hợp đồng bổ sung: Handy Habit · run 1 · 2026-11-10

**DESIGN CONTRACT — chưa triển khai.** Phần này thay chỉ dẫn Habit cũ về onboarding3 choices/bốn khu/top switch/Lite Pro/không sửa appearance/history cắt; không đổi hợp đồng app khác. [AUDIT](HANDY_HABIT_AUDIT.md) ghi source/evidence; [PLAN](HANDY_HABIT_PLAN.md) ghi models/Free–Pro/slices. Không đọc “xong”02/11 như chứng nhận MASTER PROMPT này.

Đã đọc hai skill tại C:/Users/Winka/.claude/skills/design-taste-frontend/SKILL.md + references/app-screens.md và frontend-ui-engineering/SKILL.md. Giữ editorial-greeting/Nunito vì dùng nhanh nhiều lần/ngày. Face: lời chào+fact thật. **Signature duy nhất: tràng hạt, hạt hôm nay chính là nút check-in.** Routine time strip là thông tin chức năng, không motif trang trí thứ hai. Draw mới bị EPERM/Node20<22; giữ style đã duyệt/seed lịch sử973037815, không claim deal/inspector mới.

### Inventory dữ liệu và jobs — app-screens §2.1

1. Habit: name/type/unit/target milli/versioned schedule/start-end/group/priority/identity/archive-trash; thường3–12, scale tới500.
2. Check-in: local day/delta/manual total/skip/note/provenance/revision; vài lần/ngày, lịch sử nhiều năm.
3. Negative: incident/budget ngày-tuần/observed zero≠unknown; không reversed checkbox.
4. Routine:1–5 routine,3–8 steps,5–40 phút; schedule/time/minimum/required/canSkip/link, giữ dữ liệu cũ.
5. Session: snapshot/cursor/current-total/elapsed-remaining/pause/recovery/summary;1active/máy.
6. Mood:0hoặc1/ngày/mood-energy1–5/optional note-tag; không prerequisite để hoàn thành ngày.
7. Stats: eligible/completed/current-best/range/planned-actual; có ghi≠đạt.
8. Data safety: schema/counts/bytes/date/destination/last success-error/next eligible/pending-conflicts/provider.
9. Người dùng mở phone vài giây để đánh dấu, sáng/tối chạy routine; desktop chỉnh nhiều/xem tuần.
10. Jobs: check-in→resume/start→Undo/backfill→create-edit→review→backup, không thêm việc để lấp chart.

Dùng fixture existing tool/screens_test.dart:practice() và test/ui_test.dart:6 habits/2 routines ngày02/11/2026, Today6due/1done/**5còn**, review23/32. Các con số từ cùng engine projection, không hardcode trong view; future fixtures assert sums/ranges/units. Demo không production seed hoặc telemetry.

### Quy tắc chung R / A / P — mọi màn đều kế thừa

**R responsive320–1440:**320–599 một cột/gutter16/targets≥48/body16/subline≥12/title24–32, text200% wrap/scroll, keyboard không che Save.600–839 một pane nếu mỗi pane<340.≥840 sidebar224 gập rail64 qua HandySidePanel/SideRail;≥1100 list/detail khi đủ.1440=224 sidebar+48gutters+1168 canvas; Today744+24+400. Editor/help max720, paywall800; không kéo panel ngắn tạo void. Overview cap4–6 rồi **Xem tất cả N** mở tại chỗ, không chỉ trỏ export. Một hệ edges/gaps16hoặc24.

**A a11y:**semantic heading/focus order theo job/visible focus/Tab-ShiftTab-Enter-Space; return focus trigger khi đóng. AA4.5:1text/3:1large-control; disabled đọc được+reason. State có chữ/shape, không chỉ màu. formatFigure/tabular digits, pickHandyDate/adaptive time picker. Bead label đủ name/day/value/target/state/action; chart có text/table equivalent. Timer không announce mỗi giây; busy/success/error semantic sau commit, không cướp focus. Refresh giữ data cũ. Reduced motion OS hoặc app→duration0, haptic/sound không bắt buộc.

**P platform:**named routes PLAN/hash strategy #/..., chưa claim server-path refresh trước browser test. Android Back/iOS swipe/Esc một cấp, dirty editor hỏi discard, saved không hỏi. Ctrl/Cmd N thêm/F tìm/comma Settings, Ctrl1–3 khu; input không bị shortcut chiếm. Dialog focus trap, OS picker cancel không lỗi. Phone3 destinations Today/Routines/Progress/gear cố định; desktop sidebar Settings/Help. Legacy habit/routine/run/session/settings routes giữ, ID thiếu có message+parent; browser Back/forward/scroll phải verified riêng.

**Identity/motion:**Nunito 400/500/600/700 thật/VI đầy đủ. Light ground#FAFAFA/surface#FFFFFF/field#F1F1F1/ink#211F1E/muted#66615F/control#D3D0CE/accent#B42318. Dark riêng ground#151414/surface#201E1D/raised#2B2827/ink#F6F3F1/muted#C0B6B2/control#817773/accent#FF897D; kiểm contrast trước chốt code. Radius18 panel/12control, spacing4/8/12/16/24/32. Không gradient/glass/resting shadow. HandyPalette dots stable theo ID, icon trung tính; giữ raw legacy icon/color và appearance Free qua display adapter, không rewrite khi render. Missed luôn xám/mực, không đỏ; red cho current bead/step/primary hoặc lỗi thao tác. HandyMotion/Swap/Reveal cho state-size, Appear chỉ item mới, không entrance kéo dài; commit không chờ animation, reduced=0.

### Today / Hôm nay

- Job/câu hỏi: **Hôm nay còn gì đánh dấu ngay?** Finding: due remaining hoặc active run2/5một dòng Resume; fixture5còn. Primary hạt hôm nay: binary1tap/count+1/quantity-duration sheet; full bead sửa ngày, long-press có lối tương đương; Undo sau commit. Negative Ghi lần, zero action riêng.
- R: greeting/date→active compact→habits→routine cap2→review1 dòng/mood optional; first bead top60%phone, cap6/Show all tại chỗ; wide habits trái/secondary phải. Group buổi chỉ khi hữu ích.
- States: first-empty Tạo+optional goal chips sau guide; no due khác all done; paused neutral/End early; loading frame; load error Retry/restore không reset; save fail giữ committed number/Retry; conflict Cần xem lại. Permission không hỏi, denied chỉ in-app next reminder.
- A/P: semantic bead48px/state shapes, /today, Tất cả→/habits, N thêm, back giữ scroll. Reject hero/KPI tiles, red missed, routine-review đẩy check-in xuống, ads xen hạt/mood mandatory.

### Habit create/edit

- Job/câu hỏi: **Việc gì, đo sao, bao lâu một lần?** Finding preview “Đọc10 trang/mỗi ngày”, edit ngày hiệu lực rõ. Primary Lưu. Name/type/goal/schedule trước, negative measure-threshold-window; Advanced start/end/group/priority/interval/quota thu gọn nhưng giữ controller/legacy choice. Standard schedules Free.
- States blank/preset; validation cạnh field+first-invalid focus; save busy chống double tap; error giữ draft; type/unit locked giải thích/Duplicate; cancel/dirty back guard; permission N/A, chỉ xin sau explicit reminder enable.
- R:320fullscreen/scroll/Save né keyboard/chips wrap;768max720;1100+preview nếu panes≥340. A/P labels thật/locale numeric/date-time picker; /habit/new, /habit/:id/edit, Ctrl-Cmd S valid/Esc guard. Reject raw ISO-HH:mm-weekday string, Advanced bắt buộc, tự đổi legacy values, khóa màu/icon đang Free.

### Habit detail/history

- Job/câu hỏi: **Đều ra sao, sửa ngày nào?** Finding completed/eligible và streak đúng đơn vị/segment. Primary chọn ngày xem/sửa total; Edit secondary. Month+legend/current-best/goal history/log30 rồi Xem thêm50tại chỗ.
- States no log/missing/future/not scheduled/skip/pause tách; loading giữ month; error inline Retry; archived/trash read-only+Restore; outside backfill nói giới hạn; permission N/A.
- R/A/P:320single/calendar không tiny35buttons,768giữ text scale,≥1100list-detail với route selection; daily semantic/text list, arrows/Enter; /habit/:id, Back đúng filter-scroll. Reject history cắt rồi export-only/red missed/ghi khi chỉ xem.

### Routines list

- Job/câu hỏi: **Chạy gì, mất bao lâu?** Finding active hoặc routine kế tiếp/duration. Primary Start/Resume ngay row, New secondary khi đã có.
- States empty giải thích+Create/templates; loading rows; start fail không half-session; archive/trash riêng; đã active thì Resume hoặc xác nhận dừng trước start mới; permission N/A, Start không xin nhắc.
- R/A/P:320Start wrap/active+4 routines/Show all N, recent4mở thêm;768one pane;≥1100list400/detail còn lại. Semantic name/time/steps; /routines,/routine/:id, keyboard Start/Back đúng row. Reject templates chen trước user data/Start cần detail/template title làm ID.

### Routine builder — Basic/Advanced

- Job/câu hỏi: **Các bước thành buổi chạy hợp lý chưa?** Finding5 steps/18 phút hoặc lỗi đúng link-step. Primary Lưu toàn draft, không tạo routine rỗng rồi save mỗi bước.
- Basic name/steps/reorder/duration/link, schedule/details disclosure; minimum/priority/required/canSkip cũ giữ Free. Advanced mode rõ, badge cạnh title cho non-Pro, preview không write.
- States empty Add step/loading draft/cycle-ref-duration validation/stale compare-reload/error giữ draft/archived link inactive; permission N/A.
- R/A/P:320linear/rule form thay graph, drag có Up/Down;768max720;≥1100preview; /routine/new,/routine/:id/edit, Ctrl-Cmd S/dirty guard. Reject mandatory graph/code expression/drag-only/half-save/import tự chạy rules.

### Runner / summary

- Job/câu hỏi: **Bước gì, còn bao lâu, tiếp thế nào?** Finding current/total/running-paused-recovered. Primary Xong bước; Pause/Resume/Skip secondary, required/canSkip giải thích.
- States initializing; untimed rõ; elapsed/remaining nhãn riêng; done transition+exactly-once link; final planned-actual/skips/credited habits; save fail giữ bước/Retry không double-credit; recovery paused+estimate; missing/deleted link nói rõ không event giả; denied notice không chặn runner.
- R/A/P:320fullscreen/no nav-sidebar/controls wrap không che nội dung;768–1440focusmax800, overview phụ khi đủ. Timer lớn vì job chính/tabular, SR không đọc mỗi giây; Space pause/Enter done ngoài input; /run/:id,/session/:id. Back pause-save rồi leave, abort confirm riêng; background persist pause trước notice/resume explicit. Reject killed-background auto-complete/countdown không nhãn/Previous xóa edited event/noisy sounds/animation delay.


### Progress / Tiến bộ và weekly review

- Job/câu hỏi: **Nhịp nào giữ được, nên đổi gì?** Finding completed/eligible và so kỳ cùng độ dài; review23/32là fixture. Primary chọn tuần/habit; Làm nhỏ lại chỉ khi có evidence.
- Review→month-year heatmap→habit/routine stats; core và reports hiện có Free, Advanced riêng. N/range/unit/unknown/pause/conflict rõ; có ghi≠đạt, correlation≥14 paired days và không gọi nguyên nhân.
- States empty0axis/missing dash, loading giữ data khi refresh, aggregation/export error Retry giữ range, permission N/A/file cancel riêng; Pro preview không chặn core.
- R/A/P:320một control row/chart160–200, year chia tháng-quý hoặc scroll trong frame;768hai block khi đủ;1440chart2/3+finding1/3, không KPItiles. Chart/table equivalent/cell keyboard label; /progress?range/filter,/progress/week, Back giữ range. Reject fake insight/missing=0/paused=miss/export cũ paywall/medical claim.

### Templates / starter collections

- Job/câu hỏi: **Mẫu nào vừa sức, sẽ tạo gì?** Finding target/schedule/steps/duration thật. Primary Dùng mẫu→customize→Save; preview không write.
- Giữ32 habit/8 routine, search EN-VI không dấu/categories/featured ít/recent picks local, goals optional. Thêm thiếu nutrition/relationships/finance/reduction/recovery/weekend chọn lọc sau model, không chạy đua số lượng. Mẫu có title/explanation/icon/dot/realistic target/schedule; advanced premium badge trước dùng, core Free.
- States initial search/no match+Clear/local catalog loading/error vẫn Tự đặt; similar item cho thêm bản riêng, không overwrite; canceled edit không data; permission N/A/reminders off.
- R/A/P:320list-previewfullscreen;7682 columns nếu item≥300;1440list+preview/cap collections Show all; semantic selection, F search/Enter preview/Esc catalog; /templates?kind=habit,/templates/:id. Reject32chip wall/trăm mẫu rỗng/Use tự ghi/copyright art/mandatory goals trong guide.

### Handy Habit R8/R9 implementation contract · run 5 · 2026-11-10

- Run 5b visual finish: guide titles 30px phone / 44px wide with wrapping tinted key words, body 16–18px; story picture occupies remaining height and action stays at foot. Wide: words left, picture right; practice in a phone frame. Scraps drift/fade once, then the same objects move and crossfade into bead strings; reduced motion is immediate. Practice mirrors Today at full size (editorial greeting, kept/due ring, personal bead colours and round check-in); dark scrim cuts out a bright target with glowing edge and adjacent coach. Do it for me stays at foot; small/enlarged layouts scroll content above it. Settings translates zone names and shows current GMT offset; filtered help retains result count and omits topic numbers. No changes to real data or platform claims.
- Inventory: empty first launch, existing personal habits/history, disposable water count and tiny routine, local preferences, actual reminders/backups. No new domain schema. Nunito, oxblood actions, vermilion ring and habit beads remain the face/signature.
- Guide question: where do my intentions go, and what do I tap? Finding: the same water/read/move intentions fade separately then become bead strings. Stage 1 has two animated beats, no question. Stage 2 uses an isolated local practice model with no controller/store/backup reference: bead, Undo, change goal 3→8, start routine, finish step, observe ring. Spotlight window and adjacent instruction, full-size controls on phones, framed phone on wide screens. Stage 3 shows a hollow missed bead and 6/7 consistency; current streak restarts honestly, best and past days remain. One content button Start. Persistent Back/Skip/progress; Back/Esc/system back undo microsteps/beats, Enter invokes primary/Do it for me. Reduced motion preserves final stills.
- Guide states: fresh/beat/practice/done/flag-save-error. First completion changes only onboarded; replay changes nothing. Existing data or old onboarded flag bypasses guide. Empty Today offers optional goal chips opening editable templates, never saves on selection.
- Help question: how do I do this task? Finding: numbered topics and steps with UI-matching drawn fragments. EN/VI accent-insensitive search, no-match/clear, contextual /help/streaks, /help/pause, /help/reminders, /help/backup; replay /welcome. Coverage follows shipped features, with honest web/native and backup-migration notes; no sync/purchase claims.
- Settings question: what is selected and how do I change it? Values below labels, sections Appearance/Habit preferences/Routines/Notifications/Data/Help/Privacy. Only wired controls, transactional persistence and visible failures; reset preference allowlist preserves library/history/reminder rules/onboarding/purchases. Keep shared auto-backup, sealed restore, MoreApps. Hide unfinished Pro purchase/sync and avoid badges on free controls; title-right badge only for an actual Pro feature when non-Pro.
- Responsive: 320/390 story fills remaining space at normal text; content scrolls above fixed footer at enlarged text, 48px targets, no fixed text heights; 1440 guide words left/picture right capped1180, help index/article and Settings groups capped960. Enlarged text wraps; practice remains real size and scrollable, coach cannot cover target. Empty/loading/error/denied states retain actions. Mock pictures may scale as illustrations, instructional text never does. Keyboard focus, semantic progress and result count; route Back returns to caller. No permission request on launch/help/replay; explain why before explicit reminder opt-in.
- Reject: seeded guide data, goal chooser on first/last stage, tiny practice screenshot, red missed days, generic purchase panel, inert toggles, unsupported platform claims. Verify EN/VI × light/dark ×320/390/1440 ×1/1.5 for beats/stages/practice/help/Settings; critique app-screens §2.7 then fix and render again. Host evidence only.

### Onboarding / story và practice

- Job/câu hỏi: **App giúp gì, chạm đâu?** Finding ý định bị quên→hạt hôm nay làm được ngay. Primary theo beat; practice thao tác thật trên demo; cuối Start/Bắt đầu.
- Stage1 hai beat: ý định đọc/uống nước/giãn cơ rời rạc→gom tràng hạt hôm nay. **Không question/purpose/profile/goal picker trang đầu.** Cùng objects chuyển state, Habit's palette/Nunito, không library teal/board terracotta; motion0vẫn hiểu.
- Stage2 pretend Today/runner controller memory, không nhận store/controller thật/autoBackup/sync/widget. Spotlight window+word beside target: bead→Undo→goal demo→Start routine→Done step→progress. **Do it for me/Làm giúp tôi** làm đúng microstep; Back lùi microstep. Demo không statistics/backup thật, SR có thao tác tương đương.
- Stage3 dạy thêm “Một ngày nghỉ không xóa hành trình”, hình dải nghỉ và đường Settings→Backup/How to. Nội dung **một nút Start**, không picker/chooser/chips; Back/Skip vẫn navigation bar. Start/Skip chỉ guide flag local→empty Today, goals/starter chips optional ở đó.
- States fresh/beat/practice/done/saving flag/error Retry giữ stage; permission N/A, không notification request; returning đã onboarded không force update; replay reset demo không domain write/reset prefs. No ads.
- R/A/P:320progress+Back+Skip cố định, picture scale nhưng text không nhỏ; target visible, coach không che;768stack hoặc panes đủ;1024/1440words-left/scene-rightmax1180, practice có khung phone. Progress stageX/3semantic, mọi stage có Back/Skip; Android Back/Esc/iOS lùi beat/microstep/stage, tại đầu thoát theo Skip; Enter primary hoặc Do it for me lúc practice, không tự kích control khác. /welcome replay về nơi gọi/first-launch về /today. Reject question đầu/chooser cuối/no Back-Skip/permissions sớm/real-data demo/drag-only/wait animation.

### How to use / Cách dùng

- Job/câu hỏi: **Làm việc này sao, vì sao kết quả vậy?** Finding topic đúng query, ví dụ ngày nghỉ không vào mẫu số. Primary chọn topic/step/mở feature; replay prominent secondary.
- Search EN-VI không dấu/aliases, numbered steps+code-drawn mocks đúng tokens/labels thật và highlight vùng thao tác. Topics: create/edit/goals/negative/check-in/Undo/history/streak/missed/pause/routines/runner/timer/recovery/templates/mood/stats/widgets/reminders/Pro/backup/restore/sync/migration/privacy/troubleshoot. Chỉ guide feature đã ship, unsupported có note/alternative. Context help Chuỗi tính sao/Nghỉ ảnh hưởng gì/Sao không nhắc/Sync khác backup mở topic.
- States index/query/results/no-match+clear/topics, loading skeleton, missing topic→index, feature unavailable có reason/alternative; permission N/A chỉ hướng dẫn bật context, không request khi đọc; replay no data writes.
- R/A/P:320onecolumn/mocks scale picture nhưng steps text không scale nhỏ;768max720;1440index+article. Mocks ExcludeSemantics vì steps truyền đủ, results announce/focus/Next-Previous accessible; /help?q=...,/help/:topic; Back query-scroll/context. Reject stale pictures/technical instructions/auto-running feature/help gallery không search.

### Settings / Cài đặt

- Job/câu hỏi: **Đổi cách dùng/bảo vệ dữ liệu ở đâu?** Finding current values/last backup/error theo nhóm. Primary mở nhóm/đổi setting; self-save+quiet saved/error, không global Save.
- Nhóm Appearance(theme/language/density/reduced motion/a11y), Habits(week/clock/default schedule-goal/check-in/streak/negative), Routines(timer/sound-haptic/transitions/confirm/Basic), Notifications(permission/rules/quiet/preview/test/private text), **Data**(Backup-Restore, Sync riêng, Trash/archive, export/integrity/reset preferences/delete), Pro, Help(how-to/replay/FAQ/What's New hữu ích), Privacy/About(local-first/permissions/policy/version-build/licenses/support/safe diagnostics). Chỉ controls đã có implementation, không placeholder.
- Pro badge bên phải feature **title**, chỉ non-Pro; ownership không badge. KEEP HandyAutoBackupSection/openSealedBackup/HandyMoreApps; Pro generic không chiếm gần cả first screen.
- States loading values/save fail rollback value+Retry/unsupported ẩn toggle+alternative/denied status+Open OS Settings trong Notifications; no data vẫn backup-help. Reset preferences giữ habit/log/mood/purchase; Delete all strong confirm nêu hậu quả, ở cuối và có backup path.
- R/A/P:320groups/control dưới title khi dài;768label+control nếu fit;1024/1440group index+page riêngmax960, không scroll-spy dài. Semantic value/title/saved/badge, /settings, /settings/:section; gear/Ctrl-Cmd comma/Back1cấp. Reject dead buttons/toggles giả/copy No cloud sai khi sync bật/schema jargon trong daily flow.

### Backup / Restore

- Job/câu hỏi: **Bản sao an toàn ở đâu, restore thay gì?** Finding last success/date/destination/bytes/schema/error. Primary Sao lưu ngay, khi restore là hành động đúng preview; Free.
- Manual JSON/ZIP compatibility/save-share; encrypted option dùng sealed core/kit/password+confirm/change/lost-password copy, không crypto mới. Auto HandyAutoBackupSection: on-off/daily-weekly/destination/retention3-7-14-30/last/next eligible/error/backup now/sealed; chạy khi mở-rời, không terminated. Auto config local không domain export.
- Pick→bounded/hash/schema/password validate toàn bộ→preview counts/date/schema/conflicts/preference scope→copy-merge remap hoặc replace. Copy-merge nói có thể tạo bản sao, khác Sync. Replace recovery bền trước commit+confirm, stale CAS dừng re-preview; summary/rollback path. CSV là logs cần existing IDs, MD-PDF reports không backups.
- States no backup Create/folder revoked Choose again/full-storage-write fail Retry giữ state-file/canceled picker-password không lỗi/wrong password-corrupt-future-too-large đúng reason/validating-decrypting no double action; permission chỉ lúc chọn folder.
- R/A/P:320counts stack/actions wrap/password không lộ;768–1440max720/metadata dễ đọc/status-focus lỗi. /settings/backup; Back validating cancel an toàn, atomic commit chờ kết quả rõ. Android SAF/cloud document provider; iOS app Files+manual picker; Windows folder; Web manual upload-download, auto unavailable không toggle giả. Reject silent overwrite/off xóa data/settings-only gọi full backup/checksum gọi encryption/password recovery giả/credentials export/Pro gate.

### Sync

- Job/câu hỏi: **Các máy đã khớp chưa, cần xem gì?** Finding last successful/pending/conflict thực. Primary Sync now; off là Bật sau provider/privacy explanation, không account bắt buộc để tracking.
- Provider/account/status/activity/error/pending/disconnect. Android appdata Free chỉ **HANDY_DRIVE_SYNC=true và Android**, flag-off không tile mời login. Windows folder conflict-aware riêng khi làm thật, backup-folder không sync. Chưa iCloud/Web auto-sync thì không hứa. Active timer local.
- States off/authorizing/canceled/idle/syncing/offline/auth-needed/quota/failed/conflict; offline local usable; remote corrupt/future giữ local; conflict candidates có day/amount/source/resolution. Disable/disconnect không xóa local/remote; check-ins không LWW.
- R/A/P:320status/candidates tuần tự;768–1440max800, hai cột chỉ≥340mỗi; text status/announce1 lần/focus resolver. /settings/sync; Back không hủy local commit; consent chỉ explicit enable, revoke/reconnect rõ. Reject success trước durable/upload/file-copy gọi sync/terminated guarantee/sync token-permission-purchase.

### Pro Lifetime / paywall

- Job/câu hỏi: **Một lần trả được gì ngoài Free?** Finding benefit đang xem/demo đúng UI/local store price thật. Primary Mua Pro Lifetime; Restore và Close tiếp tục Free luôn thấy.
- Advanced routines/insights/personalization/convenience+remove ads. Demo hữu hạn bằng kit/still đọc được reduced motion, preview không write; Free table rõ ownership/core habits. Chỉ benefits đã làm, không demo native health giả.
- States price loading/ready/pending/purchased/canceled/offline/error/restore none-success-error/unsupported-chưa bán; không giá placeholder/discount giả/pending cấp quyền; cached entitlement đúng adapter, refund không xóa data.
- R/A/P:320benefit list+demo/bottom action không che;768–1440max800/comparison wrap; demo semantics đủ/no auto-focus Buy/keyboard Close-Restore-Buy. /pro?feature=..., Back context; store native purchase/restore, Web không checkout/xuyên-store promise. Reject subscription/scarcity/ownership paywall/fake purchase switch/upgrade để Undo-restore.

### Mood optional

- Job/câu hỏi: **Muốn ghi cảm nhận hôm nay thế nào?** Finding entry hoặc Chưa ghi trung tính. Primary mood-energy rồi Save thường2 chạm, note-tag optional/Skip không entry.
- States none/edit/deleted/loading/save fail giữ draft/insufficient paired samples nói N; permission N/A; basic history Free. R/A/P320sheet không auto keyboard,768–1440max560, labels1–5không emoji-color only/focus selection; standalone /mood/:day, Back dirty guard. Reject due-count mood task/mandatory note/streak mood/medical inference.

### Trash

- Job/câu hỏi: **Lấy lại thứ đã xóa được không?** Finding N ngày còn/nội dung-links sẽ hồi. Primary Restore, permanent delete context+confirm.
- States empty/loading/restore conflict-missing link giải thích giữ item/purge fail Retry/permission N/A;30 ngày khác archive/Undo RAM. R/A/P320rows wrap/countdown không cắt,768–1440max800+preview; semantic name-kind-Ndays/keyboard focus restored item; /settings/trash→Back Data. Reject hard-delete lúc move trash/không nói policy/ID mới khi restore/offline sync resurrect purge.

### Gate trước khi đổi contract thành đã triển khai

Mỗi slice render màn/state đã đổi EN/VI/light-dark/320/768/1024/1440/text200%/focus-hover-pressed-disabled, so sibling source. App-screens §2.7: biggest block trả lời câu hỏi; grid/edges kín; hue đúng data; totals/range/units khớp; zero/missing rõ; legend đúng marks; phone nav không chiếm canvas. Sửa ba lỗi nặng rồi render lại tối đa3vòng. Motion0vẫn đủ nghĩa, commit không chờ animation. Không cần marketing asset.

Baseline36renderer cases PASS/direct critique7PNG ở AUDIT, films ngoài viewport chưa interaction evidence. Không UI mới vì chưa code; browser inspector/SR/OS/device/store chưa verified. Báo riêng source/unit/widget/emulator/device/store. Run1 không sửa lib/test/shared package và giữ uncommitted work khác.


## Handy Habit · run 2 · restore preview and trash contract (2026-11-10)

- Restore question: What is in this file, and what will happen here? Finding: file size, recorded backup date (or “Not recorded” for older files), original schema and habit/record/routine/run/pause/trash counts. Primary: Merge; Replace is an explicit secondary action with a second confirmation. File/password picker cancel writes nothing; invalid password/tamper/unsupported schema keeps local data and gives a retryable error. Preview is scrollable at 320px/text scale; actions wrap. Metadata is text, with keyboard/screen-reader labels. No preview writes. Stale preview must be reopened.
- Replace saves a durable device-local pre-replace recovery copy before the atomic commit; a failed save prevents replacement, and a failed commit leaves the current state intact. Settings offers “Recover before last replace” only when a copy exists, with confirmation. The recovery copy is private, remains on this device, and is overwritten by the next successful checkpoint; ordinary backup files exclude it.
- Trash question: What can I put back, and how long is left? Finding: each habit/routine title, kind and “N days left” (“còn N ngày”). Primary: Restore, retaining identity, history and valid links. Secondary: Delete for good, confirmed with the affected history/link consequences and “This cannot be undone.” Empty: “The trash is empty”. A caption states 30 days and archive is separate. Active linked runs must be ended before deletion. Deleted items disappear from Today, active lists, pickers and reminders; stored past records remain until purge.
- Trash is reached from Settings / Your data, route /settings/trash. Back/Esc returns to Settings; native back/swipe follows kit routes. Widths 320–1440: one scrollable column capped at 800px, wrapping row actions rather than clipped trailing buttons; 48px targets, semantic action labels include titles, full text at large scale. Nunito/editorial Habit palette stays; no red missed-day marks. Kit HandyAppear/HandyReveal animate rows and empty/content transitions, reduced motion uses kit behavior. Errors keep rows, restore/purge publish only after commit; confirmation cancel writes nothing. Screenshots/widget rendering are host evidence only, not device verification.

Host visual review: run 2 covers EN/VI, light/dark, 320/1440 at 150% text, plus reduced motion for Trash. Real Nunito/icon screenshots inspected: rows/actions fit and preview wraps/scrolls, with a 720px desktop cap. Backup dates use localized calendar/time text. Existing Habit Settings calendar/quiet values move below labels to keep the restore entry path usable at 320px/large text. No physical device/browser verification claimed.


### Handy Habit run 3b ? screenshot critique and host evidence

- §2.7 question/finding: greeting and vermilion kept/due ring lead; six due/one kept/five remaining derive from the same engine fixture, not a KPI dashboard. Reading is0/10 pages, water3/8, review23/32; preserved units and windows. Zero progress remains an open bead, missing/paused never fill as success.
- Edges/density: 1440 splits1024px content into600px habits +24px gutter +400px secondary column. Routines/review/reminder remain visible, cards keep their natural height; no stretched secondary panel. Phone shows the first check-ins before routines. The editor keeps a deliberate blank working area and a reachable pinned Save.
- Identity/colour: real bundled Nunito verified in all text roles and component themes. Oxblood words/actions, ochre date, vermilion daily ring; personal colour belongs to saved habit identities and beads (explicit brief exception), neutral navigation. No copied header band/gradients/icon boxes. Missed hollow/paused neutral beads have different shapes.
- Round1 findings fixed: kit grey card fill, fallback teal routine ticks, and the ring pushing the second check-in below60% at320/150%. Card theme now uses owned surfaces, routine fallback is a neutral step icon, progress/remaining share a compact block; greeting adapts at enlarged text. Final full-matrix rerender passes the original position assertion.
- Labels/states: kept/due is labelled directly with ring semantics; personal hues match across icon/history/today. EN/VI controls wrap at320/390/1440 and100/150%; sidebar folds, primary actions retain contrast in dark. A full-suite Ahem-font regression exposed an unbounded All routines button; bounded wrapping restored the four run2 overflow checks.
- Evidence: app93 tests (including5 new contrast/font/identity tests), engine82; app+engine dart analyze clean and format checks unchanged. Full tool/screens_test.dart63 scenarios pass;24 matrix cases render Today/editor/history/routines/progress (120 matrix PNGs), plus existing extra states/films. Inspected Today/editor comparison sheets for every matrix combination and individual small/large/dark/history shots. Screenshot folder: C:/Users/Winka/AppData/Local/Temp/habit-run3b-shots/.
- No tracking, schema or route change; docs/FUNCTIONS.md unchanged. Source/unit/widget/host-render evidence only; no emulator/device/browser/store verification.

## Handy Habit · R7 Basic routines implementation contract · 2026-11-10

### R17/R18 Advanced routine contract · 2026-11-10

- Inventory/jobs: ordered steps, finite weekday/habit/time rules, A/B choices, prior-step dependencies, stack-after prompts, weekday seconds, reusable block snapshots and named presets. Builder asks “What changes this plan?”; runner asks “What do I do now, and why?”; summary answers “What actually happened?”. Keep Nunito, Habit palette and the existing bead signature; routine tracks encode saved durations.
- Reference decisions: Boards' Pro title badges and explanatory template fields; Habit's atomic draft and focused runner. Basic is the default. An explicit Advanced disclosure reveals one-line explanations and individually expandable controls. Non-Pro sees badges to the right of titles and a small working, non-saving demo; existing advanced plans remain runnable. No purchase link until a real destination exists.
- Primary actions: builder Save commits the whole validated draft; runner chooses A/B before timing, then Done; summary reads saved decisions. Blocks and presets insert independent snapshots; future edits never rewrite runs. Dependencies must point to prior steps; invalid references/cycles/over-200 plans fail with the draft intact.
- States: blank/add, collapsed Basic, Advanced, non-Pro demo, missing habit/dependency, invalid draft, saving/error/retry, branch awaiting choice, skipped with reason, stacking prompt, recovered paused, complete/aborted summary. No network/loading state for local rule evaluation. No timers claimed while closed; branch selection never starts a background timer.
- Responsive/a11y: 320–390 single scroll and wrapping controls; 768–1440 bounded editor/640px runner, no stretched cards. EN/VI, light/dark and text 1/1.5; 48px targets, labelled controls, keyboard native buttons, focus order and reduced-motion kit disclosure. Routes/back/Esc retain existing dirty/save guards on every platform. Reject raw code/expression editing, drag-only dependencies, beginner-visible rule grids, fake checkout and colour-only explanations.
- Verification: render Basic/Advanced builder, conditional step, branch runner and summary in all 24 combinations; inspect, critique, fix and render again. Host widget/raster evidence only; no devices.
- R17/R18 result: app187/engine175 host checks pass; final24-case render produced168 PNGs including non-Pro badges/demo. Branch clocks/Undo, clipped conditional capture and wrapped badges were fixed across three rounds; [written critique](handy_habit/R17_R18_REVIEW.md). No browser/device/store certification.

- Inventory: personal routines (usually 1–8, potentially hundreds), ordered steps (0–200), seconds/minimum/priority/required/canSkip, optional habit and amount; saved session snapshots and actual elapsed seconds. Daily phone use and occasional desktop editing; no new data schema or Pro logic.
- Face: existing editorial greeting, Nunito, owned HabitPalette vermilion/oxblood/ochre. Bead check-in remains the single app signature; routine duration track encodes actual steps, never decorative KPIs. References: Boards card sheet's focused editing context; existing Habit form's atomic draft/unsaved discard and busy/error/retry mechanics. Boards currently saves card edits immediately with Undo; this builder follows the requested whole-draft Save.
- Library question: What can I start or resume, and how long will it take? Finding: active session, estimated duration and latest session date/status beside each routine. Start/Resume on each row; four rows then Show all in place. New routine opens a blank draft with all eight starter templates reachable there. Templates never displace personal routines.
- Detail question: What will I do in this routine? Finding: ordered steps, duration, linked habit and latest runs. Primary Start/Resume, secondary Edit opens one whole draft; no per-step durable edits. Recent runs capped with Show all in place.
- Builder question: Are these steps ready to save? Finding: step count and summed duration, plus inline validation. Name + steps first, existing schedule/group/note via Advanced settings. Step form retains minimum/priority/required/canSkip; no Advanced Pro features. Add/edit/remove/reorder/link affect draft only; drag and labelled up/down controls. One Save commits all fields/steps once; busy blocks double submit; failure retains draft for retry; stale/deleted routine refuses overwrite. Cancel/back/Esc asks Unsaved changes; dismissing keeps draft. Template selection fills draft only.
- Runner question: What is my current step and what comes next? Finding: current title large, elapsed/planned, paused/running/recovered, resolved progress and remaining names. Fullscreen without shell. Done commits immediately, then kit HandySwap transition; track uses kit HandyMotion, summary HandyAppear. Skip obeys canSkip; no timer implies manual completion. Space pause/resume, Enter Done (or finish when all resolved), Esc/back requests pause-and-exit confirmation; typing and open dialogs never activate runner shortcuts. Abort is a separate confirmed action.
- Recovery: persisted snapshot and anchor recover paused, estimated time explicitly labelled; foreground/background persists pause. No terminated/background timer or alert guarantee. Exactly-once event IDs and causal operations remain authoritative; summary names only credited links, distinguishes skips/already-reached/no-credit and preserves session snapshots.
- States: library empty/create/templates, missing detail/history, builder empty/add/validation/busy/stale/save error, runner initialization/save error/recovered/untimed/paused/completed/skipped/summary. Permission N/A (Start never requests). No new ad placement. Errors keep state and offer retry through existing action.
- Responsive/platform: 320/390 linear scroll with wrapping controls and pinned primary; 768 one pane; library >=1100 list/detail; 1440 bounded readable runner 640px. Text 1/1.5, 48px controls, named labels, visible focus; progress semantics without announcing every tick. Routes /routines,/routine/new,/routine/:id/edit,/routine/:id,/run/:id,/session/:id; native/web back obey guards. Reduced motion zero duration via kit. Reject drag-only, live partial saves, false timer promises, full-width stretched cards, clipped footers, invented credit.
- Supervisor 3b fix: Today section actions align flush with the right edge of their own card column, including EN/VI large text.
- Verification: host widget renders EN/VI × light/dark × 320/390/1440 × 1/1.5, critique against app-screens §2.7, fix then re-render. Host evidence only; device checks delegated to supervisor.

### R7 host screenshot critique (app-screens §2.7)

- Question/hierarchy: library exposes Start/Resume + latest run; builder leads with name, 5 steps and 39 minutes; runner makes the current step and labelled elapsed/planned time largest; summary names actual credited habits. Nunito and Habit palette remain visible throughout. No new app signature beyond beads.
- Edges/density: standalone detail is centered and bounded, library uses list/detail at desktop, long lists expand in place. Today actions now land at each column's right edge. Final narrow effective-width rows stack Start below metadata so VI/150% text has the full measure. Runner's deliberate 640px focus measure is justified by the single-step job; sparse libraries show their real two routines rather than invented filler.
- Colour: vermilion encodes steps/progress, oxblood primary actions, ochre/personal bead colours remain owned tokens; neutral navigation and flat surfaces, no new gradients/shadows/icon tiles. Paused clocks use ink, running clocks the data hue.
- Arithmetic: fixture's 1+8+10+5+15 = 39 minutes, 5 planned steps, 5 completed/0 skipped. Water goes 3→4, reading 0→10; meditation was already kept and earns no duplicate event. Summary names two credited habits; actual elapsed 0:00 is honest for rapid synthetic completion. No typed independent total or optimistic invented credit.
- States: no prior session says Not run yet; untimed and zero elapsed remain labelled; recovered time is explicitly an estimate and remains paused. Busy/failure/stale/discard/skip/required/exactly-once/reduced-motion paths have widget/unit evidence. Captions and control labels wrap at320/390/1440 and100/150%; duration-strip segments come from saved step seconds.
- Fix/verify rounds: removed bulky name help and moved Advanced after steps, centered detail, stacked narrow row actions. Fixed premature header captures by pumping route transitions before stills. All24 R7 combinations were re-rendered after the final layout refinement; comparison sheets cover every combination. HTML/browser inspector was not used: these are Flutter host raster/widget captures, not browser/device evidence.


## Handy Habit · R10/R11 negative habits contract · 2026-11-10

- Inventory: mixed build/reduce habits (typically 1–12); count incidents in thousandths, explicit zero observations, optional notes, versioned daily/weekly ceilings, historical observations and causal edits. Daily phone glance and occasional desktop correction; totals always derive from records.
- Face/signature: existing Nunito, Habit vermilion/oxblood/ochre, personal habit colours and bead strings. References: Bookmark Spotlight positioning in welcome/motion.dart keeps coaching words away from controls; Habit whole-draft editor and Boards focused forms establish single primary Save and clear cancel/back.
- Create question: What am I building or reducing? First Basic choice Build a habit / Break a habit, followed by name and None at all / At most N per day or week. Reduction uses whole incident counts; direction locks after records/links. Threshold revisions apply prospectively, weekly changes at the existing/new week boundary. Primary Save; invalid integers retain draft and explain; cancel/back uses existing unsaved guard.
- Today question: What happened today? Finding: recorded incidents against the ceiling, or Unknown until recorded. Primary bead logs +1 immediately with causal Undo, including beyond limit. Quiet None today confirms zero; an existing positive total must be edited explicitly. Open periods are provisional, never streak credit. Within-limit beads use personal colour; over-limit is a neutral filled-outline mark; unknown hollow. Labels and shapes supplement colour.
- History question: Which days are known and within the limit? Month cells expose incident totals, explicit none, unknown, pause and skip; editing/backfill includes Return to unknown. Weekly review counts daily opportunities and closed full weekly windows, includes unknown in eligible denominator with a labelled unknown count; excludes open/paused weekly windows without prorating ceilings. Recovery is a fresh start, never punishment.
- Help question: How does reducing differ from building? Searchable Positive vs negative habits topic with accurate mixed-bead mock, zero versus unknown, provisional daily/weekly close and no routine incidents. No presentation setting without a meaningful choice.
- Responsive/platform: 320–1440 and text 1/1.5; one scrolling editor, wrapping choices and row copy, 48px actions; desktop retains existing capped split shell. Named routes and native/web back/Esc unchanged; keyboard focus and screen-reader incident/none/status labels. Kit motion respects reduced motion. Practice coach sits above the first target when later controls are below.
- States: existing empty Today/create invitation, loading/retry, durable-save error and Undo failure remain. Unknown is a real state; zero is real data. Reject automatic success for silence, red/shaming marks, weekly day-count quotas for negative habits, routine-to-incident links, decorative new panels and settings with no choice.
- Verification: host widget render matrix EN/VI × light/dark × 320/390/1440 × text 1/1.5 for create, mixed Today, history and review; inspect screenshots, critique/fix/re-render. No device/browser/store claim.

Historical R11 Progress contract (counting superseded by R12/R13 below): “What did I record, and which closed periods were within the limit?” Weekly activity counts explicit zero observations as check-ins; per-habit metrics name within-limit counts, including unknown closed periods in the denominator. Existing responsive list/chart, keyboard/back and export states remain.

### Handy Habit R12/R13 implementation contract · run 7 · 2026-11-10

- Inventory: 32 existing habit and 8 routine presets with stable IDs; incident ceilings; schedules; local calendar dates, pauses and observations; routine sessions. Typical library 1–20 habits, history 1–366 days in a selected year. All totals derive from engine results.
- Gallery question: what feels manageable to start? Finding: each result names its actual target and schedule. Featured offers three useful starts; search matches EN/VI without accents, 13 collection chips narrow results. Habit/routine switch lives in create, never another tab. Existing names remain available as independent copies. Boards gallery → preview → setup → create supplies mechanics; Habit keeps Nunito, oxblood actions, palette dots and bead rhythm.
- Preview question: what will I create? Finding: exact goal, schedule, and ordered routine steps with durations. Primary Customise opens the existing editor with a disposable draft; Cancel/back writes nothing; Save persists once, then returns. Blank creation remains available. Local catalog has no permission/loading requirement; no-match offers Clear; failed save retains draft/retry.
- Progress question: what have I kept in this week, month or year? Finding: kept / eligible with its unit, then current/best streak per habit. Weekly review stays one tap away. Month calendar answers which days were kept; yearly heatmap answers where a rhythm appears, overall and per habit; routine rows state finished / started. Habit and routine lists cap at five with Show all. No comparison/correlation or Pro gate.
- Counting: closed weekly reduction limits use recorded incidents, blanks infer no incident; quiet line “Counted from what you recorded”. Today’s daily blank remains unknown, past blank daily days are hollow and excluded from consistency; pauses, skips, conflicts and unfinished periods are excluded. Partial weekly windows remain neutral. Explain exclusions once beside totals. Heatmap uses habit identity hues, neutral missed cells, hollow unknown cells; future cells never imply success.
- Responsive: 320/390 single column, wrapping chips/actions, no fixed text heights; 768 wider rows; 1440 paired Progress sections and a bounded content column. Year scrolls only inside its labelled frame. Text 1/1.5, EN/VI, light/dark mandatory. Keyboard native controls, search autofocus only on request, back/Escape restores prior stage. Cells expose date/status/counts in semantics and tooltips; calendar day opens existing history/backfill. Named /templates?collection=… and /progress retained.
- Reject: chip wall of 32 presets, automatic save on selection, generic KPI cards, red misses, blank-as-failure denominator, chart without a finding. HandySwap/Reveal transitions respect reduced motion. Host render → app-screens §2.7 critique → fix → re-render; no device claim.


### Handy Habit R15/R16 Sync contract · run 9 · 2026-11-10

- Job/question: is my Habit data in step with my other Android phone, and what needs attention? Finding: Off / Connecting / Synced / Pending / Error / Update required, followed by pending count and last successful sync. One primary action: Turn on or Sync now; separate Turn off and Disconnect.
- Inventory: optional Free provider Google Drive; selected account; device-local enabled/base/activity/error/time; immutable causal operations for habits, check-ins, incidents, moods, routines, sessions, trash and tombstones. Concurrent absolute totals/skips and moods expose retained candidates with explicit review actions. Never choose tracking data by wall time.
- Route /settings/sync from Settings › Data, separate from Backup. Android row exists only with HANDY_DRIVE_SYNC=true. Other platforms state “Use backup to move data” in help/data guidance. Back/Esc return to Settings; keyboard focus follows visual order; state changes use live semantics.
- Face/signature: keep Nunito, owned vermilion/oxblood/ochre and existing bead identity; a quiet status line, open rows and one primary button. No KPI cards, decorative cloud hero, fake progress, disabled unavailable toggle or Android↔iOS claim.
- Layout: 320/390 single scroll column with 16px gutters, wrapped values/actions and ≥48px targets; 1440 centered readable max720 column. Text at 1.5 must wrap without truncating account/error/privacy. Loading keeps page stable and disables duplicate actions; errors explain recovery while local tracking remains usable.
- Privacy/limits paragraph: own hidden Drive app folder, appdata scope only, no developer server, no end-to-end encryption, foreground sync, deletions propagate, backup remains separate; off/disconnect delete neither copy. Review EN/VI × light/dark × 320/390/1440 × text1/1.5 for all six states, critique, fix and re-render.

### Handy Habit R14 mood contract · run 8 · 2026-11-10

- Inventory/jobs: 0–1 mood/day, mood 1–5, optional energy 1–5/note up to 4096/tags up to 8; no inferred mood. Daily glance on phone, occasional edits/history on desktop. Existing habits, due totals, beads and routines stay primary. Nunito/editorial greeting and owned oxblood/vermilion/ochre palette; beads remain the only signature.
- Today question: want to record how today feels? Finding: “How’s today?” or today's chosen label, one quiet line after habits. Tap opens five labelled choices; tap a choice saves immediately (two taps total). “Add details” opens optional fields; Cancel/back/Skip writes nothing. No keyboard on open, required note, mood streak, medical claim, red/green judgement or correlation.
- Sheet question: what do I want to remember? Finding: date and chosen label. Primary Save for detailed edits, Delete secondary for existing entry; deleted entry keeps a recoverable tombstone, Restore in mood history plus immediate Undo. Notes remain in local app data and user-requested backups/exports; never notifications/widgets/lock screen. No new permission.
- Progress question: how did I record feeling over this range? Finding: dated labels, no averages or judgement. Simple history capped at five with Show all; neutral empty days stay unlogged, never a failure. Tap a row to edit; deleted entries available via a quiet disclosure. No Pro gate. Range follows Progress.
- Settings: Show mood on Today defaults on; off removes only the prompt, keeps history/data. How to use has a searchable Mood topic and matching drawn mock.
- Responsive/a11y/platform: 320/390 one scroll column, 1440 bounded 560px sheet/history beside Progress sections where possible; choices wrap with >=48px targets and words, no font emoji. EN/VI light/dark text 1/1.5. Native buttons/focus/Tab/Enter, back/Esc returns without writing; dirty detailed draft asks discard. Busy blocks duplicate submission/back; failure keeps draft with Retry. Selection/reveal uses kit motion, zero reduced motion. /mood/:day routes; no loading permission needed after existing store load.
- Calendar fix: unknown day is a drawn hollow ring, never unsupported Nunito U+25CB. Rendered calendar Text is checked against bundled font cmap. Host matrix render → app-screens §2.7 critique → fix → re-render; no device claim.

- Critique fixes: short Mood/Tâm trạng sheet title avoids 320px/150% AppBar truncation; desktop mood history follows the calendar in the left column to use the space beside habit/routine details. Quick choice labels remain words, all the same neutral/anchor treatment, with48px targets. Deletion explains Restore; re-logging a deleted day starts with blank optional details. These changes are re-rendered across the matrix.

### Handy Habit R19/R20 + Pro contract · run 13 · 2026-11-11

- Inventory: local habits, versioned goals, daily/weekly opportunities, pauses/skips/unknowns, optional mood 1–5; typical 1–20 habits and 28–90 closed days. Demo figures derive from disposable engine history. Studio choices are preferences, never changes to habit identity/history.
- Pro question: what will I keep with one purchase? Finding: selected capability playing in the top panel. Large Habit headline plus one sentence; drawn thumbnails in Routines / Understand / Make it yours sections; replay returns to top. Pinned Restore/Get Pro with localized price and honest unavailable/loading/pending/owned/cancel/error states. Purchase only when real store permits. References: saved run12 sibling Pro rasters; keep Nunito, beads, oxblood/vermilion.
- Insights question: which small change would help this week? Finding: kept/eligible for equal elapsed month/quarter windows with exact dates and exclusions. Group comparisons, explained difficulty, weekday misses with denominators, accept/dismiss goal rules effective tomorrow, mood co-occurrence with minimum evidence and no causal language. Advanced insights/report/filtering need Pro; core Progress/exports/mood stay free. Free screen shows labelled demo and badges. PDF preview then explicit save.
- Studio question: how will my daily screen feel? Finding: live preview of palette/layout/spacing/icons/runner. Everyone previews; Apply checks current Pro at write time. Cancel/back writes nothing. Pro loss uses free appearance and retains choices. Three Habit palettes in light/dark, AA text; licence-safe Material outlines. Widget choices only if native renderer supports them.
- Responsive/platform: 320/390 stacked, 1440 bounded 1000px and paired sections; text1/1.5 wraps, scrollable controls/footer, >=48px targets. Routes /progress/smart and /settings/studio; Back/Esc, Tab/Enter, live status and labelled chart cells. Kit reduced motion. Existing load retry; failed writes retain draft; empty insights explain insufficient data.
- Reject: fabricated prices, red misses, inferred mood, weekly quotas attributed to weekdays, percentages without baselines, causation, automatic goals, preview writes, generic KPI tiles. Render EN/VI × light/dark ×320/390/1440 ×text1/1.5; critique, fix, render again beside saved sibling Pro references.

- Run13 critique/fixes: selected panel now precedes its description, matching sibling order; footer wraps Restore/Get Pro without clipping at320/text1.5. Thumbnails distinguish calendars, branches, clock, blocks and analytics. Unsupported Nunito arrow replaced with words and glyph regression tests. Studio preview targets the selected habit, retains its identity hue and shows the chosen icon. Failed/stale Apply keeps draft and inline recovery copy. Final matrix re-rendered; PDFs inspected as actual A4 pages. Final insights fixture has morning Reading and evening Walking to make group counts visible; all figures come from engine history. No device/browser/store claim.
