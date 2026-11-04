# Refactor audit: 14 app (bắt đầu 2026-11-04)

Quyết định sản phẩm: [PRODUCT_DECISIONS_2026_11](PRODUCT_DECISIONS_2026_11.md).
Mức sẵn sàng phát hành: [RELEASE_READINESS](RELEASE_READINESS.md).

Tài liệu này ghi **baseline đo từ source** (không lấy từ spec), quyết định cho từng
mục, và trạng thái thực hiện. Cột Trạng thái chỉ đổi khi có code + test trong repo:

- `DONE`: đã làm và có test chạy được trên máy (host); chưa phải thiết bị thật.
- `TODO`: chưa làm.
- `HAS`: baseline đã đáp ứng quyết định, không cần sửa.
- `BLOCKED`: thiếu công cụ/quyền/nền tảng; ghi lý do.

## Baseline kỹ thuật

- Monorepo Dart pub workspace + melos; 14 app trong `apps/`, 27 gói trong
  `packages/` (engine thuần Dart, adapter nền tảng, `handy_ui` kit).
- Forms (`apps/handy_forms`, `packages/handy_forms_engine`) và Widget
  (`apps/handy_widget`, `packages/handy_widget_engine`) **chưa được commit**;
  chúng thuộc một phiên làm việc khác. Việc sửa code hai app này chờ phiên đó
  commit, để không trộn công việc của hai phiên (xem mục Forms, Widget).
- Kiểm thử baseline: `dart run melos run test --no-select` chạy ngày 2026-11-04;
  kết quả ghi ở cuối tài liệu.
- Chưa có thiết bị Android thật, chưa có macOS/Xcode: mọi mục native ghi
  `BLOCKED` cho tới khi có môi trường.

## Thứ tự thực hiện

| Lát | Nội dung | Trạng thái |
| --- | --- | --- |
| S0 | Audit, quyết định, baseline test, release readiness | DONE |
| S1 | Việc bỏ/ẩn nhỏ, giữ dữ liệu: Docs QR → Thử nghiệm; Keep bỏ Đo bằng ảnh; hợp đồng màu Boards | DONE |
| S2a | Keep Collections: dữ liệu v4 trong engine (nhiều-nhiều, hồ sơ món, wishlist, completion, ảnh phụ, trường riêng) + sao lưu ZIP | DONE |
| S2b | Keep Collections: giao diện (4 lối vào, gallery, mẫu, wishlist → đã có, demo gỡ được) | DONE |
| S2c | Keep: tách ảnh khỏi tệp thư viện JSON 16 MB (cần cho bộ sưu tập nhiều ảnh) | DONE |
| S3 | Trip: thư viện mẫu tem, Bộ sưu tập tem trong Passport, tạo tem một chạm sau lượt ghé | DONE |
| S4 | Card: thư viện mẫu lớn (120–200 thiết kế khác nhau thật), contact sheet, kiểm tra trùng | DONE (144 mẫu, 55 bố cục) |
| S5 | Media: thư viện nền/khung/thẻ hướng dẫn 9:16 cho ảnh chụp màn hình | DONE |
| S6 | Tools: Gần đây/Ghim, preset VAT/giảm giá/% thay đổi; nhóm công cụ theo tình huống | TODO |
| S7 | Recall demo deck; Habit 20–40 preset; Spend lặp giao dịch/yêu thích | TODO |
| S8 | Dev: lỗi JSON theo dòng/cột, copy JSON pointer, lịch sử request có che | TODO |
| S9 | Boards: bỏ người phụ trách/bình luận khỏi UI mặc định, mẫu bảng | TODO |
| S10 | Forms, Widget (sau khi phiên kia commit) | BLOCKED |
| S11 | Native Android/iOS, store, Ads/IAP, a11y; tài liệu cuối | BLOCKED (thiết bị) |

## Từng app

### Tools

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Bàn làm việc gõ là ra kết quả, máy tính, %, đơn vị, lương, ngày, VietQR, chia hóa đơn, dọn chữ, đọc số | KEEP_CORE | Có; một màn "bàn", danh mục Ctrl K | HAS |
| Phụ đề, bốc thăm, âm lịch, mật khẩu, đo bằng ảnh, sổ tính | KEEP_ADVANCED | Có, nằm trong danh mục cùng cấp | TODO (nhóm "Thêm") |
| Ghim | ADD | Có (`pinned` trong catalog) | HAS |
| Gần đây, sao chép một chạm, lịch sử tính (opt-in), preset VAT/giảm hai lần/% thay đổi | ADD | Chưa | TODO |

### Docs

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Quét, cắt, OCR → TXT/MD/DOCX, PDF gộp/tách/xoay/ký/đánh số/nén | KEEP_CORE | Có | HAS |
| Markdown, in hai mặt, thư viện tệp UTF-8 | KEEP_ADVANCED | Có, Markdown là ô bắt đầu thứ hai | TODO (hạ cấp) |
| Gửi tệp bằng QR chạy | RETIRE/FREEZE: Thử nghiệm, mặc định tắt | Ô dưới lưới bắt đầu | DONE (S1) |
| Giới hạn 50 tệp đã giữ | Nới theo tài nguyên thật | `reader.dart`: 50 tài liệu | TODO (đổi định dạng lưu cần migration) |
| Preset quét (giấy/hóa đơn/bảng), tên tệp gợi ý từ OCR đã xác nhận, thao tác PDF hàng loạt | ADD | Chưa | TODO |

### Media

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Chú thích, hướng dẫn, sửa ảnh nhanh, nối ảnh, che nhạy cảm có duyệt | KEEP_CORE | Có | HAS |
| GIF/HTML/Markdown, ZIP dự án | KEEP_ADVANCED | Có | TODO (hạ cấp định dạng ít dùng) |
| Quay màn hình iOS ghi đúng là "trong app" | RETIRE nhãn sai | FUNCTIONS đã ghi "nội dung trong app" | HAS (kiểm lại chuỗi UI ở S5) |
| Thư viện nền/khung/thẻ 9:16/preset số bước | ADD | 6 màu nền phẳng + khung điện thoại/trình duyệt | Khung DONE (S5): 12 kiểu nhanh, 4 khổ, 6 nền hai màu, tiêu đề; preset số bước/che trong trình chú thích TODO |

### Dev

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| JSON, JWT (chỉ giải mã), Base64/URL, regex, thời gian, hash, UUID, request, cURL | KEEP_CORE | Có; 22 công cụ | HAS |
| HMAC, hệ cơ số, cron 6 trường | KEEP_ADVANCED | Cùng cấp | TODO |
| Lỗi JSON theo dòng/cột, tìm nhanh trên cây, copy JSON pointer, lịch sử request opt-in có che | ADD | Chưa có vị trí lỗi | TODO |

### Keep

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Hồ sơ món, cho mượn, thùng, QR, bảo hành, giá trị, sao lưu | KEEP_CORE | Có (`handy_inventory`, dữ liệu v3) | HAS |
| Dự đoán sắp hết | KEEP_ADVANCED (hồ sơ Tiêu hao) | Hiện trên "Cần để ý" mặc định | TODO |
| Đo bằng ảnh | RETIRE khỏi Keep | Menu món + "Thêm vào ghi chú" | DONE (S1) |
| Collections, mẫu, hồ sơ động, wishlist, completion, nhiều ảnh/món, demo | ADD P0 | Không có | DONE (S2a dữ liệu, S2b giao diện); nhiều ảnh/món mới có ở dữ liệu, chưa có ô thêm ảnh phụ |
| Lưu ảnh | Rủi ro | Cả thư viện (dữ liệu + ảnh base64) là một JSON tối đa 16 MB; vài chục món có ảnh là chạm trần | DONE (S2c): ảnh ra kho byte riêng |

### Recall

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| SRS, cloze, đảo chiều, che ảnh, Anki, CSV | KEEP_CORE | Có | HAS |
| Chép chính tả, TTS từng mặt, dán ghi chú | KEEP_ADVANCED | Có | HAS (đã ở menu phụ) |
| Demo deck không lẫn thống kê thật, lọc thẻ khó, ôn lại thẻ quên | ADD | Chưa | TODO |

### Bookmark

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Chia sẻ vào, Chưa xếp, bộ sưu tập, trùng, tìm, mở link gốc | KEEP_CORE | Có | HAS |
| Bản đọc offline, Tập trung, kiểm tra link, Bộ lọc đã lưu | KEEP_ADVANCED | Có | HAS |
| Giới hạn hàng loạt có huỷ/giãn cách | DE-SCOPE mặc định không giới hạn | Đã có: 200 bản đọc/lượt, 500 link/lượt, ≥ 2 s mỗi host, Dừng | HAS |
| Thẻ ảnh/dòng, gộp trùng có duyệt, xuất bộ sưu tập | ADD | Có thẻ/dòng; gộp trùng thủ công | TODO |

### Spend

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Ghi một dòng, còn tiêu được, tài khoản, chuyển khoản/hoàn tiền/thẻ, ngân sách, định kỳ, sao kê, BigInt | KEEP_CORE | Có | HAS |
| Kịch bản giả định | RETIRE (đã bỏ 2026-11-03, dữ liệu giữ) | Có | HAS |
| Lặp giao dịch một chạm, giao dịch yêu thích, giải thích đối chiếu | ADD | "Dùng làm mẫu" qua menu sổ | TODO |

### Habit

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Check-in, lịch linh hoạt, chuỗi, kỳ nghỉ, nhắc, quy trình, nhìn lại tuần | KEEP_CORE | Có | HAS |
| 20–40 preset thói quen/quy trình theo nhóm | ADD | `routineTemplates()` có mẫu quy trình; chưa có preset thói quen | TODO |

### Trip

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Lịch trình, đã ghé một chạm, đặt chỗ, hành lý, chi tiêu, nhật ký, Passport, sổ kỷ niệm | KEEP_CORE | Có | HAS |
| **Xưởng làm tem** | KEEP + nâng cấp (ngoại lệ) | 4 dáng × 5 màu mực, chữ vòng, PNG/A4, từ Passport | HAS (giữ) |
| Thư viện 30–60 mẫu tem khác nhau thật, Bộ sưu tập tem, tạo từ lượt ghé | ADD | Chưa | DONE (S3): 40 kiểu, tem lưu trên lượt ghé, "Tem của bạn" trong Hộ chiếu |
| GPX/KML, replay, so sánh chuyến | Không đưa lại | Đã bỏ | HAS |

### Boards

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Khối danh mục, Kanban/Danh sách/Hôm nay/Lịch, checklist, hạn, lặp, mẫu | KEEP_CORE | Có | HAS |
| Phụ thuộc, WIP, trường tùy chỉnh | KEEP_ADVANCED | Có | HAS |
| Người phụ trách, luồng bình luận | RETIRE khỏi UI cá nhân | Có trong chi tiết việc, bộ lọc, xuất | TODO (S9) |
| Màu chàm trong hợp đồng cũ | Sửa tài liệu | `UX_REDESIGN.md` ghi #6366F1 | DONE (S1) |

### Card

| Mục | Quyết định | Baseline | Trạng thái |
| --- | --- | --- | --- |
| Canvas, lớp, bắt dính, chữ/ảnh/hình/QR, nhiều mặt, hồ sơ, xuất | KEEP_CORE | Có | HAS |
| Chữ ký email, trang HTML, dấu cắt | KEEP_ADVANCED | Có | TODO (hạ cấp) |
| 120–200 mẫu khác nhau thật, thư viện tài nguyên, gallery, đổi màu một chạm | ADD | 11 mẫu | Mẫu + gallery DONE (S4); đổi màu một chạm, yêu thích, thư viện hoạ tiết riêng TODO |

### Forms, Widget

Chưa commit, thuộc phiên khác. Các quyết định trong master prompt (Forms: hạ
quy trình/tự động hóa/kiosk xuống tùy chọn, `HandyBrand.forms`, lịch hồ sơ theo
truy vấn thật; Widget: luồng 4 bước, kiểm duyệt trùng hình ảnh, hướng dẫn đặt
widget) được ghi lại ở đây và thực hiện ở S10 khi mã nguồn đã có trong git.

## Nhật ký thực hiện

### S1 (2026-11-04)

- Docs: "Gửi sang máy khác" chỉ hiện khi bật Cài đặt → Thử nghiệm (mặc định tắt);
  đường dẫn `/transfer` vẫn mở được để không gãy link. Không có dữ liệu lưu nào
  bị ảnh hưởng (tính năng không lưu lịch sử).
- Keep: bỏ "Đo bằng ảnh" khỏi menu món; ghi chú "Đo bằng ảnh: ≈ …" đã ghi vẫn
  nằm nguyên trong ghi chú, xem/sửa/xuất như văn bản.
- Boards: hợp đồng thiết kế ghi màu #A61C8E.

### S2a (2026-11-04)

- `handy_inventory` lên dữ liệu phiên bản 4: `collections` (tối đa 200; tên,
  loại, màu nhận diện, ảnh bìa, mục tiêu do người dùng đặt, thứ tự riêng) và
  các trường tuỳ chọn của món: `profile`, `status` (owned/ordered/wanted),
  `priority`, `collections`, `series`/`number`/`variant`/`edition`/`condition`,
  `link`, `budget` + tiền tệ, `photos` (11 ảnh phụ), `fields` (40 trường riêng).
- Món đồ là bản ghi duy nhất: bộ sưu tập chỉ tham chiếu, xoá bộ sưu tập không xoá
  món, xoá món dọn thứ tự và ảnh bìa. Món đang muốn/đang đặt không cho mượn được.
  `markOwned` chuyển wishlist thành đã có trên cùng ID.
- ZIP mang ảnh phụ (vai trò `gallery`, giữ thứ tự); bản sao lưu JSON bỏ đường dẫn
  ảnh phụ như ảnh bìa. Gộp bản sao lưu trong app gộp cả bộ sưu tập.
- 10 loại bộ sưu tập: figure, thẻ, sách/truyện, game, board game, LEGO/mô hình,
  đồng hồ, thiết bị, đồ máy ảnh, khác; mỗi loại gợi ý vài trường riêng. Không có
  danh mục "chính thức" nào được dựng sẵn.
- Test: `packages/handy_inventory/test/collections_test.dart` (8 ca: đọc dữ liệu
  v3 không đổi, nhiều-nhiều, wishlist, completion, giữ giá trị ẩn, từ chối tham
  chiếu sai, ZIP khứ hồi).

## Kết quả test nền (2026-11-04, trước S1)

`dart run melos run test --no-select` trên Windows: **41/41 gói SUCCESS**, gồm cả
`handy_forms`, `handy_forms_engine`, `handy_widget`, `handy_widget_engine` (bản
chưa commit trên máy). Sau S1/S2a: `handy_docs` (transfer 6/6), `handy_keep`
(64/64), `handy_inventory` (61/61) chạy lại đều đạt.

### S2c (2026-11-04)

- `handy_storage/blobs.dart`: kho byte theo id (`BlobRepository`). Native: một
  tệp mỗi mục trong `<support>/<namespace>-blobs/`, tên là SHA-256 của id, đầu
  tệp ghi id và SHA-256 của nội dung, ghi qua tệp tạm rồi đổi tên. Web: CSDL
  IndexedDB riêng `<namespace>-blobs` (không nâng cấp CSDL cũ). Đọc lại luôn kiểm
  SHA-256.
- Keep: tệp thư viện phiên bản 2 chỉ còn dữ liệu; ảnh và hóa đơn nằm trong kho
  byte. Thứ tự ghi: byte mới → dữ liệu → dọn byte mà chính lần chạy này đã bỏ (ảnh
  của bản bị đặt lại vẫn còn để hoàn tác). Thư viện v1 nhúng ảnh vẫn đọc được và
  được chuyển ở lần lưu kế tiếp. Ảnh mất khỏi kho được đếm (`missing`), không làm
  hỏng việc mở thư viện.
- Test: `packages/handy_storage/test/blobs_test.dart`,
  `apps/handy_keep/test/blob_storage_test.dart` (chuyển v1 → v2, 21 MB ảnh,
  ảnh mất, lỗi ghi ảnh giữ thư viện cũ).

### S2b (2026-11-04)

- Keep: kệ bộ sưu tập trên màn chính, trang bộ (`#/collection/<id>`), Muốn có
  (`#/wishlist`), "Đã có rồi", form món có chọn bộ/trạng thái/thông tin sưu tầm,
  bộ mẫu gỡ được. Món muốn có không vào danh sách chỗ để và tổng giá trị.
- Ảnh review đã soát §2.7 hai vòng (bìa không lấy món chưa có, nhãn ngắn, ô
  không ảnh nhạt, form gập trường hiếm).
- Test: `apps/handy_keep/test/collections_ui_test.dart` (kệ mẫu vào/ra, tạo bộ +
  thêm món + muốn có + đã có, món gia dụng lưu như cũ, danh sách muốn có).
- Còn lại cho Keep: ô thêm ảnh phụ (dữ liệu đã có), sắp xếp thứ tự bằng kéo,
  ảnh bìa tự chọn, hồ sơ Tiêu hao để giấu "sắp hết" khỏi màn chính, bản giới thiệu
  bộ sưu tập PDF/PNG (P1).

### S3 (2026-11-04)

- Trip engine: `visit.stamp` (tuỳ chọn) + `saveStamp`, `removeStamp`,
  `stampedVisits`; giá trị được kiểm (kiểu, mực, zoom 1–3, lệch −1..1, nghiêng
  ±12°, mòn 0–1); ảnh chỉ của chính lượt ghé hoặc ảnh bìa chuyến. Đi theo bản
  sao lưu đầy đủ sẵn có.
- Trip app: 40 kiểu tem (7 nhóm), viền mới (đôi, chấm, vỏ sò) và hoạ tiết (sao,
  chấm, tia nắng, dấu huỷ, ruy băng, góc vé); Xưởng có bộ chọn kiểu, "Giữ tem",
  mở lại tem đã giữ; Hộ chiếu có "Tem của bạn" nhóm theo chuyến và in A4 tất cả;
  trang địa điểm có "Làm tem"/"Sửa tem".
- Soát ảnh hai vòng: viền vỏ sò không hiện (vẽ lại thành đường gợn liền có nét
  mực), dấu huỷ đè ngày (dời sang phải/nửa trên), biểu tượng máy in đổi thành con
  dấu cho khớp lời hướng dẫn.
- Test: `packages/handy_trip_engine/test/stamps_test.dart`,
  `apps/handy_trip/test/stamp_styles_test.dart` (40 kiểu khác chữ ký, mọi kiểu vẽ
  được chữ tiếng Việt, giữ tem → Hộ chiếu → mở lại).

### S4 (2026-11-04)

- `handy_card_engine/template_library.dart`: 44 bố cục mới (12 danh thiếp, 6 hồ sơ
  mạng xã hội, 5 bài vuông, 6 thiệp mời A5, 4 CV A4, 5 thẻ giá, 4 thẻ sự kiện, 4 tờ
  rơi A5) × 2–3 phong cách = 133 mẫu; cộng 11 mẫu vẽ tay = 144. Đếm thật: 55 bố cục
  khác nhau; không hai mẫu nào trùng hình học mặt trước (phong cách đổi cả hoạ tiết).
- Sửa lỗi có sẵn: mẫu "Creator" dựng trên khổ A5 do chỉ số khổ lệch sau khi thêm
  A5/A4; nay lấy khổ vuông theo id.
- App: màn chính còn một mẫu mỗi dịp + "Xem cả N mẫu"; Thư viện mẫu có chip dịp và
  lưới dựng lười.
- Test: `packages/handy_card_engine/test/template_library_test.dart` (≥140 mẫu, ≥40
  bố cục, id duy nhất, hình học mặt trước duy nhất, phần tử trong trang, chữ tiếng
  Việt), `apps/handy_card/test/template_gallery_test.dart`. Bảng tổng hợp:
  `tool/screens_test.dart` → `contact-sheet-gallery`.
- Còn lại: đổi màu một chạm cho cả thiết kế, yêu thích mẫu, thư viện hoạ tiết/khung
  riêng, ảnh minh hoạ gốc cho ô ảnh.

### S5 (2026-11-04)

- `handy_media_engine/frame_shot.dart`: nền hai màu (`background2`), khổ (`aspect`:
  1:1, 4:5, 9:16, 16:9; nền nở ra, ảnh ở giữa), dải tiêu đề PNG do app vẽ.
- App: 12 kiểu nhanh, chip khổ, 6 nền hai màu, ô tiêu đề (vẽ bằng phông của Media,
  đủ tiếng Việt); bản xem trước ghim trên, điều khiển cuộn (trước đó cuộn là mất xem
  trước).
- Soát ảnh: thêm tiêu đề trang trên màn rộng, khoảng cách dưới dải kiểu nhanh.
- Test: `packages/handy_media_engine/test/frame_shot_test.dart` (khổ, nền hai màu,
  tiêu đề, khổ lạ bị từ chối), `apps/handy_media/test/frame_page_test.dart` (kiểu
  Story ra đúng 9:16, tiêu đề làm ảnh cao thêm).
