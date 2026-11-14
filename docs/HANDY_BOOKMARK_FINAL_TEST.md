# Handy Bookmark · Final test trước production

Bản này thay `HANDY_BOOKMARK_TEST_PLAN.md` và `bookmark-final-prepublish/` cho lần phát hành
đầu. Mỗi ca có mã, cách làm, kết quả mong đợi và cột kết quả. Chỉ ghi PASS khi đã làm thật
trên đúng thiết bị và có bằng chứng (ảnh chụp, log). Không đánh dấu PASS từ test tự động cho
một ca cần thiết bị.

**Kết quả:** `PASS` · `FAIL #n` (số lỗi ở mục Z) · `BLOCKED` (lý do) · `N/A`.

## 0. Môi trường

| Mục | Giá trị |
| --- | --- |
| Emulator | `HandyBookmark_Final_API35` (Android 15, Google Play, Pixel 3a 1080×2220 @440dpi, 4 GB RAM, 16 GB dữ liệu), nằm ở `D:\AndroidAVD`. Mở: `emulator -avd HandyBookmark_Final_API35` |
| Bản app | **release** `com.apps.winka.handybookmark`, ký bằng upload key (`android/key.properties`, không commit). Build: `flutter build apk --release --target-platform android-x64` trong `apps/handy_bookmark` |
| Cài | `adb push app-release.apk /data/local/tmp/hb.apk` rồi `adb shell pm install -r /data/local/tmp/hb.apk` (cài thẳng 68 MB làm emulator rớt kết nối) |
| Chỉ một adb | Tắt adb của BlueStacks trước khi dùng emulator: `adb kill-server`, dừng mọi tiến trình `adb`, rồi `adb start-server`. Hai adb chạy song song làm thiết bị "offline" |
| Ngôn ngữ | Lượt 1 tiếng Việt (Cài đặt hệ thống › Ngôn ngữ › Tiếng Việt). Lượt 2 tiếng Anh cho các màn chính (mục T) |
| App nguồn | Có sẵn: YouTube, YouTube Music, Chrome, Maps, Photos, Gmail. Cài từ Play (`tooling/bookmark-final/install_apps.py`): Facebook, Instagram, TikTok (`com.ss.android.ugc.trill` ở VN), Threads, X, Reddit, Shopee, ShopeeFood, Grab, Lazada, Tiki, Pinterest, Spotify, Cốc Cốc, Firefox, Edge, Opera. Chỉ hỗ trợ app phổ biến. Chủ app tự đăng nhập; không ai khác nhập mật khẩu |
| Mạng | Bật. Các ca mất mạng dùng `adb shell svc wifi disable` và `svc data disable` |
| Bằng chứng | `docs/qa/evidence/bookmark-final/` (ảnh `F-<mã>.png`, log `F-<mã>.txt`). Ảnh có nội dung riêng tư không đưa lên repo |

## 1. Dữ liệu test

Mỗi loại nguồn nằm trong một bộ sưu tập riêng để dễ xem.

- **Nhập sẵn:** `tooling/bookmark-final/seed-links.html` (12 thư mục → 12 bộ sưu tập T1–T12,
  một link không thư mục → Chưa xếp). Chỉ gồm link đã xác nhận có thật; T12 là ca biên
  (404, 410, 500, 403, 429, 301, chậm 30 giây, http, địa chỉ nội bộ, host không tồn tại,
  link rất dài, tiêu đề emoji + dấu, không tiêu đề, link trùng theo `si=`, `utm_`, `twitter.com`).
- **Share giả lập (lặp lại được):** `tooling/bookmark-final/share.ps1` gửi đúng nội dung từng
  app gửi khi bấm Share (`youtu.be/...?si=`, `vt.tiktok.com`, `instagram.com/reel/...?igsh=`,
  `facebook.com/share/r/...`, chữ kèm link, nhiều link, ảnh).
- **Share thật từ app:** mục C. Mỗi nền tảng tạo bộ sưu tập ngay trong bảng chia sẻ:
  `S YouTube`, `S YouTube Shorts`, `S Facebook`, `S Facebook Reel`, `S TikTok`, `S Instagram`,
  `S Instagram Reel`, `S Threads`, `S X`, `S Reddit`, `S Shopee`, `S Chrome`, `S Ảnh`.

## A. Cài đặt và lần mở đầu

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| A1 | Cài mới, mở app | Màn chào lần đầu; chữ không tràn ở 1080×2220; không quảng cáo |PASS (lỗi #3) |
| A2 | Đi hết các bước chào | Mỗi bước có Tiếp/Quay lại; nút Back hệ thống quay lại bước trước |PASS (lỗi #1, #2, #4, #5, #6) |
| A3 | Bỏ qua ở bước 1 | Vào trang chủ trống, có lời mời lưu link đầu tiên |PASS (lỗi #3, #7) |
| A4 | Android 13+ hỏi quyền thông báo | Chỉ hỏi khi lần đầu đặt nhắc, không hỏi ngay khi mở app | |
| A5 | Tắt app khi đang ở bước chào, mở lại | Không lặp lại bước đã qua hoặc mở đúng chỗ, không treo | |
| A6 | Xoay ngang ở màn chào | Bố cục không vỡ, không mất trạng thái | |

## B. Lưu link trong app

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| B1 | Dán 1 link vào ô, Lưu | Dải chân màn "Đã lưu. Cho vào:" + 3 gợi ý + Khác…; không mở trang khác | |
| B2 | Chạm 1 bộ gợi ý trên dải | Mục vào bộ đó; dải "Đã cho vào X" + Hoàn tác | |
| B3 | Hoàn tác ở B2 | Mục về Chưa xếp | |
| B4 | Bỏ qua dải (đợi 8 giây) | Mục ở Chưa xếp, đếm "N mục chưa xếp" tăng 1 | |
| B5 | Lưu lại đúng link đã có | Hỏi: mở bản có sẵn / xem / vẫn lưu thêm | |
| B6 | Lưu link chỉ khác `utm_`, `si=`, `www`, `twitter.com`→`x.com` | Nhận là trùng | |
| B7 | Gõ chữ không có link; `mailto:`; `javascript:`; `ftp://` | Báo lỗi tại ô, không lưu | |
| B8 | Nút Dán khi clipboard trống / đã dùng | Thông báo đúng, không lưu | |
| B9 | Lưu (+) › Nhiều link: dán 10 link lẫn chữ | Đếm đúng số link, lưu đủ, bỏ chữ | |
| B10 | Lưu khi tắt mạng | Lưu ngay; tiêu đề/ảnh điền sau khi có mạng | |
| B11 | Lưu từ trong một bộ sưu tập | Vào thẳng bộ đó, dải chỉ báo "Đã lưu vào X" | |
| B12 | Lưu ảnh từ thư viện (1, nhiều, file 25 MB+, 50 MP+, ảnh hỏng) | Nhận đúng giới hạn, báo lỗi rõ, không lưu dở | |
| B13 | Chọn chữ trong Chrome › menu "Handy Bookmark" (PROCESS_TEXT) | Lưu link trong đoạn chữ | |
| B14 | Phím tắt app (nhấn giữ biểu tượng) | Mở đúng màn (Lưu link…) | |

## C. Nhận share từ app khác

Mỗi dòng: share từ app nguồn → bảng chia sẻ của Handy Bookmark hiện ảnh + tiêu đề, chọn/tạo bộ
`S …`. Ghi lại: tiêu đề, ảnh, nền tảng, loại (video/post/profile), bộ sưu tập, trùng.

| Mã | Nguồn (app thật) | Mong đợi | KQ |
| --- | --- | --- | --- |
| C1 | YouTube video (nút Share) | `youtu.be/…?si=` nhận đúng video, ảnh bìa, tiêu đề | |
| C2 | YouTube Shorts | Loại video, ảnh dọc/bìa, tiêu đề Short | |
| C3 | YouTube playlist, kênh | Loại playlist/profile | |
| C4 | Facebook bài viết | Nền tảng Facebook; tiêu đề có thể bị chặn → không lỗi, vẫn lưu | |
| C5 | Facebook Reel (`/share/r/`) | Loại video | |
| C6 | Facebook video, `fb.watch` | Loại video | |
| C7 | TikTok video (`vt.tiktok.com`) | Loại video; chữ kèm link được bỏ | |
| C8 | TikTok hồ sơ | Loại profile | |
| C9 | Instagram post `/p/` | Loại post | |
| C10 | Instagram Reel `/reel/…?igsh=` | Loại video; `igsh` không làm trùng thành khác | |
| C11 | Threads, X, Reddit | Đúng nền tảng | |
| C12 | Shopee/Lazada sản phẩm | Loại mua sắm | |
| C13 | Chrome trang web | Tiêu đề trang, ảnh og | |
| C23 | YouTube Music (bài hát, playlist) | Nền tảng YouTube Music, loại âm thanh/danh sách phát; không gộp với video YouTube cùng ID | |
| C24 | Spotify (bài, album, playlist, nghệ sĩ, podcast) | Âm thanh / danh sách phát / trang cá nhân | |
| C25 | ShopeeFood quán ăn | Nền tảng ShopeeFood, loại địa điểm, biểu tượng đồ ăn | |
| C26 | Grab Food quán ăn (`food.grab.com`, `r.grab.com`) | Nền tảng Grab, loại địa điểm | |
| C27 | Lazada sản phẩm (link rút gọn `s.lazada.vn`) | Mua sắm; share lần hai không thành mục trùng (bỏ `spm`, `laz_trackid`) | |
| C28 | Tiki sản phẩm (`tiki.vn`, `ti.ki`) | Mua sắm | |
| C29 | Pinterest pin (`pin.it`, `vn.pinterest.com/pin/`) | Loại ảnh | |
| C30 | Trình duyệt phổ biến: Chrome, Cốc Cốc, Edge, Firefox, Opera (Samsung Internet chỉ có trên máy Samsung, không test được trên emulator) | Mỗi trình duyệt: tiêu đề trang đúng (từ tiêu đề gửi kèm, hoặc chữ trước/sau link), không ra tên miền | |
| C31 | Safari (iPhone) | Tiêu đề trang từ Safari | BLOCKED: không có iPhone/Mac; chỉ sửa trong code |
| C32 | X | Nền tảng X, bỏ `?s=`/`?t=` | App X crash trên emulator: test bằng share giả lập và link x.com từ trình duyệt |
| C14 | Share nhiều link một lần (SEND_MULTIPLE) | Lưu đủ | |
| C15 | Share 1 ảnh, 20 ảnh, 21 ảnh | 20 nhận, quá 20 báo rõ | |
| C16 | Share khi app đang đóng / đang mở / bị khóa app | Lưu chắc chắn trước khi bảng hiện; khóa app thì không lộ danh sách bộ | |
| C17 | Đóng bảng không chọn | Ở Chưa xếp | |
| C18 | Tạo bộ mới ngay trong bảng | Bộ được tạo khi mở app, mục nằm trong đó | |
| C19 | Dòng đầu bảng ghi "Gợi ý" khi trang đó đã có trong một bộ | Đúng bộ | |
| C20 | Đặt nhắc từ bảng chia sẻ | Thông báo đến đúng giờ (mục O) | |
| C21 | Share lại link đã có | Không tạo bản trùng, báo đã có | |
| C22 | Share khi mất mạng | Vẫn lưu; tiêu đề điền sau | |

## D. Đọc tiêu đề, ảnh, nhận diện (dữ liệu nhập T1–T12)

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| D1 | Nhập `seed-links.html` | Xem trước: số link, trùng, lỗi; Thêm → 12 bộ T1–T12 + 1 mục Chưa xếp |PASS: 58 link → 55 mục, 12 bộ T1–T12, 1 Chưa xếp (lỗi #9, #10) |
| D2 | Mở từng bộ T1–T11 | Mỗi mục đúng nền tảng/loại; có ảnh khi trang có ảnh; không ảnh thì dải thấp ghi tên trang | |
| D3 | Trùng trong seed (`si=`, `utm_`, twitter.com) | Báo trùng ở bước xem trước, không nhập hai lần |FAIL #11 (3 cặp trùng bắt được, cặp Shorts `si=` thì không) |
| D4 | Bật/tắt "Đọc thông tin trang" trong Cài đặt | Tắt thì không tải gì từ mạng | |
| D5 | Làm mới một mục | Tiêu đề do người dùng đổi tên không bị ghi đè | |

## E. Trang chủ

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| E1 | Thư viện trống | Lời mời lưu, không có ô bộ sưu tập rỗng thừa | |
| E2 | Hàng chờ: N chưa xếp / N chưa đọc | Số khớp; một mục chỉ đếm một lần; chưa có bộ nào thì không có dòng Chưa xếp | |
| E3 | Hẹn đọc | Nhóm theo ngày, giờ đúng múi | |
| E4 | Bộ sưu tập | Bìa ảnh thật; bộ không ảnh hiện màu nhạt + biểu tượng; "Bộ sưu tập mới" là một dòng mỏng | |
| E5 | Mới lưu: nút gạt danh sách/lưới | Nhớ lựa chọn sau khi tắt mở app; hàng thẻ bằng nhau | |
| E6 | Dải đầu | Chỉ ghi "N mục"; Tìm và Cài đặt bấm được | |

## F. Chưa xếp và xếp nhanh

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| F1 | Thẻ "N mục chưa xếp" › Xếp nhanh | Từng mục, gợi ý đúng trang/từ, Bỏ qua, Hoàn tác, "Đã xếp xong" | |
| F2 | Nơi Chưa xếp › nút "Xếp vào" trên từng dòng | Gợi ý trước, "Bộ sưu tập khác…" | |
| F3 | Chọn nhiều › Chuyển | Chuyển hết, có Hoàn tác | |

## G. Tập trung

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| G1 | Mở từ thẻ "N mục chưa đọc" | Số thẻ = số mục trong hàng | |
| G2 | Vuốt phải/trái, nút Đã đọc/Để sau/Lưu trữ | Đúng hành động, Hoàn tác được | |
| G3 | Giảm chuyển động bật | Không có hiệu ứng bay, vẫn đúng | |
| G4 | Hết hàng | "Đã xem hết", nút về trang chủ | |

## H. Bộ sưu tập

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| H1 | Tạo bộ: tên, biểu tượng, emoji, màu | Hiện đúng ở trang chủ và Thư viện | |
| H2 | Sửa, đổi tên trùng tên bộ khác | Báo trùng hoặc cho phép rõ ràng | |
| H3 | Xóa bộ có mục | Hỏi chuyển mục đi đâu; không mất mục | |
| H4 | Thư mục con (Pro) | Free thấy lời mời Pro, Pro tạo được | |
| H5 | Chọn ảnh bìa | Bìa đổi; xóa mục làm bìa thì về tự động | |
| H6 | Gửi bộ sưu tập (HTML) và nhận lại trên máy khác/cùng máy | Trang mở được trong Chrome; nhận lại không trùng, tên "(từ bạn)" khi trùng tên | |

## I. Tìm, lọc, sắp xếp, thẻ

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| I1 | Tìm "pho ha noi" không dấu | Ra mục "Phở … Hà Nội" | |
| I2 | Lọc theo nguồn, loại, thẻ, ngày | Kết quả đúng, "Xóa bộ lọc" | |
| I3 | Sắp xếp các kiểu | Đúng thứ tự, nhớ theo từng bộ | |
| I4 | Thẻ: thêm, đổi tên, bấm thẻ | Đúng danh sách | |
| I5 | Tìm trong bản đọc offline | Ra đoạn khớp | |

## J. Chi tiết một mục

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| J1 | Chạm mục | Mở link gốc trong app nguồn/trình duyệt; đếm lần mở | |
| J2 | Menu … › Chi tiết | Mở bản gốc, Đọc, Yêu thích, Chuyển, Đổi tên, Làm mới, Chia sẻ, Nhắc, Thẻ, Ghi chú | |
| J3 | Chia sẻ ra ngoài | "tiêu đề + link", không kèm ghi chú | |
| J4 | Xóa + Hoàn tác | Về đúng chỗ | |
| J5 | Ảnh: xem, phóng to, chia sẻ bản sạch / bản gốc | Bản sạch không EXIF | |

## K. Đọc offline

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| K1 | Đọc một bài VnExpress, Wikipedia | Chữ chính, ảnh trong bài (tối đa 20) | |
| K2 | Lưu bản offline rồi tắt mạng | Đọc được | |
| K3 | Đổi cỡ chữ, nền | Giữ cho lần sau | |
| K4 | Đánh dấu đoạn, ghi chú | Còn sau khi tắt mở app | |
| K5 | Trang không đọc được (TikTok, PDF) | Báo rõ, không treo | |

## L. Kiểm tra link

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| L1 | Kiểm tra bộ T12 | 404/410 = không còn (thẻ có nhãn, ảnh xám); 301 = đã chuyển; 500/403/429/chậm/host sai = không xác định (không nhãn trên thẻ) | |
| L2 | Kiểm tra bộ T3–T6 (mạng xã hội) | Không mục nào bị ghi là hỏng | |
| L3 | Link hỏng › "Dùng địa chỉ mới" | Đổi địa chỉ, có Hoàn tác | |
| L4 | Dừng giữa chừng | Giữ kết quả đã có | |
| L5 | Kiểm tra hằng ngày khi mất mạng | Không đánh dấu gì | |

## M. Chọn nhiều

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| M1 | Nhấn giữ › chọn nhiều › Chuyển/Thẻ/Đã đọc/Yêu thích/Lưu trữ/Xóa/Sao chép/Xuất | Đúng cho mọi mục, Hoàn tác | |
| M2 | Chọn tất cả kết quả lọc (lớn) | Có tiến trình, Hủy trước khi ghi | |

## N. Thùng rác

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| N1 | Xóa mục, mục ảnh, mục có bản offline | Vào Thùng rác | |
| N2 | Khôi phục | Về đúng bộ, giữ bản offline | |
| N3 | Xóa hẳn, Dọn hết | Hỏi lại; không khôi phục được | |
| N4 | Mục quá 30 ngày (đổi ngày hệ thống) | Tự dọn | |

## O. Nhắc nhở và thông báo

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| O1 | Đặt nhắc 1 phút sau | Hỏi quyền lần đầu; thông báo đến đúng giờ | |
| O2 | Từ chối quyền | App nói rõ, có lối mở Cài đặt; không crash | |
| O3 | Chạm thông báo | Mở đúng mục | |
| O4 | Tắt app hẳn (vuốt khỏi đa nhiệm) trước giờ nhắc | Vẫn đến | |
| O5 | Khởi động lại máy trước giờ nhắc | Vẫn đến (BOOT_COMPLETED) | |
| O6 | Cập nhật app trước giờ nhắc | Vẫn đến (MY_PACKAGE_REPLACED) | |
| O7 | Xóa mục có nhắc | Nhắc bị hủy | |
| O8 | Đổi giờ/múi giờ hệ thống | Nhắc theo giờ mới đúng | |
| O9 | 50 nhắc cùng lúc | Giới hạn rõ, không mất nhắc | |
| O10 | Không làm phiền bật | Theo hệ thống | |

## P. Widget màn hình chính

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| P1 | Thêm widget Lưu nhanh | Chạm mở ô dán link | |
| P2 | Widget Hàng đọc (3 mục chưa đọc mới nhất) | Đúng mục; chạm mở mục | |
| P3 | Widget Bộ yêu thích | Đúng bộ, số mục; chạm mở bộ | |
| P4 | Widget Pro (Gợi ý đọc, Ảnh) | Free: lời mời Pro; Pro: nội dung | |
| P5 | Thêm/xóa/đọc mục trong app | Widget cập nhật | |
| P6 | Đổi kích thước, chế độ tối, tiếng Anh | Không cắt chữ, đúng màu | |
| P7 | Khóa app bật | Widget không lộ tiêu đề | |

## Q. Dữ liệu

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| Q1 | Sao lưu ZIP, xóa app, cài lại, khôi phục | Đủ mục, bộ, thẻ, ảnh, bản offline, thùng rác | |
| Q2 | Sao lưu có khóa mật khẩu (.hseal), sai mật khẩu | Báo sai, không ghi gì | |
| Q3 | Tự động sao lưu vào thư mục (SAF) | Có file theo lịch | |
| Q4 | Xuất JSON/CSV/HTML/Markdown/TXT, nhập lại | Đúng số mục | |
| Q5 | Nhập Pocket CSV/HTML | Bộ "Pocket", trạng thái đọc, thẻ | |
| Q6 | Nhập file hỏng, file 31 MB, ZIP có đường dẫn `../` | Từ chối cả file, không ghi dở | |
| Q7 | Gộp link trùng | Giữ nhãn, ghi chú, bộ của bản kia | |
| Q8 | Dọn bộ nhớ đệm ảnh | Ảnh tải lại được, dữ liệu không mất | |

## R. Cài đặt

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| R1 | Ngôn ngữ: hệ thống / Tiếng Việt / English | Đổi ngay, không cần mở lại |PASS: đổi Tiếng Việt có hiệu lực ngay |
| R2 | Giao diện sáng/tối/hệ thống | Mọi màn đúng màu, chữ đủ tương phản | |
| R3 | Khóa app (vân tay/PIN) | Hỏi khi mở; nền đa nhiệm che nội dung | |
| R4 | Tên thư viện | Hiện ở dải đầu | |
| R5 | Lịch sử tìm bật/tắt | Tắt thì xóa | |
| R6 | Trợ giúp, liên hệ, quyền riêng tư, "Các app Handy khác" | Mở đúng | |

## S. Pro và quảng cáo

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| S1 | Mua Pro trọn đời (tài khoản test, track nội bộ) | Mở khóa ngay | BLOCKED đến khi có track test |
| S2 | Khôi phục mua trên máy khác | Mở khóa | |
| S3 | Quảng cáo | Không có quảng cáo ở bất kỳ đâu (app cố ý không có, `lib/app.dart`) | |
| S4 | Tính năng Pro khi Free | Lời mời rõ, không mất dữ liệu đã có | |

## T. Giao diện, trợ năng, tiếng Anh

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| T1 | Cỡ chữ hệ thống lớn nhất + hiển thị lớn nhất | Không tràn, không cắt nút | |
| T2 | TalkBack: trang chủ, lưu, chi tiết, bảng chia sẻ | Đọc đủ nhãn, thứ tự hợp lý | |
| T3 | Xoay ngang, chia đôi màn hình | Bố cục rộng đúng | |
| T4 | Chế độ tối mọi màn | Không chữ chìm | |
| T5 | Lặp các màn chính bằng tiếng Anh | Không chữ tràn/cắt | |
| T6 | Cử chỉ Back, back dự đoán | Không thoát app ngoài ý muốn, không mất chữ đang gõ | |
| T7 | Rà UI: không bóng đổ xấu, không gradient, không hộp lồng hộp | Theo `docs/UX_REDESIGN.md` | |

## U. Bền và hiệu năng

| Mã | Cách làm | Mong đợi | KQ |
| --- | --- | --- | --- |
| U1 | 1.000 / 10.000 mục (nhập) | Cuộn mượt, tìm < 1 giây | |
| U2 | Tắt app (force stop) khi đang lưu/nhập | Không hỏng dữ liệu; mở lại đủ | |
| U3 | Bộ nhớ máy gần đầy | Báo lỗi rõ, không mất dữ liệu | |
| U4 | Mất mạng giữa lúc đọc/kiểm tra | Dừng an toàn | |
| U5 | Nâng cấp từ bản BlueStacks cũ (cùng ký) | Dữ liệu còn nguyên | |

## Z. Lỗi tìm thấy

| # | Ca | Mô tả | Mức | Trạng thái |
| --- | --- | --- | --- | --- |
| 1 | A2 | Màn chào: trang 1 và trang 2 đều ghi "Step 1 of 3"; thanh tiến trình không đổi giữa hai trang | Trung bình | Mở |
| 2 | A2, T5 | Màn chào tiếng Anh: nhãn "Ảnh chụp" vẫn là tiếng Việt | Trung bình | Mở |
| 3 | A1, A2, A3, T7 | Bóng đổ: thẻ ảnh ở màn chào, vệt bóng trên khung chữ dưới ở bước 3, ba ảnh ở trang chủ trống | Trung bình | Mở |
| 4 | A2 | Bước 2: tiêu đề "Saved to Good food" nhưng đoạn dưới kết "Nothing was saved." — đọc mâu thuẫn | Thấp | Mở |
| 5 | A2, T2 | Bước 2: nút Share giả không báo là nút bấm được; nội dung bảng chia sẻ chưa hiện vẫn nằm trong cây trợ năng (TalkBack đọc thứ không thấy) | Trung bình | Mở |
| 6 | A2 | Bước 3: hai mũi tên quay lại xếp chồng (màn chào và màn Search giả) | Thấp | Mở |
| 7 | A3 | Ô dán link trang chủ trống: chữ gợi ý bị cắt "Paste a link to sav…" ở 1080 px | Thấp | Mở |
| 8 | O2, R | Cài đặt › "Báo khi cần xử lý" bật sẵn nhưng ghi "Máy chưa cho phép thông báo. Tắt rồi bật lại để cho phép." — phải có nút Cho phép trực tiếp, không bắt tắt/bật | Trung bình | Mở |
| 9 | D1, Q | Nhập file HTML dấu trang trình duyệt chỉ có ở nút "Khôi phục"; màn "Nhập và xuất" (mô tả có ghi "Dấu trang trình duyệt") không có lối này | Trung bình | Mở |
| 10 | D1 | Xem trước khi nhập ghi "3 link đã có sẵn" lúc thư viện trống; thực ra là link trùng nhau trong file | Thấp | Mở |
| 11 | D3, B6 | Hai link Shorts chỉ khác `?si=` (`youtube.com/shorts/ID?si=…` và `www.youtube.com/shorts/ID`) không được nhận là trùng | Trung bình | Mở |
| 12 | R | Cài đặt có mục "Đồng bộ · Sắp có" trong bản production | Thấp | Mở |

## Ngoài phạm vi lần này

- Windows: chưa có trong bảng Share của Windows (chỉ dán, Ctrl+V, kéo thả). Làm Share Target khi
  đóng gói MSIX cho Microsoft Store; lần này ưu tiên Google Play.

## Tiêu chí ra production

Mọi ca A–U là PASS, hoặc BLOCKED/N/A có lý do được chủ app chấp nhận; không còn lỗi mức cao;
test tự động của app và engine đều xanh trên commit đem đi build.
