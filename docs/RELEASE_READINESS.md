# Release readiness (2026-11-04)

Trạng thái thật, tách theo mức kiểm chứng. "Code + test trên máy" không phải
"đã chạy trên thiết bị". Không mục nào ở đây được nâng mức nếu chưa có log/bằng
chứng trong `docs/qa/evidence`.

| Mức                                            | Trạng thái                                                                                                                                                |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Unit + widget test trên Windows (host)         | 12 app đã commit và các gói dùng chung: chạy bằng `dart run melos run test --no-select`. Forms/Widget có test riêng của phiên kia, chưa commit            |
| Android emulator                               | Một số luồng: xuất/khôi phục Docs, codec Media, quyền thông báo Keep, giải mã QR Tools; Forms quyền camera/GPS; Widget đặt/giữ qua khởi động lại (API 35) |
| Android thiết bị thật                          | **BLOCKED**: chưa có thiết bị trong môi trường này                                                                                                        |
| iOS simulator / thiết bị                       | **BLOCKED**: cần macOS + Xcode + ký; chưa build lần nào                                                                                                   |
| Windows thật                                   | OCR Docs, tự sao lưu thư mục, thông báo Windows, ghi/đọc Forms và Widget                                                                                  |
| Web                                            | PWA worker test sau khi build; Forms, Widget chạy offline trên Edge                                                                                       |
| Store, Ads, IAP                                | **BLOCKED**: chưa có tài khoản store, ID quảng cáo, sản phẩm; không giao dịch thật                                                                        |
| Thông báo nền (app đã đóng, sau khởi động lại) | Chưa kiểm chứng                                                                                                                                           |

## Để gỡ BLOCKED

1. Android thật: cài APK debug từng app, chạy `integration_test/tour_test.dart`
   bằng `python tooling/device-tour.py --device <serial>` (đã có), cộng ma trận ở
   master prompt mục 7.1 (cài mới, nâng cấp có dữ liệu, quyền bị từ chối, thông báo
   sau khi tắt app/khởi động lại, widget, xuất/khôi phục).
2. iOS: máy Mac có Xcode, tài khoản Apple Developer; `flutter build ios` từng app,
   bật App Groups cho Bookmark (Share Extension) và Widget (WidgetKit); chạy trên
   simulator rồi thiết bị.
3. Store: tạo sản phẩm Pro Lifetime và ID quảng cáo theo `docs/STORE_SETUP.md`,
   điền `config/monetization.json` (không commit), thử mua/khôi phục/hoàn tiền
   trong sandbox.
