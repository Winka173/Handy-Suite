# Import/export — schema và giới hạn

Full JSON: app=handy-trip/schema=1, các collection có stable IDs, UTC instants,
IANA zones, exact-money minor strings và base64 managed bytes. ZIP có manifest
formatVersion/appVersion/exportedAt/timezone/counts, data.json, assets/, previews/,
size/SHA-256 từng entry. Không absolute paths. Không dùng public report để restore.

Import full backup: bounded decode, ZIP traversal/bomb guard, schema/FK/hash/count/
media signature validation, preview, merge hoặc replace xác nhận lần hai; CAS revision
và transaction giữ dữ liệu trước nếu lỗi. Merge remap mọi entity/reference/asset path,
tắt incoming alarms, không nhập entitlement, không sync tài chính. Undo một bước trong
phiên, không hứa Undo sau restart. Duplicate merge cùng digest bị từ chối.

Giới hạn công khai: 30 MB/gói, 998 payload entries, ảnh/PDF tối đa 12 MB, ảnh 16 MP,
managed library tối đa 300 MB; không streaming toàn thư viện vô hạn. Chọn chuyến/ngày
để chia gói. Vượt giới hạn báo lỗi và giữ nguyên dữ liệu; không âm thầm cắt bớt.
Export có picker cancel; import preview cancel không ghi database. Chưa có cancel
giữa một lần tính toán PDF/ZIP, đây là giới hạn còn mở.

CSV riêng: kind,id,title,day,currency,minor,record_b64. Lossless private payload,
display columns phải khớp; không bỏ qua thay đổi trong bảng tính. Conflict IDs từ chối;
cần parent IDs/assets đã có. Generic CSV chọn destination itinerary hoặc wishlist,
map cột; ngày YYYY-MM-DD, giờ HH:mm, tọa độ hữu hạn, không geocode.
JSON itinerary interchange: {"app":"handy-trip-itinerary","schema":1,
"stops":[{"title":"Lunch","day":"2026-11-02","time":"12:00","placeName":"User label"}]}.
Cần chọn target trip; địa điểm không khớp giữ thành note, không tự tạo visited.

ICS: all-day/UTC/TZID, SUMMARY/UID/DTSTART/DTEND, escaping/folding UTF-8;
không recurrence, không seconds khác 00, không âm thầm làm mất precision.
GeoJSON/KML/GPX chỉ points, tối đa 10000 điểm/3 MB; không route/track hoặc XML DTD.
Imported points thành wishlist. Export precise coordinates cần consent riêng.

Public JSON/Markdown/PDF/ICS whitelist loại booking codes/private notes/addresses/GPS.
Public album ZIP dùng tên mới và JPEG RGB reencode bỏ EXIF, chỉ ảnh nhật ký,
không booking attachments. Nội dung nhìn thấy trên ảnh vẫn cần người dùng kiểm tra.
Private journal JSON/Markdown và full backup có cảnh báo rõ; backup giữ nguyên ảnh gốc.
PDF/album có giới hạn riêng để tránh quá bộ nhớ. Hủy/lỗi không xóa gallery/source file.

P1: personal stamp PNG/PDF không có GPS/mã booking, ghi rõ unofficial. Memory Book
PDF và HTML ZIP có hai layout, tối đa 366 ngày/100 ảnh; private notes/captions và
expense totals đều opt-in, mặc định bỏ. HTML được escape, không script/network;
ảnh reencode bỏ EXIF, manifest/hash trong ZIP. Nội dung ảnh vẫn cần review.
Recipe lịch trình giữ title/day/time/end/duration/type/fold/order/placeName, bỏ
history/booking/finance/private notes/assets/GPS. Zone khác target bị từ chối;
không tự sửa thời gian. Round-trip tests kiểm tra schema đang hỗ trợ.
