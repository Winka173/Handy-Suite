# Phát triển Handy Suite

Flutter 3.44.9 / Dart 3.12.2. Mười một app trong `apps/handy_*`, 24 package dùng chung
trong `packages/handy_*`; khai báo workspace tại `pubspec.yaml`.

- Engines xử lý dữ liệu thuần Dart; UI nằm trong app/shared UI package.
- Files/storage quản lý giới hạn nhập/xuất, local snapshots và IndexedDB.
- Native plugins cho capture, camera, notifications, PDF và store gọi qua adapter.
- Mỗi app có identity, dữ liệu, cấu hình store và PWA cache riêng.
- Không backend/cloud AI; không lưu token vào log hoặc export mặc định.

## Môi trường

Flutter và Python 3. Android: Java 21 + Android SDK. Windows: Visual Studio C++
desktop toolchain. iOS: macOS/Xcode. Node 22.13+ chỉ phục vụ tooling QA trình duyệt.

```powershell
./tooling/flutter-bootstrap.ps1
dart run melos run analyze --no-select
dart run melos run test --no-select
```

Từ thư mục app: `flutter run -d windows` hoặc chọn device Android/iOS phù hợp.
Từ root, build cả suite:

```powershell
./tooling/flutter-builds.ps1 -Apps @('tools','docs','media','dev','keep','recall','save','spend','habit','trip') -Target apk
./tooling/flutter-builds.ps1 -Apps @('tools','docs','media','dev','keep','recall','save','spend','habit','trip') -Target windows
./tooling/flutter-builds.ps1 -Apps @('tools','docs','media','dev','keep','recall','save','spend','habit','trip') -Target web
```

Trên macOS, từ thư mục app dùng `flutter build ios --simulator --no-codesign` để
kiểm tra simulator build; chưa có bằng chứng local cho lệnh này trên môi trường hiện tại.

## Kiểm thử

Kết quả unit/widget hiện tại nằm trong `docs/qa/evidence/spend-workspace-tests-summary.json`;
28 skip: 27 remote-schema case theo offline policy
và một host PDFium test cần DLL thật đã được chạy riêng trên Windows.

```powershell
npm ci --ignore-scripts
npm run typecheck
npm run format:check
python tooling/verify-fixtures.py
```

Sau khi build Web cả chín app: `npm test` chạy RE2 bridge, chín PWA worker tests và
ba Web Share Target protocol tests (12 test trong Node VM).
Chỉ chạy RE2: `npx vitest run --config tooling/vitest.re2.config.ts`.

Android integration/screenshot runner:

```powershell
./tooling/flutter-screenshots.ps1 -App media -Scenario editor -Device emulator-5558
```

Các scenario gồm native, pdf, capture, guide, recovery, conversion, camera-share,
large-project, state, reader, parity, video-transform và editor; app hỗ trợ được
kiểm tra ngay trong runner. Capture/camera test cần thao tác hộp thoại OS thật;
các helper Python chỉ tương tác với emulator QA được chỉ định.

`python tooling/verify-bookmark-checkpoint.py` kiểm tra build cả bảy app, test workspace,
MSIX unsigned và integration/share Android Handy Bookmark trong `docs/qa/evidence`.
Cần build outputs thực tế, không tự tạo bằng chứng trên clone mới. Source hash và
artifact hash được kiểm tra riêng. Các native integration cũ của sáu app còn lại
được giữ làm bằng chứng lịch sử; audit sáu app `verify-flutter-checkpoint.py` yêu
cầu đúng snapshot cũ nên không chứng nhận source hiện tại. Không sửa log lỗi để
biến thành pass. Browser VM test không thay thế browser runtime.

## Quy tắc dữ liệu

Import phải validate hết trước khi commit; ZIP kiểm tra path/checksum/giới hạn.
Export là bản sao. Giữ file gốc khi lỗi/hủy; thay schema phải có version và test
roundtrip. Không dereference URI ngoài app mà chưa có lựa chọn rõ ràng của người dùng.

Editor draft dùng repository riêng, debounce 500ms, xếp thứ tự write. Save thư viện
trước, clear draft sau; lỗi cleanup không được báo sai là lỗi lưu project. Pan mode
không sửa layer. Share PNG phải review ảnh flatten, không dùng editable ZIP để che
pixel nhạy cảm. Chi tiết giới hạn nằm trong [FUNCTIONS](FUNCTIONS.md).

Cấu hình phát hành: [STORE_SETUP](STORE_SETUP.md). Không commit secrets/khóa ký.

Handy Spend: `python tooling/verify-spend-checkpoint.py` audits current Spend builds,
Android ledger/import/Undo, permissions and independent EN/VI exports together with
full workspace unit/widget tests. Earlier app native/build records remain historical.

Spend independent export/PDF review tools require
`python -m pip install -r tooling/spend-qa-requirements.txt`.
After the export widget tests emit actual files, run
`python tooling/verify-spend-exports.py`. After a successful Android screenshot run,
`python tooling/spend-ui-review.py` creates the 11-page review PDF.

When the workspace is edited concurrently, the frozen candidate in
`.tooling/spend-qa` is separate from live-source certification. Recheck it with
`python tooling/publish-spend-snapshot.py --verify-only`; the published audit records
its source hash and artifact directory. `verify-spend-checkpoint.py` instead checks
live workspace records and writes `spend-live-workspace-audit.json`.

Handy Habit: run `flutter test --no-pub` separately in `packages/handy_habit_engine`
and `apps/handy_habit` (native assets require app package context). UI review renderer:
`flutter test --no-pub tool/screens_test.dart`; set FLUTTER_ROOT to the SDK.
See [Habit QA](handy_habit/QA_PLAN.md). Build fingerprints can use `--app habit`
to exclude unrelated app edits while including shared packages and root config.
