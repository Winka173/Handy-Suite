# Handy Habit — kiến trúc sản phẩm và kế hoạch

10/11/2026 · DESIGN, chưa triển khai. Baseline/evidence: [AUDIT](HANDY_HABIT_AUDIT.md). Screen contracts: phần Habit run1 trong [UX_REDESIGN](UX_REDESIGN.md). Files mới dưới đây là đề xuất, không claim source đã có.

## 1. Quyết định

- KEEP unlimited habits,4 types/mọi lịch chuẩn/history/pauses/backfill/Undo/appearance hiện có/linked steps/foreground runner/weekly review/mọi export/offline/EN-VI.
- IMPROVE Today bead lên trước fold, editor ngắn, Basic builder, history Show all tại chỗ, Settings groups/preview, reminder status, backup recovery bền, Pro demo.
- ADD negative incidents, optional mood, year heatmap, trash30 ngày, story/practice onboarding, searchable help, conflict-safe sync, Advanced routines và insights dùng hằng tuần.
- HIDE FROM PRIMARY UI rules/exports/bulk/archive/trash/tùy chọn hiếm; vẫn có trong context/settings. Library trong create, chưa tab thứ tư.
- SIMPLIFY không KPI dashboard/project manager/mood task. Suy nhóm sáng/chiều/tối từ giờ nhắc/routine và cho sửa; duration/weekly review từ log, không bắt thêm nhật ký.
- REMOVE ONLY IF PROVEN REDUNDANT: không xóa capability; Lite đã bỏ, variant cũ vẫn routine thường, không hồi sinh để bán Pro. Không telemetry để khẳng định ít dùng.

## 2. Competitor matrix

Tra nguồn chính thức10/11/2026; chưa cài/chạy đối thủ. Không copy code/art/layout/branding, kể cả code GPL của Loop. Free/Pro và ưu tiên là quyết định của Habit; tests là của Habit, không test đối thủ.

| Đối thủ → ý hữu ích (nguồn) | Habit hiện có | Gap | Quyết định | Free/Pro | Evidence/tests |
| --- | --- | --- | --- | --- | --- |
| [Streaks support](https://streaks.app/support/) → quick check-in/timer/history/widget | Bead/4 types/runner | Phone check-in xuống sâu | IMPROVE thứ tự/hit area/Undo | Free | AT ui_test pass; thêm fold/scroll/keyboard |
| [Streaks negative tasks](https://streaks.app/help/how-do-negative-tasks-work/) → day/week limit | Chưa negative | Incident/budget/zero-vs-unknown thiếu | ADD ledger, không mặc định không ghi=thành công | Free | Thêm zero/unknown/budget/recovery/conflict |
| [Streaks health tasks](https://streaks.app/help/creating-health-tasks/) → ít ghi tay | Routine-linked exactly-once | Chưa native health | Gate sau core, chỉ UI khi native path thật | Health optional Pro/manual Free | Permission/revoke/dedupe/device chưa có |
| [Loop official repo](https://github.com/iSoron/uhabits) → schedules/graphs/score/offline/export | Streak/eligible rate/month/CSV | Chưa year/comparisons | KEEP denominator rõ, ADD heatmap, không copy score | Core Free/comparison Pro | ET DST/quota pass; thêm leap/missing |
| [HabitNow publisher listing](https://play.google.com/store/apps/details?id=com.habitnow&hl=en) → schedules/categories/timers/reminders | Multi-step routine/time/group | Basic/diagnostics chưa đủ | IMPROVE builder/runner, không todo/calendar system | Basic Free/rules Pro | ET links/recovery pass; thêm builder/a11y/permission |
| [Habitify](https://habitify.me/) → buổi/timer/mood | Giờ nhắc/routine/note/review | Chưa mood/energy | ADD optional2 chạm, không suy cảm xúc | Basic Free/correlation Pro | Thêm roundtrip/edit/skip/no-entry |
| [Habitify official help](https://intercom.help/habitify-app/en/articles/6113487-explore-habitify-plans-free-plus-and-pro) → Off Mode/checklist/automation | Vacation/linked/auto-next | Chưa dependency/stack/blocks | KEEP pause Free, ADD local finite rules, không API server/AI | Advanced Pro | ET pause pass; thêm DAG/path/snapshot |
| [TickTick gallery](https://help.ticktick.com/articles/7055781878401335296) → discovery/create nhanh | Runtime32 habit/8 routine | Search/explanation/full preview thiếu; routine Use ghi ngay | IMPROVE32/8 trước, preview→customize→save, goal chips optional sau guide | Core Free/advanced presets Pro | AT presets pass; thêm search/EN-VI/no-write-before-save |

Ưu tiên lợi ích hằng tuần: data safety → daily flow → giáo dục/help → negative → heatmap/review → mood optional → sync → Advanced/Pro. Nhóm buổi chỉ khi hữu ích; không tự bật reminder từ mẫu.

## 3. Kiến trúc và model

Pure-Dart engine/domain, app sở hữu persistence, native qua adapters; giữ StatefulWidget/controller, không thêm framework routing/state. Kit hành vi/motion/a11y, Habit sở hữu presentation. Không backend/account bắt buộc/paid API/shared business state. Tách khi cần thành operations.dart/migration.dart/trash.dart/negative.dart/mood.dart/routine_rules.dart/sync.dart; giữ adapter API cũ tới khi call sites/tests chuyển xong, không rewrite hàng loạt.

Bất biến: validate toàn bộ→CAS transaction→publish; cancel/error giữ state/file nguồn; local dates không dời khi timezone/day-boundary đổi; schedule/goal effectiveFrom giữ history; daily→weekly mở segment, weekly đổi ranh tuần; type/unit không reinterpret số cũ; retry cùng op ID; linked event/op/cursor cùng transaction; chart có đơn vị/mẫu số/range; zero≠missing, skip/pause/unknown không success giả.

### Version và migration

Baseline data schema2, SQLite/IDB physical1. Run 2 ships data3/physical2, including R4 trash in v3 as required by the combined brief. Read chain shipped: 1→2→3; planned next versions: 4→5→6; writer theo slice, không parser chỉ nhận1/latest bỏ schema giữa. Backup manifest/data phải tương thích sau normalize.

| Schema | Thêm | Migration/roundtrip |
| --- | --- | --- |
| 3/R3+R4 (IMPLEMENTED, host tested) | Causal operations/revisions, versioned clock policy, trash/tombstones | Mỗi v2 event→legacy op ID tất định từ eventId/payload hash, actor legacy ổn định; entityId giữ logical eventId để phát hiện cùng event khác payload; số/ngày/provenance giữ, cùng ancestry không double count |
| 4/R10 (planned) | Negative GoalRevision/IncidentOp/Observation | Habits cũ positive, unit/target history giữ, zero/unknown riêng, CSV cũ đọc được |
| 5/R14 (planned) | MoodEntry/revision/delete | Mood rỗng, không suy từ notes; time/tags/note roundtrip |
| 6/R17 (planned) | Advanced graph/plan snapshots/trace | List cũ→linear path tương đương; active/closed sessions giữ snapshot |

R3 tạo operations table/index và IDB store→physical2. Slice sau ưu tiên payload; cần thêm table/index thì bump physical tiếp. Không đổi DB name/format app ID. Migration transaction + durable recovery trước migrate, future/corrupt/quota giữ bản gốc, IDB onblocked/versionchange xử lý tab cũ.

Mỗi bump có fixtures JSON/ZIP mọi version đã phát hành→latest→export/restore equality→restart SQLite/Web; CSV compatibility; future/corrupt/truncation/path/hash/size/partial write refusal; provenance/remap/pause/reminder/dedupe/session recovery. Cập nhật DATA_SCHEMA/matrix/KNOWN_ISSUES/FUNCTIONS cùng slice, không sửa tool registry vì Habit không đổi tool IDs. Không sửa QA log thành pass.

### Causal operations và sync revisions (v3)

Operation{id,actorId,actorSeq,lamport,parents,entityKind,entityId,intent,payload,formatVersion} immutable; actor riêng từng máy, counter không dựa wall clock. Config có revision heads/conflict candidates; HabitState.revision vẫn CAS local. Sync protocol format/version/minReader/generation/hash/size riêng, base local không export.

- Add delta union op IDs, retry idempotent; binary success cap1/ngày nhưng giữ cả provenance/linked steps. Nâng projection/validation cùng nhau để raw sum>1000 không làm restore fail.
- setManualTotal thay manual contributions đã quan sát, giữ linked và additions mới máy khác. Hai absolute edits/skip-vs-add concurrent không cộng hai tổng hoặc LWW: giữ candidates, Cần xem lại, không chấm đạt/lỡ tới resolve.
- Retract/Undo tham chiếu đúng observed op; không xóa phần máy khác/resurrect sau offline. Thay snapshot Undo toàn state bằng domain inverse trước bật sync.
- Cùng ID khác payload, duplicate actor sequence, refs/amount/schema/hash sai→reject/quarantine batch, giữ local. Resolution op có parents mọi candidates; clock skew không quyết định thắng.
- Payload bounded, không full snapshot mỗi op; compact chỉ sau checkpoint/ack mọi replica biết đến và recovery snapshot. Tombstone không expire theo30 ngày UI, máy offline lâu join có deletion knowledge.
- ClockPolicy{zone,dayBoundaryMinutes,effectiveFrom} versioned, chỉ áp recording tương lai; ngày cũ không tính lại từ timestamp. Duration dùng milli phút như baseline.

### Trash (v3, bundled with R3)

TrashEntry{id,kind,entityId,deletedAtUtc,expiresAtUtc,deletionRevision,payloadRef,referenceSnapshot}. Giữ30 ngày, days-left=ceil(remaining/24h) clamp0..30. Habit ẩn Today/reminders ngay, history còn khi trong trash, future eligibility chốt ngày xóa. Routine giữ session snapshots. Restore nguyên ID/links còn hợp lệ; đã purge habit thì nói không còn, không tạo habit mới. Active session dùng entity phải pause/đóng/xác nhận xử lý trước xóa. Purge payload/history sau30 ngày theo lời báo trước, idempotent, giữ tombstone nhẹ cho sync. Archive cất lâu dài, không expire.

### Negative (planned v4)

Habit.direction=build|reduce, không reversed binary. GoalRevision{id,effectiveFrom,measure=count|quantity|duration,unit,window=day|week,maxIncidentsMilli,weekStart,baselineMilli?}; positive weekly quota giữ riêng. IncidentOp có habit/day/amount/source/note/instant/revision, edit/retract qua ledger. Observation{habitId,localDay,confirmedThrough}: observed+no incidents=zero, thiếu ghi=unknown. Optional xác nhận0 cho cả nhóm, không bắt nhiều việc mỗi ngày.

Today1/2 lần trong giới hạn, primary Ghi lần, zero action riêng. Kỳ mở provisional, không cộng streak trước đóng; closed observed≤threshold đạt, vượt phản hồi trung tính/không đỏ. Weekly là tổng incidents, không số ngày tốt. Nghỉ không thành zero; kỳ thiếu observation/đang nghỉ không đủ tuyên bố đạt, hiển thị known+unknown. Không auto-prorate threshold âm làm mục tiêu chặt hơn, sửa từ kỳ sau. Không routine completion→incident; reduction% chỉ baseline người dùng xác nhận và cùng đơn vị/kỳ, không y tế.

### Mood (planned v5)

MoodEntry{id,day,recordedAtUtc,mood1..5?,energy1..5?,note≤4096,tags≤8,revision,deletedAt?}; ít nhất mood hoặc energy, một entry hiệu lực/ngày, edit có revision; concurrent không ngầm average. Skip không tạo entry, không suy mood từ habit. Correlation local cần≥14 paired observed days, nêu N/missing, chỉ liên hệ không nguyên nhân/chẩn đoán. Thiếu mẫu nói thiếu, không upsell che data.

Basic routine library chính là các plan tái sử dụng. Save as template tạo bản Routine độc lập bằng model hiện có, không chỉnh plan gốc hoặc session snapshot; bản này đi trong full backup. Nếu cần metadata mới ngoài model phải có schema bump/roundtrip trước, không giấu fields mới trong UI.

### Advanced routines (planned v6)

RoutinePlanRevision{id,from,graphVersion,nodes,edges,blocksSnapshot,presets}; node ID stable. Rules hữu hạn: condition theo dữ liệu ngày/session đã có, prior-node dependency, choice branch, stack-after; không expression/code tùy ý. DAG≤200 expanded steps, không cycle/recursive blocks, mọi path có exit/required reachable. Block snapshot/version lúc thêm, sửa không rewrite session. Seconds theo weekday, foreground timer policy/auto-transition opt-in, không background alarm giả.

Session chụp resolved plan+decision inputs/trace+steps; nhánh đã đi không đổi vì sync mới. Undo branch phải undo dependent steps trước nếu cần; linked exactly-once vẫn đúng; restore/sync không rerun automation.

### Backup/sync theo nền tảng

| Platform | Backup Free | Sync | Gate |
| --- | --- | --- | --- |
| Android | Picker/share/auto SAF+sealed | Appdata chỉ Android và HANDY_DRIVE_SYNC=true, off default | OAuth/signing/2 devices/offline/revoke/corrupt |
| iOS | Files manual/auto app Files folder, không folder tùy ý | Chưa iCloud tới source+entitlement+test | Mac/Xcode/device; không Android↔iOS auto claim |
| Windows | Manual/auto folder/retention/sealed | Optional conflict-aware folder cùng engine; OS cloud folder là transport | 2 clients/atomic temp→rename/CAS, không file-copy LWW |
| Web | JSON/ZIP/hseal upload-download, không auto folder | Không auto cloud promise | IDB quota/eviction/offline/tab, backup ngoài browser |

Local commit trước, sync debounce/open/resume/manual không chặn check-in. Engine three-way/union validate→transaction; local đổi trong lúc tải thì rebase current qua CAS, remote generation fail retry hữu hạn. Base advance sau local commit bền; upload fail giữ pending. Decode bounded/hash/schema, remote corrupt/partial giữ local. Enable/cancel/deny không sửa domain; disable/disconnect bỏ queue/session token/base cũ, không xóa local/remote data.

Sync config/schedules/pauses/mood/trash/closed sessions/check-in ledger. Active timer/session local, không merge hai cursor; closed union ID/provenance. Chuyển phiên dở qua restore preview+pause, không takeover tự động. Theme/locale/default week/permission/OS schedules/folder credentials/store entitlement/guide/base không sync; schedule.weekStart là domain nên sync. Backup giữ full domain kể active/trash/mood, device preferences tùy chọn preview; không secrets/token/base. Restore permissions off, không auto sync hoặc cấp purchase.

Tests sync: no-op/idempotence/convergence/order independence; concurrent binary/count/absolute/Undo/skip; schedule/week boundaries; delete-edit/restore/purge; IDs/clock skew;2active local sessions; interrupted uploads/downloads/stale remote/corrupt/future/migration; local edits in flight; disable/rejoin. Không copy Boards localOnlyKinds events/executions hay record LWW cho check-ins.

## 4. Ranh Free / Pro Lifetime

Mục tiêu, chưa billing verified. Không khóa hồi tố tính năng hiện Free. Unlimited vẫn tuân giới hạn an toàn công bố.

| Năng lực | Free | Pro Lifetime |
| --- | --- | --- |
| Habits/history | Unlimited positive/negative/4 types/mọi lịch chuẩn; check-in/Undo/backfill/full history/streak/eligible/archive/trash | Không bán habit slots hoặc quyền dữ liệu |
| Routines | Create/reorder/link/time/runner/pause/skip/recovery/basic templates; minimum/priority/required cũ | Tạo/sửa condition/branch/dependency/stack/blocks/variable durations/advanced presets/session insights |
| Progress | Weekly review/month-year heatmap/chart/filter/CSV-MD-PDF hiện có | Multi-period/group comparison/advanced filters/heatmaps/explainable suggestions/correlation/designed reports |
| Mood | Entry/energy/note/tag/edit/delete/calendar/history | Advanced correlations/trends |
| Templates |32/8 và core starter collections | Advanced premium presets, preview Free |
| Reminders/widgets | Supported local reminders, basic Today/single-habit/routine launcher | Advanced widget looks/dashboard presets |
| Appearance | System/light/dark/Nunito/locale/reduced motion/a11y/density cơ bản/icon-màu hiện có | Premium themes/icon packs/layouts/routine visuals/dashboard studio |
| Convenience | Routine-linked exactly-once hiện có | Local automation/saved filters/batch/optional verified health |
| Ownership | JSON/ZIP/CSV/import/export mọi format hiện có; manual/auto/encrypted backup/restore/sync/integrity/trash | Luôn Free, không Pro badge |
| Education/ads | Guide/replay/searchable help/troubleshooting; offline usable; ads chỉ chỗ duyệt sau guide | Bỏ ads và benefits trên, một lần, không subscription |

Entitlement qua store thật, không switch fake production. Preview không write. Mất Pro giữ data/config, fallback looks, đọc/export/chạy routine đã lưu an toàn; chặn tạo/sửa Advanced mới và tắt automation. Restore không cấp quyền mua. Android/iOS/Windows theo store; Web không checkout giả hoặc claim purchase xuyên store. Chưa bán nói chưa bán, không giá placeholder. Ads không runner/form/backup/help.

## 5. Information architecture

| Đích | Job | Route |
| --- | --- | --- |
| Today/Hôm nay | Bead, active-run1 dòng, due habits, routine Start, mood optional/review compact | /today, root /→Today |
| Routines/Quy trình | Start/resume/library/builder/sessions | /routines, /routine/:id, /routine/new, /routine/:id/edit, /run/:id, /session/:id |
| Progress/Tiến bộ | Week/month/year/habit/session stats | /progress, /progress/week?from=...; query range/filter |
| Quản lý habits từ Today | All/search/group/archive/editor/history | /habits, /habit/:id, /habit/new, /habit/:id/edit |
| Templates, chưa Library tab | Search/category/preview/customize | /templates?kind=habit, /templates/:id |
| Settings gear cố định | Groups/data/backup/sync/trash | /settings, /settings/:section |
| Help/guide/Pro | Replay/search/topic/demo | /welcome, /help?q=..., /help/:topic, /pro?feature=... |

320–599 bottom nav3 khu Today/Routines/Progress, gear trên, Add contextual. Ba khu trả lời ba việc hằng ngày; habit management vẫn1 chạm Tất cả, không xóa capability tab cũ.600–839 một pane nếu thiếu chỗ.≥840 sidebar224 hoặc rail64 bằng HandySidePanel/SideRail, Settings/Help ở chân;≥1100 split nếu mỗi pane≥340. Max canvas1168/gutter16phone24wide;1440=224+48+1168, Today=744+24+400. Rail fold thì center theo vùng còn lại, không blank band kéo dài.

Giữ legacy habit/routine/run/session/settings routes. Named routes qua hash strategy là #/today, không claim server path refresh trước browser QA. Missing ID/route có message+parent. URL/filter/selection hỗ trợ back/forward/scroll. Android Back/iOS swipe/Esc một cấp, dirty edit discard guard, runner pause-save trước leave; abort riêng. Ctrl/Cmd N thêm/F tìm/comma Settings, Ctrl1–3 khu; runner Space pause/Enter done ngoài input. Không chiếm shortcut browser khi đang gõ.

## 6. Slices runs 2..N

Mỗi run một feature area, supervisor review rồi chuyển. A/E/AT/ET theo AUDIT; files mới là đề xuất. Mọi slice đọc lại sibling source liên quan, contract trước code, EN/VI/light-dark/320–1440, cập nhật docs coupled và evidence levels. Bump schema phải backup/restore/migration roundtrip trước UI ghi mới. Shared change chỉ nếu unavoidable, compatible, report riêng. Device là việc supervisor phải làm, không claim host đã kiểm.

| Run | Files/phạm vi | Tests thêm + acceptance | Supervisor device check |
| --- | --- | --- | --- |
| R2 P0 data safety — IMPLEMENTED / HOST TESTED | A settings/data, backup/recovery helpers, kit integration | AT backup_restore: hseal wrong password/tamper/cancel, metadata/schema/size preview, stale CAS/rollback, durable pre-replace recovery; giữ v1/v2 | SAF local/cloud provider, iOS Files, Windows retention/sealed, Web upload/download |
| R3 P0 causal storage — IMPLEMENTED / HOST TESTED | E operations/migration/models/portable/calendar/routines; A stores/controller; schema3/physical2 | ET legacy migration/union/retract/absolute-conflict; AT transaction/CAS/restart; số/ngày/provenance giữ, domain Undo | Upgrade years data/kill migration/commit/low storage; browser blocked tab/quota |
| R4 P0 trash — IMPLEMENTED / HOST TESTED | E trash/models/portable; A delete menus/settings trash; bundled schema3 | ET restore/purge/day/refs/backup; AT restart→restore/Ndays/active guard/archive riêng | Ngày29/30/restore links/permanent delete/backup |
| R5 P1 shell/Today | A shell/app/today/habits list/kit motion | AT routes/URL/one-tap/Undo/reduced motion/scale; bead top60%; cap→Show all; films ensureVisible+state assert | Rapid tap/back/rotation/SR, fold/keyboard, browser refresh/back |
| R6 P1 habit editor/history | A editor/appearance/view/month_grid/form; E clock policy | AT cancel/fail/legacy Advanced/effective targets/history Show all; ET custom day-boundary/DST giữ ngày cũ |320keyboard/VI dài/swipe dirty/midnight/appearance giữ log |
| R7 P1 Basic routines | A draft builder/list/detail/runner UI | AT draft add/reorder/link/cancel/fail/required/skip/time/summary; ET exactly-once regressions; save toàn draft | Drag+nút up/down/linked count/background/kill/reopen/exit |
| R8 P1 onboarding | A welcome/page/story/practice + routes | AT2beats/no-question/Back-Skip-Esc-Enter/practice check-in-Undo-goal-run-done/Do it for me/final1Start/replay no writes/upgrade no force | First launch/update/replay/OS back/large text/dark/VI/no permissions |
| R9 P1 help/Settings | A how_to_page/how_to_mocks/groups/parts/routes | AT search không dấu/EN-VI/no-match/context/replay, badge non-Pro, persist/error/reset-only-prefs; topics theo enabled features | Làm theo ảnh/SR/reset giữ data-purchase/support/privacy |
| R10 P1 negative engine | E negative/goal/ops/calendar/portable/migration; schema4 | ET incident/zero/unknown/day-week/open-close/skip/pause/retract/DST/history/conflict; full formats/old positives | Upgrade/reopen/restore mixed/check day-week boundaries |
| R11 P1 negative UX | A editor/today/check_in/history/help | AT incident/Undo/zero optional/unknown≠success/budget/backfill/neutral/no routine incident |2/day,3/week/EN-VI/SR/zero-vs-unknown |
| R12 P1 templates | E presets/catalog/routines; A templates/create/help | ET IDs/content/EN-VI/defaults; AT search/category/preview/customize/cancel/save once; giữ32/8, report counts mới | Offline/back/no duplicate/previews khớp UI |
| R13 P1 core Progress | E review/heatmap; A insights/progress/week | ET denominator/leap/DST/quota/unknown/conflict; AT range/filter/Show all/export/zero; month-year Free | Years data/text scale/SR table/cell backfill |
| R14 P2 mood | E mood/model/portable/migration; A optional sheet/calendar; schema5 | ET validation/revision/delete/roundtrip; AT2tap/skip/no forced note/privacy, core không phụ thuộc | Offline/edit/delete/restart/restore/export privacy |
| R15 P0 sync engine | E sync/protocol/merge/reducer; A base abstraction | ET full conflict suite ở §3/convergence/closed union/active local/corrupt/local edits in flight |2 states/2 processes/conflict values/manual+linked không mất |
| R16 P1 Android Drive | A sync/provider/controller/section/lifecycle/pubspec | AT fake auth/offline/quota/CAS/retry/disable/rejoin/flag-off/no delete/token export; appdata only | Owner OAuth/signing/2Android/deny-revoke/offline/interruption/Sync now |
| R17 P2 Advanced engine | E routine_rules/plans/portable/migration; schema6 | ET DAG/cycle/refs/path cap/inputs snapshot/Undo/linked/weekday/all-schema roundtrip | Active basic upgrade/branch restart/restore no automation |
| R18 P2 Advanced UX | A builder/blocks/presets/trace/runner/gates | AT Basic-Advanced/readable preview/draft/validation/fail/existing run-safe/summary | Branch/dependency/skip/Undo/recovery/motion, no terminated timer |
| R19 P2 insights | E correlation/comparison/suggestions; A advanced progress/report | ET≥14 pairs/missing/no-cause/segments; AT explain-why/free core/report preview | Check against independent export/data ít-nhiều/no medical |
| R20 P2 studio | A design/theme/dashboard/widget preview | AT AA light-dark/preview cancel-apply/entitlement loss/Nunito VI/widths/no data rewrite | OS theme/text scale/contrast/stable dots/appearance giữ lịch |
| R21 P1 paywall | A pro/entitlements/page/demos/settings + shared purchase | AT matrix/demo/motion/pending/cancel/offline/error/restore/price absent/refund; fake chỉ host | Real sandbox buy/restore/refund Android-iOS-Windows/local price/Web honest |
| R22 P1 reminders/widgets | A reminders/run_notice/home_widget/settings + Android native | AT status/test/permission/quiet/redaction/pin≠installed; ET cap/provenance/native compile | Deny/grant/revoke/reboot/battery/launcher refresh/pin/single-habit/routine; iOS notice |
| R23 P2 Windows sync | A folder_provider/panel dùng engine chung | ET/AT temp→rename/CAS/2process/cancel/errors; Free/off default |2Windows/cloud-folder locks/interruption/disconnect giữ local |
| R24 P2 convenience | E local rules; A saved filters/batch preview | ET replay IDs/cycle/cap/atomic batch; AT preview/Undo/gates/local foreground | Batch totals/Undo/error/kill-reopen no double rule |
| R25 platform gate | Capability docs và native shortcuts/health/iOS widget riêng từng run |1integration/run, channel tests/build; thiếu source/toolchain/entitlement báo BLOCKED, không fake UI | Signed permission/revoke/source dedupe/privacy, owner Mac/entitlements |
| R26 P0 scale/reliability | A queries/controller/cache/lazy views; E benchmarks |1/10/100/500 habits,≥100k logs/years/100 routines; measure p95/heap/commit counts, deltas/index cache, transaction regressions | Low-end release rapid taps/rotation/low storage/kill; browser quota/eviction/tabs |
| R27 release | Habit docs/store assets/platform config/evidence | Scoped engine/app/integration/build/independent export decode/EN-VI-dark-light320/768/1024/1440/source-artifact hashes | Supervisor device-store-provider matrix/Mac iOS sign/build/privacy/screenshots đúng binary |

R25 tùy capability; chưa làm được R27 ghi unavailable, không hứa store. Run lớn tách tiếp, không hạ acceptance. R26: reference device ghi model/OS; release p95 feedback<100ms, durable commit<250ms tại100 habits/10klogs, cold start<2s. Profile khi lệch, không xóa test/tăng bar. Đo ledger+backup size: giữ guard30MB, không cho silent data omission; nếu không đủ phải thiết kế checkpoint/compaction an toàn trước thay giới hạn có docs/tests.

## 7. Owner decisions và inputs

Một quyết định sản phẩm mở: giá cơ sở/thị trường giá Pro Lifetime, owner chọn khi có demo/paywall reviewable ở R21; không chặn R2–R20, không giá giả.

Inputs phát hành khác: OAuth clients/signing cho Drive, store product IDs/publisher/consent, Mac/Xcode/Apple entitlement/device. Không đọc secret để đoán. Đã chốt guide3stages đúng sibling/no-question đầu/no-picker cuối,3 destinations/Library trong create, trash30 ngày, ownership Free, mood optional, negative unknown trung thực/missed không đỏ. Không cần hỏi lại.

Run1 không shared change. Slice sau ưu tiên app-owned wrapper; nếu buộc sửa handy_ui/files/core phải compatible và report từng thay đổi.


### Run 2 implementation notes (2026-11-10)

R2–R4 are source implemented and host tested, not device/browser verified. R4 is bundled into data schema 3 (the combined-run brief overrides its earlier proposed v4); later proposed schemas move down one. SQLite/IDB physical version is 2; store names and format IDs stay unchanged.
- R2: signature-based sealed ZIP restore, recorded date/size/original schema/counts, copy-merge, durable device-local pre-replace checkpoint, atomic commit rollback, CAS both at checkpoint and commit, Settings recovery after restart. Old JSON/ZIP v1/v2 still read. Missing old backup dates are explicit. Imported reminder rules are off; merge preserves current preferences.
- R3: deterministic legacy event revision IDs, immutable operation headers/content hashes, row parents, writer-incarnation actors with monotonic sequence/Lamport clocks, semantic addDelta/setManualTotal with observed IDs, operation union/collision checks, absolute-edit/skip conflict candidates, persisted guarded inverse Undo/retraction. Versioned midnight clock policy records future timezone changes; custom boundaries remain R6. This foundation does not enable sync or claim a full materialized cross-device reducer (R15).
- R4: 30-day UTC retention with ceil days-left, deleted records hidden from active reads/reminders while history/links remain, original-ID restoration, neutral retained gaps, active linked session guard, permanent-delete confirmation, idempotent purge on open, tombstones and redacted erased-item inverse payloads retained for later sync. Archive remains independent. Backup merge remaps trashed links as copies; only ordinary backups contain trash, not device recovery checkpoints.
- Native upgrade takes a flushed pre-v2 SQLite recovery file and migrates in a transaction; injected interruption rolls back and retries. Browser physical upgrade only adds missing stores atomically, preserving old rows; normalization occurs on read and v3 writes at the next commit. Browser quota/blocked-tab/runtime migration still needs real browser verification.
- Core history/calendar values and provenance are preserved in v1/v2 migration and ZIP/JSON roundtrips. All tests, including pre-existing uncommitted advanced-form/appearance tests, are part of the final run. See the run-2 report for exact final counts and file manifest.

Run 2 final host checks: engine74/74, app70/70 (`flutter test --no-pub`); both `dart analyze` clean and `dart format --output=none --set-exit-if-changed lib test` report0 changed. Fixture verifier PASS21 files/39 documented tools; no fixture/registry changes. No device/browser/store tests.

R3 regression guard: manual habit/routine order is stored as validated entityOrder IDs, separate from database key/row order; guarded order revisions preserve reorder Undo across restart and backup roundtrip without snapshotting the whole state.
