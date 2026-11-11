# Handy Suite

Monorepo Flutter 3.44.9 / Dart 3.12.2 gồm mười một ứng dụng local-first:

| App            | Source                | Chức năng                                                                                |
| -------------- | --------------------- | ---------------------------------------------------------------------------------------- |
| Handy Docs     | `apps/handy_docs`     | Markdown, scanner, PDF, reader                                                           |
| Handy Media    | `apps/handy_media`    | Quick Tools, Capture & Annotate, video                                                   |
| Handy Tools    | `apps/handy_tools`    | Calculator/converter, password, QR                                                       |
| Handy Dev      | `apps/handy_dev`      | Data tools và HTTPS API client                                                           |
| Handy Keep     | `apps/handy_keep`     | Đồ dùng, hóa đơn, cho mượn, nhắc hạn                                                     |
| Handy Recall   | `apps/handy_recall`   | Flashcard, spaced repetition, image occlusion                                            |
| Handy Bookmark | `apps/handy_bookmark` | Lưu link offline, bộ sưu tập, tìm kiếm, Focus, backup                                    |
| Handy Spend    | `apps/handy_spend`    | Sổ thu/chi, ngân sách, Safe to Spend, forecast, Financial Sandbox                        |
| Handy Habit    | `apps/handy_habit`    | Positive/reduction habits, routines, Progress, mood, backup/sync and Pro Lifetime |
| Handy Trip     | `apps/handy_trip`     | Lịch trình offline, địa điểm, check-in xác nhận, nhật ký, hành lý và chi tiêu            |
| Handy Boards   | `apps/handy_boards`   | Category-first tasks, Kanban, planner, optional Study, local backup                      |
| Handy Forms    | `apps/handy_forms`    | Thiết kế form, thu thập offline, phiên bản bất biến, báo cáo và backup (đang hoàn thiện) |
| Handy Card     | `apps/handy_card`     | Thiết kế thẻ, scene graph, hồ sơ, export và ZIP project                                  |
| Handy Widget   | `apps/handy_widget`   | Theme gốc, Widget Studio, ảnh/lịch/đồng hồ native và backup — đang triển khai            |

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

- [Handy Trip: chức năng và bằng chứng kiểm thử](docs/handy_trip/FEATURE_MATRIX.md).

- [Toàn bộ chức năng](docs/FUNCTIONS.md).
- [Trạng thái triển khai và kiểm thử](FEATURE_MATRIX.md).
- [Lỗi và giới hạn](KNOWN_ISSUES.md).
- [Cấu hình Ads + Pro Lifetime](docs/STORE_SETUP.md).
- [Ảnh review UI](docs/UI_REVIEW.md).
- [Handy Bookmark: chức năng và bằng chứng kiểm thử](docs/HANDY_BOOKMARK_FEATURE_MATRIX.md).
- [Handy Spend: chức năng và bằng chứng kiểm thử](docs/handy_spend/FEATURE_MATRIX.md).
- [Handy Habit: features/evidence](docs/handy_habit/FEATURE_MATRIX.md), [Free/Pro](docs/handy_habit/FREE_PRO.md), [host QA](docs/handy_habit/TEST_RESULTS.md), [release checklist](docs/handy_habit/RELEASE_CHECKLIST.md). Schema9; privacy URL pending owner, device/OAuth/Billing gates remain.

Node 22.13+ chỉ phục vụ QA RE2/PWA và format tài liệu: `npm ci --ignore-scripts`,
`npm run typecheck`, `npm run format:check`. Sau khi build Web cả chín app, chạy
`npm test` cho các test RE2/PWA và giao thức Web Share Target trong Node VM.

Các ứng dụng đang được phát triển. Kiểm thử hiện có không thay thế kiểm thử thiết
bị thật, iOS, browser runtime, giao dịch store hoặc chứng nhận phát hành.

Handy Boards is in progress: [feature matrix](docs/HANDY_BOARDS_FEATURE_MATRIX.md).
