# Review UI Flutter

Ảnh từ Android emulator với dữ liệu QA riêng. Không phải chứng nhận thiết bị thật,
iOS hoặc coverage mọi màn hình. Một số ảnh dùng debug theme/banner của test harness.

| App / luồng       | Ảnh                                                                                                                                                                                                                                                                               |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Docs              | [Scanner](qa/evidence/screenshots/docs-four-corners.png), [Markdown](qa/evidence/screenshots/docs-markdown-editor.png), [PDF](qa/evidence/screenshots/docs-pdf-preview.png), [Reader](qa/evidence/screenshots/docs-reader-safe-html.png)                                          |
| Media Quick Tools | [Crop](qa/evidence/screenshots/media-interactive-crop.png), [Watermark](qa/evidence/screenshots/media-vietnamese-watermark.png), [Metadata](qa/evidence/screenshots/media-exif-gps.png), [Subtitle](qa/evidence/screenshots/media-subtitles.png)                                  |
| Media editor      | [Annotation](qa/evidence/screenshots/media-annotation-editor.png), [Draft restore](qa/evidence/screenshots/media-editor-draft-restored.png), [Zoom/pan](qa/evidence/screenshots/media-editor-zoom-pan.png), [Share review](qa/evidence/screenshots/media-editor-share-review.png) |
| Media khác        | [Catalog](qa/evidence/screenshots/media-catalog-search.png), [Cleanup](qa/evidence/screenshots/media-cleanup-confirm.png), [Guide exports](qa/evidence/screenshots/media-guide-exports.png), [Video](qa/evidence/screenshots/media-video-rotated-muted.png)                       |
| Tools             | [Calculator](qa/evidence/screenshots/tools-calculator.png), [Export history](qa/evidence/screenshots/tools-export-history.png), [QR history](qa/evidence/screenshots/tools-optional-qr-history.png)                                                                               |
| Dev               | [JSON](qa/evidence/screenshots/dev-json-formatter.png), [Schema](qa/evidence/screenshots/dev-json-schema.png), [API collections](qa/evidence/screenshots/dev-api-collections.png), [Pins](qa/evidence/screenshots/dev-pinned-tools.png)                                           |
| Keep              | [Inventory](qa/evidence/screenshots/keep-home-light.png), [Receipt](qa/evidence/screenshots/keep-pdf-receipt.png), [Recovery](qa/evidence/screenshots/keep-preserved-library-recovery.png)                                                                                        |
| Recall            | [Decks](qa/evidence/screenshots/recall-home-light.png), [Study](qa/evidence/screenshots/recall-study-answer.png)                                                                                                                                                                  |

Các ảnh khác và raw logs nằm trong [qa/evidence](qa/evidence).
Giới hạn đã biết, gồm preview video emulator: [KNOWN_ISSUES](../KNOWN_ISSUES.md).

## Handy Save

Ảnh từ emulator HandySave_QA_API35, dữ liệu QA riêng:

- [Inbox](qa/evidence/screenshots/save-inbox.png)
- [Library và tìm kiếm](qa/evidence/screenshots/save-library-search.png)
- [Collections](qa/evidence/screenshots/save-collections.png)
- [Focus](qa/evidence/screenshots/save-focus.png)
- [Cài đặt](qa/evidence/screenshots/save-settings.png)
- [Quick Add](qa/evidence/screenshots/save-quick-add.png)
- [Nhận share khi app đóng](qa/evidence/screenshots/save-cold-share.png)
- [Nhận share khi app đang mở](qa/evidence/screenshots/save-warm-share.png)
- [Chuyển sang trình xử lý URL Android](qa/evidence/screenshots/save-open-system-handler.png)

Ảnh chuyển URL là màn hình Chrome First Run trên emulator mới; kiểm tra xác nhận
đã chuyển ra ngoài Handy Save, chưa xác nhận website tải thành công.

Test widget có màn hình hẹp 360px và text scale 1.6; editor còn có test 320px,
text scale 2.0. Đây là các mẫu kiểm tra cụ thể, chưa phải chứng nhận accessibility
hoặc mọi kích thước. Luồng Ads/Pro cần cấu hình store thật trước review phát hành.

## Handy Spend

Ảnh Android emulator HandySpend_QA_API35, dữ liệu QA riêng, giao diện tiếng Anh:

[Mở bản PDF gồm 11 màn hình](qa/evidence/spend-ui-review.pdf).

Snapshot `8655b2af2608`; [audit](qa/evidence/spend-checkpoint-audit.json).
Dấu chạm màu xanh trong ảnh là overlay của môi trường QA.

- [Home](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-home.png), [Giao dịch](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-transactions.png), [Báo cáo](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-reports.png).
- [Kế hoạch](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-plan.png), [Sandbox](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-sandbox.png), [Thêm giao dịch](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-add-transaction.png).
- [Ánh xạ sao kê](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-import-map.png), [Duyệt dòng nhập](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-import-review.png), [Đối chiếu và Undo](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-import-result.png).
- [Tài khoản](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-accounts.png), [Cài đặt](qa/evidence/spend-candidate-8655b2af2608/screenshots/spend-settings.png).

Spend bật nhãn luôn hiển thị trên trường nhập/chọn để nhận biết chức năng cả khi
đã có giá trị. Theme mặc định của các app khác được giữ nguyên.

Luồng CSV kiểm tra số dư sau nhập và sau Undo, mở lại SQLite để xác nhận dữ liệu.
File đầu vào đi qua wizard thật; chưa kiểm tra thao tác chọn file bằng OS provider.
Ảnh đang cuộn có thể chỉ hiện một phần trang. Không dùng ảnh làm bằng chứng cho
thiết bị thật, iOS, browser hoặc giao dịch Ads/Pro.

## Handy Habit

[Complete PDF](qa/evidence/habit-ui-review.pdf) /
[HTML gallery](qa/evidence/habit-ui-review.html). Actual bundled-font widget renders
cover Today, Habits, Routines, Insights, builder, Lite, running/paused states, settings,
habit history/editor and dark/empty onboarding. Android captures include the routine
flow, recovery and the production notification-denied UI. Captions distinguish widget
renders from emulator screenshots; neither is physical-device, iOS or browser proof.

Review against the app-screen skill: the daily action and runner completion button
remain primary; teal marks progress without coloring every row; titles, units and
notes wrap, modal actions stay reachable by scroll. Four automated accessibility cases
pass contrast, tap targets and labels in all main areas at mobile/desktop widths.
Long habit forms/history remain scrollable; extreme text scaling and assistive-tech
runtime still require device review. The PDF is evidence for review, not a UI approval.
