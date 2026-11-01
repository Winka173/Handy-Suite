# Handy Suite

Monorepo Flutter 3.44.9 / Dart 3.12.2 gồm bảy ứng dụng local-first:

| App          | Source              | Chức năng                                             |
| ------------ | ------------------- | ----------------------------------------------------- |
| Handy Docs   | `apps/handy_docs`   | Markdown, scanner, PDF, reader                        |
| Handy Media  | `apps/handy_media`  | Quick Tools, Capture & Annotate, video                |
| Handy Tools  | `apps/handy_tools`  | Calculator/converter, password, QR                    |
| Handy Dev    | `apps/handy_dev`    | Data tools và HTTPS API client                        |
| Handy Keep   | `apps/handy_keep`   | Đồ dùng, hóa đơn, cho mượn, nhắc hạn                  |
| Handy Recall | `apps/handy_recall` | Flashcard, spaced repetition, image occlusion         |
| Handy Save   | `apps/handy_save`   | Lưu link offline, bộ sưu tập, tìm kiếm, Focus, backup |

Không backend hoặc cloud AI. Mô hình Free + Ads + Pro Lifetime.

## Bắt đầu

```powershell
./tooling/flutter-bootstrap.ps1
dart run melos run analyze --no-select
dart run melos run test --no-select
Set-Location apps/handy_tools
flutter run -d windows
```

Android cần Java 21/Android SDK; Windows cần Visual Studio C++ toolchain; iOS cần
macOS/Xcode. Python 3 dùng cho công cụ QA. Xem [hướng dẫn phát triển](docs/DEVELOPMENT.md).

## Tài liệu

- [Toàn bộ chức năng](docs/FUNCTIONS.md).
- [Trạng thái triển khai và kiểm thử](FEATURE_MATRIX.md).
- [Lỗi và giới hạn](KNOWN_ISSUES.md).
- [Cấu hình Ads + Pro Lifetime](docs/STORE_SETUP.md).
- [Ảnh review UI](docs/UI_REVIEW.md).
- [Handy Save: chức năng và bằng chứng kiểm thử](docs/HANDY_SAVE_FEATURE_MATRIX.md).

Node 22.13+ chỉ phục vụ QA RE2/PWA và format tài liệu: `npm ci --ignore-scripts`,
`npm run typecheck`, `npm run format:check`. Sau khi build Web cả bảy app, chạy
`npm test` cho các test RE2/PWA và giao thức Web Share Target trong Node VM.

Các ứng dụng đang được phát triển. Kiểm thử hiện có không thay thế kiểm thử thiết
bị thật, iOS, browser runtime, giao dịch store hoặc chứng nhận phát hành.
