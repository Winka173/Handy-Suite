# Lỗi và giới hạn hiện tại

Handy Save: xem [giới hạn riêng](docs/HANDY_SAVE_KNOWN_LIMITATIONS.md). Metadata từ
website thật chưa có lần fetch thành công trên host QA; lưu link offline vẫn chạy.
Android share đã kiểm tra trên emulator; iOS, browser runtime và app xã hội thật
chưa xác nhận. Backup không chứa thumbnail cache, tối đa 30MB.

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
    fallback từ CDN. Đáng chú ý cho thẻ học ngoại ngữ của Recall.
12. Giao diện mới của Handy Save chưa có lại tìm kiếm đã lưu (Pro) và sắp xếp thủ công
    (lên/xuống); dữ liệu `savedSearches` và `bookmarkOrder` vẫn được giữ và sao lưu.
13. Giao diện mới của Handy Docs bỏ ghim công cụ và "đầu vào đã lưu" cho Markdown (bản
    nháp đã được lưu). Dữ liệu `favorites`/`drafts` cũ vẫn giữ trong cài đặt. Ảnh review
    màn PDF chỉ có trạng thái trống vì PDFium không chạy trong `flutter test`; màn có
    tệp đã được kiểm tra bằng integration test trên Windows nhưng chưa có ảnh.
14. Giao diện mới của Handy Media bỏ bộ tìm công cụ (Ctrl K), ghim và "đầu vào đã lưu"
    của phụ đề; dữ liệu `favorites`/`drafts` cũ vẫn giữ và xóa được trong Cài đặt. Màn
    Chụp màn hình chỉ kiểm tra được bằng widget test với kênh native giả; bố cục mới
    chưa chạy trên thiết bị Android/iOS thật.

Chi tiết chức năng và giới hạn: [FUNCTIONS](docs/FUNCTIONS.md).
Trạng thái kiểm thử: [FEATURE_MATRIX](FEATURE_MATRIX.md).
