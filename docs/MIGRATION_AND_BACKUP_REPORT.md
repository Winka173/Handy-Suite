# Migration và sao lưu (refactor 2026-11)

Mỗi thay đổi dữ liệu ghi: phiên bản, cách đọc dữ liệu cũ, khứ hồi sao lưu, test.

| App | Thay đổi | Phiên bản | Dữ liệu cũ | Test |
| --- | --- | --- | --- | --- |
| Docs | QR chạy thành thử nghiệm | Không đổi định dạng; cờ `qr-transfer` trong danh sách favorites của cài đặt | Cài đặt cũ đọc nguyên; tính năng không lưu lịch sử | `apps/handy_docs/test/transfer_test.dart` |
| Keep | Bỏ "Đo bằng ảnh" | Không đổi | Ghi chú đo cũ là văn bản thường, giữ nguyên | `apps/handy_keep/test/measure_test.dart` |
| Keep | Bộ sưu tập, hồ sơ món, wishlist, ảnh phụ, trường riêng | Trạng thái Keep 3 → 4 | v1–3 đọc nguyên; món cũ không thêm khoá nào khi ghi lại; ID, QR `handy-keep://item/<id>`, hóa đơn, ảnh bìa không đổi | `packages/handy_inventory/test/collections_test.dart` |

## Keep 3 → 4

- Mọi trường mới là tuỳ chọn. Ghi lại một món v3 cho ra đúng JSON cũ (test
  "a version 3 library loads as it was").
- Bản sao lưu ZIP v4 có thêm tham chiếu `gallery` (kèm `index`); app cũ (v3) từ
  chối ZIP v4 vì số phiên bản, không đọc sai.
- Hạ cấp: app bản cũ không mở được thư viện v4 (từ chối, không ghi đè). Muốn quay
  lại bản cũ thì xuất ZIP trước.
- Rủi ro còn mở: thư viện Keep (dữ liệu + ảnh) là một JSON tối đa 16 MB; ZIP tối
  đa 255 tệp, 28 MB ảnh. Bộ sưu tập nhiều ảnh cần tách lưu ảnh (S2c) trước khi
  phát hành giao diện bộ sưu tập.
