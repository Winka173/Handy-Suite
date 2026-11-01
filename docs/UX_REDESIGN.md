# Handy Suite — làm lại UI/UX

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

  | App    | Màu       | App   | Màu       |
  | ------ | --------- | ----- | --------- |
  | Tools  | `#E8590C` | Save  | `#0E7490` |
  | Keep   | `#B7791F` | Docs  | `#1D5FBF` |
  | Recall | `#4D7C0F` | Media | `#C2255C` |
  | Dev    | `#0F8A5F` | Spend | `#2E7D32` |
  | Habit  | `#B42318` |       |           |

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

## Hợp đồng: Handy Save

**Dữ liệu và việc** (skill §2.1)

- Đối tượng: link đã lưu (URL gốc và đã chuẩn hóa, tiêu đề, mô tả, ghi chú, nguồn như
  YouTube/TikTok/Facebook/Shopee, domain, ảnh thu nhỏ, bộ sưu tập, thẻ, yêu thích,
  ghim, đã đọc, lưu trữ, số lần mở, hẹn nhắc); bộ sưu tập lồng nhau; thẻ; bộ sưu tập
  thông minh (Pro, 1–12 điều kiện); tìm kiếm đã lưu (Pro).
- Quy mô thật: 50–3.000 link; mỗi ngày lưu 1–10 link, chủ yếu qua nút Chia sẻ của app
  khác; 5–30 bộ sưu tập; phần lớn link mới nằm trong "Chưa xếp".
- Người dùng: một người, chủ yếu điện thoại. Lưu từ app khác (không mở Handy Save), rồi
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
`platform/` và `services/` giữ nguyên từ bản cũ. Chưa có trong giao diện mới: tìm kiếm
đã lưu (Pro) và sắp xếp thủ công (lên/xuống); dữ liệu của chúng vẫn được giữ.

**Kế hoạch triển khai** (`apps/handy_save/lib/`, giữ `controller.dart`, `platform/`,
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
  hai công cụ nhanh (Sửa ảnh, Phụ đề) và, trên Android/iOS, Chụp màn hình.
- Trình soạn: "Bước này cần chỉ vào đâu và che gì?" Ảnh bước là khối lớn nhất; dải
  bước bên trái (desktop) hoặc dưới (điện thoại); thanh công cụ 9 loại chú thích; bảng
  thuộc tính lớp đang chọn. Nút chính **Xuất hướng dẫn**.
- Sửa ảnh: "Ảnh ra sẽ trông thế nào?" Xem trước là khối lớn nhất; một hàng chọn việc
  (Cắt, Cỡ, Định dạng, Đóng dấu, EXIF); nút chính **Lưu ảnh** (một ảnh) hoặc **Lưu ZIP**.
- Phụ đề: "Thời gian đã khớp chưa?" Các cue đầu tiên trước/sau khi dời là khối lớn
  nhất; nút chính **Lưu tệp**.

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
5. **Sửa ảnh** (`#/image`), **Phụ đề** (`#/subtitles`), **Chụp màn hình**
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
ngay dưới), `subtitles/` (xem trước các câu đầu trước/sau khi dời, Lưu kiểm tra toàn tệp),
`capture/` + `native_capture_page.dart` (giữ nguyên logic; bố cục mới: chụp, bản vừa
chụp, tạo bản mới của video). Xóa hướng dẫn giờ xóa cả bản nháp. Bỏ Ctrl K, ghim và
"đầu vào đã lưu" của phụ đề.

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

## Lộ trình

| Bước | Phạm vi                                              | Trạng thái |
| ---- | ---------------------------------------------------- | ---------- |
| 1    | Kit chung + Tools (bàn làm việc, băng, QR, mật khẩu) | Xong       |
| 2    | Dev                                                  | Xong       |
| 3    | Keep                                                 | Xong       |
| 4    | Recall                                               | Xong       |
| 5    | Save                                                 | Xong       |
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
cũ trùng Dev và Save. Vì đỏ là màu của app, Habit **không bao giờ tô đỏ ngày lỡ**: ngày lỡ
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
