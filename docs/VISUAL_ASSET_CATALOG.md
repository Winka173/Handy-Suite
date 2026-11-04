# Danh mục tài nguyên hình ảnh (refactor 2026-11)

Chỉ đếm thứ có trong repo và chạy được; mỗi mục ghi cách kiểm chứng. "Khác nhau"
nghĩa là khác bố cục/hình dạng/hoạ tiết, không phải đổi màu.

| App | Tài nguyên | Số lượng thật | Nguồn và giấy phép | Kiểm chứng |
| --- | --- | --- | --- | --- |
| Trip | Kiểu tem | 40 kiểu, 7 nhóm (Du lịch 6, Cổ điển 6, Dấu bưu điện 6, Tem thư 6, Vé 6, Tối giản 4, Dễ thương 6) | Vẽ bằng code (`stamp_design.dart`), tác phẩm của dự án; phông chữ của app | Test: 40 id, 40 chữ ký `shape/edge/decor/weight` khác nhau, mọi kiểu vẽ được chữ tiếng Việt; ảnh tổng hợp `tool/screens_test.dart` → `stamp-catalogue` |
| Keep | Bộ mẫu | 1 kệ, 4 món board game (chữ, không ảnh) | Văn bản của dự án | `apps/handy_keep/test/collections_ui_test.dart` |
| Card | Mẫu thiết kế | 144 mẫu = 11 vẽ tay + 44 bố cục × 2–3 phong cách (133); 55 bố cục khác nhau | Dựng bằng phần tử của scene graph trong code (`templates.dart`, `template_library.dart`); phông có sẵn của app | Test hình học mặt trước duy nhất, phần tử trong trang; ảnh tổng hợp `contact-sheet-gallery` |
| Widget | Chủ đề / hình nền / trang trí | Theo phiên Widget: 40 / 80 / 240, chưa qua duyệt khác biệt | `docs/handy_widget/` | S10 |
| Media | Nền/khung ảnh chụp màn hình | 6 nền phẳng + khung điện thoại/trình duyệt (chưa mở rộng) | Vẽ bằng code | S5 |

Không có ảnh tải từ mạng, không logo hay nhân vật của bên thứ ba trong các mục
trên.
