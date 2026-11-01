# Handy Save verification

From `apps/handy_save`: `flutter test --no-pub`. Native SQLite tests must run from
this package so its bundled native asset hook is active. From the suite root use
`dart run melos run test --no-select`. Root-only direct tests without Save's native
asset bundle can fail before opening SQLite; that is not a corruption diagnosis.

Engine: URL/social/unknown-domain normalization, duplicate equivalence, immutable
models, null clearing, field bounds, collection cycles, search and smart rule/date
boundaries; six-format roundtrip; malformed import/path/bomb/hash refusal; 50k data.

App: form/widget tests, no writes on Cancel, quick-save commit-before-ack retry,
preserved notes, duplicates/Add Anyway, safe metadata parsing and IPv4/IPv6 policy,
thumbnail decode/limits, native SQLite rollback/reopen/indexes/FTS/manual order,
worker death/deadline and cache LRU/cascade. Screenshots use isolated QA storage.
The bookmark-tap regression test verifies immediate original-URL dispatch and
separate Details menu navigation. `tooling/save-open-smoke.py` checks actual Android
dispatch outside the app; it does not claim a website loaded or social login worked.

Browser worker: `npx vitest run tooling/save-share-worker.test.ts --config
tooling/vitest.flutter.config.ts`. Node VM checks actual worker POST protocol,
queue transaction-before-redirect, no URL in redirect/client payload, malformed
input/size/full queue/abort/path rejection. VM providers are test doubles, never
production storage. Actual IndexedDB/PWA runtime must be tested in a browser.

Android: `tooling/flutter-screenshots.ps1 -App save -Device emulator-5558`; native
instrumentation under `android/app/src/androidTest` tests real Intent/AtomicFile
queue. ADB cold/warm SEND and restart should prove end-to-end database persistence.
Record permission-denied, scheduling/cancel and actual URL launcher outcomes.

Recorded on HandySave_QA_API35: five native queue tests, Flutter SQLite/clipboard/
ZIP integration with six screenshots, ADB cold/warm/multi-URL/duplicate persistence,
and notification denied/granted/50-schedule-cap/immediate OS delivery/cancel.
Repeat notifications with `tooling/save-notifications.ps1`; only the dedicated QA
emulator is accepted. Delayed delivery, reboot and notification tap are not covered.

Windows OLE parser: nine MSVC /W4 /WX cases passed; output is
`qa/evidence/save-windows-drop-tests.log`. These feed actual OLE callbacks using
test data objects and do not establish Explorer/browser interaction.

Performance: `flutter test test/store_test.dart`; `dart run tool/store_benchmark.dart`
records real native SQLite 100/1k/10k/50k seed, reopen, indexed query, pagination and
snapshot timings. The recorded Windows VM figures are not UI frame-rate or mobile
memory guarantees. Scrolling/frame timings on physical devices remain open.

Still required where hardware/apps exist: Facebook post/Reel, Instagram post/Reel,
TikTok, YouTube/Shorts, X, Reddit, browser share and Copy Link; installed-app opening,
iOS extension/signing, browser install/offline/update, Explorer OLE drops, background/
reboot notification delivery, storage pressure and release purchase/ads sessions.
