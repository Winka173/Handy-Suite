# Handy Suite Flutter functions

Seven independent local-first Flutter apps. Current code/test status: [FEATURE_MATRIX](../FEATURE_MATRIX.md).
Known limits: [KNOWN_ISSUES](../KNOWN_ISSUES.md). Screenshots: [UI_REVIEW](UI_REVIEW.md).

## Handy Save

Ứng dụng lưu và tổ chức link, hoạt động offline. Chi tiết trạng thái từng phần:
[Handy Save feature matrix](HANDY_SAVE_FEATURE_MATRIX.md).

- Màn Đã lưu: ô tìm, dải Chưa xếp (mỗi link mới có sẵn các bộ sưu tập hay dùng, một
  chạm là xếp xong), danh sách nơi (Chưa xếp, Tất cả, Yêu thích, Chưa đọc, Lưu trữ,
  bộ sưu tập lồng nhau, bộ thông minh, thẻ) và Tập trung; desktop ba cột (nơi, link,
  chi tiết); dạng dòng/thẻ, tải thêm khi cuộn; lọc theo nguồn, loại, thẻ, ngày lưu và
  thứ tự; lịch sử tìm (bật trong Cài đặt).
- Nhận một/nhiều URL từ văn bản; chuẩn hóa bảo thủ, giữ URL gốc, phát hiện trùng;
  mở bản có sẵn, lưu thêm hoặc xem thông tin để hợp nhất thủ công.
- Android nhận SEND/SEND_MULTIPLE bằng hàng chờ bền vững; iOS có Share Extension
  dùng App Group; Windows nhận text/URL/.url qua kéo thả; Web có POST Share Target.
  Clipboard chỉ được đọc khi người dùng bấm nút.
- Bookmark: tiêu đề, mô tả, ghi chú, tags, bộ sưu tập; favorite, pin, read, archive;
  chỉnh sửa/xóa, Undo, mở/copy URL gốc và đếm lần mở.
  Bấm bookmark mở URL gốc; menu Chi tiết mở thông tin và các thao tác quản lý.
- Bộ sưu tập lồng nhau, màu/icon, quản lý tags độc lập; lọc theo collection, tag,
  nền tảng, loại nội dung, cờ trạng thái và ngày lưu/mở; nhiều kiểu sort, thứ tự thủ công.
- Smart Collections AND/OR và saved searches dùng quyền Pro Lifetime đã xác thực;
  điều kiện văn bản, cờ, ngày tương đối, ngày tuyệt đối và số lần mở.
- Focus theo hàng đợi chưa đọc; mở, đánh dấu, bỏ qua, lưu trữ hoặc chuyển collection.
- Batch move/tag/read/favorite/archive/delete/copy/export; chọn toàn bộ kết quả lọc
  có tiến trình và hủy trước commit; Undo từ chối ghi đè thay đổi mới hơn.
- Metadata tùy chọn, mặc định tắt; native kiểm tra public IP, redirect, MIME, dung
  lượng, timeout/cancel. Không đăng nhập/cookies. Thumbnail raster được xác thực,
  encode lại và cache có giới hạn; có thể nhập thumbnail từ file. Web không fetch
  metadata khi không bảo đảm được chính sách mạng. Lưu link không cần metadata.
- Nhắc xem lại theo preset hoặc ngày/giờ; Android/iOS có tích hợp local notifications,
  Windows/Web có danh sách trong app. Chưa chứng nhận giao thông báo nền/reboot.
- Nhập/xuất JSON, CSV, HTML, Markdown, TXT và ZIP; preview, thống kê lỗi/trùng,
  merge/replace có xác nhận; giữ đầy đủ cấu trúc khi round-trip giữa Handy Save.
  Backup tối đa 30MB, không kèm thumbnail cache.
- SQLite/FTS chạy worker trên native, IndexedDB trên Web; giao dịch nguyên tử,
  kiểm tra integrity, đóng/mở lại, lưu bản phục hồi trước reset và dọn cache.
- EN/VI, theme, lịch sử tìm kiếm tùy chọn mặc định tắt; thông tin quyền riêng tư;
  Ads + Pro Lifetime theo shared adapters, không quảng cáo trong quick-save/share/open.

Không có backend, đồng bộ cloud, tải video hay cloud AI. iOS, thiết bị vật lý,
browser runtime, app mạng xã hội thực và giao dịch store cần kiểm chứng riêng.
Xem [giới hạn](HANDY_SAVE_KNOWN_LIMITATIONS.md) và [test plan](HANDY_SAVE_TEST_PLAN.md).

## Chức năng chung

| Nhóm         | Chức năng hiện có                                                                                                         | Giới hạn cần giữ rõ                                                                               |
| ------------ | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Giao diện    | Theme sáng/tối/theo hệ thống; ngôn ngữ EN/VI/theo hệ thống; điều hướng riêng từng app, bố cục mobile/desktop              | Chưa chứng nhận mọi kích thước, accessibility và nền tảng                                         |
| Dữ liệu      | Xử lý local; shared packages Dart; cấu trúc dữ liệu có version; đọc dữ liệu version 1 bằng import rõ ràng                 | Flutter không tự đọc sandbox external application storage cũ; URI cũ không tự dereference         |
| Nhập/xuất    | File picker, giới hạn byte/kích thước; tên file an toàn; xuất bản sao; tiến trình/hủy trong luồng hỗ trợ                  | Quyền và file provider phụ thuộc OS; không ghi đè file gốc tự động                                |
| Camera/share | Camera ở luồng tài liệu/ảnh; share qua OS ở luồng có nút chia sẻ                                                          | Camera native Android/iOS; Android emulator đã thử; nhận file ở app đích chưa chứng nhận          |
| ZIP          | Manifest/assets/checksum, kiểm tra đường dẫn, file lỗi, giới hạn giải nén; roundtrip tests                                | Không nhận ZIP tùy ý như thư viện giải nén tổng quát                                              |
| Khôi phục    | Native snapshot đã kiểm tra, preserve/reset, xuất diagnostic ZIP, undo reset; Web IndexedDB transaction                   | Xóa bản ghi không phải cam kết secure erase; power loss/multiwriter/browser eviction còn giới hạn |
| Cài đặt      | Backup/import cài đặt từng app; từ chối backup khác app; reset preferences, xóa input đã lưu, xóa preview RAM có xác nhận | Giữ thư viện, ảnh/hóa đơn, file xuất và quyền mua; không quét/xóa thư mục tùy ý                   |
| Text tools   | Pin, lưu/nạp input rõ ràng, Undo/Redo, workflow text allowlist, metadata lịch sử xuất và chia sẻ lại có kiểm tra file     | Chỉ ở tool được hỗ trợ; không lưu nội dung kết quả/token trong lịch sử; secret không autosave     |
| Doanh thu    | Free + Ads + Pro Lifetime; native adapters, restore/purchase UI và cấu hình riêng từng store                              | Chưa có tài khoản/ID/cấu hình thật; không coi test adapter là giao dịch/ads thật                  |
| Phân phối    | Android, iOS, Windows, Web source targets; PWA cache riêng app và kích hoạt update rõ ràng; MSIX development              | iOS chưa build trên Windows; MSIX chưa ký; browser runtime và store approval chưa xác nhận        |

## Handy Docs

Source: `apps/handy_docs/lib`, `packages/handy_docs_engine`, `packages/handy_pdf`.

- **Markdown:** sửa source, preview GFM, tìm/thay thế literal, template, highlight
  code local; xuất Markdown/HTML/text/PDF và ZIP gồm source + các bản xuất.
  Desktop soạn và xem trước cạnh nhau; Ctrl S lưu, Ctrl F tìm, Ctrl P xuất PDF;
  rời trình soạn khi chưa lưu sẽ được hỏi. Recipe md-text dùng workflow chung
  (Cài đặt → Quy trình văn bản). Mermaid chưa có renderer offline được kiểm chứng.
- **Bàn làm việc:** màn chính hiện việc dở (bản quét, bản nháp, PDF đang mở, tài
  liệu đọc chưa lưu) như xấp giấy, bốn lối bắt đầu và tài liệu đọc gần đây.
- **Scanner:** nhập ảnh/camera, crop bốn góc kéo trực tiếp, sửa phối cảnh,
  tương phản, nhiều trang, sắp xếp/xóa trang, ghép PDF, lưu/khôi phục session JSON.
  Không OCR/AI. Scanner giới hạn cạnh 2048 / 4Mpx mỗi trang, session 16MB/16Mpx.
- **PDF:** mở/preview qua PDFium ở nền tảng native hỗ trợ; ghép PDF, chọn/extract
  trang, reorder, duplicate, xoay, render trang ra PNG, watermark text ASCII.
  Bảo toàn source; không hứa sửa mọi cấu trúc hoặc mã hóa PDF.
- **Reader library:** nhập một/nhiều file UTF-8 text/code/Markdown/HTML, giữ nguyên
  BOM/CRLF/source khi ZIP; tìm, recent, favorite, folder, rename; xuất/restore thư
  viện. HTML đọc như nội dung an toàn, không thực thi script hoặc tải remote.
- **Giới hạn text:** source 1MB; render/export rendered Markdown 100KB. Các giới
  hạn bổ sung, native adapter và coverage nằm trong FEATURE_MATRIX.

## Handy Media

Source: `apps/handy_media/lib`, `packages/handy_media_engine`, `packages/handy_capture`.

Màn chính là **Xưởng**: các hướng dẫn (mới nhất trước, mỗi cái một dải phim các bước),
rồi công cụ nhanh Sửa ảnh, Phụ đề và (Android/iOS) Chụp màn hình.

### Quick Tools

- Nhập ảnh từ file/camera, batch ảnh; crop kéo/resize trực tiếp, preset tỉ lệ,
  resize, rotate, flip ngang/dọc; convert PNG/JPEG/static WebP.
- Watermark text hoặc logo, vị trí/kích thước và xuất batch bằng engine chung.
- Xem/xóa EXIF/GPS **PNG/JPEG đã kiểm chứng**. JPEG strip bỏ orientation:
  cần preview kết quả. Không tuyên bố mọi metadata/định dạng đều được hỗ trợ.
- WebP input 16Mpx; encode 4Mpx; animated WebP bị từ chối.
- Subtitle SRT/VTT: parse/convert, kiểm tra timing, dịch thời gian với xem trước các
  câu đầu trước/sau; Lưu kiểm tra lại toàn tệp. Không có tự nhận dạng giọng nói.

### Capture & Annotate

- Thư viện project: tạo, mở, tìm, xóa có xác nhận; metadata/tags, các bước có
  title/body, reorder/xóa; import project v1 JSON và portable project ZIP.
- Nhập nhiều screenshot hoặc camera vào cùng editor. Kiểm tra toàn batch trước
  khi thay đổi; ảnh thiếu từ project cũ phải relink rõ ràng.
- 9 loại annotation: arrow, rectangle, ellipse, highlight, opaque redact, text,
  step number, freehand pen, spotlight. Chọn/kéo/resize, style, alignment, thứ tự
  layer, xóa, Undo/Redo, lặp vùng che sang bước khác theo công cụ hiện có.
- Zoom 1–3× và pan riêng chế độ chỉnh layer; edit ảnh rotate90, resize50, crop theo
  vùng chọn qua renderer chung, có xác nhận flatten và Undo.
- Draft riêng từng project, debounce 500ms, restore/discard; write có thứ tự,
  lỗi vẫn giữ project đã lưu. Sau restart không phục hồi Undo stack; phần thay
  đổi trong cửa sổ debounce chưa bảo đảm. Xem [recovery](DEVELOPMENT.md).
- Xuất flattened PNG; preview trước khi share PNG; guide HTML/PDF/Markdown,
  flattened ZIP, long image, change map. Review captions/masks trước khi xuất.
- ZIP project gồm manifest + assets để chuyển máy, giữ ảnh PNG gốc byte-exact.
  JSON/ZIP editable chứa ảnh gốc; không dùng chúng để giấu pixel nhạy cảm.
- Version 1 PNG tới 32Mpx được giữ nguyên; output flatten tối đa 16Mpx; guide dùng
  giới hạn nhỏ hơn. Tối đa 100 bước, 8MB/PNG, 20MB ảnh active, thư viện serialize 30MB.

### Screen capture/video native

- Android: MediaProjection với hộp thoại đồng ý thật, screenshot PNG, quay H264
  MP4; import video, trim theo keyframe, join clip tương thích, lấy frame, xuất,
  preview play/pause/seek và hủy/cleanup capture do app quản lý.
- Transform tạo bản MP4 H264/AAC: rotate bội 90°, resize không upscale, mute;
  kiểm tra owned URI, giới hạn input 5 phút/output 30MB, hủy và xóa output dở.
  Không phải bộ chuyển mọi codec/container.
- iOS: ReplayKit quay **nội dung trong app**, AVFoundation trim/join/frame/
  transform source. Chưa build/run bằng Xcode; không tuyên bố quay toàn hệ thống.
- Windows/Web: import thay cho giả lập screen capture native chưa triển khai.
- Android emulator đã kiểm tra codec/output độc lập. Preview texture còn lỗi viền
  xanh trên emulator; MP4 decode độc lập không có viền. Thiết bị thật chưa xác nhận.

## Handy Tools

Source: `apps/handy_tools/lib`, `packages/handy_tools_engine`.

- 23 tool đăng ký ở bảng cuối tài liệu; calculator/converter có form chuyên dụng.
  Phép tính dùng quy tắc rõ ràng; tỷ giá nhập tay, không có feed giá trực tuyến.
- Password generator dùng secure random, tùy độ dài/nhóm ký tự và tùy chọn
  tránh ký tự khó phân biệt. Không lưu password vào history.
- QR text/URL, Wi-Fi, contact và calendar event; xuất PNG/SVG/PDF, preview nội dung
  an toàn trước khi hành động, history QR tùy chọn và xóa history.
- QR decoder/camera native; có fallback nhập/paste khi không hỗ trợ. Android đã
  test decode ảnh và quyền bị từ chối; live optical/interoperability chưa đủ bằng chứng.
- Text workflow/pins/drafts/input Undo và export metadata theo các tool allowlist.

## Handy Dev

Source: `apps/handy_dev/lib`, `packages/handy_dev_engine`, `third_party/re2`,
`third_party/json_schema`; 28 tool đăng ký được liệt kê cuối tài liệu.

- JSON tree/table, search/projection; format/minify/diff, JSONPath subset,
  JSON↔YAML/TOML/XML/CSV, JSONL; infer TypeScript/JSON Schema từ mẫu.
- JSON Schema draft-07 local, bounded evaluation, không tải external references;
  898 case conformance pass, 27 remote case bỏ qua theo chính sách offline.
- Regex RE2 native và RE2JS vendored trên Web: không backreference/lookaround;
  input/pattern/match có giới hạn để tránh regex backtracking.
- API client HTTPS: method/query/body/headers, Basic/Bearer/API-key authentication,
  timeout/cancel và response có giới hạn, collections, environments, biến template,
  import/export các dạng cURL phổ biến. Không phải shell cURL đầy đủ.
- Secrets ở session; loại khỏi export/lưu mặc định; không log token. JWT chỉ
  decode, không xác minh chữ ký; HAR summary bỏ URL/header/body; .env sample chỉ
  tên biến; redact JSON cần review. Secret tools không autosave draft/recipe.
- Live endpoint, redirect/provider và browser CORS cần kiểm chứng tiếp.

## Handy Keep

Source: `apps/handy_keep/lib`, `packages/handy_inventory`.

- CRUD hồ sơ đồ dùng; tên/vị trí/thông tin mua, ảnh (chụp bằng camera trên
  Android/iOS hoặc chọn file PNG/JPEG ≤4 MB, kiểm tra chữ ký file); tìm không dấu theo
  tên/chỗ để/thùng/người mượn/serial/ghi chú; danh sách xếp theo chỗ ở hiện tại (người
  mượn, thùng, chỗ để); lọc Đang cho mượn/Theo thùng/Chưa vào thùng; cho mượn và trả;
  ngày mua/bảo hành/bảo dưỡng chọn bằng lịch; dải "Cần để ý" (quá hạn và 30 ngày tới)
  và trang Đến hạn.
- Thùng chuyển nhà: tạo/sửa/xóa (xóa thùng giữ lại đồ bên trong), gán đồ vào thùng;
  nhãn QR item/box, xuất ảnh mã QR hoặc cả tấm nhãn có tên (PNG 3×) để in; mở hồ sơ local bằng `handy-keep://item/<id>` hoặc
  `handy-keep://box/<id>`. Không tải URL nhãn qua mạng.
- Hóa đơn ảnh/PDF đính kèm hồ sơ; xuất dossier TXT và review trước share qua OS.
- Backup ZIP dữ liệu + ảnh/hóa đơn, checksum; restore merge/replace có xác nhận,
  staged validation; giữ dữ liệu cũ khi file lỗi/hủy/save thất bại. Version 1 JSON
  không tự đọc absolute image paths không tin cậy.
- Local notifications cho mốc đến hạn: xin quyền, schedule/cancel và cấu hình
  local. Android đã test deny/grant/schedule/immediate delivery; delayed,
  background, reboot và iOS chưa đủ bằng chứng.

## Handy Recall

Source: `apps/handy_recall/lib`, `packages/handy_recall`.

- CRUD deck/card; question/answer; màn Hôm nay: số thẻ đến hạn, thời gian ước tính và
  lịch ôn 14 ngày; buổi ôn toàn màn hình: lật đáp án (phím cách), chấm Quên/Khó/Nhớ/Dễ
  (phím 1–4), mỗi nút ghi khoảng cách tới lần ôn sau theo scheduler thật; "Lưu, thêm
  thẻ khác" để nhập liền tay; scheduler spaced repetition và lịch sử/review state
  được giữ qua backup.
- Import/export CSV question/answer; backup/restore JSON có schedule và ảnh
  embedded bounded; import thẻ cũ một mask sang nhiều mask.
- Image occlusion: nhập ảnh, tạo nhiều vùng che trên cùng ảnh, kéo/resize trực
  tiếp, chọn/xóa vùng, lưu và ôn qua editor/state chung. Không OCR/AI.
- Local notifications nhắc ôn với xin quyền, schedule/cancel; giới hạn kiểm chứng
  delayed/background/reboot/iOS giống Keep.

## Verification limits

Code presence does not establish device or release certification. iOS builds,
physical devices, browser runtime/offline/update, real store transactions and
AdMob setup remain open. Current issues are recorded in [KNOWN_ISSUES](../KNOWN_ISSUES.md).

## Registry công cụ chính xác từ source Flutter

Hai bảng dưới được trích từ registry Dart hiện tại; mô tả gốc bằng tiếng Anh giữ
nguyên để tránh diễn giải sai quy tắc xử lý. Các thao tác ngoài registry đã được
liệt kê theo từng app ở trên.

### Handy Tools

| ID                | Tool                      | Behavior / limits                                                                        |
| ----------------- | ------------------------- | ---------------------------------------------------------------------------------------- |
| `calculate`       | Máy tính                  | Operators + − * / % ^, parentheses, sqrt/abs/sin/cos/tan/log. Trigonometry uses radians. |
| `units`           | Đổi đơn vị                | Compatible units; C/F/K supported.                                                       |
| `loan`            | Lịch trả nợ               | Fixed annual rate, monthly installments; excludes fees and taxes.                        |
| `compound`        | Lãi kép                   | No additional contributions, tax or fees.                                                |
| `percent`         | Phần trăm                 | Percentage value and amount after discount.                                              |
| `dates`           | Khoảng cách ngày          | Calendar days in UTC; end minus start.                                                   |
| `normalize`       | Chuẩn hóa khoảng trắng    | NFC Unicode, trim each line, collapse spaces and tabs.                                   |
| `deduplicate`     | Lọc dòng trùng            | Keep first exact occurrence.                                                             |
| `sort`            | Sắp xếp dòng              | Unicode code-point order, independent of locale.                                         |
| `uppercase`       | Viết hoa                  | Unicode uppercase.                                                                       |
| `lowercase`       | Viết thường               | Unicode lowercase.                                                                       |
| `accents`         | Bỏ dấu                    | Remove combining marks and map Vietnamese đ/Đ.                                           |
| `count`           | Đếm văn bản               | Code points, UTF-16 units, whitespace-separated words and lines.                         |
| `contrast`        | Độ tương phản             | WCAG contrast; normal text AA requires 4.5.                                              |
| `tax`             | Tính thuế                 | Amounts round half up to two decimals.                                                   |
| `split-bill`      | Chia hóa đơn và tiền tip  | Rounded cents are allocated exactly; extra cents go to first shares.                     |
| `ratio`           | Tính tỷ lệ                | Proportional new second term.                                                            |
| `manual-exchange` | Đổi tiền theo tỷ giá nhập | User-provided rate only; no live rate lookup.                                            |
| `business-days`   | Số ngày làm việc          | Start inclusive, end exclusive. Weekend indices Sun=0, Sat=6.                            |
| `title-case`      | Viết hoa đầu từ           | Unicode letter groups; not language-specific editorial rules.                            |
| `sentence-case`   | Viết hoa đầu câu          | Capitalize first letter and after . ! ?; abbreviations not inferred.                     |
| `literal-replace` | Tìm và thay thế           | Literal replacement, bounded to one million UTF-16 units.                                |
| `colors`          | HEX / RGB / HSL           | HEX input, HSL in degrees and percentages.                                               |

### Handy Dev

| ID                  | Tool                 | Behavior / limits                                                                                                                  |
| ------------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `schema`            | Kiểm tra JSON Schema | Local draft-07 validation with RE2 patterns. 20 KB schema; external references and format assertions disabled; bounded evaluation. |
| `regex`             | Biểu thức RE2        | Local RE2; no lookaround/backreferences. 100 KB input / 1000-byte pattern / 1000 matches; bounded capture output.                  |
| `json-typescript`   | JSON → TypeScript    | Infer a sample type; missing array fields optional, no runtime validation.                                                         |
| `json-schema-infer` | Suy luận JSON Schema | Draft-07 inference from sample only.                                                                                               |
| `json-toml`         | JSON → TOML          | Reject null/unsafe integers and lossy roundtrip.                                                                                   |
| `jsonpath`          | JSONPath giới hạn    | Supports $, .name, [index], [*], ["key"]; no scripts or filters.                                                                   |
| `json-project`      | Chọn trường JSON     | Object array; options are JSON field-name array.                                                                                   |
| `json`              | Định dạng JSON       | Strict JSON format.                                                                                                                |
| `json-min`          | Rút gọn JSON         | Validate and minify.                                                                                                               |
| `yaml-json`         | YAML → JSON          | Reject duplicate keys, cycles and excessive aliases.                                                                               |
| `json-yaml`         | JSON → YAML          | JSON flow syntax is valid YAML 1.2; preserves scalar types.                                                                        |
| `toml-json`         | TOML → JSON          | Parse TOML; dates emitted as ISO strings.                                                                                          |
| `xml-json`          | XML → JSON           | Attributes @_ and #text; mixed-content mapping is partial; DTD disabled.                                                           |
| `json-xml`          | JSON → XML           | Exactly one root key; attributes @_ and #text.                                                                                     |
| `csv-json`          | CSV → JSON           | Auto delimiter; strict header/field count; strings retained.                                                                       |
| `json-csv`          | JSON → CSV           | Flat objects only; spreadsheet formulas escaped (lossy).                                                                           |
| `jsonl`             | JSONL → JSON         | Parse nonempty lines as JSON.                                                                                                      |
| `base64-encode`     | Mã hóa Base64        | UTF-8 text.                                                                                                                        |
| `base64-decode`     | Giải mã Base64       | Strict UTF-8 and canonical unused bits.                                                                                            |
| `url-encode`        | Mã hóa URL           | Encode a UTF-8 component.                                                                                                          |
| `url-decode`        | Giải mã URL          | Reject invalid UTF-8/percent escapes.                                                                                              |
| `sha256`            | SHA-256              | Local UTF-8 hash.                                                                                                                  |
| `sha512`            | SHA-512              | Local UTF-8 hash.                                                                                                                  |
| `jwt`               | Giải mã JWT          | Decode only; signature NEVER verified; no saved drafts.                                                                            |
| `json-diff`         | So sánh JSON         | Before JSON; options after JSON. JSON Pointer paths.                                                                               |
| `env-sample`        | .env mẫu             | Export names only; remove all values.                                                                                              |
| `har`               | Tóm tắt HAR          | Only method, status, duration; omit URLs/headers/bodies.                                                                           |
| `redact`            | Ẩn bí mật JSON       | Mask common credential keys recursively; review before sharing.                                                                    |
