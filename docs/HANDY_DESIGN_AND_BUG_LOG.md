# Handy Suite: sổ thiết kế và lỗi (Bookmark, Boards và kit dùng chung)

Cập nhật: 2026-11-10. Tổng hợp mọi quyết định thiết kế, mọi lỗi chủ báo và cách đã sửa trong đợt làm lại Handy Bookmark và Handy Boards (8–10/11/2026). Chi tiết từng màn nằm trong hợp đồng thiết kế ở [UX_REDESIGN.md](UX_REDESIGN.md); giới hạn số liệu nằm trong [FUNCTIONS.md](FUNCTIONS.md).

**Ký hiệu trạng thái**

- ✅ Đã sửa: có test, đã commit, push và cài lên BlueStacks.
- 🟡 Còn mở: chưa làm, chờ quyết định, hoặc mới làm được một phần.
- ⏸ Chủ quyết định tạm bỏ.
- ℹ️ Không phải lỗi: giải thích hoặc giữ nguyên có chủ đích.

Mã commit (ví dụ `15584c53`) nằm trên nhánh `ui-rebuild`.

---

## 1. Nguyên tắc làm việc (chủ đặt ra, đang áp dụng)

| Nguyên tắc                            | Cách áp dụng                                                                                                                                                                          |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Mỗi app độc lập**                   | Mỗi app có bảng màu, font và nhận diện riêng. Không vì app khác đã dùng một màu mà tự giới hạn mình. Kit chỉ dùng chung hành vi, khoảng cách và trợ năng.                             |
| **Mọi thay đổi UI qua 2 skill**       | Chạy `design-taste-frontend` (phần app screens) và `frontend-ui-engineering`. Viết hợp đồng thiết kế vào `UX_REDESIGN.md` trước khi viết mã.                                          |
| **Làm theo bản phác đã chọn**         | Bản phác là chuẩn. Không đem bố cục cũ vào lại, không làm hỏng những gì đã sửa trước đó.                                                                                              |
| **Danh sách lỗi: xác nhận trước**     | Với lỗi chủ báo, tìm nguyên nhân và cách sửa, báo lại, chờ chủ đồng ý rồi mới sửa. Khi chủ nói "làm tới khi xong hết" thì làm liên tục.                                               |
| **Hỏi khi có nhiều phong cách**       | Dựng các phương án (mock HTML, ảnh so sánh) để chủ chọn.                                                                                                                              |
| **Commit và push sau mỗi việc**       | Chỉ lấy phần của phiên này. Không đụng tệp của phiên khác (ví dụ `apps/handy_bookmark/web/manifest.json`, `tooling/app-icons.py` của người khác).                                     |
| **Build và cài sau mỗi thay đổi**     | Cài lên 2 máy BlueStacks Android 11: `127.0.0.1:5555` (dọc) và `127.0.0.1:5575` (ngang). Trước khi cài phải kiểm tra `ro.product.model == SM-S908E`. Không gỡ app, không xoá dữ liệu. |
| **Build có biến môi trường mua hàng** | `--dart-define-from-file=../../.tooling/monetization-defines.json --dart-define=HANDY_DRIVE_SYNC=true`. Thiếu biến thì trang Pro báo "chưa bán".                                      |
| **Không bí mật trong repo**           | Khoá ký, `play-publisher.json` và `monetization.local.json` không bao giờ được commit hay in ra.                                                                                      |
| **Phát hành production là việc tay**  | Chỉ chủ phát hành.                                                                                                                                                                    |
| **Bỏ thứ cũ**                         | Gỡ hẳn mã và tài nguyên đã bị thay.                                                                                                                                                   |
| **Tiết kiệm token**                   | Làm trực tiếp, không chia việc cho nhiều agent. Chỉ chạy test liên quan; chạy toàn bộ trước khi commit.                                                                               |

---

## 2. Hệ thiết kế chung

### 2.1 Hành trình chọn phong cách

1. **Bản tham khảo "Pocket Hub":** dùng làm ý tưởng (ảnh xem trước bắt buộc, lớp nền tách bằng sắc độ). Không chép.
2. **Pastel (9/11):** chủ chọn pastel cho cả hai app, gồm phương án 1 (pastel sáng) làm bản sáng và phương án 4 (pastel trên nền than) làm bản tối.
3. **Revert rồi khôi phục:** chủ cho revert, rồi đổi ý khôi phục (`28744ee1` → `8246c15b`). Sau đó dựng lại đúng theo bản phác (`249df697`, `cacd0f82`).
4. **Tương phản mạnh 3a (9/11):** góp ý "ít màu, chữ nhỏ cho người mắt yếu". Chủ xem 5 phương án 3a–3e và chọn **3a cho cả hai app** (`15584c53`).
5. **Boards bỏ màu hồng (9/11):** chủ chọn **cam đất** trong 4 phương án, và **icon khung bảng 3 cột** trong 3 phương án (`182c5cdc`).

### 2.2 Hướng 3a: dải đầu trang đậm và nút vàng

- Đầu trang là **một dải màu đậm duy nhất**: tên trang màu trắng đậm, dòng số liệu nhạt, nút chính màu vàng `#E0A93B` (bản tối `#E6B44F`; chữ `#241A05`).
- Mục đang chọn ở thanh bên dùng màu dải, chữ trắng.
- **Bác bỏ:** dải đậm ở nhiều chỗ, thanh bên đậm (3d/3e), nút vàng ở các màn khác.

|                   | Handy Bookmark             | Handy Boards                               |
| ----------------- | -------------------------- | ------------------------------------------ |
| Dải (sáng / tối)  | `#0F4B54` / `#145A64`      | `#7C2D12` / `#6E2A12`                      |
| Nút vàng (sáng / tối) | `#E0A93B` / `#E6B44F`  | `#E0A93B` / `#E6B44F`                      |
| Màu nhấn          | `#0E7490` (link `#0F4B54`) | `#B53C0A` (tối `#F0936A`)                  |
| Nền / bề mặt nâng | `#EEF3F3` / `#E6EDED`      | `#F5F1EE` / cột `#ECE6E1`                  |
| Chữ / chữ phụ     | `#0B1213` / `#38423F`      | `#17110D` / `#3D332D`                      |
| Font              | Manrope                    | Plus Jakarta Sans                          |
| Icon              | (giữ nguyên)               | Khung kem 3 cột, một thẻ vàng, nền cam đất |

### 2.3 Cỡ chữ (cho người mắt yếu)

| Vai trò                              | Cỡ                                                  |
| ------------------------------------ | --------------------------------------------------- |
| Chữ đọc (`bodyMedium` / `bodyLarge`) | 15,5 / 16,5                                         |
| Chữ phụ (`bodySmall`, `labelMedium`) | ≥ 13,5                                              |
| Tiêu đề mục (`titleLarge`)           | 21, đậm 700                                         |
| Tên trang trên dải                   | Bookmark 30; Boards 28 (điện thoại) / 32 (màn rộng) |
| Nút                                  | 16                                                  |

### 2.4 Độ tương phản

- **Kiểm định:** đã đo 128 cặp màu theo WCAG. Ba cặp không đạt đã được sửa:
  - chấm hổ phách của Bookmark: 2,36:1;
  - chấm ô liu của Bookmark: 2,87:1;
  - thanh tiến độ hổ phách của Boards: 2,49:1.
- **Cách sửa:** `HandyPalette` (kit) làm đậm màu nhận diện ở bản sáng tới 3,45:1 so với nền trắng. Chỉ hổ phách và ô liu thay đổi. Việc này ảnh hưởng nhẹ tới mọi app.
- **Kết quả sau sửa** (tính lại từ màu trong `design/theme.dart` ngày 10/11):
  - chữ trên dải: 9,4–10,5:1; riêng bản tối Bookmark (dải `#145A64`) là 7,9:1;
  - chữ phụ trên dải: 7,2–8,1:1; riêng bản tối Bookmark là 6,3:1;
  - nút vàng so với dải: ≥ 4,4:1; riêng bản tối Bookmark là 4,1:1 (yêu cầu cho phần tử không phải chữ là 3:1);
  - chữ trên nút vàng: ≥ 8:1;
  - chữ trên ô màu: ≥ 9,4:1 (bản tối ≥ 6,7:1);
  - màu nhấn Boards trên cột: 4,69:1.

### 2.5 Chuyển động (kit `motion.dart`)

- **Mục đích:** chuyển động là phản hồi và sự liền mạch, không phải để trình diễn. Mọi chuyển động về 0 khi máy bật "giảm chuyển động".
- **Các thành phần:**
  - `HandySwap`: chuyển mềm giữa hai trạng thái.
  - `HandyReveal`: co giãn theo nội dung. Khi giảm chuyển động thì không co giãn, vì một hiệu ứng co giãn dài 0 làm Flutter báo lỗi bố cục.
  - `HandyAppear` (10/11): thứ mới tới thì mờ dần vào kèm phóng nhẹ, chơi đúng một lần cho mỗi thứ.
- **Thông báo có nút Hoàn tác:** đặt `persist: false` để tự tắt (Flutter mặc định giữ mãi khi có nút) (`0a001235`).

### 2.6 Nhãn Pro

Mọi lối vào tính năng Pro đều ghi "Pro" **trước khi** người dùng bấm, và chỉ hiện với người chưa có Pro (`e8280186`).

---

## 3. Handy Bookmark

### 3.1 Bố cục hiện tại

- **Điện thoại, Trang chủ (từ trên xuống):**
  1. thương hiệu;
  2. **dải đầu trang** (tên thư viện, số liệu, ô dán link và nút Lưu vàng);
  3. hai thẻ hàng chờ: "N mục chưa xếp" (Xếp nhanh) và "N mục chờ xem lại" (Tập trung), cùng tint xanh nhạt, tách nhau 8pt;
  4. Hẹn đọc;
  5. Bộ sưu tập (ô pastel);
  6. Mới lưu.
- **Máy tính / tablet:**
  - thanh bên 260pt (thương hiệu, Thư viện, các nơi, bộ sưu tập, Thùng rác, Cài đặt; nằm dưới thanh trạng thái);
  - dải đầu trang nằm ngang;
  - trang tổng quan: hàng chờ, Hẹn đọc, 6 ô bộ sưu tập, Mới lưu 6 cột;
  - danh sách có khung chi tiết 440pt bên phải;
  - lề 24 ở cả hai bên cho dải, danh sách và khung chi tiết.
- **Trang chi tiết một mục trên màn rộng:** 2 cột.
  - Trái: ảnh, tiêu đề, Mở bản gốc, Đọc.
  - Phải: các nút thao tác, hẹn nhắc, thẻ, ghi chú, chi tiết, và "Cũng trong <bộ sưu tập>" (hoặc "Thêm từ <trang>"), tối đa 6 mục.

### 3.2 Tính năng thêm trong đợt này

| Tính năng                  | Mô tả                                                                                                                                                                                                                                                                                                                                       | Commit     |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| **Gửi bộ sưu tập**         | Chọn 1 hay nhiều bộ (kèm thư mục) và gửi đi **một tệp HTML**: trình duyệt mở như một trang, Handy Bookmark thì nhập được. Kèm ảnh thu nhỏ đã bỏ dữ liệu vị trí. Ghi chú chỉ gửi khi bật công tắc. Không gửi thẻ, hẹn nhắc, trạng thái đã đọc.                                                                                               | `3bc28432` |
| **Nhận bộ sưu tập**        | Vào Bộ sưu tập › Xem tất cả › "Thêm bộ sưu tập được gửi cho bạn" (hoặc Cài đặt › Dữ liệu › Khôi phục). App kiểm tra cả tệp trước, xem trước rồi mới nhập; link đã có không nhân đôi; bộ trùng tên được thêm "(từ bạn)". **Thư mục:** Pro sang Pro thì giữ; người nhận free thì gộp vào bộ cha, tên thư mục thành thẻ. Gửi và nhận đều free. | `3bc28432` |
| **Nhấn giữ bộ sưu tập**    | Hiện "Gửi cho bạn bè" (bộ đó chọn sẵn) và "Sửa". Menu "⋯" ở thanh bên cũng có Gửi.                                                                                                                                                                                                                                                          | `806eeaac` |
| **Bản đọc offline có ảnh** | Tối đa 20 ảnh trong thân bài, mỗi ảnh ≤ 1280 px (JPEG đã bỏ dữ liệu ẩn), tổng ≤ 10 MB, tải trong ≤ 45 giây qua bộ tải an toàn. Ảnh nằm bên trong bản đọc (định dạng 2), nên xoá bài là ảnh mất theo.                                                                                                                                        | `d026e518` |
| **Xếp nhanh**              | Sau mỗi lần xếp hiện "Đã cho vào X" kèm Hoàn tác; có trạng thái "Đã xếp xong".                                                                                                                                                                                                                                                              | `e6539771` |
| **Hẹn đọc**                | Dải ruy băng vàng trên mục được hẹn; nhóm theo Tối nay, Ngày mai, Cuối tuần.                                                                                                                                                                                                                                                                | `a670361e` |

### 3.3 Lỗi và góp ý đã sửa

| Chủ báo                                                                                 | Nguyên nhân                                                                         | Cách sửa                                                                     | TT  |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | --- |
| Chữ "See all" lệch hoặc đè                                                              | Nút ở đầu mục chiếm hết chỗ trống                                                   | Giới hạn nút rộng tối đa 45%, để tiêu đề co lại                              | ✅  |
| Mục Chưa xếp quá to                                                                     | Thẻ gợi ý xếp ngay trên Trang chủ                                                   | Gộp thành một thẻ hàng chờ, bấm vào là Xếp nhanh                             | ✅  |
| Xếp nhanh chuyển mục mà không báo                                                       | Không có xác nhận                                                                   | Hiện "Đã cho vào X" kèm Hoàn tác                                             | ✅  |
| Thông báo Hoàn tác không tự tắt                                                         | Flutter giữ snackbar có nút cho tới khi người dùng đóng                             | Đặt `persist: false` ở cả hai app và trong kit (`0a001235`)                  | ✅  |
| Trang Giấy phép báo lỗi                                                                 | Font Geist và Bricolage thiếu tệp giấy phép OFL trong assets                        | Khai báo tệp OFL trong `handy_ui`                                            | ✅  |
| Xem tất cả bộ sưu tập mở sai chỗ; trên điện thoại không ra ô                            | Trỏ nhầm trang                                                                      | Trang Thư viện hiện bộ sưu tập dạng ô; màn rộng có trang "Tất cả bộ sưu tập" | ✅  |
| Trang tổng quan màn rộng lệch về một phía, hàng chờ sát nhau, thẻ Mới lưu cao không đều | Bố cục cũ                                                                           | Sắp lại cả màn, hai thẻ hàng chờ tách rời, chừa sẵn chỗ cho 2 dòng tiêu đề   | ✅  |
| Hai thẻ hàng chờ ở bản tối trông như nhau                                               | Tint xanh tối quá gần màu dải                                                       | Thử nền đất nung; cuối cùng chủ chọn hai thẻ **cùng tint** (`54401ad0`)      | ✅  |
| Logo thanh bên bị thanh trạng thái che (máy ngang)                                      | Thanh bên không có `SafeArea`                                                       | Thêm `SafeArea`                                                              | ✅  |
| Cuộn thanh bên thì nền xanh của mục đang chọn trôi đè logo                              | `ListTile` tô nền lên lớp `Material` của cả trang, nằm ngoài vùng cắt của danh sách | Danh sách có lớp `Material` trong suốt riêng, cắt theo mép                   | ✅  |
| Mục đang chọn ở thanh bên có chữ đen trên nền xanh                                      | Tiêu đề có kiểu chữ cố định, màu "đang chọn" không tác động tới                     | Đặt chữ trắng cho tiêu đề và nút "⋯"; có test kiểm tra màu                   | ✅  |
| Hàng "Thư viện" lệch so với các hàng dưới                                               | Lề trong khác các hàng còn lại                                                      | Dùng chung lề                                                                | ✅  |
| Dải đầu trang không thẳng mép với danh sách                                             | Dải lề 24, danh sách lề 16                                                          | Cùng lề 24 ở cả hai bên                                                      | ✅  |
| Màn chi tiết trên máy tính trống nhiều                                                  | Một cột hẹp                                                                         | Bố cục 2 cột, thêm "Cũng trong bộ sưu tập"                                   | ✅  |
| Bản đọc offline không có ảnh                                                            | Thiết kế ban đầu chỉ giữ chữ                                                        | Giữ ảnh, có giới hạn (xem 3.2)                                               | ✅  |
| Lỗi bố cục khi bật giảm chuyển động                                                     | Hiệu ứng co giãn dài 0 tự bố cục lại trong lúc bố cục                               | Sửa `HandyReveal` trong kit                                                  | ✅  |

### 3.4 Đã bàn nhưng không làm

- ⏸ **Gửi bằng link** (`winka.top/s/bookmark#<dữ liệu>`): khả thi (khoảng 60–90 ký tự mỗi link, không kèm ảnh), nhưng chủ tạm bỏ. Đã có đánh giá kỹ thuật nếu sau này cần.
- 🟡 **Nhận tệp qua nút "chia sẻ vào app" trên Android:** chưa làm (chủ đồng ý để sau). Hiện Handy Bookmark vẫn hiện trong bảng chia sẻ khi chia sẻ tệp `.html`, nhưng app chưa đọc được tệp theo đường đó.
- ℹ️ **Trang Giấy phép:** giữ lại, vì giấy phép MIT, BSD, Apache và OFL bắt buộc phải kèm thông báo bản quyền.

---

## 4. Handy Boards

### 4.1 Bố cục hiện tại

- **Trang bảng:**
  - dải màu cam đất: tên bảng, số việc đang mở và trễ, ngày quan trọng gần nhất;
  - màn rộng có thêm nút "Lọc" và nút vàng "Thẻ mới";
  - ô nhóm 2×2 (màn rộng xếp 4 ô một hàng);
  - thanh tuần;
  - hàng chip cột;
  - Kanban.
- **Kanban trên điện thoại:** mỗi lần thấy 1 cột, cột kề ló ra hai bên để thả thẻ. Cột đầu và cột cuối thẳng lề nhờ `_LaneSnap`.
- **Màn rộng:** thanh bên 248pt và các cột chia đều.

### 4.2 Tính năng thêm trong đợt này (10/11)

| Tính năng                             | Mô tả                                                                                                                                                 | Commit                 |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| **Cam đất và icon mới**               | Màu nhấn `#B53C0A`, dải `#7C2D12`, icon khung 3 cột. Bộ vẽ icon nay hỗ trợ đường even-odd, nên icon đơn sắc của Android vẫn giữ được lỗ khung.        | `182c5cdc`             |
| **Công tắc "Hiện việc con trên thẻ"** | Thay cho nút có chữ đổi qua lại                                                                                                                       | `715faa70`             |
| **Tạo việc con**                      | Menu "⋯" của thẻ có "Thêm việc con" (mở thẻ, bật sẵn bàn phím). Chi tiết thẻ có nút "Việc con n/m".                                                   | `18734754`             |
| **Thùng rác 30 ngày**                 | Mỗi thẻ ghi "còn N ngày"; mở app là tự dọn thẻ hết hạn                                                                                                | `b466234b`             |
| **Kéo thẻ**                           | Cột sẽ nhận thẻ sáng lên (nền nhạt màu cam đất, viền 2pt)                                                                                             | `69d470c7`             |
| **Kéo cả cột**                        | Nhấn giữ đầu cột rồi kéo, cột đích sáng lên                                                                                                           | `57d904d0`             |
| **Ngày quan trọng có giờ**            | Giờ không bắt buộc (lưu dạng `HH:MM`). Dòng dưới tên bảng ghi "lúc 8:30, còn 3 ngày"; đúng ngày thì đếm giờ. Trong bảng sửa, mỗi mốc nằm trên 2 dòng. | `01ed112d`, `b21e5fe0` |
| **Trang Bảng đã lưu trữ**             | Ảnh bìa, số thẻ xong và đang mở, các nhóm, mốc gần nhất, ngày lưu trữ, lần sửa cuối; nút Khôi phục và Xoá vĩnh viễn                                   | `610db7bd`             |
| **Giải thích ô khi tạo từ mẫu**       | Mọi ô của 30 mẫu có khung "Trên bảng: …" với câu trả lời đang nhập                                                                                    | `dc87ac7e`             |
| **Công tắc "Thẻ ở đây là đã xong"**   | Giữ lại (chủ chọn), thêm dòng giải thích                                                                                                              | `2291652c`             |

### 4.3 Lỗi và góp ý đã sửa

| Chủ báo                                                       | Nguyên nhân                                                                                                                                          | Cách sửa                                                                       | TT  |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | --- |
| Lệch lề, thiếu khoảng đệm, khoảng trống lạ                    | Bản dựng pastel đầu tiên làm vội                                                                                                                     | Dựng lại đúng bản phác, rà lại cả màn                                          | ✅  |
| Trạng thái "đang chọn" của ô nhóm xấu                         | Chỉ có viền                                                                                                                                          | Nền đậm hơn kèm dấu tích, các ô khác mờ đi                                     | ✅  |
| Đổi tuần mà các cột không có chuyển động                      | Thiếu hiệu ứng                                                                                                                                       | `PeriodSlide`: trượt và mờ theo hướng đổi kỳ                                   | ✅  |
| Mất phần cột kề ló ra để kéo thẻ; cột đầu và cuối thụt vào    | Tính sai lề                                                                                                                                          | `_LaneSnap`: lề 16, cột kề ló 32                                               | ✅  |
| Trang Pro báo "chưa bán"                                      | Build thiếu biến môi trường mua hàng                                                                                                                 | Luôn build kèm `monetization-defines`                                          | ✅  |
| Xem trước mẫu "1 tháng" không có nút đổi thời gian            | Thiếu thanh thời gian                                                                                                                                | Thêm thanh thời gian vào bảng xem trước                                        | ✅  |
| Bảng "Chuyển tới" có nút radio, không biết thẻ đang ở cột nào | Bố cục cũ                                                                                                                                            | Tô cột hiện tại kèm "Đang ở đây · N thẻ", thêm nút Lên đầu và Xuống cuối       | ✅  |
| Bảng xem trước cần thẻ mẫu và cho biết đó là thẻ mẫu          | Không có                                                                                                                                             | Thẻ mẫu mang nhãn "Ví dụ" kèm dòng ghi chú                                     | ✅  |
| "Việc của tôi" cần có bản free                                | Bị khoá Pro                                                                                                                                          | Mở free; các thao tác bên trong vẫn là Pro                                     | ✅  |
| Chữ trên trang Pro cần màu khác                               | Cột Pro không nổi bật                                                                                                                                | Tô màu nhấn cho cột Pro                                                        | ✅  |
| Lưu "Ngày quan trọng" thì ra **màn đỏ**                       | Các ô tên bị huỷ ngay khi bảng bắt đầu đóng; bàn phím đóng làm ô dựng lại với dữ liệu đã huỷ                                                         | Bảng tự quản lý các ô của nó; có test giả lập bàn phím đóng                    | ✅  |
| Dấu ✅ nằm ở cột "Chưa bắt đầu"                               | Cột đó đang bật "Thẻ ở đây là đã xong". Mẫu đặt đúng cờ cho cột "Hoàn thành"; chưa rõ vì sao cột kia bị bật (không đọc được dữ liệu trên BlueStacks) | Giữ công tắc, thêm dòng giải thích; người dùng tự tắt ở menu "⋯" của cột       | ℹ️  |
| Hai nút "Hiện thẻ gọn" / "Hiện việc con" khó hiểu             | Thật ra là một nút có chữ đổi qua lại                                                                                                                | Đổi thành một công tắc cố định                                                 | ✅  |
| Không thấy cách tạo thẻ con                                   | Ô "Thêm việc con" nằm sâu dưới cùng                                                                                                                  | Thêm hai lối vào (xem 4.2). Chủ chọn giữ việc con, không làm thẻ con lồng nhau | ✅  |
| Lưu trữ bảng nên là trang riêng, nhiều thông tin hơn          | Chỉ là một bảng nhỏ                                                                                                                                  | Trang riêng (xem 4.2)                                                          | ✅  |
| Thùng rác cần ghi rõ thời gian                                | Chỉ ghi "xoá N ngày trước"                                                                                                                           | Tự xoá sau 30 ngày, mỗi thẻ ghi còn bao nhiêu ngày (chủ chọn 7a)               | ✅  |
| Mục cần Pro phải có nhãn Pro                                  | Thiếu ở vài lối vào                                                                                                                                  | Bộ lọc, Mẫu thẻ, nhóm Tự động hoá                                              | ✅  |
| Nên đổi màu khác hồng và đổi icon                             | Chủ muốn                                                                                                                                             | Cam đất và icon khung 3 cột (`182c5cdc`)                                       | ✅  |

---

## 5. Thay đổi trong kit dùng chung (`packages/handy_ui`)

- **`HandyPalette`:** ở bản sáng, màu nhận diện được làm đậm tới mức đọc được (hổ phách, ô liu).
- **`motion.dart`:** thêm `HandyAppear`; `HandyReveal` an toàn khi bật giảm chuyển động.
- **Snackbar:** đặt `persist: false` trong các tiện ích của kit.
- **Font:** khai báo tệp giấy phép OFL của Geist và Bricolage.

## 6. Kiểm tra

- **Test tự động (10/11):**
  - Bookmark: 307 test;
  - engine Bookmark: 153 test;
  - Boards: 96 test;
  - engine Boards: 168 test;
  - `handy_ui`: 10 test.

  Lần chạy cuối của mọi bộ đều qua. Có thêm các test mới: gửi/nhận, ảnh offline, kéo cột, cột sáng khi kéo, lưu ngày quan trọng, cả 30 mẫu, trang lưu trữ, thùng rác 30 ngày, màu mục đang chọn.

- **Thiết bị:** đã cài và kiểm tra bằng mắt trên BlueStacks 5555 (dọc) và 5575 (ngang 1280×720pt). Đây là máy giả lập, không phải máy thật.
- **Còn hỏng từ trước:** một số cảnh trong bộ chụp ảnh review (`tool/screens_test.dart`) của cả hai app. Kịch bản vẫn bấm vào những nút đã dời chỗ trong đợt làm lại. Test thật của app không bị ảnh hưởng.

## 7. Việc còn mở

- 🟡 **Nhận tệp qua nút chia sẻ của Android** (Bookmark): để sau.
- 🟡 **Ẩn Handy Bookmark khỏi bảng chia sẻ cho tệp `.html`:** chưa làm, đi cùng mục trên.
- 🟡 **Ảnh review:** cập nhật kịch bản các cảnh đang hỏng.
- 🟡 **Bản phát hành mới lên Play** (closed testing) gồm các thay đổi từ 9/11: chưa làm. Phát hành production là việc tay của chủ.
- ⏸ **Gửi bằng link qua winka.top:** tạm bỏ. Nếu làm lại cần mã SHA-256 của khoá ký trong Play Console và quyền deploy trang.
