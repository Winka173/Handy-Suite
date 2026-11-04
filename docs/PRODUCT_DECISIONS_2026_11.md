# Quyết định sản phẩm 2026-11 (refactor 14 app)

Nguồn: master prompt "Handy Suite — refactor 14 app" do chủ sản phẩm gửi ngày
2026-11-04. Khi tài liệu cũ (spec, `docs/UX_REDESIGN.md`) xung đột với các quyết
định dưới đây, quyết định này thắng; source thực tế quyết định cách migration.
Kế hoạch và trạng thái từng việc: [REFACTOR_AUDIT](REFACTOR_AUDIT.md).

## Đã chốt

1. Giữ đúng 14 app độc lập: Tools, Docs, Media, Dev, Keep, Recall, Bookmark,
   Spend, Habit, Trip, Boards, Card, Forms, Widget. Không mở app thứ 15, không có
   Handy Auto, không tách Handy Collect: Collections nằm trong Keep.
2. Mỗi app tự cài và chạy một mình. Gói dùng chung chỉ ở build-time; deep link giữa
   các app là tiện ích, không phải điều kiện.
3. Offline-first, không backend bắt buộc, không tài khoản, không cloud AI, không
   subscription. Free + Ads + Pro Lifetime. Sao lưu/khôi phục dữ liệu cá nhân luôn
   miễn phí. Không quảng cáo trong luồng nhạy cảm, chỉnh sửa hay xuất quan trọng.
4. Android/iOS là mục tiêu phát hành ưu tiên; Windows/Web giữ chức năng hiện có.
   Không báo iOS đã build/test khi chưa có macOS/Xcode và thiết bị.
5. Không mất dữ liệu: ID, lịch sử, ảnh, hóa đơn, phiên bản form, template, dự án.
   Mọi việc bỏ tính năng đi kèm migration/compatibility.
6. Không thêm rule/automation engine chung cho cả suite.
7. **Ngoại lệ bắt buộc:** giữ và nâng cấp Xưởng làm tem của Handy Trip, đưa lên
   rõ trong Passport và chi tiết lượt ghé.

## Bốn trạng thái

| Trạng thái    | Nghĩa                                                                           |
| ------------- | ------------------------------------------------------------------------------- |
| KEEP_CORE     | Giữ, đặt ở luồng chính                                                          |
| KEEP_ADVANCED | Giữ và chạy được, dời vào Nâng cao/Thêm                                         |
| RETIRE        | Bỏ khỏi UI mặc định, ngừng phát triển; dữ liệu cũ vẫn đọc, xuất, khôi phục được |
| ADD/IMPROVE   | Làm thật end-to-end: lưu trữ, trạng thái rỗng/lỗi, test, nhập/xuất              |

## Quyết định thay cho việc đã làm trước đó

Các việc vòng 3–4 (2026-11-03) bị quyết định mới thay đổi:

- Docs "Gửi sang máy khác" (QR chạy): **RETIRE/FREEZE**, chỉ còn trong mục Thử
  nghiệm, mặc định tắt, tới khi thử với máy nhận thật.
- Keep "Đo bằng ảnh": **RETIRE khỏi Keep**; công cụ chính thức ở Tools. Ghi chú
  đo cũ giữ nguyên.
- Boards: trường người phụ trách và luồng bình luận **RETIRE khỏi UI cá nhân mặc
  định**; bình luận cũ chuyển sang ghi chú/nhật ký, vẫn có trong bản xuất.
- Boards: màu chàm #6366F1 trong hợp đồng cũ là lỗi thời; màu của Boards là
  #A61C8E.
