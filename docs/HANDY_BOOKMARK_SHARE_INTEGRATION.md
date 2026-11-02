# Handy Bookmark share integration

Status: Android queue **EMULATOR_TESTED** (five native instrumentation tests);
end-to-end cold/warm share evidence is recorded separately below. iOS requires
Xcode/macOS and an Apple team. Windows native OLE text/URL/.url drop is implemented
and compiles; nine C++ parser/data-object tests passed, but Explorer interaction
remains unverified. Web POST Share Target has Node VM tests, not browser proof.

## Shared Flutter contract

Channel: `handy.save/share`.

- `drain` (no arguments) returns a list of `{id: UUID string, text: string, title?: string, receivedAt: ISO8601 UTC string}`. Reading does **not** remove deliveries. Each delivery may contain multiple links with surrounding text; Flutter extracts and validates URLs.
- `ack` with `{id: string}` removes only that delivery's owned UUID file and returns a Boolean. The caller must commit bookmark changes to its database before acknowledgment. Keep a durable processed-delivery ledger / URL uniqueness checks so a crash between commit and acknowledgment is safe.
- Native `incoming` has no private payload. Android emits it after a successful warm share; iOS emits it when a scene becomes active. Flutter also drains at startup and resume. A handler installed after the notification can still recover the delivery from disk.
- Native errors use `SHARE_QUEUE_ERROR`, generic descriptions, and no URL logs. Android also emits `shareError` with this code and shows brief localized failure feedback. Do not acknowledge an unresolved storage failure.
- Windows `drain` returns `[]`; `ack` returns false. There is no OS share target claim on Windows.

The queue rejects oversized delivery input rather than silently truncating: 262144 UTF-16 code units for combined text, at most 100 pending deliveries, at most 100 providers/clip items per incoming operation, and a 4096-character optional title. Existing deliveries are preserved when full. Storage errors are surfaced. Corrupt records remain on disk and produce an explicit drain error, allowing repair rather than silent data loss. Queue content is private user data.

## Android

Package/namespace `com.example.handysuite.save`; debug application ID adds `.flutterpilot`. The exported Flutter Activity uses `singleTask` and registers `ACTION_SEND` and `ACTION_SEND_MULTIPLE` for `text/*`. Initial `onCreate` commits the incoming delivery before Flutter initializes; `onNewIntent` commits warm/background deliveries without starting another stack. Shared `EXTRA_TEXT`, multiple text extras, subject, and clip text / HTTP(S) URI values are supported. Content/file attachments are never resolved, read, or fetched.

A UUID is attached to the handled Intent and restored through Activity state. Redelivery of that handled Intent does not create a second queue record. Independent OS deliveries may have different UUIDs; Flutter's normalized URL duplicate rules handle them. Native deduplication does not treat identical user content as a permanent suppression key.

Each record lives in app-private `files/share_queue/<uuid>.json`, committed through `AtomicFile` (including fsync). Draining is repeatable until exact acknowledgment. Files are not exposed through a provider. Android backup is disabled. The AdMob manifest value defaults to Google's test application ID; production release configuration must supply its own verified ID and signing. The share bridge does not initialize ads.

Five Android instrumentation tests in `android/app/src/androidTest/.../ShareQueueTest.kt` exercise the real Android Intent and AtomicFile implementation: process-instance recovery/exact ack, multiple and clip text, rejection without partial writes, queue capacity, and traversal/unowned-file protection. All five passed on the isolated HandySave_QA_API35 emulator; raw output: `qa/evidence/save-android-instrument-tests.log`. Coordinate Gradle builds with `tooling/flutter-android-lock.ps1`. This is emulator execution, not physical-device verification.

## iOS

The Xcode project includes a real `SaveShare` app-extension target, Runner target dependency, Embed App Extensions phase, Swift sources, activation rules, and Debug/Release/Profile configurations. Both targets compile `Shared/ShareQueue.swift` and use App Group **`group.com.example.handysuite.bookmark`**. Host bundle ID: `com.example.handysuite.save`; extension: `com.example.handysuite.bookmark.SaveShare`.

The extension accepts `public.url` and `public.plain-text` through `NSItemProvider`. It loads bounded providers serially, never fetches URL contents, and commits one delivery to the App Group container using atomic JSON writing and complete-until-first-authentication file protection. The directory is excluded from backup. Cross-process flock locking serializes queue capacity checks, reads, writes and acknowledgment. The shared file survives extension completion with the host closed. A 20-second extraction timeout yields explicit failure rather than success. Failed/oversized extraction never commits partial delivery data.

The minimal extension view uses Dynamic Type, system colors, VoiceOver announcement, English/Vietnamese feedback, and Done. It says **queued** (bookmarks are created when Flutter next runs), never falsely claims a database save in a closed host. It never launches the host and has no advertising/network code. `AppDelegate` registers the Flutter channel with the implicit engine; `SceneDelegate` signals pending work on resume. IDs remain in files until acknowledgment.

**Signing is source configuration only.** No Apple account/team/provisioning profile is available here. On macOS, select the same Apple team on Runner and SaveShare, register both bundle IDs and the exact App Group, enable App Groups on both provisioning profiles, then build with Xcode. Keep host/extension version and build numbers aligned for archive submission (initial extension is 1.0.0 build 1). Replace example IDs only as a coordinated source/signing change. Simulator and physical-device extension lifecycle tests remain required; Windows cannot compile Swift or run iOS.

## Manual platform verification still required

1. With networking disabled, share a browser URL on cold launch, warm launch, and after backgrounding; verify Inbox persistence after restart.
2. Share text with multiple URLs and surrounding text, duplicated clip text, unsupported/empty input, maximum input, and a full queue. Verify honest localized feedback and no loss of prior pending data.
3. Kill the host between database commit and native ack; reopen and verify no duplicate bookmark and eventual acknowledgment.
4. On iOS, share while the host is terminated, finish the extension without launching the host, then launch and verify the queued bookmark. Verify multiple app-group processes and queue limit behavior.
5. Test actual Facebook Reel/post, Instagram Reel/post, TikTok, YouTube Short/video, X, Reddit, browser shares and Copy Link fallback with installed apps. These real-world source tests are **NOT_STARTED**, not platform verified.

Facebook controls its own internal sharing menu; users may need More, Custom, or the operating system Share Sheet to find Handy Bookmark. Clipboard paste remains available through an explicit user action. No overlays, accessibility automation, or private deep-link schemes are used.

## Validation recorded in this session

- PASS: Android manifest parsed as XML; verified `singleTask`, SEND and SEND_MULTIPLE registrations.
- PASS: Xcode OpenStep project parsed; verified extension target, host dependency/embed phase, three extension configurations and entitlement paths.
- PASS: four iOS plist/entitlement files parsed.
- PASS: five Android instrumentation tests on emulator-5558 (HandySave_QA_API35), Android API 35.
- PASS: Flutter Android integration covers offline save, explicit clipboard, duplicates,
  collection/notes, portable ZIP round-trip and reopening the actual SQLite database;
  six screenshots in `qa/evidence/screenshots/save-*.png`.
- Cold/warm SEND smoke: run `python tooling/bookmark-android-share-smoke.py` after building
  the main APK; `qa/evidence/save-native-share-result.json` is authoritative for its outcome.
- PASS: actual cold/warm SEND with multiple links, process reuse, tracking-URL duplicate
  protection, exact three-record SQLite check and empty acknowledged queue.
- PASS: nine Windows native OLE parser tests; `qa/evidence/save-windows-drop-tests.log`.
- No iOS compilation or device execution on this Windows host. Runtime share-source behavior remains unverified.
