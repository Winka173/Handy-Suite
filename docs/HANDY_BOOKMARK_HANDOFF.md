# Handy Bookmark — handoff (07/11/2026)

Tạm dừng để làm project khác. Đọc file này trước khi làm tiếp Handy Bookmark
(`apps/handy_bookmark`, nhánh `ui-rebuild`). Chi tiết phát hành nằm ở
`docs/HANDY_BOOKMARK_RELEASE.md`; các hợp đồng UX ở cuối `docs/UX_REDESIGN.md`
(mục "Hợp đồng: Handy Bookmark · …"); giới hạn đã biết ở
`docs/HANDY_BOOKMARK_KNOWN_LIMITATIONS.md`.

## 1. Đang ở đâu

| Mục | Trạng thái |
|---|---|
| Google Play | App `com.apps.winka.handybookmark` đã qua lượt duyệt đầu. Kiểm thử kín (`alpha`): **1.0.0 (5)** đã phát hành (qua fastlane), nhóm tester `testers-community@googlegroups.com`, link tham gia Android/web đã có. Code 1–5 đã dùng; bản sau phải là `+6`. |
| Trang store | EN (mặc định) + VI: chữ, icon, ảnh bìa, 6 ảnh màn hình mỗi ngôn ngữ, email `apps.winka.studio@gmail.com`, web repo GitHub. Danh mục Năng suất; thẻ Năng suất, Sổ tay, Công cụ. App content đã điền (riêng tư, đăng nhập, IARC, độ tuổi 13+, Data safety "không thu thập", người bán, điều khoản). |
| Pro | Sản phẩm `handy_bookmark_pro`, mua một lần, **99.000đ** (VN), Play tự quy đổi (US 3,89 USD), đang ACTIVE. App tin kết quả Google Play (không khoá giấy phép; xem commit `b99521b`). |
| Đồng bộ Google Drive | Code xong (`lib/sync/drive_*.dart`), có từ 1.0.0 (4) (build với `HANDY_DRIVE_SYNC=true`). Client OAuth Android cho debug/upload/Play signing do chủ tài khoản tạo trên Google Cloud, trong **project riêng "Handy Bookmark"** (không dùng `play-publisher-513712`), màn đồng ý đã Publish; các bước ở `docs/HANDY_BOOKMARK_RELEASE.md` › Google Drive sync. **Chưa chạy thật giữa hai máy.** |
| Repo | Mọi việc của phiên đã commit + push (commit cuối của Bookmark: `b99521b`). Còn `apps/handy_bookmark/web/manifest.json` (chỉ khác xuống dòng) và `docs/HANDY_BOOKMARK_HO_SO_DAY_DU.html` (của người khác) chưa commit — không phải của phiên này. |
| Thiết bị | BlueStacks `127.0.0.1:5556` (dữ liệu thật của người dùng) và `127.0.0.1:5575`, kiểm `ro.product.model == SM-S908E` trước khi cài; không dùng 5555/emulator-5554. Cả hai có bản debug mới nhất; 5556 là bản có cờ Drive. |

## 2. Làm trong đợt này (theo thứ tự commit)

- Đọc tiêu đề + hình cho Facebook (post/reel), TikTok (khối JSON), Instagram, YouTube, X/Threads (nội dung bài làm tiêu đề), Reddit (oEmbed, không có hình), Vimeo (WebP); bắt trang đăng nhập/"Make Your Day" và thử lại (`7600cd5`).
- Icon mới (hai bookmark), adaptive icon Android + monochrome; ô bộ sưu tập ở hàng đầu khung chia sẻ Android là nền nhạt + chữ cái (`38cda8f`).
- Khung lưu khi chia sẻ (Flutter trong `ShareSheetActivity`, entry `shareSheet`): link vào hàng chờ trước, khung chỉ thêm lựa chọn; một chạm vào bộ sưu tập là cho vào và hiện thẻ "Đã lưu vào …"; tạo bộ mới tại chỗ; không liệt kê chỗ đang ở; ô bộ sưu tập hàng đầu cũng mở khung (`94e298b`, `a61066c`, `1f37436`, `ea3e36e`).
- Hiệu ứng đang đọc trang: làm tối + vòng xoay (`ReadingShade`).
- Màn chào: thêm bước khung chọn bộ sưu tập; cảnh Tìm vẽ như màn Tìm thật (`0f2f096`).
- Phát hành: id `com.apps.winka.handybookmark` (debug giữ `com.example.handysuite.bookmark.flutterpilot`), upload key mới, ProGuard cho ML Kit, fastlane + `tool/play.py`, ảnh store sinh từ `tool/screens_test.dart` (`STORE_SHOTS=1`), `PRIVACY.md` + `TERMS.md` và link trong Cài đặt › Giới thiệu (`ea3e36e` … `3f47d52`).
- Pro trên Play + nối cấu hình cửa hàng vào bản build (`d70b19f`), rồi chuyển sang tin Google Play (`b99521b`).
- Đồng bộ Google Drive (`8bee3e1`).

## 3. Việc còn lại (ưu tiên từ trên xuống)

1. **Chạy thật đồng bộ Drive** trên hai máy cùng tài khoản Google (bản cài từ Play, hoặc debug có cờ): lưu ở mỗi máy, một máy mất mạng, xoá rồi khôi phục từ Đã xoá gần đây, ảnh, tắt đồng bộ, thu hồi quyền trong tài khoản Google. Nếu bật báo "Google chưa cho phép": kiểm client OAuth (package + SHA-1) và test users của màn đồng ý OAuth. Ghi kết quả vào `docs/HANDY_BOOKMARK_RELEASE.md` (mục Google Drive sync, dòng "Verified").
2. **Mua Pro thật** từ bản tester: thêm tài khoản tester vào *Cài đặt › Kiểm thử giấy phép* (không bị trừ tiền), mua, gỡ/cài lại rồi Khôi phục giao dịch.
3. API Play từng trả 500 vài giờ sau lượt duyệt đầu (bản 4 tải tay); bản 5 đã lên bình thường bằng `fastlane android publish`. Nếu lại gặp 500: tải tay (Kiểm thử kín › Alpha › Tạo bản phát hành mới) với `build/app/outputs/bundle/release/app-release.aab`.
4. **Link chính sách/điều khoản** đang trỏ nhánh `ui-rebuild`. Khi merge vào `main`: đổi `ui-rebuild` → `main` trong `lib/settings/help_links.dart`, `PRIVACY.md`/`TERMS.md` (link chéo), `docs/HANDY_BOOKMARK_RELEASE.md`, Play Console (Chính sách quyền riêng tư, Điều khoản dịch vụ) và màn đồng ý OAuth.
5. **Data safety** khi Drive sync được dùng: xem lại hướng dẫn của Google về dữ liệu gửi vào Drive của chính người dùng (hiện khai "không thu thập").
6. Lên production: tài khoản cá nhân cần ≥ 12 tester tham gia 14 ngày liên tục; production luôn làm tay.
7. Chưa có: iOS (khung chia sẻ mới, Drive), đồng bộ khi app đóng, Android ↔ iPhone.

## 4. Làm tiếp thế nào

```sh
# gốc repo (PowerShell): giải gói, tạo junction Windows
./tooling/flutter-bootstrap.ps1
# cấu hình cửa hàng (file trên máy, gitignored) → defines cho bản build
python tooling/prepare-store-config.py config/monetization.local.json

# apps/handy_bookmark
flutter analyze --no-pub
flutter test --no-pub --timeout 90s                       # cả bộ: 1 lần trước commit
flutter build apk --debug --no-pub --dart-define=HANDY_DRIVE_SYNC=true

# apps/handy_bookmark/android (Git Bash)
export PATH="/c/Ruby33-x64/bin:$PATH" LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1 FASTLANE_OPT_OUT_USAGE=1
HANDY_DRIVE_SYNC=true fastlane android publish            # preflight, build, tải lên alpha, rollout
```

Trước mỗi bản phát hành: nâng `version: 1.0.0+N` trong `pubspec.yaml`, viết
`android/fastlane/metadata/android/{en-US,vi}/changelogs/N.txt` (≤ 500 ký tự).

**Bí mật (không bao giờ commit, in hay dán):** `~/.secrets/play-publisher.json`
(khoá API dùng chung), `C:\Users\Winka\handy-bookmark-upload.jks` +
`~/.secrets/handy-bookmark-upload.properties` (upload key, đã nhắc sao lưu),
`apps/handy_bookmark/android/key.properties` (gitignored).
`config/monetization.local.json` (gitignored) giữ mã sản phẩm và link store;
khoá giấy phép đã bỏ trống có chủ ý.

## 5. Bản đồ code

| Phần | Ở đâu |
|---|---|
| Đọc trang (tiêu đề, hình) | `lib/services/metadata_native.dart`, `metadata_parser.dart`, `metadata_judge.dart`, `metadata_thumbnail.dart`; thử lại trong `lib/controller.dart` (`refreshMetadata`, `_retryMissing`) |
| Nhận chia sẻ (Android) | `android/.../save/ShareActivity.kt` → `ShareSheetActivity.kt` (Flutter, `shareSheet` trong `lib/main.dart`); hàng chờ `ShareQueue.kt` (`peek`, `amend`); lối tắt bộ sưu tập `ShareTargets.kt` |
| Khung lưu | `lib/share_sheet/` (`snapshot.dart` app ghi sau mỗi thay đổi; `sheet_controller.dart`; `share_sheet.dart`) |
| Nhận vào thư viện | `SaveController.drain` → `_takeLink`, `_collectionNamed`, `_keepRead` |
| Đồng bộ | engine `packages/handy_bookmark_engine/lib/src/sync.dart`; thư mục `lib/sync/folder_sync_io.dart`; Drive `lib/sync/drive_provider.dart`, `drive_sync.dart`, `drive_section.dart` |
| Mua Pro | `packages/handy_store` (Kotlin `HandyStorePlugin.kt`), `packages/handy_monetization` |
| Màn chào | `lib/welcome/rehearsal.dart`, `more_scenes.dart`, `welcome_page.dart` |
| Ảnh store / review | `tool/screens_test.dart` (`STORE_SHOTS=1 STORE_LOCALE=vi|en SHOTS_DIR=…`) |
