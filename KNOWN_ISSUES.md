# Lỗi và giới hạn hiện tại

Handy Trip: [giới hạn riêng](docs/handy_trip/KNOWN_LIMITATIONS.md) và
[bằng chứng QA](docs/handy_trip/QA_RESULTS.md). Host/Android emulator và build
Android/Windows/Web đã có; iOS, thiết bị thật, browser/provider runtime và store
chưa được chứng nhận. Bản AAB/MSIX chưa ký phát hành.

Handy Bookmark: xem [giới hạn riêng](docs/HANDY_BOOKMARK_KNOWN_LIMITATIONS.md). Đọc tiêu đề
và hình đã chạy thật (2026-11-07, host Windows) với Facebook, Instagram, YouTube, X, Threads,
TikTok và web thường; Reddit chỉ có tiêu đề (oEmbed), reel 18+/riêng tư thì không. Android
share đã kiểm tra trên BlueStacks; iOS chưa chạy thật. Backup không chứa thumbnail cache,
tối đa 30MB.

1. iOS source chưa build/run trên Windows; cần macOS/Xcode. Chưa kiểm thử thiết bị
   Android/iOS thật. Các build Android/Windows/Web không chứng nhận iOS.
2. Media video preview có viền xanh trên emulator texture; MP4 giải mã độc lập
   không có viền. Hardware-codec/playback trên thiết bị thật chưa được xác nhận.
3. Android emulator đôi khi mất ADB. Log lỗi được giữ; kết quả lấy lại qua cùng VM
   chỉ được chấp nhận khi driver thật trả về test pass và hash log khớp.
4. Keep/Recall notifications đã kiểm tra deny/grant, schedule/immediate/cancel;
   delayed/background/reboot và iOS còn cần QA. Windows/Web có danh sách due trong app.
5. Camera/share đã thử qua OS Android; camera vật lý, provider lỗi/low-storage,
   process loss và việc app đích nhận file còn thiếu bằng chứng.
6. Browser runtime/offline/update chưa được kiểm chứng; chỉ có static Web builds
   và Node VM RE2/PWA checks. IndexedDB quota/eviction và multi-tab conflict còn mở.
7. Chưa có cấu hình/tài khoản store/AdMob thật. Purchase/restore/refund, consent,
   ads delivery, release signing và store acceptance chưa xác nhận.
8. Dev API live endpoints/redirect/CORS cần QA. Secrets chỉ giữ trong session và
   bị loại khỏi export mặc định; JWT decode không xác minh chữ ký. JSON Schema
   không tải external references; 27 case tương ứng được skip có chủ đích.
9. PNG/JPEG metadata đã kiểm chứng; không nhận mọi định dạng metadata. Static
   WebP encode tối đa 4Mpx; animation bị từ chối. Scanner giới hạn 4Mpx/trang;
   rendered Markdown 100KB; MP4 transform chỉ H264/AAC có giới hạn 5 phút/30MB.
10. Draft editor debounce 500ms, không phục hồi Undo stack sau restart. Snapshot
    không phải secure erase; power-loss, multiwriter và đĩa đầy cần thêm coverage.
    File gốc không bị ghi đè tự động.
11. Font đóng gói (Geist, Bricolage) chỉ có chữ Latin và tiếng Việt. Android, iOS,
    Windows tự lấy font hệ thống cho tiếng Nhật, Trung, Hàn. Bản Web offline
    (`--no-web-resources-cdn`) không có font CJK nên chữ Nhật/Trung/Hàn hiện thành
    ô vuông; cần đóng gói một font CJK (khoảng 4–8 MB) hoặc cho phép tải font
    fallback từ CDN. Recall nay tải lát font khi cần và giữ để dùng offline (mục 25); các app khác chưa.
12. Handy Bookmark (tên cũ Handy Save, đổi 2026-11-02) đã có lại tìm kiếm đã lưu (Pro) và
    thứ tự tự xếp; thêm nhập từ Pocket, bản đọc offline và kiểm tra link hỏng (chỉ khi bấm,
    không có trên Web). Bản đọc và kiểm tra link mới kiểm thử trên host với máy chủ cục bộ,
    chưa tải từ website thật hay chạy trên thiết bị; trang dựng bằng JavaScript (nhiều mạng
    xã hội) hoặc cần đăng nhập không cho bản đọc, và Hoàn tác sau khi xóa link không khôi
    phục bản đọc. Tên kho dữ liệu trên máy (`handy-save.sqlite`, IndexedDB `handy-save-*`,
    khóa cài đặt, `ProductName` Windows) và mã định dạng bản sao lưu (`handy-save`,
    `handy-save-zip`) giữ tên cũ để không mất dữ liệu; mã ứng dụng đổi sang
    `com.example.handysuite.bookmark`, nên bản cài thử cũ trên Android/iOS là một app khác.
    Bằng chứng QA cũ trong `docs/qa/evidence/save-*` thuộc tên và đường dẫn cũ.
13. Giao diện mới của Handy Docs bỏ ghim công cụ và "đầu vào đã lưu" cho Markdown (bản
    nháp đã được lưu). Dữ liệu `favorites`/`drafts` cũ vẫn giữ trong cài đặt. Ảnh review
    màn PDF chỉ có trạng thái trống vì PDFium không chạy trong `flutter test`; màn có
    tệp đã được kiểm tra bằng integration test trên Windows nhưng chưa có ảnh.
14. Giao diện mới của Handy Media bỏ bộ tìm công cụ (Ctrl K), ghim và "đầu vào đã lưu"
    của phụ đề; dữ liệu `favorites`/`drafts` cũ vẫn giữ và xóa được trong Cài đặt. Màn
    Chụp màn hình chỉ kiểm tra được bằng widget test với kênh native giả; bố cục mới
    chưa chạy trên thiết bị Android/iOS thật.

15. Handy Spend đã có SQLite và các luồng tài chính/import trên Android emulator;
    chưa chứng nhận IndexedDB trong browser, Windows Hello/Explorer drop hoặc khóa
    bằng sinh trắc/PIN thành công trên thiết bị thật. Notification mới kiểm tra
    schedule/immediate/cancel, chưa delayed/reboot. Database và backup không mã hóa.
    CSV/XLSX/PDF xuất có giải mã độc lập EN/VI; OS file provider và nhiều định dạng
    sao kê thực tế còn cần QA. Receipt/OCR và lãi suất theo ngân hàng thuộc P1.
16. Giao diện mới của chín app đã chạy tour có quay phim trên BlueStacks (Android 11,
    x86_64, màn ngang 960×540 dp) bằng `tooling/device-tour.py`. Đó là máy giả lập,
    không phải điện thoại thật; chưa chạy trên iOS. Chia sẻ từ Facebook, YouTube và
    TikTok vào Bookmark chưa thử trên máy này.
17. Giao diện mới của Handy Spend (2026-11-01): đồng hiển thị là "đ" vì Geist và
    Bricolage không có ký tự ₫ (nhập vẫn nhận ₫, đ, k, tr). Màu `#RRGGBB` và icon của
    danh mục cũ vẫn giữ trong dữ liệu nhưng app vẽ chấm theo thứ tự danh mục và không
    còn sửa màu/icon. Bốn khu không có URL web riêng; trang con thì có. Bản sửa nhập
    sao kê, tour và `native_test` mới chạy trên BlueStacks, chưa trên điện thoại thật
    hay emulator QA; bằng chứng trong `docs/qa/evidence` thuộc giao diện cũ.
18. Giao diện mới của Handy Habit (2026-11-02): màu đổi từ teal sang đỏ son `#B42318`,
    nên ngày lỡ luôn là vòng rỗng xám có chữ, không bao giờ tô đỏ. Màu và icon riêng của
    thói quen, quy trình vẫn giữ trong dữ liệu nhưng không còn sửa trong app; chấm màu lấy
    theo thứ tự tạo. Xong một bước thì bước kế tự chạy (tạm dừng vẫn do bạn bấm; ra nền vẫn
    dừng). Bốn khu không có URL web riêng; trang con thì có. Tour và `native_test` mới chạy
    trên BlueStacks (máy giả lập); ảnh `habit-ui-review.pdf` và bằng chứng UI cũ thuộc bản
    trước.

19. Tự sao lưu (2026-11-02) ghi bản sao lưu của Keep, Recall, Bookmark, Spend, Habit, Docs
    (tệp đã giữ) và Media vào thư mục người dùng chọn, khi mở hoặc rời app, không chạy nền khi
    app đã đóng. Android dùng bộ chọn thư mục của hệ thống (máy, Google Drive, OneDrive); iOS
    ghi vào thư mục của app trong Tệp (iCloud Backup của máy mang theo, không chọn được thư mục
    khác); Windows chọn thư mục bất kỳ; Web không có. Khóa bằng mật khẩu dùng X25519 +
    AES-256-GCM, khóa riêng được bọc bằng PBKDF2-SHA256 600.000 vòng; app không lưu mật khẩu,
    quên mật khẩu thì không mở được. Đã kiểm thử trên host và ghi/xoay vòng thư mục trên Windows
    thật; bộ chọn thư mục Android (SAF) và thư mục iOS chưa chạy trên thiết bị.
20. Thông báo trên Windows (Keep, Recall): lịch hẹn tạo, liệt kê và hủy đã kiểm tra trên Windows
    thật, nhưng chưa thấy toast thật bật lên đúng giờ. Windows không tự lặp hằng ngày nên nhắc
    ôn hằng ngày được đặt sẵn 14 ngày và nạp lại mỗi lần mở app. Bookmark, Spend và Habit trên
    Windows vẫn dùng danh sách trong app.
21. Widget màn hình chính (Android) cho Habit, Spend, Recall: APK debug build được và Android
    (BlueStacks, máy giả lập) đã đăng ký cả ba widget, nhưng chưa đặt widget lên màn hình chính
    để xem nó vẽ hay bấm thử. Widget Spend chỉ hiện số tiền khi app không bật khóa và không ẩn số
    tiền. iOS chưa có widget (cần Xcode).
22. Liên kết giữa app (Spend → Keep "Thêm vào Handy Keep", Bookmark → Recall "Tạo thẻ ôn") chỉ
    có trên Android/iOS và chỉ điền sẵn, người dùng vẫn bấm Lưu. Trên BlueStacks, link
    `handy-keep://new?…` mở trình tạo món đồ với tên đã điền, và `handy-recall://new?…` hỏi bộ
    thẻ rồi mở trình tạo thẻ đã điền cả hai mặt. Nút gửi link trong Spend và Bookmark chưa bấm
    thử trên máy; Recall chưa nhận link trên iOS.
23. Handy Tools: Tính lương dùng bảng tham số có ngày hiệu lực (kiểm tra lần cuối 2026-11-02),
    bỏ qua phụ cấp miễn thuế, người không cư trú và quyết toán năm; danh sách ngân hàng VietQR
    là bản chép ngày 2026-11-02, không tự cập nhật, và app không kiểm tra được tên chủ tài khoản.
24. Handy Dev: timestamp và cron chỉ đọc UTC, múi giờ máy hoặc độ lệch cố định (không có tên
    múi giờ IANA nên độ lệch cố định không theo giờ mùa hè); so sánh văn bản dừng ở 20.000
    dòng mỗi bên hoặc 2.000 dòng đổi; `convert` chỉ đổi qua lại với JSON (YAML → TOML
    phải qua hai bước) để mỗi lần mất mát dữ liệu đều thấy được.
25. Handy Recall: chữ Nhật/Trung/Hàn trên Web cần mạng lần đầu để tải lát font Noto, sau đó
    giữ trong cache `handy_recall-fonts-v1`. Đọc to dùng giọng của hệ điều hành; bản build
    Windows cần `nuget.exe` trên PATH (máy này chưa có). Nhập Anki chưa thử trên thiết bị;
    ô điền khuyết lồng nhau, learning step và dữ liệu FSRS của Anki không được nhập.
26. Handy Keep: giá là số người dùng nhập, không quy đổi giữa các loại tiền; tổng tách theo
    từng loại tiền. Thêm hàng loạt tối đa 20 ảnh mỗi lần và phải vừa thư viện 16 MB. CSV, thêm
    hàng loạt và chụp liên tiếp mới kiểm thử trên host.
27. Handy Habit: màn chạy quy trình vẫn tạm dừng khi app rời màn hình; trên Android/iOS một
    thông báo im lặng nói đang dừng ở đâu và còn bao lâu (không đếm ngược). Chế độ nghỉ và
    thông báo này mới kiểm thử trên host.
28. Handy Spend (schema 2): ảnh hóa đơn, chia tiền, gợi ý khoản định kỳ, mẫu sao kê và "Dự báo
    nếu…" mới kiểm thử trên host; camera, chia sẻ/mở hóa đơn, lưu hóa đơn trong IndexedDB và
    bản sao lưu ZIP 85 MB chưa chạy trên thiết bị hay trình duyệt.
29. Handy Docs: nhận dạng chữ chạy trên máy (gói `handy_ocr`); ML Kit (Android/iOS) chưa thử
    trên thiết bị với dấu tiếng Việt, Windows chỉ đọc tiếng Việt khi đã cài gói OCR tiếng Việt
    (máy này chỉ có en-US), Web không có. Ký/điền, nén ảnh và dấu tiếng Việt cần PDFium native
    (không có trên Web); nén mạnh biến trang thành ảnh nên mất chữ chọn được. Docs cần iOS 15.5.
30. Handy Media: phụ đề đã chuyển sang Handy Tools. Trên Windows chỉ chụp ảnh màn hình, không
    quay; "Tìm thông tin nhạy cảm" dựa vào nhận dạng chữ trên máy nên có thể bỏ sót và chưa
    chạy trên Android/iOS; xuất GIF chạy trên luồng giao diện, không có MP4, giới hạn 100 khung,
    48 Mpx và 20 MB.
31. Pro: mọi bản build hiện chưa có mã sản phẩm trên store nên Pro chưa mua được. Các tính năng
    mới chưa bị khóa sau Pro; kế hoạch Pro từng app nằm trong `docs/STORE_SETUP.md`.

Chi tiết chức năng và giới hạn: [FUNCTIONS](docs/FUNCTIONS.md).

Handy Habit: xem [QA riêng](docs/handy_habit/QA_PLAN.md). iOS cần Mac/Xcode; chưa
kiểm chứng thiết bị thật, screen reader, browser eviction/quota/offline runtime,
OS file provider, nhắc sau reboot hoặc giao dịch/consent trên store thật.
Windows/Web dùng danh sách đến hạn trong app, không hứa nhắc nền. SQLite/backup
không mã hóa. Timer chỉ auto-next ở tiền cảnh; khôi phục sẽ tạm dừng và cảnh báo
ước tính thời gian. P1 vacation/widget/challenge chưa triển khai.
Trạng thái kiểm thử: [FEATURE_MATRIX](FEATURE_MATRIX.md).

Chức năng thêm ngày 2026-11-02 (đợt 2): Media nối ảnh cần các ảnh cùng chiều
rộng và một đoạn trùng gần như giống hệt (nội dung động như video hay đồng hồ
có thể làm lệch khớp); Tools sổ tính căn kết quả theo dòng, một dòng dài tự xuống
hàng sẽ làm lệch các kết quả bên dưới; Docs chỉ tìm trong Tệp đã giữ (không tìm
trong bản quét hay PDF đang mở); Keep chỉ đoán ngày sắp hết khi có ít nhất hai
lần mua cách nhau tối đa 180 ngày; Dev chỉ so với phản hồi trước trong cùng phiên.

Handy Boards remains in development (Kanban rebuild 2026-11-07). Not yet built: designed poster/PDF export styles (Pro), recurring cards, premium appearance packs. No Boards store product id is configured, so Pro cannot be bought. The engine still carries the removed modules' code (study, planning, rules, views) for old data; it is unused by the app. Drag and drop is host-tested only; no device or iOS run yet. [Known limitations](docs/HANDY_BOARDS_KNOWN_LIMITATIONS.md) cover native/provider/store QA and platform verification.

Handy Card is in development. PDF export embeds the bundled faces; SVG names
them only, so a viewer without them substitutes. PDF gradients are 64 vector
bands. Crop is set with sliders (no drag crop yet). The batch generator has an
engine but no screen; NFC, Wallet passes, brand kits, XLSX and SVG import are
not built. Stored designs are not encrypted. Nothing has run on a device yet;
see `docs/HANDY_CARD_PLATFORM_MATRIX.md`.

Round 3 features (2026-11-03), host-tested only, none run on a device yet:
Tools "Đo bằng ảnh" (Keep's copy was removed on 2026-11-04) is an estimate that holds only for flat things in
the reference's plane, photographed square on (no perspective correction).
Recall dictation needs a system voice for the deck's answer language and
skips cloze and picture cards. Docs' Word export is minimal Office Open XML
(paragraphs and breaks, no styles) and was not opened in Word on this
machine; "print both sides" cannot add a blank page, so with an odd count
the last sheet is taken out by hand; page numbers need the Android, iOS or
Windows app. Media's screenshot frame stops at 16 Mpx. Keep's moving boxes
were kept on purpose: they already show as places in the same list.

Docs "Gửi sang máy khác" (2026-11-03; experimental and off by default since
2026-11-04) is host-tested only: the frames, the
checksum and both screens pass with a camera fed by hand, but no phone has
read the codes off a real screen yet, so the 6 frames a second and the
480-byte frame are estimates. Up to 100 KB; receiving needs the Android or
iOS app; the screen may dim during a long send (no wake lock).

The 2026-11 refactor (see `docs/REFACTOR_AUDIT.md`) is host-tested only: unit
and widget tests on Windows plus rendered review shots; nothing from it has run
on a phone or on iOS. Its limits: Docs keeps up to 500 files in the same 8 MB,
and a library or reader ZIP holding more than 50 is written as version 2, which
an older Docs refuses; Dev's send history is off by default, keeps at most 50
sends on this device and only the request's URL template without query values;
Spend's "Again" chips look back 28 days and its reconcile hints are suggestions
from the ledger, never changes; Recall's practice rounds never move a card in
the schedule; Keep predicts running out only for items with no profile or the
consumable one; Card switches palettes only for designs drawn in one of its ten
palettes; Bookmark merges only links that imports would also call the same.
Every app still uses a `com.example.*` package id, which no store accepts
(`docs/ANDROID_IOS_RELEASE_CHECKLIST.md`).

## Handy Bookmark (2026-11-06)

- Sync on phones is not available: only a folder kept in step by a cloud client on a computer.
  Sync trusts each device's clock; a badly wrong clock can win or lose edits. Tombstones are kept
  365 days.
- Importing Pocket or Raindrop twice no longer adds empty copies of collections that already
  exist by name and place; the preview offers to put new links into them (off by default, so a
  same-named collection that gets new links is still created separately). Links are never
  duplicated.
- Backups now carry each collection's view and sort (`collectionViews`). The automatic backup
  records what it left out (pictures or offline copies too large, missing or unreadable) and is
  only called complete when nothing was. Offline copies of items in Recently Deleted are not in
  backups. Folder sync carries no preferences: views stay on the device where they were set.
- Previews stored before 2026-11-06 may still carry EXIF on the device; shared pages re-encode
  every picture, so nothing leaves with it.
- The weekly nudge is rescheduled when the library changes; a library left untouched for
  weeks gets one nudge, not one a week.
- iOS image sharing is written but has never been compiled.
- Collections in the share sheet's top row (sharing shortcuts) need Android 10 or later and
  show only after the person has collections; the system decides how many direct targets to
  show and in what order. Apps such as TikTok, Facebook and Chrome open their own share list
  first, and no app can add itself there: the person taps More. Checked on BlueStacks
  (Android 11) through Chrome's More; not yet on a phone, or from TikTok or Facebook.
