# Handy Suite — trạng thái chức năng

Cập nhật **2026-11-02**. Danh mục chi tiết: [FUNCTIONS](docs/FUNCTIONS.md).
Đã code, đã test và đã kiểm thử thiết bị thật là các trạng thái riêng biệt.

Handy Trip là app độc lập thứ mười. Đã có engine, SQLite/IndexedDB, planner,
check-in xác nhận, nhật ký/ảnh, booking/hành lý/chi tiêu và portable exports.
Các kiểm thử và giới hạn riêng được ghi ở [Trip matrix](docs/handy_trip/FEATURE_MATRIX.md).
P1 đã code và có kiểm thử host/Android emulator: stamp, Memory Book, EXIF xác nhận,
replay, so sánh và recipe. Khả năng phát hành store chưa hoàn tất.

Handy Habit là app độc lập thứ chín: thói quen, lịch/streak, routine runner,
insights, nhắc cục bộ và backup. R15/R16/run9: schema7/physical2, causal sync và Android Drive appdata Free tùy chọn đã source/host tested; chỉ hiện với build define, còn owner OAuth và kiểm tra hai Android ([setup](docs/handy_habit/RELEASE.md)). Run 2 (10/11): schema3/physical2, Undo domain bền, preview/khôi phục có bản phục hồi trước thay thế và Thùng rác30 ngày; source/host tested, chưa device/browser. Trạng thái từng chức năng và bằng
chứng nằm tại [Habit matrix](docs/handy_habit/FEATURE_MATRIX.md). Kiểm thử host,
emulator, thiết bị thật và store được ghi riêng. Run3 (10/11), R5/R6: ba khu
Today/Routines/Progress, sidebar gập/nhớ, routes/shortcuts, check-in + Undo, nhóm buổi,
Show all tại chỗ, dirty-exit guard và lịch sử theo mục tiêu hiệu lực. Schema4 giữ ngày
lịch sử, thêm giờ bắt đầu ngày có phiên bản; physical2. Host/widget/screenshots đã kiểm;
browser URL/back-forward và thiết bị thật vẫn cần supervisor. R7 (run4): thư viện
Start/Resume/phiên gần nhất, builder bản nháp lưu một lần/dirty guard, runner xác nhận
thoát + shortcuts + tổng kết habit được ghi; host/widget và ma trận ảnh EN/VI/sáng/tối/
320–1440/text1–1.5; kill/background/keyboard/SR thật chờ supervisor.
R8/R9 (run5/5b): guide ba giai đoạn/hai beat, practice Today không ghi dữ liệu,
15 chủ đề tìm không dấu/hình minh họa/context help, Settings nhóm/persist/reset giữ data,
múi giờ thân thiện có GMT/DST. Source/host widget tested; native OS back/permission,
screen reader và link policy/support thật vẫn chờ supervisor.
R10/R11 (run6): schema5/physical2, giảm thói quen bằng số lần/ghi rõ0/chưa rõ, giới hạn ngày/tuần có lịch sử; Today +1/Undo/Không có, history/review mẫu số trung thực, không liên kết routine; help hiện16 chủ đề EN/VI. Host engine/widget/render matrix; thiết bị/browser chưa kiểm mới. R12/R13 (run7):44 mẫu habit/11 routine/13 nhóm, tìm không dấu → preview → tùy chỉnh → lưu một lần; Progress tuần/tháng/năm, lịch tháng, heatmap tổng/từng habit, streak/độ đều đặn/quy trình và Show all đều Free. Tuần giảm đã qua suy ra ngày trống là không có; ngày cũ trống theo giới hạn ngày không vào mẫu số. Schema5 giữ nguyên; host unit/widget/render, chưa device/browser/store mới. R14 (run8): tâm trạng tùy chọn hai chạm, năng lượng/ghi chú/nhãn tùy chọn, lịch sử theo khoảng ở Progress, sửa/xóa/Hoàn tác/khôi phục, ẩn lời nhắc ở Today và help17 chủ đề. Schema6/physical2, JSON/ZIP/CSV + migration1–5 + SQLite reopen đã host tested; không đưa tâm trạng vào thông báo/widget. Chưa kiểm thiết bị/browser mới; chưa có correlation/sync transport.

| App / nhóm            | Chức năng đã code                                                                                                                                                                                                                                            | Kiểm thử có bằng chứng                                                                                                                                                                                                     | Còn thiếu                                                                                                                          |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Shared                | EN/VI, theme, navigation, safe files, snapshot recovery, preferences backup, scoped cleanup                                                                                                                                                                  | Unit/widget; Android save/reopen, corrupt recovery, cancel; cleanup bằng preferences thật                                                                                                                                  | Thiết bị thật, power loss, multiwriter/browser storage                                                                             |
| Shared (2026-11-02)   | Tự sao lưu ra thư mục có khóa mật khẩu (7 app), mở `.hseal` khi khôi phục; thông báo Windows (Keep/Recall); widget Android (Habit/Spend/Recall); liên kết Spend → Keep, Bookmark → Recall; "Các app khác"; gói `handy_ocr` tách khỏi `handy_scan`            | Host tests; Windows thật: ghi/xoay vòng thư mục, hẹn/liệt kê/hủy toast, OCR Docs                                                                                                                                           | Android SAF và thư mục iOS, widget trên launcher, link giữa hai app đã cài, toast hiện đúng giờ                                    |
| Shared (2026-11-02 b) | Trip xưởng làm tem; Spend ghi bằng một dòng; Docs tìm chữ trong tệp đã giữ; Recall dán ghi chú thành thẻ; Habit nhìn lại tuần; Tools sổ tính; Dev so với lần gửi trước; Media nối ảnh chụp màn hình; Keep đoán ngày sắp hết (dữ liệu v3)                     | Host tests: bộ đọc một dòng, nhìn lại tuần, tách thẻ, tìm không dấu, sổ tính, so phản hồi, nối ảnh trên trang tổng hợp, ước lượng sắp hết và roundtrip v3, tem đủ 4 hình ra PNG/PDF; ảnh review Trip/Spend/Docs/Keep/Tools | Chưa chạy trên Android/iOS/Web; chưa có ảnh review cho trang nhìn lại tuần, dán thẻ, sổ tính, so phản hồi, nối ảnh                 |
| Docs                  | Markdown/GFM, find/replace/template, highlight, PDF/HTML/text/ZIP export, workflow                                                                                                                                                                           | Unit và Android export/restore, roundtrip, source-byte preservation                                                                                                                                                        | iOS, provider/device QA; Mermaid renderer chưa có                                                                                  |
| Docs scanner          | Camera/import, crop 4 góc, perspective, contrast, nhiều trang, ghép PDF, session JSON; OCR trên máy (ML Kit Android/iOS, Windows.Media.Ocr), PDF tìm được chữ                                                                                                | Transform/roundtrip/error/cancel tests; Android UI; OCR: host parse/thứ tự dòng/scale/kênh Windows, Windows native thật (en-US, lớp chữ ẩn)                                                                                | Camera vật lý, iOS, low-storage/process-loss; OCR ML Kit và tiếng Việt chưa thử trên thiết bị; Windows cần gói OCR tiếng Việt      |
| Docs PDF/reader       | PDF preview/merge/extract/reorder/duplicate/rotate/watermark tiếng Việt (font nhúng)/page PNG; UTF-8 library/search/favorites/folders/ZIP; ký và điền (chữ ký lưu, chữ, ngày); nén ảnh/nén mạnh; một lối mở tệp văn bản, Tệp đã giữ                          | PDFium thật, native reader save/reopen; BOM/CRLF và ZIP roundtrip; PDFium host: font nhúng đọc lại, vị trí trên trang xoay, nén nhỏ hơn và giữ ảnh dùng chung/trong suốt                                                   | iOS, nhiều loại PDF/provider hơn; HTML không chạy script; ký/nén chưa thử trên Android/iOS; nén mạnh mất lớp chữ                   |
| Media Quick Tools     | Crop/resize/aspect/rotate/flip, PNG/JPEG/static WebP, batch watermark text/logo                                                                                                                                                                              | Pixel/alpha/format tests; Android outputs và independent decode                                                                                                                                                            | Animated WebP không hỗ trợ; encode WebP 4Mpx                                                                                       |
| Media metadata        | PNG/JPEG EXIF/GPS inspect/remove (phụ đề SRT/VTT đã chuyển sang Tools; engine giữ trong `handy_media_engine`)                                                                                                                                                | Format/error/roundtrip tests; native UI                                                                                                                                                                                    | Metadata ngoài PNG/JPEG chưa được chứng nhận                                                                                       |
| Media annotation      | 9 layer kinds, drag/resize/alignment/order, Undo/Redo, image edits, zoom/pan, camera/batch intake; tìm thông tin nhạy cảm (OCR `handy_scan` + mẫu email/điện thoại/thẻ Luhn/IBAN/tài khoản/OTP/token) đề xuất vùng che để duyệt                              | Unit/widget và Android editor; source preservation, corrupt batch refusal; unit test mẫu/hộp; widget test duyệt/hủy/Hoàn tác; Windows OCR thật (integration)                                                               | Thiết bị thật/iOS; camera recovery thêm tình huống; OCR Android/iOS chưa chạy trên máy; OCR có thể sót chữ                         |
| Media project/guide   | Project JSON/ZIP assets; draft restore; flattened PNG/share review; guide HTML/PDF/MD/ZIP/long image/change map/GIF động (khung theo bước, thanh chú thích)                                                                                                  | Actual private-store draft reopen, ZIP roundtrip; 6 guide outputs decoded độc lập; GIF giải mã lại (số khung, thời gian, vùng che, thanh chú thích)                                                                        | Abrupt power loss; gửi file tới app đích chưa chứng nhận; GIF mã hóa trên luồng chính; không có MP4                                |
| Media capture/video   | Android system PNG/H264 capture; import/trim/join/frame; MP4 rotate/resize/mute; preview; Windows chụp cả màn hình hoặc một vùng trên lớp phủ đứng yên (GDI/WIC, đa màn hình, DPI vật lý)                                                                    | Hộp thoại quyền Android thật; cancel/codec tests; FFmpeg/OpenCV decode; Windows integration thật (cả màn hình, vùng kéo, hủy, vào bước hướng dẫn)                                                                          | Preview texture có viền xanh trên emulator; iOS source-only; Windows không quay màn hình; Web dùng import                          |
| Tools                 | 23 registered tools, form calculator/converter, secure password, structured QR, PNG/SVG/PDF, optional history                                                                                                                                                | Unit/widget; Android QR decode/quyền bị từ chối, export/history                                                                                                                                                            | Live optical QR, thiết bị thật/iOS                                                                                                 |
| Dev                   | 28 data tools, RE2, local JSON Schema, JSON tree/table, API headers/auth, collections/environments/cURL                                                                                                                                                      | Unit; 898 schema cases; native RE2/API UI; Web RE2 VM                                                                                                                                                                      | 27 external-schema cases bỏ qua theo offline policy; live endpoint/CORS QA                                                         |
| Keep                  | Inventory, loans/due dates, boxes/QR labels/deep links, photo/PDF receipts, dossier share, ZIP backup, giá mua + tổng giá trị theo chỗ/tiền tệ, xuất CSV, thêm nhiều món từ ảnh                                                                              | 62 app tests + 51 engine tests; Windows native PDF/label/ZIP/recovery; Android cold/warm links và exact stored bytes; restore/error/cancel; schema v2 roundtrip JSON/ZIP, CSV formula-safety, batch một lần ghi (host)     | iOS, receipt/provider coverage, share recipient; CSV/batch/camera liên tục chưa chạy trên thiết bị                                 |
| Recall                | Deck/card CRUD, study/scheduler/history, CSV/JSON/ảnh, multi-mask occlusion editor; nhập Anki .apkg/.colpkg (anki2/anki21/anki21b, xem trước, tùy chọn giữ lịch), thẻ điền khuyết, thẻ đảo chiều, đọc to (flutter_tts), font CJK Web cache; backup schema v2 | 45 engine tests (fixture .apkg dựng bằng SQLite trên host), 39 app tests; Windows native review (trước bản này)                                                                                                            | iOS, thiết bị thật; đọc to và nhập Anki chưa chạy trên thiết bị; bộ lọc .apkg của file picker Android; build Windows cần nuget.exe |
| Bookmark              | Offline bookmarks, native share queues, collections/tags, search/Focus, batch/Undo, reminders, sáu dạng backup                                                                                                                                               | 51 app tests; engine/roundtrip; Android emulator SQLite/share; Windows native SQLite/ZIP/UI; xem [matrix riêng](docs/HANDY_BOOKMARK_FEATURE_MATRIX.md)                                                                     | iOS, browser runtime, app xã hội/thiết bị thật, live metadata, store                                                               |
| Spend                 | Sổ thu/chi chính xác, chuyển khoản/hoàn tiền, ngân sách, Safe to Spend, forecast, sandbox, CSV/XLSX import/Undo, backup, PDF, nhắc hạn, khóa OS                                                                                                              | SQLite crash/WAL và 100k dòng; Android ledger/import/đối chiếu/Undo; 10 file xuất EN/VI giải mã độc lập; xem [matrix riêng](docs/handy_spend/FEATURE_MATRIX.md)                                                            | iOS, browser runtime, thiết bị thật, Windows Hello/drop, file provider và store                                                    |
| Notifications         | Keep/Recall/Bookmark/Spend reminders, quyền/schedule/cancel                                                                                                                                                                                                  | Android deny/grant, pending schedule, immediate delivery/cancel                                                                                                                                                            | Delayed/background/reboot, iOS; Windows/Web dùng danh sách trong app                                                               |
| Monetization          | Ads + Pro Lifetime native adapters, consent, purchase/restore UI                                                                                                                                                                                             | Controller/channel; Android RSA/Keystore; Android/Windows compile                                                                                                                                                          | Tài khoản/ID thật, giao dịch/ads/restore/refund thật, signing/store approval                                                       |
| Distribution          | 8 Android/Windows/Web targets, iOS source, PWA assets, unsigned AAB/MSIX                                                                                                                                                                                     | Spend: [audit hiện tại](docs/qa/evidence/spend-checkpoint-audit.json); 7 app trước giữ bằng chứng build lịch sử                                                                                                            | iOS build; browser runtime/offline/update; install/signing QA                                                                      |

Mốc regression đã chạy: **1.698 test pass trên 27 package/app**, 28 skip có lý do,
ở source `5844653bf4b5`. Workspace sau đó có chỉnh sửa đồng thời ở các app/shared UI;
mốc này không chứng nhận các chỉnh sửa mới. Spend được kiểm tra tiếp trên snapshot
cố định; phạm vi và artifact xem trong [audit](docs/qa/evidence/spend-checkpoint-audit.json).
Kết quả: [log toàn workspace](docs/qa/evidence/spend-workspace-tests.log)
và [tổng hợp tự động](docs/qa/evidence/spend-workspace-tests-summary.json), gồm 27 package/app.
Chưa dùng thiết bị Android/iOS thật. Không tuyên bố không còn bug
hoặc sẵn sàng phát hành. Xem [KNOWN_ISSUES](KNOWN_ISSUES.md).

Ảnh/log/artifact reports: [docs/qa/evidence](docs/qa/evidence).

Các native integration/build của bảy app trước được giữ làm bằng chứng lịch sử,
chưa chạy lại trên snapshot bổ sung Handy Spend. Regression unit/widget gồm cả tám app.
Không đồng nhất build thành công với kiểm chứng runtime trên mọi nền tảng.

Handy Boards (rebuilt Kanban-first 2026-11-07): boards → columns → cards with one-level
subtasks, categories independent of columns (category strip = overview + filter), 10
templates with a live preview, 60 original covers, Bookmark-style tour, Settings and How to
use (auto backup, archived cards, delete all data), Pro Lifetime (templates, covers,
automations, insights). Table/calendar/study/focus modules were
removed. [Exact status and gaps](docs/HANDY_BOARDS_FEATURE_MATRIX.md). Not release complete.

Boards remaining-work batch: Study reports (working calendars and workload removed
2026-11-03), Trello
subset, lazy versioned storage/indexed paging, native streamed ZIP/PDF + staged
large restores, mobile widget/shortcut source and owned validation localization.
See docs/HANDY_BOARDS_FEATURE_MATRIX.md and source-bound QA checkpoint for code,
automated tests and device verification separately. Store/iOS/physical checks are
not inferred from Android/Windows/Web builds.

Handy Card: app thiết kế thẻ (danh thiếp, portfolio, thẻ sự kiện, thẻ shop,
thiết kế tự do). Đã có engine scene graph thuần Dart, editor nhiều lớp (chọn,
kéo, đổi cỡ, xoay, nhóm, căn, snap, undo), hồ sơ với binding live/snapshot,
PNG/JPEG/SVG/PDF/tờ in/vCard/QR/trang hồ sơ HTML/chữ ký email và ZIP dự án.
Trạng thái thật từng mục: [Card test matrix](docs/HANDY_CARD_TEST_MATRIX.md).
Batch mới có engine (chưa có màn hình); NFC, Wallet, brand kit chưa làm. Chưa
build và chưa chạy trên Android/iOS/Windows/Web.

Vòng 3 (2026-11-03), unit test + widget test trên máy, chưa chạy thiết bị:
Tools có Bốc thăm và Đo bằng ảnh (Keep cũng đo từ ảnh của món đồ); Media có
khung ảnh chụp màn hình; Docs lưu chữ OCR thành Word, in hai mặt thủ công và
đánh số trang; Recall có chép chính tả; Card có thiệp cưới, thiệp tân gia/sinh
nhật, CV một trang, khổ A5 và A4. Đã gộp hoặc bỏ: Dev còn 24 tool (converter
gộp thành `convert`, bỏ HAR và .env), Tools còn 17 (phần trăm và tỷ lệ vào Sổ
tính, màu sang Dev, bỏ tỷ giá nhập tay), Trip bỏ so sánh chuyến, Habit bỏ
Routine Lite, Boards bỏ timeline và critical path.

Vòng 4 (2026-11-03), unit test + widget test trên máy, chưa chạy thiết bị:
Docs gửi một tệp nhỏ sang máy khác bằng mã QR chạy (nhận cần camera
Android/iOS); Trip ghi "đã ghé" một chạm; Docs Quét mở camera ngay; Media một
lối Ảnh chụp màn hình (một ảnh đóng khung, nhiều ảnh nối). Đã gộp hoặc bỏ:
Dev còn 22 tool (JSON lọc và JSON suy kiểu), Tools đưa các phép biến đổi chữ
vào bàn làm việc và ngày làm việc vào Ngày, Bookmark gộp bộ lọc đã lưu, Trip
một kiểu sổ kỷ niệm; bỏ what-if của Spend, phát lại hành trình và GPX/KML của
Trip, Workload của Boards, quy trình chữ của Docs, sắp xếp thủ công của
Bookmark (dữ liệu cũ vẫn mở được).

Refactor 2026-11 (lát S1, 2026-11-04), xem [REFACTOR_AUDIT](docs/REFACTOR_AUDIT.md):
Docs "Gửi sang máy khác" thành tính năng thử nghiệm, mặc định tắt; Keep bỏ "Đo
bằng ảnh" (Tools giữ, ghi chú cũ còn nguyên).

Refactor 2026-11 (các lát còn lại, 2026-11-04; có test và ảnh duyệt, chưa chạy trên
thiết bị): Keep bộ sưu tập, wishlist, kho ảnh; Trip 40 kiểu tem và tem đã giữ; Card 144
mẫu, thư viện, mẫu đã thích, đổi bảng màu một chạm; Media khung ảnh chụp màn hình; Tools
tình huống và Gần đây; Habit 32 gợi ý; Recall bộ mẫu và luyện thêm; Spend ghi lại một chạm
và giải thích đối chiếu; Dev chỉ chỗ lỗi JSON, chép JSON Pointer, lịch sử gửi opt-in;
Boards mặc định cá nhân; Bookmark gộp link trùng có duyệt; Docs kiểu giấy khi quét và
500 tệp đã giữ. Trạng thái từng mục: [REFACTOR_AUDIT](docs/REFACTOR_AUDIT.md).

## Handy Bookmark redesign (2026-11-06)

Per-feature status with proof: `docs/bookmark-redesign/FEATURE_QA_MATRIX.md`. In short:

- **Done, host-tested:** no ads; picture items and owned pictures (backed up, previews without
  EXIF); Recently Deleted for 30 days with tombstones; visual home with one Save button and
  All / Links / Pictures; first-run guide with a real first save; Focus swipe deck; per-collection
  view and order; Raindrop import; collection shared as one page; named library and dateline;
  storage use; sync protocol (simulated devices).
- **Code only:** Android image share (APK builds); read-later reminders with Mark as read / Remind in 1 hour and needs-attention notifications (no weekly nudge, removed 2026-11-08); folder sync on
  computers (host tests with real files).
- **Blocked:** iOS share extension images (no Mac: not compiled); iCloud Drive and Google Drive
  sync on phones (container, OAuth client, devices).
- Nothing in this redesign has been run on an emulator or a device yet.
