# Known limitations — chưa release-ready

- Chưa physical-device QA trên bất kỳ nền tảng nào. iOS chưa build/run vì máy Windows
  không có Mac/Xcode; share extension cần team + App Group thực.
- Android emulator đã chạy data/GPS/notification/share, GPS/notification denied và
  Photo Picker Back cancel; chưa chứng minh camera/gallery selection/denial,
  lost picker recovery, airplane/low disk, reboot/
  background reminder reliability hoặc app đích nhận file/maps.
- Windows native build và SQLite host tests; chưa Windows UI/location/installer runtime.
  Web compile/PWA VM không thay thế browser IndexedDB, secure location context,
  camera fallback, quota/eviction/multi-tab/offline update.
- Portable bundle tối đa 30 MB/998 entries; không streaming unlimited. Chọn chuyến/ngày.
  Không có mid-compute cancel cho PDF/ZIP. Full library over 30 MB cần nhiều selections.
- Search hiện in-memory, database có indexes nhưng chưa FTS. Fixture 1000 trips/
  10000 visits đã đo host; chưa image-heavy mobile scroll/startup/memory.
- JPEG/PNG/static WebP + PDF attachments. PDF signature/EOF guard không thay parser
  PDF hoàn chỉnh; PDF được lưu/xuất riêng để mở bằng reader của OS.
- Không tiles/geocoding mặc định; NoBasemap + explicit map handoff, không GPS tracks.
  Vị trí người dùng xác nhận không phải bằng chứng đã ghé hay taxonomy địa lý chính thức.
- P1 đã code/test host và Android emulator; không thay thế kiểm thử iOS/thiết bị thật.
  Memory Book tối đa 366 ngày/100 ảnh; không có map tiles.
  Cross-app recipe/file handoff chưa kiểm thử đầu cuối với app nhận.
- Publisher accounts/product IDs/AdMob/UMP/signing/store sandbox chưa có. Không
  production ads/purchase/restore/refund/store submission nào được tuyên bố pass.
- Workspace có source thay đổi đồng thời. Bằng chứng sourceUnchanged=false chỉ là
  snapshot; đối chiếu source hash trước khi dùng artifact để phát hành.
