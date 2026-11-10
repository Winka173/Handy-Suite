# Handy Habit — audit run 1

Ngày 10/11/2026. Chỉ audit/kiến trúc/UX contract, chưa triển khai. Đọc working tree kể cả thay đổi chưa commit; không dùng HEAD thay cho source hiện tại. Xem [PLAN](HANDY_HABIT_PLAN.md) và phần Habit run 1 trong [UX_REDESIGN](UX_REDESIGN.md).

## Phạm vi và bằng chứng

A = apps/handy_habit/lib; E = packages/handy_habit_engine/lib/src; AT = apps/handy_habit/test; ET = packages/handy_habit_engine/test. COMPLETE chỉ có nghĩa đủ hành vi hiện có ghi trong hàng, không phải hoàn tất MASTER PROMPT hay release. PARTIAL = có một phần; BROKEN chỉ khi tái hiện sai; MISSING = chưa có; BLOCKED BY PLATFORM = capability/toolchain chưa sẵn; NOT VERIFIED = source có nhưng thiếu bằng chứng runtime. Không tìm thấy lỗi core tái hiện được trong các test đã chạy, không tự gán BROKEN vì thiếu coverage.

| Mức | Kết quả mới trong run 1 |
| --- | --- |
| source implemented | Các hàng có source bên dưới; không bao gồm tính năng đề xuất |
| unit tested | PASS 61 test engine: flutter test --no-pub --reporter expanded |
| widget/host tested | PASS 42 test app cùng lệnh; gồm SQLite thật trên host, export, appearance, Advanced form chưa commit |
| screenshot renderer | PASS 36 case tool/screens_test.dart, Nunito thật; có cảnh báo tap ngoài viewport ở films |
| emulator tested | Không chạy; không adb/emulator/BlueStacks |
| device tested | NOT VERIFIED trong run này |
| store tested | NOT VERIFIED: không purchase/restore/consent thật |

Evidence tại thư mục report: C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/codex/. Files: habit_run1_engine_tests.log, habit_run1_app_tests.log, habit_run1_screens.log, habit-run1-shots/. Baseline chỉ đúng working tree lúc chạy, không chứng nhận thay đổi sau đó.

## Kiểm kê source và test

| Chức năng | Trạng thái | Source | Test / khoảng trống |
| --- | --- | --- | --- |
| Habit CRUD; binary/count/duration/quantity; đơn vị/target/note | COMPLETE | A habits/habit_editor.dart; E models.dart | AT ui_test; ET engine_test/timestamp_test; type/unit khóa khi có log hoặc liên kết |
| Search không dấu/group/priority/manual order/duplicate | COMPLETE | A habits/habits_page.dart, habit_view.dart | UI có test màn chính; reorder/group chưa có case chuyên biệt đầy đủ |
| Icon/màu habit và routine, preview/cancel/Undo | COMPLETE | A habits/habit_appearance.dart, today/rows.dart, routines/routine_view.dart | AT appearance_test: giữ lịch/log/links/steps, contrast không ghi đổi màu gốc; phần chưa commit phải giữ |
| Daily/weekdays/N ngày đạt mỗi tuần/interval; start/end | COMPLETE | E models/calendar; A habit_editor | ET recurrence/next-due; weekly là số ngày đạt, không weekly quantity budget |
| Effective schedule/target history | COMPLETE | E models/calendar | ET schedule version/weekly boundary; edit có thể từ hôm nay, không luôn ngày mai |
| IANA zone/DST/local day/week-start | COMPLETE | E calendar/models; A settings | ET DST/offset/week boundary; default Asia/Ho_Chi_Minh; OS clock change thật chưa kiểm |
| Custom day boundary | MISSING | localDay hiện nửa đêm | Cần versioned policy, không dời ngày cũ |
| One-tap bead, count+1, duration/quantity quick-add | COMPLETE | A today/beads/check_in/rows | AT ui_test binary once/count cap/duration; vị trí trên fold còn cần sửa |
| Undo/CAS/save trước publish/cancel/fail | COMPLETE | A controller/scope/ui/form | AT store_test/ui_test/advanced_form_test; Undo snapshot RAM, mất sau restart, chưa sync-safe |
| Backfill/manual total/note/skip | COMPLETE | E calendar; A check_in/month_grid | ET future/backfill/linked protection; AT past-day |
| Current/best streak, quota, eligible denominator | COMPLETE | E calendar/pauses | ET daily/weekly/partial/open/skip; chưa negative threshold |
| Archive/unarchive theo kỳ | COMPLETE | E archiveHabit; A habit/routine views | ET archive giữ quá khứ; archive không phải trash |
| Delete/cleanup/Undo | PARTIAL | A habit_view:284, routine_view:338 | AT delete cleanup; habit hard-delete events và links/reminders, không giữ30 ngày; session snapshots còn |
| Vacation all/chosen/edit/end/delete | COMPLETE | E pauses; A pauses/today/settings | ET pause_test; AT pause_ui_test; prorate ceil, done khi nghỉ vẫn tính; không còn thiếu |
| Negative incidents/thresholds/reduction | MISSING | E type chưa có direction/incident model | Tên preset giảm màn hình không chứng minh negative engine |
| Mood/energy/reflection/tags | MISSING | Không model/view | Habit/step note không phải mood |
| Routine CRUD/schedule/archive/duplicate | COMPLETE | A routines/routine_editor/view | AT ui_test/appearance_test; giữ minimum/priority cũ |
| Step builder/reorder/time/minimum/required/canSkip/habit link | PARTIAL | E models; A routine_editor/view | Có source; thiếu Basic/Advanced và coverage builder đầy đủ |
| Foreground runner/pause/resume/skip/previous-next/extend/note/auto-next | COMPLETE | A runner/runner_view; E routines | AT ui_test/pause_ui_test; không background service |
| Exactly-once linked progress, guarded Undo, abort giữ log | COMPLETE | E routines/models; A controller | ET engine_test; AT SQL rollback store_test; unique session/step |
| Session snapshot/recovery/one active/summary | COMPLETE | E models/routines; A session_view/runner | ET clock anomaly; AT recover/background; chưa live cross-device |
| Conditional/branch/dependency/stack/blocks/variable duration | MISSING | Routine hiện list tuyến tính | minimum/priority không phải rule graph; Lite đã bỏ |
| 32 habit presets /8 nhóm /8 routine templates | COMPLETE | E presets.dart, routines.dart:177; A preset_sheet/routines_page | AT presets_test chạy PASS xác nhận runtime32/8; routine EN/VI cùng8; preset chỉ fill editor |
| Template search/preview/explanations/goal collections | PARTIAL | A preset_sheet là chip nhóm; routines_page Use ghi ngay | Chưa search/full preview; HabitPreset chưa explanation/icon/color riêng |
| Month calendar/history | PARTIAL | A month_grid/habit_view:229 | Calendar test; history take(30), còn lại trỏ export, không Show all |
| Insights range/filters/streak/weekly bars/routine planned-actual | COMPLETE | A insights; E calendar | ET metrics; AT responsive/export; chart cap52 periods, không yearly heatmap |
| Weekly review/comparison/missed-day pattern/Làm nhỏ lại | COMPLETE | E review; A week_review/today | ET engine_test review; suy từ log, không thêm nhật ký |
| Year heatmap/advanced comparisons/correlation/suggestions | MISSING | Chưa yearly/mood model | Month grid không phải year heatmap |
| Local reminders Android/iOS/quiet/weekdays/snooze | PARTIAL | A reminders/run_notice/settings; E dueReminders | ET DST/quiet/cap; AT fake notice; 200 rules, earliest50/400days; next text không phải notification preview/test thật |
| Background reminder Windows/Web | BLOCKED BY PLATFORM | Habit adapter chọn in-app due list | Package có Windows adapter không có nghĩa Habit đã wire; Web không native alarm |
| Paused-run notice/tap/reboot | NOT VERIFIED | A run_notice/app; Android boot receiver | Fake-port tests pass; source integration chưa chạy lại; OS delivery/lockscreen/tap chưa kiểm |
| SQLite WAL/FULL/FK/CAS/transaction/integrity | COMPLETE | A data/store_native/controller | AT store_test thật: stale/rollback/corrupt/future/v1/100 habits/100 routines/10k events/1k sessions |
| IndexedDB atomic/stale-tab/quota/offline | NOT VERIFIED | A data/store_web | Host app test không chạy browser; source rewrite mọi store mỗi commit |
| Full JSON/ZIP/preview copy-merge/replace/checksum/limit | COMPLETE | E portable; A settings/data | ET roundtrip/path/checksum/size/future; AT export; chưa durable pre-restore recovery tự động |
| Auto folder backup/sealed restore | PARTIAL | A app:62, settings:461, settings/data:169; kit backup.dart | ĐÃ HandyAutoBackupSection/openSealedBackup; thiếu Habit-level password/tamper/lifecycle/retention tests; SAF/iOS provider chưa verified |
| CSV logs import/export; MD/PDF EN/VI | COMPLETE | E portable; A settings/data/insights | ET IDs/provenance/conflicts/pauses; AT bytes/cancel; CSV cần habit IDs sẵn, PDF >10k events chặn |
| Optional sync/provider/conflict merge/status | MISSING | Không Habit sync source | merge() đổi IDs là copy-import, không dùng làm sync; không LWW check-ins |
| First launch/Skip | PARTIAL | A shell/habit_shell:185 | AT first-open; một màn3 choices, ví dụ ghi data thật; thiếu story/practice/progress/Back/replay |
| Searchable how-to/drawn mocks/context/replay | MISSING | Không Habit help/welcome route | Cần đọc sibling và làm search theo brief |
| Settings theme/locale/calendar/reminders/pauses/data/delete | PARTIAL | A settings; kit settings | Có groups/guard, thiếu routine defaults/diagnostics/help/reset-only-prefs/privacy-version đầy đủ; Pro generic quá cao |
| More apps | COMPLETE | kit settings chèn HandyMoreApps | Đã có qua shared composition, tự ẩn khi thiếu listingUrl |
| Pro Lifetime/restore/ads consent | PARTIAL | A app→kit HandyApp/HandyProSection; monetization/store deps | Official adapters có; chưa Habit benefit demos/feature entitlements; chưa bán/transaction verified |
| Wide navigation/Show all/URLs | PARTIAL | A shell/app | Mobile4 destinations, desktop segmented TOP BAR không rail; split≥1000; top areas cùng /, detail routes có |
| EN/VI/Nunito/light-dark/a11y/keyboard | PARTIAL | A words/design identity/beads/shell/runner | AT a11y/responsive320/768/1024/1440; real SR/text-scale/browser keyboard chưa verified |
| Motion/reduced motion | PARTIAL | Kit transitions có; Habit chưa direct HandySwap/Reveal/Appear | Cần data-change feedback/zero duration verification |
| Android Today widget/3 quick rows | NOT VERIFIED | A home_widget/app; Android HandyWidget.kt | AT device_test chỉ pure view/deep-link data; chưa launcher/pin/refresh thật, single-habit/routine launcher thiếu |
| iOS widget/health/OS shortcuts | BLOCKED BY PLATFORM | Chưa native implementation | Cần code trước, rồi toolchain/entitlement/device; Android Health Connect cũng MISSING |
| Scale/performance | PARTIAL | E HabitIndex; A stores/controller/IndexedStack | 10k test không benchmark latency; native scan payloads, Web clear/rewrite, full-state validate/notify mỗi check-in |

## Schema, dependencies, migration và rủi ro

- Data schema2: E pauses.dart/habitSchema. SQLite user_version1, IndexedDB version1 là version vật lý riêng. State gồm habits/events/routines/sessions/pauses/settings; pauses ở state payload.
- Migration hiện tại: v1 không pauses→[]→save v2; v1 có pauses hoặc future bị reject, không reset. ET pause_test và AT store_test kiểm JSON/ZIP/SQLite cũ. Units integer milli≤1e12; duration phút; ngày local giữ nguyên, timestamp chuẩn offset UTC.
- Dependencies: pure engine archive/crypto/handy_core portable ZIP+CSV/timezone; app dùng sqlite3 3.5.2/path_provider/web, handy_files/ui/notifications/home_widget/monetization/ads, pdf. Không backend. Schema bump phải nâng codec/store/backup/CSV/provenance/runner đồng bộ và roundtrip trước UI.
- ZIP app ID handy-habit; manifest SHA-256 + data.json, assets rỗng,30MB. SQLite/JSON/ZIP plain không mã hóa; hseal là lớp sealed dùng core, không crypto mới. Folder settings/device permissions cần tách domain export.
- Copy merge remap mọi entity/step/pause ID, recalculates eventHash, chặn digest lặp và hai active sessions; hai backup khác nhau vẫn có thể nhân đôi nội dung. Không phải dedupe/sync.
- P0: hard-delete chỉ Undo RAM; replace chưa recovery bền; global revision chỉ local CAS; snapshot LWW hoặc snapshot Undo sẽ mất check-ins khi sync. Cần causal ledger/conflict policy trước provider.
- P1: negative weekly budget khác weekly quota, day-boundary mới không dời lịch sử; operation ledger tăng backup size phải đo, giữ guard30MB trước khi quyết thay đổi.

## Sibling source đã đối chiếu

| Source tham chiếu | Cơ chế thực đọc | Habit cần làm |
| --- | --- | --- |
| Boards welcome/page/story_scene/practice_board/motion; Bookmark welcome/rehearsal/story_scene | Hai story beats; widget demo state riêng/Spotlight/Do it for me; Back/Esc/Enter; final dạy thêm time | IMPROVE guide riêng; không question đầu/chooser cuối, không real data |
| Cả hai settings/how_to_page và how_to_mocks | Topic/numbered steps/code-drawn crop/replay; không thấy TextField search trong trang hiện tại | ADD searchable EN/VI theo brief, không copy thiếu sót sibling |
| Boards settings/settings_page/settings_parts; Bookmark settings/save_settings | Group/value/Pro badge non-Pro cạnh title/MoreApps | IMPROVE Habit groups, KEEP backup kit và MoreApps đã có |
| Boards và Bookmark lib/sync; Boards engine src/sync và test/sync_test | Android build flag/appdata/base fingerprints/remote CAS/disable giữ local | ADD engine merge riêng; Boards record conflict LWW và loại events/executions khỏi sync KHÔNG áp cho Habit check-ins |
| Boards pro/pro_page/pro_demos; Bookmark pro/explore_pro/pro_demos | Demo/reduced-motion still/benefits/shared purchase restore | ADD Habit demos/entitlements; ownership Free |
| Sibling help/trash; kit motion/sidebar | Trash30 ngày và days-left; HandySidePanel/SideRail, cap lists | ADD durable trash, IMPROVE fold/Show all/motion |

## Reconcile claim tài liệu

Không sửa registry/matrix nguồn trong run chỉ audit; bảng là đính chính, cập nhật cùng slice hành vi sau.

| Claim | Kết luận |
| --- | --- |
| FUNCTIONS32/8/schema2/pauses/sealed/JSON-ZIP-CSV | Đúng source, counts runtime PASS; provider/device vẫn chưa verified |
| FUNCTIONS và matrix riêng nói desktop rail/named areas | Desktop segmented top bar; bốn khu chung /, detail có routes; phải sửa claim |
| FUNCTIONS reminders preview | Chỉ next-reminders text, chưa full notification preview/test UI |
| docs/handy_habit/DATA_SCHEMA history100/page | Source chỉ30 + export, không pagination |
| Matrix riêng Lite builder/variants/tests còn vài hàng | Stale; FUNCTIONS/root matrix đã ghi bỏ Lite03/11; không dùng evidence Lite cho hiện tại |
| KNOWN_ISSUES P1 vacation/widget/challenge chưa triển khai | Vacation đã làm; Android widget source có/chưa launcher verified; challenge chưa làm, ngoài scope chính |
| KNOWN_ISSUES SQLite/backup không mã hóa | Đúng plain; cần ngoại lệ hseal, không phủ nhận encryption đã có |
| Root matrix weekly review host và historical logs | Giữ mức evidence; log/build/emulator cũ không chứng nhận working tree hiện tại |
| UX Habit cũ onboarding3 choices/no appearance/Lite/top switch | Appearance đã có; Lite bỏ; phần contract run1 thay thiết kế cũ, chưa phải code mới |
| FUNCTIONS/KNOWN_ISSUES official store adapter/chưa bán | Chỉ wiring, không store verified; không đọc secret config để đoán product ID |

## Critique ảnh baseline — app-screens §2.7

Đã xem trực tiếp7PNG: phone Today, desktop Today, first-open, editor, runner, Insights, Settings. Fixture practice() của tool/screens_test là6 habits/2 routines ngày02/11, không dữ liệu người dùng/telemetry.

1. Giữ Nunito/lời chào/bead và neutral missed; desktop edges nhất quán. Phone Today đẩy hàng habit đầu xuống khoảng2/3 màn bởi review+routines: ưu tiên bead và active run một dòng.
2. Onboarding chỉ text+3 nút, thiếu practice. Settings Pro generic lớn đẩy Calendar/Data/Help sâu. Hai lỗi thứ bậc cần sửa trước trang trí.
3. Editor Advanced thu gọn đã đúng, giữ legacy selection/draft. Teal icons lặp ở Today là legacy: icon trung tính/dot ổn định, không ghi lại màu raw.
4. Runner cần nhãn elapsed/remaining để0:00 không bị đọc như hết giờ; khoảng trống focus không tự là lỗi. Insights phải nêu finding và phân biệt có ghi/đạt.
5. Renderer36 case PASS nhưng films tap bead-meditate tại y1010.5 ngoài390×844; GIF đó không chứng minh check-in animation. Slice Today phải ensureVisible và assert state, không tắt warning để giả pass.
6. Chưa soát toàn EN/dark/320/error/permission bằng ảnh hoặc browser/SR thật. draw.mjs thử chạy bị EPERM lstat user-root; Node PATH20.19.2<skill22. Giữ editorial-greeting/Nunito/seed lịch sử973037815, không bịa seed hoặc inspector PASS.

Không sửa shared packages/lib/test/other apps, không secrets/devices/git writes. Các quyết định KEEP/IMPROVE/ADD/HIDE và slices trong PLAN.
