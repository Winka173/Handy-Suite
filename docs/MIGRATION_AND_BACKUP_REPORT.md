# Migration và sao lưu (refactor 2026-11)

Mỗi thay đổi dữ liệu ghi: phiên bản, cách đọc dữ liệu cũ, khứ hồi sao lưu, test.

| App | Thay đổi | Phiên bản | Dữ liệu cũ | Test |
| --- | --- | --- | --- | --- |
| Docs | QR chạy thành thử nghiệm | Không đổi định dạng; cờ `qr-transfer` trong danh sách favorites của cài đặt | Cài đặt cũ đọc nguyên; tính năng không lưu lịch sử | `apps/handy_docs/test/transfer_test.dart` |
| Keep | Bỏ "Đo bằng ảnh" | Không đổi | Ghi chú đo cũ là văn bản thường, giữ nguyên | `apps/handy_keep/test/measure_test.dart` |
| Keep | Tệp thư viện trên máy: ảnh tách ra kho byte | `handy-keep-local` 1 → 2 | v1 (ảnh base64 nhúng) đọc được, chuyển khi lưu lần tới; ID ảnh không đổi | `apps/handy_keep/test/blob_storage_test.dart` |
| Trip | Tem đã giữ trên lượt ghé | Trường tuỳ chọn `visit.stamp`, không đổi số phiên bản | Lượt ghé cũ không có tem, đọc nguyên; bản sao lưu đầy đủ mang theo tem | `packages/handy_trip_engine/test/stamps_test.dart` |
| Keep | Bộ sưu tập, hồ sơ món, wishlist, ảnh phụ, trường riêng | Trạng thái Keep 3 → 4 | v1–3 đọc nguyên; món cũ không thêm khoá nào khi ghi lại; ID, QR `handy-keep://item/<id>`, hóa đơn, ảnh bìa không đổi | `packages/handy_inventory/test/collections_test.dart` |
| Dev | Lịch sử gửi opt-in | Kho mới `handy-dev-history`, `version: 1` | Không có dữ liệu cũ; tệp hỏng thì bắt đầu lại ở trạng thái tắt; không nằm trong bản xuất workspace hay cài đặt | `packages/handy_dev_engine/test/history_test.dart`, `apps/handy_dev/test/history_test.dart` |
| Docs | Tệp đã giữ: 50 → 500 trong ngân sách 8 MB | `handy-reader-library` và `handy-reader-pack` 1 → 2 chỉ khi > 50 tệp | v1 đọc nguyên; ≤ 50 tệp vẫn ghi v1; bản app cũ từ chối v2 rõ ràng (không đọc thiếu) | `packages/handy_docs_engine/test/reader_limit_test.dart` |

## Keep 3 → 4

- Mọi trường mới là tuỳ chọn. Ghi lại một món v3 cho ra đúng JSON cũ (test
  "a version 3 library loads as it was").
- Bản sao lưu ZIP v4 có thêm tham chiếu `gallery` (kèm `index`); app cũ (v3) từ
  chối ZIP v4 vì số phiên bản, không đọc sai.
- Hạ cấp: app bản cũ không mở được thư viện v4 (từ chối, không ghi đè). Muốn quay
  lại bản cũ thì xuất ZIP trước.
- Từ S2c ảnh không còn nằm trong JSON 16 MB của thư viện. Giới hạn còn lại nằm ở
  bản sao lưu ZIP: tối đa 255 tệp, 28 MB ảnh mỗi ZIP.
- Bản lưu dự phòng (Cài đặt → khôi phục) giữ tệp dữ liệu; ảnh của nó vẫn ở kho
  byte và không bị dọn khi đặt lại, nên hoàn tác thấy lại ảnh.
